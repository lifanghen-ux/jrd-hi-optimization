function report=Test_JRD_Search()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); Setup_JRD();
input=load(fullfile(root,'Data_N10.mat'),'data'); d=input.data; wall=tic;
originalRng=rng; preserved=true;
args={'Seed',918,'MaxSeconds',Inf,'MaxEvaluations',3000, ...
    'Starts',4,'ILSIterations',2,'CacheLimit',10000};
direct=MS_VND_Direct(d,args{:}); preserved=preserved&&isequal(rng,originalRng);
replay=MS_VND_Direct(d,args{:});
assert(direct.TotalCost==replay.TotalCost && isequal(direct.GroupId,replay.GroupId));
assert(direct.TotalCost<=PartitionCost(ones(1,d.N),d).TotalCost+1e-9);
assert(direct.TotalCost>=12059.2516110867-1e-8);
assert(all(diff(direct.Convergence(:,2))<=1e-8));
assert(direct.Counters.KernelEvaluations<=3000);
indirect=MS_VND_Indirect(d,args{:}); replay=MS_VND_Indirect(d,args{:});
assert(indirect.TotalCost==replay.TotalCost && isequal(indirect.K,replay.K));
assert(indirect.TotalCost<=IndirectInnerExact(ones(d.N,1),d).TotalCost+1e-9);
assert(all(diff(indirect.Convergence(:,2))<=1e-8) && indirect.Counters.KernelEvaluations<=3000);
assert(preserved && isequal(rng,originalRng));
% A hard one-kernel budget must still return the initial feasible solution.
for solver={@MS_VND_Direct,@MS_VND_Indirect}
    minimal=solver{1}(d,'MaxSeconds',Inf,'MaxEvaluations',1);
    assert(isfinite(minimal.TotalCost) && minimal.Counters.KernelEvaluations==1);
end
% Local moves must not worsen cost; verify the claim for all implemented types.
cache=GroupCostCache(d,SearchBudget(Inf,Inf,'direct_group'),5000);
options=JRDSearchOptions('SplitTrials',2);
neighborhoods={'relocate','merge','swap','split'};
for initial={{1:d.N},{1:4,5:7,8:10}}
    state=DirectState(initial{1},cache);
    for k=1:numel(neighborhoods)
        [neighbor,stop]=BestNeighbor_Direct(state,neighborhoods{k},cache,options);
        assert(~stop && neighbor.TotalCost<=state.TotalCost+1e-9);
        checked=PartitionCost(neighbor.Groups,d);
        assert(abs(checked.TotalCost-neighbor.TotalCost)<1e-8);
    end
end
% Short budget smoke checks at all four actual sizes. Not performance evidence.
smoke=cell(2,4);
scales=[10 30 50 100];
for j=1:4
    input=load(fullfile(root,sprintf('Data_N%d.mat',scales(j))),'data');
    for s=1:2
        solver=@MS_VND_Direct; if s==2, solver=@MS_VND_Indirect; end
        smoke{s,j}=solver(input.data,'MaxSeconds',0.25,'Seed',120+j, ...
            'Starts',2,'ILSIterations',0);
        assert(isfinite(smoke{s,j}.TotalCost) && smoke{s,j}.TotalCost>0);
    end
end
% Pipeline validation: paired raw/summary output and source/data snapshots.
[pipeline,pathOut]=Run_Optimized_Experiment('NList',10,'Runs',2,'Seconds',0.15, ...
    'OutputRoot',fullfile(root,'Validation_V1','pipeline'));
assert(strcmp(pipeline.Status,'complete'));
saved=load(fullfile(pathOut,'results.mat'),'Results');
assert(isequal(saved.Results.TC_Direct,pipeline.TC_Direct));
assert(all(abs(pipeline.Saving_Percent- ...
    100*(pipeline.TC_Indirect-pipeline.TC_Direct)./pipeline.TC_Indirect)<1e-10));
assert(height(pipeline.RawTable)==2 && height(pipeline.SummaryTable)==2);
report=struct('Status','PASS','DirectN10',direct,'IndirectN10',indirect, ...
    'ScaleSmoke',{smoke},'PipelinePath',pathOut,'RuntimeSeconds',toc(wall), ...
    'CompletedAt',datestr(now,30));
fprintf('Search tests PASS. N10 validation Direct=%.10f, Indirect=%.10f\n', ...
    direct.TotalCost,indirect.TotalCost);
end
