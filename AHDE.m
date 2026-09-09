function [bestTC,bestT,bestK,bestF,TCArray,TArray,KArray,FArray]  = AHDE(Gm, Np, KSup, KInf, FSup, FInf, sw, di, sr, hw, hr, S, pij, n)
% adaptive hybrid differential evolution method for JRD-HI
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

%% initialization parameters
Fmin = 0.2 ;Fmax = 1.2;  % the bound of mutation operator
CR = 0.2;  % the probability of crossover
G = 1;     % the initial generation count
D = 2*n;   % the dimension of chromosome
X = rand(D,Np);             % generate initial population
X_next_1 = zeros(D,Np);     % temp array used in selection to store X
X_next_2 = zeros(D,Np);     % temp array used in selection to store X
f_selection = zeros(1,2*Np); % temp array used in selection to store fitness
lcmArray = zeros(KSup, KSup);
% store least common mutiplier to avoid repeated computation
for iterLcm_1 = 1:KSup
    for iterLcm_2 = 1:KSup
        lcmArray(iterLcm_1, iterLcm_2) = lcm(iterLcm_1, iterLcm_2);
    end
end
%% storage allocation
TCArray = zeros(1,Gm);  % array to store best total cost of each generation
XArray = zeros(D,Gm);   % array to store best chromosome of each generation
KArray = cell(1,Gm);    % array to store best K of each generation
FArray = cell(1,Gm);    % array to store best F of each generation
TArray = zeros(1,Gm);   % array to store best T of each generation
%% 进入主循环
while G <= Gm
    %%%%%%%%%%%%%%%%%%%%%%%%----mutation----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        %产生j,L,p三个不同的数
        dx = randperm(Np) ;
        j = dx(1);
        L = dx(2);
        p = dx(3);
        %要保证与i不同
        if j == i
            j  = dx(4);
        elseif L == i
            L = dx(4);
        elseif p == i
            p = dx(4);
        end
        adaptOperator = exp(1-Gm/(Gm + 1-G));  % mutation operator
        F = Fmin + (Fmax - Fmin)*adaptOperator;
        X_next_1(:,i) = X(:,j) + F*(X(:,L) - X(:,p));
        X_next_1(X_next_1>1) = rand; X_next_1(X_next_1<0) = rand;  % dont exceed the bound
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%---crossover----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1: Np
        randx = randperm(D);% rand sequence of [1,2,3,...,D]
        for j = 1:D
            if rand <= CR || randx(1) ==j
                X_next_2(j,i) = X(j,i);
            else
                X_next_2(j,i) = X_next_1(j,i);
            end
        end
    end
    
    %%%%%%%%%%%%%%%%%%----selection---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:Np
        f_selection(1,i) = fitness(X_next_2(:,i), KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
        f_selection(1,Np+i) = fitness(X(:,i),  KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    end
    [TC_temp,idx_temp] = sort(f_selection(:));
    X_next_3 = [X_next_2,X];
    X_next = X_next_3(:,idx_temp(1:Np));
    % find the minimal total cost
    TCArray(G) = TC_temp(1);
    XArray(:,G) = X_next(:,1);
    best_X = XArray(:,G);
    [KArray{G},FArray{G},TArray(G)] = decode(best_X, KInf, KSup, FInf, FSup, sw, di, sr, hw, hr, S, pij, n, lcmArray);
    bestTC = TCArray(G);
    X = X_next;
    G = G + 1;
end
bestK = KArray{G-1};
bestF = FArray{G-1};
bestT = TArray(G-1);
end

%% sub-functions 
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