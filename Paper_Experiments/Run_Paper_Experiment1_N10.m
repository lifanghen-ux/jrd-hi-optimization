function [Study,out]=Run_Paper_Experiment1_N10(varargin)
%RUN_PAPER_EXPERIMENT1_N10 Reproducible N=10 correctness/accuracy study.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'Runs',5,integer); addParameter(p,'BaseSeed',20260919,integer);
addParameter(p,'PopulationSize',80,@(x) integer(x)&&x>=4); addParameter(p,'Generations',250,integer);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
out=CreatePaperOutput(root,'Experiment1_N10',char(o.OutputRoot)); input=load(fullfile(root,'Data_N10.mat'),'data'); d=input.data;
Study=struct('SchemaVersion',1,'Experiment','N=10 reproducible validation', ...
    'Status','running','Config',o,'Input',d,'Manifest',JRDProjectManifest(root), ...
    'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
    'ClaimBoundary','grid DP is exact; evolutionary runs are heuristic unless they hit that certificate');
SavePaperStudy(fullfile(out,'study.mat'),Study);
Study.ExactContinuous=ExactDP_Direct(d);
Study.ExactGrid=ExactDP_DirectGrid(d,'GridStep',o.GridStep,'GridMethod','projection');
enumerated=EvaluateDirectGridPartition(Study.ExactGrid.GroupId,d,'GridStep',o.GridStep,'GridMethod','enumerate');
assert(abs(enumerated.TotalCost-Study.ExactGrid.TotalCost)<=1e-10*Study.ExactGrid.TotalCost, ...
    'JRD:GridMismatch','Projection and literal T enumeration disagree.');
Study.ExactGridEnumerationCheck=enumerated;
assert(Study.ExactGrid.TotalCost+1e-9>=Study.ExactContinuous.TotalCost, ...
    'JRD:GridBound','A discrete-grid value cannot beat its continuous relaxation.');
Study.Runs=cell(o.Runs,1); rows=cell(o.Runs,8);
for r=1:o.Runs
    seed=mod(o.BaseSeed+r-1,2^32); answer=EvolutionaryX_Direct(d,'Seed',seed, ...
        'PopulationSize',o.PopulationSize,'Generations',o.Generations,'GridStep',o.GridStep);
    gap=100*(answer.TotalCost-Study.ExactGrid.TotalCost)/Study.ExactGrid.TotalCost;
    hit=abs(answer.TotalCost-Study.ExactGrid.TotalCost)<=1e-9*Study.ExactGrid.TotalCost;
    Study.Runs{r}=answer; rows(r,:)={r,seed,answer.TotalCost,gap,hit,answer.GroupCount, ...
        answer.RuntimeSeconds,answer.Counters.GroupEvaluations};
    record=struct('Run',r,'Seed',seed,'Answer',answer); %#ok<NASGU>
    save(fullfile(out,'raw',sprintf('N10_run%03d.mat',r)),'record','-v7'); SavePaperStudy(fullfile(out,'study.mat'),Study);
    fprintf('Experiment1 N=10 run=%d TC=%.10f grid-gap=%.6g%% hit=%d\n',r,answer.TotalCost,gap,hit);
end
Study.RunTable=cell2table(rows,'VariableNames',{'Run','Seed','TotalCost','GridOptimalityGapPercent', ...
    'HitGridOptimum','GroupCount','RuntimeSeconds','GroupEvaluations'});
Study.Status='complete'; Study.CompletedAt=datestr(now,30);
writetable(Study.RunTable,fullfile(out,'runs.csv')); SavePaperStudy(fullfile(out,'study.mat'),Study);
end
