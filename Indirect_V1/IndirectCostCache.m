classdef IndirectCostCache < handle
    properties (SetAccess=private)
        Data
        Budget
        Limit
        Entries
    end
    methods
        function obj=IndirectCostCache(data,budget,limit)
            obj.Data=NormalizeJRDData(data); obj.Budget=budget; obj.Limit=limit;
            obj.Entries=containers.Map('KeyType','char','ValueType','any');
        end
        function result=Get(obj,K)
            K=K(:);
            assert(numel(K)==obj.Data.N && all(K>=obj.Data.KInf & ...
                K<=obj.Data.KSup & K==fix(K)),'JRD:InvalidK','Invalid integer multipliers.');
            obj.Budget.Requests=obj.Budget.Requests+1; obj.Budget.Check();
            key=sprintf('%d_',K);
            if isKey(obj.Entries,key)
                obj.Budget.CacheHits=obj.Budget.CacheHits+1; result=obj.Entries(key);
            else
                obj.Budget.Begin();
                [result,intervals]=IndirectInnerKernel(K,obj.Data);
                obj.Budget.InnerCandidates=obj.Budget.InnerCandidates+intervals;
                if obj.Entries.Count>=obj.Limit
                    obj.Entries=containers.Map('KeyType','char','ValueType','any');
                    obj.Budget.CacheResets=obj.Budget.CacheResets+1;
                end
                obj.Entries(key)=result;
            end
        end
    end
end
