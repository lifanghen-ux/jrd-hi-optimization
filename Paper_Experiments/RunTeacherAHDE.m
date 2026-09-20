function result=RunTeacherAHDE(data,varargin)
%RUNTEACHERAHDE Reproducible adapter around the unchanged teacher AHDE.m.
d=NormalizeJRDData(data); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'Seed',20260919,@(x) integer(x)&&x<=2^32-1);
addParameter(p,'Generations',200,integer); addParameter(p,'PopulationSize',max(40,4*d.N),@(x) integer(x)&&x>=4);
addParameter(p,'FixedF',[],@(x) isempty(x)||(isscalar(x)&&x==1)); parse(p,varargin{:}); o=p.Results;
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(o.Seed,'twister'); timer=tic;
if isempty(o.FixedF)
    [tc,t,K,F,curve,TArray,KArray,FArray]=AHDE(o.Generations,o.PopulationSize, ...
        d.KSup,d.KInf,d.FSup,d.FInf,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N);
    mode='coordinated: teacher AHDE unchanged';
else
    [tc,t,K,F,curve,KArray,TArray]=AHDE_FixedF1(o.Generations,o.PopulationSize, ...
        d.KSup,d.KInf,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N);
    FArray=repmat({ones(d.N,1)},1,o.Generations);
    mode='non-coordinated: AHDE structure constrained to F_i=1';
end
runtime=toc(timer); K=K(:); F=F(:);
[checked,ordering,warehouse,delivery,retail,penalty]=Fitness_Indirect(t,K,F,d);
assert(abs(tc-checked)<=1e-9*max(1,checked),'JRD:CostMismatch','AHDE result failed recomputation.');
result=struct('TotalCost',checked,'T',t,'K',K,'F',F, ...
    'OrderingCost',ordering,'DeliveryCost',delivery, ...
    'WarehouseHoldingCost',warehouse,'RetailHoldingCost',retail,'PenaltyCost',penalty, ...
    'Algorithm','AHDE','Mode',mode,'Seed',o.Seed,'Options',o, ...
    'RuntimeSeconds',runtime,'ConvergenceTC',curve(:), ...
    'TByGeneration',TArray(:),'KByGeneration',{KArray},'FByGeneration',{FArray}, ...
    'Optimality','heuristic feasible solution; no global certificate');
end
