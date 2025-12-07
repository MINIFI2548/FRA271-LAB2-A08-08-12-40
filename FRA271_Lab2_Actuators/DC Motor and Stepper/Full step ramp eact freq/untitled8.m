clc; clear; close all;

% --- รายชื่อไฟล์ ---
% สร้างตัวเลข 100, 200, ..., 1000
fileIndices = 100:100:1000; 
numFiles = length(fileIndices);

% พารามิเตอร์อื่นๆ
dt = 0.001; % Sample Time

% กำหนดพารามิเตอร์ filtfilt filter
Fs = 1000;              % Sampling Frequency (Hz) - แก้เป็นค่าจริงของคุณ
fc = 20;  
% ออกแบบ Filter (Butterworth Low-pass, Order 4)
order = 4;              % ความชันของการตัดกราฟ
Wn = fc / (Fs/2);       % Normalized Frequency (Nyquist)
[b, a] = butter(order, Wn, 'low');


% วนลูปประมวลผลทีละไฟล์
for k = 1:numFiles
    % สร้างชื่อไฟล์อัตโนมัติ เช่น fullstep-100.mat
    currentFileName = sprintf('fullstep-%d.mat', fileIndices(k));
    
    % ถ้าไฟล์มี Path นำหน้า ให้ใส่ Path ที่นี่
    % fullPath = fullfile('C:\Path\To\Your\Files', currentFileName);
    % หรือถ้าไฟล์อยู่ใน Folder ปัจจุบันอยู่แล้วก็ใช้ชื่อไฟล์ได้เลย
    fullPath = currentFileName; 
    
    try
        fprintf('Processing file: %s ...\n', currentFileName);
        
        % 1. โหลดข้อมูล
        if exist(fullPath, 'file') ~= 2
            fprintf('  Warning: File not found, skipping.\n');
            continue;
        end
        loadedData = load(fullPath);
        
        if isfield(loadedData, 'data')
            ds = loadedData.data;
        else
            vars = fieldnames(loadedData);
            ds = loadedData.(vars{1});
        end
        
        % 2. ดึงสัญญาณ
        sigVel = ds.getElement('Motor Angular Velocity');
        sigEN  = ds.getElement('EN');
        
        if isempty(sigVel) || isempty(sigEN)
            fprintf('  Warning: Signals not found in this file.\n');
            continue;
        end
        
        velocity = sigVel.Values.Data;
        velocity = filtfilt(b, a, velocity);
        en_signal = sigEN.Values.Data;
        
        % ปรับขนาดให้เท่ากัน
        min_len = min(length(velocity), length(en_signal));
        velocity = velocity(1:min_len);
        en_signal = en_signal(1:min_len);
        
        % 3. แบ่ง Segments (Rising Edge 0->1)
        binary_en = en_signal > 0.5;
        diff_en = diff([0; binary_en]); 
        start_indices = find(diff_en == 1);
        
        % ตัดตัวสุดท้ายออก (ตาม Logic เดิมของคุณ)
        num_segments = length(start_indices) - 1;
        
        if num_segments < 1
            fprintf('  No valid segments found.\n');
            continue;
        end
        
        fprintf('  Found %d segments.\n', num_segments);
        
        % --- คำนวณ Scale กลาง (Global Limits) เฉพาะไฟล์นี้ ---
        y_min = min(velocity);
        y_max = max(velocity);
        y_range = y_max - y_min;
        if y_range == 0, y_range = 1; end
        global_ylim = [y_min - 0.1*y_range, y_max + 0.1*y_range];
        
        max_duration = 0;
        for i = 1:num_segments
            idx_start = start_indices(i);
            idx_end = start_indices(i+1) - 1;
            
            current_len = idx_end - idx_start + 1;
            current_duration = (current_len - 1) * dt;
            if current_duration > max_duration
                max_duration = current_duration;
            end
        end
        global_xlim = [0, max_duration];
        
        % 4. พล็อตกราฟ (สร้าง 1 Figure ต่อ 1 ไฟล์)
        % ชื่อหน้าต่างจะบอกว่าเป็นของไฟล์ไหน
        figTitle = sprintf('%d hz/s^2 (All Segments)', fileIndices(k));
        figure('Name', figTitle, 'NumberTitle', 'off');
        
        cols = 3;
        rows = ceil(num_segments / cols);
        
        for i = 1:num_segments
            % ดึงข้อมูล
            idx_start = start_indices(i);
            idx_end = start_indices(i+1) - 1;
            
            seg_vel = velocity(idx_start:idx_end);
            seg_time_duration = (0:(length(seg_vel)-1)) * dt;
            
            subplot(rows, cols, i);
            plot(seg_time_duration, seg_vel, 'LineWidth', 1.2);
            title(['Segment ' num2str(i)]);
            
            % กำหนด Scale ให้เท่ากันทั้งหน้าต่าง
            xlim(global_xlim);
            ylim(global_ylim);
            
            xlabel('Time (s)');
            ylabel('Velocity');
            grid on;
        end
        
        % จัดระยะห่างกราฟให้สวยงาม (Optional)
        sgtitle(figTitle); % ใส่หัวข้อใหญ่ด้านบน
        
    catch ME
        fprintf('Error processing %s: %s\n', currentFileName, ME.message);
    end
end

fprintf('All files processed.\n');