function ids=GreedyGridPartition(data,cache,randomized)
%GREEDYGRIDPARTITION Sequential insertion using the same grid objective.
n=data.N; if randomized, order=randperm(n); else, order=1:n; end
groups={}; groupCost=[];
for item=order
    candidateCost=zeros(1,numel(groups)+1);
    for g=1:numel(groups)
        candidateCost(g)=cache.Get([groups{g},item]).Cost-groupCost(g);
    end
    singleton=cache.Get(item); candidateCost(end)=singleton.Cost;
    [~,rank]=sort(candidateCost);
    if randomized, selected=rank(randi(min(3,numel(rank)))); else, selected=rank(1); end
    if selected>numel(groups)
        groups{selected}=item; groupCost(selected)=singleton.Cost;
    else
        groups{selected}=[groups{selected},item];
        groupCost(selected)=cache.Get(groups{selected}).Cost;
    end
end
ids=zeros(1,n);
for g=1:numel(groups), ids(groups{g})=g; end
ids=CanonicalizePartition(ids);
end
