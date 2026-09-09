% 檔名: JADE.m
function [bestTC, bestT, bestK, bestF, TCArray, TArray, KArray, FArray] = JADE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
    % JADE: Adaptive Differential Evolution with Optional External Archive
    
    %% 1. JADE 專屬控制參數
    p = 0.05;         % pbest 的比例 (取前 5% 的精英)
    c = 0.1;          % 參數自適應的學習率
    mu_CR = 0.5;      % 交叉率 CR 的初始歷史均值
    mu_F = 0.5;       % 變異率 F 的初始歷史均值
    Archive = [];     % 外部存檔 (初始化為空)
    
    %% 2. 基礎初始化
    D = 2 * n;   
    X = rand(D, Np);             
    TC_temp = zeros(1, Np); 
    
    % 預計算最小公倍數矩陣 (加速查表)
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
    
    % 計算初始種群的適應度
    for i = 1:Np
        TC_temp(i) = fitness(X(:, i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    end
    
    %% 3. JADE 主迴圈
    G = 1;
    while G <= Gm
        S_CR = []; % 存放本代成功的 CR
        S_F = [];  % 存放本代成功的 F
        
        X_next = zeros(D, Np);
        TC_next = zeros(1, Np);
        
        % 將當前種群排序，找出前 p% 的精英索引
        [~, sorted_idx] = sort(TC_temp);
        pbest_num = max(round(p * Np), 2); % 至少保留2個
        pbest_idx = sorted_idx(1:pbest_num);
        
        for i = 1:Np
            % --- 生成自適應參數 CR_i 和 F_i ---
            % CR_i 服從常態分佈 Normal(mu_CR, 0.1)
            CR_i = mu_CR + 0.1 * randn();
            CR_i = min(max(CR_i, 0), 1); % 截斷在 [0, 1]
            
            % F_i 服從柯西分佈 Cauchy(mu_F, 0.1)
            while true
                F_i = mu_F + 0.1 * tan(pi * (rand() - 0.5));
                if F_i > 0 % F_i 必須大於 0
                    break;
                end
            end
            F_i = min(F_i, 1); % 最大截斷為 1
            
            % --- Current-to-pbest/1 變異策略 ---
            % 1. 從精英中隨機選一個 X_pbest
            idx_pbest = pbest_idx(randi(pbest_num));
            X_pbest = X(:, idx_pbest);
            
            % 2. 從當前種群隨機選 X_r1 (不等於 i)
            r1 = randi(Np);
            while r1 == i
                r1 = randi(Np);
            end
            X_r1 = X(:, r1);
            
            % 3. 從 當前種群 + 外部存檔 中隨機選 X_r2 (不等於 i 和 r1)
            P_and_A = [X, Archive];
            num_P_and_A = size(P_and_A, 2);
            r2 = randi(num_P_and_A);
            while r2 == i || r2 == r1
                r2 = randi(num_P_and_A);
            end
            X_r2 = P_and_A(:, r2);
            
            % 生成變異向量 V_i
            V_i = X(:, i) + F_i * (X_pbest - X(:, i)) + F_i * (X_r1 - X_r2);
            
            % 越界處理
            V_i(V_i > 1) = rand(); 
            V_i(V_i < 0) = rand();  
            
            % --- 二項式交叉 (Binomial Crossover) ---
            U_i = X(:, i);
            j_rand = randi(D);
            for j = 1:D
                if rand() <= CR_i || j == j_rand
                    U_i(j) = V_i(j);
                end
            end
            
            % --- 選擇與存檔 (Selection & Archive) ---
            fit_U = fitness(U_i, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
            if fit_U < TC_temp(i)
                % 成功：把被淘汰的劣質父代放入外部存檔
                Archive = [Archive, X(:, i)];
                
                % 子代上位
                X_next(:, i) = U_i;
                TC_next(i) = fit_U;
                
                % 記錄成功的參數
                S_CR = [S_CR, CR_i];
                S_F = [S_F, F_i];
            else
                X_next(:, i) = X(:, i);
                TC_next(i) = TC_temp(i);
            end
        end
        
        % --- 管理外部存檔容量 ---
        if size(Archive, 2) > Np
            % 隨機剔除多餘的存檔，保持容量為 Np
            rand_keep = randperm(size(Archive, 2), Np);
            Archive = Archive(:, rand_keep);
        end
        
        % --- 更新歷史經驗均值 (mu_CR 和 mu_F) ---
        if ~isempty(S_CR)
            mu_CR = (1 - c) * mu_CR + c * mean(S_CR);
        end
        if ~isempty(S_F)
            % F 的更新使用 Lehmer mean (給予大 F 值更高的權重)
            lehmer_mean_F = sum(S_F.^2) / sum(S_F);
            mu_F = (1 - c) * mu_F + c * lehmer_mean_F;
        end
        
        % --- 記錄當代最優 ---
        X = X_next;
        TC_temp = TC_next;
        [TCArray(G), ind] = min(TC_temp);
        XArray(:, G) = X(:, ind);
        
        [KArray{G}, FArray{G}, TArray(G)] = decode(XArray(:, G), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
        
        bestTC = TCArray(G);
        G = G + 1;
    end
    
    bestK = KArray{Gm};
    bestF = FArray{Gm};
    bestT = TArray(Gm);
end

%% --- 子函數：適應度計算 (間接分組真理公式) ---
function TC = fitness(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
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
    
    Co = S / T + sum(sw ./ (K .* T));
    Chw = sum( (F - 1) .* K .* T .* di .* hw ./ (2 .* F) );
    Cd = sum( F .* sr ./ (K .* T) );
    Chr = sum( K .* T .* di .* hr ./ (2 .* F) );
    Cp = penalty / T;
    
    TC = Co + Chw + Cd + Chr + Cp;
end

%% --- 子函數：解碼輸出 ---
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