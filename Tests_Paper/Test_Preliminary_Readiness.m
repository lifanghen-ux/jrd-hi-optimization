function report=Test_Preliminary_Readiness(varargin)
%TEST_PRELIMINARY_READINESS Small deterministic gates before paper pilots.
% Does not rerun Experiment 1 or write to its frozen certificate directory.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); Setup_JRD();
p=inputParser; addParameter(p,'Smoke',true,@(x) islogical(x)&&isscalar(x));
addParameter(p,'FailureRecovery',true,@(x) islogical(x)&&isscalar(x));
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
wall=tic; oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
protected={'AHDE.m','Fitness_Indirect.m','Run_Paper_Experiment1_N10.m'};
protected{3}=fullfile('Paper_Experiments',protected{3});
for n=[10 30 50 100], protected{end+1}=sprintf('Data_N%d.mat',n); end %#ok<AGROW>
before=cellfun(@(x) JRDFileSHA256(fullfile(root,x)),protected,'UniformOutput',false);
if isempty(o.OutputRoot)
    outputRoot=fullfile(root,'Validation_Paper','Preliminary_Readiness');
else
    outputRoot=char(o.OutputRoot);
end
if ~isfolder(outputRoot), mkdir(outputRoot); end
out=tempname(outputRoot); mkdir(out);

% Independent small model: exercise grid interiors, both truncated boundaries,
% negative hr-hw, and every nonempty subset without reusing N10 certificates.
d=struct('N',4,'D',[900;1200;800;1500],'sw',[8;12;9;11], ...
    'sr',[2;3;2.5;4],'hw',[1;1.5;0.8;1.2],'hr',[2;1.1;1.5;2.4], ...
    'S',40,'p',zeros(4),'KInf',1,'KSup',4,'FInf',1,'FSup',4);
d.p(1,3)=25; d.p(2,4)=31;
gridCases={[0.01,0.40],[0.30,0.40],[0.01,0.04]}; maxGridError=0;
for g=1:numel(gridCases)
    bounds=gridCases{g};
    for mask=1:2^d.N-1
        items=find(bitget(mask,1:d.N));
        a=DirectEvolutionOptions(d,'PopulationSize',4,'Generations',1, ...
            'GridStep',0.01,'TMin',bounds(1),'TMax',bounds(2),'GridMethod','projection');
        projected=DirectGridGroupCost(items,d,a); a.GridMethod='enumerate';
        enumerated=DirectGridGroupCost(items,d,a);
        normalized=NormalizeJRDData(d);
        kernel=DirectGridGroupKernel(items,normalized,a);
        groupCache=DirectGridCostCache(normalized,a); cached=groupCache.Get(items);
        assert(isequaln(kernel,enumerated)&&isequaln(cached,enumerated), ...
            'JRD:NormalizedKernel','The normalized fast kernel changed the public group result.');
        brute=Inf;
        for f=d.FInf:d.FSup
            for t=bounds(1):0.01:bounds(2)
                costs=independentDirectParts(items,t,f,d);
                brute=min(brute,sum(costs));
            end
        end
        maxGridError=max([maxGridError,abs(projected.Cost-enumerated.Cost),abs(projected.Cost-brute)]);
        assertCostParts(projected,projected.Cost);
        assert(projected.T>=bounds(1)-1e-12&&projected.T<=bounds(2)+1e-12);
    end
end
assert(maxGridError<1e-8,'JRD:GridOracle','Grid result disagrees with an independent literal model.');

ids=[8 8 3 3]; options=DirectEvolutionOptions(d,'PopulationSize',4,'Generations',1,'GridStep',0.01);
cache=DirectGridCostCache(d,options); one=DirectGridPartitionCost(ids,cache);
requests=cache.Requests; relabeled=DirectGridPartitionCost([1 1 2 2],cache);
assert(isequal(one.GroupId,relabeled.GroupId)&&one.TotalCost==relabeled.TotalCost&&cache.Hits>=2);
assert(cache.Requests==requests+2); assertCostParts(one,one.TotalCost);
compact=DirectGridPartitionCost(ids,cache,'fitness');
assert(compact.TotalCost==one.TotalCost&&isequal(compact.GroupId,one.GroupId)&& ...
    compact.GroupCount==one.GroupCount,'JRD:FitnessDetailMode','Lightweight fitness changed partition values.');
