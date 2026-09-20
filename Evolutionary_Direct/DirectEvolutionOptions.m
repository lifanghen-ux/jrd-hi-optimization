function options = DirectEvolutionOptions(data,varargin)
%DIRECTEVOLUTIONOPTIONS Checked options for the evolutionary-X Direct solver.
d = NormalizeJRDData(data);
p = inputParser;
integer = @(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0;
positive = @(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0;
addParameter(p,'Seed',20260919,@(x) integer(x)&&x<=2^32-1);
addParameter(p,'PopulationSize',max(40,min(160,4*d.N)),@(x) integer(x)&&x>=4);
addParameter(p,'Generations',200,@(x) integer(x)&&x>=1);
addParameter(p,'EliteCount',2,@(x) integer(x)&&x>=1);
addParameter(p,'TournamentSize',3,@(x) integer(x)&&x>=2);
addParameter(p,'CrossoverRate',0.85,@(x) positive(x)&&x<=1);
addParameter(p,'MutationRate',0.90,@(x) positive(x)&&x<=1);
addParameter(p,'IntensifyElites',2,@(x) integer(x));
addParameter(p,'IntensifyTrials',4,@(x) integer(x));
addParameter(p,'StallGenerations',Inf,@(x) isscalar(x)&&((isinf(x)&&x>0)||integer(x)));
addParameter(p,'GridStep',0.001,positive);
addParameter(p,'TMin',[],@(x) isempty(x)||positive(x));
addParameter(p,'TMax',[],@(x) isempty(x)||positive(x));
addParameter(p,'GridMethod','projection',@(x) ischar(x)&&ismember(x,{'projection','enumerate'}));
addParameter(p,'FValues',[],@(x) isempty(x)||(isnumeric(x)&&isvector(x)&&all(isfinite(x))&&all(x==fix(x))));
addParameter(p,'FixedF',[],@(x) isempty(x)||(isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)));
addParameter(p,'CacheLimit',200000,@(x) integer(x)&&x>=1);
addParameter(p,'Tolerance',1e-11,positive);
addParameter(p,'InitialPartitions',{},@(x) iscell(x));
parse(p,varargin{:}); options=p.Results;
assert(options.EliteCount<options.PopulationSize,'JRD:EvolutionOptions', ...
    'EliteCount must be smaller than PopulationSize.');
assert(options.TournamentSize<=options.PopulationSize,'JRD:EvolutionOptions', ...
    'TournamentSize cannot exceed PopulationSize.');
assert(options.IntensifyElites<=options.PopulationSize,'JRD:EvolutionOptions', ...
    'IntensifyElites cannot exceed PopulationSize.');
if isempty(options.TMin), options.TMin=options.GridStep; end
assert(options.TMin>0&&abs(options.TMin/options.GridStep-round(options.TMin/options.GridStep))<1e-10, ...
    'JRD:EvolutionOptions','TMin must lie on the T grid.');
if ~isempty(options.TMax)
    assert(options.TMax>=options.TMin,'JRD:EvolutionOptions','TMax must be at least TMin.');
    assert(abs((options.TMax-options.TMin)/options.GridStep- ...
        round((options.TMax-options.TMin)/options.GridStep))<1e-10, ...
        'JRD:EvolutionOptions','TMax must lie on the grid beginning at TMin.');
end
if ~isempty(options.FixedF)
    assert(options.FixedF>=d.FInf&&options.FixedF<=d.FSup,'JRD:EvolutionOptions', ...
        'FixedF is outside the data bounds.');
    options.FValues=options.FixedF;
elseif isempty(options.FValues)
    options.FValues=d.FInf:d.FSup;
else
    options.FValues=unique(options.FValues(:)');
    assert(all(options.FValues>=d.FInf&options.FValues<=d.FSup),'JRD:EvolutionOptions', ...
        'FValues are outside the data bounds.');
end
end
