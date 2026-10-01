function [Study,out]=Run_Paper_Experiment3_StrategyComparison(varargin)
%RUN_PAPER_EXPERIMENT3_STRATEGYCOMPARISON Evolutionary-X versus original AHDE.
% 500 generations and population=10N are reference settings, to be profiled
% before a formal protocol is locked. Runtime never selects the strategy.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'NList',[10 30 50 100],@(x) isnumeric(x)&&isvector(x)&&~isempty(x)&&all(ismember(x,[10 30 50 100]))&&numel(unique(x))==numel(x));
addParameter(p,'Runs',30,integer); addParameter(p,'BaseSeed',20260919,@(x) integer(x)&&x<=2^32-1);
addParameter(p,'Generations',500,integer); addParameter(p,'PopulationFactor',10,integer);
addParameter(p,'MinimumPopulation',40,@(x) integer(x)&&x>=4);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x));
addParameter(p,'MaxNewSolves',Inf,@(x) (isnumeric(x)&&isscalar(x)&&isinf(x)&&x>0)||integer(x));
addParameter(p,'ContinueOnTaskError',false,@(x) islogical(x)&&isscalar(x));
addParameter(p,'RetryFailedTasks',true,@(x) islogical(x)&&isscalar(x));
parse(p,varargin{:}); o=p.Results;
strategies={'DirectEvolutionaryX','IndirectTeacherAHDE'};
config=rmfield(o,{'OutputRoot','ResumeDir','MaxNewSolves','ContinueOnTaskError','RetryFailedTasks'}); manifest=JRDProjectManifest(root);
if isempty(o.ResumeDir)
    out=CreatePaperOutput(root,'Experiment3_StrategyComparison',char(o.OutputRoot));
    Study=struct('SchemaVersion',2,'ExperimentKind','Exp3','Experiment','Direct versus Indirect strategy cost', ...
        'Status','running','Config',config,'Strategies',{strategies},'Manifest',manifest, ...
        'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
        'InstanceDefinition','one immutable Data_N*.mat instance per N; algorithm seeds are not additional benchmark instances', ...
        'BudgetRole','population=10N and generations=500 are paper reference settings requiring pilot wall-clock measurement', ...
        'FairnessRule',['same instance, paired seed, population and generation level; variable structures and inner work remain different. ' ...
        'Same seed does not imply identical random trajectories, and equal population/generations does not imply equal objective-evaluation work'], ...
        'TimeRole','runtime is reported but never decides which strategy has lower cost', ...
        'IndirectRole','unchanged teacher AHDE is primary; stronger Indirect search belongs to robustness/supplementary', ...
        'ClaimBoundary','large-scale values are best feasible costs, not proven global optima', ...
        'ResumeGranularity','one completed solver call; interruption inside unchanged AHDE restarts only that incomplete call');
    Study.Inputs=cell(numel(o.NList),1); Study.Records=cell(numel(o.NList),o.Runs,2);
