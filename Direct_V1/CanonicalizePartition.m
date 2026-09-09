function ids = CanonicalizePartition(groupId)
% Restricted-growth labels in order of first item appearance.
validateattributes(groupId,{'numeric'},{'vector','nonempty','finite','integer','positive'});
groupId = groupId(:)';
labels = unique(groupId,'stable');
[~,ids] = ismember(groupId,labels);
end
