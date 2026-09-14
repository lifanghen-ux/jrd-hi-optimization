function options = JRDSearchOptions(varargin)
p = inputParser;
integer = @(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v==fix(v)&&v>=0;
positive = @(v) isnumeric(v)&&isscalar(v)&&v>0&&~isnan(v);
addParameter(p,'Seed',20260909,@(v) integer(v)&&v<=2^32-1);
addParameter(p,'MaxSeconds',30,positive);
addParameter(p,'MaxEvaluations',Inf,@(v) positive(v)&&(isinf(v)||v==fix(v)));
addParameter(p,'Starts',8,@(v) integer(v)&&v>=2);
addParameter(p,'ILSIterations',20,integer);
addParameter(p,'PerturbMoves',3,@(v) integer(v)&&v>=1);
addParameter(p,'CacheLimit',50000,@(v) integer(v)&&v>=1);
addParameter(p,'SplitTrials',6,integer);
addParameter(p,'Tolerance',1e-11,@(v) positive(v)&&isfinite(v));
addParameter(p,'UseTimeBudgetFully',false,@(v) islogical(v)&&isscalar(v));
addParameter(p,'IndirectNeighborhoodProfile','coordinate_swap',@(v) ischar(v)&& ...
    ismember(v,{'coordinate','coordinate_swap','coordinate_swap_block', ...
    'coordinate_swap_block_conflict'}));
addParameter(p,'BlockValuesPerItem',3,@(v) integer(v)&&v>=1);
addParameter(p,'BlockPartnersPerItem',2,@(v) integer(v)&&v>=1);
addParameter(p,'BlockConflictPairLimit',200,integer);
parse(p,varargin{:});
options = p.Results;
assert(~options.UseTimeBudgetFully || isfinite(options.MaxSeconds), ...
    'JRD:UnboundedSearch','Full-time search requires a finite time budget.');
end
