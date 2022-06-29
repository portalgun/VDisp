classdef Ptb < handle
% help OculusVR
% developer.oculus.com/download
% PsychVRHMD

properties
    % opts
    VDisp

    bSkipSyncTest
    bVR
    bDebug
    bDummy
    bDataPixx
    bTextRender

    stereoMode
    % 0 - none
    % 1 - stereo
    % 2 - left/right
    % 3 - top/bottom
    % 4 - eye per display
    % 5 - eye per display, flipped

    gry
    blk
    wht
    alpha

    textFont
    textSize
    text=struct()
    cText=struct()

    wdwPtr
    wdwXYpix

    % calc
    refreshRate
    ifi
    fps
    bStereo

    % Flags
    bDataPixxOn=0
    bAlphaBlendingOn=0
    gammaFlag=-1


    vblT
    onsetT
    flipT
    listen=1 % 0 - off, 1 - on, 2 - ptb only

    setupInfo
    closeInfo
    ME
end
methods
    function obj=Ptb(vDisp,Opts)
        if nargin < 1
            vDisp=[];
        end
        if nargin < 2
            Opts=struct();
        end
        obj.parse_display(vDisp);
        obj.parse_opts(Opts);


        if obj.bDummy
            return
        end

        try
            sca;
        end
        [obj.setupInfo]=evalc('obj.Ptb_main();');
        obj.setupInfo=strrep(obj.setupInfo,[newline newline],'');
        obj.setupInfo=regexprep(obj.setupInfo,'PTB-','  PTB-');
        obj.setupInfo=regexprep(obj.setupInfo,'PTB-WARNING','PTB-WARN');
        if ~isempty(obj.ME)
            disp(obj.setupInfo)
            rethrow(ME);
        end

    end
    function parse_display(obj,vDisp)
        global VDISP;
        if isempty(vDisp) && ~isempty(VDISP)
            obj.VDisp=VDISP;
        elseif isa(vDisp,'VDisp')
            obj.VDisp=vDisp;
        elseif isempty(vDisp)
            obj.VDisp=VDisp();
        elseif ischar(vDisp)
            obj.VDisp=VDisp(vDisp);
        else
            error(); % TODO
        end
    end
    function obj=parse_opts(obj,Opts)
        P=obj.getP;
        obj=Args.parse(obj,P,Opts);

        % Datapixx
        if isempty(obj.bDataPixx) && obj.VDisp.bDataPixx
            obj.bDataPixx=true;
        elseif isempty(obj.bDataPixx)
            obj.bDataPixx=false;
        elseif obj.bDataPixx && ~obj.VDisp.bDataPixx
            Error.warnSoft('Datapixx is not setup with display');
        end

        % alpha
        if isempty(obj.alpha) && obj.bDebug
            obj.alpha = 0.5;
        elseif isempty(obj.alpha)
            obj.alpha = 1.0;
        end

        % skipSync
        if isempty(obj.bSkipSyncTest) && ~isempty(obj.VDisp.bSkipSyncTest)
            obj.bSkipSyncTest=obj.VDisp.bSkipSyncTest;
        elseif isempty(obj.bSkipSyncTest)
            obj.bSkipSyncTest=false;
        end

        if isempty(obj.stereoMode)
            obj.stereoMode=obj.VDisp.defStereoMode;
        end

        obj.bStereo=obj.stereoMode > 0;
    end
    function Ptb_main(obj)
        obj.ME=[];
        obj.dispSepS('PTB_SETUP');
        try
            obj.dispSep('VDISP');
            obj.VDisp=obj.VDisp.init(obj);
            obj.dispSep('SETUP');
            obj.setup();
            obj.dispSep('GAMMA');
            obj.gamma_setup();

            obj.DP_open();

            %obj.textFont
            %obj.text.font=obj.textFont;
            %Screen('Preference','DefaultFontName')
            %Screen('Preference','DefaultFontName',obj.textFont);
            %Screen('Preference','DefaultFontStyle',0);
            %Screen('Preference','TextRenderer', 1);

            obj.dispSep('OPEN');
            obj.open();
            %obj.openInfo=evalc('obj.open();'); %wdwPtr
            if obj.bVR
                obj.dispSep('VR');
                obj.VR_setup();
            end
            obj.dispSep('IFI');
            obj.get_ifi();
            obj.dispSep('TEXT');
            obj.set_text();
            %obj.textInfo=evalc('obj.set_text;');
            obj.dispSep('ALPHA');
            obj.alpha_blend_on;
            obj.dispSep('GAMMA_APPLY');
            obj.gamma_correct();
            obj.dispSep('main.pilot_flatFLIP');
            Screen('Flip', obj.wdwPtr,[],0);
            obj.refresh;
            obj.keyOn_noMat();
            obj.dispSepS('PTB_SETUP_END');
        catch ME
            try
                obj.sca;
            end
            obj.ME=ME;
        end
    end
    function obj = get_ifi(obj)
        obj.ifi     = Screen('GetFlipInterval', obj.wdwPtr);
        obj.fps     = 1/obj.ifi;
    end

    function obj=setup(obj)
        AssertOpenGL;

        % PREPARE PSYCHIMAGING
        PsychImaging('PrepareConfiguration');
        % FLOATING POINT NUMBERS
        PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
        % USE NORMALIZED [0 1] RANGE FOR COLOR AND LUMINANCE LEVELS
        PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
        % SKIP SYNCTESTS OR NOT

        Screen('Preference', 'SkipSyncTests', double(obj.bSkipSyncTest));
        if obj.bVR
            obj.VR_setup();
        end

        PsychDebugWindowConfiguration([],obj.alpha); % NOTE! must call before opening ptb window
    end
    function obj=VR_setup(obj)
        if obj.bStereo
            str='Stereoscopic';
        elseif ~obj.bStereo
            str='Monoscopic';
        end
        obj.HMD = PsychVRHMD('AutoSetupHMD', str);

        [projL,projR]=psychVRHMD('GetStaticREnderParameters',hmd);
        needPanelFitter = psychVRHMD('GetPanelFitterParameters',hmd);
        [bufferSize, imagingFlags, stereoMode]=PsychVRHMD('GetClientRenderingParameters',hmd);
        PsychVRHMD('SetBasicQuality', hmd, basicQuality);
        PsychVRHMD('SetupRenderingParameters', hmd, basicTask,basicRequirements,basicQuality,fov,pixelsPerDisplay);
        %pixelsPerDisplay - ratio of number of render target pixels to display pixels at center of distortion (def 1.0)
        %fov [leftdeg rightdeg updeg downdeg]
        info = PsychVRHMD('GetInfo',hmd);
        PsychVRHMD('Close',hmd);
        hmnd;

    end

    function obj=DP_open(obj)
        if obj.bDataPixx && obj.VDisp.bDataPixx
            obj.dispSep('DATAPIXX');
            % SET BOOLEAN INDICATING THAT DATAPIXX IS BEING USED

            % TURN DATAPIXX ON
            Ptb.DPopen();
            obj.bDataPixxOn = 1;
        else
            obj.bDataPixxOn = 0;
            %disp(['psyDatapixxInit: WARNING! unrecognized localHostName: ' hostname() '. Write code?']);
        end
    end
    function obj=DP_close(obj)
        %% TURN DATAPIXX OFF
        if obj.bDataPixxOn==0
            return
        end
        Ptb.DPclose();
        obj.bDataPixxOn = 0;
    end

    function obj=alpha_blend_on(obj)
