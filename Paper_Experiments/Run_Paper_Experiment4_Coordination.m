function [Study,out]=Run_Paper_Experiment4_Coordination(varargin)
%RUN_PAPER_EXPERIMENT4_COORDINATION Reoptimize each outer X/K with f/F or one.
% Both Indirect cases call the same original AHDE, only FInf/FSup differ.
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
cases={'Direct_Coordinated','Direct_F1','Indirect_Coordinated','Indirect_F1'};
config=rmfield(o,{'OutputRoot','ResumeDir','MaxNewSolves','ContinueOnTaskError','RetryFailedTasks'}); manifest=JRDProjectManifest(root);
if isempty(o.ResumeDir)
    out=CreatePaperOutput(root,'Experiment4_Coordination',char(o.OutputRoot));
    Study=struct('SchemaVersion',2,'ExperimentKind','Exp4','Experiment','coordination value: optimized f/F versus one', ...
        'Status','running','Config',config,'Cases',{cases},'Manifest',manifest, ...
        'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
        'InstanceDefinition','one immutable Data_N*.mat instance per N; algorithm seeds are not additional benchmark instances', ...
        'BudgetRole','population=10N and generations=500 are paper reference settings requiring pilot wall-clock measurement', ...
        'Design',['Each case independently reoptimizes X or K. Within each strategy the algorithm implementation is identical; ' ...
        'only the delivery-frequency feasible domain changes. Original AHDE remains 2N-dimensional even when FInf=FSup=1. ' ...
        'Paired seeds support reproducibility, not identical random trajectories. Equal population/generation levels are not equal inner work'], ...
        'SanityRule','coordinated feasible set contains fixed-frequency set; a higher found coordinated TC is flagged as heuristic_search_insufficiency', ...
        'SupplementaryRole','AHDE_FixedF1.m is supplementary only and is never called by this primary runner', ...
        'ResumeGranularity','one completed solver call; interruption inside unchanged AHDE restarts only that incomplete call');
    Study.Inputs=cell(numel(o.NList),1); Study.Records=cell(numel(o.NList),o.Runs,4);
else
    out=char(o.ResumeDir); loaded=load(fullfile(out,'study.mat'),'Study'); Study=loaded.Study;
    assert(Study.SchemaVersion==2&&strcmp(Study.ExperimentKind,'Exp4'), ...
        'JRD:CheckpointSchema','Historical Exp4 checkpoints must retain their original runner/source version.');
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
    normalized=NormalizeJRDData(d);
    assert(normalized.FInf<=1&&normalized.FSup>=1,'JRD:FrequencyBounds','The coordinated frequency domain must include one.');
    if ~isempty(Study.Inputs{ni})
        assert(isequaln(d,Study.Inputs{ni}),'JRD:StaleCheckpoint','The saved instance differs from the current original data.');
    end
    Study.Inputs{ni}=d; population=max(o.MinimumPopulation,o.PopulationFactor*d.N);
    for r=1:o.Runs
        seed=mod(o.BaseSeed+1000003*d.N+r-1,2^32);
        order=circshift(1:4,[0,-mod(r-1,4)]);
        for c=order
            path=fullfile(out,'raw',sprintf('N%d_%s_run%03d.mat',d.N,cases{c},r));
            if isempty(Study.Records{ni,r,c})&&isfile(path)
                Study.Records{ni,r,c}=RecoverPaperStrategyRecord(path,d,cases{c},r,seed,population,o.Generations,o.GridStep);
                Study=ResolvePaperStrategyTaskError(Study,ni,r,c,cases{c});
                Study=PaperStrategyOutputs(Study,out);
                SavePaperStudy(fullfile(out,'study.mat'),Study);
            end
            if isempty(Study.Records{ni,r,c})
                if ~o.RetryFailedTasks&&~isempty(Study.Failures{ni,r,c}), continue; end
                Study.AttemptCounts(ni,r,c)=Study.AttemptCounts(ni,r,c)+1;
                taskTimer=tic;
                try
                    [answer,failure]=RunPaperTaskGuard(@() RunPaperStrategyCase(d,cases{c},seed,population,o.Generations,o.GridStep),o.ContinueOnTaskError);
                catch problem
                    failure=struct('Identifier',problem.identifier,'Message',problem.message, ...
                        'Report',getReport(problem,'extended','hyperlinks','off'),'At',datestr(now,30), ...
                        'ElapsedSeconds',toc(taskTimer),'IsGlobalBlocker',PaperTaskFailureIsFatal(problem));
                    Study=RecordPaperStrategyTaskError(Study,ni,r,c,cases{c},seed,failure);
                    Study.Status='stopped_task_error';
                    if failure.IsGlobalBlocker, Study.Status='blocked_global_error'; end
                    Study=PaperStrategyOutputs(Study,out); SavePaperStudy(fullfile(out,'study.mat'),Study);
                    rethrow(problem);
                end
                if isempty(failure)
                    kind='Indirect'; if c<=2, kind='Direct'; end
                    Study.Records{ni,r,c}=answer;
                    Study=ResolvePaperStrategyTaskError(Study,ni,r,c,cases{c});
                    record=struct('N',d.N,'InstanceId',sprintf('FixedData_N%d',d.N),'Case',cases{c}, ...
                        'Run',r,'Seed',seed,'Answer',answer,'Diagnostics',JRDAnalyzeSolution(d,answer,kind));
                    SavePaperStrategyRecord(path,record);
                    fprintf('Experiment4 N=%d run=%d %s TC=%.10f runtime=%.3fs\n', ...
                        d.N,r,cases{c},answer.TotalCost,answer.RuntimeSeconds);
                else
                    Study=RecordPaperStrategyTaskError(Study,ni,r,c,cases{c},seed,failure);
                    fprintf('Experiment4 TASK_FAILED N=%d run=%d %s %s: %s\n',d.N,r,cases{c},failure.Identifier,failure.Message);
                end
                Study=PaperStrategyOutputs(Study,out);
                SavePaperStudy(fullfile(out,'study.mat'),Study);
                newSolves=newSolves+1;
                if newSolves>=o.MaxNewSolves&&any(cellfun(@isempty,Study.Records(:)))
                    Study.Status='paused_solver_boundary'; Study=PaperStrategyOutputs(Study,out);
                    SavePaperStudy(fullfile(out,'study.mat'),Study); return;
                end
            elseif ~isfile(path)
                answer=Study.Records{ni,r,c}; kind='Indirect'; if c<=2, kind='Direct'; end
                record=struct('N',d.N,'InstanceId',sprintf('FixedData_N%d',d.N),'Case',cases{c}, ...
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
