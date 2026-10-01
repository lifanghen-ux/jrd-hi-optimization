function answer=RunPaperStrategyCase(data,name,seed,population,generations,gridStep)
%RUNPAPERSTRATEGYCASE One independent Exp3/4 solver call and model checks.
fixed=endsWith(name,'_F1'); frequencyArgs={};
if fixed, frequencyArgs={'FixedF',1}; end
if startsWith(name,'Direct')
    answer=EvolutionaryX_Direct(data,'Seed',seed,'PopulationSize',population, ...
        'Generations',generations,'GridStep',gridStep,frequencyArgs{:});
    JRDAnalyzeSolution(data,answer,'Direct');
    if fixed
        assert(all(answer.GroupF(:)==1),'JRD:FixedFrequency','Direct fixed-f solution has a non-one frequency.');
    end
else
    answer=RunTeacherAHDE(data,'Seed',seed,'PopulationSize',population, ...
        'Generations',generations,frequencyArgs{:});
    JRDAnalyzeSolution(data,answer,'Indirect');
    if fixed
        assert(all(answer.F(:)==1),'JRD:FixedFrequency','Indirect fixed-F solution has a non-one frequency.');
    end
end
end