% MOST COMMON ALPHA-BLENDING FACTORS
        Screen('BlendFunction', obj.wdwPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        obj.bAlphaBlendingOn=1;
    end

    function obj=alpha_blend_off(obj,wdwPtr)
        Screen('BlendFunction', wdwPtr, GL_ONE, GL_ZERO);
        obj.bAlphaBlendingOn=0;
    end

    function open(obj)
        XY=obj.VDisp.XYpix;
        WH=obj.VDisp.WHpix;
        rect=[XY XY+WH];
        if ismac
            [obj.wdwPtr, obj.wdwXYpix]  = PsychImaging('OpenWindow', obj.VDisp.sid, obj.gry, [],[], [], obj.stereoMode);
        else
            [obj.wdwPtr, obj.wdwXYpix]  = PsychImaging('OpenWindow', obj.VDisp.sid, obj.gry, rect,[], [], obj.stereoMode);
        end
    end
% TEXT/FONT
    function []=set_text(obj)


        obj.text.font=obj.textFont;
        obj.text.size=obj.textSize;
        obj.cText.size=obj.text.size;
        obj.cText.font=obj.text.font;

        Screen('TextFont', obj.wdwPtr, obj.textFont);
        Screen('Preference','DefaultFontName',obj.textFont);
        Screen('TextSize',obj.wdwPtr,obj.textSize);

        if obj.bTextRender
            Screen('Preference','TextRenderer', 1);
        end

        [obj.text.H,obj.text.W,obj.text.WSpc,obj.text.HTail]=obj.get_text_char_dims();

        obj.text.dH=obj.text.H/obj.text.size;
        obj.text.dW=obj.text.W/obj.text.size;
        obj.text.dWSpc=obj.text.WSpc/obj.text.size;

        obj.cText=obj.text;
        %obj.cText.H=obj.text.H;
        %obj.cText.W=obj.text.W;
        %obj.cText.WSpc=obj.text.WSpc;

        %obj.cText.dH=obj.text.dH;
        %obj.cText.dW=obj.text.dW;
        %obj.cText.dWSpc=obj.text.dWSpc;
    end
    function change_font(obj,textFont,textSize)
        bFontFlag=false;
        bSizeFlag=false;
        if ~strcmp(textFont,obj.cText.font)
            Screen('TextFont',obj.wdwPtr,textFont);
            obj.cText.font=textFont;
            bFontFlag=true;
        end
        if nargin >= 3 && ~isequal(textSize,obj.cText.size)
            Screen('TextSize',obj.wdwPtr,textSize);

            if ~bFontFlag
                lastSize=obj.cText.size;
                lastW=obj.cText.W;
                lastH=obj.cText.H;
                lastWSpc=obj.cText.WSpc;
            end

            obj.cText.size=textSize;
            bSizeFlag=true;
        end
        if bFontFlag
            [obj.cText.H,obj.cText.W,obj.cText.WSpc,obj.cText.HTail]=obj.get_text_char_dims();
        elseif bSizeFlag
            obj.update_text_char_dims(lastSize,lastW,lastH,lastWSpc);
        end

    end
    function update_text_char_dims(obj,lastSize,lastW,lastH,lastWSpc)
        dSz=obj.cText.size-lastSize;
        obj.cText.W    = lastW    + obj.cText.dW    * dSz;
        obj.cText.H    = lastH    + obj.cText.dH    * dSz;
        obj.cText.WSpc = lastWSpc + obj.cText.dWSpc * dSz;
    end
    function [height,width,wspace,htail]=get_text_char_dims(obj)
        jR=Screen('TextBounds',obj.wdwPtr,'j');
        %hj=jR(4)-jR(2);

        gR=Screen('TextBounds',obj.wdwPtr,'G');
        %hg=gR(4)-gR(2);
        wg=gR(3)-gR(1);

        ggR=Screen('TextBounds',obj.wdwPtr,'GG');
        wgg=ggR(3)-ggR(1);
        %hgg=ggR(4)-ggR(2);

        %jjR=Screen('TextBounds',obj.wdwPtr,['j' newline 'j']);
        %hjj=jjR(4)-jjR(2);

        height=jR(4)-gR(2);
        width=wg;
        wspace=wgg-wg*2;
        htail=height-(gR(4)-gR(2));
        %vspace=hjj-hj*2
        %dk
    end
    function restore_font(obj)
        if ~strcmp(obj.text.font,obj.cText.font)
            Screen('TextFont',obj.wdwPtr,obj.text.font);
            obj.cText.font=obj.text.font;
        end
        if nargin >= 3 && ~isequal(obj.text.size,obj.cText.Size)
            Screen('TextSize',obj.wdwPtr,obj.text.size);
            obj.cText.size=obj.text.size;
        end
    end
% FLIP
    function []=flip(obj,when)
        if ~exist('when','var')
            when=0;
        end
        Screen('DrawingFinished',obj.wdwPtr);
        [obj.vblT obj.onsetT obj.flipT]= Screen('Flip',obj.wdwPtr,when,0,0,1);
    end
    function []=flip_hold(obj,when)
        if ~exist('when','var')
            when=0;
        end
        Screen('DrawingFinished',obj.wdwPtr);
        Screen('Flip',obj.wdwPtr,when,1,0,1);
    end

    function refresh(obj)
        obj.refreshRate=Screen('GetFlipInterval',obj.wdwPtr);
    end
    function []=gamma_setup(obj)
        obj.VDisp.GammaC.load;
        switch obj.VDisp.GammaC.type
            case {'None','','none'}
                return
            case {'LookupTable','Lookup'}
                PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'LookupTable');
            case 'Simple'
                PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma');
            otherwise
                error(['    Unhandled gammaType. gamCrctType=' obj.VDisp.GammaC.type]);
        end
        obj.gammaFlag=0;
    end
    function gamma_correct(obj)
        obj.gammaFlag=-1;
        switch obj.VDisp.GammaC.type
            case {'None','none',''}
                obj.gammaFlag=0;
            case {'LookupTable','Lookup'}
                fprintf('    ');
                PsychColorCorrection('SetLookupTable', obj.wdwPtr, obj.VDisp.GammaC.inv);
                disp(['    Using ' obj.VDisp.GammaC.type ' to correct gamma']);
                obj.gammaFlag=1;
            case 'Simple'
                PsychColorCorrection('SetEncodingGamma', obj.wdwPtr, 1./obj.VDisp.GammaC.exp);
                disp('    WARNING! correcting gamma via SimpleGamma. This is not advised!');
                obj.gammaFlag=2;
            otherwise
                error(['    WARNING! unhandled D.gammaType: ' obj.VDisp.GammaC.type ]);
        end
    end

    function close(obj)
        obj.closeInfo=evalc('obj.sca();');
        obj.closeInfo=strrep(obj.closeInfo,[newline newline],'');
    end
    function sca(obj)
        obj.dispSepS('PTB_CLOSE');

        try
            obj.DP_close;
        end
        sca;

        obj.keyOn_noPtb;
        disp(newline);
        obj.dispSepS('PTB_CLOSE_END');
    end
