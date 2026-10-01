function [Queue,out]=Run_Unattended_Preliminary_Queue(varargin)
%RUN_UNATTENDED_PRELIMINARY_QUEUE Finish readable pilots before a soft deadline.
% The deadline chooses NEW stages only; it never interrupts a solver, changes
% a frequency domain or participates in judging strategy cost.
root=Setup_JRD(); p=inputParser;
addParameter(p,'ProfileDir','',@(x) ischar(x)||isstring(x));
addParameter(p,'Deadline','2026-10-01 16:50:00',@(x) ischar(x)||isstring(x));
addParameter(p,'OutputRoot',fullfile(root,'Results_Unattended'),@(x) ischar(x)||isstring(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x));
addParameter(p,'DryRun',false,@(x) islogical(x)&&isscalar(x));
addParameter(p,'SafetyFactor',1.7,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=1);
parse(p,varargin{:}); options=p.Results;
config=rmfield(options,{'OutputRoot','ResumeDir','DryRun'});
deadline=datetime(config.Deadline,'InputFormat','yyyy-MM-dd HH:mm:ss');
assert(isfolder(config.ProfileDir),'JRD:InvalidData','A completed profiling directory is required.');
profileLoaded=load(fullfile(config.ProfileDir,'profile.mat'),'Study'); profile=profileLoaded.Study;
assert(profile.AllJobsCompleted,'JRD:InvalidData','Finish requested profiling before the queue.');
assert(options.DryRun||~isfield(profile,'SyntheticFixture')||~profile.SyntheticFixture, ...
    'JRD:InvalidData','Synthetic test timings must never schedule real experiment jobs.');
if isempty(options.ResumeDir)
    if ~isfolder(options.OutputRoot), mkdir(options.OutputRoot); end
    out=tempname(char(options.OutputRoot)); mkdir(out);
    [gitStatus,gitCommit]=system(sprintf('git -C "%s" rev-parse HEAD',root));
    assert(gitStatus==0,'JRD:SourceRevision','Unable to record Git revision.');
    Queue=struct('Status','planned','StartedAt',datestr(now,30),'Config',config, ...
        'GitCommit',strtrim(gitCommit),'SourceManifest',JRDProjectManifest(root), ...
        'Source',PaperSourceSnapshot(root),'Stages',{{}},'Errors',{{}},'Skipped',{{}}, ...
        'ProfileDirectory',char(config.ProfileDir),'Deadline',char(config.Deadline), ...
        'CommittedUniqueTasks',0,'CurrentStage','','CurrentRoot','','CurrentExpectedTasks',0, ...
        'CurrentReusedTasks',0,'EstimatedRemainingSeconds',0,'FormalBenchmark',false, ...
        'BudgetExplanation','12-run G100/P4N calibration, then same-budget 36/108 extension; Exp3/4 reference budget if feasible, shared pilot budget otherwise');
    copyfile(fullfile(config.ProfileDir,'timings.csv'),fullfile(out,'profiling_summary.csv'));
else
    out=char(options.ResumeDir); loaded=load(fullfile(out,'queue.mat'),'Study'); Queue=loaded.Study;
    assert(isequaln(Queue.Config,config)&&isequal(Queue.SourceManifest,JRDProjectManifest(root)), ...
        'JRD:StaleCheckpoint','Queue configuration, data or source changed.');
end
persist(Queue,out);
fprintf('UNATTENDED_OUTPUT=%s\n',out);
if options.DryRun
    Queue.Status='dry_run_validated'; persist(Queue,out); return;
end
if ~isempty(options.ResumeDir)&&ismember(Queue.Status,{'complete','completed_with_failures'})
    persist(Queue,out); return;
end
baseArgs={'NList',[30 50 100],'InstanceSource','generated','Instances',1,'Runs',1, ...
    'SFactors',0.3,'BaseInstanceSeed',20261001,'BaseSeed',20261001, ...
    'Generations',100,'PopulationFactor',4,'MinimumPopulation',40,'GridStep',0.001};
