clc; clear; close all;

%% ============================================================
% 1. INITIALIZE SYSTEM PARAMETERS
% ============================================================
Ts = 5e-6;              
Tstop = 2.0;            
Vdc_nom = 250;          

% --- REALISM PARAMETERS ---
Noise_V_Std = 0.5;      % Voltage Noise
Noise_I_Std = 0.05;     % Current Noise
Noise_V_Power = (Noise_V_Std^2) * Ts;
Noise_I_Power = (Noise_I_Std^2) * Ts;

%% ============================================================
% 2. LOAD SAVED MODEL
% ============================================================
model = 'DCMG_Kalman_Filter'; % Make sure your saved .slx matches this name

% Check if file exists before trying to run it
if ~exist([model '.slx'], 'file')
    error('Model %s.slx not found! Ensure it is in the current folder.', model);
end

% Load the model into memory silently (runs much faster than opening the GUI)
load_system(model);

%% ============================================================
% 3. RUN CALIBRATION (Healthy State)
% ============================================================
disp('1. Running Calibration...');
set_param([model '/Attack_Signal'], 'Amplitude', '0'); 

% Simulate to gather healthy noise data
simOut = sim(model, 'SaveOutput', 'on', 'SaveFormat', 'Dataset');

% Extract healthy residual and dynamically set threshold
res_calib = simOut.yout.getElement(1).Values.Data;
calib_data = res_calib(round(0.5/Ts):end);
threshold = mean(calib_data) + 4*std(calib_data); 

% Inject calculated threshold back into the model's detector logic
set_param([model '/Detector'], 'const', num2str(threshold));
disp([' -> Robust Threshold Calculated: ' num2str(threshold)]);

%% ============================================================
% 4. RUN ROBUST PULSE SIMULATION (Attacked State)
% ============================================================
disp('2. Running Robust Pulse Simulation...');
set_param([model '/Attack_Signal'], 'Amplitude', '20'); 

% Simulate with attack active
simOut = sim(model);

% Extract Data
yout = simOut.yout;
residual = yout.getElement(1).Values.Data;
alarm = double(yout.getElement(2).Values.Data);
Vdc_meas = yout.getElement(3).Values.Data; 
iL_meas  = yout.getElement(4).Values.Data;
t = (0:length(alarm)-1)' * Ts;

% GENERATE PULSE GROUND TRUTH (0.4s Period, 50% Duty Cycle)
GT_attack = (t >= 1.0) & (mod(t - 1.0, 0.40) < 0.20 - 1e-9);
GT_attack = double(GT_attack);

%% ============================================================
% 5. METRICS CALCULATION
% ============================================================
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

% ============================================================
% 6. GENERATE OUTPUT FILES
% ============================================================
disp('Simulation Complete. Generating results');

% Ensure the output generator script is in the same folder
generate_results;