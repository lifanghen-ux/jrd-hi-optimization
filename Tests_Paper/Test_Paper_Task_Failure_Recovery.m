function report=Test_Paper_Task_Failure_Recovery(varargin)
%TEST_PAPER_TASK_FAILURE_RECOVERY Local failures must not erase good tasks.
% Uses one-generation jobs and synthetic task exceptions in new test folders.
% It never changes the original model, datasets, or teacher solver.
root=Setup_JRD(); p=inputParser;
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:});
dest=char(p.Results.OutputRoot);
if isempty(dest), dest=fullfile(root,'Validation_Paper','Task_Failure_Recovery'); end
if ~isfolder(dest), mkdir(dest); end
out=tempname(dest); mkdir(out); wall=tic;
originalRng=rng; cleanup=onCleanup(@() rng(originalRng)); %#ok<NASGU>

[value,failure]=RunPaperTaskGuard(@() 73,true);
assert(value==73&&isempty(failure));
[value,failure]=RunPaperTaskGuard(@() throwTaskFixture('JRD:InjectedTaskFailure','synthetic independent task failure'),true);
assert(isempty(value)&&isstruct(failure)&&strcmp(failure.Identifier,'JRD:InjectedTaskFailure')&& ...
    contains(failure.Report,'synthetic independent task failure')&&~failure.IsGlobalBlocker);
assertThrows(@() RunPaperTaskGuard(@() throwTaskFixture('JRD:InjectedTaskFailure','strict mode'),false), ...
    'JRD:InjectedTaskFailure');
fatalIds={'JRD:CostMismatch','JRD:InvalidData','JRD:StaleCheckpoint', ...
    'JRD:StaleRawRecord','JRD:CheckpointSchema','JRD:FrequencyBounds','MATLAB:UndefinedFunction'};
for k=1:numel(fatalIds)
    id=fatalIds{k};
    assert(PaperTaskFailureIsFatal(MException(id,'synthetic integrity blocker')));
    assertThrows(@() RunPaperTaskGuard(@() throwTaskFixture(id,'synthetic integrity blocker'),true),id);
end

exp2={'NList',10,'Instances',1,'Runs',2,'InstanceSource','generated','SFactors',0.3, ...
    'BaseInstanceSeed',764,'BaseSeed',487,'Generations',1,'PopulationFactor',1, ...
    'MinimumPopulation',8,'GridStep',0.01,'VNDMaxGroupEvaluations',20, ...
    'VNDStarts',2,'VNDILSIterations',0};
strategy={'NList',10,'Runs',2,'BaseSeed',489,'Generations',1, ...
    'PopulationFactor',1,'MinimumPopulation',8,'GridStep',0.01};
runners={@Run_Paper_Experiment2_DirectPerformance, ...
    @Run_Paper_Experiment3_StrategyComparison,@Run_Paper_Experiment4_Coordination};
