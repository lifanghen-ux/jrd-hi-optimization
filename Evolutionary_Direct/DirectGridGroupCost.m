function value = DirectGridGroupCost(items,data,options)
%DIRECTGRIDGROUPCOST Exact minimum on the configured (T,f) lattice.
% "projection" checks the two grid neighbours around the continuous
% minimizer. Convexity makes it exactly equivalent to enumerating all T.
d=NormalizeJRDData(data); items=sort(items(:)');
assert(~isempty(items)&&all(items>=1&items<=d.N&items==fix(items))&& ...
    numel(unique(items))==numel(items),'JRD:InvalidGroup','Invalid Direct group.');
f=options.FValues(:);
penaltyCoefficient=sum(sum(d.PUpper(items,items)));
fixedOrdering=d.S+sum(d.sw(items)); deliveryCoefficient=sum(d.sr(items));
warehouseBase=sum(d.D(items).*d.hw(items));
holdingDifference=sum(d.D(items).*(d.hr(items)-d.hw(items)));
A=fixedOrdering+penaltyCoefficient+f*deliveryCoefficient;
B=warehouseBase+holdingDifference./f;
assert(all(A>0)&all(B>0),'JRD:InvalidCost','Direct group has a nonpositive coefficient.');
tStar=sqrt(2*A./B); step=options.GridStep; tMin=options.TMin;
if isempty(options.TMax)
    tMax=max(tMin,ceil(max(tStar)/step)*step+step);
else
    tMax=options.TMax;
end
assert(tMax>=tMin,'JRD:GridRange','The T grid is empty.');
if strcmp(options.GridMethod,'enumerate')
    t=tMin:step:tMax;
    objective=A./t+B.*t/2;
    [cost,index]=min(objective(:));
    [fi,ti]=ind2sub(size(objective),index);
    bestF=f(fi); bestT=t(ti); candidates=numel(objective);
else
    lower=floor(tStar/step)*step;
    upper=ceil(tStar/step)*step;
    lower=min(tMax,max(tMin,lower)); upper=min(tMax,max(tMin,upper));
    cLower=A./lower+B.*lower/2; cUpper=A./upper+B.*upper/2;
    useUpper=cUpper<cLower;
    perF=cLower; perF(useUpper)=cUpper(useUpper);
    perT=lower; perT(useUpper)=upper(useUpper);
    [cost,fi]=min(perF); bestF=f(fi); bestT=perT(fi); candidates=2*numel(f);
end
ordering=fixedOrdering/bestT;
delivery=bestF*deliveryCoefficient/bestT;
warehouse=sum((bestF-1)*bestT*d.D(items).*d.hw(items)/(2*bestF));
retail=sum(bestT*d.D(items).*d.hr(items)/(2*bestF));
penalty=penaltyCoefficient/bestT;
parts=[ordering,delivery,warehouse,retail,penalty];
assert(abs(sum(parts)-cost)<=1e-10*max(1,cost),'JRD:CostMismatch', ...
    'Direct grid cost decomposition failed.');
value=struct('Cost',cost,'F',bestF,'T',bestT,'A',A(fi),'B',B(fi), ...
    'OrderingCost',ordering,'DeliveryCost',delivery, ...
    'WarehouseHoldingCost',warehouse,'RetailHoldingCost',retail, ...
    'PenaltyCost',penalty,'PenaltyCoefficient',penaltyCoefficient, ...
    'GridTMin',tMin,'GridTMax',tMax,'GridStep',step, ...
    'GridMethod',options.GridMethod,'GridCandidatesChecked',candidates);
end
