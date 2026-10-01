function result=RunCommonDirectBaseline(name,data,varargin)
%RUNCOMMONDIRECTBASELINE Direct partition adapters with one grid objective.
% GA/JADE preserve their search operators but use N active label coordinates
% and exact grid T/f evaluation. They are adaptations, not historical 2N runs.
% Original GA_Direct/JADE_Direct/MS_VND_Direct remain unchanged.
d=NormalizeJRDData(data); p=inputParser;
if strcmp(name,'GA'), name='GA_Direct';
elseif strcmp(name,'JADE'), name='JADE_Direct';
elseif strcmp(name,'VND'), name='MS_VND_Direct'; end
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'Seed',20260919,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0&&x<=2^32-1);
addParameter(p,'PopulationSize',max(40,4*d.N),@(x) integer(x)&&x>=4);
addParameter(p,'Generations',100,integer);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'VNDMaxGroupEvaluations',[],@(x) isempty(x)||(integer(x)||(isscalar(x)&&x==Inf)));
addParameter(p,'VNDStarts',4,@(x) integer(x)&&x>=2);
addParameter(p,'VNDILSIterations',10,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0);
parse(p,varargin{:}); o=p.Results;
assert(ismember(name,{'GA_Direct','JADE_Direct','MS_VND_Direct'}),'JRD:Baseline','Unsupported common Direct baseline.');
if isempty(o.VNDMaxGroupEvaluations)
    o.VNDMaxGroupEvaluations=o.PopulationSize*(o.Generations+1);
end
prior=rng; cleanup=onCleanup(@() rng(prior)); %#ok<NASGU>
rng(o.Seed,'twister'); wall=tic;
gridOptions=DirectEvolutionOptions(d,'PopulationSize',4,'Generations',1,'GridStep',o.GridStep);
grid=DirectGridCostCache(d,gridOptions);
partitionEvaluations=0; evaluationSeconds=0; checkpoints={}; trace=zeros(0,7);
bestCost=Inf; bestPartition=[];
if strcmp(name,'MS_VND_Direct')
    budget=SearchBudget(Inf,o.VNDMaxGroupEvaluations,'common_grid_group');
    vndCache=CommonGridVNDCostCache(d,gridOptions,budget);
    vndOptions=JRDSearchOptions('Seed',o.Seed,'MaxSeconds',Inf, ...
        'MaxEvaluations',o.VNDMaxGroupEvaluations,'Starts',o.VNDStarts, ...
        'ILSIterations',o.VNDILSIterations);
    current=DirectState({1:d.N},vndCache); acceptVND(current,0);
    info=struct('StartsStarted',0,'StartsCompleted',0,'AcceptedMoves',0, ...
        'NeighborCandidates',0,'Perturbations',0,'BudgetStopped',false);
    try
        for start=1:o.VNDStarts
            budget.Check(); info.StartsStarted=info.StartsStarted+1;
            if start==1, current=DirectState(groupsOf(bestPartition),vndCache);
            elseif start==2, current=DirectState(num2cell(1:d.N),vndCache);
            else, current=Init_Greedy(d,vndCache,start~=3); end
            acceptVND(current,start); current=descend(current,start);
            info.StartsCompleted=info.StartsCompleted+1;
            for iteration=1:o.VNDILSIterations
                if rand<0.2, current=DirectState(groupsOf(bestPartition),vndCache); end
                groups=PerturbPartition(current.Groups,d.N,vndOptions.PerturbMoves);
                current=DirectState(groups,vndCache);
                info.Perturbations=info.Perturbations+1;
                acceptVND(current,start); current=descend(current,start);
            end
        end
    catch exception
        if strcmp(exception.identifier,'JRD:BudgetExceeded'), info.BudgetStopped=true;
        else, rethrow(exception); end
    end
    grid=vndCache.GridCache; extra=info; extra.Budget=budget.Snapshot();
