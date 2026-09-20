function ids=RandomCanonicalPartition(n)
%RANDOMCANONICALPARTITION Generate a varied restricted-growth partition.
assert(n>=1&&n==fix(n));
if n==1, ids=1; return; end
upper=max(2,min(n,ceil(2*sqrt(n)))); target=randi([1,upper]);
ids=randi(target,1,n); ids=CanonicalizePartition(ids);
end
