% 文件名: ADE.m
function [bestTC, bestT, bestK, bestF, TCArray, TArray, KArray, FArray] = ADE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
    % ---------------------------------------------------------
    % 预处理与内存分配
    % ---------------------------------------------------------
    Fmin = 0.2; Fmax = 1.2;  
    CR = 0.2;  
    D = 2 * n;   
    X = rand(D, Np);             
    X_next = zeros(D, Np);         
    X_next_1 = zeros(D, Np);     
    X_next_2 = zeros(D, Np);     
    TC_temp = zeros(1, Np);       
    
    % 预计算最小公倍数矩阵，极大提升运算速度
    lcmArray = zeros(KSup, KSup);
    for i = 1:KSup
        for j = 1:KSup
            lcmArray(i, j) = lcm(i, j);
        end
    end
    
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

%% --- 子函数：适应度计算 (植入了我们跑通的真理公式) ---
function TC = fitness(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
    % 1. 解码：将 [0,1] 的实数映射到整数范围
    K = floor(X(1:n) * (KSup - KInf + 1)) + KInf;
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    
    % 2. 计算惩罚系数累加和
    penalty = 0;
    for i = 1:n-1
        for j = i+1:n
            if pij(i,j) > 0
                penalty = penalty + pij(i,j) / lcmArray(K(i), K(j));
            end
        end
    end
    
    % 3. 解析法求最优 T (对应论文公式7)
    numerator = 2 * (S + sum((sw + F.*sr) ./ K) + penalty);
    denominator = sum( (hw + (hr - hw)./F) .* K .* di );
    T = sqrt(numerator / denominator);
    
    % 4. 计算总成本 (与验证成功的公式完全一致)
    Co = S / T + sum(sw ./ (K .* T));
    Chw = sum( (F - 1) .* K .* T .* di .* hw ./ (2 .* F) );
    Cd = sum( F .* sr ./ (K .* T) );
    Chr = sum( K .* T .* di .* hr ./ (2 .* F) );
    Cp = penalty / T;
    
    TC = Co + Chw + Cd + Chr + Cp;
end

%% --- 子函数：解码输出 ---
function [K, F, T] = decode(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
    K = floor(X(1:n) * (KSup - KInf + 1)) + KInf;
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    
    penalty = 0;
    for i = 1:n-1
        for j = i+1:n
            if pij(i,j) > 0
                penalty = penalty + pij(i,j) / lcmArray(K(i), K(j));
            end
        end
    end
    numerator = 2 * (S + sum((sw + F.*sr) ./ K) + penalty);
    denominator = sum( (hw + (hr - hw)./F) .* K .* di );
    T = sqrt(numerator / denominator);
end