else
    population=rand(d.N,o.PopulationSize); fitness=evaluate(population);
    record(0,population,fitness);
    if strcmp(name,'GA_Direct')
        for generation=1:o.Generations
            previous=population; oldFitness=fitness;
            probability=cumsum((1./oldFitness)/sum(1./oldFitness));
            for i=1:o.PopulationSize
                selected=find(rand<=probability,1,'first');
                if isempty(selected), selected=o.PopulationSize; end
                population(:,i)=previous(:,selected);
            end
            for i=1:o.PopulationSize
                if rand<=0.8&&d.N>1
                    cut=randi(d.N-1); pair=randperm(o.PopulationSize,2);
                    temp=population(1:cut,pair(1));
                    population(1:cut,pair(1))=population(1:cut,pair(2));
                    population(1:cut,pair(2))=temp;
                end
            end
            for i=1:o.PopulationSize
                coordinate=randi(d.N);
                if rand<=0.1, population(coordinate,i)=rand; end
            end
            trialFitness=evaluate(population);
            combined=[population previous]; values=[trialFitness oldFitness];
            [~,order]=sort(values); chosen=order(1:o.PopulationSize);
            population=combined(:,chosen); fitness=values(chosen);
            record(generation,population,fitness);
        end
    else
        muCR=0.5; muF=0.5; archive=zeros(d.N,0);
        for generation=1:o.Generations
            acceptedCR=[]; acceptedF=[]; next=population; nextFitness=fitness;
            [~,sorted]=sort(fitness); top=max(round(0.05*o.PopulationSize),2);
            elite=sorted(1:top);
            for i=1:o.PopulationSize
                cr=min(max(muCR+0.1*randn,0),1);
                f=-1; while f<=0, f=muF+0.1*tan(pi*(rand-0.5)); end
                f=min(f,1); pbest=elite(randi(top));
                first=randi(o.PopulationSize); while first==i, first=randi(o.PopulationSize); end
                pooled=[population archive]; second=randi(size(pooled,2));
                while second==i||second==first, second=randi(size(pooled,2)); end
                mutant=population(:,i)+f*(population(:,pbest)-population(:,i)) ...
                    +f*(population(:,first)-pooled(:,second));
                mutant(mutant>1)=rand; mutant(mutant<0)=rand;
                trial=population(:,i); forced=randi(d.N);
                for coordinate=1:d.N
                    if rand<=cr||coordinate==forced, trial(coordinate)=mutant(coordinate); end
                end
                trialCost=evaluate(trial);
                if trialCost<fitness(i)
                    archive(:,end+1)=population(:,i); %#ok<AGROW>
                    next(:,i)=trial; nextFitness(i)=trialCost;
                    acceptedCR(end+1)=cr; acceptedF(end+1)=f; %#ok<AGROW>
                end
            end
            if size(archive,2)>o.PopulationSize
                archive=archive(:,randperm(size(archive,2),o.PopulationSize));
            end
            if ~isempty(acceptedCR), muCR=0.9*muCR+0.1*mean(acceptedCR); end
            if ~isempty(acceptedF), muF=0.9*muF+0.1*sum(acceptedF.^2)/sum(acceptedF); end
            population=next; fitness=nextFitness; record(generation,population,fitness);
        end
        extra=struct('FinalMuCR',muCR,'FinalMuF',muF,'ArchiveSize',size(archive,2));
    end
    if strcmp(name,'GA_Direct'), extra=struct(); end
end
searchSeconds=toc(wall); postTimer=tic;
common=DirectGridPartitionCost(bestPartition,grid);
continuous=PartitionCost(common.GroupId,d);
assert(abs(common.TotalCost-bestCost)<=1e-10*max(1,bestCost),'JRD:CostMismatch','Grid baseline recomputation failed.');
postSeconds=toc(postTimer);
result=struct('Algorithm',name,'Seed',o.Seed,'Options',o, ...
    'CommonGridTC',common.TotalCost,'TotalCost',common.TotalCost, ...
    'CommonGridSolution',common,'GroupId',common.GroupId,'GroupCount',common.GroupCount, ...
    'NativeContinuousTC',continuous.TotalCost,'NativeContinuousSolution',continuous, ...
    'SearchObjective','DirectGridPartitionCost (grid T and optimized integer group f)', ...
    'NativeObjectiveMeaning','continuous-T reoptimization of the same final partition; auxiliary only', ...
    'SearchSeconds',searchSeconds,'PostprocessSeconds',postSeconds, ...
    'RuntimeSeconds',searchSeconds+postSeconds,'ObjectiveEvaluationSeconds',evaluationSeconds, ...
    'PartitionEvaluations',partitionEvaluations,'Counters',grid.Snapshot(), ...
    'CheckpointPartitions',{checkpoints},'Details',extra, ...
    'Convergence',array2table(trace,'VariableNames',{'Checkpoint','Generation','CommonBestTC', ...
        'ElapsedSeconds','PartitionEvaluations','GroupEvaluations','GroupRequests'}));
