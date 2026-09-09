function result = ExactDP_Direct(data)
% Exact subset-partition DP, never used as a special case by MS_VND_Direct.
d = NormalizeJRDData(data);
assert(d.N<=16,'JRD:ExactSizeLimit','Subset DP is limited to N<=16.');
timer=tic; count=2^d.N;
budget=SearchBudget(Inf,Inf,'direct_group');
cache=GroupCostCache(d,budget,count);
cost=zeros(1,count); choice=zeros(1,count);
for mask=1:count-1
    items=find(bitget(mask,1:d.N));
    cost(mask+1)=cache.Get(items);
end
dp=Inf(1,count); dp(1)=0; transitions=0;
for mask=1:count-1
    anchor=2^(find(bitget(mask,1:d.N),1)-1);
    sub=mask;
    while sub>0
        if bitand(sub,anchor)>0
            value=cost(sub+1)+dp(bitxor(mask,sub)+1);
            transitions=transitions+1;
            if value<dp(mask+1), dp(mask+1)=value; choice(mask+1)=sub; end
        end
        sub=bitand(sub-1,mask);
    end
end
groups={}; mask=count-1;
while mask>0
    sub=choice(mask+1);
    groups{end+1}=find(bitget(sub,1:d.N)); %#ok<AGROW>
    mask=bitxor(mask,sub);
end
result=PartitionCost(groups,d);
result.Certificate='global optimum under the current Direct model and integer F bounds';
result.DPValue=dp(end);
result.Transitions=transitions;
result.RuntimeSeconds=toc(timer);
result.Counters=budget.Snapshot();
end
