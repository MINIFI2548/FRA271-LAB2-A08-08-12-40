function split_mat_dataset(inputFile)    
    % โหลดไฟล์
    S = load(inputFile);
    
    if ~isfield(S, 'data')
        error('ไม่พบตัวแปร data');
    end
    DS = S.data;
    
    % หา index ของสัญญาณ Motor Frequency
    n = DS.numElements;
    mfIdx = -1;
    for i = 1:n
        if strcmp(DS{i}.Name, 'Motor Frequency')
            mfIdx = i;
            break;
        end
    end
    
    if mfIdx < 0
        error('ไม่พบ signal Motor Frequency');
    end
    
    % ดึง vector ของค่า Motor Frequency
    mf_values = DS{mfIdx}.Values.Data;
    
    % หา unique ค่าความถี่
    uniqueMF = unique(mf_values);
    
    % เตรียมชื่อไฟล์
    [p, name, ~] = fileparts(inputFile);
    
    % วนแยกไฟล์ตามค่าความถี่
    for u = 1:length(uniqueMF)
        val = uniqueMF(u);
    
        % index ของ sample ที่มีค่า Motor Frequency ตรงกัน
        idx = (mf_values == val);
    
        % เตรียม Dataset ใหม่
        newDS = Simulink.SimulationData.Dataset;
    
        % slice ทุก signal ตาม index เดียวกัน
        for i = 1:n
            sig = DS{i}.Values;
    
            % ถ้า signal เป็น timeseries → slice โดยรักษาเวลาและ Data
            if isa(sig, 'timeseries')
                newSig = sig;
                newSig.Time = sig.Time(idx);
                newSig.Data = sig.Data(idx,:);
            else
                error('สัญญาณไม่ใช่ timeseries ไม่สามารถ slice ได้');
            end
    
            newDS = newDS.addElement(newSig, DS{i}.Name);
        end
    
        % บันทึก
        outputName = fullfile(p, sprintf('%s_%g.mat', name, val));
    
        data = newDS;   % #ok<NASGU>
        save(outputName, 'data');
    end
end 

split_mat_dataset('test-3freqin-1file.mat');