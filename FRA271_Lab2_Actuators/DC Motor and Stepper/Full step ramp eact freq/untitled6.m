clc; clear; close all;

% --- รายชื่อไฟล์ ---
fileIndices = 100:100:1000; % 100, 200, ..., 1000
numFiles = length(fileIndices);

% สร้างสี (Gradient)
% colors = jet(numFiles);
colors = [
    1.0  0.0  0.0;  % 1. Red
    0.0  0.0  1.0;  % 2. Blue
    0.0  0.5  0.0;  % 3. Dark Green
    0.6  0.0  0.8;  % 4. Purple
    1.0  0.5  0.0;  % 5. Orange
    0.0  0.0  0.0;  % 6. Black
    0.0  0.8  1.0;  % 7. Cyan
    0.8  0.8  0.0;  % 8. Dark Yellow
    1.0  0.0  1.0;  % 9. Magenta
    0.5  0.5  0.5   % 10. Gray
];

% พารามิเตอร์ Filter
Fs = 1000; fc = 20;
[b, a] = butter(4, fc/(Fs/2), 'low');
dt = 0.001; % Sample Time

% เตรียมตัวแปรเก็บข้อมูล
data_median = {};
data_min = {};
data_max = {};

% =========================================================================
% ส่วนที่ 1: ประมวลผลข้อมูล
% =========================================================================
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
        
        sigVel = ds.getElement('Motor Angular Velocity');
        sigEN  = ds.getElement('EN');
        
        if isempty(sigVel) || isempty(sigEN), continue; end
        
        vel = sigVel.Values.Data;
        en  = sigEN.Values.Data;
        
        % กรองสัญญาณ
        vel = filtfilt(b, a, vel);
        vel(vel < 0) = 0;
        
        min_len = min(length(vel), length(en));
        vel = vel(1:min_len);
        en = en(1:min_len);
        
        % แบ่ง Segments
        binary_en = en > 0.5;
        diff_en = diff([0; binary_en]); 
        start_indices = find(diff_en == 1);
        
        % --- แก้ไขตรงนี้: ตัด Segment สุดท้ายออกเสมอ ---
        % ถ้าเจอ 10 รอบ เราจะใช้แค่ 9 รอบแรก
        total_found = length(start_indices);
        num_segments_to_use = total_found - 1; 
        
        if num_segments_to_use < 1
            fprintf('Skipping (Not enough segments)\n');
            continue; 
        end
        
        % เก็บข้อมูลแต่ละ Segment
        segments_data = cell(num_segments_to_use, 1);
        segments_peak = zeros(num_segments_to_use, 1);
        
        for i = 1:num_segments_to_use
            idx_start = start_indices(i);
            % ไม่ต้องเช็คจบไฟล์แล้ว เพราะเราตัดตัวสุดท้ายทิ้ง
            % จุดจบคือ "ก่อนเริ่มรอบถัดไป 1 ช่อง" เสมอ
            idx_end = start_indices(i+1) - 1;
            
            seg = vel(idx_start:idx_end);
            segments_data{i} = seg;
            segments_peak(i) = max(seg);
        end
        
        % --- เรียงลำดับตามค่า Peak ---
        [sorted_peaks, sort_indices] = sort(segments_peak);
        
        % 1. หา Min (น้อยที่สุด) -> ตัวแรก
        idx_min = sort_indices(1);
        data_min{k} = segments_data{idx_min};
        
        % 2. หา Median (ตรงกลาง) -> ตัวกลาง
        mid_pos = ceil(num_segments_to_use / 2);
        idx_med = sort_indices(mid_pos);
        data_median{k} = segments_data{idx_med};
        
        % 3. หา Max (มากที่สุด) -> ตัวสุดท้าย
        idx_max = sort_indices(end);
        data_max{k} = segments_data{idx_max};
        
        fprintf('Used %d segments (Discarded last). Med Peak=%.1f\n', ...
                num_segments_to_use, sorted_peaks(mid_pos));

    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

% =========================================================================
% ส่วนที่ 2: พล็อตกราฟ 4 หน้าต่าง
% =========================================================================

% --- Figure 1: Median Peak (ตัวแทนตรงกลาง) ---
figure('Name', '1. Median Peak Segments', 'NumberTitle', 'off');
hold on;
for k = 1:numFiles
    if k <= length(data_median) && ~isempty(data_median{k})
        t = (0:length(data_median{k})-1) * dt;
        plot(t, data_median{k}, 'LineWidth', 2, 'Color', colors(k,:), ...
             'DisplayName', sprintf('%d hz/s^2', fileIndices(k)));
    end
end
title('Median Peak Segments');
xlabel('Time (s)'); ylabel('Velocity');
grid on; legend('Location', 'best');
hold off;

% --- Figure 2: Min Peak (แย่ที่สุด) ---
figure('Name', '2. Min Peak Segments', 'NumberTitle', 'off');
hold on;
for k = 1:numFiles
    if k <= length(data_min) && ~isempty(data_min{k})
        t = (0:length(data_min{k})-1) * dt;
        plot(t, data_min{k}, 'LineWidth', 1.5, 'Color', colors(k,:), ...
             'DisplayName', sprintf('%d hz/s^2', fileIndices(k)));
    end
end
title('Minimum Peak Segments (Worst Case)');
xlabel('Time (s)'); ylabel('Velocity');
grid on; legend('Location', 'best');
hold off;

% --- Figure 3: Max Peak (ดีที่สุด) ---
figure('Name', '3. Max Peak Segments', 'NumberTitle', 'off');
hold on;
for k = 1:numFiles
    if k <= length(data_max) && ~isempty(data_max{k})
        t = (0:length(data_max{k})-1) * dt;
        plot(t, data_max{k}, 'LineWidth', 1.5, 'Color', colors(k,:), ...
             'DisplayName', sprintf('%d hz/s^2', fileIndices(k)));
    end
end
title('Maximum Peak Segments (Best Case)');
xlabel('Time (s)'); ylabel('Velocity');
grid on; legend('Location', 'best');
hold off;

% --- Figure 4: Comparison (เทียบทั้ง 3 ค่า) ---
figure('Name', '4. Comparison All 3 (Envelope)', 'NumberTitle', 'off');
hold on;
for k = 1:numFiles
    if k <= length(data_median) && ~isempty(data_median{k})
        t_med = (0:length(data_median{k})-1) * dt;
        t_min = (0:length(data_min{k})-1) * dt;
        t_max = (0:length(data_max{k})-1) * dt;
        
        % Plot Min/Max (เส้นประบาง)
        plot(t_min, data_min{k}, ':', 'LineWidth', 0.8, 'Color', colors(k,:), 'HandleVisibility', 'off');
        plot(t_max, data_max{k}, '--', 'LineWidth', 0.8, 'Color', colors(k,:), 'HandleVisibility', 'off');
             
        % Plot Median (เส้นทึบหนา)
        plot(t_med, data_median{k}, '-', 'LineWidth', 2, 'Color', colors(k,:), ...
             'DisplayName', sprintf('%d hz/s^2', fileIndices(k)));
    end
end
title('Comparison: Min/Max (Dashed) vs Median (Solid)');
xlabel('Time (s)'); ylabel('Velocity');
grid on; legend('Location', 'best');
hold off;