% 文件名: Main_Verify.m
clc; clear; close all;

% 1. 检查并加载数据
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir);
dataPath = fullfile(projectDir,'testDataN6_Paper.mat');
assert(isfile(dataPath),'JRD:MissingData','Missing dataset: %s',dataPath);
load(dataPath, 'data');

% 2. 输入论文表6和表7中给定的绝对最优解
T_opt = 0.2174;
K_opt = [1, 1, 1, 1, 4, 3];
F_opt = [5, 3, 3, 2, 5, 2];

% 3. 调用适应度函数计算各项成本
[TC, Co, Chw, Cd, Chr, Cp] = Fitness_Indirect(T_opt, K_opt, F_opt, data);

% 4. 格式化输出报告，与论文原数据对齐
fprintf('\n==================================================\n');
fprintf('     JRD-HI 模型间接分组成本验证 (n=6)     \n');
fprintf('==================================================\n');
fprintf('【各项明细成本】\n');
fprintf(' - 订货成本 (Co)      : %10.2f\n', Co);
fprintf(' - 惩罚成本 (Cp)      : %10.2f\n', Cp);
fprintf(' - 中心仓库存 (Chw)   : %10.2f\n', Chw);
fprintf(' - 配送成本 (Cd)      : %10.2f\n', Cd);
fprintf(' - 零售商库存 (Chr)   : %10.2f\n', Chr);
fprintf('--------------------------------------------------\n');
fprintf('【与论文表 6 数据对比】\n');
fprintf('补货阶段总成本 (Co+Cp): %10.2f  | 论文标答: 1745.02\n', Co + Cp);
fprintf('中心仓库总库存        : %10.2f  | 论文标答: 2371.56\n', Chw);
fprintf('配送阶段总成本 (Cd)   : %10.2f  | 论文标答:  343.07\n', Cd);
fprintf('零售商总库存   (Chr)  : %10.2f  | 论文标答:  969.61\n', Chr);
fprintf('--------------------------------------------------\n');
fprintf('★ 计算总成本 (TC)    : %10.2f  | 论文标答: 5429.26\n', TC);
fprintf('==================================================\n');
