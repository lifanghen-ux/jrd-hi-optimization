function result = DirectGridPartitionCost(partition,cache)
%DIRECTGRIDPARTITIONCOST Evaluate one canonical, nonempty Direct partition.
d=cache.Data;
if iscell(partition)
    assert(~isempty(partition)&&all(~cellfun(@isempty,partition)),'JRD:InvalidPartition','Empty group.');
    partition=cellfun(@(x) x(:)',partition,'UniformOutput',false); flat=[partition{:}];
    assert(isequal(sort(flat(:))',(1:d.N)),'JRD:InvalidPartition', ...
        'Each item must occur exactly once.');
    ids=zeros(1,d.N);
    for g=1:numel(partition), ids(partition{g})=g; end
else
    assert(numel(partition)==d.N,'JRD:InvalidPartition','Wrong partition length.');
    ids=CanonicalizePartition(partition);
end
ids=CanonicalizePartition(ids); count=max(ids);
groups=arrayfun(@(g) find(ids==g),1:count,'UniformOutput',false);
values=cell(1,count); costs=zeros(1,count); f=costs; t=costs;
parts=zeros(count,5);
for g=1:count
    values{g}=cache.Get(groups{g}); v=values{g};
    costs(g)=v.Cost; f(g)=v.F; t(g)=v.T;
    parts(g,:)=[v.OrderingCost,v.DeliveryCost,v.WarehouseHoldingCost, ...
        v.RetailHoldingCost,v.PenaltyCost];
end
total=sum(costs);
result=struct('TotalCost',total,'GroupId',ids,'Groups',{groups}, ...
    'GroupCount',count,'GroupF',f,'GroupT',t,'GroupCost',costs, ...
    'OrderingCost',sum(parts(:,1)),'DeliveryCost',sum(parts(:,2)), ...
    'WarehouseHoldingCost',sum(parts(:,3)),'RetailHoldingCost',sum(parts(:,4)), ...
    'PenaltyCost',sum(parts(:,5)),'GroupDetails',{values});
assert(abs(sum([result.OrderingCost,result.DeliveryCost,result.WarehouseHoldingCost, ...
    result.RetailHoldingCost,result.PenaltyCost])-total)<=1e-10*max(1,total), ...
    'JRD:CostMismatch','Partition cost decomposition failed.');
end
