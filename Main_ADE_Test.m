% 文件名: Main_ADE_Test.m
clc; clear; close all;

% 1. 加载我们在第一步验证成功的绝对准确数据
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir);
load(fullfile(projectDir,'testDataN6_Paper.mat'), 'data');
rng(20260908,'twister');

% 把结构体拆解为 ADE 算法需要的独立列向量参数 (注意需转置为列向量)
n = data.N;
S = data.S;
di = data.D';   
sw = data.sw';  
sr = data.sr';  
hw = data.hw';  
hr = data.hr';  
pij = data.p;   

% 2. 算法参数设置
Gm = 500;       % 最大迭代次数
Np = 10 * n;    % 种群大小 (通常设为维度的5-10倍)
KInf = 1; KSup = 20; % 乘子K的上下界
FInf = 1; FSup = 20; % 频率F的上下界

% 3. 运行 ADE 算法
fprintf('算法开始运行，请稍候...\n');
tic; % 开始计时
[bestTC, bestT, bestK, bestF, TCArray] = ADE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n);
runTime = toc; % 结束计时

% 4. 打印寻优结果
fprintf('\n==================================================\n');
fprintf('     ADE 算法求解 JRD-HI 模型结果 (n=6)     \n');
fprintf('==================================================\n');
fprintf('★ 算法找到的最小总成本 (TC) : %10.2f \n', bestTC);
fprintf('★ 理论最优总成本 (参考标答) :    5429.26 \n');
fprintf('--------------------------------------------------\n');
fprintf('最优基本周期 T  : %f\n', bestT);
fprintf('最优补货乘子 K  : '); disp(bestK');
fprintf('最优配送频率 F  : '); disp(bestF');
fprintf('算法运行时间    : %.3f 秒\n', runTime);
fprintf('==================================================\n');

% 5. 画出收敛曲线图
figure;
plot(1:Gm, TCArray, 'LineWidth', 2, 'Color', 'b');
xlabel('迭代次数 (Generation)');
ylabel('当前最优总成本 (Total Cost)');
title('ADE 算法收敛曲线 (JRD-HI)');
grid on;