fixed=EvaluateDirectGridPartition(ids,d,'GridStep',0.01,'FixedF',1);
assert(one.TotalCost<=fixed.TotalCost+1e-8&&all(fixed.GroupF==1), ...
    'JRD:FeasibleSet','Optimized-f group evaluator must include the fixed-f partition.');

% Both AHDE cases must execute the exact teacher implementation; only the F
% bounds change. Compare all teacher outputs, including checkpoint solutions.
ahdeArgs={'Seed',7321,'PopulationSize',8,'Generations',2};
beforeAHDE=rng;
ahde=RunTeacherAHDE(d,ahdeArgs{:}); fixedAHDE=RunTeacherAHDE(d,ahdeArgs{:},'FixedF',1);
assert(isequal(rng,beforeAHDE),'JRD:CallerRNG','The teacher wrapper changed caller random state.');
rng(7321,'twister');
[coordinatedTC,coordinatedT,coordinatedK,coordinatedF]= ...
    AHDE(2,8,d.KSup,d.KInf,d.FSup,d.FInf,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N);
assert(abs(ahde.TotalCost-coordinatedTC)<1e-8&&ahde.T==coordinatedT&& ...
    isequal(ahde.K,coordinatedK(:))&&isequal(ahde.F,coordinatedF(:)), ...
    'JRD:TeacherImplementation','Coordinated wrapper changed the original teacher implementation.');
rng(7321,'twister');
[nativeTC,nativeT,nativeK,nativeF,nativeCurve,nativeTArray,nativeKArray,nativeFArray]= ...
    AHDE(2,8,d.KSup,d.KInf,1,1,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N);
assert(abs(fixedAHDE.TotalCost-nativeTC)<1e-8&&fixedAHDE.T==nativeT&& ...
    isequal(fixedAHDE.K,nativeK(:))&&isequal(fixedAHDE.F,nativeF(:))&& ...
    isequal(fixedAHDE.ConvergenceTC,nativeCurve(:))&& ...
    isequal(fixedAHDE.TByGeneration,nativeTArray(:))&& ...
    isequal(fixedAHDE.KByGeneration,nativeKArray)&&isequal(fixedAHDE.FByGeneration,nativeFArray), ...
    'JRD:FixedAHDEImplementation','Fixed-F must use the original teacher AHDE with F bounds 1..1.');
assert(all(fixedAHDE.F==1)&&all(cellfun(@(x) all(x(:)==1),fixedAHDE.FByGeneration)), ...
    'JRD:FixedFrequency','Teacher fixed-F output or checkpoint contains a frequency other than one.');
assertCostParts(ahde,ahde.TotalCost); assertCostParts(fixedAHDE,fixedAHDE.TotalCost);
anomaly=PaperCoordinationSanity(110,100); feasible=PaperCoordinationSanity(90,100);
roundoff=PaperCoordinationSanity(100+1e-10,100);
assert(anomaly.IsAnomaly&&strcmp(anomaly.Status,'heuristic_search_insufficiency')&& ...
    ~feasible.IsAnomaly&&~roundoff.IsAnomaly,'JRD:CoordinationSanity','Nested-feasible-set anomaly classification failed.');

% Search seeds and independent instance seeds are separate experimental axes.
beforeGenerator=rng;
first=GeneratePaperBenchmarkInstance(30,8417); second=GeneratePaperBenchmarkInstance(30,8417);
third=GeneratePaperBenchmarkInstance(30,8418);
assert(isequaln(first,second)&&~isequaln(first,third),'JRD:BenchmarkReplay','Independent-instance replay failed.');
assert(isequal(rng,beforeGenerator),'JRD:CallerRNG','Benchmark generation changed caller random state.');
checkBenchmarkLaw(first);

% Every saved checkpoint is evaluated by the same grid objective. The running
% best can only improve, and the final row must equal the returned common TC.
commonNames={'GA_Direct','JADE_Direct','MS_VND_Direct'}; commonAnswers=cell(1,3);
for a=1:numel(commonNames)
    commonAnswers{a}=RunCommonDirectBaseline(commonNames{a},d,'Seed',934, ...
        'PopulationSize',8,'Generations',2,'GridStep',0.01, ...
        'VNDMaxGroupEvaluations',30,'VNDStarts',2,'VNDILSIterations',0);
    assertCommonCheckpoint(commonAnswers{a},d,0.01);
