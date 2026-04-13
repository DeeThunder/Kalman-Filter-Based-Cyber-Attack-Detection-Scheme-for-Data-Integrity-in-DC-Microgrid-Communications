%% ============================================================
% (Run this AFTER the simulation is complete)
% ============================================================

% 1. Create Results Folder
folderName = 'Results';
mkdir(folderName);
disp(['Created output folder: ' folderName]);

% 2. Safety Check: Load Data
if ~exist('t','var') || ~exist('residual','var')
    error('CRITICAL: No simulation data found. Please run the Main Simulation Script first.');
end

% 3. Check Threshold
if ~exist('threshold','var')
    threshold = 8.7557; % Fallback
end

% ============================================================
% A. CALCULATE LATENCY (First Pulse Only)
% ============================================================
disp('Calculating Detection Latency...');
attack_start_idx = find(GT_attack == 1, 1);
if ~isempty(attack_start_idx)
    detect_offset = find(alarm(attack_start_idx:end) == 1, 1);
    if ~isempty(detect_offset)
        detect_idx = attack_start_idx + detect_offset - 1;
        Latency = t(detect_idx) - t(attack_start_idx);
        fprintf(' -> Detection Latency: %.6f seconds\n', Latency);
    else
        Latency = NaN;
    end
else
    Latency = NaN;
end

% ============================================================
% B. EXPORT DATA
% ============================================================
disp('Exporting Data...');
SimData = table(t, Vdc_meas, iL_meas, residual, alarm, GT_attack, ...
    'VariableNames', {'Time', 'Vdc', 'iL', 'Residual', 'Alarm', 'GroundTruth'});
writetable(SimData, fullfile(folderName, 'Simulation_Data.csv'));
save(fullfile(folderName, 'Simulation_Workspace.mat'));

% ============================================================
% C. GENERATE FIGURES
% ============================================================
disp('Generating Figures...');

% --- FIG 1: SYSTEM STATES ---
f1 = figure('Name', 'System_States', 'Color', 'w', 'Position', [100 100 900 600]);
subplot(2,1,1); plot(t, Vdc_meas, 'Color', [0 0.4470 0.7410]); 
title('DC Bus Voltage', 'FontSize', 12, 'FontWeight', 'bold'); grid on; xlim([0 Tstop]);
subplot(2,1,2); plot(t, iL_meas, 'Color', [0.8500 0.3250 0.0980]); 
title('Inductor Current', 'FontSize', 12, 'FontWeight', 'bold'); grid on; xlim([0 Tstop]);
saveas(f1, fullfile(folderName, 'Fig1_Physical_States.png'));

