% ดึงข้อมูลจาก timeseries
d_raw = data.Data;

% บีบมิติให้เหลือเวกเตอร์เดียว
d = squeeze(d_raw);

% sample freq
len_data = length(data.Time);
sample_freq = len_data / max(data.Time);

% FFT
N = length(d);
d_f = fft(d);
P2 = abs(d_f/N);               % two-sided
P1 = P2(1:N/2+1);              % one-sided
P1(2:end-1) = 2*P1(2:end-1);

freq = sample_freq*(0:(N/2))/N;

figure
plot(freq, P1);

xlabel('Frequency (Hz)');
ylabel('Amplitude');
title('One-Sided Amplitude Spectrum');
grid on;