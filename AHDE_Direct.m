function [bestTC,bestT,bestK,bestF,TCArray,TArray,KArray,FArray]  = AHDE_Direct(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
% adaptive hybrid differential evolution method for JRD-HI
% Note：all variables is created through column vector
% Input: 
%       Gm: maximal number of generation
%       Np: population size
%       other cost parameters
% Output: 
%       TCArray: array to store best cost of each generation 
%       bestTC: final best total cost
%       bestK; best replenishment multiplier K
%       bestF: best delivery multiplier F
%       bestT: best basic cycle interval
% Date: 2021.03.31
% Author: Sirui Wang
% Version: V1.0

%% initialization parameters
lcmArray = []; % 给主循环里的函数调用提供一个空变量，防止报错
Fmin = 0.2 ;Fmax = 1.2;  % the bound of mutation operator
CR = 0.2;  % the probability of crossover
G = 1;     % the initial generation count
D = 2*n;   % the dimension of chromosome
X = rand(D,Np);             % generate initial population
X_next_1 = zeros(D,Np);     % temp array used in selection to store X
X_next_2 = zeros(D,Np);     % temp array used in selection to store X
f_selection = zeros(1,2*Np); % temp array used in selection to store fitness

%% storage allocation
TCArray = zeros(1,Gm);  % array to store best total cost of each generation
XArray = zeros(D,Gm);   % array to store best chromosome of each generation
KArray = cell(1,Gm);    % array to store best K of each generation
FArray = cell(1,Gm);    % array to store best F of each generation
TArray = zeros(1,Gm);   % array to store best T of each generation
%% 进入主循环
while G <= Gm
    %%%%%%%%%%%%%%%%%%%%%%%%----mutation----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        %产生j,L,p三个不同的数
        dx = randperm(Np) ;
        j = dx(1);
        L = dx(2);
        p = dx(3);
        %要保证与i不同
        if j == i
            j  = dx(4);
        elseif L == i
            L = dx(4);
        elseif p == i
            p = dx(4);
        end
        adaptOperator = exp(1-Gm/(Gm + 1-G));  % mutation operator
        F = Fmin + (Fmax - Fmin)*adaptOperator;
        X_next_1(:,i) = X(:,j) + F*(X(:,L) - X(:,p));
        X_next_1(X_next_1>1) = rand; X_next_1(X_next_1<0) = rand;  % dont exceed the bound
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%---crossover----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1: Np
        randx = randperm(D);% rand sequence of [1,2,3,...,D]
        for j = 1:D
            if rand <= CR || randx(1) ==j
                X_next_2(j,i) = X(j,i);
            else
                X_next_2(j,i) = X_next_1(j,i);
            end
        end
    end
    
    %%%%%%%%%%%%%%%%%%----selection---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        f_selection(1,i) = fitness(X_next_2(:,i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
        f_selection(1,Np+i) = fitness(X(:,i),  KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    end
    [TC_temp,idx_temp] = sort(f_selection(:));
    X_next_3 = [X_next_2,X];
    X_next = X_next_3(:,idx_temp(1:Np));
    % find the minimal total cost
    TCArray(G) = TC_temp(1);
    XArray(:,G) = X_next(:,1);
    best_X = XArray(:,G);
    [KArray{G},FArray{G},TArray(G)] = decode(best_X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    bestTC = TCArray(G);
    X = X_next;
    G = G + 1;
end
bestK = KArray{G-1};
bestF = FArray{G-1};
bestT = TArray(G-1);
end

%% --- 子函数：适应度计算 (直接分组公式) ---
function TC = fitness(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
    % 1. 解码：直接分组的染色体含义变了
    % X(1:n) 映射为物品 i 所在的组号 (范围 1 到 n)
    % X(n+1:end) 映射为该组 k 的配送频率 F_k
    m = n; % 最大允许的组数等于物品数
    Group_Idx = floor(X(1:n) * m) + 1; 
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    
    TC = 0; % 总成本初始化
    
    % 2. 按“组(篮子)”来分别计算成本
    for k = 1:m
        idx = find(Group_Idx == k); % 找出被分配到第 k 组的所有物品的索引
        
        if isempty(idx)
            continue; % 如果这个篮子是空的，直接跳过，不产生任何成本
        end
        
        f_k = F(k); % 该组的配送频率
        
        % 3. 计算该组内的异质品混装惩罚 (只要同组就惩罚，不需要算lcm)
        penalty = 0;
        if length(idx) > 1
            for i = 1:length(idx)-1
                for j = i+1:length(idx)
                    item_i = idx(i);
                    item_j = idx(j);
                    if pij(item_i, item_j) > 0
                        penalty = penalty + pij(item_i, item_j);
                    end
                end
            end
        end
        
        % 4. 解析法求该组的最优周期 T_k
        % 分子: 主要订货费 S + 组内次要订货费之和 + 组内单次配送费之和 * f_k + 惩罚
        num = S + sum(sw(idx)) + f_k * sum(sr(idx)) + penalty;
        % 分母: 组内物品的综合库存系数
        den = sum( (hw(idx) + (hr(idx) - hw(idx)) / f_k) .* di(idx) );
        
        T_k = sqrt(2 * num / den);
        
        % 5. 累加该组的总成本 (公式: 分子/T_k + 分母*T_k/2)
        TC_k = num / T_k + den * T_k / 2;
        TC = TC + TC_k;
    end
end

%% --- 子函数：解码输出 (直接分组) ---
% 注意：为了主程序兼容，这里返回的 K 实际上是 Group_Idx (物品的分组归属)
function [Group_Idx, F, T_dummy] = decode(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
    m = n;
    Group_Idx = floor(X(1:n) * m) + 1;
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    T_dummy = 0; % 直接分组有多个 T_k，不再返回单一 T，这里返回0占位
end