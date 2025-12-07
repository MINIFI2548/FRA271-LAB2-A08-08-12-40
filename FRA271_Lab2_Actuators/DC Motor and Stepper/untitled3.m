clc; clear; close all;

% รายชื่อไฟล์ที่ต้องการนำมาพล็อต
fileList = {
    'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\Full step ramp eact freq\fullstep-500.mat', ...
    'ramp2acc500.mat', ...
    'ramp4acc500.mat', ...
    'ramp8acc500.mat', ...
    'ramp16acc500.mat', ...
    'ramp32acc500.mat'
};

% ชื่อที่จะแสดงในกราฟ (ต้องเรียงลำดับให้ตรงกับ fileList)
lableList = {
    'Full step', ...
    'Half step', ...
    '1/4 Step', ...
    '1/8 Step', ...
    '1/16 Step', ...
    '1/32 Step'
};

% กำหนดพารามิเตอร์ filtfilt filter
Fs = 1000;              % Sampling Frequency (Hz)
fc = 20;  

% ออกแบบ Filter (Butterworth Low-pass, Order 4)
order = 4;
Wn = fc / (Fs/2);
[b, a] = butter(order, Wn, 'low');

% สร้างสีสำหรับเส้นกราฟ
colors = lines(length(fileList));

figure('Name', 'Comparison Max Velocity', 'NumberTitle', 'off');
hold on;

for k = 1:length(fileList)
    filename = fileList{k};
    
    try
        % 1. โหลดข้อมูล
        fprintf('Processing %s ... ', filename);
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
        sigFreq = ds.getElement('Stepper Frequency');
        
        if isempty(sigVel) || isempty(sigEN) || isempty(sigFreq)
            fprintf('Skipping (Missing signals)\n');
            continue;
        end
        
        velocity  = sigVel.Values.Data;
        en_signal = sigEN.Values.Data;
        frequency = sigFreq.Values.Data;
        
        % กรองสัญญาณ (Filter)
        velocity = filtfilt(b, a, velocity);
        
        % --- แก้ไขจุดที่ 1: กำจัดค่าที่น้อยกว่า 0 ให้เป็น 0 ---
        velocity(velocity < 0) = 0;
        
        % ตัดข้อมูลให้เท่ากัน
        min_len = min([length(velocity), length(en_signal), length(frequency)]);
        velocity  = velocity(1:min_len);
        en_signal = en_signal(1:min_len);
        frequency = frequency(1:min_len);
        
        % 3. แบ่ง Segments
        binary_en = en_signal > 0.5;
        diff_en = diff([0; binary_en]); 
        start_indices = find(diff_en == 1);
        num_segments = length(start_indices);
        
        % 4. ค้นหา Segment ที่มีความเร็วสูงสุด (Max Peak Velocity)
        max_peak_val = -inf;
        best_seg_vel = [];
        best_seg_freq = [];
        
        for i = 1:num_segments
            idx_start = start_indices(i);
            if i < num_segments
                idx_end = start_indices(i+1) - 1;
            else
                idx_end = length(velocity);
            end
            
            % ดึงข้อมูลช่วงนี้
            seg_vel  = velocity(idx_start:idx_end);
            seg_freq = frequency(idx_start:idx_end);
            
            % หาค่าสูงสุดของช่วงนี้
            current_peak = max(seg_vel);
            
            % ถ้ามากกว่าที่เคยเจอ ให้จำไว้เป็น Best Segment
            if current_peak > max_peak_val
                max_peak_val = current_peak;
                best_seg_vel = seg_vel;
                best_seg_freq = seg_freq;
            end
        end
        
        fprintf('Max Vel = %.2f\n', max_peak_val);
        
        % 5. พล็อตกราฟ (ถ้ามีข้อมูล)
        if ~isempty(best_seg_vel)
            % จัดเรียงตามความถี่ (Optional: เพื่อให้เส้นกราฟเรียบสวย)
            [sorted_freq, sort_idx] = sort(best_seg_freq);
            sorted_vel = best_seg_vel(sort_idx);
            
            % --- แก้ไขจุดที่ 2: ใช้ lableList ใน DisplayName ---
            currentLabel = lableList{k};
            
            plot(sorted_freq, sorted_vel, 'LineWidth', 1.5, ...
                 'Color', colors(k,:), ...
                 'DisplayName', currentLabel);
        end
        
    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

title('Motor Angular Velocity vs Stepper Frequency (Max Velocity Segment)');
xlabel('Stepper Frequency (Hz)');
ylabel('Motor Angular Velocity');
legend('Location', 'best'); % ไม่ต้องใช้ Interpreter none แล้วเพราะเป็นข้อความปกติ
grid on;
hold off