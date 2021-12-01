% This script provides bounds and scaling factors for the design variables.
% The bounds on the joint variables are informed by experimental data.
% The bounds on the remaining variables are fixed.
% The bounds are scaled such that the upper/lower bounds cannot be
% larger/smaller than 1/-1.
%
% Author: Antoine Falisse
% Date: 12/19/2018
% Adapted: Lars D'Hondt
% Date: 01 dec 2021
%--------------------------------------------------------------------------
function [bounds,scaling] = getBounds(S,model_info)

% Kinematics file for bounds -- input arguments
IKfile_bounds = fullfile(S.subject.folder_name, S.subject.IKfile_bounds);
Qs = getIK(IKfile_bounds,model_info);

% Get the names of the coordinates
coordinate_names = fieldnames(model_info.ExtFunIO.coordi);
NMuscle = length(model_info.ExtFunIO.muscle.params.names);

%% Spline approximation of Qs to get Qdots and Qdotdots
Qs_spline.data = zeros(size(Qs.allfilt));
Qs_spline.data(:,1) = Qs.allfilt(:,1);
Qdots_spline.data = zeros(size(Qs.allfilt));
Qdots_spline.data(:,1) = Qs.allfilt(:,1);
Qdotdots_spline.data = zeros(size(Qs.allfilt));
Qdotdots_spline.data(:,1) = Qs.allfilt(:,1);
for i = 2:size(Qs.allfilt,2)
    Qs.datafiltspline(i) = spline(Qs.allfilt(:,1),Qs.allfilt(:,i));
    [Qs_spline.data(:,i),Qdots_spline.data(:,i),...
        Qdotdots_spline.data(:,i)] = ...
        SplineEval_ppuval(Qs.datafiltspline(i),Qs.allfilt(:,1),1);
end

%% get IK-besed bounds from spline
% The extreme values are selected as upper/lower bounds, which are then
% further extended.

% prepare index arrays for later use
idx_mtp = [];
idx_arms = [model_info.ExtFunIO.jointi.arm_r,model_info.ExtFunIO.jointi.arm_r];
idx_shoulder_flex = [];
idx_elbow = [];
for i = 1:length(coordinate_names)
    coordinate = coordinate_names{i};
    coord_idx = model_info.ExtFunIO.coordi.(coordinate);
    spline_idx = strcmp(Qs.colheaders(1,:),coordinate);
    % Qs
    bounds.Qs.upper(coord_idx) = max((Qs_spline.data(:,spline_idx)));
    bounds.Qs.lower(coord_idx) = min((Qs_spline.data(:,spline_idx)));
    % Qdots
    bounds.Qdots.upper(coord_idx) = max((Qdots_spline.data(:,spline_idx)));
    bounds.Qdots.lower(coord_idx) = min((Qdots_spline.data(:,spline_idx)));
    % Qdotdots
    bounds.Qdotdots.upper(coord_idx) = max((Qdotdots_spline.data(:,spline_idx)));
    bounds.Qdotdots.lower(coord_idx) = min((Qdotdots_spline.data(:,spline_idx)));

    % save indices for later use
    if contains(coordinate,'mtp')
        idx_mtp(end+1) = coord_idx;
    end
    if find(idx_arms(:)==coord_idx)
        if contains(coordinate,'elbow')
            idx_elbow(end+1) = coord_idx;
        elseif contains(coordinate,'flex')
            idx_shoulder_flex(end+1) = coord_idx;
        end
    end
end

%% extend IK-based bounds
idx_extend = [floating_base,leg_r,leg_l,torso,idx_elbow,idx_shoulder_flex];
% The bounds are extended by twice the absolute difference between upper
% and lower bounds.
Qs_range = abs(bounds.Qs.upper - bounds.Qs.lower);
bounds.Qs.lower = bounds.Qs.lower(idx_extend) - 2*Qs_range(idx_extend);
bounds.Qs.upper = bounds.Qs.upper(idx_extend) + 2*Qs_range(idx_extend);

