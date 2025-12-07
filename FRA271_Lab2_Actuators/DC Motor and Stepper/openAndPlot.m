clc; clear; close all;

% ชื่อไฟล์
filename = 'C:\Users\Asus\OneDrive\Desktop\FRA271_Lab2_Actuators\DC Motor and Stepper\Full step ramp eact freq\fullstep-500.mat';

try
    % 1. Load ข้อมูลจากไฟล์ .mat
    loadedData = load(filename);
    
    % ตรวจสอบว่าตัวแปรชื่ออะไร (จากไฟล์ของคุณ ตัวแปรหลักน่าจะชื่อ 'data')
    if isfield(loadedData, 'data')
        ds = loadedData.data;
    else
        % ถ้าไม่ใช่ชื่อ 'data' ให้ดึงตัวแปรตัวแรกมาใช้เลย
        vars = fieldnames(loadedData);
        ds = loadedData.(vars{1});
        fprintf('Using variable: %s\n', vars{1});
    end

    % 2. ดึงข้อมูล 'Motor Angular Velocity'
    % ใช้ฟังก์ชัน getElement เพื่อค้นหาสัญญาณจากชื่อ
    targetSignalName = 'Motor Angular Velocity';
    sigElement = ds.getElement(targetSignalName);
    
    if isempty(sigElement)
        error('ไม่พบสัญญาณชื่อ "%s" ใน Dataset', targetSignalName);
    end

    % 3. แยกค่า Time และ Data
    % ข้อมูลมักจะเก็บอยู่ใน Property .Values ซึ่งเป็น timeseries object
    time = sigElement.Values.Time;
    velocity = sigElement.Values.Data;

    % 4. พล็อตกราฟ
    figure('Name', 'Motor Analysis', 'NumberTitle', 'off');
    plot(time, velocity, 'LineWidth', 1.5);
    title(['Plot: ' targetSignalName]);
    xlabel('Time (seconds)');
    ylabel('Angular Velocity');
    grid on;
    
    % ปรับแกน X ให้พอดีกับข้อมูล
    xlim([min(time) max(time)]);
    
    % แสดงสถิติเบื้องต้นใน Command Window
    fprintf('--- Statistics for %s ---\n', targetSignalName);
    fprintf('Duration: %.4f s\n', max(time));
    fprintf('Data Points: %d\n', length(velocity));
    fprintf('Max Velocity: %.4f\n', max(velocity));
    fprintf('Mean Velocity: %.4f\n', mean(velocity));

catch ME
    % กรณีเกิด Error (เช่น หาชื่อไม่เจอ)
    fprintf(2, 'Error: %s\n', ME.message);
    
    % ช่วย list รายชื่อสัญญาณที่มีอยู่จริงออกมาให้ดู
    if exist('ds', 'var')
        fprintf('\nรายชื่อสัญญาณที่มีในไฟล์:\n');
        for i = 1:ds.numElements
            elem = ds.get(i);
            fprintf('- %s\n', elem.Name);
        end
    end
end