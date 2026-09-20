function result=EvolutionaryX_Direct(data,varargin)
%EVOLUTIONARYX_DIRECT Evolutionary search over X={G_k}; grid-exact T_k,f_k.
% Termination is generation/stall based. Wall time is recorded only.
d=NormalizeJRDData(data); options=DirectEvolutionOptions(d,varargin{:});
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(options.Seed,'twister'); timer=tic;
cache=DirectGridCostCache(d,options); population=zeros(options.PopulationSize,d.N);
next=0;
for q=1:numel(options.InitialPartitions)
    candidate=options.InitialPartitions{q};
    assert(numel(candidate)==d.N,'JRD:InitialPartition','Initial partition has wrong length.');
    next=next+1; population(next,:)=CanonicalizePartition(candidate);
    if next==options.PopulationSize, break; end
end
seeds={ones(1,d.N),1:d.N};
for q=1:numel(seeds)
    if next<options.PopulationSize, next=next+1; population(next,:)=seeds{q}; end
end
if next<options.PopulationSize
    next=next+1; population(next,:)=GreedyGridPartition(d,cache,false);
end
if next<options.PopulationSize
    next=next+1; population(next,:)=GreedyGridPartition(d,cache,true);
end
while next<options.PopulationSize
    next=next+1; population(next,:)=RandomCanonicalPartition(d.N);
end
[costs,answers]=evaluatePopulation(population);
[bestCost,index]=min(costs); best=answers{index}; bestGeneration=0;
trace=nan(options.Generations+1,7);
trace(1,:)=traceRow(0,costs,population);
stall=0; generationsCompleted=0; stopReason='configured generations completed';
for generation=1:options.Generations
    [costs,order]=sort(costs); population=population(order,:); answers=answers(order);
    newPopulation=population(1:options.EliteCount,:);
    while size(newPopulation,1)<options.PopulationSize
        first=tournament(costs); second=tournament(costs);
        child=population(first,:);
        if rand<options.CrossoverRate
            child=CrossoverDirectPartition(population(first,:),population(second,:));
        end
        if rand<options.MutationRate
            moves=1+(rand<0.30)+(rand<0.10);
            for m=1:moves, child=MutateDirectPartition(child); end
        end
        newPopulation(end+1,:)=child; %#ok<AGROW>
    end
    population=makeDiverse(newPopulation);
    [costs,answers]=evaluatePopulation(population);
    % Mutation-only intensification uses the identical partition evaluator.
    [~,eliteOrder]=sort(costs);
    for e=1:min(options.IntensifyElites,numel(eliteOrder))
        target=eliteOrder(e);
        for trial=1:options.IntensifyTrials
            candidate=MutateDirectPartition(population(target,:));
            answer=DirectGridPartitionCost(candidate,cache);
            if answer.TotalCost<costs(target)-options.Tolerance*max(1,costs(target))
                population(target,:)=candidate; costs(target)=answer.TotalCost; answers{target}=answer;
            end
        end
    end
    [generationBest,index]=min(costs);
    if generationBest<bestCost-options.Tolerance*max(1,bestCost)
        bestCost=generationBest; best=answers{index}; bestGeneration=generation; stall=0;
    else
        stall=stall+1;
    end
    generationsCompleted=generation; trace(generation+1,:)=traceRow(generation,costs,population);
    if isfinite(options.StallGenerations)&&stall>=options.StallGenerations
        stopReason='configured stall generations reached'; break;
    end
end
trace=trace(1:generationsCompleted+1,:); elapsed=toc(timer);
% Reconstruct from the winning X so every stored field is independently consistent.
best=DirectGridPartitionCost(best.GroupId,cache);
best.Algorithm='Evolutionary-X + grid-exact (T_k,f_k)';
best.DecisionStructure='X/{G_k}, T_k, f_k; no K_i';
best.Seed=options.Seed; best.Options=options; best.RuntimeSeconds=elapsed;
best.GenerationsCompleted=generationsCompleted; best.BestGeneration=bestGeneration;
best.StopReason=stopReason; best.Counters=cache.Snapshot();
best.Convergence=array2table(trace,'VariableNames',{'Generation','BestTC','MeanTC', ...
    'UniquePartitions','GroupEvaluations','CacheHits','ElapsedSeconds'});
best.Optimality='heuristic feasible partition; inner (T_k,f_k) is exact on the configured grid';
result=best;
    function [values,details]=evaluatePopulation(pop)
        values=zeros(size(pop,1),1); details=cell(size(pop,1),1);
        for z=1:size(pop,1)
            details{z}=DirectGridPartitionCost(pop(z,:),cache); values(z)=details{z}.TotalCost;
        end
    end
    function index=tournament(values)
        candidates=randperm(numel(values),options.TournamentSize);
        [~,local]=min(values(candidates)); index=candidates(local);
    end
    function row=traceRow(generation,values,pop)
        counters=cache.Snapshot();
        row=[generation,min(values),mean(values),size(unique(pop,'rows'),1), ...
            counters.GroupEvaluations,counters.CacheHits,toc(timer)];
    end
    function pop=makeDiverse(pop)
        pop=unique(pop,'rows','stable'); attempts=0;
        while size(pop,1)<options.PopulationSize
            attempts=attempts+1;
            if ~isempty(pop)&&rand<0.6
                candidate=MutateDirectPartition(pop(randi(size(pop,1)),:));
            else
                candidate=RandomCanonicalPartition(d.N);
            end
            if ~ismember(candidate,pop,'rows'), pop(end+1,:)=candidate; end %#ok<AGROW>
            if attempts>20*options.PopulationSize
                % Degenerate tiny-N spaces can contain fewer unique partitions than P.
                pop(end+1,:)=candidate; %#ok<AGROW>
            end
        end
        pop=pop(1:options.PopulationSize,:);
    end
end