try
    if seconds(deadline-datetime('now'))<900
        Queue.Status='not_started_insufficient_window'; persist(Queue,out); return;
    end
    [Queue,calibration,calStage]=invokeStage(Queue,out,'Exp2_Calibration_12', ...
        @Run_Paper_Experiment2_DirectPerformance,baseArgs,12,0,[]);
    Queue.Exp2Directory=calStage.Directory;
    calibrationWall=calStage.WallClockSeconds;
    % Includes actual CSV/Study/figure overhead, not theoretical operator counts.
    calibrationWall=max(calibrationWall,sum(calibration.RawTable.RuntimeSeconds));
    if ~isfield(Queue,'Exp2Choice')
        remaining=seconds(deadline-datetime('now'))-900;
        estimate108=8*calibrationWall*config.SafetyFactor;
        estimate36=2*calibrationWall*config.SafetyFactor;
        count=12; instances=1; runs=1;
        calibrationComplete=strcmp(calibration.Status,'complete')&&calStage.CompletedTasks==12;
        if calibrationComplete&&estimate108<=remaining, count=108; instances=3; runs=3;
        elseif calibrationComplete&&estimate36<=remaining, count=36; instances=3; runs=1; end
        reason='actual complete 12-task pilot plus 70% runtime margin; 15 minutes retained for report';
        if ~calibrationComplete, reason='calibration has missing/failed tasks; do not extrapolate incomplete timing or expand'; end
        Queue.Exp2Choice=struct('TotalTasks',count,'Instances',instances,'Runs',runs, ...
            'CalibrationWallSeconds',calibrationWall,'Additional108EstimateSeconds',estimate108, ...
            'Additional36EstimateSeconds',estimate36,'SafetyFactor',config.SafetyFactor, ...
            'ChosenAt',datestr(now,30),'Reason',reason);
        persist(Queue,out);
    end
    choice=Queue.Exp2Choice;
    if choice.TotalTasks>12
        Queue.EstimatedRemainingSeconds=choice.Additional36EstimateSeconds;
        if choice.TotalTasks==108, Queue.EstimatedRemainingSeconds=choice.Additional108EstimateSeconds; end
        targetRoot=fullfile(out,sprintf('Exp2_Selected_%d',choice.TotalTasks));
        existing=findStudy(targetRoot);
        if isempty(existing)
            [~,existing]=Extend_Paper_Experiment2_Preliminary(Queue.Exp2Directory, ...
                'Instances',choice.Instances,'Runs',choice.Runs,'OutputRoot',targetRoot);
        end
        modified=replaceArgument(baseArgs,'Instances',choice.Instances);
        modified=replaceArgument(modified,'Runs',choice.Runs);
        [Queue,~,expandedStage]=invokeStage(Queue,out,sprintf('Exp2_Selected_%d',choice.TotalTasks), ...
            @Run_Paper_Experiment2_DirectPerformance,modified,choice.TotalTasks,12,existing);
        Queue.Exp2Directory=expandedStage.Directory; persist(Queue,out);
    end
    % Reference Exp3 estimate uses measured Evolutionary N30/50/100 and AHDE
    % N100 for every smaller AHDE scale: conservative, not an equality claim.
    referenceDirect=profileSeconds(profile,'EvolutionaryX',30)+ ...
        profileSeconds(profile,'EvolutionaryX',50)+profileSeconds(profile,'EvolutionaryX',100);
    ahde100=profileSeconds(profile,'TeacherAHDE',100);
    referenceSeed=referenceDirect+max(20,0.5*profileSeconds(profile,'EvolutionaryX',30))+4*ahde100;
    pilotSeed=calibrationWall+4*max(2,0.08*ahde100); % measured pilot all-alg total overestimates its Direct portion
    if ~isfield(Queue,'Exp3Choice')
        Queue.Exp3Choice=chooseStrategyBudget(referenceSeed,pilotSeed,[5 3], ...
            seconds(deadline-datetime('now'))-900,config.SafetyFactor);
        persist(Queue,out);
    end
    if Queue.Exp3Choice.Runs>0
        selected=Queue.Exp3Choice;
        Queue.EstimatedRemainingSeconds=selected.EstimatedSeconds;
        args={'NList',[10 30 50 100],'Runs',selected.Runs,'BaseSeed',20261002, ...
            'Generations',selected.Generations,'PopulationFactor',selected.PopulationFactor, ...
            'MinimumPopulation',40,'GridStep',0.001};
        [Queue,~,strategyStage]=invokeStage(Queue,out,'Exp3_Preliminary', ...
            @Run_Paper_Experiment3_StrategyComparison,args,8*selected.Runs,0,[]);
        Queue.Exp3Directory=strategyStage.Directory; persist(Queue,out);
    else
        Queue.Skipped{end+1}='Exp3: insufficient predicted time for a complete 3-seed study'; persist(Queue,out);
    end
    if ~isfield(Queue,'Exp4Choice')
        Queue.Exp4Choice=chooseStrategyBudget(2*referenceSeed,2*pilotSeed,[3 2 1], ...
            seconds(deadline-datetime('now'))-900,config.SafetyFactor);
        persist(Queue,out);
    end
    if Queue.Exp4Choice.Runs>0
        selected=Queue.Exp4Choice;
        Queue.EstimatedRemainingSeconds=selected.EstimatedSeconds;
        args={'NList',[10 30 50 100],'Runs',selected.Runs,'BaseSeed',20261003, ...
            'Generations',selected.Generations,'PopulationFactor',selected.PopulationFactor, ...
            'MinimumPopulation',40,'GridStep',0.001};
        [Queue,~,coordinationStage]=invokeStage(Queue,out,'Exp4_Preliminary', ...
            @Run_Paper_Experiment4_Coordination,args,16*selected.Runs,0,[]);
        Queue.Exp4Directory=coordinationStage.Directory; persist(Queue,out);
    else
        Queue.Skipped{end+1}='Exp4: insufficient predicted time for a complete 1-seed study'; persist(Queue,out);
    end
    Queue.Status='complete';
    for j=1:numel(Queue.Stages)
        if ~strcmp(Queue.Stages{j}.Status,'complete'), Queue.Status='completed_with_failures'; end
    end
    Queue.CompletedAt=datestr(now,30); Queue.CurrentStage=''; Queue.CurrentRoot='';
    Queue.EstimatedRemainingSeconds=0; persist(Queue,out);
    fprintf('UNATTENDED_DONE status=%s completed_unique=%d\n',Queue.Status,Queue.CommittedUniqueTasks);
