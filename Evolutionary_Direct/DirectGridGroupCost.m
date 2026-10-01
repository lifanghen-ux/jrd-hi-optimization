function value = DirectGridGroupCost(items,data,options)
%DIRECTGRIDGROUPCOST Exact minimum on the configured (T,f) lattice.
% "projection" checks the two grid neighbours around the continuous
% minimizer. Convexity makes it exactly equivalent to enumerating all T.
d=NormalizeJRDData(data); items=sort(items(:)');
assert(~isempty(items)&&all(items>=1&items<=d.N&items==fix(items))&& ...
    numel(unique(items))==numel(items),'JRD:InvalidGroup','Invalid Direct group.');
value=DirectGridGroupKernel(items,d,options);
end
