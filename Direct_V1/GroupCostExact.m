function [cost,bestF,bestT] = GroupCostExact(items,data)
d = NormalizeJRDData(data);
cache = GroupCostCache(d,SearchBudget(Inf,Inf,'direct_group'),1);
[cost,bestF,bestT] = cache.Get(items);
end
