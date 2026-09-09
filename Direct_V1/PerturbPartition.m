function groups = PerturbPartition(groups,n,moves)
ids=zeros(1,n);
for q=1:numel(groups), ids(groups{q})=q; end
for step=1:moves
    ids=CanonicalizePartition(ids); item=randi(n);
    candidates=1:max(ids)+1;
    candidates(candidates==ids(item))=[];
    if sum(ids==ids(item))==1, candidates(candidates==max(ids)+1)=[]; end
    if isempty(candidates), continue; end
    target=candidates(randi(numel(candidates)));
    ids(item)=target;
end
ids=CanonicalizePartition(ids);
groups=arrayfun(@(q) find(ids==q),1:max(ids),'UniformOutput',false);
end
