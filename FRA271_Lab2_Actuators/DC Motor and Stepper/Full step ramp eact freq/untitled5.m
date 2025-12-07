clc; clear; close all;

% --- รายชื่อไฟล์ ---
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

% พารามิเตอร์
dt = 0.001; % Sample Time

% เตรียมตัวแปรเก็บข้อมูลเพื่อพล็อตรวม
all_avg_curves = {};
all_max_curves = {};
all_time_axes  = {};

% --- ส่วนที่ 1: วนลูปประมวลผลแต่ละไฟล์ ---
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
        % vel = filtfilt(b, a, vel);
        en  = sigEN.Values.Data;
        
        % Filter & Clean
        vel(vel < 0) = 0;
        
        min_len = min(length(vel), length(en));
        vel = vel(1:min_len);
        en = en(1:min_len);
        
        % แบ่ง Segments
        binary_en = en > 0.5;
        diff_en = diff([0; binary_en]); 
        start_indices = find(diff_en == 1);
        num_segments = length(start_indices);
        
        if num_segments == 0, continue; end
        
        % 1. หาความยาวสูงสุด
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
        
        % 2. สร้าง Matrix [max_len x num_segments]
        data_matrix = NaN(max_seg_len, num_segments);
        for i = 1:num_segments
            seg_len = length(segments_list{i});
            data_matrix(1:seg_len, i) = segments_list{i};
        end
        
        % 3. คำนวณ Average (Mean) และ Max
        avg_curve = mean(data_matrix, 2, 'omitnan'); % หาค่าเฉลี่ย
        max_curve = max(data_matrix, [], 2, 'omitnan'); % หาค่าสูงสุด
        
        % สร้างแกนเวลา
        time_axis = (0:length(avg_curve)-1) * dt;
        
        % เก็บข้อมูลไว้พล็อตทีหลัง
        all_avg_curves{k} = avg_curve;
        all_max_curves{k} = max_curve;
        all_time_axes{k}  = time_axis;
        
        fprintf('Done.\n');
        
    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

% --- ส่วนที่ 2: พล็อตผลลัพธ์ ---

% แบบที่ 1: กราฟรวมทุกไฟล์ (เฉพาะ Average)
figure('Name', 'Comparison Average Velocity', 'NumberTitle', 'off');
hold on;
for k = 1:numFiles
    if k <= length(all_avg_curves) && ~isempty(all_avg_curves{k})
        plot(all_time_axes{k}, all_avg_curves{k}, 'LineWidth', 2, ...
             'Color', colors(k,:), ...
             'DisplayName', sprintf('Fullstep-%d (Avg)', fileIndices(k)));
    end
end
title('Comparison of Average Velocity vs Time');
xlabel('Time (s)');
ylabel('Average Angular Velocity');
legend('Location', 'best');
grid on;
hold off;

% แบบที่ 2: กราฟรวมทุกไฟล์ (เฉพาะ Max)
figure('Name', 'Comparison Max Velocity', 'NumberTitle', 'off');
hold on;
for k = 1:numFiles
    if k <= length(all_max_curves) && ~isempty(all_max_curves{k})
        plot(all_time_axes{k}, all_max_curves{k}, 'LineWidth', 2, ...
             'Color', colors(k,:), ...
             'LineStyle', '-', ...
             'DisplayName', sprintf('Fullstep-%d (Max)', fileIndices(k)));
    end
end
title('Comparison of Max Velocity vs Time');
xlabel('Time (s)');
ylabel('Max Angular Velocity');
legend('Location', 'best');
grid on;
hold off;

% แบบที่ 3 (แถม): พล็อตแยกรายไฟล์ (Avg คู่ Max)
% จะเด้งมา 10 หน้าต่าง ถ้าไม่อยากได้คอมเมนต์ส่วนนี้ทิ้งได้ครับ
%{
for k = 1:numFiles
    if k <= length(all_avg_curves) && ~isempty(all_avg_curves{k})
        figure('Name', sprintf('File %d Detail', fileIndices(k)));
        hold on;
        % พล็อตเส้น Max จางๆ
        plot(all_time_axes{k}, all_max_curves{k}, 'r--', 'LineWidth', 1.2, 'DisplayName', 'Max Envelope');
        % พล็อตเส้น Avg หนาๆ
        plot(all_time_axes{k}, all_avg_curves{k}, 'b-', 'LineWidth', 2, 'DisplayName', 'Average');
        
        title(sprintf('Fullstep-%d: Average vs Max', fileIndices(k)));
        xlabel('Time (s)'); ylabel('Velocity');
        legend; grid on;
    end
end
%}