% Test oracle copied verbatim from JADE.m; only function name changed.
function TC = Legacy_JADE(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
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
