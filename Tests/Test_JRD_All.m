function readiness=Test_JRD_All()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); Setup_JRD();
out=fullfile(root,'Validation_V1'); if ~isfolder(out), mkdir(out); end
before=JRDProjectManifest(root);
mathematics=Test_JRD_Mathematics();
save(fullfile(out,'mathematics.mat'),'mathematics');
search=Test_JRD_Search();
save(fullfile(out,'search.mat'),'search');
hitRate=Test_N10_HitRate();
save(fullfile(out,'n10_acceptance.mat'),'hitRate');
storage=Test_Storage_Fix();
save(fullfile(out,'storage.mat'),'storage');
after=JRDProjectManifest(root);
assert(isequal(before,after),'JRD:ChangedDuringTests','Source or fixed data changed during tests.');
readiness=struct('Status','PASS','Manifest',after,'MATLABVersion',version, ...
    'CompletedAt',datestr(now,30),'FormalExperimentRun',false);
save(fullfile(out,'readiness.mat'),'readiness');
disp(readiness);
end
