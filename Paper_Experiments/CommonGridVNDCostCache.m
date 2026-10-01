classdef CommonGridVNDCostCache < handle
    % Adapter for preserved VND neighborhoods using the common grid kernel.
    properties (SetAccess=private)
        Data
        Budget
        GridCache
    end
    methods
        function obj=CommonGridVNDCostCache(data,options,budget)
            obj.Data=NormalizeJRDData(data); obj.Budget=budget;
            obj.GridCache=DirectGridCostCache(obj.Data,options);
        end
        function [cost,f,T]=Get(obj,items)
            if isempty(items), cost=0; f=NaN; T=NaN; return; end
            obj.Budget.Requests=obj.Budget.Requests+1; obj.Budget.Check();
            key=sprintf('%d_',sort(items(:)'));
            hit=isKey(obj.GridCache.Entries,key);
            if hit, obj.Budget.CacheHits=obj.Budget.CacheHits+1;
            else, obj.Budget.Begin(); end
            value=obj.GridCache.Get(items);
            if ~hit
                obj.Budget.InnerCandidates=obj.Budget.InnerCandidates+value.GridCandidatesChecked;
            end
            cost=value.Cost; f=value.F; T=value.T;
        end
    end
end
