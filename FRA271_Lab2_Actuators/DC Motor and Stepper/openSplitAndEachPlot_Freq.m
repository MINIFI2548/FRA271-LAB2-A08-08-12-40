clc; clear; close all;

% --- ตั้งค่าการแสดงผล ---
PLOT_TYPE = 1; % 1 = Subplot, 2 = Separate Figures
Filter_ON = 1; % 1 = on, 0 = off

filename = 'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\ramp4acc500.mat';

% กำหนดพารามิเตอร์ filtfilt filter
Fs = 1000;              % Sampling Frequency (Hz) - แก้เป็นค่าจริงของคุณ
fc = 20;  
% ออกแบบ Filter (Butterworth Low-pass, Order 4)
order = 4;              % ความชันของการตัดกราฟ
Wn = fc / (Fs/2);       % Normalized Frequency (Nyquist)
[b, a] = butter(order, Wn, 'low');

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
    sigVel  = ds.getElement('Motor Angular Velocity');
    sigEN   = ds.getElement('EN');
    sigFreq = ds.getElement('Stepper Frequency'); % <--- เพิ่มตรงนี้: ดึงสัญญาณ Frequency ออกมา
    
    velocity  = sigVel.Values.Data;
    if Filter_ON == 1 
        %กรองสัญญาณด้วย filtfilt (Zero-phase)
        velocity = filtfilt(b, a, velocity);
    end
    en_signal = sigEN.Values.Data;
    frequency = sigFreq.Values.Data; % <--- เพิ่มตรงนี้: เก็บค่าใส่ตัวแปร
    
    % ปรับขนาดข้อมูลทุกตัวให้เท่ากัน (ตัดส่วนเกินทิ้ง)
    min_len = min([length(velocity), length(en_signal), length(frequency)]); % <--- แก้ไขตรงนี้: เทียบความยาวรวม Frequency ด้วย
    velocity  = velocity(1:min_len);
    en_signal = en_signal(1:min_len);
    frequency = frequency(1:min_len); % <--- เพิ่มตรงนี้: ตัดขนาด Frequency ให้เท่าเพื่อน
    
    % 3. แบ่ง Segments (ใช้ Logic เดิม)
    binary_en = en_signal > 0.5;
    diff_en = diff([0; binary_en]); 
    start_indices = find(diff_en == 1);
    % num_segments = length(start_indices) - 1; % เอาทุก Segment
    num_segments = 3;
    
    fprintf('Found %d segments.\n', num_segments);

    % --- คำนวณ Scale แกน Y (Velocity) ---
    y_min = min(velocity);
    y_max = max(velocity);
    y_range = y_max - y_min;
    if y_range == 0, y_range = 1; end
    global_ylim = [y_min - 0.1*y_range, y_max + 0.1*y_range];

    % --- คำนวณ Scale แกน X (Frequency) --- 
    % <--- แก้ไขตรงนี้: เปลี่ยนจากคำนวณเวลา เป็นหาค่า Min/Max ของ Frequency ทั้งหมดแทน
    x_min = min(frequency);
    x_max = max(frequency);
    x_range = x_max - x_min;
    if x_range == 0, x_range = 1; end
    
    % เผื่อขอบซ้ายขวานิดหน่อย
    global_xlim = [x_min - 0.05*x_range, x_max + 0.05*x_range];
    
    fprintf('Global X Lim (Freq): [%.2f, %.2f]\n', global_xlim(1), global_xlim(2));

    % 4. พล็อตกราฟ
    if PLOT_TYPE == 1
        figure('Name', 'Velocity vs Frequency', 'NumberTitle', 'off');
        cols = 3;
        rows = ceil(num_segments / cols);
        
        for i = 1:num_segments
            idx_start = start_indices(i);
            if i < num_segments
                idx_end = start_indices(i+1) - 1;
            else
                idx_end = length(velocity);
            end
            
            % ตัดข้อมูลตามช่วง Segment
            seg_vel  = velocity(idx_start:idx_end);
            seg_freq = frequency(idx_start:idx_end); % <--- เพิ่มตรงนี้: ตัดข้อมูล Frequency ของช่วงนี้มาใช้
            
            subplot(rows, cols, i);
            
            % <--- แก้ไขตรงนี้: พล็อต Frequency คู่กับ Velocity
            plot(seg_freq, seg_vel, 'LineWidth', 1.2); 
            
            title(['Segment ' num2str(i)]);
            
            % กำหนด Scale
            xlim(global_xlim); % <--- ใช้ Scale ของ Frequency ที่คำนวณไว้
            ylim(global_ylim);
            
            xlabel('Stepper Frequency (Hz)'); % <--- แก้ไขตรงนี้: เปลี่ยนชื่อแกน
            ylabel('Angular Velocity');
            grid on;
        end
        
    else
        % แบบแยกหน้าต่าง
        for i = 1:num_segments
            idx_start = start_indices(i);
            if i < num_segments
                idx_end = start_indices(i+1) - 1;
            else
                idx_end = length(velocity);
            end
            
            seg_vel  = velocity(idx_start:idx_end);
            seg_freq = frequency(idx_start:idx_end); % <--- เพิ่มตรงนี้
            
            figure('Name', ['Segment ' num2str(i)], 'NumberTitle', 'off');
            plot(seg_freq, seg_vel, 'LineWidth', 1.5); % <--- แก้ไขตรงนี้
            
            title(['Segment ' num2str(i)]);
            xlim(global_xlim);
            ylim(global_ylim);
            
            xlabel('Stepper Frequency (Hz)'); % <--- แก้ไขตรงนี้
            ylabel('Angular Velocity');
            grid on;
        end
    end

catch ME
    fprintf(2, 'Error: %s\n', ME.message);
end