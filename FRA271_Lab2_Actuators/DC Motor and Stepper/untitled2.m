clc; clear; close all;

filename = 'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\Full step ramp eact freq\fullstep-500.mat';

% 1. โหลดข้อมูลจากไฟล์
fprintf('Loading data...\n');
loadedData = load(filename);
    if isfield(loadedData, 'data')
        ds = loadedData.data;
    else
        vars = fieldnames(loadedData);
        ds = loadedData.(vars{1});
    end

% 2. ตรวจสอบชื่อตัวแปรใน Workspace (สมมติว่าชื่อตัวแปรคือ 'motor_velocity')
% ถ้าตัวแปรชื่ออื่น ให้เปลี่ยน 'motor_velocity' เป็นชื่อที่ถูกต้องจากไฟล์ของคุณ
raw_data = ds.getElement('Motor Angular Velocity').Values.Data; 

% 3. กำหนดพารามิเตอร์ (สำคัญมาก: ต้องตรงกับระบบจริงของคุณ)
Fs = 1000;              % Sampling Frequency (Hz) - แก้เป็นค่าจริงของคุณ
fc = 20;                % Cutoff Frequency (Hz) - ความถี่ที่จะเริ่มตัด Noise ออก
                        % (สำหรับ Motor Velocity มักใช้ช่วง 10-100Hz ขึ้นกับ Dynamics)

% 4. ออกแบบ Filter (Butterworth Low-pass, Order 4)
order = 4;              % ความชันของการตัดกราฟ
Wn = fc / (Fs/2);       % Normalized Frequency (Nyquist)
[b, a] = butter(order, Wn, 'low');

% 5. กรองสัญญาณด้วย filtfilt (Zero-phase)
filtered_data = filtfilt(b, a, raw_data);

% 6. พล็อตกราฟเปรียบเทียบ
t = (0:length(raw_data)-1) / Fs; % สร้างแกนเวลา
figure;
plot(t, raw_data, 'b-', 'LineWidth', 0.5); hold on;
plot(t, filtered_data, 'r-', 'LineWidth', 1.5);
legend('Raw Signal (Noisy)', 'Filtfilt Output (Zero-phase)');
xlabel('Time (s)');
ylabel('Angular Velocity');
title('Comparison of Raw vs. Zero-Phase Filtered Data');
grid on;