end
evolution=EvolutionaryX_Direct(d,'Seed',934,'PopulationSize',8,'Generations',2, ...
    'GridStep',0.01,'IntensifyTrials',1);
recomputed=EvaluateDirectGridPartition(evolution.GroupId,d,'GridStep',0.01);
assert(abs(evolution.TotalCost-recomputed.TotalCost)<1e-8); assertCostParts(evolution,evolution.TotalCost);
assert(all(diff(evolution.Convergence.CommonBestTC)<=1e-8)&& ...
    size(evolution.CheckpointPartitions,1)==height(evolution.Convergence));
for k=1:height(evolution.Convergence)
    evaluated=EvaluateDirectGridPartition(evolution.CheckpointPartitions(k,:),d,'GridStep',0.01);
    assert(abs(evaluated.TotalCost-evolution.Convergence.CommonBestTC(k))<1e-8, ...
        'JRD:CommonConvergence','Evolutionary checkpoint and common objective disagree.');
end
assert(abs(evolution.CommonGridTC-evolution.Convergence.CommonBestTC(end))<1e-8);

smokes=struct(); taskFailures=struct();
if o.Smoke
    % N=10 and two generations are pipeline tests; their values are not paper
    % evidence and the frozen Experiment1 directory is never touched.
    smokes=smokeRunners(out);
end
if o.FailureRecovery
    taskFailures=Test_Paper_Task_Failure_Recovery('OutputRoot',out);
end
after=cellfun(@(x) JRDFileSHA256(fullfile(root,x)),protected,'UniformOutput',false);
assert(isequal(before,after),'JRD:ProtectedFilesChanged','A protected model, teacher solver, data or frozen runner changed.');
report=struct('Status','PASS','MaxIndependentGridError',maxGridError, ...
    'TeacherFixedFExactReplay',true,'BenchmarkDeterministic',true, ...
    'CommonCheckpointAlgorithms',{commonNames},'SmokeResults',smokes,'TaskFailureRecovery',taskFailures, ...
    'ProtectedFiles',{protected},'ProtectedSHA256',{after}, ...
    'RuntimeSeconds',toc(wall),'OutputDir',out,'FormalExperimentRun',false, ...
    'MATLABVersion',version,'CompletedAt',datestr(now,30));
save(fullfile(out,'preliminary_readiness.mat'),'report','-v7'); disp(report);
end

function parts=independentDirectParts(items,t,f,d)
penalty=0;
for i=1:numel(items)-1
    for j=i+1:numel(items), penalty=penalty+max(d.p(items(i),items(j)),0); end
end
parts=[(d.S+sum(d.sw(items)))/t,f*sum(d.sr(items))/t, ...
    sum((f-1)*t*d.D(items).*d.hw(items)/(2*f)), ...
    sum(t*d.D(items).*d.hr(items)/(2*f)),penalty/t];
end

function assertCostParts(solution,total)
names={'OrderingCost','DeliveryCost','WarehouseHoldingCost','RetailHoldingCost','PenaltyCost'};
values=cellfun(@(x) solution.(x),names);
assert(all(isfinite(values))&&all(values>=0)&& ...
    abs(sum(values)-total)<=1e-9*max(1,total),'JRD:CostParts','Five costs do not sum to the saved TC.');
end

function checkBenchmarkLaw(d)
assert(d.N==30&&all(d.D>=500&d.D<=5000)&&all(d.sw>=40&d.sw<=100));
assert(all(d.hw>=0.5&d.hw<3)&&all(d.hr./d.hw>=1.2&d.hr./d.hw<2));
assert(all(d.sr./d.sw>=0.1&d.sr./d.sw<0.38)&&abs(d.S-0.3*sum(d.sw))<1e-8);
assert(all(all(tril(d.p)==0)));
[i,j,p]=find(d.p); scale=d.sw(i)+d.sw(j); scale=scale(:);
assert(all(p>=1.2*scale&p<2*scale),'JRD:PenaltyLaw','The benchmark generator changed the existing penalty law.');
end

