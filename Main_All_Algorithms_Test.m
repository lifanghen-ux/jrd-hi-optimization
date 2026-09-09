% 文件名: Main_All_Algorithms_Test.m
clc; clear; close all;

% 1. 加载我们在第一步验证成功的绝对准确数据
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir);
load(fullfile(projectDir,'testDataN6_Paper.mat'), 'data');
rng(20260908,'twister');

% 把结构体拆解为算法需要的独立列向量参数
n = data.N; 
S = data.S; 
di = data.D';   
sw = data.sw';  
sr = data.sr';  
hw = data.hw';  
hr = data.hr';  
pij = data.p;   

% 2. 算法通用参数设置
Gm = 500;       % 最大迭代次数
Np = 10 * n;    % 种群大小
KInf = 1; KSup = 20; % 乘子K的上下界
FInf = 1; FSup = 20; % 频率F的上下界

fprintf('======================================================\n');
fprintf('正在进行四大算法争霸赛 (间接分组验证)，请稍候...\n');
fprintf('======================================================\n\n');

% 3. 依次运行四个算法并记录时间和收敛曲线
% --- 运行 ADE ---
fprintf('正在运行 ADE 算法...\n');
tic;
[TC_ADE, T_ADE, K_ADE, F_ADE, curve_ADE] = ADE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n);
time_ADE = toc;

% --- 运行 AHDE ---
fprintf('正在运行 AHDE 算法...\n');
tic;
[TC_AHDE, T_AHDE, K_AHDE, F_AHDE, curve_AHDE] = AHDE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n);
time_AHDE = toc;

% --- 运行 GA ---
fprintf('正在运行 GA 算法...\n');
tic;
[TC_GA, T_GA, K_GA, F_GA, curve_GA] = GA(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n);
time_GA = toc;

% --- 运行 DE ---
fprintf('正在运行 DE 算法...\n');
tic;
[TC_DE, T_DE, K_DE, F_DE, curve_DE] = DE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n);
time_DE = toc;

% 4. 打印战报表
fprintf('\n======================================================\n');
fprintf('     四大启发式算法 JRD-HI 间接分组跑分结果 (n=6)     \n');
fprintf('======================================================\n');
fprintf('算法\t\t最优总成本\t\t求解时间(秒)\t\t找到的最优T\n');
fprintf('------------------------------------------------------\n');
fprintf('ADE \t\t%.2f \t\t%.3f \t\t\t%.4f\n', TC_ADE, time_ADE, T_ADE);
fprintf('AHDE\t\t%.2f \t\t%.3f \t\t\t%.4f\n', TC_AHDE, time_AHDE, T_AHDE);
fprintf('GA  \t\t%.2f \t\t%.3f \t\t\t%.4f\n', TC_GA, time_GA, T_GA);
fprintf('DE  \t\t%.2f \t\t%.3f \t\t\t%.4f\n', TC_DE, time_DE, T_DE);
fprintf('------------------------------------------------------\n');
fprintf('理论标答:\t5429.26 \t\t - \t\t\t0.2174\n');
fprintf('======================================================\n');

% 5. 绘制所有算法的对比收敛曲线
figure('Name', '四种算法收敛性能对比', 'Position', [100, 100, 800, 500]);
plot(1:Gm, curve_ADE, 'LineWidth', 2, 'Color', 'b'); hold on;
plot(1:Gm, curve_AHDE, 'LineWidth', 2, 'Color', 'r');
plot(1:Gm, curve_GA, 'LineWidth', 2, 'Color', 'g');
plot(1:Gm, curve_DE, 'LineWidth', 2, 'Color', 'k');
xlabel('迭代次数 (Generation)', 'FontSize', 12);
ylabel('当前最优总成本 (Total Cost)', 'FontSize', 12);
title('不同启发式算法在 JRD-HI 模型上的收敛曲线对比', 'FontSize', 14);
legend('ADE', 'AHDE', 'GA', 'DE', 'FontSize', 11);
grid on;
