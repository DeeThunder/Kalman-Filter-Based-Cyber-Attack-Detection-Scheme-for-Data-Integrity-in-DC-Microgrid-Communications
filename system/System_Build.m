clc; clear; close all;
%% ============================================================
% 1. SYSTEM SETTINGS (ROBUST VALIDATION)
% ============================================================
Ts = 5e-6;              
Tstop = 2.0;            
Vdc_nom = 250;          

% --- REALISM PARAMETERS ---
Mismatch_Factor = 1.10;
Noise_V_Std = 0.5;      % Voltage Noise
Noise_I_Std = 0.05;     % Current Noise

Noise_V_Power = (Noise_V_Std^2) * Ts;
Noise_I_Power = (Noise_I_Std^2) * Ts;

%% ============================================================
% 2. KALMAN FILTER LOGIC
% ============================================================
kf_code = [
'function [est,res] = fcn(y,u)', newline, ...
'    persistent x_est P Ad Bd Cd Q Rcov', newline, ...
'    % Parameters (Imperfect Knowledge)', newline, ...
'    Mismatch = ' num2str(Mismatch_Factor) ';', newline, ...
'    L = 1.8e-3 * Mismatch;', newline, ...
'    C = 2.2e-3 / Mismatch;', newline, ...
'    R = 6.25; rL = 0.1; Ts = 5e-6;', newline, ...
'    % Matrices', newline, ...
'    Ac = [-rL/L, -1/L; 1/C, -1/(R*C)];', newline, ...
'    Bc = [1/L; 0];', newline, ...
'    % Init', newline, ...
'    if isempty(x_est)', newline, ...
'        Ad = eye(2) + Ac*Ts + (Ac^2 * Ts^2)/2;', newline, ...
'        Bd = (eye(2)*Ts + (Ac*Ts^2)/2) * Bc;', newline, ...
'        Cd = eye(2);', newline, ...
'        x_est = [0; 250];', newline, ...
'        P = eye(2);', newline, ...
'        Q = eye(2)*1e-5;', newline, ...
'        Rcov = eye(2)*0.5;', newline, ...
'    end', newline, ...
'    % Update', newline, ...
'    x_pred = Ad*x_est + Bd*u;', newline, ...
'    P_pred = Ad*P*Ad'' + Q;', newline, ...
'    K = P_pred*Cd''/(Cd*P_pred*Cd'' + Rcov);', newline, ...
'    x_est = x_pred + K*(y - Cd*x_pred);', newline, ...
'    P = (eye(2)-K*Cd)*P_pred;', newline, ...
'    est = x_est;', newline, ...
'    res = norm(y - Cd*x_pred);', newline, ...
'end'
];

%% ============================================================
% 3. BUILD MODEL
% ============================================================
model = 'DCMG_Kalman_Filter';
if bdIsLoaded(model), close_system(model,0); end
new_system(model);
open_system(model);

set_param(model, 'SolverType', 'Fixed-step', 'Solver', 'ode3', ...
    'FixedStep', num2str(Ts), 'StopTime', num2str(Tstop));

% Plant
add_block('simulink/Ports & Subsystems/Model', [model '/Plant'], ...
    'Position',[100 100 300 250], 'ModelName', 'DCMG_PhysicalPlant'); 
add_block('simulink/Signal Attributes/Signal Specification', [model '/Spec_iL'], ...
    'Position',[350 110 400 130], 'Dimensions', '1', 'DataType', 'double');
add_block('simulink/Signal Attributes/Signal Specification', [model '/Spec_Vdc'], ...
    'Position',[350 210 400 230], 'Dimensions', '1', 'DataType', 'double');

% Noise
add_block('simulink/Sources/Band-Limited White Noise', [model '/Noise_iL'], ...
    'Position', [350 50 380 80], 'Cov', num2str(Noise_I_Power), 'Ts', num2str(Ts), 'Seed', '23341');
add_block('simulink/Sources/Band-Limited White Noise', [model '/Noise_Vdc'], ...
    'Position', [350 260 380 290], 'Cov', num2str(Noise_V_Power), 'Ts', num2str(Ts), 'Seed', '9981');
add_block('simulink/Math Operations/Sum', [model '/Sum_iL'], 'Position', [450 110 470 130]);
add_block('simulink/Math Operations/Sum', [model '/Sum_Vdc'], 'Position', [450 210 470 230]);

% Kalman Filter
kf_block_path = [model '/Kalman_Filter'];
add_block('simulink/User-Defined Functions/MATLAB Function', kf_block_path, 'Position',[700 180 850 250]);
r = sfroot; chart = r.find('-isa','Stateflow.EMChart','Path',kf_block_path);
chart.Script = kf_code; chart.ChartUpdate = 'Discrete'; chart.SampleTime = num2str(Ts);
old_data = chart.find('-isa','Stateflow.Data'); for k=1:length(old_data), old_data(k).delete; end
d_y = Stateflow.Data(chart); d_y.Name='y'; d_y.Scope='Input'; d_y.Port=1; d_y.Props.Array.Size = '[2 1]'; 
d_u = Stateflow.Data(chart); d_u.Name='u'; d_u.Scope='Input'; d_u.Port=2; d_u.Props.Array.Size = '[1 1]'; 
d_est = Stateflow.Data(chart); d_est.Name='est'; d_est.Scope='Output'; d_est.Port=1; d_est.Props.Array.Size = '[2 1]';
d_res = Stateflow.Data(chart); d_res.Name='res'; d_res.Scope='Output'; d_res.Port=2; d_res.Props.Array.Size = '[1 1]';

