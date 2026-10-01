function result=RunTeacherAHDE(data,varargin)
%RUNTEACHERAHDE Reproducible adapter around the unchanged teacher AHDE.m.
d=NormalizeJRDData(data); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'Seed',20260919,@(x) integer(x)&&x<=2^32-1);
addParameter(p,'Generations',500,integer); addParameter(p,'PopulationSize',max(40,10*d.N),@(x) integer(x)&&x>=4);
addParameter(p,'FixedF',[],@(x) isempty(x)||(isscalar(x)&&x==1)); parse(p,varargin{:}); o=p.Results;
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(o.Seed,'twister'); timer=tic;
fInf=d.FInf; fSup=d.FSup;
mode='coordinated: unchanged teacher AHDE';
if ~isempty(o.FixedF)
    assert(d.FInf<=1&&d.FSup>=1,'JRD:FrequencyBounds','The coordinated frequency domain must include one.');
    fInf=1; fSup=1;
    mode='fixed-F: unchanged teacher AHDE with FInf=FSup=1';
end
% Keep the original 2N-dimensional chromosome, random-number consumption,
% mutation, boundary repair, crossover and selection in BOTH frequency modes.
[tc,t,K,F,curve,TArray,KArray,FArray]=AHDE(o.Generations,o.PopulationSize, ...
    d.KSup,d.KInf,fSup,fInf,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N);
runtime=toc(timer); K=K(:); F=F(:);
assert(all(K>=d.KInf&K<=d.KSup&K==fix(K))&&all(F>=fInf&F<=fSup&F==fix(F)), ...
    'JRD:TeacherDecodedBounds','Teacher AHDE returned a decoded value outside the requested integer bounds.');
if ~isempty(o.FixedF)
    assert(all(F==1)&&all(cellfun(@(v) all(v(:)==1),FArray)), ...
        'JRD:FixedFrequency','The unchanged AHDE fixed-F run must return F=1 at every checkpoint.');
end
[checked,ordering,warehouse,delivery,retail,penalty]=Fitness_Indirect(t,K,F,d);
assert(abs(tc-checked)<=1e-9*max(1,checked),'JRD:CostMismatch','AHDE result failed recomputation.');
result=struct('TotalCost',checked,'T',t,'K',K,'F',F, ...
    'OrderingCost',ordering,'DeliveryCost',delivery, ...
    'WarehouseHoldingCost',warehouse,'RetailHoldingCost',retail,'PenaltyCost',penalty, ...
    'Algorithm','AHDE','Mode',mode,'Seed',o.Seed,'Options',o, ...
    'Implementation','unchanged teacher AHDE.m','SearchDimension',2*d.N, ...
    'ActualFrequencyBounds',[fInf fSup],'ObjectiveEvaluations',2*o.PopulationSize*o.Generations, ...
    'RandomnessNote','same seed ensures reproducibility, not identical search trajectories across algorithms or feasible domains', ...
    'RuntimeSeconds',runtime,'ConvergenceTC',curve(:), ...
    'TByGeneration',TArray(:),'KByGeneration',{KArray},'FByGeneration',{FArray}, ...
    'Optimality','heuristic feasible solution; no global certificate');
end
