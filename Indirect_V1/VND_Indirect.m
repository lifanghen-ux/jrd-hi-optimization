function [current,info,history] = VND_Indirect(current,cache,options)
% Exact best-improvement VND over the configured, finite neighborhoods.
% Pair blocks use top single-coordinate alternatives so coordinated moves
% can cross a barrier without enumerating the full 20^2 values per pair.
profile=option(options,'IndirectNeighborhoodProfile','coordinate_swap');
valueCount=option(options,'BlockValuesPerItem',3);
partners=option(options,'BlockPartnersPerItem',2);
conflictLimit=option(options,'BlockConflictPairLimit',200);
names={'coordinate','swap','uninformed_pair_block','conflict_pair_block'};
last=find(strcmp(profile,{'coordinate','coordinate_swap', ...
    'coordinate_swap_block','coordinate_swap_block_conflict'}),1);
assert(~isempty(last),'JRD:IndirectProfile','Unknown indirect neighborhood profile.');
info=struct('AcceptedMoves',0,'NeighborCandidates',0,'BudgetStopped',false, ...
    'NeighborhoodNames',{names},'NeighborhoodCandidates',zeros(1,4), ...
    'NeighborhoodAccepted',zeros(1,4),'CompletedNeighborhoods',false(1,4), ...
    'Profile',profile,'ExhaustedConfiguredNeighborhoods',false);
history=[toc(cache.Budget.Timer),current.TotalCost,cache.Budget.Evaluations];
kind=1; n=cache.Data.N; ranked=cell(n,1);
while kind<=last
    candidate=current; stopped=false; count=0;
    try
        switch kind
            case 1
                ranked=cell(n,1);
                for i=1:n
                    values=(cache.Data.KInf:cache.Data.KSup)';
                    values(values==current.K(i))=[]; scores=Inf(size(values));
                    for q=1:numel(values)
                        K=current.K; K(i)=values(q); trial=cache.Get(K);
                        scores(q)=trial.TotalCost; consider(trial);
                    end
                    [~,order]=sortrows([scores,values],[1 2]);
                    take=min(valueCount,numel(order)); ranked{i}=values(order(1:take))';
                end
            case 2
                for i=1:n-1
                    for j=i+1:n
                        if current.K(i)==current.K(j), continue; end
                        K=current.K; K([i,j])=K([j,i]); consider(cache.Get(K));
                    end
                end
            case 3
                pairs=uninformedPairs(n,partners);
                evaluatePairs(pairs);
            case 4
                pairs=[cache.Data.PairI(:),cache.Data.PairJ(:),cache.Data.PairPenalty(:)];
                if ~isempty(pairs)
                    pairs=sortrows(pairs,[-3 1 2]);
                    pairs=pairs(1:min(conflictLimit,size(pairs,1)),1:2);
                    evaluatePairs(pairs);
                end
        end
    catch exception
        if strcmp(exception.identifier,'JRD:BudgetExceeded'), stopped=true;
        else, rethrow(exception); end
    end
    info.NeighborCandidates=info.NeighborCandidates+count;
    info.NeighborhoodCandidates(kind)=info.NeighborhoodCandidates(kind)+count;
    info.CompletedNeighborhoods(kind)=~stopped;
    improved=candidate.TotalCost<current.TotalCost-options.Tolerance*max(1,current.TotalCost);
    if improved
        current=candidate; info.AcceptedMoves=info.AcceptedMoves+1;
        info.NeighborhoodAccepted(kind)=info.NeighborhoodAccepted(kind)+1;
        history(end+1,:)=[toc(cache.Budget.Timer),current.TotalCost,cache.Budget.Evaluations]; %#ok<AGROW>
        kind=1;
    else, kind=kind+1; end
    if stopped, info.BudgetStopped=true; return; end
end
info.ExhaustedConfiguredNeighborhoods=true;

    function consider(trial)
        count=count+1;
        if trial.TotalCost<candidate.TotalCost-options.Tolerance*max(1,candidate.TotalCost)
            candidate=trial;
        end
    end
    function evaluatePairs(pairs)
        for row=1:size(pairs,1)
            i=pairs(row,1); j=pairs(row,2);
            for vi=ranked{i}
                for vj=ranked{j}
                    % Both coordinates must change; otherwise this duplicates
                    % the already exhausted coordinate neighborhood.
                    K=current.K; K(i)=vi; K(j)=vj; consider(cache.Get(K));
                end
            end
        end
    end
end

function pairs=uninformedPairs(n,partners)
% Deterministic cyclic design independent of penalty values. It isolates
% generic block-search benefit from conflict-guided pair selection.
pairs=zeros(0,2);
for offset=1:min(partners,n-1)
    for i=1:n
        j=mod(i-1+offset,n)+1;
        pairs(end+1,:)=sort([i,j]); %#ok<AGROW>
    end
end
pairs=unique(pairs,'rows','stable');
end

function value=option(options,name,default)
if isfield(options,name), value=options.(name); else, value=default; end
end
