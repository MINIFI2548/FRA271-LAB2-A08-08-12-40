clc; clear; close all;

% --- รายชื่อไฟล์ (เรียงตามลำดับที่ต้องการ) ---
fileIndices = 100:100:1000; % 100, 200, ..., 1000
numFiles = length(fileIndices);

% กำหนดพารามิเตอร์ filtfilt filter
Fs = 1000;              % Sampling Frequency (Hz) - แก้เป็นค่าจริงของคุณ
fc = 20;  
% ออกแบบ Filter (Butterworth Low-pass, Order 4)
order = 4;              % ความชันของการตัดกราฟ
Wn = fc / (Fs/2);       % Normalized Frequency (Nyquist)
[b, a] = butter(order, Wn, 'low');

% สร้างสี (Gradient)
colors = jet(numFiles);

figure('Name', 'Median Velocity vs Time', 'NumberTitle', 'off');
hold on;

% พารามิเตอร์
dt = 0.001; % Sample Time (วินาที)

for k = 1:numFiles
    filename = sprintf('fullstep-%d.mat', fileIndices(k));
    
    try
        fprintf('Processing %s ... ', filename);
        loadedData = load(filename);
        
        if isfield(loadedData, 'data')
            ds = loadedData.data;
        else
            vars = fieldnames(loadedData);
            ds = loadedData.(vars{1});
        end
        
        % ดึงข้อมูล
        sigVel = ds.getElement('Motor Angular Velocity');
        sigEN  = ds.getElement('EN');
        
        if isempty(sigVel) || isempty(sigEN), continue; end
        
        vel = sigVel.Values.Data;
        vel = filtfilt(b, a, vel);
        en  = sigEN.Values.Data;
        
        % Filter & Clean
        vel(vel < 0) = 0; % กำจัดค่าติดลบ
        
        % ตัดความยาวให้เท่ากัน
        min_len = min(length(vel), length(en));
        vel = vel(1:min_len);
        en = en(1:min_len);
        
        % --- แบ่ง Segments ---
        binary_en = en > 0.5;
        diff_en = diff([0; binary_en]); 
        start_indices = find(diff_en == 1);
        num_segments = length(start_indices);
        
        if num_segments == 0, continue; end
        
        % --- เตรียมข้อมูลสำหรับหา Median ---
        % 1. หาความยาวสูงสุดของรอบในไฟล์นี้
        max_seg_len = 0;
        segments_list = cell(num_segments, 1);
        
        for i = 1:num_segments
            idx_start = start_indices(i);
            if i < num_segments
                idx_end = start_indices(i+1) - 1;
            else
                idx_end = length(vel);
            end
            
            seg_data = vel(idx_start:idx_end);
            segments_list{i} = seg_data;
            
            if length(seg_data) > max_seg_len
                max_seg_len = length(seg_data);
            end
        end
        
        % 2. สร้าง Matrix ขนาด [max_len x num_segments]
        % เติมด้วย NaN (เพื่อให้ Median ไม่เอาช่วงที่ข้อมูลขาดไปมาคำนวณ)
        data_matrix = NaN(max_seg_len, num_segments);
        
        for i = 1:num_segments
            seg_len = length(segments_list{i});
            data_matrix(1:seg_len, i) = segments_list{i};
        end
        
        % 3. คำนวณ Median แนวนอน (Dimension 2)
        % ใช้ 'omitnan' เพื่อข้ามช่องว่าง
        median_curve = median(data_matrix, 2, 'omitnan');
        
        % สร้างแกนเวลาสำหรับเส้นนี้
        time_axis = (0:length(median_curve)-1) * dt;
        
        % --- Plot ---
        plot(time_axis, median_curve, 'LineWidth', 1.5, ...
             'Color', colors(k,:), ...
             'DisplayName', sprintf('Fullstep-%d', fileIndices(k)));
         
        fprintf('Done.\n');

    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

title('Motor Angular Velocity vs Time (Median Method)');
xlabel('Time (s)');
ylabel('Angular Velocity');
legend('Location', 'best');
grid on;
hold off;