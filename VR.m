classdef VR < handle
properties
    hmd
    task
end
function obj = VR(task)
    obj.hmd=PsychOculusVR1('AutoSetupHMD');
    task='Tracked3DVR'; % motion tracking
    task='Stereoscopic'; % no tracking
    task='Monoscopic';  % regular display
    basicReqs='LowPersistience'; % keep exposure time of visual images on retina low if ossible
    basicReqs='DebugDisplay'; % on other display as well
    basicReqs='Float16Display'; % auto


    hmd('SetAutoClose',obj.hmd,mode)
    % 1 - close hmd
    % 2 close all hmds and shutdown driver
    %
    PsychVRHMD('IsOpen',obj.hmd)

    PsychVRHMD('Close', obj.hmd)
    PsychVRHMD('Controllers',obj.hmd)
    info=PsychVRHMD('GetInfo',obj.hmd)
    PsychVRHMD('GetInputState',obj.hmd,controllertype)

    state=PsychVRHMD('PrepareRender', obj.hmd)

    eyePose = PsychVRHMD('GetEyePose',obj.hmd)
    % Query PsychVRHMD('SetupRendeirngParameters',obj.hmd)
    PsychVRHMD('SetBasicQuality',obj,hmd, basicQuality)


end
methods(Static=true)
    PsychDefaultSetup(2);
    screenid=max(Screen('Screens'));
    PsychImaging('PrepareConfiguration')
    hmd=PsychVR

    hmd = PsychVRHMD('AutoSetupHMD', 'Monoscopic');
    PsychOculusVR1('Verbosity', 3);
    Screen('Preference','Verbosity', 3);
end
end