function assertCommonCheckpoint(answer,d,step)
assert(abs(answer.CommonGridTC-answer.CommonGridSolution.TotalCost)<1e-8);
assertCostParts(answer.CommonGridSolution,answer.CommonGridTC);
curve=answer.Convergence;
assert(istable(curve)&&ismember('CommonBestTC',curve.Properties.VariableNames));
assert(all(diff(curve.CommonBestTC)<=1e-8)&& ...
    abs(curve.CommonBestTC(end)-answer.CommonGridTC)<1e-8);
assert(numel(answer.CheckpointPartitions)==height(curve));
for k=1:height(curve)
    evaluated=EvaluateDirectGridPartition(answer.CheckpointPartitions{k},d,'GridStep',step);
    assert(abs(evaluated.TotalCost-curve.CommonBestTC(k))<1e-8, ...
        'JRD:CommonConvergence','Saved partition and CommonBestTC disagree.');
end
end

function results=smokeRunners(out)
exp2Args={'NList',10,'Instances',2,'Runs',2,'InstanceSource','generated', ...
    'SFactors',0.3,'BaseInstanceSeed',681,'BaseSeed',977,'Generations',2, ...
    'PopulationFactor',1,'MinimumPopulation',8,'GridStep',0.01, ...
    'VNDMaxGroupEvaluations',30,'VNDStarts',2,'VNDILSIterations',0};
[partial2,p2]=Run_Paper_Experiment2_DirectPerformance(exp2Args{:},'OutputRoot',out,'MaxNewSolves',1);
assert(startsWith(partial2.Status,'paused_')&&height(partial2.RawTable)==1&&~any(partial2.RawTable.InstanceComplete));
[e2,~]=Run_Paper_Experiment2_DirectPerformance(exp2Args{:},'ResumeDir',p2);
assert(isequaln(partial2.Records{1,1,1},e2.Records{1,1,1}));
assert(strcmp(e2.Status,'complete')&&height(e2.RawTable)==16&& ...
    numel(unique(e2.RawTable.InstanceID))==2&&numel(unique(e2.RawTable.InstanceSeed))==2&& ...
    height(e2.InstanceSummaryTable)==8&&height(e2.SummaryTable)==4&&all(e2.RawTable.InstanceComplete));
assert(numel(unique(e2.RawTable.AlgorithmSeed))==4&& ...
    ~any(ismember(e2.RawTable.AlgorithmSeed,e2.RawTable.InstanceSeed)), ...
    'JRD:SeedAxes','The smoke design did not separate instances from algorithm random seeds.');
for row=1:height(e2.RawTable)
    mask=strcmp(e2.RawTable.InstanceID,e2.RawTable.InstanceID{row});
    reference=min(e2.RawTable.CommonGridTC(mask));
    assert(abs(e2.RawTable.ReferenceBestTC(row)-reference)<1e-8&& ...
        abs(e2.RawTable.GapPercent(row)-100*(e2.RawTable.CommonGridTC(row)-reference)/reference)<1e-8);
end
for si=1:numel(e2.Scenarios)
    for run=1:e2.Config.Runs
        for a=1:numel(e2.Algorithms)
            answer=e2.Records{si,run,a}; d=e2.Inputs{si};
            common=EvaluateDirectGridPartition(answer.GroupId,d,'GridStep',0.01);
            assert(abs(common.TotalCost-answer.CommonGridTC)<1e-8);
            assertCostParts(common,answer.CommonGridTC);
            if a==1
                for k=1:height(answer.Convergence)
                    q=EvaluateDirectGridPartition(answer.CheckpointPartitions(k,:),d,'GridStep',0.01);
                    assert(abs(q.TotalCost-answer.Convergence.CommonBestTC(k))<1e-8);
                end
            else
                assertCommonCheckpoint(answer,d,0.01);
            end
        end
    end
end
assert(all(e2.InstanceSummaryTable.StdTC>=0)&&all(e2.InstanceSummaryTable.CVPercent>=0));
[e2Resume,~]=Run_Paper_Experiment2_DirectPerformance(exp2Args{:},'ResumeDir',p2);
assert(isequaln(e2.Records,e2Resume.Records)&&isequaln(e2.RawTable,e2Resume.RawTable), ...
    'JRD:CompleteResume','Exp2 complete resume recomputed or duplicated completed work.');
