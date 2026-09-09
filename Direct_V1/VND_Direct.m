function [state,info,history] = VND_Direct(state,cache,options)
kinds={'relocate','merge','swap','split'};
info=struct('AcceptedMoves',0,'NeighborCandidates',0,'BudgetStopped',false, ...
    'ExhaustedConfiguredNeighborhoods',false);
history=[toc(cache.Budget.Timer),state.TotalCost,cache.Budget.Evaluations];
k=1;
while k<=numel(kinds)
    [candidate,stop,count]=BestNeighbor_Direct(state,kinds{k},cache,options);
    info.NeighborCandidates=info.NeighborCandidates+count;
    improved=candidate.TotalCost<state.TotalCost-options.Tolerance*max(1,abs(state.TotalCost));
    if improved
        state=candidate; info.AcceptedMoves=info.AcceptedMoves+1;
        history(end+1,:)=[toc(cache.Budget.Timer),state.TotalCost,cache.Budget.Evaluations]; %#ok<AGROW>
        k=1;
    else
        k=k+1;
    end
    if stop, info.BudgetStopped=true; return; end
end
info.ExhaustedConfiguredNeighborhoods=true;
end
