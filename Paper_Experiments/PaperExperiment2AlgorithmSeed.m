function seed=PaperExperiment2AlgorithmSeed(n,instanceSeed,run,baseSeed,instanceSource)
%PAPEREXPERIMENT2ALGORITHMSEED Stable task identity when adding instances/runs.
if strcmp(instanceSource,'fixed')
    seed=mod(baseSeed+1000003*n+run-1,2^32);
else
    seed=mod(baseSeed+1000003*n+10007*instanceSeed+run-1,2^32);
end
end