allArgs={exp2,strategy,strategy}; checks=cell(1,3);
for kind=1:3
    runner=runners{kind}; args=allArgs{kind};
    [partial,path]=runner(args{:},'OutputRoot',out,'MaxNewSolves',1,'ContinueOnTaskError',true);
    assert(startsWith(partial.Status,'paused_')&&height(partial.RawTable)==1);
    assert(~isempty(partial.Records{1,1,1})&&isempty(partial.Records{1,1,2}));
    firstSuccess=partial.Records{1,1,1}; event=failure;
    event.N=10; event.Run=1; event.Attempt=1; event.Resolved=false; event.ResolvedAt='';
    if kind==1
        event.InstanceID=partial.Scenarios(1).InstanceID;
        event.Algorithm=partial.Algorithms{2}; event.AlgorithmSeed=firstSuccess.Seed;
        partial.Failures{1,1,2}=event; partial.ErrorRecords=event;
        if isfield(partial,'AttemptCounts'), partial.AttemptCounts(1,1,2)=1; end
    else
        if kind==3, names=partial.Cases; else, names=partial.Strategies; end
        partial.AttemptCounts(1,1,2)=1;
        partial=RecordPaperStrategyTaskError(partial,1,1,2,names{2},firstSuccess.Seed,failure);
    end
    SavePaperStudy(fullfile(path,'study.mat'),partial);

    % Independent remaining calls run while this single failure is retained.
    [withFailure,~]=runner(args{:},'ResumeDir',path, ...
        'ContinueOnTaskError',true,'RetryFailedTasks',false);
    expected=numel(withFailure.Records);
    assert(strcmp(withFailure.Status,'completed_with_failures')&& ...
        height(withFailure.RawTable)==expected-1&&isempty(withFailure.Records{1,1,2})&& ...
        isequaln(firstSuccess,withFailure.Records{1,1,1}), ...
        'JRD:TaskFailureContinuation','A single failure prevented independent work or erased a successful task.');
    assertTaskCSV(path,expected,1);
    assert(numel(withFailure.ErrorRecords)==1&&~withFailure.ErrorRecords(1).Resolved);
    if kind==1
        assert(~any(withFailure.RawTable.InstanceComplete));
        mask=strcmp(withFailure.InstanceSummaryTable.Algorithm,withFailure.Algorithms{2});
        assert(withFailure.InstanceSummaryTable.Runs(mask)==1);
    else
        assert(sum(withFailure.RawTable.PairComplete)==(expected/2)&& ...
            all(withFailure.SummaryTable.Runs==1));
        if kind==2, assert(height(withFailure.PairedComparison)==1);
        else, assert(height(withFailure.PairedSavings)==1); end
    end

    % A skip-failed resume is idempotent; it does not repeat any successful call.
    [skipReplay,~]=runner(args{:},'ResumeDir',path, ...
        'ContinueOnTaskError',true,'RetryFailedTasks',false);
    assert(isequaln(withFailure.Records,skipReplay.Records)&& ...
        isequaln(withFailure.RawTable,skipReplay.RawTable)&&numel(skipReplay.ErrorRecords)==1);

    % Retry executes only the missing failed task and retains its error history.
    [recovered,~]=runner(args{:},'ResumeDir',path, ...
        'ContinueOnTaskError',true,'RetryFailedTasks',true);
    assert(strcmp(recovered.Status,'complete')&&height(recovered.RawTable)==expected&& ...
        all(~cellfun(@isempty,recovered.Records(:)))&& ...
        all(cellfun(@isempty,recovered.Failures(:)))&&numel(recovered.ErrorRecords)==1&& ...
        recovered.ErrorRecords(1).Resolved&&~isempty(recovered.ErrorRecords(1).ResolvedAt));
    for task=1:numel(withFailure.Records)
        if ~isempty(withFailure.Records{task})
            assert(isequaln(withFailure.Records{task},recovered.Records{task}), ...
                'JRD:SuccessfulTaskRepeated','Retry changed a previously successful solution or its recorded wall time.');
        end
    end
    assertTaskCSV(path,expected,0);
    errors=readtable(fullfile(path,'errors.csv'));
    assert(height(errors)==1&&errors.Resolved(1));
    if kind==1
        assert(all(recovered.RawTable.InstanceComplete));
    else
        assert(all(recovered.RawTable.PairComplete)&&all(recovered.SummaryTable.Runs==2));
    end
    % Integrity checks remain global even when the continue policy is enabled.
    changed=args; idx=find(strcmp(changed(1:2:end),'Generations')); changed{2*idx}=2;
    assertThrows(@() runner(changed{:},'ResumeDir',path,'ContinueOnTaskError',true), ...
        'JRD:StaleCheckpoint');
    checks{kind}=struct('OutputDir',path,'ExpectedTasks',expected, ...
        'FailedTaskCountBeforeRetry',1,'SuccessesAfterRetry',height(recovered.RawTable), ...
        'SuccessfulTasksUnchanged',true,'ErrorHistoryRetained',true);
end
report=struct('Status','PASS','FatalIdentifiers',{fatalIds},'Experiments',{checks}, ...
    'RuntimeSeconds',toc(wall),'OutputDir',out,'FormalExperimentRun',false, ...
    'CompletedAt',datestr(now,30));
save(fullfile(out,'task_failure_recovery.mat'),'report','-v7'); disp(report);
end

function assertTaskCSV(path,expected,failed)
for file={'task_status.csv','failed_tasks.csv','errors.csv','raw_results.csv'}
    assert(isfile(fullfile(path,file{1})),'JRD:TaskCSV','Missing task-level output.');
end
tasks=readtable(fullfile(path,'task_status.csv'));
bad=readtable(fullfile(path,'failed_tasks.csv'));
assert(height(tasks)==expected&&height(bad)==failed&& ...
    sum(strcmp(tasks.Status,'failed'))==failed&&sum(strcmp(tasks.Status,'complete'))==expected-failed&& ...
    ~any(strcmp(tasks.Status,'pending')),'JRD:TaskCSV','Task statuses do not match successful and failed calls.');
if failed>0, assert(all(strcmp(bad.ErrorIdentifier,'JRD:InjectedTaskFailure'))); end
end

function assertThrows(call,identifier)
threw=false;
try, call(); catch exception, threw=strcmp(exception.identifier,identifier); end
assert(threw,'JRD:GlobalBlocker','Expected exception was swallowed or changed.');
end

function value=throwTaskFixture(identifier,message)
% Declare the output expected by taskFunction(). The error itself is invoked
% as a statement so MATLAB does not replace its identifier with maxlhs.
value=[]; %#ok<NASGU>
error(identifier,'%s',message);
end
