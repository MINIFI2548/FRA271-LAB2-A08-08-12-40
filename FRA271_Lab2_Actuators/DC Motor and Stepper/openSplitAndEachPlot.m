clc; clear; close all;

% --- ตั้งค่าการแสดงผล ---
% 1 = Subplot (รวมในหน้าต่างเดียว)
% 2 = Separate Figures (แยกหน้าต่างใครมัน)
PLOT_TYPE = 1;

% ชื่อไฟล์
filename = 'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\Full step ramp eact freq\fullstep-500.mat';

try
    % 1. โหลดข้อมูล
    fprintf('Loading data...\n');
    loadedData = load(filename);
    
    if isfield(loadedData, 'data')
        ds = loadedData.data;
    else
        vars = fieldnames(loadedData);
        ds = loadedData.(vars{1});
    end

    % 2. ดึงสัญญาณ
    sigVel = ds.getElement('Motor Angular Velocity');
    sigEN  = ds.getElement('EN');
    
    velocity = sigVel.Values.Data;
    en_signal = sigEN.Values.Data;
    time = sigVel.Values.Time; % Time รวมทั้งหมด
    
    % ปรับขนาดให้เท่ากัน
    min_len = min(length(velocity), length(en_signal));
    velocity = velocity(1:min_len);
    en_signal = en_signal(1:min_len);


    % 3. แบ่ง Segments (Rising Edge 0->1)
    binary_en = en_signal > 0.5;
    diff_en = diff([0; binary_en]); 
    start_indices = find(diff_en == 1);
    num_segments = length(start_indices) - 1;
    
    fprintf('Found %d segments.\n', num_segments);

    % --- คำนวณ Scale กลาง (Global Limits) ---
    % แกน Y: ใช้ min/max ของข้อมูลทั้งหมด
    y_min = min(velocity);
    y_max = max(velocity);
    % เผื่อขอบบนล่าง 10% ให้กราฟดูสวย
    y_range = y_max - y_min;
    global_ylim = [y_min - 0.1*y_range, y_max + 0.1*y_range];

    % แกน X: ต้องวนลูปหาว่า Segment ไหนยาวนานที่สุด
    max_duration = 0;
    dt = 0.001; % Sample time (ถ้าทราบค่าแน่นอน)
    
    % Pre-calculate duration loop
    for i = 1:num_segments
        idx_start = start_indices(i);
        if i < num_segments
            idx_end = start_indices(i+1) - 1;
        else
            idx_end = length(velocity);
        end
        current_len = idx_end - idx_start + 1;
        current_duration = (current_len - 1) * dt;
        
        if current_duration > max_duration
            max_duration = current_duration;
        end
    end
    
    global_xlim = [0, max_duration];
    
    fprintf('Global Y Lim: [%.2f, %.2f]\n', global_ylim(1), global_ylim(2));
    fprintf('Global X Lim: [0, %.2f] sec\n', max_duration);

    % 4. พล็อตกราฟ
    if PLOT_TYPE == 1
        % แบบ Subplot
        figure('Name', 'All Segments', 'NumberTitle', 'off');
        % คำนวณจำนวนแถวและคอลัมน์อัตโนมัติ
        cols = 3;
        rows = ceil(num_segments / cols);
        
        for i = 1:num_segments
            % ดึงข้อมูล
            idx_start = start_indices(i);
            if i < num_segments
                idx_end = start_indices(i+1) - 1;
            else
                idx_end = length(velocity);
            end
            
            seg_vel = velocity(idx_start:idx_end);
            % สร้างแกนเวลา local (เริ่มที่ 0 วินาที)
            seg_time_duration = (0:(length(seg_vel)-1)) * dt; % สมมติ dt=0.001
            
            subplot(rows, cols, i);
            plot(seg_time_duration, seg_vel, 'LineWidth', 1.2);
            title(['Segment ' num2str(i)]);
            xlabel('Time (s)');
            % --- กำหนด Scale ตรงนี้ ---
            xlim(global_xlim);
            ylim(global_ylim);
            xlabel('Time (s)');
            ylabel('Velocity');
            grid on;
        end
        
    else
        % แบบแยกหน้าต่าง (Separate Figures)
        for i = 1:num_segments
            idx_start = start_indices(i);
            if i < num_segments
                idx_end = start_indices(i+1) - 1;
            else
                idx_end = length(velocity);
            end
            
            seg_vel = velocity(idx_start:idx_end);
            seg_time_duration = (0:(length(seg_vel)-1)) * 0.001;
            
            figure('Name', ['Segment ' num2str(i)], 'NumberTitle', 'off');
            plot(seg_time_duration, seg_vel, 'LineWidth', 1.5);
            title(['Motor Velocity - Segment ' num2str(i)]);
            % --- กำหนด Scale ตรงนี้ ---
            xlim(global_xlim);
            ylim(global_ylim);
            xlabel('Time (s)');
            ylabel('Velocity');
            grid on;
        end
    end

catch ME
    fprintf(2, 'Error: %s\n', ME.message);
end