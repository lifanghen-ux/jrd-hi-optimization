function child=CrossoverDirectPartition(parentA,parentB)
%CROSSOVERDIRECTPARTITION Preserve complete group blocks without label meaning.
parentA=CanonicalizePartition(parentA); parentB=CanonicalizePartition(parentB);
n=numel(parentA); child=zeros(1,n); next=0;
groupsA=unique(parentA); selected=rand(size(groupsA))<0.5;
if ~any(selected), selected(randi(numel(selected)))=true; end
if all(selected)&&numel(selected)>1, selected(randi(numel(selected)))=false; end
for label=groupsA(selected)
    next=next+1; child(parentA==label)=next;
end
for label=unique(parentB)
    items=find(parentB==label & child==0);
    if ~isempty(items), next=next+1; child(items)=next; end
end
for item=find(child==0)
    next=next+1; child(item)=next;
end
child=CanonicalizePartition(child);
end
