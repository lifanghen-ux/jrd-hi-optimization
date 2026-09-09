% 文件名: ADE.m
function [bestTC, bestT, bestK, bestF, TCArray, TArray, KArray, FArray] = ADE_Direct(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
    % ---------------------------------------------------------
    % 预处理与内存分配
    % ---------------------------------------------------------
    lcmArray = []; % 给主循环里的函数调用提供一个空变量，防止报错
    Fmin = 0.2; Fmax = 1.2;  
    CR = 0.2;  
    D = 2 * n;   
    X = rand(D, Np);             
    X_next = zeros(D, Np);         
    X_next_1 = zeros(D, Np);     
    X_next_2 = zeros(D, Np);     
    TC_temp = zeros(1, Np);       
    
    TCArray = zeros(1, Gm);  
    XArray = zeros(D, Gm);   
    KArray = cell(1, Gm);    
    FArray = cell(1, Gm);    
    TArray = zeros(1, Gm);   
    
    % ---------------------------------------------------------
    % 差分进化主循环
    % ---------------------------------------------------------
    G = 1;
    while G <= Gm
        % --- 1. 变异 (Mutation) ---
        for i = 1:Np
            dx = randperm(Np);
            dx(dx == i) = []; % 剔除自身
            j = dx(1); L = dx(2); p = dx(3);
            
            adaptOperator = exp(1 - Gm/(Gm + 1 - G));  % 自适应变异算子
            MutF = Fmin + (Fmax - Fmin) * adaptOperator;
            X_next_1(:, i) = X(:, j) + MutF * (X(:, L) - X(:, p));
            
            % 越界处理
            X_next_1(X_next_1 > 1) = rand; 
            X_next_1(X_next_1 < 0) = rand;  
        end
        
        % --- 2. 交叉 (Crossover) ---
        for i = 1:Np
            randx = randperm(D);
            for j = 1:D
                if rand <= CR || randx(1) == j
                    X_next_2(j, i) = X(j, i);
                else
                    X_next_2(j, i) = X_next_1(j, i);
                end
            end
        end
        
        % --- 3. 选择 (Selection) ---
        for i = 1:Np
            fit_mutant = fitness(X_next_2(:, i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
            fit_origin = fitness(X(:, i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
            
            if fit_mutant < fit_origin
               X_next(:, i) = X_next_2(:, i);
               TC_temp(i) = fit_mutant;
            else
               X_next(:, i) = X(:, i);
               TC_temp(i) = fit_origin;
            end
        end
        
        % --- 4. 记录当代最优解 ---
        [TCArray(G), ind] = min(TC_temp);
        XArray(:, G) = X_next(:, ind);
        best_X = XArray(:, G);
        
        [KArray{G}, FArray{G}, TArray(G)] = decode(best_X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
        
        bestTC = TCArray(G);
        X = X_next;
        G = G + 1;
    end
    
    bestK = KArray{Gm};
    bestF = FArray{Gm};
    bestT = TArray(Gm);
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