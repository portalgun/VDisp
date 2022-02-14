classdef PP < handle
properties
    vrgF

    Xpix
    Ypix
    XpixCtr
    YpixCtr

    YmDiff
    XmDiff

    C
        % Xm
        % Ym
        % Xdeg
        % Ydeg
        %
        % FF
        % FFx
        % FFy
        %
        % FB
        % FBx
        % FBy
    L
    R

    PPxyz

end
properties(Hidden)
    plane
    % XXX
    %D.durationMs=60;
    %D.numFrm   = round((D.durationMs./1000)./D.ifi); % num frames computed via desired duration

    VDisp
end
methods
    function obj=PP(VDisp)

        obj.VDisp=VDisp;
        obj.vrgF=2*atand(obj.VDisp.SubjInfo.IPDm/(2*obj.VDisp.Zm));

        obj.get_proj_planes();
        obj.get_pixel_grid();
        obj.get_intrplnts();
        obj.plane=createPlane([1 0 obj.VDisp.Zm],[0 1 obj.VDisp.Zm],[0 -1 obj.VDisp.Zm]);
    end
    function get_proj_planes(obj)
        obj.get_proj_plane('C');
        obj.get_proj_plane('L');
        obj.get_proj_plane('R');
    end
    function get_proj_plane(obj,LorRorC)
        [obj.(LorRorC).Xm,obj.(LorRorC).Ym,...
         obj.(LorRorC).Xdeg,obj.(LorRorC).Ydeg ...
        ] =    PP.proj_plane(obj.VDisp.SubjInfo.LExyz, ...
                             obj.VDisp.SubjInfo.RExyz, ...
                             obj.VDisp.WHpix, ...
                             obj.VDisp.WHmm, ...
                             obj.VDisp.Zm, ...
                             LorRorC ...
                            );
    end
    function obj=get_pixel_grid(obj)
        [obj.Xpix,obj.Ypix]=meshgrid(1:obj.VDisp.WHpix(1),1:obj.VDisp.WHpix(2));
        obj.XpixCtr=obj.Xpix-obj.VDisp.ctrXYpix(1);
        obj.YpixCtr=obj.Ypix-obj.VDisp.ctrXYpix(2);
    end
    function get_intrplnts(obj)
        obj.get_forward_intrplnt('C');
        obj.get_forward_intrplnt('L');
        obj.get_forward_intrplnt('R');

        obj.get_back_intrplnt('C');
        obj.get_back_intrplnt('L');
        obj.get_back_intrplnt('R');
    end

    function obj=get_forward_intrplnt(obj,LorRorC)
        % XXX CHECK
        obj.(LorRorC).FF=cell(1,2);
        obj.(LorRorC).FFx=cell(1,2);
        obj.(LorRorC).FFy=cell(1,2);
        obj.(LorRorC).FFx{1}=transpose(obj.Xpix(1,:));
        obj.(LorRorC).FFx{2}=transpose(obj.(LorRorC).Xm(1,:));
        obj.(LorRorC).FFy{1}=   flipud(obj.Ypix(:,1));
        obj.(LorRorC).FFy{2}=   flipud(obj.(LorRorC).Ym(:,1));

        obj.YmDiff=diff(obj.C.Ym(1:2,1));
        obj.XmDiff=diff(obj.C.Xm(1,1:2));

        % XXX?
        %obj.FF{1}=griddedInterpolant(obj.(LorRorC).FFx{1},obj.(LorRorC).FFy{1},'linear');
        %obj.FF{2}=griddedInterpolant(obj.(LorRorC).FFx{2},obj.(LorRorC).FFy{2},'linear');
    end
    function obj=get_back_intrplnt(obj,LorRorC)
        obj.(LorRorC).FBx{1}=obj.(LorRorC).FFx{2};
        obj.(LorRorC).FBx{2}=obj.(LorRorC).FFx{1};
        obj.(LorRorC).FBy{1}=obj.(LorRorC).FFy{2};
        obj.(LorRorC).FBy{2}=obj.(LorRorC).FFy{1};

        % XXX CHECK
        obj.(LorRorC).FB=cell(1,2);
        %add=-0.5;
        a=0;

        %obj.FB{1}=griddedInterpolant(transpose(obj.C.Xm(1,:)),transpose(obj.C.XpixCtr(1,:))+a,'linear');
        %obj.FB{2}=griddedInterpolant   (flipud(obj.C.Ym(:,1)),   flipud(obj.C.YpixCtr(:,1))+a,'linear');

        obj.(LorRorC).FB{1}=griddedInterpolant(obj.(LorRorC).FBx{1},obj.(LorRorC).FBx{2},'linear');
        obj.(LorRorC).FB{2}=griddedInterpolant(obj.(LorRorC).FBy{1},obj.(LorRorC).FBy{2},'linear');

    end

    function pointsXYZm=forward_project(obj,LitpRC,RitpRC, LExyzVec,RExyzVec,Zvec,cinit,LorRorC)
        if nargin < 8
            LorRorC='C';
        end
        % PIX 2 METERS
        %pointsXYZm=XYZ.forward_project(obj.LExyz,obj.RExyz,LitpRC,RitpRC,obj.C.Xm,obj.C.Ym,obj.C.Zm,obj.C.XpixCtr,obj.C.YpixCtr);

        if nargin < 4
            n=size(LitpRC,1);
            LExyzVec=repmat(obj.VDisp.SubjInfo.LExyz,n,1);
            RExyzVec=repmat(obj.VDisp.SubjInfo.RExyz,n,1);
            if nargin < 5
                Zvec=repmat(obj.VDisp.Zm,n,1);
                if nargin < 6
                    cinit=zeros(size(RExyzVec));
                end
            end
        end


        %pointsXYZm=intersectLinesFromPoints(LExyzVec,LitpXYZm,RExyzVec,RitpXYZm,[],cinit); % SLOW
        % ----

        %LitpXYm = [interp1(obj.C.Xm(1,:),LitpRC(:,2)) interp1(obj.C.Ym(:,1)',LitpRC(:,1))];
        %RitpXYm = [interp1(obj.C.Xm(1,:),RitpRC(:,2)) interp1(obj.C.Ym(:,1)',RitpRC(:,1))];
        LitpXYm=obj.forward_interp_(LorRorC,LitpRC);
        RitpXYm=obj.forward_interp_(LorRorC,RitpRC);

        LitpCxyz=[LitpXYm, Zvec];
        RitpCxyz=[RitpXYm, Zvec];

        pointsXYZm=intersectLinesFromPoints(LExyzVec,LitpCxyz,RExyzVec,RitpCxyz);
    end
    function [RCL,RCR]=back_project(obj,pointsXYZ,bRound,LorRorC)
        if nargin < 4
            LorRorC='C';
        end
        if nargin < 3
            bRound=false;
        end
        n=size(pointsXYZ,1);
        LExyz=repmat(obj.VDisp.SubjInfo.LExyz,n,1);
        RExyz=repmat(obj.VDisp.SubjInfo.RExyz,n,1);

        Lline=createLine3d(LExyz,pointsXYZ);
        Rline=createLine3d(RExyz,pointsXYZ);
        PPxyzLM=intersectLinePlane(Lline,obj.plane);
        PPxyzRM=intersectLinePlane(Rline,obj.plane);

        RCL=obj.back_interp_(LorRorC,PPxyzLM(:,1:2));
        RCR=obj.back_interp_(LorRorC,PPxyzRM(:,1:2));


        if bRound
            RCL=round(RCL,8);
            RCR=round(RCR,8);
        end

    end
end
methods(Static)
    %function apply_CPs(CPs,winWHdeg,winPosXYZ)
    %    % NOTE CPs are ctred raw CPS
    %end
    function [IppXm,IppYm,IppXdeg,IppYdeg]=proj_plane(LExyz,RExyz,scrnWHpix,scrnWHmm,IppZm,LorRorC)

        if strcmp(LorRorC,'L')
            K = RExyz(1);
        elseif strcmp(LorRorC,'C')
            K = 0;
        elseif strcmp(LorRorC,'R')
            K = LExyz(1);
        end

        scrnXY=scrnWHmm/1000;
        scrn=fliplr(round(scrnWHpix));
        I = zeros(scrn);

        IppXm    = K + Wave.smpPos(size(I,2)./scrnXY(1),size(I,2));
        IppYm    = fliplr(Wave.smpPos(size(I,1)./scrnXY(2),size(I,1)));
        IppXm    = IppXm + diff(IppXm(1:2))/2;
        IppYm    = IppYm - diff(IppYm(1:2))/2;
        [IppXm,IppYm] = meshgrid(IppXm,IppYm);

        IppXdeg = atand(IppXm./IppZm);
        IppYdeg = atand(IppYm./IppZm);
    end
end
methods(Access=private)
    function XY=forward_interp_(obj,LorRorC,vRC)
        XY=zeros(size(vRC));

        % pix, m
        XY(:,1)=obj.interp1F(obj.(LorRorC).FFx{1}, obj.(LorRorC).FFx{2},vRC(:,2), obj.XmDiff);
        XY(:,2)=obj.interp1F(obj.(LorRorC).FFy{1}, obj.(LorRorC).FFy{2},vRC(:,1), obj.YmDiff);

        % OLD
        %XY(:,1)=obj.FF{1}(VRC(:,2));
        %XY(:,2)=obj.FF{2}(VRC(:,1));
    end
    function RC=back_interp_(obj,LorRorC,VXY)
        RC=zeros(size(VXY));
        RC(:,2)=obj.(LorRorC).FB{1}(VXY(:,1));
        RC(:,1)=obj.(LorRorC).FB{2}(VXY(:,2));
    end
    function yi=interp1F(obj,x,y,xi,ydiff)
        % x is pix
        % y is m

        m = size(x,1);

        % ind1 = hist(ci,x).bin = round(xi) = x(ind1)
        ind1=floor(xi);  % XXX bottlneck 2

        ind1 = max(ind1,1);     % To avoid index=0 when xi < x(1)
        ind1 = min(ind1,m-1);   % To avoid index=m+1 when xi > x(end).

        yi = y(ind1) + (xi-ind1)*ydiff; % XXX bottlneck 1
    end
end
methods(Static,Access=private)
    function yi=interp1qr(x,y,xi)
        % XXX NOT USED?
    %https://www.mathworks.com/matlabcentral/fileexchange/43325-quicker-1d-linear-interpolation-interp1qr
        m = size(x,1);
        %n = size(y,2);

        % For each 'xi', get the position of the 'x' element bounding it on the left [p x 1]
        [~,ind1] = histc(xi,x); % XXX bottleneck 1, get left bound

        ind1 = max(ind1,1);     % To avoid index=0 when xi < x(1)
        ind1 = min(ind1,m-1);   % To avoid index=m+1 when xi > x(end).

        ind2=ind1+1;
        x1=x(ind1);
        y1=y(ind1);


        t = (xi-x1)./(x(ind2)-x1); % dxi/dx
        % Get 'yi'
        yi = y1 + t.*(y(ind2)-y1); % XXX bottlneck 2
        % Give NaN to the values of 'yi' corresponding to 'xi' out of the range of 'x'


        %yi(xi<x(1) | xi>x(end),:) = NaN;
    end
end
end