% The bounds are extended by 3 times the absolute difference between upper
% and lower bounds.
Qdots_range = abs(bounds.Qdots.upper - bounds.Qdots.lower);
bounds.Qdots.lower = bounds.Qdots.lower - 3*Qdots_range;
bounds.Qdots.upper = bounds.Qdots.upper + 3*Qdots_range;

% The bounds are extended by 3 times the absolute difference between upper
% and lower bounds.
Qdotdots_range = abs(bounds.Qdotdots.upper - bounds.Qdotdots.lower);
bounds.Qdotdots.lower = bounds.Qdotdots.lower - 3*Qdotdots_range;
bounds.Qdotdots.upper = bounds.Qdotdots.upper + 3*Qdotdots_range;

%% manual adjustment
% For several joints, we manually adjust the bounds
% floating base tx
bounds.Qs.upper(model_info.ExtFunIO.jointi.floating_base(4)) = 2;  
bounds.Qs.lower(model_info.ExtFunIO.jointi.floating_base(4)) = 0;
% Pelvis_ty
bounds.Qs.upper(model_info.ExtFunIO.jointi.floating_base(5)) = S.subject.IG_PelvisY*1.2;
bounds.Qs.lower(model_info.ExtFunIO.jointi.floating_base(5)) = S.subject.IG_PelvisY*1.2;
% Pelvis_tz
bounds.Qs.upper(model_info.ExtFunIO.jointi.floating_base(6)) = 0.1;
bounds.Qs.lower(model_info.ExtFunIO.jointi.floating_base(6)) = -0.1;
% Elbow
bounds.Qs.lower(idxx_elbow) = 0;
% Mtp
bounds.Qs.upper(idx_mtp) = 1.05;
bounds.Qs.lower(idx_mtp) = -0.5;
bounds.Qdots.upper(idx_mtp) = 13;
bounds.Qdots.lower(idx_mtp) = -13;
bounds.Qdotdots.upper(idx_mtp) = 500;
bounds.Qdotdots.lower(idx_mtp) = -500;

% We adjust some bounds when we increase the speed to allow for the
% generation of running motions.
if S.subject.vPelvis_x_trgt > 1.33
    % Pelvis tilt
    bounds.Qs.lower(model_info.ExtFunIO.jointi.floating_base(1)) = -20*pi/180;
    % Shoulder flexion
    bounds.Qs.lower(idx_shoulder_flex) = -50*pi/180;
    % Pelvis tx
    bounds.Qdots.upper(model_info.ExtFunIO.jointi.floating_base(4)) = 4;
end

%% Muscle activations
bounds.a.lower = 0.05*ones(1,NMuscle);
bounds.a.upper = ones(1,NMuscle);

%% Muscle-tendon forces
bounds.FTtilde.lower = zeros(1,NMuscle);
bounds.FTtilde.upper = 5*ones(1,NMuscle);

%% Time derivative of muscle activations
tact = 0.015;
tdeact = 0.06;
bounds.vA.lower = (-1/100*ones(1,NMuscle))./(ones(1,NMuscle)*tdeact);
bounds.vA.upper = (1/100*ones(1,NMuscle))./(ones(1,NMuscle)*tact);

%% Time derivative of muscle-tendon forces
bounds.dFTtilde.lower = -1*ones(1,NMuscle);
bounds.dFTtilde.upper = 1*ones(1,NMuscle);

%% Arm activations
bounds.a_a.lower = -ones(1,nq.arms);
bounds.a_a.upper = ones(1,nq.arms);

%% Arm excitations
bounds.e_a.lower = -ones(1,nq.arms);
bounds.e_a.upper = ones(1,nq.arms);

%% Mtp
if strcmp(S.subject.mtp_type,'active')
    % excitations
    bounds.e_mtp.lower = -ones(1,2);
    bounds.e_mtp.upper = ones(1,2);
    % activations
    bounds.a_mtp.lower = -ones(1,2);
    bounds.a_mtp.upper = ones(1,2);
