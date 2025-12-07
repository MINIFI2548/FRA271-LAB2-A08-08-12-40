clc; clear; close all;

% =========================================================================
% 1. ส่วนกำหนดค่า
% =========================================================================
fileList = {
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\Full step ramp eact freq\fullstep-500.mat', ...
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\ramp2acc500.mat', ...
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\ramp4acc500.mat', ...
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\ramp8acc500.mat', ...
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\ramp16acc500.mat', ...
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\ramp32acc500.mat'
};

titleList = {
    'Full step', ...
    'Half step', ...
    '1/4 step', ...
    '1/8 step', ...
    '1/16 step', ...
    '1/32 step'
};

if length(fileList) ~= length(titleList)
    error('Error: จำนวนไฟล์และชื่อหัวข้อไม่เท่ากัน');
end

numFiles = length(fileList);

% =========================================================================
% 2. พารามิเตอร์
% =========================================================================
dt = 0.001; 
Fs = 1000;              
fc = 20;  
order = 4;             
Wn = fc / (Fs/2);       
[b, a] = butter(order, Wn, 'low');

% =========================================================================
% 3. เริ่มประมวลผล
% =========================================================================
for k = 1:numFiles
    currentFileName = fileList{k};
    currentTitle    = titleList{k};
    fullPath = currentFileName;
    
    try
        fprintf('Processing (%d/%d): %s ...\n', k, numFiles, currentTitle);
        
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
        
        % 1. ดึงสัญญาณ
        sigVel  = ds.getElement('Motor Angular Velocity');
        sigEN   = ds.getElement('EN');
        sigFreq = ds.getElement('Stepper Frequency');
        
        if isempty(sigVel) || isempty(sigEN) || isempty(sigFreq)
            fprintf('  Warning: Signals missing.\n');
            continue;
        end
        
        velocity = sigVel.Values.Data;
        velocity = filtfilt(b, a, velocity); % Filter
        en_signal = sigEN.Values.Data;
        frequency = sigFreq.Values.Data;
        
        % ปรับขนาดให้เท่ากัน
        min_len = min([length(velocity), length(en_signal), length(frequency)]);
        velocity  = velocity(1:min_len);
        en_signal = en_signal(1:min_len);
        frequency = frequency(1:min_len);
        
        % 2. แบ่ง Segments
        binary_en = en_signal > 0.5;
        diff_en = diff([0; binary_en]); 
        start_indices = find(diff_en == 1);
        
        % ตัดตัวสุดท้ายออก
        total_segments = length(start_indices) - 1;
        
        if total_segments < 1
            fprintf('  Not enough segments.\n');
            continue;
        end
        
        % 3. เก็บข้อมูลทุก Segment
        seg_struct = struct('vel', {}, 'freq', {}, 'peak', {}, 'index', {});
        
        for i = 1:total_segments
            idx_start = start_indices(i);
            idx_end = start_indices(i+1) - 1;
            
            s_vel  = velocity(idx_start:idx_end);
            s_freq = frequency(idx_start:idx_end);
            
            seg_struct(i).vel   = s_vel;
            seg_struct(i).freq  = s_freq;
            seg_struct(i).peak  = max(s_vel); 
            seg_struct(i).index = i;
        end
        
        % 4. เลือก 3 อันดับแรก
        [~, sortIdx] = sort([seg_struct.peak], 'descend');
        
        top3_count = min(3, total_segments);
        top3_indices = sortIdx(1:top3_count);
        top3_segments = seg_struct(top3_indices);
        
        fprintf('segments %d\n', top3_count);

        % --- แก้ไขจุดที่ Error: คำนวณ Scale โดยใช้วิธีวนลูปแทนการต่อ array ---
        y_max = -inf; y_min = inf;
        x_max = -inf; x_min = inf;
        
        for p = 1:top3_count
            % หา min/max ของแต่ละ segment แล้วเทียบกับค่า global
            y_max = max(y_max, max(top3_segments(p).vel));
            y_min = min(y_min, min(top3_segments(p).vel));
            
            x_max = max(x_max, max(top3_segments(p).freq));
            x_min = min(x_min, min(top3_segments(p).freq));
        end
        
        % เผื่อขอบบนล่าง 10%
        y_range = y_max - y_min; if y_range==0, y_range=1; end
        global_ylim = [y_min - 0.1*y_range, y_max + 0.1*y_range];
        global_xlim = [x_min, x_max];

        % 6. Plot กราฟ
        figure('Name', currentTitle, 'NumberTitle', 'off');
        
        for p = 1:top3_count
            subplot(1, 3, p);
            
            plot(top3_segments(p).freq, top3_segments(p).vel, 'LineWidth', 1.5);
            
            title(sprintf('segments %d', top3_count));
            xlabel('Frequency (Hz)');
            ylabel('Angular Velocity');
            
            xlim(global_xlim);
            ylim(global_ylim);
            grid on;
        end
        
        sgtitle([currentTitle]);
        
    catch ME
        fprintf('Error processing %s: %s\n', currentFileName, ME.message);
    end
end
fprintf('Done.\n');