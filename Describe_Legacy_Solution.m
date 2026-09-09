function solution = Describe_Legacy_Solution(strategy,k,f,t,data)
% Decode the returned legacy solution without changing or optimizing it.
% Direct's legacy "bestK" is GroupId; its scalar "bestT" is a placeholder.
k = k(:); f = f(:); n = data.N;
assert(numel(k)==n && numel(f)==n && all(isfinite(k)) && ...
    all(k==fix(k)) && all(isfinite(f)) && all(f==fix(f)) && ...
    all(f>=1 & f<=20),'JRD:InvalidSolution','Invalid encoded solution.');
D = data.D(:); sw = data.sw(:); sr = data.sr(:);
hw = data.hw(:); hr = data.hr(:);
if strcmp(strategy,'Direct')
    assert(all(k>=1 & k<=n),'JRD:InvalidGroup','Every item must have a valid group.');
    labels = unique(k,'stable');
    groups = cell(numel(labels),1);
    groupF = zeros(numel(labels),1);
    groupT = zeros(numel(labels),1);
    groupCost = zeros(numel(labels),1);
    canonicalId = zeros(n,1);
    for q = 1:numel(labels)
        idx = find(k==labels(q));
        groups{q} = idx(:)';
        canonicalId(idx) = q;
        % F is indexed by the ORIGINAL group label, not by item or new label.
        fk = f(labels(q));
        penaltyBlock = triu(data.p(idx,idx),1);
        penalty = sum(penaltyBlock(penaltyBlock>0));
        A = data.S + sum(sw(idx)) + fk*sum(sr(idx)) + penalty;
        B = sum(D(idx).*(hw(idx)+(hr(idx)-hw(idx))/fk));
        groupF(q) = fk;
        groupT(q) = sqrt(2*A/B);
        groupCost(q) = A/groupT(q)+B*groupT(q)/2;
    end
    solution = struct('GroupId',canonicalId,'Groups',{groups}, ...
        'GroupF',groupF,'GroupT',groupT,'GroupCost',groupCost, ...
        'GroupCount',numel(labels),'OriginalGroupId',k, ...
        'OriginalFByLabel',f,'RecomputedTC',sum(groupCost));
elseif strcmp(strategy,'Indirect')
    assert(all(k>=1 & k<=20) && isscalar(t) && isfinite(t) && t>0, ...
        'JRD:InvalidSolution','Invalid K or basic cycle.');
    penalty = 0;
    for i = 1:n-1
        for j = i+1:n
            if data.p(i,j)>0
                penalty = penalty + data.p(i,j)/lcm(k(i),k(j));
            end
        end
    end
    A = data.S + sum((sw+f.*sr)./k) + penalty;
    B = sum((hw+(hr-hw)./f).*k.*D);
    solution = struct('K',k,'F',f,'T',t,'RecomputedTC',A/t+B*t/2);
else
    error('JRD:InvalidStrategy','Unknown strategy.');
end
end
