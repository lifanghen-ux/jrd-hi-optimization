% Test oracle copied verbatim from DE.m; only function name changed.
function TC = Legacy_DE(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
    % 1. 解碼：將連續變數映射到離散整數空間
    K = floor(X(1:n) * (KSup - KInf + 1)) + KInf;
    F = floor(X(n+1:end) * (FSup - FInf + 1)) + FInf;
    
    % 2. 計算異質品懲罰成本係數 (只算上三角，避免死迴圈)
    penalty = 0;
    for i = 1:n-1
        for j = i+1:n
            if pij(i,j) > 0
                penalty = penalty + pij(i,j) / lcmArray(K(i), K(j));
            end
        end
    end
    
    % 3. 解析法推導最優基本週期 T (對應論文公式7)
    numerator = 2 * (S + sum((sw + F.*sr) ./ K) + penalty);
    denominator = sum( (hw + (hr - hw)./F) .* K .* di );
    T = sqrt(numerator / denominator);
    
    % 4. 計算五大成本模組
    Co = S / T + sum(sw ./ (K .* T));
    Chw = sum( (F - 1) .* K .* T .* di .* hw ./ (2 .* F) );
    Cd = sum( F .* sr ./ (K .* T) );
    Chr = sum( K .* T .* di .* hr ./ (2 .* F) );
    Cp = penalty / T;
    
    % 5. 輸出總成本
    TC = Co + Chw + Cd + Chr + Cp;
end

%% --- 子函數：解碼輸出 ---
