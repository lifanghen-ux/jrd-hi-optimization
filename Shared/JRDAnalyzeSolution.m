function row=JRDAnalyzeSolution(data,answer,strategy)
% Reconciled five-part cost and conflict diagnostics for either strategy.
d=NormalizeJRDData(data); direct=strcmp(strategy,'Direct');
assert(direct||strcmp(strategy,'Indirect'),'JRD:Strategy','Unknown strategy.');
if direct
    periods=zeros(d.N,1); F=zeros(d.N,1); ids=answer.GroupId(:);
    major=0; minor=0;
    for g=1:numel(answer.Groups)
        items=answer.Groups{g}; periods(items)=answer.GroupT(g); F(items)=answer.GroupF(g);
        major=major+d.S/answer.GroupT(g);
        minor=minor+sum(d.sw(items))/answer.GroupT(g);
    end
    isolated=ids(d.PairI)~=ids(d.PairJ);
    penalty=sum(d.PairPenalty(~isolated)./periods(d.PairI(~isolated)));
    groupCount=answer.GroupCount; differentK=NaN; attenuation=NaN;
else
    K=answer.K(:); F=answer.F(:); periods=K*answer.T;
    major=d.S/answer.T; minor=sum(d.sw./periods);
    isolated=false(size(d.PairPenalty));
    penalty=sum(d.PairPenalty./lcm(K(d.PairI),K(d.PairJ)))/answer.T;
    groupCount=numel(unique(K));
    if isempty(d.PairPenalty), differentK=NaN; attenuation=NaN;
    else
        differentK=mean(K(d.PairI)~=K(d.PairJ));
        attenuation=1-sum(d.PairPenalty./lcm(K(d.PairI),K(d.PairJ)))/sum(d.PairPenalty);
    end
end
ordering=major+minor;
delivery=sum(d.sr.*F./periods);
warehouse=sum(d.D.*d.hw.*periods.*(1-1./F))/2;
retail=sum(d.D.*d.hr.*periods./F)/2;
total=ordering+delivery+warehouse+retail+penalty;
assert(abs(total-answer.TotalCost)<=1e-10*max(1,total),'JRD:CostMismatch','Five-part decomposition failed.');
if isempty(d.PairPenalty), edgeRate=NaN; weightedRate=NaN;
else
    edgeRate=mean(isolated); weightedRate=sum(d.PairPenalty(isolated))/sum(d.PairPenalty);
end
row=struct('N',d.N,'Strategy',strategy,'TotalCost',total, ...
    'OrderingCost',ordering,'MajorOrderingCost',major,'MinorOrderingCost',minor, ...
    'DeliveryCost',delivery,'WarehouseHoldingCost',warehouse, ...
    'RetailHoldingCost',retail,'PenaltyCost',penalty, ...
    'PositivePenaltyEdges',numel(d.PairPenalty),'GroupOrKClassCount',groupCount, ...
    'StrictEdgeIsolationRate',edgeRate,'WeightedEdgeIsolationRate',weightedRate, ...
    'DifferentKEdgeRate',differentK,'PenaltyCoefficientAttenuation',attenuation);
end
