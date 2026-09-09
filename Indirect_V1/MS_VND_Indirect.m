function result = MS_VND_Indirect(data,varargin)
options=JRDSearchOptions(varargin{:});
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(options.Seed,'twister'); wall=tic;
d=NormalizeJRDData(data);
budget=SearchBudget(options.MaxSeconds,options.MaxEvaluations,'indirect_fixed_K');
cache=IndirectCostCache(d,budget,options.CacheLimit);
best=cache.Get(repmat(d.KInf,d.N,1));
history=[toc(budget.Timer),best.TotalCost,budget.Evaluations];
starts=0; completedStarts=0; perturbations=0; accepted=0; neighbors=0; stopped=false;
try
    start=1;
    while start<=options.Starts || options.UseTimeBudgetFully
        budget.Check();
        if start==1
            current=best;
        elseif start==2
            % Relative independent-item cycle lengths, clipped to legal K.
            ratios=sqrt((d.sw+d.sr)./(d.D.*d.hr));
            K=round(ratios/min(ratios)*d.KInf);
            current=cache.Get(min(max(K,d.KInf),d.KSup));
        else
            if mod(start,2)==0
                K=randi([d.KInf,d.KSup],d.N,1);
            else
                K=best.K;
                index=randperm(d.N,min(options.PerturbMoves,d.N));
                K(index)=randi([d.KInf,d.KSup],numel(index),1);
            end
            current=cache.Get(K);
        end
        starts=starts+1; accept(current);
        [current,info,trace]=VND_Indirect(current,cache,options); append(trace); accept(current);
        accepted=accepted+info.AcceptedMoves; neighbors=neighbors+info.NeighborCandidates;
        if info.BudgetStopped, stopped=true; break; end
        completedStarts=completedStarts+1;
        for iteration=1:options.ILSIterations
            if rand<0.2, current=best; end
            K=current.K; index=randperm(d.N,min(options.PerturbMoves,d.N));
            K(index)=randi([d.KInf,d.KSup],numel(index),1);
            current=cache.Get(K); perturbations=perturbations+1; accept(current);
            [current,info,trace]=VND_Indirect(current,cache,options); append(trace); accept(current);
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
[recomputed,t]=IndirectCostFixed(best.K,best.F,d);
assert(abs(recomputed-best.TotalCost)<=1e-10*max(1,best.TotalCost) && ...
    abs(t-best.T)<=1e-8*max(1,t),'JRD:CostMismatch','Indirect reconstruction failed.');
result=best; result.TotalCost=recomputed; result.T=t;
result.Algorithm='IG-EI-VND-ILS'; result.Seed=options.Seed; result.Options=options;
result.SearchSeconds=searchTime; result.RuntimeSeconds=toc(wall);
result.Counters=counters; result.StartsStarted=starts; result.StartsCompleted=completedStarts;
result.Perturbations=perturbations; result.AcceptedMoves=accepted;
result.NeighborCandidates=neighbors; result.BudgetStopped=stopped;
result.Optimality='exact T/F for returned K; outer K is heuristic, no global certificate';
result.Convergence=history;
result.ConvergenceColumns={'SearchSeconds','BestTC','FixedKKernelEvaluations'};
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
