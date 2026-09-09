classdef GroupCostCache < handle
    % Bound to one immutable data copy and frequency range per search.
    properties (SetAccess=private)
        Data
        Budget
        Limit
        Entries
    end
    methods
        function obj = GroupCostCache(data,budget,limit)
            obj.Data = NormalizeJRDData(data);
            obj.Budget = budget;
            obj.Limit = limit;
            obj.Entries = containers.Map('KeyType','char','ValueType','any');
        end
        function [cost,f,T] = Get(obj,items)
            if isempty(items), cost=0; f=NaN; T=NaN; return; end
            items = sort(items(:)');
            assert(all(items>=1 & items<=obj.Data.N & items==fix(items)) && ...
                numel(unique(items))==numel(items),'JRD:InvalidGroup','Invalid group items.');
            obj.Budget.Requests = obj.Budget.Requests+1;
            obj.Budget.Check();
            key = sprintf('%d_',items);
            if isKey(obj.Entries,key)
                obj.Budget.CacheHits = obj.Budget.CacheHits+1;
                value = obj.Entries(key);
            else
                obj.Budget.Begin();
                d = obj.Data;
                frequencies = d.FInf:d.FSup;
                A = d.S+sum(d.sw(items))+sum(sum(d.PUpper(items,items))) ...
                    + frequencies*sum(d.sr(items));
                B = sum(d.D(items).*d.hw(items)) ...
                    + sum(d.D(items).*(d.hr(items)-d.hw(items)))./frequencies;
                costs = sqrt(2*A.*B);
                [cost,index] = min(costs);
                value = [cost,frequencies(index),sqrt(2*A(index)/B(index))];
                obj.Budget.InnerCandidates = obj.Budget.InnerCandidates+numel(frequencies);
                if obj.Entries.Count>=obj.Limit
                    obj.Entries = containers.Map('KeyType','char','ValueType','any');
                    obj.Budget.CacheResets = obj.Budget.CacheResets+1;
                end
                obj.Entries(key) = value;
            end
            cost=value(1); f=value(2); T=value(3);
        end
    end
end