% --- FIG 2: ZOOMED DETECTION (Show Latency) ---
f2 = figure('Name', 'Detection_Zoom', 'Color', 'w', 'Position', [150 150 900 600]);
subplot(2,1,1); plot(t, residual, 'Color', [0.4940 0.1840 0.5560]); hold on;
yline(threshold, 'r--', 'LineWidth', 2);
title('Residual (Zoomed on First Attack)', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0.9 1.3]); grid on; % Zoom to see latency
subplot(2,1,2); area(t, GT_attack, 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none'); hold on;
plot(t, alarm, 'r', 'LineWidth', 1.5);
title('Logic State (Zoomed)', 'FontSize', 12, 'FontWeight', 'bold');
ylim([-0.1 1.1]); xlim([0.9 1.3]); grid on;
saveas(f2, fullfile(folderName, 'Fig2_Detection_Zoomed.png'));

% --- FIG 3: CONFUSION MATRIX ---
f3 = figure('Name', 'Confusion_Matrix', 'Color', 'w', 'Position', [200 200 500 450]);
C = [TP, FP; FN, TN];
imagesc(C); 
colormap(flipud(gray)); 

% Add Numeric Text to Cells
textStrings = num2str(C(:), '%d'); 
textStrings = strtrim(cellstr(textStrings)); 
[x, y] = meshgrid(1:2); 
text(x(:), y(:), textStrings(:), 'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'Color', 'r', 'FontWeight', 'bold');
set(gca, 'XTick', 1:2, 'YTick', 1:2, ... % Centers ticks at 1 and 2
         'XTickLabel', {'Attack', 'Normal'}, ...
         'YTickLabel', {'Attack', 'Normal'}, ...
         'TickLength', [0 0]); % Removes the little tick lines for a cleaner look

% Add Axis Titles for Clarity
xlabel('Predicted Class', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Actual Class', 'FontSize', 12, 'FontWeight', 'bold');
title(['Confusion Matrix (Accuracy: ' num2str(Accuracy*100, '%.2f') '%)'], 'FontSize', 13);

axis square;
saveas(f3, fullfile(folderName, 'Fig3_Confusion_Matrix.png'));

% --- FIG 4: METRICS BAR CHART ---
f4 = figure('Name', 'Performance_Metrics', 'Color', 'w', 'Position', [250 250 600 500]);
metrics_data = [Precision, Recall, Accuracy, FPR] * 100; 
b = bar(metrics_data, 'FaceColor', 'flat');
b.CData(1,:) = [0 0.4470 0.7410]; b.CData(2,:) = [0.8500 0.3250 0.0980]; 
b.CData(3,:) = [0.9290 0.6940 0.1250]; b.CData(4,:) = [0.6350 0.0780 0.1840]; 
xticklabels({'Precision', 'Recall', 'Accuracy', 'FPR'});
title('System Performance Metrics', 'FontSize', 14, 'FontWeight', 'bold');
ylim([0 110]); grid on;
for i = 1:length(metrics_data)
    text(i, metrics_data(i) + 2, sprintf('%.2f%%', metrics_data(i)), 'HorizontalAlignment', 'center', 'FontSize', 12);
end
saveas(f4, fullfile(folderName, 'Fig4_Performance_Metrics.png'));

% --- FIG 5: DYNAMIC METRICS OVER TIME ---
is_TP = (GT_attack == 1) & (alarm == 1);
is_FP = (GT_attack == 0) & (alarm == 1);
is_TN = (GT_attack == 0) & (alarm == 0);
is_FN = (GT_attack == 1) & (alarm == 0);
cum_TP = cumsum(is_TP); cum_FP = cumsum(is_FP); cum_TN = cumsum(is_TN); cum_FN = cumsum(is_FN);
eps_val = 1e-9;
Run_Pre = cum_TP ./ (cum_TP + cum_FP + eps_val);
Run_Rec = cum_TP ./ (cum_TP + cum_FN + eps_val);
Run_FPR = cum_FP ./ (cum_FP + cum_TN + eps_val);
Run_Acc = (cum_TP + cum_TN) ./ (cum_TP + cum_TN + cum_FP + cum_FN + eps_val);

f5 = figure('Name', 'Running_Metrics', 'Color', 'w', 'Position', [100 100 1000 700]);
sgtitle('Dynamic Performance Over Time', 'FontSize', 16);
subplot(2,2,1); plot(t, Run_Pre, 'b', 'LineWidth', 2); title('Running Precision'); grid on; ylim([-0.1 1.1]);
subplot(2,2,2); plot(t, Run_Rec, 'g', 'LineWidth', 2); title('Running Recall'); grid on; ylim([-0.1 1.1]);
subplot(2,2,3); plot(t, Run_FPR, 'r', 'LineWidth', 2); title('Running FPR'); grid on; ylim([-0.1 1.1]);
subplot(2,2,4); plot(t, Run_Acc, 'y', 'LineWidth', 2); title('Running Accuracy'); grid on; ylim([-0.1 1.1]);
saveas(f5, fullfile(folderName, 'Fig5_Dynamic_Metrics.png'));

% --- FIG 6: ROBUST PULSE PERFORMANCE---
f6 = figure('Name','Robust_Pulse_Check', 'Color', 'w', 'Position', [300 300 900 600]);

subplot(2,1,1); 
plot(t, residual, 'Color', [0.2 0.2 0.2]); hold on; 
yline(threshold, 'r--', 'LineWidth', 2, 'Label', 'Threshold');
title('Residual Signal (Full Simulation)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Residual Magnitude'); grid on; xlim([0 Tstop]);

subplot(2,1,2); 
% Plot Alarm
plot(t, alarm, 'r', 'LineWidth', 1.5, 'DisplayName', 'Alarm'); hold on;
% Plot Ground Truth (Dashed Blue)
plot(t, GT_attack, 'b--', 'LineWidth', 1.5, 'DisplayName', 'True Attack Pulse');
title('Detection vs Ground Truth (Robustness Check)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('State (0/1)'); xlabel('Time (s)');
ylim([-0.1 1.1]); xlim([0 Tstop]); 
legend('Location', 'best'); grid on;

saveas(f6, fullfile(folderName, 'Fig6_Robust_Pulse_Performance.png'));

disp('------------------------------------------------');
disp(' SUCCESS! All 6 figures saved.');
disp([' Output Folder: ' fullfile(pwd, folderName)]);
disp('------------------------------------------------');