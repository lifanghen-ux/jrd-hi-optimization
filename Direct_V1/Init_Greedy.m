function state = Init_Greedy(data,cache,randomized)
% Complete construction before returning; the caller retains its incumbent.
if randomized, order=randperm(data.N); else, order=1:data.N; end
groups={}; costs=[];
for item=order
    deltas=zeros(1,numel(groups)+1);
    newCosts=deltas;
    for q=1:numel(groups)
        newCosts(q)=cache.Get([groups{q},item]);
        deltas(q)=newCosts(q)-costs(q);
    end
    newCosts(end)=cache.Get(item); deltas(end)=newCosts(end);
    [~,rank]=sort(deltas);
    if randomized, q=rank(randi(min(3,numel(rank)))); else, q=rank(1); end
    if q>numel(groups), groups{q}=item; else, groups{q}=[groups{q},item]; end
    costs(q)=newCosts(q);
end
state=DirectState(groups,cache);
end