end

%% Lumbar activations
% Only used when no muscles actuate the lumbar joints (e.g. Rajagopal
% model)
bounds.a_lumbar.lower = -ones(1,nq.trunk);
bounds.a_lumbar.upper = ones(1,nq.trunk);

%% Lumbar excitations
% Only used when no muscles actuate the lumbar joints (e.g. Rajagopal
% model)
bounds.e_lumbar.lower = -ones(1,nq.trunk);
bounds.e_lumbar.upper = ones(1,nq.trunk);

%% Final time
bounds.tf.lower = 0.1;
bounds.tf.upper = 1;

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Scaling
% Qs
scaling.Qs      = max(abs(bounds.Qs.lower),abs(bounds.Qs.upper));
bounds.Qs.lower = (bounds.Qs.lower)./scaling.Qs;
bounds.Qs.upper = (bounds.Qs.upper)./scaling.Qs;
% Qdots
scaling.Qdots      = max(abs(bounds.Qdots.lower),abs(bounds.Qdots.upper));
bounds.Qdots.lower = (bounds.Qdots.lower)./scaling.Qdots;
bounds.Qdots.upper = (bounds.Qdots.upper)./scaling.Qdots;
% Qs and Qdots are intertwined
bounds.QsQdots.lower = zeros(1,2*nq.all);
bounds.QsQdots.upper = zeros(1,2*nq.all);
bounds.QsQdots.lower(1,1:2:end) = bounds.Qs.lower;
bounds.QsQdots.upper(1,1:2:end) = bounds.Qs.upper;
bounds.QsQdots.lower(1,2:2:end) = bounds.Qdots.lower;
bounds.QsQdots.upper(1,2:2:end) = bounds.Qdots.upper;
scaling.QsQdots                 = zeros(1,2*nq.all);
scaling.QsQdots(1,1:2:end)      = scaling.Qs ;
scaling.QsQdots(1,2:2:end)      = scaling.Qdots ;
% Qdotdots
scaling.Qdotdots = max(abs(bounds.Qdotdots.lower),...
    abs(bounds.Qdotdots.upper));
bounds.Qdotdots.lower = (bounds.Qdotdots.lower)./scaling.Qdotdots;
bounds.Qdotdots.upper = (bounds.Qdotdots.upper)./scaling.Qdotdots;
bounds.Qdotdots.lower(isnan(bounds.Qdotdots.lower)) = 0;
bounds.Qdotdots.upper(isnan(bounds.Qdotdots.upper)) = 0;
% Arm torque actuators
% Fixed scaling factor
scaling.ArmTau = 150;
% Fixed scaling factor
scaling.LumbarTau = 150;
% Mtp torque actuators
% Fixed scaling factor
scaling.MtpTau = 100;
% Time derivative of muscle activations
% Fixed scaling factor
scaling.vA = 100;
% Muscle activations
scaling.a = 1;
% Arm activations
scaling.a_a = 1;
% Arm excitations
scaling.e_a = 1;
% Time derivative of muscle-tendon forces
% Fixed scaling factor
scaling.dFTtilde = 100;
% Muscle-tendon forces
scaling.FTtilde         = max(...
    abs(bounds.FTtilde.lower),abs(bounds.FTtilde.upper)); 
bounds.FTtilde.lower    = (bounds.FTtilde.lower)./scaling.FTtilde;
bounds.FTtilde.upper    = (bounds.FTtilde.upper)./scaling.FTtilde;

%% Hard bounds
% We impose the initial position of pelvis_tx to be 0
bounds.QsQdots_0.lower = bounds.QsQdots.lower;
bounds.QsQdots_0.upper = bounds.QsQdots.upper;
bounds.QsQdots_0.lower(2*model_info.ExtFunIO.jointi.floating_base(4)-1) = 0;
bounds.QsQdots_0.upper(2*model_info.ExtFunIO.jointi.floating_base(4)-1) = 0;

end
