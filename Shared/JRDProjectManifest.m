function manifest=JRDProjectManifest(root)
% Active MATLAB source + fixed data; exclude backups and generated results.
folders={'','Shared','Direct_V1','Indirect_V1','Tests','Tests/Oracles'};
relative={};
for f=1:numel(folders)
    files=dir(fullfile(root,folders{f},'*.m'));
    for j=1:numel(files)
        relative{end+1}=strrep(fullfile(folders{f},files(j).name),'\','/'); %#ok<AGROW>
    end
end
for n=[10 30 50 100]
    relative{end+1}=sprintf('Data_N%d.mat',n); %#ok<AGROW>
end
relative{end+1}='testDataN6_Paper.mat';
relative=sort(relative);
manifest=repmat(struct('RelativePath','','SHA256',''),1,numel(relative));
for j=1:numel(relative)
    manifest(j).RelativePath=relative{j};
    manifest(j).SHA256=JRDFileSHA256(fullfile(root,relative{j}));
end
end