catch problem
    Queue.Status='blocked_global_error'; Queue.Blocker=struct('Identifier',problem.identifier, ...
        'Message',problem.message,'Report',getReport(problem,'extended','hyperlinks','off'),'At',datestr(now,30));
    Queue.Errors{end+1}=Queue.Blocker; persist(Queue,out); rethrow(problem);
end
end

function [Queue,Study,stage]=invokeStage(Queue,out,name,runner,args,total,reused,existing)
found=[];
for j=1:numel(Queue.Stages)
    if strcmp(Queue.Stages{j}.Name,name), found=j; break; end
end
if ~isempty(found)&&ismember(Queue.Stages{found}.Status,{'complete','completed_with_failures'})
    stage=Queue.Stages{found}; saved=load(fullfile(stage.Directory,'study.mat'),'Study'); Study=saved.Study; return;
end
stageRoot=fullfile(out,name); if ~isfolder(stageRoot), mkdir(stageRoot); end
if isempty(existing), existing=findStudy(stageRoot); end
if isempty(found)
    found=numel(Queue.Stages)+1;
    Queue.Stages{found}=struct('Name',name,'Status','running','Root',stageRoot,'Directory','', ...
        'ExpectedTasks',total,'ReusedTasks',reused,'CompletedTasks',0,'FailedTasks',0, ...
        'WallClockSeconds',0,'StartedAt',datestr(now,30),'BudgetArguments',{args});
