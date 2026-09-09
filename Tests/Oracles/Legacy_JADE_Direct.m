% Test oracle copied verbatim from JADE_Direct.m; only function name changed.
function TC = Legacy_JADE_Direct(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n)
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
