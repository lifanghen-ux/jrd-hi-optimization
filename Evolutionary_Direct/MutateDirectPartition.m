function child=MutateDirectPartition(parent)
%MUTATEDIRECTPARTITION Relocate, merge, split or swap actual item groups.
child=CanonicalizePartition(parent); n=numel(child); groupCount=max(child);
available={'relocate'};
if groupCount>=2, available=[available,{'merge','swap'}]; end %#ok<AGROW>
if any(accumarray(child(:),1)>=2), available=[available,{'split'}]; end %#ok<AGROW>
kind=available{randi(numel(available))};
switch kind
    case 'relocate'
        item=randi(n); labels=1:groupCount+1;
        labels(labels==child(item))=[]; child(item)=labels(randi(numel(labels)));
    case 'merge'
        pair=randperm(groupCount,2); child(child==pair(2))=pair(1);
    case 'swap'
        pair=randperm(n,2); attempts=0;
        while child(pair(1))==child(pair(2))&&attempts<10
            pair=randperm(n,2); attempts=attempts+1;
        end
        if child(pair(1))~=child(pair(2))
            temporary=child(pair(1)); child(pair(1))=child(pair(2)); child(pair(2))=temporary;
        end
    case 'split'
        sizes=accumarray(child(:),1); candidates=find(sizes>=2);
        label=candidates(randi(numel(candidates))); items=find(child==label);
        selected=rand(size(items))<0.5;
        if ~any(selected), selected(randi(numel(items)))=true; end
        if all(selected), selected(randi(numel(items)))=false; end
        child(items(selected))=groupCount+1;
end
child=CanonicalizePartition(child);
end