%% KEY
    function keyOn(obj)
        if obj.listen==-1
            obj.listen=0;
            ListenChar(obj.listen);
        end
        obj.listen=1;
        ListenChar(obj.listen);
    end
    function keyOn_noMat(obj)
        obj.listen=2;
        ListenChar(obj.listen);
    end
    function keyOn_noPtb(obj)
        obj.listen=0;
        ListenChar(obj.listen);
    end
    function keyOff(obj)
        % neither
        obj.listen=-1;
        ListenChar(obj.listen);
    end

end
methods(Static)
    function DPclose()
        Datapixx('Open');
        Datapixx('SelectDevice',4,'LEFT');      % SELECT LEFT  VIEWPIXX MONITOR
        Datapixx('SetVideoGreyscaleMode',0);    % TURN OFF CUSTOM GRAYSCALE MODE
        Datapixx('SelectDevice',4,'RIGHT');     % SELECT RIGHT VIEWPIXX MONITOR
        Datapixx('SetVideoGreyscaleMode',0);    % TURN OFF CUSTOM GRAYSCALE MODE
        Datapixx('SelectDevice',-1);            % NORMAL OPERATION
        Datapixx('RegWr');                      % WRITE
        Datapixx('Close');
    end
    function DPopen()
        Datapixx('Open');
        Datapixx('SelectDevice',4,'LEFT');      % SELECT LEFT  VIEWPIXX MONITOR, DEVICE TYPE 4
        Datapixx('SetVideoGreyscaleMode',1);    % TURN ON CUSTOM GRAYSCALE MODE: RED CHANNEL==LEFT
        Datapixx('SelectDevice',4,'RIGHT');     % SELECT RIGHT VIEWPIXX MONITOR, DEVICE TYPE 4
        Datapixx('SetVideoGreyscaleMode',2);    % TURN ON CUSTOM GRAYSCALE MODE: GREEN==RIGHT CHANNEL
        Datapixx('SelectDevice',-1);            % NORMAL OPERATION
        Datapixx('RegWr');                      % WRITE
    end
    function SCA()
        try
            Ptb.DPclose();
        end
        sca;
        obj.keyOn;
    end
    function P=getP()
        P={ ...
            'textFont','Monospaced','ischar'; % XXX isfont
            'textSize',30,'Num.is';
            'gry',0.5,'isnormal';
            'wht',1.0,'isnormal';
            'blk',0.0,'isnormal';
            'alpha',[],'isnormal_e';
            'bDummy',false,'isBinary';
            'bDebug',false,'isBinary';
            'bTextRender',1,'isBinary';
            'stereoMode',[],'Num.is';
            'bVR',false,'isBinary';
            'bSkipSyncTest',[],'isBinary';
            'bDataPixx',[],'isbinary_e';
        };
    end
    function dispSepS(name)
        l=76-length(name);
        txt=[ name repmat('-',1,l)];
        disp(txt);
    end
    function dispSep(name)
        l=73-length(name);
        txt=['---' name repmat('-',1,l)];
        disp(txt);
    end

end
end
