function report=Test_Unattended_Queue(varargin)
%TEST_UNATTENDED_QUEUE Scheduler/report smoke; never invokes a solver task.
% All default profiling numbers below are explicitly synthetic TEST fixtures.
% A supplied completed ProfileDir can additionally exercise the real index.
root=Setup_JRD(); p=inputParser;
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
addParameter(p,'ProfileDir','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
dest=char(o.OutputRoot);
if isempty(dest), dest=fullfile(root,'Validation_Paper','Unattended_Queue_Smoke'); end
if ~isfolder(dest), mkdir(dest); end
out=tempname(dest); mkdir(out); wall=tic;
fixture=fullfile(out,'SYNTHETIC_TEST_PROFILE'); mkdir(fixture);
jobs={'EvolutionaryX',30;'EvolutionaryX',50;'EvolutionaryX',100; ...
    'GA',100;'JADE',100;'VND',100;'TeacherAHDE',100};
records=cell(1,size(jobs,1)); rows=cell(size(jobs,1),10);
for k=1:size(jobs,1)
    n=jobs{k,2};
    records{k}=struct('Algorithm',jobs{k,1},'N',n,'Population',10*n, ...
        'Generations',500,'GridStep',0.001,'Seed',43, ...
        'WallClockSeconds',k,'SolverReportedSeconds',k,'TC',1, ...
        'BudgetDescription','SYNTHETIC TEST FIXTURE ONLY; not measured runtime');
    rows(k,:)={jobs{k,1},n,10*n,500,0.001,43,k,k,1,records{k}.BudgetDescription};
end
Study=struct('Purpose','synthetic scheduler test fixture; never performance evidence', ...
    'Records',{records},'AllJobsCompleted',true,'SyntheticFixture',true); %#ok<NASGU>
SavePaperStudy(fullfile(fixture,'profile.mat'),Study);
timings=cell2table(rows,'VariableNames',{'Algorithm','N','Population','Generations', ...
    'GridStep','Seed','WallClockSeconds','SolverReportedSeconds','TC','BudgetDescription'});
writetable(timings,fullfile(fixture,'timings.csv'));
beforeProfile=JRDFileSHA256(fullfile(fixture,'profile.mat'));
beforeTimings=JRDFileSHA256(fullfile(fixture,'timings.csv'));

[queue,queueDir]=Run_Unattended_Preliminary_Queue('ProfileDir',fixture, ...
    'Deadline','2099-01-01 00:00:00','OutputRoot',out,'DryRun',true);
assert(strcmp(queue.Status,'dry_run_validated')&&isempty(queue.Stages)&& ...
    queue.CommittedUniqueTasks==0&&isempty(queue.Errors), ...
    'JRD:QueueDryRun','DryRun must not start any experimental solver task.');
assertQueueFiles(queueDir);
state=jsondecode(fileread(fullfile(queueDir,'queue_state.json')));
assert(strcmp(state.Status,'dry_run_validated')&&state.CommittedUniqueTasks==0);
saved=load(fullfile(queueDir,'queue.mat'),'Study');
assert(strcmp(saved.Study.Status,queue.Status)&&isequal(saved.Study.SourceManifest,queue.SourceManifest));
assert(strcmp(beforeProfile,JRDFileSHA256(fullfile(fixture,'profile.mat')))&& ...
    strcmp(beforeTimings,JRDFileSHA256(fullfile(fixture,'timings.csv'))));
[replay,replayDir]=Run_Unattended_Preliminary_Queue('ProfileDir',fixture, ...
    'Deadline','2099-01-01 00:00:00','ResumeDir',queueDir,'DryRun',true);
assert(strcmp(replayDir,queueDir)&&strcmp(replay.Status,'dry_run_validated')&& ...
    replay.CommittedUniqueTasks==0&&isempty(replay.Stages));

% Incomplete timing must be rejected before any experimental stage exists.
incomplete=fullfile(out,'INCOMPLETE_TEST_PROFILE'); mkdir(incomplete);
Study.AllJobsCompleted=false; SavePaperStudy(fullfile(incomplete,'profile.mat'),Study);
writetable(timings,fullfile(incomplete,'timings.csv'));
assertThrows(@() Run_Unattended_Preliminary_Queue('ProfileDir',incomplete, ...
    'Deadline','2099-01-01 00:00:00','OutputRoot',out,'DryRun',true),'JRD:InvalidData');

% Exp2 exposes FailedTaskTable while Exp3/4 expose FailedTasks. The readable
% report must handle both without starting an algorithm or loading a solver.
exp2=fullfile(out,'SYNTHETIC_EXP2_FAILED_TASK'); mkdir(exp2);
Study=struct('Status','completed_with_failures','SyntheticFixture',true); %#ok<NASGU>
Study.SummaryTable=table({'fixture_algorithm'},1,'VariableNames',{'Algorithm','SuccessfulRuns'});
Study.FailedTaskTable=table({'JRD:InjectedTaskFailure'},'VariableNames',{'ErrorIdentifier'});
SavePaperStudy(fullfile(exp2,'study.mat'),Study);
queue.Exp2Directory=exp2; queue.Status='completed_with_failures';
queue.Stages={struct('Name','SYNTHETIC_EXP2_ONLY','Status','completed_with_failures', ...
    'CompletedTasks',1,'ExpectedTasks',2,'ReusedTasks',0,'FailedTasks',1, ...
    'WallClockSeconds',0,'Directory',exp2)};
queue.CommittedUniqueTasks=1;
Write_Unattended_Preliminary_Report(queue,queueDir);
markdown=fileread(fullfile(queueDir,'REPORT.md'));
assert(contains(markdown,'Exp2Directory')&&contains(markdown,'未解决失败数：1')&& ...
    contains(markdown,'fixture_algorithm'),'JRD:QueueReport','Exp2 failed-task report was not generated.');
exp3=fullfile(out,'SYNTHETIC_EXP3_FAILED_TASK'); mkdir(exp3);
Study=rmfield(Study,'FailedTaskTable');
Study.FailedTasks=table({'JRD:InjectedTaskFailure'},'VariableNames',{'ErrorIdentifier'});
SavePaperStudy(fullfile(exp3,'study.mat'),Study);
queue.Exp3Directory=exp3;
Write_Unattended_Preliminary_Report(queue,queueDir);
markdown=fileread(fullfile(queueDir,'REPORT.md'));
assert(contains(markdown,'Exp3Directory')&&numel(strfind(markdown,'未解决失败数：1'))==2);

% Parse the monitor without executing its polling loop or launching services.
script=fullfile(root,'Paper_Experiments','Watch_JRD_Preliminary_Queue.ps1');
escaped=strrep(script,'''','''''');
ps=sprintf(['$syntaxTokens=$null; $syntaxErrors=$null; ' ...
    '[System.Management.Automation.Language.Parser]::ParseFile(''%s'',[ref]$syntaxTokens,[ref]$syntaxErrors) | Out-Null; ' ...
    'if($syntaxErrors.Count -gt 0){$syntaxErrors | Format-List;exit 1}; Write-Output ''POWERSHELL_SYNTAX_PASS'''],escaped);
