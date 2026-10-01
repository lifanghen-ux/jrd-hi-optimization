function [Study,out]=Run_Paper_Experiment2_DirectPerformance(varargin)
%RUN_PAPER_EXPERIMENT2_DIRECTPERFORMANCE Common-objective multi-instance study.
% 'paper-reference' supports published 500-generation/10N-population design;
% it is a reference configuration, not a final validated experimental budget.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
seed=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0&&x<=2^32-1;
optionalInteger=@(x) isempty(x)||integer(x);
addParameter(p,'Design','pilot',@(x) ischar(x)&&ismember(x,{'pilot','paper-reference'}));
addParameter(p,'NList',[30 50 100],@(x) isnumeric(x)&&isvector(x)&&all(ismember(x,[10 30 50 100]))&&numel(unique(x))==numel(x));
addParameter(p,'InstanceSource','generated',@(x) ischar(x)&&ismember(x,{'generated','fixed'}));
addParameter(p,'Instances',[],optionalInteger); addParameter(p,'Runs',[],optionalInteger);
addParameter(p,'SFactors',[],@(x) isempty(x)||(isnumeric(x)&&isvector(x)&&all(isfinite(x))&&all(x>0)&&numel(unique(x))==numel(x)));
addParameter(p,'BaseInstanceSeed',20261001,seed); addParameter(p,'BaseSeed',20260919,seed);
addParameter(p,'Generations',[],optionalInteger); addParameter(p,'PopulationFactor',[],optionalInteger);
addParameter(p,'MinimumPopulation',40,@(x) integer(x)&&x>=4);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'VNDMaxGroupEvaluations',[],@(x) isempty(x)||integer(x)||(isnumeric(x)&&isscalar(x)&&x==Inf));
addParameter(p,'VNDStarts',4,@(x) integer(x)&&x>=2);
addParameter(p,'VNDILSIterations',10,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0);
addParameter(p,'BestRelativeTolerance',1e-9,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0);
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
addParameter(p,'MaxNewSolves',Inf,@(x) (isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0)||(isnumeric(x)&&isscalar(x)&&x==Inf));
addParameter(p,'ContinueOnTaskError',false,@(x) islogical(x)&&isscalar(x));
addParameter(p,'RetryFailedTasks',true,@(x) islogical(x)&&isscalar(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
if strcmp(o.Design,'paper-reference')
    defaults=struct('Instances',20,'Runs',1,'SFactors',[0.1 0.2 0.3 0.4 0.5],'Generations',500,'PopulationFactor',10);
else
    defaults=struct('Instances',3,'Runs',3,'SFactors',0.3,'Generations',100,'PopulationFactor',4);
end
for field=fieldnames(defaults)'
    if isempty(o.(field{1})), o.(field{1})=defaults.(field{1}); end
end
if strcmp(o.InstanceSource,'fixed')
    assert(o.Instances==1&&isequal(o.SFactors,0.3),'JRD:FixedInstanceDesign', ...
        'Fixed Data_N*.mat mode requires Instances=1 and SFactors=0.3; fixed inputs are never rescaled.');
end
algorithms={'EvolutionaryX','GA_Direct','JADE_Direct','MS_VND_Direct'};
config=rmfield(o,{'OutputRoot','ResumeDir','MaxNewSolves','ContinueOnTaskError','RetryFailedTasks'}); manifest=JRDProjectManifest(root);
if isempty(o.ResumeDir)
    out=CreatePaperOutput(root,'Experiment2_DirectPerformance',char(o.OutputRoot));
    [scenarios,inputs]=makeScenarios();
    mkdir(fullfile(out,'instances'));
    for sx=1:numel(scenarios)
        data=inputs{sx}; generation=scenarios(sx).Generation; %#ok<NASGU>
        save(fullfile(out,'instances',[scenarios(sx).InstanceID '.mat']),'data','generation','-v7');
    end
    Study=struct('SchemaVersion',2,'Experiment','Direct algorithm performance on a common grid objective', ...
        'Status','running','Config',config,'Algorithms',{algorithms},'Manifest',manifest, ...
        'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
        'Scenarios',scenarios,'Inputs',{inputs}, ...
        'Records',{cell(numel(scenarios),o.Runs,numel(algorithms))}, ...
        'BaselineRationale',['GA/JADE are Direct partition adapters retaining their original search operators but using N active labels and the common grid fitness. ' ...
        'VND reuses the existing structural neighborhoods with the same grid kernel. Historical 2N native algorithms remain separate.'], ...
        'BudgetCaveat',['Equal population/generations controls evolutionary outer layers only; it is not equal work. ' ...
        'VND uses a preset uncached group-evaluation cap independent of observed EvolutionaryX performance and preset starts/ILS. ' ...
        'Report actual group requests/evaluations, partition evaluations and wall-clock search/postprocess separately.'], ...
        'MetricDefinition',['Reference is the lowest CommonGridTC among all algorithms and algorithm seeds on the SAME InstanceID. ' ...
        'BestCount counts instances where an algorithm best matches reference within BestRelativeTolerance; RunBestCount counts individual matching runs. ' ...
        'AverageGap averages per-instance mean run gaps. StdTC/CVPercent are within-instance random-seed statistics. Reference is BKS, not global certificate.']);
else
    out=char(o.ResumeDir); loaded=load(fullfile(out,'study.mat'),'Study'); Study=loaded.Study;
    assert(Study.SchemaVersion==2&&isequaln(Study.Config,config)&&isequal(Study.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Resume configuration, source, fixed data, or schema changed.');
end
if ~isfield(Study,'ErrorRecords'), Study.ErrorRecords=struct([]); end
if ~isfield(Study,'Failures'), Study.Failures=cell(size(Study.Records)); end
if ~isfield(Study,'AttemptCounts')
    Study.AttemptCounts=double(~cellfun(@isempty,Study.Records));
end
for attemptSlot=1:numel(Study.Failures)
    if ~isempty(Study.Failures{attemptSlot})&&isfield(Study.Failures{attemptSlot},'Attempt')
        Study.AttemptCounts(attemptSlot)=max(Study.AttemptCounts(attemptSlot),Study.Failures{attemptSlot}.Attempt);
    end
end
Study.TaskSeedPolicy='instance_identity_v1';
Study.ExecutionPolicy=struct('ContinueOnTaskError',o.ContinueOnTaskError,'RetryFailedTasks',o.RetryFailedTasks);
Study.Status='running'; SavePaperStudy(fullfile(out,'study.mat'),Study); newSolves=0;
if o.MaxNewSolves==0
    Study.Status='paused_by_task_limit'; exportStudy(); SavePaperStudy(fullfile(out,'study.mat'),Study); return;
end
for si=1:numel(Study.Scenarios)
    scenario=Study.Scenarios(si); d=Study.Inputs{si};
    population=max(o.MinimumPopulation,o.PopulationFactor*d.N);
    presetVNDBudget=o.VNDMaxGroupEvaluations;
    if isempty(presetVNDBudget), presetVNDBudget=population*(o.Generations+1); end
    for r=1:o.Runs
        algorithmSeed=PaperExperiment2AlgorithmSeed(d.N,scenario.InstanceSeed,r,o.BaseSeed,o.InstanceSource);
        order=circshift(1:numel(algorithms),[0 mod(si+r-2,numel(algorithms))]);
        for ai=order
            if ~isempty(Study.Records{si,r,ai}), continue; end
            if ~o.RetryFailedTasks&&~isempty(Study.Failures{si,r,ai}), continue; end
            rawPath=fullfile(out,'raw',sprintf('%s_%s_run%03d.mat',scenario.InstanceID,algorithms{ai},r));
            recoveringRaw=isfile(rawPath);
            if ~recoveringRaw
                Study.AttemptCounts(si,r,ai)=Study.AttemptCounts(si,r,ai)+1;
            end
            [answer,taskFailure]=RunPaperTaskGuard(@solveCurrentTask,o.ContinueOnTaskError);
            if ~recoveringRaw, newSolves=newSolves+1; end
            if ~isempty(taskFailure)
                taskFailure.InstanceID=scenario.InstanceID; taskFailure.N=d.N;
                taskFailure.Algorithm=algorithms{ai}; taskFailure.Run=r; taskFailure.AlgorithmSeed=algorithmSeed;
                taskFailure.Attempt=max(1,Study.AttemptCounts(si,r,ai));
                taskFailure.Resolved=false; taskFailure.ResolvedAt='';
                Study.Failures{si,r,ai}=taskFailure;
                if isempty(Study.ErrorRecords), Study.ErrorRecords=taskFailure;
                else, Study.ErrorRecords(end+1)=taskFailure; end
                exportStudy(); SavePaperStudy(fullfile(out,'study.mat'),Study);
                fprintf('Experiment2 FAILED %s %s run=%d [%s]: %s\n', ...
                    scenario.InstanceID,algorithms{ai},r,taskFailure.Identifier,taskFailure.Message);
            else
                if isfield(answer,'RecoveredFromRaw')&&answer.RecoveredFromRaw
                    Study.Records{si,r,ai}=answer; Study.Failures{si,r,ai}=[];
                    resolveErrors(scenario.InstanceID,r,algorithms{ai});
                    exportStudy(); SavePaperStudy(fullfile(out,'study.mat'),Study);
                else
                    record=struct('Scenario',scenario,'Run',r,'Algorithm',algorithms{ai}, ...
                        'AlgorithmSeed',algorithmSeed,'Answer',answer,'Input',d,'Config',config,'Manifest',manifest);
                    outputTimer=tic; SavePaperStrategyRecord(rawPath,record);
                    answer.OutputWriteSeconds=toc(outputTimer); Study.Records{si,r,ai}=answer;
                    Study.Failures{si,r,ai}=[];
                    resolveErrors(scenario.InstanceID,r,algorithms{ai});
                    exportStudy(); SavePaperStudy(fullfile(out,'study.mat'),Study);
                    fprintf('Experiment2 %s %s run=%d CommonGridTC=%.10f search=%.3fs\n', ...
                        scenario.InstanceID,algorithms{ai},r,answer.CommonGridTC,answer.SearchSeconds);
                end
            end
            if newSolves>=o.MaxNewSolves
                Study.Status='paused_by_task_limit';
                exportStudy(); SavePaperStudy(fullfile(out,'study.mat'),Study); return;
            end
        end
    end
end
Study.Status='complete';
if any(~cellfun(@isempty,Study.Failures(:))), Study.Status='completed_with_failures'; end
Study.CompletedAt=datestr(now,30);
exportStudy(); SavePaperStudy(fullfile(out,'study.mat'),Study);
if strcmp(Study.Status,'complete')&&any(~cellfun(@isempty,Study.Records(:))), Plot_Paper_Experiment2(Study,out); end
    function taskAnswer=solveCurrentTask()
            if isfile(rawPath)
                taskLoaded=load(rawPath,'record');
                assert(isfield(taskLoaded,'record')&&isstruct(taskLoaded.record)&& ...
                    all(isfield(taskLoaded.record,{'Config','Manifest','Scenario','Input','Run','AlgorithmSeed','Algorithm','Answer'})), ...
                    'JRD:InvalidRawSchema','Raw record schema is missing required fields.');
                recovered=taskLoaded.record;
                assert(isequaln(recovered.Config,config)&&isequal(recovered.Manifest,manifest)&& ...
                    isequaln(recovered.Scenario,scenario)&&isequaln(recovered.Input,d)&& ...
                    recovered.Run==r&&recovered.AlgorithmSeed==algorithmSeed&&strcmp(recovered.Algorithm,algorithms{ai}), ...
                    'JRD:StaleRawRecord','Raw record input, configuration, source, or task identity changed.');
                taskAnswer=recovered.Answer;
                checked=EvaluateDirectGridPartition(taskAnswer.GroupId,d,'GridStep',o.GridStep);
                assert(abs(checked.TotalCost-taskAnswer.CommonGridTC)<=1e-9*max(1,checked.TotalCost), ...
                    'JRD:StaleRawRecord','Raw record common-grid solution failed recomputation.');
                taskAnswer.RecoveredFromRaw=true; return;
            end
            if ai==1
                taskAnswer=EvolutionaryX_Direct(d,'Seed',algorithmSeed,'PopulationSize',population, ...
                    'Generations',o.Generations,'GridStep',o.GridStep);
                taskAnswer.SearchSeconds=taskAnswer.RuntimeSeconds; taskAnswer.PostprocessSeconds=0;
                if ~isfield(taskAnswer,'PartitionEvaluations')
                    taskAnswer.PartitionEvaluations=population*(taskAnswer.GenerationsCompleted+1) ...
                        +taskAnswer.Options.IntensifyElites*taskAnswer.Options.IntensifyTrials*taskAnswer.GenerationsCompleted;
                end
                postTimer=tic;
                taskAnswer.NativeContinuousSolution=PartitionCost(taskAnswer.GroupId,d);
                taskAnswer.NativeContinuousTC=taskAnswer.NativeContinuousSolution.TotalCost;
                taskAnswer.PostprocessSeconds=toc(postTimer);
            else
                taskAnswer=RunCommonDirectBaseline(algorithms{ai},d,'Seed',algorithmSeed, ...
                    'PopulationSize',population,'Generations',o.Generations,'GridStep',o.GridStep, ...
                    'VNDMaxGroupEvaluations',presetVNDBudget,'VNDStarts',o.VNDStarts, ...
                    'VNDILSIterations',o.VNDILSIterations);
            end
            validation=tic;
            common=EvaluateDirectGridPartition(taskAnswer.GroupId,d,'GridStep',o.GridStep);
            taskAnswer.ValidationSeconds=toc(validation);
            assert(abs(common.TotalCost-taskAnswer.TotalCost)<=1e-9*max(1,common.TotalCost), ...
                'JRD:CostMismatch','Final common-grid score differs from search objective.');
            taskAnswer.CommonGridTC=common.TotalCost; taskAnswer.CommonGridSolution=common; taskAnswer.TotalCost=common.TotalCost;
            if ~ismember('CommonBestTC',taskAnswer.Convergence.Properties.VariableNames)
                taskAnswer.Convergence.CommonBestTC=taskAnswer.Convergence.BestTC;
            end
            taskAnswer.RuntimeSeconds=taskAnswer.SearchSeconds+taskAnswer.PostprocessSeconds+taskAnswer.ValidationSeconds;
            taskAnswer.InstanceID=scenario.InstanceID; taskAnswer.InstanceSeed=scenario.InstanceSeed; taskAnswer.AlgorithmSeed=algorithmSeed;
            taskAnswer.OutputWriteSeconds=NaN; % available in Study after this raw commit
    end
    function [scenarios,inputs]=makeScenarios()
        scenarios=struct('InstanceID',{},'N',{},'SFactor',{},'Instance',{},'InstanceSeed',{},'Source',{},'Generation',{}); inputs={};
        for ni=1:numel(o.NList)
            for sf=1:numel(o.SFactors)
                for instance=1:o.Instances
                    n=o.NList(ni); instanceSeed=mod(o.BaseInstanceSeed+1000003*n+10007*sf+101*instance,2^32);
                    id=sprintf('N%d_S%03d_Q%02d_I%03d',n,round(100*o.SFactors(sf)),sf,instance);
                    if strcmp(o.InstanceSource,'fixed')
                        original=load(fullfile(root,sprintf('Data_N%d.mat',n)),'data'); data=original.data;
                        generation=struct('Generator','frozen Data_N*.mat','File',sprintf('Data_N%d.mat',n));
                        instanceSeed=NaN; id=sprintf('N%d_FIXED',n);
                    else
                        [data,generation]=GeneratePaperBenchmarkInstance(n,instanceSeed,'SFactor',o.SFactors(sf));
                    end
                    scenarios(end+1)=struct('InstanceID',id,'N',n,'SFactor',o.SFactors(sf), ...
                        'Instance',instance,'InstanceSeed',instanceSeed,'Source',o.InstanceSource,'Generation',generation); %#ok<AGROW>
                    inputs{end+1,1}=data; %#ok<AGROW>
                end
            end
        end
    end
    function exportStudy()
        exportTaskStatus();
        rows={}; convergenceRows={};
        for exportScenario=1:numel(Study.Scenarios)
            sc=Study.Scenarios(exportScenario);
            for rx=1:o.Runs
                for ax=1:numel(algorithms)
                    exportAnswer=Study.Records{exportScenario,rx,ax}; if isempty(exportAnswer), continue; end
                    counter=exportAnswer.Counters;
                    rows(end+1,:)={sc.N,sc.SFactor,sc.InstanceID,sc.Instance,sc.InstanceSeed,algorithms{ax},rx, ...
                        exportAnswer.AlgorithmSeed,exportAnswer.CommonGridTC,exportAnswer.NativeContinuousTC,exportAnswer.SearchSeconds, ...
                        exportAnswer.PostprocessSeconds,exportAnswer.ValidationSeconds,exportAnswer.RuntimeSeconds,exportAnswer.OutputWriteSeconds, ...
                        exportAnswer.CommonGridSolution.GroupCount,max(o.MinimumPopulation,o.PopulationFactor*sc.N),o.Generations, ...
                        exportAnswer.PartitionEvaluations,counter.GroupEvaluations,counter.GroupRequests, ...
                        exportAnswer.CommonGridSolution.OrderingCost,exportAnswer.CommonGridSolution.DeliveryCost, ...
                        exportAnswer.CommonGridSolution.WarehouseHoldingCost,exportAnswer.CommonGridSolution.RetailHoldingCost, ...
                        exportAnswer.CommonGridSolution.PenaltyCost}; %#ok<AGROW>
                    c=exportAnswer.Convergence;
                    for k=1:height(c)
                        exportGeneration=NaN; if ismember('Generation',c.Properties.VariableNames), exportGeneration=c.Generation(k); end
                        groupEvaluations=NaN; if ismember('GroupEvaluations',c.Properties.VariableNames), groupEvaluations=c.GroupEvaluations(k); end
                        unit='generation'; if ax==4, unit='VND checkpoint'; end
                        convergenceRows(end+1,:)={sc.N,sc.SFactor,sc.InstanceID,sc.InstanceSeed,algorithms{ax},rx, ...
                            exportAnswer.AlgorithmSeed,k,unit,exportGeneration,c.ElapsedSeconds(k),c.CommonBestTC(k),groupEvaluations}; %#ok<AGROW>
                    end
                end
            end
        end
        rawNames={'N','SFactor','InstanceID','Instance','InstanceSeed','Algorithm','Run','AlgorithmSeed', ...
            'CommonGridTC','NativeContinuousTC','SearchSeconds','PostprocessSeconds','ValidationSeconds', ...
            'RuntimeSeconds','RawWriteSeconds','GroupCount','PopulationSize','Generations', ...
            'PartitionEvaluations','GroupEvaluations','GroupRequests','OrderingCost','DeliveryCost', ...
            'WarehouseHoldingCost','RetailHoldingCost','PenaltyCost'};
        convNames={'N','SFactor','InstanceID','InstanceSeed','Algorithm','Run','AlgorithmSeed', ...
            'Checkpoint','CheckpointUnit','Generation','ElapsedSeconds','CommonBestTC','GroupEvaluations'};
        if isempty(rows)
            emptyInstanceNames={'N','SFactor','InstanceID','InstanceSeed','Algorithm','Runs','BestTC','MeanTC','MedianTC', ...
                'StdTC','WorstTC','CVPercent','AverageRuntimeSeconds','AverageSearchSeconds','AverageGapPercent', ...
                'BestHit','RunBestCount','ReferenceBestTC'};
            emptySummaryNames={'N','Algorithm','Instances','Runs','AverageRuntimeSeconds','BestCount','RunBestCount', ...
                'AverageGapPercent','AverageWithinInstanceStdTC','AverageWithinInstanceCVPercent','BestTC','MeanTC'};
            Study.RawTable=cell2table(cell(0,numel(rawNames)),'VariableNames',rawNames);
            Study.RawTable.ReferenceBestTC=zeros(0,1); Study.RawTable.GapPercent=zeros(0,1);
            Study.RawTable.IsReferenceBest=false(0,1); Study.RawTable.InstanceComplete=false(0,1);
            Study.InstanceSummaryTable=cell2table(cell(0,numel(emptyInstanceNames)),'VariableNames',emptyInstanceNames);
            Study.SummaryTable=cell2table(cell(0,numel(emptySummaryNames)),'VariableNames',emptySummaryNames);
            Study.ConvergenceTable=cell2table(cell(0,numel(convNames)),'VariableNames',convNames);
            writetable(Study.RawTable,fullfile(out,'raw_results.csv'));
            writetable(Study.InstanceSummaryTable,fullfile(out,'instance_summary.csv'));
            writetable(Study.SummaryTable,fullfile(out,'summary.csv'));
            writetable(Study.ConvergenceTable,fullfile(out,'convergence.csv')); return;
        end
        raw=cell2table(rows,'VariableNames',rawNames);
        raw.ReferenceBestTC=zeros(height(raw),1); raw.GapPercent=zeros(height(raw),1); raw.IsReferenceBest=false(height(raw),1);
        raw.InstanceComplete=false(height(raw),1);
        for exportScenario=1:numel(Study.Scenarios)
            mask=strcmp(raw.InstanceID,Study.Scenarios(exportScenario).InstanceID); if ~any(mask), continue; end
            reference=min(raw.CommonGridTC(mask)); raw.ReferenceBestTC(mask)=reference;
            raw.InstanceComplete(mask)=all(~cellfun(@isempty,reshape(Study.Records(exportScenario,:,:),[],1)));
            raw.GapPercent(mask)=100*(raw.CommonGridTC(mask)-reference)/reference;
            raw.IsReferenceBest(mask)=abs(raw.CommonGridTC(mask)-reference)<=o.BestRelativeTolerance*max(1,abs(reference));
        end
        instanceRows={};
        for exportScenario=1:numel(Study.Scenarios)
            sc=Study.Scenarios(exportScenario);
            for ax=1:numel(algorithms)
                mask=strcmp(raw.InstanceID,sc.InstanceID)&strcmp(raw.Algorithm,algorithms{ax}); if ~any(mask), continue; end
                values=raw.CommonGridTC(mask); sigma=NaN; if numel(values)>1, sigma=std(values); end
                instanceRows(end+1,:)={sc.N,sc.SFactor,sc.InstanceID,sc.InstanceSeed,algorithms{ax},numel(values), ...
                    min(values),mean(values),median(values),sigma,max(values),100*sigma/mean(values), ...
                    mean(raw.RuntimeSeconds(mask)),mean(raw.SearchSeconds(mask)),mean(raw.GapPercent(mask)), ...
                    any(raw.IsReferenceBest(mask)),sum(raw.IsReferenceBest(mask)),raw.ReferenceBestTC(find(mask,1))}; %#ok<AGROW>
            end
        end
        instanceNames={'N','SFactor','InstanceID','InstanceSeed','Algorithm','Runs','BestTC','MeanTC','MedianTC', ...
            'StdTC','WorstTC','CVPercent','AverageRuntimeSeconds','AverageSearchSeconds','AverageGapPercent', ...
            'BestHit','RunBestCount','ReferenceBestTC'};
        instances=cell2table(instanceRows,'VariableNames',instanceNames); summaryRows={};
        for n=unique(instances.N)'
            for ax=1:numel(algorithms)
                mask=instances.N==n&strcmp(instances.Algorithm,algorithms{ax}); if ~any(mask), continue; end
                stds=instances.StdTC(mask); cvs=instances.CVPercent(mask);
                meanStd=NaN; if any(isfinite(stds)), meanStd=mean(stds(isfinite(stds))); end
                meanCV=NaN; if any(isfinite(cvs)), meanCV=mean(cvs(isfinite(cvs))); end
                summaryRows(end+1,:)={n,algorithms{ax},sum(mask),sum(instances.Runs(mask)), ...
                    mean(instances.AverageRuntimeSeconds(mask)),sum(instances.BestHit(mask)),sum(instances.RunBestCount(mask)), ...
                    mean(instances.AverageGapPercent(mask)),meanStd,meanCV,min(instances.BestTC(mask)),mean(instances.MeanTC(mask))}; %#ok<AGROW>
            end
        end
        summaryNames={'N','Algorithm','Instances','Runs','AverageRuntimeSeconds','BestCount','RunBestCount', ...
            'AverageGapPercent','AverageWithinInstanceStdTC','AverageWithinInstanceCVPercent','BestTC','MeanTC'};
        Study.RawTable=raw; Study.InstanceSummaryTable=instances;
        Study.SummaryTable=cell2table(summaryRows,'VariableNames',summaryNames);
        Study.ConvergenceTable=cell2table(convergenceRows,'VariableNames',convNames);
        writetable(Study.RawTable,fullfile(out,'raw_results.csv'));
        writetable(Study.InstanceSummaryTable,fullfile(out,'instance_summary.csv'));
        writetable(Study.SummaryTable,fullfile(out,'summary.csv'));
        writetable(Study.ConvergenceTable,fullfile(out,'convergence.csv'));
    end
    function resolveErrors(instanceID,runNumber,algorithmName)
        for errorIndex=1:numel(Study.ErrorRecords)
            previousError=Study.ErrorRecords(errorIndex);
            if strcmp(previousError.InstanceID,instanceID)&&previousError.Run==runNumber&&strcmp(previousError.Algorithm,algorithmName)
                Study.ErrorRecords(errorIndex).Resolved=true;
                Study.ErrorRecords(errorIndex).ResolvedAt=datestr(now,30);
            end
        end
    end
    function exportTaskStatus()
        statusRows={};
        for statusScenarioIndex=1:numel(Study.Scenarios)
            statusScenario=Study.Scenarios(statusScenarioIndex);
            for statusRun=1:o.Runs
                statusSeed=PaperExperiment2AlgorithmSeed(statusScenario.N,statusScenario.InstanceSeed,statusRun,o.BaseSeed,o.InstanceSource);
                for statusAlgorithm=1:numel(algorithms)
                    status='pending'; errorIdentifier=''; errorMessage='';
                    attempt=Study.AttemptCounts(statusScenarioIndex,statusRun,statusAlgorithm);
                    if ~isempty(Study.Records{statusScenarioIndex,statusRun,statusAlgorithm})
                        status='complete';
                    elseif ~isempty(Study.Failures{statusScenarioIndex,statusRun,statusAlgorithm})
                        status='failed'; statusFailure=Study.Failures{statusScenarioIndex,statusRun,statusAlgorithm};
                        errorIdentifier=statusFailure.Identifier; errorMessage=statusFailure.Message;
                        if isfield(statusFailure,'Attempt'), attempt=max(attempt,statusFailure.Attempt); else, attempt=max(attempt,1); end
                    end
                    statusRows(end+1,:)={statusScenario.N,statusScenario.InstanceID,statusScenario.InstanceSeed, ...
                        algorithms{statusAlgorithm},statusRun,statusSeed,status,errorIdentifier,errorMessage,attempt}; %#ok<AGROW>
                end
            end
        end
        statusNames={'N','InstanceID','InstanceSeed','Algorithm','Run','AlgorithmSeed','Status','ErrorIdentifier','ErrorMessage','Attempt'};
        Study.TaskStatusTable=cell2table(statusRows,'VariableNames',statusNames);
        Study.FailedTaskTable=Study.TaskStatusTable(strcmp(Study.TaskStatusTable.Status,'failed'),:);
        Study.Progress=struct('Expected',height(Study.TaskStatusTable), ...
            'Complete',sum(strcmp(Study.TaskStatusTable.Status,'complete')), ...
            'Failed',sum(strcmp(Study.TaskStatusTable.Status,'failed')), ...
            'Pending',sum(strcmp(Study.TaskStatusTable.Status,'pending')));
        errorRows={};
        for errorIndex=1:numel(Study.ErrorRecords)
            savedError=Study.ErrorRecords(errorIndex);
            errorRows(end+1,:)={savedError.N,savedError.InstanceID,savedError.Algorithm,savedError.Run,savedError.AlgorithmSeed, ...
                savedError.Identifier,savedError.Message,savedError.At,savedError.ElapsedSeconds,savedError.Attempt, ...
                savedError.Resolved,savedError.ResolvedAt,savedError.Report}; %#ok<AGROW>
        end
        errorNames={'N','InstanceID','Algorithm','Run','AlgorithmSeed','Identifier','Message','At','ElapsedSeconds','Attempt','Resolved','ResolvedAt','Report'};
        if isempty(errorRows), errorRows=cell(0,numel(errorNames)); end
        Study.ErrorTable=cell2table(errorRows,'VariableNames',errorNames);
        writetable(Study.TaskStatusTable,fullfile(out,'task_status.csv'));
        writetable(Study.FailedTaskTable,fullfile(out,'failed_tasks.csv'));
        writetable(Study.ErrorTable,fullfile(out,'errors.csv'));
    end
end
