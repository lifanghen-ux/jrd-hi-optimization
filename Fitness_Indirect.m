% 文件名: Fitness_Indirect.m
function [TC, Co, Chw, Cd, Chr, Cp] = Fitness_Indirect(T, K, F, data)
    % 解包数据
    S = data.S; D = data.D; sw = data.sw; sr = data.sr;
    hw = data.hw; hr = data.hr; p = data.p; N = data.N;

    % 1. 总订货成本 Co (主订货费 + 次要订货费)
    Co = S / T + sum(sw ./ (K .* T));

    % 2. 中心仓库总库存成本 Chw
    Chw = sum( (F - 1) .* K .* T .* D .* hw ./ (2 .* F) );

    % 3. 配送成本 Cd
    Cd = sum( F .* sr ./ (K .* T) );

    % 4. 零售商总库存成本 Chr
    Chr = sum( K .* T .* D .* hr ./ (2 .* F) );

    % 5. 异质品惩罚成本 Cp
    Cp = 0;
    for i = 1:N-1
        for j = i+1:N
            if p(i,j) > 0
                % 当物品i和j同时补货时触发惩罚
                lcm_val = lcm(K(i), K(j));
                Cp = Cp + p(i,j) / (lcm_val * T);
            end
        end
    end

    % 6. 总成本 TC
    TC = Co + Chw + Cd + Chr + Cp;
end