for field={'OrderingCost','DeliveryCost','WarehouseHoldingCost','RetailHoldingCost','PenaltyCost','GroupT','GroupF'}
    result.(field{1})=common.(field{1});
end
if strcmp(name,'MS_VND_Direct')
    result.ComparisonMeaning='preserved VND neighborhoods with common-grid group cache; preset group-evaluation cap';
else
    result.ComparisonMeaning=['GA/JADE partition adapter: original search operators, N effective continuous labels, ' ...
        'common-grid fitness; not an unchanged replay of historical 2N implementation'];
end
    function labels=decode(chromosome)
        labels=CanonicalizePartition(min(d.N,floor(chromosome(:)'*d.N)+1));
    end
    function costs=evaluate(chromosomes)
        costs=zeros(1,size(chromosomes,2)); evalTimer=tic;
        for k=1:size(chromosomes,2)
            answer=DirectGridPartitionCost(decode(chromosomes(:,k)),grid,'fitness');
            costs(k)=answer.TotalCost; partitionEvaluations=partitionEvaluations+1;
        end
        evaluationSeconds=evaluationSeconds+toc(evalTimer);
    end
    function record(generation,pop,values)
        [value,index]=min(values);
        if value<bestCost, bestCost=value; bestPartition=decode(pop(:,index)); end
        counters=grid.Snapshot(); checkpoints{end+1,1}=bestPartition;
        trace(end+1,:)=[numel(checkpoints),generation,bestCost,toc(wall), ...
            partitionEvaluations,counters.GroupEvaluations,counters.GroupRequests];
    end
    function acceptVND(state,start)
        partitionEvaluations=partitionEvaluations+1;
        if state.TotalCost<bestCost
            bestCost=state.TotalCost; bestPartition=labelsOf(state.Groups);
        end
        counters=vndCache.GridCache.Snapshot(); checkpoints{end+1,1}=bestPartition;
        trace(end+1,:)=[numel(checkpoints),NaN,bestCost,toc(wall), ...
            partitionEvaluations,counters.GroupEvaluations,counters.GroupRequests];
    end
    function state=descend(state,start)
        kinds={'relocate','merge','swap','split'}; kind=1;
        while kind<=numel(kinds)
            [candidate,stopped,count]=BestNeighbor_Direct(state,kinds{kind},vndCache,vndOptions);
            info.NeighborCandidates=info.NeighborCandidates+count;
            partitionEvaluations=partitionEvaluations+count;
            improved=candidate.TotalCost<state.TotalCost-vndOptions.Tolerance*max(1,abs(state.TotalCost));
            if improved
                state=candidate; info.AcceptedMoves=info.AcceptedMoves+1;
                acceptVND(state,start); kind=1;
            else, kind=kind+1; end
            if stopped
                info.BudgetStopped=true;
                error('JRD:BudgetExceeded','Preset grid group-evaluation budget reached.');
            end
        end
        acceptVND(state,start);
    end
    function labels=labelsOf(groups)
        labels=zeros(1,d.N);
        for z=1:numel(groups), labels(groups{z})=z; end
        labels=CanonicalizePartition(labels);
    end
    function groups=groupsOf(labels)
        groups=cell(1,max(labels));
        for z=1:numel(groups), groups{z}=find(labels==z); end
    end
end