% Wiring
add_block('simulink/Math Operations/Sum',[model '/Attack_Inj'], 'Position',[550 250 580 280],'Inputs','|++');
add_block('simulink/Sources/Pulse Generator',[model '/Attack_Signal'], ...
    'Position',[450 300 480 330]);
set_param([model '/Attack_Signal'], ...
    'PulseType', 'Time based', ...
    'Period', '0.4', ...      % 0.4s Cycle
    'PulseWidth', '50', ...   % 50% Duty Cycle (0.2s ON, 0.2s OFF)
    'PhaseDelay', '1.0', ...  % Start at 1.0s
    'Amplitude', '20');

add_block('simulink/Signal Routing/Mux',[model '/Mux'], 'Position',[600 150 610 250],'Inputs','2');
add_block('simulink/Sources/Constant',[model '/Vin_Known'], 'Position',[350 20 400 50]);
set_param([model '/Vin_Known'],'Value',num2str(Vdc_nom));

add_block('simulink/Logic and Bit Operations/Compare To Constant', [model '/Detector'],'Position',[950 200 1050 230]);
set_param([model '/Detector'],'const','0.5','relop','>');

% Connections
add_line(model, 'Plant/1', 'Spec_iL/1', 'autorouting','on');
add_line(model, 'Plant/2', 'Spec_Vdc/1', 'autorouting','on');
add_line(model, 'Spec_iL/1', 'Sum_iL/1', 'autorouting','on');
add_line(model, 'Noise_iL/1', 'Sum_iL/2', 'autorouting','on');
add_line(model, 'Spec_Vdc/1', 'Sum_Vdc/1', 'autorouting','on');
add_line(model, 'Noise_Vdc/1', 'Sum_Vdc/2', 'autorouting','on');
add_line(model, 'Sum_iL/1', 'Mux/1', 'autorouting','on');
add_line(model, 'Sum_Vdc/1', 'Attack_Inj/1', 'autorouting','on');
add_line(model, 'Attack_Signal/1', 'Attack_Inj/2', 'autorouting','on');
add_line(model, 'Attack_Inj/1', 'Mux/2', 'autorouting','on');
add_line(model, 'Mux/1', 'Kalman_Filter/1', 'autorouting','on'); 
add_line(model, 'Vin_Known/1', 'Kalman_Filter/2', 'autorouting','on'); 
add_line(model, 'Kalman_Filter/2', 'Detector/1', 'autorouting','on');

% Logging
add_block('simulink/Sinks/Out1', [model '/Res_Out'], 'Position',[950 100 980 130]); set_param([model '/Res_Out'], 'Port', '1');
add_block('simulink/Sinks/Out1', [model '/Alarm_Out'], 'Position',[1100 200 1130 230]); set_param([model '/Alarm_Out'], 'Port', '2');
add_block('simulink/Sinks/Out1', [model '/Vdc_Out'], 'Position',[1100 300 1130 330]); set_param([model '/Vdc_Out'], 'Port', '3');
add_block('simulink/Sinks/Out1', [model '/iL_Out'], 'Position',[1100 400 1130 430]); set_param([model '/iL_Out'], 'Port', '4');

add_line(model, 'Kalman_Filter/2', 'Res_Out/1', 'autorouting','on');
add_line(model, 'Detector/1', 'Alarm_Out/1', 'autorouting','on');
add_line(model, 'Attack_Inj/1', 'Vdc_Out/1', 'autorouting','on');
add_line(model, 'Sum_iL/1', 'iL_Out/1', 'autorouting','on');

%% ============================================================
% 7. RUN CALIBRATION
% ============================================================
set_param([model '/Attack_Signal'],'Amplitude','0'); 
set_param(model, 'SaveOutput', 'on', 'SaveFormat', 'Dataset');
simOut = sim(model);

yout = simOut.yout;
res_calib = yout.getElement(1).Values.Data;
calib_data = res_calib(round(0.5/Ts):end);
threshold = mean(calib_data) + 4*std(calib_data); 
set_param([model '/Detector'],'const',num2str(threshold));

%% ============================================================
% 8. RUN ROBUST PULSE SIMULATION
% ============================================================
set_param([model '/Attack_Signal'],'Amplitude','20');
simOut = sim(model);

% Extract Data
yout = simOut.yout;
residual = yout.getElement(1).Values.Data;
alarm = double(yout.getElement(2).Values.Data);
Vdc_meas = yout.getElement(3).Values.Data; 
iL_meas  = yout.getElement(4).Values.Data;
t = (0:length(alarm)-1)' * Ts;

%  GENERATE PULSE GROUND TRUTH 
GT_attack = (t >= 1.0) & (mod(t - 1.0, 0.40) < 0.20 - 1e-9);
GT_attack = double(GT_attack);

% Metrics
warmup_idx = round(0.5/Ts); 
valid_alarm = alarm(warmup_idx:end);
valid_GT = GT_attack(warmup_idx:end);

TP = sum(valid_GT==1 & valid_alarm==1);
FP = sum(valid_GT==0 & valid_alarm==1);
TN = sum(valid_GT==0 & valid_alarm==0);
FN = sum(valid_GT==1 & valid_alarm==0);

Precision = TP/(TP+FP+eps);
Recall = TP/(TP+FN+eps);
FPR = FP/(FP+TN+eps);
Accuracy = (TP+TN)/(TP+TN+FP+FN);

fprintf('\n=== ROBUST PULSE RESULTS ===\n');
fprintf('Precision: %.4f\n',Precision);
fprintf('Recall:    %.4f\n',Recall);
fprintf('FPR:       %.4f\n',FPR);
fprintf('Accuracy:  %.4f\n',Accuracy);

% Automatically run the Output Generator
generate_results;