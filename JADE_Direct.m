% 文件名: JADE_Direct.m
function [bestTC, bestT, bestK, bestF, TCArray] = JADE_Direct(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
    % JADE: Adaptive Differential Evolution (Direct Grouping)
    
    %% 1. JADE 专属控制参数
    p = 0.05;         
    c = 0.1;          
    mu_CR = 0.5;      
    mu_F = 0.5;       
    Archive = [];     
    lcmArray = []; % 给主循环里的函数调用提供一个空变量，防止报错
    %% 2. 基础初始化
    D = 2 * n;   
    X = rand(D, Np);             
    TC_temp = zeros(1, Np); 
    TCArray = zeros(1, Gm);  
    XArray = zeros(D, Gm);   
    
    % 计算初始种群的适应度 (直接分组，无 lcmArray)
    for i = 1:Np
        TC_temp(i) = fitness(X(:, i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n);
    end
    
    %% 3. JADE 主循环
    G = 1;
    while G <= Gm
        S_CR = []; S_F = [];  
        X_next = zeros(D, Np);
        TC_next = zeros(1, Np);
        
        [~, sorted_idx] = sort(TC_temp);
        pbest_num = max(round(p * Np), 2); 
        pbest_idx = sorted_idx(1:pbest_num);
        
        for i = 1:Np
            CR_i = mu_CR + 0.1 * randn();
            CR_i = min(max(CR_i, 0), 1); 
            
            while true
                F_i = mu_F + 0.1 * tan(pi * (rand() - 0.5));
                if F_i > 0, break; end
            end
            F_i = min(F_i, 1); 
            
            % --- 变异 ---
            idx_pbest = pbest_idx(randi(pbest_num));
            X_pbest = X(:, idx_pbest);
            
            r1 = randi(Np);
            while r1 == i, r1 = randi(Np); end
            X_r1 = X(:, r1);
            
            P_and_A = [X, Archive];
            num_P_and_A = size(P_and_A, 2);
            r2 = randi(num_P_and_A);
            while r2 == i || r2 == r1, r2 = randi(num_P_and_A); end
            X_r2 = P_and_A(:, r2);
            
            V_i = X(:, i) + F_i * (X_pbest - X(:, i)) + F_i * (X_r1 - X_r2);
            V_i(V_i > 1) = rand(); V_i(V_i < 0) = rand();  
            
            % --- 交叉 ---
            U_i = X(:, i);
            j_rand = randi(D);
            for j = 1:D
                if rand() <= CR_i || j == j_rand
                    U_i(j) = V_i(j);
                end
            end
            
            % --- 选择与存档 ---
            fit_U = fitness(U_i, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n);
            if fit_U < TC_temp(i)
                Archive = [Archive, X(:, i)];
                X_next(:, i) = U_i;
                TC_next(i) = fit_U;
                S_CR = [S_CR, CR_i];
                S_F = [S_F, F_i];
            else
                X_next(:, i) = X(:, i);
                TC_next(i) = TC_temp(i);
            end
        end
        
        if size(Archive, 2) > Np
            rand_keep = randperm(size(Archive, 2), Np);
            Archive = Archive(:, rand_keep);
        end
        
        if ~isempty(S_CR), mu_CR = (1 - c) * mu_CR + c * mean(S_CR); end
        if ~isempty(S_F)
            lehmer_mean_F = sum(S_F.^2) / sum(S_F);
            mu_F = (1 - c) * mu_F + c * lehmer_mean_F;
        end
        
        X = X_next; TC_temp = TC_next;
        [TCArray(G), ind] = min(TC_temp);
        XArray(:, G) = X(:, ind);
        G = G + 1;
    end
    best_X = XArray(:, end);
    [bestK, bestF, bestT] = decode(best_X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n);
    bestTC = TCArray(end);
end

%% --- 子函数：适应度计算 (直接分组公式) ---
function TC = fitness(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n)
    m = n; 
    Group_Idx = floor(X(1:n) * m) + 1; 
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    TC = 0; 
    for k = 1:m
        idx = find(Group_Idx == k); 
        if isempty(idx), continue; end
        f_k = F(k); 
        penalty = 0;
        if length(idx) > 1
            for i = 1:length(idx)-1
                for j = i+1:length(idx)
                    if pij(idx(i), idx(j)) > 0
                        penalty = penalty + pij(idx(i), idx(j));
                    end
                end
            end
        end
        num = S + sum(sw(idx)) + f_k * sum(sr(idx)) + penalty;
        den = sum( (hw(idx) + (hr(idx) - hw(idx)) / f_k) .* di(idx) );
        T_k = sqrt(2 * num / den);
        TC = TC + num / T_k + den * T_k / 2;
    end
end

%% --- 子函数：解码输出 ---
function [Group_Idx, F, T_dummy] = decode(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n)
    m = n;
    Group_Idx = floor(X(1:n) * m) + 1;
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    T_dummy = 0; 
end