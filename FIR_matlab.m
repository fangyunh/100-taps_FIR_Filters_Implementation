
clear; close all; clc;

N = 100;                  
f_pass = 0.2;            
f_stop = 0.23;           
freq_bands = [0 f_pass f_stop 1];
desired    = [1 1 0 0];
wstop = 10^(80/20); % Stopband weight for 80 dB attenuation
weights    = [1 wstop];      

h_unquant = firpm(N-1, freq_bands, desired, weights);

[H_unquant, w] = freqz(h_unquant, 1, 1024);

H_unquant_dB = 20*log10(abs(H_unquant));

B = 15;  % using Q15 format 31

scaling_factor = 2^B;
h_scaled       = round(h_unquant * scaling_factor);

h_scaled = min(max(h_scaled, -32768), 32767);

h_quant = h_scaled / scaling_factor;

[H_quant, wq] = freqz(h_quant, 1, 1024);
H_quant_dB = 20*log10(abs(H_quant));

B_7 = 7;  % using Q8 format

scaling_factor_7 = 2^B_7;
h_scaled_7       = round(h_unquant * scaling_factor_7);

h_scaled_7 = min(max(h_scaled_7, -32768), 32767);

h_quant_7 = h_scaled_7 / scaling_factor_7;

[H_quant_7, wq_7] = freqz(h_quant_7, 1, 1024);
H_quant_dB_7 = 20*log10(abs(H_quant_7));

figure;
hold on;
plot(w/pi, H_unquant_dB, 'DisplayName','Unquantized');
plot(wq/pi, H_quant_dB, 'DisplayName','Quantized Q15');
plot(wq_7/pi, H_quant_dB_7, 'DisplayName','Quantized Q7');
xlabel('Normalized Frequency (\times \pi rad/sample)');
ylabel('Magnitude (dB)');
title('Comparison of Unquantized vs Quantized Filter');
grid on;
legend('show');

fid = fopen('fir_coefficients.hex', 'w');

for k = 1:length(h_scaled)
    val_int16 = int16(h_scaled(k));
    val_uint16 = typecast(val_int16, 'uint16');
    fprintf(fid, '%04X\n', val_uint16);
end

fclose(fid);

