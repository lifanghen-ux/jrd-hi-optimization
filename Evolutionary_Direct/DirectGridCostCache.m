classdef DirectGridCostCache < handle
    %DIRECTGRIDCOSTCACHE Subset cache bound to one data/options snapshot.
    properties (SetAccess=private)
        Data
        Options
        Entries
        Requests = 0
        Hits = 0
        Misses = 0
        Resets = 0
        GridCandidatesChecked = 0
    end
    methods
        function obj=DirectGridCostCache(data,options)
            obj.Data=NormalizeJRDData(data); obj.Options=options;
            obj.Entries=containers.Map('KeyType','char','ValueType','any');
        end
        function value=Get(obj,items)
            items=sort(items(:)');
            assert(~isempty(items)&&all(items>=1&items<=obj.Data.N&items==fix(items))&& ...
                numel(unique(items))==numel(items),'JRD:InvalidGroup','Invalid Direct group.');
            obj.Requests=obj.Requests+1; key=sprintf('%d_',items);
            if isKey(obj.Entries,key)
                obj.Hits=obj.Hits+1; value=obj.Entries(key); return;
            end
            value=DirectGridGroupCost(items,obj.Data,obj.Options);
            obj.Misses=obj.Misses+1;
            obj.GridCandidatesChecked=obj.GridCandidatesChecked+value.GridCandidatesChecked;
            if obj.Entries.Count>=obj.Options.CacheLimit
                obj.Entries=containers.Map('KeyType','char','ValueType','any');
                obj.Resets=obj.Resets+1;
            end
            obj.Entries(key)=value;
        end
        function counters=Snapshot(obj)
            counters=struct('GroupRequests',obj.Requests,'CacheHits',obj.Hits, ...
                'GroupEvaluations',obj.Misses,'CacheResets',obj.Resets, ...
                'CachedGroups',obj.Entries.Count, ...
                'GridCandidatesChecked',obj.GridCandidatesChecked);
        end
    end
end
