function [Report,out]=Run_Preliminary_Audit_Tests()
%RUN_PRELIMINARY_AUDIT_TESTS Full suites in a fresh, nonhistorical output folder.
% Never invokes the frozen Run_Paper_Experiment1_N10 or a formal long study.
root=Setup_JRD(); outputRoot=fullfile(root,'Validation_Preliminary');
if ~isfolder(outputRoot), mkdir(outputRoot); end
out=tempname(outputRoot); mkdir(out);
protected={'AHDE.m','Data_N10.mat','Data_N30.mat','Data_N50.mat','Data_N100.mat', ...
    'Fitness_Indirect.m','Direct_V1/GroupCostExact.m','Direct_V1/PartitionCost.m', ...
    'Paper_Experiments/Run_Paper_Experiment1_N10.m'};
frozen=dir(fullfile(root,'Results_Paper','Experiment1_N10','**','*'));
for j=1:numel(frozen)
    if ~frozen(j).isdir
        protected{end+1}=fullfile(frozen(j).folder,frozen(j).name); %#ok<AGROW>
    end
end
before=hashes(); source=JRDProjectManifest(root);
Report=struct('Status','RUNNING','StartedAt',datestr(now,30),'MATLABVersion',version, ...
    'SourceManifest',source,'ProtectedFilePaths',{protected},'ProtectedSHA256',{before}, ...
    'Suites',{{}},'FormalExperimentRun',false);
saveReport();
names={'legacy_all','completed_search','paper_revision','preliminary_readiness'};
result=[]; captured=''; % evalc cannot introduce variables into a nested static workspace.
for j=1:numel(names)
    fprintf('AUDIT_TEST_START %s %s\n',names{j},datestr(now,30)); wall=tic;
    try
        switch j
            case 1, captured=evalc('result=Test_JRD_All(fullfile(out,''legacy''));');
            case 2, captured=evalc('result=Test_JRD_Completion(fullfile(out,''legacy''));');
            case 3, captured=evalc('result=Test_Paper_Revision(fullfile(out,''paper''));');
            case 4, captured=evalc('result=Test_Preliminary_Readiness(''OutputRoot'',fullfile(out,''preliminary''));');
        end
        Report.Suites{j}=struct('Name',names{j},'Status','PASS','RuntimeSeconds',toc(wall),'Result',result);
        logPath=fullfile(out,[names{j},'.txt']); fid=fopen(logPath,'w','n','UTF-8');
        assert(fid>=0); fprintf(fid,'%s',captured); fclose(fid);
        saveReport(); fprintf('AUDIT_TEST_PASS %s wall=%.3f\n',names{j},Report.Suites{j}.RuntimeSeconds);
    catch problem
        Report.Status='FAIL'; Report.Error=struct('Identifier',problem.identifier, ...
            'Message',problem.message,'Report',getReport(problem,'extended','hyperlinks','off'));
        Report.FailedSuite=names{j}; saveReport(); rethrow(problem);
    end
end
assert(isequal(before,hashes()),'JRD:FrozenEvidenceChanged','Original model/data/Exp1 evidence changed during tests.');
assert(isequal(source,JRDProjectManifest(root)),'JRD:ChangedDuringTests','Source changed during the full test suite.');
Report.Status='PASS'; Report.CompletedAt=datestr(now,30); Report.FrozenExperiment1='unchanged; not rerun';
saveReport(); fprintf('AUDIT_ALL_PASS OUTPUT=%s\n',out);
    function values=hashes()
        values=cell(size(protected));
        for k=1:numel(protected)
            path=protected{k};
            if ~isfile(path), path=fullfile(root,path); end
            values{k}=JRDFileSHA256(path);
        end
    end
    function saveReport()
        SavePaperStudy(fullfile(out,'audit_tests.mat'),Report);
    end
end
