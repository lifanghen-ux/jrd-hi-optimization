% Test oracle copied verbatim from AHDE_Direct.m; only function name changed.
function TC = Legacy_AHDE_Direct(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
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
