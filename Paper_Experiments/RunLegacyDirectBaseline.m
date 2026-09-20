function result=RunLegacyDirectBaseline(name,data,varargin)
%RUNLEGACYDIRECTBASELINE Run a preserved legacy Direct solver, then re-score X.
d=NormalizeJRDData(data); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'Seed',20260919,@(x) integer(x)&&x<=2^32-1);
addParameter(p,'Generations',200,integer); addParameter(p,'PopulationSize',max(40,4*d.N),@(x) integer(x)&&x>=4);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
parse(p,varargin{:}); o=p.Results;
assert(ismember(name,{'GA_Direct','JADE_Direct'}),'JRD:Baseline','Unsupported legacy baseline.');
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(o.Seed,'twister'); solver=str2func(name); timer=tic;
[nativeTC,nativeT,groupLabels,F,curve]=solver(o.Generations,o.PopulationSize, ...
    d.KSup,d.KInf,d.FSup,d.FInf,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N);
runtime=toc(timer);
legacy=Describe_Legacy_Solution('Direct',groupLabels,F,nativeT,d);
assert(abs(nativeTC-legacy.RecomputedTC)<=1e-9*max(1,nativeTC),'JRD:CostMismatch','Legacy result failed.');
rescoreTimer=tic; common=EvaluateDirectGridPartition(legacy.GroupId,d,'GridStep',o.GridStep); rescoreRuntime=toc(rescoreTimer);
result=struct('Algorithm',name,'Seed',o.Seed,'Options',o,'NativeTotalCost',nativeTC, ...
    'NativeSolution',legacy,'CommonGridSolution',common,'TotalCost',common.TotalCost, ...
    'NativeRuntimeSeconds',runtime,'CommonRescoreSeconds',rescoreRuntime, ...
    'RuntimeSeconds',runtime+rescoreRuntime,'ConvergenceTC',curve(:), ...
    'ComparisonMeaning','legacy partition re-optimized with the common grid inner solver');
end
