function result=JRDCompleteSearch(data,strategy,varargin)
% Shared outer controller. No time/evaluation cutoffs. One step = full VND.
p=inputParser;
integer=@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v==fix(v)&&v>=0;
addParameter(p,'Seed',20260909,@(v) integer(v)&&v<=2^32-1);
addParameter(p,'Starts',8,@(v) integer(v)&&v>=2);
addParameter(p,'ILSIterations',20,integer);
addParameter(p,'PerturbFraction',0.1,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0&&v<=1);
addParameter(p,'RestartProbability',0.2,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=0&&v<=1);
addParameter(p,'Tolerance',1e-11,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0);
addParameter(p,'CacheLimit',50000,@(v) integer(v)&&v>=1);
addParameter(p,'IndirectNeighborhoodProfile','coordinate_swap_block_conflict',@(v) ischar(v)&& ...
    ismember(v,{'coordinate','coordinate_swap','coordinate_swap_block', ...
    'coordinate_swap_block_conflict'}));
addParameter(p,'BlockValuesPerItem',3,@(v) integer(v)&&v>=1);
addParameter(p,'BlockPartnersPerItem',2,@(v) integer(v)&&v>=1);
addParameter(p,'BlockConflictPairLimit',200,integer);
addParameter(p,'Checkpoint','',@(v) ischar(v)&&isrow(v)||isequal(v,''));
parse(p,varargin{:}); o=p.Results; checkpoint=o.Checkpoint; signature=rmfield(o,'Checkpoint');
assert(ismember(strategy,{'Direct','Indirect'}),'JRD:Strategy','Unknown strategy.');
d=NormalizeJRDData(data); direct=strcmp(strategy,'Direct');
assert(d.N>=2 && (direct || d.KSup>d.KInf),'JRD:DegenerateSearch', ...
    'Completed perturbation study requires N>=2 and a nontrivial K domain.');
root=fileparts(fileparts(mfilename('fullpath'))); manifest=JRDProjectManifest(root);
old=rng; cleanup=onCleanup(@() rng(old)); %#ok<NASGU>
wall=tic; budget=SearchBudget(Inf,Inf,strategy);
if direct, cache=GroupCostCache(d,budget,o.CacheLimit); else, cache=IndirectCostCache(d,budget,o.CacheLimit); end
local=JRDSearchOptions('MaxSeconds',Inf,'MaxEvaluations',Inf,'SplitTrials',0, ...
    'Tolerance',o.Tolerance,'IndirectNeighborhoodProfile',o.IndirectNeighborhoodProfile, ...
    'BlockValuesPerItem',o.BlockValuesPerItem, ...
    'BlockPartnersPerItem',o.BlockPartnersPerItem, ...
    'BlockConflictPairLimit',o.BlockConflictPairLimit);
C=struct('SchemaVersion',1,'Strategy',strategy,'Data',data,'Options',signature, ...
    'Manifest',manifest,'StepsCompleted',0,'Best',[],'Current',[], ...
    'StartKeys',{{}},'DuplicateStarts',0,'Perturbations',0,'AcceptedMoves',0, ...
    'NeighborCandidates',0,'NeighborhoodCandidates',zeros(1,4), ...
    'NeighborhoodAccepted',zeros(1,4),'History',zeros(0,3), ...
    'RuntimeSeconds',0,'Counters',[]);
