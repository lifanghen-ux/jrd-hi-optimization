% Test oracle copied verbatim from ADE.m; only function name changed.
function TC = Legacy_ADE(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
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
