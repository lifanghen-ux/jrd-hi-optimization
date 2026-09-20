function source=PaperSourceSnapshot(root)
%PAPERSOURCESNAPSHOT Store exact active MATLAB text with each study.
manifest=JRDProjectManifest(root); source=struct('RelativePath',{},'SHA256',{},'Text',{});
for i=1:numel(manifest)
    if endsWith(manifest(i).RelativePath,'.m')
        source(end+1)=struct('RelativePath',manifest(i).RelativePath, ...
            'SHA256',manifest(i).SHA256,'Text',fileread(fullfile(root,manifest(i).RelativePath))); %#ok<AGROW>
    end
end
end
