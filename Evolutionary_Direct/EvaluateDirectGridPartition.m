function result=EvaluateDirectGridPartition(partition,data,varargin)
%EVALUATEDIRECTGRIDPARTITION Public checked evaluator for one Direct X.
d=NormalizeJRDData(data); options=DirectEvolutionOptions(d,'PopulationSize',4,'Generations',1,varargin{:});
cache=DirectGridCostCache(d,options); result=DirectGridPartitionCost(partition,cache);
result.Options=options; result.Counters=cache.Snapshot();
end
