function state = DirectState(groups,cache)
groups = groups(~cellfun(@isempty,groups));
groups = cellfun(@(g) sort(g(:)'),groups,'UniformOutput',false);
[~,order]=sort(cellfun(@(g) g(1),groups)); groups=groups(order);
costs=zeros(1,numel(groups));
for q=1:numel(groups), costs(q)=cache.Get(groups{q}); end
state=struct('Groups',{groups},'Costs',costs,'TotalCost',sum(costs));
end
