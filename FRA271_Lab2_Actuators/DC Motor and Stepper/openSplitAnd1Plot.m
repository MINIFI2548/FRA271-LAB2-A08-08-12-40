clc; clear; close all;

% ชื่อไฟล์
filename = 'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\Full step ramp eact freq\fullstep-500.mat';

try
    % 1. โหลดข้อมูล
    fprintf('Loading data from %s ...\n', filename);
    loadedData = load(filename);
    
    % ดึง Dataset (สมมติชื่อตัวแปรคือ 'data' หรือตัวแรกที่พบ)
    if isfield(loadedData, 'data')
        ds = loadedData.data;
    else
        vars = fieldnames(loadedData);
        ds = loadedData.(vars{1});
    end

    % 2. ดึงสัญญาณที่ต้องใช้ (Velocity และ EN)
    sigVel = ds.getElement('Motor Angular Velocity');
    sigEN  = ds.getElement('EN');
    
    if isempty(sigVel) || isempty(sigEN)
        error('ไม่พบสัญญาณ Motor Angular Velocity หรือ EN');
    end
    
    % ดึงค่าออกมาเป็น Array
    % ตรวจสอบว่าเวลาตรงกันไหม (โดยปกติ Simulink จะตรงกัน)
    time = sigVel.Values.Time;
    velocity = sigVel.Values.Data;
    en_signal = sigEN.Values.Data;
    
    % ตรวจสอบขนาดข้อมูลว่าเท่ากันหรือไม่
    if length(velocity) ~= length(en_signal)
        warning('ขนาดข้อมูล Velocity และ EN ไม่เท่ากัน! จะใช้ขนาดที่เล็กกว่า');
        min_len = min(length(velocity), length(en_signal));
        velocity = velocity(1:min_len);
        en_signal = en_signal(1:min_len);
        time = time(1:min_len);
    end

    % 3. หาจุดเริ่มต้นของแต่ละรอบ (Rising Edges)
    % แปลง EN เป็น 0 หรือ 1 (เผื่อค่ามาเป็นทศนิยม)
    binary_en = en_signal > 0.5;
    
    % หาตำแหน่งที่เปลี่ยนจาก 0 -> 1
    % เติม 0 ไว้ข้างหน้า 1 ตัว เพื่อให้จับจุดเริ่มต้นได้ถ้าข้อมูลเริ่มด้วย 1 เลย
    diff_en = diff([0; binary_en]); 
    start_indices = find(diff_en == 1);
    
    num_segments = length(start_indices);
    fprintf('พบข้อมูลทั้งหมด %d รอบ (Segments)\n', num_segments);

    % 4. ตัดแบ่งข้อมูลเก็บลง Cell Array
    segments = cell(num_segments, 1);
    
    figure('Name', 'Segmented Data', 'NumberTitle', 'off');
    hold on;
    colors = lines(num_segments); % สร้างสีสำหรับแยกแต่ละเส้น
    
    for i = 1:num_segments
        idx_start = start_indices(i);
        
        % จุดสิ้นสุดคือ ก่อนเริ่มรอบถัดไป 1 ช่อง
        if i < num_segments
            idx_end = start_indices(i+1) - 1;
        else
            % รอบสุดท้ายจบที่ข้อมูลตัวสุดท้าย
            idx_end = length(velocity);
        end
        
        % ดึงข้อมูลช่วงนั้นมาเก็บ
        seg_time = time(idx_start:idx_end);
        seg_vel  = velocity(idx_start:idx_end);
        seg_en   = en_signal(idx_start:idx_end);
        
        % เก็บลง struct ใน cell array
        segments{i}.Time = seg_time;
        segments{i}.Velocity = seg_vel;
        segments{i}.EN = seg_en;
        segments{i}.StartIndex = idx_start;
        segments{i}.EndIndex = idx_end;
        
        % พล็อตกราฟ (ปรับเวลาให้เริ่มที่ 0 เพื่อเปรียบเทียบรูปทรง)
        plot(seg_time - seg_time(1), seg_vel, 'Color', colors(i,:), 'DisplayName', sprintf('Set #%d', i));
    end
    
    title('Comparison of All Segments (Time Shifted to 0)');
    xlabel('Time Duration (s)');
    ylabel('Angular Velocity');
    grid on;
    % legend show; % เปิด legend ถ้ารกเกินไปให้คอมเมนต์ออก
    hold off;
    
    fprintf('ดำเนินการเสร็จสิ้น! ข้อมูลถูกเก็บในตัวแปร "segments"\n');
    fprintf('ตัวอย่าง: เข้าถึงข้อมูลชุดที่ 1 โดยใช้ segments{1}.Velocity\n');

catch ME
    fprintf(2, 'Error: %s\n', ME.message);
end