command=sprintf('powershell.exe -NoLogo -NoProfile -NonInteractive -Command "%s"',ps);
[syntaxCode,syntaxOutput]=system(command);
assert(syntaxCode==0&&contains(syntaxOutput,'POWERSHELL_SYNTAX_PASS'), ...
    'JRD:MonitorSyntax','Monitor PowerShell parsing failed: %s',syntaxOutput);

realQueueDir='';
if ~isempty(o.ProfileDir)
    source=char(o.ProfileDir); profileHash=JRDFileSHA256(fullfile(source,'profile.mat'));
    timingHash=JRDFileSHA256(fullfile(source,'timings.csv'));
    [realQueue,realQueueDir]=Run_Unattended_Preliminary_Queue('ProfileDir',source, ...
        'Deadline','2099-01-01 00:00:00','OutputRoot',out,'DryRun',true);
    assert(strcmp(realQueue.Status,'dry_run_validated')&&isempty(realQueue.Stages)&&realQueue.CommittedUniqueTasks==0);
    assertQueueFiles(realQueueDir);
    assert(strcmp(profileHash,JRDFileSHA256(fullfile(source,'profile.mat')))&& ...
        strcmp(timingHash,JRDFileSHA256(fullfile(source,'timings.csv'))));
end
report=struct('Status','PASS','OutputDir',out,'SyntheticProfileDir',fixture, ...
    'SyntheticQueueDir',queueDir,'RealProfileDryRunDir',realQueueDir, ...
    'SolverTasksExecuted',0,'SyntheticTimingIsEvidence',false, ...
    'IncompleteProfilingRejected',true,'Exp2FailedTableReported',true, ...
    'Exp3FailedTableReported',true,'PowerShellSyntaxCode',syntaxCode, ...
    'RuntimeSeconds',toc(wall),'CompletedAt',datestr(now,30));
save(fullfile(out,'unattended_queue_test.mat'),'report','-v7'); disp(report);
end

function assertQueueFiles(folder)
for name={'queue.mat','queue_state.json','REPORT.md','profiling_summary.csv'}
    assert(isfile(fullfile(folder,name{1})),'JRD:QueueOutput','Missing DryRun output: %s',name{1});
end
end

function assertThrows(call,identifier)
threw=false;
try, call(); catch exception, threw=strcmp(exception.identifier,identifier); end
assert(threw,'JRD:QueueGuard','Expected exception was swallowed or changed.');
end
