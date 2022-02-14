classdef VDisp < handle
% TODO min max values for points and display
properties

    %Opts
    hostname
    subjname

    Zm
    WHmm % XXX todo change back to m
    XYpix
    WHpix

    gammaType %$fname OR num OR exp

    bDataPixx
    bSkipSyncTest=1
    defStereoMode

    % Calc
    hz
    bitsOut
    XYdeg
    sid

    ctrXYpix
    ctrRCpix

    % conversion
    pixPerDegXY
    pixPerMxy
    degPerMxy


    GammaC
    d %secondary attributes - changing/arbitrary

    SubjInfo
    PP
end
methods
    function obj=VDisp(hostname,subjname)
        if nargin < 1
            hostname=Sys.hostname;
        end
        if nargin < 2 || isempty(subjname)
            Error.warnSoft('Using default subjectInfo');
            subjname=[];
        end

        obj.hostname=hostname;
        Opts=VDisp.read(hostname);
        obj.parse_opts(Opts);

        obj.get_dims();

        obj.subjname=subjname;
        obj.SubjInfo=SubjInfo(subjname);


        obj.PP=PP(obj);
        %obj.get_proj_plane('C');
        %obj.get_pixel_grid();
        %obj.get_forwardInterpolant();
        %obj.get_backInterpolant();

        global VDISP;
        VDISP=obj;
    end
    function parse_opts(obj,Opts)
        P=obj.getP();
        Args.parse(obj,P,Opts);

        obj.GammaC=GammaC(obj.gammaType);
    end
    function setup_Xorg(obj)

        % XXX NOT USED
        dest='/etc/X11/xorg.conf.d/90-ptbxorg.conf';
        if ~isempty(obj.xconf)
            if Fil.exist(dest)
                delete(dest);
            end
            copyfile(obj.xconf, dest);
        end
    end
    function obj=init(obj,ptb)
        obj.get_sid(ptb);
        obj.get_res(ptb);
        obj.get_rate(ptb);
        obj.get_bits(ptb);
    end

    function obj=get_res(obj,ptb)
        if ~isempty(obj.WHpix)
            return
        elseif exist('ptb','var')
            a = Screen('Resolution',obj.sid);
            obj.WHpix(1)=a.width;
            obj.WHpix(2)=a.height;
        elseif Sys.islinux
            [~,scrn]=system('xrandr -q | sed ''s/primary //g'' | grep " connected" | awk ''{print $3}'' | grep "[0-9]" | sed ''s/\(x\|+\)/ /g''');
        elseif ismac
            [~,scrn]=system('system_profiler SPDisplaysDataType | grep Resolution | awk ''{print $2 " " $4}''');
        elseif ispc
            [~,scrn]=system('wmic desktopmonitor get ScreenHeight, screenwidth');
        end

        try
            scrn=strsplit(scrn,newline);
            scrn=scrn(~cellfun(@isempty, scrn));
            scrn=reshape(scrn,size(scrn,2),1);
            for i = 1:size(scrn,1)
                obj.WHpix(i,:)=strsplit(scrn{i});
            end
        end
    end

    function obj=get_bits(obj,ptb)
        obj.bitsOut = Screen('PixelSize',obj.sid)./3;
    end

    function obj=get_sid(obj,ptb)
        screens=Screen('Screens');
        wh=zeros(length(screens),2);
        for i = 1:length(screens)
            j=screens(i);
            [wh(i,1) wh(i,2)]=Screen('DisplaySize',j);
        end
        [ind]=ismember(wh,obj.WHpix,'rows');
        ind=find(ind);
        obj.sid=screens(ind);
        if isempty(obj.sid);
            obj.sid=0;
        end
    end

    function obj=get_rate(obj,ptb)
        if ~isempty(obj.hz)
            return
        end
        if exist('ptb','var')
            hz=Screen('FrameRate',obj.sid);
        elseif ismac
            [~,hz]=system('system_profiler SPDisplaysDataType | grep Resolution | awk ''{print $6}''');
        else
            % XXX
            obj.hz=[];
        end
        for i = 1:size(obj.hz,1)
            tmp=splitlines(obj.hz);
            tmp(strcmp(tmp,''))=[];
            obj.hz=transpose(str2double(tmp));
        end
    end

    function obj=get_dims(obj)
        obj.XYdeg   = 2.*atan2d(0.5.*obj.WHmm,obj.Zm*1000);
        obj.pixPerDegXY = obj.WHpix(1:2)./obj.XYdeg;

        obj.pixPerMxy=obj.WHpix./obj.WHmm*1000;
        %obj.pixPerMxy=obj.WHpix(1:2)./obj.WHmm;
        %
        %degPerMxy=obj.XYdeg./obj.WHmm*1000
        obj.degPerMxy=obj.pixPerMxy./obj.pixPerDegXY;
        %obj.degPerMxy=repmat(2*atand(0.5/(obj.nZm)),1,2);

        obj.ctrXYpix=round(obj.WHpix./2)+0.5; % XXX NOTE
        obj.ctrRCpix=fliplr(obj.ctrXYpix);
    end
end
methods(Static=true)
    function out=hasXorg()
        if isunix()
            out=~isempty(Sys.run('xset q &>/dev/null && echo 1'));
        else
            out=false;
        end
    end
    function [Opts,fil]=read(name,bVR)
        if nargin < 1 || isempty(name)
            name=Sys.hostname;
            name=strtok(strrep(name,'-','_'),'.');
        end
        dire=getenv('PX_ETC');
        fil=[dire 'VDisp.d' filesep name '.cfg'];
        if ~Fil.exist(fil)
            error(['VDisp config ' fil ' does not exist']);
        end
        Opts=Cfg.read(fil);
    end
end
methods(Static)
    function P=getP()
        P={...
            'Zm',[],'Num.is';
            'WHmm',[],'Num.is_2';
            'WHpix',[],'Num.is_2';
            'XYpix',[],'Num.is_2';
            'bDataPixx',0,'isBinary';
            'bSkipSyncTest',0,'isBinary';
            'gammaType','','ischar';
            'defStereoMode',0,'Num.is';
        };

    end

end
end
