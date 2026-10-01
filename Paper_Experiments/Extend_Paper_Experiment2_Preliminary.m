function [Study,out]=Extend_Paper_Experiment2_Preliminary(parentDir,varargin)
%EXTEND_PAPER_EXPERIMENT2_PRELIMINARY New study; reuse completed matching tasks.
% Parent artifacts are read-only. Only Instances/Runs may change. Task seeds
% depend on instance identity, so extending the grid preserves random streams.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'Instances',[],@(x) isempty(x)||integer(x));
addParameter(p,'Runs',[],@(x) isempty(x)||integer(x));
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
parse(p,varargin{:}); o=p.Results;
parentDir=char(parentDir); loaded=load(fullfile(parentDir,'study.mat'),'Study'); parent=loaded.Study;
assert(parent.SchemaVersion==2&&isfield(parent,'Scenarios')&&isfield(parent,'Records'), ...
    'JRD:CheckpointSchema','Expected an Experiment 2 schema2 checkpoint.');
currentManifest=JRDProjectManifest(root);
assert(isequal(parent.Manifest,currentManifest),'JRD:StaleCheckpoint', ...
    'Parent source/data manifest changed; cross-version result reuse is not allowed.');
if isempty(o.Instances), o.Instances=parent.Config.Instances; end
if isempty(o.Runs), o.Runs=parent.Config.Runs; end
assert(o.Instances>=parent.Config.Instances&&o.Runs>=parent.Config.Runs, ...
    'JRD:CheckpointSchema','Extension must not shrink the parent instance/run design.');
if strcmp(parent.Config.InstanceSource,'fixed')
    assert(o.Instances==1,'JRD:FixedInstanceDesign','Frozen input mode contains one instance per N.');
end
newConfig=parent.Config; newConfig.Instances=o.Instances; newConfig.Runs=o.Runs;
names=fieldnames(newConfig); runnerArgs={};
for k=1:numel(names), runnerArgs(end+1:end+2)={names{k},newConfig.(names{k})}; end %#ok<AGROW>
[Study,out]=Run_Paper_Experiment2_DirectPerformance(runnerArgs{:}, ...
    'OutputRoot',o.OutputRoot,'MaxNewSolves',0,'ContinueOnTaskError',true);
assert(isequaln(Study.Config,newConfig)&&isequal(Study.Algorithms,parent.Algorithms), ...
    'JRD:CheckpointSchema','Extension changed an unapproved algorithm/configuration dimension.');
Study.ParentDir=parentDir; Study.ReusedRecords=0; provenance={};
for si=1:numel(Study.Scenarios)
    scenario=Study.Scenarios(si);
    sourceIndex=find(strcmp({parent.Scenarios.InstanceID},scenario.InstanceID),1);
    if ~isempty(sourceIndex)
        assert(isequaln(Study.Inputs{si},parent.Inputs{sourceIndex})&& ...
            isequaln(scenario,parent.Scenarios(sourceIndex)), ...
            'JRD:StaleCheckpoint','A matched instance changed its data or generator metadata.');
    end
    for run=1:Study.Config.Runs
        expectedSeed=PaperExperiment2AlgorithmSeed(scenario.N,scenario.InstanceSeed,run, ...
            Study.Config.BaseSeed,Study.Config.InstanceSource);
        for algorithm=1:numel(Study.Algorithms)
            reused=false; sourceRun=NaN; sourceInstance='';
            if ~isempty(sourceIndex)&&run<=parent.Config.Runs
                answer=parent.Records{sourceIndex,run,algorithm};
                if ~isempty(answer)
                    assert(answer.AlgorithmSeed==expectedSeed&&strcmp(answer.InstanceID,scenario.InstanceID), ...
                        'JRD:StaleCheckpoint','A reused task does not have the stable expected identity/seed.');
                    checked=EvaluateDirectGridPartition(answer.GroupId,Study.Inputs{si},'GridStep',Study.Config.GridStep);
                    assert(abs(checked.TotalCost-answer.CommonGridTC)<=1e-9*max(1,checked.TotalCost), ...
                        'JRD:CostMismatch','A reused task failed common-grid recomputation.');
                    Study.Records{si,run,algorithm}=answer;
                    if isfield(parent,'AttemptCounts')
                        Study.AttemptCounts(si,run,algorithm)=parent.AttemptCounts(sourceIndex,run,algorithm);
                    else, Study.AttemptCounts(si,run,algorithm)=1; end
                    record=struct('Scenario',scenario,'Run',run,'Algorithm',Study.Algorithms{algorithm}, ...
                        'AlgorithmSeed',expectedSeed,'Answer',answer,'Input',Study.Inputs{si}, ...
                        'Config',Study.Config,'Manifest',Study.Manifest);
                    SavePaperStrategyRecord(fullfile(out,'raw',sprintf('%s_%s_run%03d.mat', ...
                        scenario.InstanceID,Study.Algorithms{algorithm},run)),record);
                    reused=true; sourceRun=run; sourceInstance=scenario.InstanceID;
                    Study.ReusedRecords=Study.ReusedRecords+1;
                end
            end
            provenance(end+1,:)={scenario.InstanceID,scenario.N,Study.Algorithms{algorithm},run,expectedSeed, ...
                reused,parentDir,sourceInstance,sourceRun}; %#ok<AGROW>
        end
    end
end
Study.TaskProvenance=cell2table(provenance,'VariableNames',{'InstanceID','N','Algorithm','Run', ...
    'AlgorithmSeed','Reused','ParentDir','ParentInstanceID','ParentRun'});
Study.ExtensionAuthorization='Instances/Runs increase only; same sources, inputs, solver/grid/budget and stable task seed policy';
Study.Status='paused_extension_ready';
writetable(Study.TaskProvenance,fullfile(out,'task_provenance.csv'));
SavePaperStudy(fullfile(out,'study.mat'),Study);
% Refresh derived CSV/progress without executing any solver task.
[Study,out]=Run_Paper_Experiment2_DirectPerformance(runnerArgs{:},'ResumeDir',out, ...
    'MaxNewSolves',0,'ContinueOnTaskError',true);
end