lost2=e2; lost2.Records{1,1,2}=[]; lost2.Status='running';
SavePaperStudy(fullfile(p2,'study.mat'),lost2);
[e2RawRestore,~]=Run_Paper_Experiment2_DirectPerformance(exp2Args{:},'ResumeDir',p2);
assert(isequaln(rmfield(e2RawRestore.Records{1,1,2},{'OutputWriteSeconds','RecoveredFromRaw'}), ...
    rmfield(e2.Records{1,1,2},'OutputWriteSeconds'))&& ...
    isnan(e2RawRestore.Records{1,1,2}.OutputWriteSeconds), ...
    'JRD:RawCommitRecovery','Exp2 failed to reclaim a raw-only completed solution.');
assert(isequaln(e2RawRestore.RawTable(:,setdiff(e2.RawTable.Properties.VariableNames,{'RawWriteSeconds'})), ...
    e2.RawTable(:,setdiff(e2.RawTable.Properties.VariableNames,{'RawWriteSeconds'}))));
changedExp2=exp2Args; changedExp2{find(strcmp(changedExp2,'Generations'))+1}=3;
rejectChangedConfig(@() Run_Paper_Experiment2_DirectPerformance(changedExp2{:},'ResumeDir',p2));
% Growing instances/seeds creates a new result directory and reuses task
% identities. Initializing the extension must not invoke any missing solver.
parentHashes=folderSnapshot(p2);
[extension,extensionPath]=Extend_Paper_Experiment2_Preliminary(p2,'Instances',3,'Runs',3,'OutputRoot',out);
assert(~strcmp(extensionPath,p2)&&numel(extension.Records)==36&& ...
    extension.ReusedRecords==16&&height(extension.RawTable)==16&& ...
    sum(strcmp(extension.TaskStatusTable.Status,'complete'))==16&& ...
    sum(strcmp(extension.TaskStatusTable.Status,'pending'))==20);
for si=1:2
    for run=1:2
        for a=1:4
            assert(isequaln(extension.Records{si,run,a},e2RawRestore.Records{si,run,a}), ...
                'JRD:ExtensionReuse','Extending instances/seeds recomputed a matching completed task.');
        end
    end
end
assert(isequal(parentHashes,folderSnapshot(p2)),'JRD:ParentChanged','Extension modified parent evidence.');
assert(isfile(fullfile(extensionPath,'task_provenance.csv'))&&height(extension.TaskProvenance)==36&& ...
    sum(extension.TaskProvenance.Reused)==16);

strategyArgs={'NList',10,'Runs',1,'BaseSeed',983,'Generations',2, ...
    'PopulationFactor',1,'MinimumPopulation',8,'GridStep',0.01};
