function [current,info,history] = VND_Indirect(current,cache,options)
info=struct('AcceptedMoves',0,'NeighborCandidates',0,'BudgetStopped',false);
history=[toc(cache.Budget.Timer),current.TotalCost,cache.Budget.Evaluations];
kind=1; n=cache.Data.N;
while kind<=2
    candidate=current; stopped=false;
    try
        if kind==1
            for i=1:n
                for value=cache.Data.KInf:cache.Data.KSup
                    if value==current.K(i), continue; end
                    K=current.K; K(i)=value; consider(K);
                end
            end
        else
            for i=1:n-1
                for j=i+1:n
                    if current.K(i)==current.K(j), continue; end
                    K=current.K; K([i,j])=K([j,i]); consider(K);
                end
            end
        end
    catch exception
        if strcmp(exception.identifier,'JRD:BudgetExceeded'), stopped=true;
        else, rethrow(exception); end
    end
    if candidate.TotalCost<current.TotalCost-options.Tolerance*max(1,current.TotalCost)
        current=candidate; kind=1; info.AcceptedMoves=info.AcceptedMoves+1;
        history(end+1,:)=[toc(cache.Budget.Timer),current.TotalCost,cache.Budget.Evaluations]; %#ok<AGROW>
    else
        kind=kind+1;
    end
    if stopped, info.BudgetStopped=true; return; end
end
    function consider(K)
        trial=cache.Get(K); info.NeighborCandidates=info.NeighborCandidates+1;
        if trial.TotalCost<candidate.TotalCost-options.Tolerance*max(1,candidate.TotalCost)
            candidate=trial;
        end
    end
end