if ~isempty(checkpoint)&&isfile(checkpoint)
    loaded=load(checkpoint,'payload'); C=loaded.payload;
    assert(C.SchemaVersion==1&&strcmp(C.Strategy,strategy)&&isequaln(C.Data,data)&& ...
        isequal(C.Options,signature)&&isequal(C.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Checkpoint does not match source/data/options.');
    for field={'Requests','CacheHits','InnerCandidates','CacheResets'}
        budget.(field{1})=C.Counters.(field{1});
    end
    budget.Evaluations=C.Counters.KernelEvaluations;
end
elapsedBefore=C.RuntimeSeconds;
stepsPerStart=o.ILSIterations+1; total=o.Starts*stepsPerStart;
for step=C.StepsCompleted+1:total
    start=floor((step-1)/stepsPerStart)+1; iteration=mod(step-1,stepsPerStart);
    % Reset the stream per logical action: branching in one strategy cannot
    % shift the random stream used by subsequent starts/perturbations.
    rng(mod(o.Seed+104729*start+1009*iteration,2^32),'twister');
    if iteration==0
        state=initial(start); key=stateKey(state);
        for attempt=1:32
            if ~any(strcmp(key,C.StartKeys)), break; end
            state=randomInitial(); key=stateKey(state);
        end
        C.DuplicateStarts=C.DuplicateStarts+any(strcmp(key,C.StartKeys));
        C.StartKeys{end+1}=key;
    else
        state=C.Current;
        if rand<o.RestartProbability, state=C.Best; end
        state=perturb(state); C.Perturbations=C.Perturbations+1;
    end
    if isempty(C.Best)||state.TotalCost<C.Best.TotalCost, C.Best=state; end
    if direct, [state,info]=VND_Direct(state,cache,local);
    else, [state,info]=VND_Indirect(state,cache,local); end
    assert(~info.BudgetStopped,'JRD:IncompleteLocalSearch','A local search was truncated.');
    if direct, assert(info.ExhaustedConfiguredNeighborhoods); end
    C.Current=state;
    if state.TotalCost<C.Best.TotalCost, C.Best=state; end
    C.AcceptedMoves=C.AcceptedMoves+info.AcceptedMoves;
    C.NeighborCandidates=C.NeighborCandidates+info.NeighborCandidates;
    if isfield(info,'NeighborhoodCandidates')
        C.NeighborhoodCandidates=C.NeighborhoodCandidates+info.NeighborhoodCandidates;
        C.NeighborhoodAccepted=C.NeighborhoodAccepted+info.NeighborhoodAccepted;
    end
    C.StepsCompleted=step; C.RuntimeSeconds=elapsedBefore+toc(wall); C.Counters=budget.Snapshot();
    C.History(end+1,:)=[step,C.Best.TotalCost,C.RuntimeSeconds];
    if ~isempty(checkpoint), JRDAtomicSave(checkpoint,C); end
    fprintf('%s seed=%u start=%d/%d perturb=%d/%d cost=%.10f\n', ...
        strategy,o.Seed,start,o.Starts,iteration,o.ILSIterations,C.Best.TotalCost);
end
if direct, result=PartitionCost(C.Best.Groups,d);
else
    result=C.Best; [result.TotalCost,result.T]=IndirectCostFixed(result.K,result.F,d);
end
assert(abs(result.TotalCost-C.Best.TotalCost)<=1e-10*max(1,result.TotalCost),'JRD:CostMismatch','Reconstruction failed.');
result.Strategy=strategy; result.Options=signature; result.Status='completed_search_tasks';
result.StartsCompleted=o.Starts; result.Perturbations=C.Perturbations;
result.LocalSearchesCompleted=C.StepsCompleted; result.DuplicateStarts=C.DuplicateStarts;
result.AcceptedMoves=C.AcceptedMoves; result.NeighborCandidates=C.NeighborCandidates;
result.NeighborhoodNames={'coordinate','swap','uninformed_pair_block','conflict_pair_block'};
result.NeighborhoodCandidates=C.NeighborhoodCandidates;
result.NeighborhoodAccepted=C.NeighborhoodAccepted;
result.RuntimeSeconds=elapsedBefore+toc(wall); result.Counters=budget.Snapshot();
result.Convergence=C.History; result.ConvergenceColumns={'CompletedLocalSearches','BestTC','DiagnosticSeconds'};
result.Optimality='best feasible solution; completed tasks are not a global certificate';
assert(C.StepsCompleted==total&&C.Perturbations==o.Starts*o.ILSIterations);
    function state=initial(index)
        if index==1
            if direct, state=DirectState({1:d.N},cache); else, state=cache.Get(repmat(d.KInf,d.N,1)); end
        elseif index==2
            if direct, state=DirectState(num2cell(1:d.N),cache);
            else, state=cache.Get(round(linspace(d.KInf,d.KSup,d.N))'); end
        else, state=randomInitial(); end
    end
    function state=randomInitial()
        if direct
            % Uniform group-count draw, then a surjection (no empty groups).
            count=randi(d.N); order=randperm(d.N); labels=zeros(1,d.N);
            labels(order(1:count))=1:count;
            labels(order(count+1:end))=randi(count,1,d.N-count);
            state=DirectState(toGroups(labels),cache);
        else, state=cache.Get(randi([d.KInf,d.KSup],d.N,1)); end
    end
    function out=perturb(state)
        moves=min(d.N,max(3,ceil(o.PerturbFraction*d.N))); before=stateKey(state);
        if direct
            groups=PerturbPartition(state.Groups,d.N,moves);
            out=DirectState(groups,cache);
            % Multi-move chains can cancel. A one-move fallback cannot.
            if strcmp(before,stateKey(out)), out=DirectState(PerturbPartition(state.Groups,d.N,1),cache); end
        else
            K=state.K; selected=randperm(d.N,moves);
            for item=selected
                candidates=d.KInf:d.KSup; candidates(candidates==K(item))=[];
                K(item)=candidates(randi(numel(candidates)));
            end
            out=cache.Get(K);
        end
        assert(~strcmp(before,stateKey(out)),'JRD:NoOpPerturbation','Perturbation must change the decision.');
    end
    function key=stateKey(state)
        if direct
            labels=zeros(1,d.N);
            for q=1:numel(state.Groups), labels(state.Groups{q})=q; end
            key=sprintf('%d_',CanonicalizePartition(labels));
        else, key=sprintf('%d_',state.K); end
    end
    function groups=toGroups(labels)
        labels=CanonicalizePartition(labels);
        groups=arrayfun(@(q) find(labels==q),1:max(labels),'UniformOutput',false);
    end
end