solvers={@Run_Paper_Experiment3_StrategyComparison,@Run_Paper_Experiment4_Coordination};
paths=cell(1,2); final=cell(1,2);
for kind=1:2
    runner=solvers{kind};
    [partial,paths{kind}]=runner(strategyArgs{:},'OutputRoot',out,'MaxNewSolves',1);
    assert(strcmp(partial.Status,'paused_solver_boundary')&&height(partial.RawTable)==1, ...
        'JRD:PartialResume','The runner did not checkpoint a partially completed seed.');
    first=partial.Records{1,1,1};
    [study,~]=runner(strategyArgs{:},'ResumeDir',paths{kind});
    expected=2; if kind==2, expected=4; end
    assert(strcmp(study.Status,'complete')&&height(study.RawTable)==expected&& ...
        isequaln(first,study.Records{1,1,1}));
    assert(all(study.RawTable.CostSumError<1e-8)&&height(study.SolutionItems)==10*expected);
    assert(all(isfinite(study.SolutionItems.Frequency))&&all(study.SolutionItems.ReplenishmentPeriod>0));
    if kind==1
        assert(height(study.PairedComparison)==1&& ...
            abs(study.PairedComparison.DirectSavingPercent- ...
            100*(study.PairedComparison.IndirectTC-study.PairedComparison.DirectTC)/study.PairedComparison.IndirectTC)<1e-8);
    else
        assert(all(study.Records{1,1,2}.GroupF==1)&&all(study.Records{1,1,4}.F==1));
        assert(strcmp(study.Records{1,1,3}.Implementation,'unchanged teacher AHDE.m')&& ...
            strcmp(study.Records{1,1,4}.Implementation,'unchanged teacher AHDE.m'));
        expectedDirect=PaperCoordinationSanity(study.Records{1,1,1}.TotalCost,study.Records{1,1,2}.TotalCost);
        expectedIndirect=PaperCoordinationSanity(study.Records{1,1,3}.TotalCost,study.Records{1,1,4}.TotalCost);
        assert(study.PairedSavings.DirectHeuristicAnomaly==expectedDirect.IsAnomaly&& ...
            study.PairedSavings.IndirectHeuristicAnomaly==expectedIndirect.IsAnomaly&&height(study.Anomalies)==1);
    end
    for c=1:expected, assertCostParts(study.Records{1,1,c},study.Records{1,1,c}.TotalCost); end
    [completedResume,~]=runner(strategyArgs{:},'ResumeDir',paths{kind});
    assert(isequaln(study.Records,completedResume.Records)&&isequaln(study.RawTable,completedResume.RawTable));
    % Recreate a shutdown after atomic raw commit but before study.mat commit.
    % This edits only a newly created test artifact; the original raw solution
    % remains and must be reclaimed with its exact original timing and trace.
    lost=study; lost.Records{1,1,expected}=[]; lost.Status='running';
    SavePaperStudy(fullfile(paths{kind},'study.mat'),lost);
    [reclaimed,~]=runner(strategyArgs{:},'ResumeDir',paths{kind});
    assert(isequaln(reclaimed.Records,study.Records)&&isequaln(reclaimed.RawTable,study.RawTable), ...
        'JRD:RawCommitRecovery','A raw-only completed solution was recomputed or duplicated.');
    changedStrategy=strategyArgs; changedStrategy{find(strcmp(changedStrategy,'Generations'))+1}=3;
    rejectChangedConfig(@() runner(changedStrategy{:},'ResumeDir',paths{kind}));
    for name={'raw_results.csv','summary.csv','comparison.csv','diagnostics.csv','convergence.csv','solution_items.csv'}
        assert(isfile(fullfile(paths{kind},name{1}))); table=readtable(fullfile(paths{kind},name{1})); %#ok<NASGU>
    end
    final{kind}=study;
end
for name={'raw_results.csv','instance_summary.csv','summary.csv','convergence.csv'}
    assert(isfile(fullfile(p2,name{1}))); table=readtable(fullfile(p2,name{1})); %#ok<NASGU>
end
for name={'performance_panels.png','performance_panels.fig','common_convergence.png','common_convergence.fig'}
    assert(isfile(fullfile(p2,name{1})),'JRD:PlotOutput','Missing final common-objective performance/convergence plot.');
end
results=struct('Status','PASS','Exp2Path',p2,'Exp2Instances',2,'Exp2RunsPerInstance',2, ...
    'Exp2Rows',height(e2.RawTable),'Exp3Path',paths{1},'Exp3Rows',height(final{1}.RawTable), ...
    'Exp4Path',paths{2},'Exp4Rows',height(final{2}.RawTable), ...
    'SolverBoundaryResume',true,'RawCommitRecovery',true,'ChangedBudgetRejected',true, ...
    'ExtensionPath',extensionPath,'ExtensionRecordsReused',16,'ExtensionMissingTasksNotRun',20);
end

function rejectChangedConfig(call)
rejected=false;
try, call(); catch exception, rejected=strcmp(exception.identifier,'JRD:StaleCheckpoint'); end
assert(rejected,'JRD:ResumeMismatch','Changing a saved experiment budget was not rejected.');
end

function rows=folderSnapshot(folder)
files=dir(fullfile(folder,'**','*')); files=files(~[files.isdir]);
rows=cell(numel(files),2);
for k=1:numel(files)
    full=fullfile(files(k).folder,files(k).name);
    rows{k,1}=full(numel(folder)+2:end); rows{k,2}=JRDFileSHA256(full);
end
rows=sortrows(rows,1);
end