else
    out=char(o.ResumeDir); loaded=load(fullfile(out,'study.mat'),'Study'); Study=loaded.Study;
    assert(Study.SchemaVersion==2&&strcmp(Study.ExperimentKind,'Exp3'), ...
        'JRD:CheckpointSchema','Historical Exp3 checkpoints must retain their original runner/source version.');
    assert(isequaln(Study.Config,config)&&isequal(Study.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Resume configuration, source, or fixed data changed.');
end
if ~isfield(Study,'Failures'), Study.Failures=cell(size(Study.Records)); end
if ~isfield(Study,'ErrorRecords'), Study.ErrorRecords=struct([]); end
if ~isfield(Study,'AttemptCounts'), Study.AttemptCounts=zeros(size(Study.Records)); end
Study.RunControls=struct('ContinueOnTaskError',o.ContinueOnTaskError,'RetryFailedTasks',o.RetryFailedTasks,'MaxNewSolves',o.MaxNewSolves);
Study.Status='running'; newSolves=0;
SavePaperStudy(fullfile(out,'study.mat'),Study);
for ni=1:numel(o.NList)
    input=load(fullfile(root,sprintf('Data_N%d.mat',o.NList(ni))),'data'); d=input.data;
    if ~isempty(Study.Inputs{ni})
        assert(isequaln(d,Study.Inputs{ni}),'JRD:StaleCheckpoint','The saved instance differs from the current original data.');
    end
    Study.Inputs{ni}=d; population=max(o.MinimumPopulation,o.PopulationFactor*d.N);
    for r=1:o.Runs
        seed=mod(o.BaseSeed+1000003*d.N+r-1,2^32);
        if mod(r,2), order=1:2; else, order=2:-1:1; end
        for s=order
            path=fullfile(out,'raw',sprintf('N%d_%s_run%03d.mat',d.N,strategies{s},r));
            if isempty(Study.Records{ni,r,s})&&isfile(path)
                Study.Records{ni,r,s}=RecoverPaperStrategyRecord(path,d,strategies{s},r,seed,population,o.Generations,o.GridStep);
                Study=ResolvePaperStrategyTaskError(Study,ni,r,s,strategies{s});
                Study=PaperStrategyOutputs(Study,out);
                SavePaperStudy(fullfile(out,'study.mat'),Study);
            end
            if isempty(Study.Records{ni,r,s})
                if ~o.RetryFailedTasks&&~isempty(Study.Failures{ni,r,s}), continue; end
                Study.AttemptCounts(ni,r,s)=Study.AttemptCounts(ni,r,s)+1;
                taskTimer=tic;
                try
                    [answer,failure]=RunPaperTaskGuard(@() RunPaperStrategyCase(d,strategies{s},seed,population,o.Generations,o.GridStep),o.ContinueOnTaskError);
                catch problem
                    failure=struct('Identifier',problem.identifier,'Message',problem.message, ...
                        'Report',getReport(problem,'extended','hyperlinks','off'),'At',datestr(now,30), ...
                        'ElapsedSeconds',toc(taskTimer),'IsGlobalBlocker',PaperTaskFailureIsFatal(problem));
                    Study=RecordPaperStrategyTaskError(Study,ni,r,s,strategies{s},seed,failure);
                    Study.Status='stopped_task_error';
                    if failure.IsGlobalBlocker, Study.Status='blocked_global_error'; end
                    Study=PaperStrategyOutputs(Study,out); SavePaperStudy(fullfile(out,'study.mat'),Study);
                    rethrow(problem);
                end
                if isempty(failure)
                    kind='Indirect'; if s==1, kind='Direct'; end
                    Study.Records{ni,r,s}=answer;
                    Study=ResolvePaperStrategyTaskError(Study,ni,r,s,strategies{s});
                    record=struct('N',d.N,'InstanceId',sprintf('FixedData_N%d',d.N),'Strategy',strategies{s}, ...
                        'Run',r,'Seed',seed,'Answer',answer,'Diagnostics',JRDAnalyzeSolution(d,answer,kind));
                    SavePaperStrategyRecord(path,record);
                    fprintf('Experiment3 N=%d run=%d %s TC=%.10f runtime=%.3fs\n', ...
                        d.N,r,strategies{s},answer.TotalCost,answer.RuntimeSeconds);
                else
                    Study=RecordPaperStrategyTaskError(Study,ni,r,s,strategies{s},seed,failure);
                    fprintf('Experiment3 TASK_FAILED N=%d run=%d %s %s: %s\n',d.N,r,strategies{s},failure.Identifier,failure.Message);
                end
                Study=PaperStrategyOutputs(Study,out);
                SavePaperStudy(fullfile(out,'study.mat'),Study);
                newSolves=newSolves+1;
                if newSolves>=o.MaxNewSolves&&any(cellfun(@isempty,Study.Records(:)))
                    Study.Status='paused_solver_boundary'; Study=PaperStrategyOutputs(Study,out);
                    SavePaperStudy(fullfile(out,'study.mat'),Study); return;
                end
            elseif ~isfile(path)
                answer=Study.Records{ni,r,s}; kind='Indirect'; if s==1, kind='Direct'; end
                record=struct('N',d.N,'InstanceId',sprintf('FixedData_N%d',d.N),'Strategy',strategies{s}, ...
                    'Run',r,'Seed',seed,'Answer',answer,'Diagnostics',JRDAnalyzeSolution(d,answer,kind));
                SavePaperStrategyRecord(path,record);
            end
        end
    end
end
Study.Status='complete';
if any(cellfun(@isempty,Study.Records(:))), Study.Status='completed_with_failures'; end
Study.CompletedAt=datestr(now,30);
Study=PaperStrategyOutputs(Study,out); SavePaperStudy(fullfile(out,'study.mat'),Study);
end
