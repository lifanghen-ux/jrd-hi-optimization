function result = MS_VND_Direct(data,varargin)
% Exact F/T inside each group, multi-start VND + ILS outside.
options=JRDSearchOptions(varargin{:});
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(options.Seed,'twister');
wall=tic;
d=NormalizeJRDData(data);
budget=SearchBudget(options.MaxSeconds,options.MaxEvaluations,'direct_group');
cache=GroupCostCache(d,budget,options.CacheLimit);
best=DirectState({1:d.N},cache); % one mandatory feasible evaluation
history=[toc(budget.Timer),best.TotalCost,budget.Evaluations];
accepted=0; neighbors=0; starts=0; completedStarts=0; perturbations=0; stopped=false;
try
    start=1;
    while start<=options.Starts || options.UseTimeBudgetFully
        budget.Check();
        if start==1
            current=best;
        elseif start==2
            current=DirectState(num2cell(1:d.N),cache);
        else
            current=Init_Greedy(d,cache,start~=3);
        end
        starts=starts+1; accept(current);
        [current,info,trace]=VND_Direct(current,cache,options); append(trace); accept(current);
        accepted=accepted+info.AcceptedMoves; neighbors=neighbors+info.NeighborCandidates;
        if info.BudgetStopped, stopped=true; break; end
        completedStarts=completedStarts+1;
        for iteration=1:options.ILSIterations
            if rand<0.2, current=best; end
            groups=PerturbPartition(current.Groups,d.N,options.PerturbMoves);
            current=DirectState(groups,cache);
            perturbations=perturbations+1; accept(current);
            [current,info,trace]=VND_Direct(current,cache,options);
            append(trace); accept(current);
            accepted=accepted+info.AcceptedMoves; neighbors=neighbors+info.NeighborCandidates;
            if info.BudgetStopped, stopped=true; break; end
        end
        if stopped, break; end
        start=start+1;
    end
catch exception
    if strcmp(exception.identifier,'JRD:BudgetExceeded'), stopped=true;
    else, rethrow(exception); end
end
searchTime=toc(budget.Timer);
counters=budget.Snapshot();
% Independently reconstruct the winning solution; outside search counters.
result=PartitionCost(best.Groups,d);
assert(abs(result.TotalCost-best.TotalCost)<=1e-10*max(1,best.TotalCost), ...
    'JRD:CostMismatch','Final partition recomputation failed.');
result.Algorithm='DG-EI-VND-ILS'; result.Seed=options.Seed;
result.Options=options; result.SearchSeconds=searchTime;
result.RuntimeSeconds=toc(wall); result.Counters=counters;
result.StartsStarted=starts; result.StartsCompleted=completedStarts;
result.Perturbations=perturbations;
result.AcceptedMoves=accepted; result.NeighborCandidates=neighbors;
result.BudgetStopped=stopped;
result.Optimality='heuristic feasible solution; no global certificate';
result.Convergence=history;
result.ConvergenceColumns={'SearchSeconds','BestTC','GroupKernelEvaluations'};
    function accept(state)
        if state.TotalCost<best.TotalCost, best=state; end
        history(end+1,:)=[toc(budget.Timer),best.TotalCost,budget.Evaluations];
    end
    function append(trace)
        floorCost=best.TotalCost;
        for row=1:size(trace,1)
            floorCost=min(floorCost,trace(row,2));
            history(end+1,:)=[trace(row,1),floorCost,trace(row,3)];
        end
    end
end
