# Kalman Filter-Based Cyber-Attack Detection Scheme for Data Integrity in DC Microgrid Communications

> **Final Year Project** — Designed by **Atanda Isaac-Great** for a client of Deethunder Nexus

---

## Abstract

This project presents a comprehensive simulation and detection framework for identifying and mitigating cyber-attacks targeting data integrity in DC Microgrids. The detection scheme leverages a Kalman Filter to observe system states and analyze residuals against predicted behaviors, rapidly identifying malicious data injection or modifications.

The system is modeled in **MATLAB/Simulink**. A dynamic thresholding mechanism is used to determine if the discrepancies between the model predictions and measured data exceed a robust threshold, minimizing false positives. The automated post-processing scripts generate performance tables and publication-quality plots for the results and discussion chapter.

---

## System Architecture

The project consists of an underlying physical plant and a Kalman Filter state estimator. The DC Microgrid relies on communication networks for coordinated control. A False Data Injection (FDI) attack alters the transmitted signals, which the Kalman Filter then flags using residual thresholding.

![System Model](system/system%20_model.png)

---

## Project Structure

```
📦 DC-Microgrid-Cyber-Attack-Detection
 ├── 📄 .gitignore
 └── 📁 system/
      ├── 📄 DCMG_PhysicalPlant.slx      # Underlying Simulink physical plant model
      ├── 📄 DCMG_Kalman_Filter.slx      # Main Simulink model with integrated Attack/Kalman Filter logic
      ├── 📄 System_Build.m              # Script to build and configure the Simulink models programmatically
      ├── 📄 System_Run.m                # Batch simulation script: Calibration & Attack Injection
      ├── 📄 generate_results.m          # Automated MATLAB post-processing script for plots
      ├── 🖼️ download.jpg                # Additional asset/diagram
      └── 📁 Results/                    # Generated output folder (plots and metrics saved here)
```

---

## How It Works

### 1. Model Calibration
The simulation starts by calculating baseline noise and normal system conditions without any attack injection. The script extracts healthy residuals and dynamically calculates a detection threshold (`threshold = mean + 4*std`) to be robust against ambient voltage and current noises.

### 2. Fake Data Injection (Attack Simulation)
The Simulink model introduces configurable pulse perturbations onto the telemetry links to mimic a false data integrity attack on the communication networks (e.g., 50% duty cycle pulses on the DC Bus voltage).

### 3. State Estimation and Kalman Filtering
A Kalman Filter tracks actual system parameters continuously versus their expected values computationally. The mathematical discrepancy (residual) between the predicted system state from the physical plant equations and actual sensor readings is outputted to a logic detector.

### 4. Alert & Anomaly Detection
The detector compares the residual from the Kalman Filter against the standard robustness calibration threshold. A high logic state (Alarm) is invoked immediately if the threshold is violated.

---

## Running the Simulation

### Prerequisites
- MATLAB R2023a or later
- Simulink
- Stateflow

### Batch Simulation & Metric Generation

```matlab
% Open MATLAB, navigate to the `system` folder, then run:
System_Run
```

Runs the simulation scenarios (baseline calibration and attacked state) and generates data, before automatically launching `generate_results.m` to save:
- `Fig1_Physical_States.png` (Voltage & Current graphs)
- `Fig2_Detection_Zoomed.png` (Zoomed-in Latency view)
- `Fig3_Confusion_Matrix.png` (TP, TN, FP, FN mapping)
- `Fig4_Performance_Metrics.png` (Precision, Recall, Accuracy, FPR)
- `Fig5_Dynamic_Metrics.png`
- `Fig6_Robust_Pulse_Performance.png`

*(Note: Data tables such as `Simulation_Data.csv` and `Simulation_Workspace.mat` are ignored via `.gitignore` to preserve display clarity.)*

---

## Key Results

| Condition | Outcome |
|-----------|---------|
| Detection Latency | Immediate reaction times mapped out in short sample times (`Ts = 5e-6`), providing real-time alerting. |
| Normal State (Baseline) | ✅ Negligible false positives. System maintains robust thresholding algorithm against ambient noise (`σ_V = 0.5`, `σ_I = 0.05`). |
| Attacked State | ✅ Verified high True Positive Rate logic tracking. |

---

## Evaluated Metrics

| Metric | Description |
|------|-------------|
| **Accuracy** | Total correct predictions (Normal vs Attacked) over the total sample size. |
| **Precision** | Ratio of True Attack alarms relative to total Alarm triggers. |
| **Recall** | Percentage of actual attacks successfully detected. |
| **False Positive Rate**| Frequency of false alarms triggered by system noise or component mismatch. |

---

## Simulation Parameters

| Parameter | Value |
|-----------|-------|
| Sample Time (`Ts`) | 5e-6 s |
| Nominal DC Voltage | 250 V |
| Voltage Noise Std (`σ_v`) | 0.5 |
| Current Noise Std (`σ_i`) | 0.05 |
| Mismatch Factor | 1.10 (to test robustness) |
| Attack Amplitude | 20 V |

---

## Project Credits

This project was done by **Deethunder Nexus ventures**.

- **Website:** [www.deethundernexus.org](https://deethundernexus.org/)
- **Email:** info@deethundernexus.org

