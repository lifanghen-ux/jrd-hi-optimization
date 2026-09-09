function [bestTC,bestT,bestK,bestF,TCArray,TArray,KArray,FArray] = GA(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
% genetic algorithm for JRD-HI
% Note：all variables is created through column vector
% Input: 
%       Gm: maximal number of generation
%       Np: population size
%       other cost parameters
% Output: 
%       TCArray: array to store best cost of each generation 
%       bestTC: final best total cost
%       bestK; best replenishment multiplier K
%       bestF: best delivery multiplier F
%       bestT: best basic cycle interval
% Date: 2021.03.31
% Author: Sirui Wang
% Version: V1.0

Pc=0.8; % probability of crossover
Pm=0.1; % probability of mutation
G = 1;  % initial generation count
D = 2*n; % dimension of chromosome
X = rand(D,Np);             % generate initial population

% storage allocation
TCArray = zeros(1,Gm);  % array to store best total cost of each generation
XArray = zeros(D,Gm);   % array to store best chromosome of each generation
KArray = cell(1,Gm);    % array to store best K of each generation
FArray = cell(1,Gm);    % array to store best F of each generation
TArray = zeros(1,Gm);   % array to store best T of each generation
lcmArray = zeros(KSup, KSup);
% store least common mutiplier to avoid repeated computation
for iterLcm_1 = 1:KSup
    for iterLcm_2 = 1:KSup
        lcmArray(iterLcm_1, iterLcm_2) = lcm(iterLcm_1, iterLcm_2);
    end
end

relative_fit = zeros(1,Np);
for i = 1:Np
    relative_fit(i) = fitness(X(:,i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
end
prob = zeros(1,Np);  % probability of selection

while G <= Gm
    % calculate probability of selection
    X_last = X;
    relative_fit_last = relative_fit;
    relative_fit = 1./relative_fit;
    prob(1) = relative_fit(1)./sum(relative_fit);
    for i = 2:Np
        prob(i) = relative_fit(i)./sum(relative_fit) + prob(i-1);
    end
    %%%%%%%%%%%%%%%%%%%%%--selection--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        r = rand;
        index = 1;
        for j = 1: Np
            if r <= prob(j)
                index = j;
                break
            end
        end
        X(:,i) = X_last(:,index);
    end
    %%%%%%%%%%%%%%%%%%%%%--crossover--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        if Pc >= rand
            c = randi([1 , D - 1] , 1 , 1); % the length of crossover
            temp = randperm(Np);
            p1 = temp(1);
            p2 = temp(2);
            temp = X(1 : c, p1);
            X(1 : c, p1 ) = X(1 : c ,p2 );
            X(1 : c ,p2 ) = temp;
        end
    end
    %%%%%%%%%%%%%%%%%%%%%--mutation--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        d = randi([1 , D] ,1 ,1);
        if(rand <= Pm)
            X(d,i)=rand;
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%--calculate fitness--%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        relative_fit(i) = fitness(X(:,i),  KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    end
    %%%%%%%%%%%%%%%%%%%%%--genetic operation--%%%%%%%%%%%%%%%%%%%%%%%
    fit_selection = [relative_fit,relative_fit_last];
    [TCArray(G),temp1] = min(fit_selection); %每代最优值
    [~,temp2] = sort(fit_selection);
    temp3 = [X,X_last];
    XArray(:,G) = temp3(:,temp1); %每代最优解
    [KArray{G},FArray{G},TArray(G)] = decode(XArray(:,G),  KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    relative_fit = fit_selection(temp2(1:Np));
    X = temp3(:,temp2(1:Np));
    G = G + 1;
end
[bestTC, ind] = min(TCArray);
bestX = XArray(:,ind);
[bestK,bestF,bestT] = decode(bestX, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
end

%% --- 子函數：適應度計算 (間接分組真理公式) ---
function TC = fitness(X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray)
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