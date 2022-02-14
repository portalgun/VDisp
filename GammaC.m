classdef GammaC < handle
properties
    type
    name
    dir
    fname

    exp

    pix
    fnc
    inv

    bInitd=0
    bSetName=0

    cals
    cal
end
methods
    function obj=GammaC(thing);
        if isempty(thing)
            obj.type='None';
        elseif isnumeric(thing)
            obj.type='Simple';
            obj.exp=thing;
        elseif ischar(thing) && ismember(thing,{'simple','Simple','exp'})
            obj.type='Simple';
            obj.exp=2.2;
        elseif ischar(thing)
            obj.type='Lookup';
            obj.name=thing;
        end
    end
    function obj=load(obj)
        if isempty(obj.name)
            return
        end
        % LOAD
        bSucces=obj.get_fname;
        if ~bSuccess
            return
        end
        S=load([obj.dir obj.fname]);

        % SELECT
        if ~isfield(S,'cal') && ~isempty(obj.cal)
            S.cal=S.cals{obj.cal};
        elseif ~isfield(S,'cal')
            S.cal=S.cals{end};
        end
        obj.cal=S.cal;
        if isfield(S,'cals')
            obj.cals=S.cals;
        end

        % CONVERT
        obj=obj.convert_cal;

        obj.bInitd=1;
    end

    function bSuccess = get_fname(obj)
        if ~obj.bInitd && ~isempty(obj.fname)
            obj.bSetName=1;
        end

        if ~isequal(obj.bSetName,1)
            [file,fdir]=obj.get_newest_cal_file_all();
            if isempty(file) && isempty(obj.fname)
                Error.warnSoft('No calibration file found.');
                bSuccess=false;
                return
            elseif isempty(file)
                Error.warnSoft(['No calibration file found with name ' obj.fname]);
                bSuccess=false;
                return
            end
            obj.fname=file;
            obj.dir=fdir;
            bSuccess=true;
        elseif isequal(obj.bSetName,1) && ~isequal(obj.bSetName,1)
            [~,obj.dir]=lORs('cal');
            chkFile([obj.dir obj.fname]);
            bSuccess=true;
        else
            chkFile([obj.dir obj.fname]);
            bSuccess=true;
        end
    end
    function [file,fdir] = get_newest_cal_file_all(obj)
        file=[];
        fdir=[];
        fdirLoc = Env.var('cal','LOC');
        fdirSrv = Env.var('cal','SRV');
        if exist(fdirLoc,'dir')
            flagLoc = Dir.check(fdirLoc,1,0);
        else
            flagLoc=0;
        end
        flagSrv = Dir.check(fdirSrv,1,0);
        fileSrv='';
        fileLoc='';
        datLoc='';
        datSrv='';
        if flagLoc==1
            [fileLoc,datLoc]=get_newest_cal_file(obj,fdirLoc);
        end
        if flagSrv==1
            [fileSrv,datSrv]=get_newest_cal_file(obj,fdirSrv);
        end
        fdirs={fdirLoc;fdirSrv};
        dates={datLoc;datSrv};
        if isempty(fileLoc)
            fLoc=[];
        else
            fLoc=fileLoc{1};
        end
        if isempty(fileSrv)
            fSrv=[];
        else
            fSrv=fileSrv{1};
        end

        files={fLoc;fSrv};
        if isempty(fLoc) && isempty(fSrv)
            return
        end
        ind=Date.newest(dates);
        file=files{ind};
        fdir=fdirs{ind};
    end
    function [file,dat]=get_newest_cal_file(obj,dir)
        FILES=Fil.find(dir,[obj.name '.*\.mat']);
        if numel(FILES)==1
            ind=1;
        elseif numel(FILES)==0
            file=[];
            dat=[];
            return
        end
        dates=strrep(FILES,obj.name,'');
        dates=strrep(dates,'.mat','');
        dates=strrep(dates,'_',' ');
        dates=strrep(dates,'-',' ');
        dates=strtrim(dates);
        dates=strrep(dates,' ','-');
        dates=dates(Str.RE.ismatch(dates,'[A-Za-z]{3}-[0-9]{2}-[0-9]{4}'));

        if ~exist('ind','var')
            ind=Date.newest(dates);
        end
        file=FILES(ind);
        dat=dates{ind};
    end
    function obj=convert_cal(obj)
        % CONVERT GAMMA DATA IN cal STRUCT TO STANDARD FORMAT
        obj.pix = obj.cal.processedData.gammaInput;
        obj.fnc = obj.cal.processedData.gammaTable;
        fail=0;
        for i = 1:size(obj.fnc,2)
            try
                obj.inv(:,i) = interp1(obj.fnc(:,i),obj.pix,linspace(min(obj.fnc(:)),max(obj.fnc(:)),transpose(numel(obj.pix))));
            catch
                obj.inv(:,i) = zeros(numel(obj.pix),1);
                fail=fail+1;
            end
        end
        obj.inv(1,isnan(obj.inv(1,:)))=0;

        if all(obj.inv==0)
            error('    Error! Calibration data is bad, read all zeros!');
        elseif fail > 0
            fai=num2str(fail);
            tot=num2str(size(obj.fnc,2));
            %warning(['psyLoadCalibrationData: WARNING! ' fai ' out of ' tot ' channels are empty. This may or may not be fine']);
        end

        % WRITE TO SCREEN
        if  isempty(obj.cal)
            error(['    Loaded empty calibration in ' fdir fname '.']);
        else
          disp(['    Loaded calibration ' obj.dir obj.fname '.']);
        end
    end
end
end
