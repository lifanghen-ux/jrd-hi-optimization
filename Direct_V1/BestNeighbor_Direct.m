function [best,stopped,evaluated] = BestNeighbor_Direct(state,kind,cache,options)
% Best improvement. Only modified groups invoke the evaluator.
best=state; stopped=false; evaluated=0;
groups=state.Groups; costs=state.Costs; m=numel(groups);
try
    switch kind
        case 'relocate'
            for a=1:m
                for item=groups{a}
                    remainder=groups{a}(groups{a}~=item);
                    for b=1:m+1
                        if b==a || (b==m+1 && isempty(remainder)), continue; end
                        candidate=groups; cc=costs;
                        candidate{a}=remainder; cc(a)=cache.Get(remainder);
                        if b==m+1, candidate{b}=item; else, candidate{b}=[groups{b},item]; end
                        cc(b)=cache.Get(candidate{b}); consider(candidate,cc);
                    end
                end
            end
        case 'merge'
            for a=1:m-1
                for b=a+1:m
                    candidate=groups; cc=costs;
                    candidate{a}=[groups{a},groups{b}]; cc(a)=cache.Get(candidate{a});
                    candidate{b}=[]; cc(b)=0; consider(candidate,cc);
                end
            end
        case 'swap'
            for a=1:m-1
                for b=a+1:m
                    for i=groups{a}
                        for j=groups{b}
                            candidate=groups; cc=costs;
                            candidate{a}=[groups{a}(groups{a}~=i),j];
                            candidate{b}=[groups{b}(groups{b}~=j),i];
                            cc(a)=cache.Get(candidate{a}); cc(b)=cache.Get(candidate{b});
                            consider(candidate,cc);
                        end
                    end
                end
            end
        case 'split'
            for a=1:m
                g=groups{a};
                if numel(g)<4, continue; end
                % Genuine two-item splits, unlike single-item relocate.
                for i=1:numel(g)-1
                    for j=i+1:numel(g)
                        splitGroup(a,g([i,j]),g(~ismember(g,g([i,j]))));
                    end
                end
                % Separate the most incompatible pair, then assign by penalty.
                penalty=cache.Data.PSym(g,g);
                [~,index]=max(penalty(:)); [i,j]=ind2sub(size(penalty),index);
                if i~=j
                    left=g(i); right=g(j);
                    for item=g(~ismember(g,[left,right]))
                        if sum(cache.Data.PSym(item,left))<=sum(cache.Data.PSym(item,right))
                            left(end+1)=item; %#ok<AGROW>
                        else
                            right(end+1)=item; %#ok<AGROW>
                        end
                    end
                    splitGroup(a,left,right);
                end
                for trial=1:options.SplitTrials
                    shuffled=g(randperm(numel(g))); cut=randi([2,numel(g)-2]);
                    splitGroup(a,shuffled(1:cut),shuffled(cut+1:end));
                end
            end
        otherwise
            error('JRD:UnknownNeighborhood','Unknown neighborhood.');
    end
catch exception
    if strcmp(exception.identifier,'JRD:BudgetExceeded'), stopped=true;
    else, rethrow(exception); end
end
    function splitGroup(a,left,right)
        candidate=groups; cc=costs;
        candidate{a}=left; candidate{end+1}=right;
        cc(a)=cache.Get(left); cc(end+1)=cache.Get(right); consider(candidate,cc);
    end
    function consider(candidate,cc)
        evaluated=evaluated+1;
        value=sum(cc);
        if value<best.TotalCost-options.Tolerance*max(1,abs(best.TotalCost))
            keep=~cellfun(@isempty,candidate);
            candidate=candidate(keep); cc=cc(keep);
            candidate=cellfun(@sort,candidate,'UniformOutput',false);
            [~,order]=sort(cellfun(@(g) g(1),candidate));
            best=struct('Groups',{candidate(order)},'Costs',cc(order),'TotalCost',value);
        end
    end
end
