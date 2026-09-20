function result=ExactDP_DirectGrid(data,varargin)
%EXACTDP_DIRECTGRID Global optimum of the discretized Direct model (N<=16).
d=NormalizeJRDData(data);
assert(d.N<=16,'JRD:ExactSizeLimit','Subset DP is limited to N<=16.');
options=DirectEvolutionOptions(d,'PopulationSize',4,'Generations',1,varargin{:});
timer=tic; cache=DirectGridCostCache(d,options); stateCount=2^d.N;
subsetCost=zeros(1,stateCount); choice=zeros(1,stateCount);
for mask=1:stateCount-1
    subsetCost(mask+1)=cache.Get(find(bitget(mask,1:d.N))).Cost;
end
dp=Inf(1,stateCount); dp(1)=0; transitions=0;
for mask=1:stateCount-1
    anchor=2^(find(bitget(mask,1:d.N),1)-1); subset=mask;
    while subset>0
        if bitand(subset,anchor)>0
            candidate=subsetCost(subset+1)+dp(bitxor(mask,subset)+1); transitions=transitions+1;
            if candidate<dp(mask+1), dp(mask+1)=candidate; choice(mask+1)=subset; end
        end
        subset=bitand(subset-1,mask);
    end
end
groups={}; mask=stateCount-1;
while mask>0
    subset=choice(mask+1); groups{end+1}=find(bitget(subset,1:d.N)); %#ok<AGROW>
    mask=bitxor(mask,subset);
end
result=DirectGridPartitionCost(groups,cache);
assert(abs(result.TotalCost-dp(end))<=1e-10*max(1,dp(end)),'JRD:CostMismatch','Grid DP failed.');
result.Algorithm='Exact subset-partition DP with grid-exact group costs';
result.Options=options; result.RuntimeSeconds=toc(timer); result.Transitions=transitions;
result.Counters=cache.Snapshot();
result.Certificate='global optimum of the configured discrete T grid and F set';
end
