function result = PartitionCost(partition,data)
% Accept either an item-label vector or a cell array of nonempty groups.
d = NormalizeJRDData(data);
if iscell(partition)
    assert(~isempty(partition) && all(~cellfun(@isempty,partition)), ...
        'JRD:InvalidPartition','Empty groups are not valid cell partitions.');
    ids = zeros(1,d.N);
    partition=cellfun(@(g) g(:)',partition,'UniformOutput',false);
    flat = [partition{:}];
    assert(isequal(sort(flat(:))',(1:d.N)),'JRD:InvalidPartition', ...
        'Each item must appear exactly once.');
    for q=1:numel(partition), ids(partition{q})=q; end
else
    assert(numel(partition)==d.N,'JRD:InvalidPartition','Wrong number of items.');
    ids = CanonicalizePartition(partition);
end
ids = CanonicalizePartition(ids);
groups = arrayfun(@(q) find(ids==q),1:max(ids),'UniformOutput',false);
cache = GroupCostCache(d,SearchBudget(Inf,Inf,'direct_group'),max(ids));
costs = zeros(1,max(ids)); f=costs; T=costs;
for q=1:numel(groups), [costs(q),f(q),T(q)]=cache.Get(groups{q}); end
result = struct('TotalCost',sum(costs),'GroupId',ids,'Groups',{groups}, ...
    'GroupCount',numel(groups),'GroupF',f,'GroupT',T,'GroupCost',costs);
end
