function [Provenance,path]=Archive_Profile_Provenance(profileDir)
%ARCHIVE_PROFILE_PROVENANCE Immutable evidence for the measured solver source.
% The profile stored hashes at startup. Recover exact Text only for old .m
% files whose current bytes still have that hash; never invent changed Text.
root=Setup_JRD(); profileDir=char(profileDir);
profileFolder=java.io.File(profileDir); profileDir=char(profileFolder.getCanonicalPath());
profilePath=fullfile(profileDir,'profile.mat');
loaded=load(profilePath,'Study'); measured=loaded.Study;
assert(isfield(measured,'SourceManifest'),'JRD:CheckpointSchema', ...
    'The profile does not contain its startup source manifest.');
old=measured.SourceManifest; current=JRDProjectManifest(root);
oldPaths={old.RelativePath}; currentPaths={current.RelativePath};
unchanged={}; changed={}; removed={};
for k=1:numel(old)
    match=find(strcmp(currentPaths,old(k).RelativePath),1);
    if isempty(match), removed{end+1,1}=old(k).RelativePath; %#ok<AGROW>
    elseif strcmp(old(k).SHA256,current(match).SHA256)
        unchanged{end+1,1}=old(k).RelativePath; %#ok<AGROW>
    else, changed{end+1,1}=old(k).RelativePath; end %#ok<AGROW>
end
added=currentPaths(~ismember(currentPaths,oldPaths)); added=added(:);

% Both startup and current algorithm/dependency paths must match: a new,
% removed, or modified file in one of these folders invalidates the proof.
allPaths=unique([oldPaths,currentPaths]); required={};
explicit={'AHDE.m','Fitness_Indirect.m', ...
    'Paper_Experiments/RunCommonDirectBaseline.m', ...
    'Paper_Experiments/CommonGridVNDCostCache.m','Paper_Experiments/RunTeacherAHDE.m'};
for k=1:numel(allPaths)
    name=allPaths{k};
    isDependency=endsWith(name,'.m')&&(startsWith(name,'Evolutionary_Direct/')|| ...
        startsWith(name,'Direct_V1/')||startsWith(name,'Shared/'));
    isFixedInput=~isempty(regexp(name,'^Data_N[^/]*\.mat$','once'));
    if isDependency||isFixedInput||ismember(name,explicit), required{end+1,1}=name; end %#ok<AGROW>
end
required=unique([required;explicit(:)]);
verified=repmat(struct('RelativePath','','SHA256',''),numel(required),1);
for k=1:numel(required)
    oi=find(strcmp(oldPaths,required{k}),1); ci=find(strcmp(currentPaths,required{k}),1);
    assert(~isempty(oi)&&~isempty(ci)&&strcmp(old(oi).SHA256,current(ci).SHA256), ...
        'JRD:ProfileSourceChanged','A measured solver/dependency/input changed: %s',required{k});
    verified(k)=current(ci);
end
path=fullfile(profileDir,'profiling_source_provenance.mat');
if isfile(path)
    saved=load(path,'Provenance');
    assert(isfield(saved,'Provenance'),'JRD:CheckpointSchema','Existing provenance has an invalid schema.');
    Provenance=saved.Provenance;
    assert(Provenance.SchemaVersion==1&&strcmp(Provenance.ProfileDir,profileDir)&& ...
        strcmp(Provenance.RepositoryRoot,root)&&isequal(Provenance.ProfileStartupManifest,old)&& ...
        isequal(Provenance.VerifiedDependencyManifest,verified)&&Provenance.MeasuredDependenciesUnchanged, ...
        'JRD:StaleProvenance','Existing provenance does not match this profile and its measured dependencies.');
    % An archive remains historical if a later commit changes only runners.
    % Validate recovered Text against startup hashes and current unchanged
    % files, without claiming a later repository HEAD was measured.
    for k=1:numel(Provenance.RecoveredUnchangedMATLABSource)
        entry=Provenance.RecoveredUnchangedMATLABSource(k);
        oi=find(strcmp(oldPaths,entry.RelativePath),1);
        assert(~isempty(oi)&&strcmp(old(oi).SHA256,entry.SHA256), ...
            'JRD:StaleProvenance','Recovered Text is not linked to its startup hash.');
        ci=find(strcmp(currentPaths,entry.RelativePath),1);
        if ~isempty(ci)&&strcmp(current(ci).SHA256,entry.SHA256)
            assert(strcmp(entry.Text,fileread(fullfile(root,entry.RelativePath))), ...
                'JRD:StaleProvenance','Recovered Text differs despite a matching file hash.');
        end
    end
    return;
end
[gitStatus,head]=system(sprintf('git -C "%s" rev-parse HEAD',root));
head=strtrim(head);
assert(gitStatus==0&&~isempty(regexp(head,'^[0-9a-f]{40}$','once')), ...
    'JRD:GitProvenance','Could not record the current HEAD commit.');
snapshot=PaperSourceSnapshot(root);
keep=ismember({snapshot.RelativePath},unchanged); recovered=snapshot(keep);
unknown=unique([changed;removed]); unknown=unknown(endsWith(unknown,'.m'));
Provenance=struct('SchemaVersion',1,'ProfileDir',profileDir,'RepositoryRoot',root, ...
    'ArchivedAt',datestr(now,30),'NewHEADCommit',head,'ProfileStartupManifest',old, ...
    'CurrentManifestAtArchive',current,'VerifiedDependencyManifest',verified, ...
    'MeasuredDependenciesUnchanged',true,'UnchangedPaths',{unchanged}, ...
    'ChangedPaths',{changed},'AddedPaths',{added},'RemovedPaths',{removed}, ...
    'RecoveredUnchangedMATLABSource',recovered,'UnrecoverableHistoricalMATLABTextPaths',{unknown}, ...
    'Interpretation',['The profile recorded SourceManifest at startup. The measured solver files, all Direct_V1/Shared/Evolutionary_Direct dependencies and fixed Data_N*.mat ' ...
        'still match those startup hashes. Changes/additions in experiment runners/tests during profiling are not changes to the measured algorithms. ' ...
        'Recovered Text is exact only for hash-matching old MATLAB paths; this archive does not reconstruct all historical project Text or claim the current full project was profiled.']);
if isfield(measured,'StartedAt'), Provenance.ProfileStartedAt=measured.StartedAt; end
if isfield(measured,'AllJobsCompleted'), Provenance.ProfileAllJobsCompleted=measured.AllJobsCompleted; end
if isfield(measured,'CompletedAt'), Provenance.ProfileCompletedAt=measured.CompletedAt; end
temporary=[tempname(profileDir),'.mat'];
save(temporary,'Provenance','-v7');
% java.nio.Files.move without REPLACE_EXISTING fails if another archive has
% appeared; it cannot overwrite a prior evidence file.
try
    emptyStrings=javaArray('java.lang.String',0);
    temporaryPath=javaMethod('get','java.nio.file.Paths',temporary,emptyStrings);
    archivePath=javaMethod('get','java.nio.file.Paths',path,emptyStrings);
    javaMethod('move','java.nio.file.Files',temporaryPath,archivePath,javaArray('java.nio.file.CopyOption',0));
catch exception
    if isfile(temporary), delete(temporary); end
    rethrow(exception);
end
end