end
Queue.Status='running'; Queue.CurrentStage=name; Queue.CurrentRoot=stageRoot;
Queue.CurrentExpectedTasks=total; Queue.CurrentReusedTasks=reused;
Queue.CurrentStageStartedAt=datestr(now,30);
persist(Queue,out); wall=tic;
if isempty(existing)
    [Study,directory]=runner(args{:},'OutputRoot',stageRoot,'ContinueOnTaskError',true,'RetryFailedTasks',true);
else
    Queue.CurrentRoot=existing; persist(Queue,out);
    [Study,directory]=runner(args{:},'ResumeDir',existing,'ContinueOnTaskError',true,'RetryFailedTasks',true);
end
stage=Queue.Stages{found}; stage.Status=Study.Status; stage.Directory=directory;
stage.WallClockSeconds=stage.WallClockSeconds+toc(wall);
stage.CompletedTasks=sum(~cellfun(@isempty,Study.Records(:)));
if isfield(Study,'TaskStatusTable'), statusTable=Study.TaskStatusTable;
else, statusTable=Study.TaskTable; end
stage.FailedTasks=sum(strcmp(statusTable.Status,'failed'));
if isfield(Study,'ReusedRecords'), stage.ReusedTasks=Study.ReusedRecords; end
stage.CompletedAt=datestr(now,30); Queue.Stages{found}=stage;
Queue.CommittedUniqueTasks=0;
for j=1:numel(Queue.Stages)
    Queue.CommittedUniqueTasks=Queue.CommittedUniqueTasks+max(0,Queue.Stages{j}.CompletedTasks-Queue.Stages{j}.ReusedTasks);
end
Queue.CurrentStage=''; Queue.CurrentRoot='';
persist(Queue,out);
end

function directory=findStudy(root)
directory=''; if ~isfolder(root), return; end
files=dir(fullfile(root,'**','study.mat'));
if isempty(files), return; end
[~,index]=max([files.datenum]); directory=files(index).folder;
end

function args=replaceArgument(args,name,value)
index=find(strcmp(args,name),1); assert(~isempty(index)); args{index+1}=value;
end

function value=profileSeconds(profile,name,n)
value=NaN;
for j=1:numel(profile.Records)
    r=profile.Records{j};
    if strcmp(r.Algorithm,name)&&r.N==n, value=r.WallClockSeconds; return; end
end
assert(isfinite(value),'JRD:InvalidData','Missing actual %s N%d profiling.',name,n);
end

function choice=chooseStrategyBudget(reference,pilot,seeds,available,safety)
choice=struct('Runs',0,'Generations',0,'PopulationFactor',0,'EstimatedSeconds',0, ...
    'Reason','no complete stage predicted to fit');
for budget=1:2
    perSeed=reference; generations=500; factor=10;
    if budget==2, perSeed=pilot; generations=100; factor=4; end
    for runs=seeds
        estimate=perSeed*runs*safety;
        if estimate<=available
            choice=struct('Runs',runs,'Generations',generations,'PopulationFactor',factor, ...
                'EstimatedSeconds',estimate,'Reason','same strategy-side generation/population budget, measured timing with safety margin'); return;
        end
    end
end
end

function persist(Queue,out)
SavePaperStudy(fullfile(out,'queue.mat'),Queue);
small=rmfield(Queue,{'Source','SourceManifest'});
path=fullfile(out,'queue_state.json'); temporary=[tempname(out),'.json'];
fid=fopen(temporary,'w','n','UTF-8'); assert(fid>=0); fprintf(fid,'%s',jsonencode(small)); fclose(fid);
[ok,message]=movefile(temporary,path,'f'); assert(ok,'JRD:ResultWrite','%s',message);
Write_Unattended_Preliminary_Report(Queue,out);
end
