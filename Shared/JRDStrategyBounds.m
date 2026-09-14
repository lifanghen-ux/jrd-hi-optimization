function bounds=JRDStrategyBounds(data)
% Common rigorous relaxation: discard S and nonnegative pair penalties,
% apply Cauchy-Schwarz, then minimize each item's F independently.
% Valid for both strategies, including hr<hw, under NormalizeJRDData bounds.
d=NormalizeJRDData(data); f=d.FInf:d.FSup;
a=d.sw+d.sr.*f; b=d.D.*(d.hw+(d.hr-d.hw)./f);
lower=sum(min(sqrt(2*a.*b),[],2));
bounds=struct('DirectLowerBound',lower,'IndirectLowerBound',lower, ...
    'Method','drop setup and pair penalty; Cauchy-Schwarz; independent bounded F', ...
    'DirectExact',[],'IndirectExact',[], ...
    'Meaning','relaxation bound, potentially loose; floating-point arithmetic');
% Bounded state-count eligibility, not a search-time cutoff. Exact work is
% either fully completed or not attempted. Never feed answers to heuristics.
if d.N<=10, bounds.DirectExact=ExactDP_Direct(d); end
base=d.KSup-d.KInf+1;
if d.N*log(max(1,base))<=log(100000)
    best=[]; states=base^d.N;
    for code=0:states-1
        q=code; K=zeros(d.N,1);
        for i=1:d.N, K(i)=d.KInf+mod(q,base); q=floor(q/base); end
        candidate=IndirectInnerExact(K,d);
        if isempty(best)||candidate.TotalCost<best.TotalCost, best=candidate; end
    end
    best.Certificate='global optimum by exhaustive bounded K and exact inner optimization';
    best.EnumeratedStates=states; bounds.IndirectExact=best;
end
if ~isempty(bounds.DirectExact), bounds.DirectLowerBound=bounds.DirectExact.TotalCost; end
if ~isempty(bounds.IndirectExact), bounds.IndirectLowerBound=bounds.IndirectExact.TotalCost; end
end
