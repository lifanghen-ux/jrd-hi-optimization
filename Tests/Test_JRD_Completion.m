function readiness=Test_JRD_Completion()
root=Setup_JRD(); before=JRDProjectManifest(root);
blockSearch=Test_Indirect_Block_Search();
loaded=load(fullfile(root,'Data_N10.mat'),'data'); d=loaded.data;
% Tiny bounded instance: test full tasks and exhaustive mathematical bounds.
d.N=3;
for name={'D','sw','sr','hw','hr'}, d.(name{1})=d.(name{1})(1:3); end
d.p=d.p(1:3,1:3); d.KSup=3; d.FSup=3;
folder=tempname; mkdir(folder);
original=rng;
for kind={'Direct','Indirect'}
    checkpoint=fullfile(folder,[kind{1},'.mat']);
    args={'Seed',41,'Starts',3,'ILSIterations',2,'Checkpoint',checkpoint};
    a=JRDCompleteSearch(d,kind{1},args{:});
    assert(isequal(rng,original));
    assert(a.StartsCompleted==3&&a.Perturbations==6&&a.LocalSearchesCompleted==9);
    assert(all(diff(a.Convergence(:,2))<=1e-8));
    b=JRDCompleteSearch(d,kind{1},'Seed',41,'Starts',3,'ILSIterations',2);
    assert(a.TotalCost==b.TotalCost);
    assert(isequal(a.Convergence(:,1:2),b.Convergence(:,1:2)));
    % Roll back one fully saved phase and replay it with an empty cache.
    copyfile([checkpoint,'.previous'],checkpoint,'f');
    c=JRDCompleteSearch(d,kind{1},args{:});
    assert(c.TotalCost==a.TotalCost&&isequal(c.Convergence(:,1:2),a.Convergence(:,1:2)));
    rejected=false;
    try, JRDCompleteSearch(d,kind{1},'Seed',42,'Starts',3,'ILSIterations',2,'Checkpoint',checkpoint);
    catch e, rejected=strcmp(e.identifier,'JRD:StaleCheckpoint'); end
    assert(rejected);
end
bounds=JRDStrategyBounds(d);
assert(bounds.IndirectExact.EnumeratedStates==27);
assert(bounds.IndirectLowerBound<=a.TotalCost+1e-8);
assert(bounds.IndirectExact.TotalCost<bounds.DirectExact.TotalCost); % Do not assume Direct wins.
% Force relaxation-only route and verify it lies below feasible solutions.
large=loaded.data; large.N=11;
for name={'D','sw','sr','hw','hr'}, large.(name{1})=[large.(name{1})(:);large.(name{1})(1)]; end
large.p=zeros(11); lower=JRDStrategyBounds(large);
feasibleD=PartitionCost(ones(1,11),large); feasibleI=IndirectInnerExact(ones(11,1),large);
assert(lower.DirectLowerBound<=feasibleD.TotalCost&&lower.IndirectLowerBound<=feasibleI.TotalCost);
% Pipeline and schedule extension, without long formal experiments.
[study,out]=Run_Strategy_Experiment('NList',10,'Runs',1,'StartsSchedule',[2 2], ...
    'PerturbSchedule',[1 1],'StableLevels',1,'OutputRoot',folder);
assert(study.LevelsCompleted==2&&numel(study.Records)==4);
[resumed,~]=Run_Strategy_Experiment('NList',10,'Runs',1,'StartsSchedule',[2 2 3], ...
    'PerturbSchedule',[1 1 1],'StableLevels',1,'ResumeDir',out);
assert(resumed.LevelsCompleted==3);
assert(all(resumed.CumulativeBest(:)<=study.CumulativeBest(:)));
% Small search-quality diagnostic; never inject the DP answer into search.
exact=ExactDP_Direct(loaded.data); costs=zeros(1,5);
for seed=1:5
    evalc('answer=JRDCompleteSearch(loaded.data,''Direct'',''Seed'',seed,''Starts'',4,''ILSIterations'',10);');
    costs(seed)=answer.TotalCost;
end
hits=sum(abs(costs-exact.TotalCost)<=1e-8);
fprintf('New completed-search N10 diagnostic: %d/5 exact hits; worst gap %.8g percent\n',hits,100*(max(costs)-exact.TotalCost)/exact.TotalCost);
after=JRDProjectManifest(root); assert(isequal(before,after));
readiness=struct('Status','PASS','Manifest',after,'CompletedAt',datestr(now,30), ...
    'Tests','complete tasks, deterministic replay, resume, mismatch rejection, bounds, pipeline extension', ...
    'FormalExperimentRun',false,'TestArtifacts',folder);
readiness.N10Diagnostic=struct('Seeds',1:5,'Starts',4,'ILSIterations',10, ...
    'ExactHits',hits,'Costs',costs,'ExactCost',exact.TotalCost);
readiness.BlockSearch=blockSearch;
dest=fullfile(root,'Validation_V1'); if ~isfolder(dest), mkdir(dest); end
save(fullfile(dest,'completion_readiness.mat'),'readiness');
disp(readiness);
end
