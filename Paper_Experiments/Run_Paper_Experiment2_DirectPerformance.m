function [Study,out]=Run_Paper_Experiment2_DirectPerformance(varargin)
%RUN_PAPER_EXPERIMENT2_DIRECTPERFORMANCE N=30/50/100 algorithm study.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'NList',[30 50 100],@(x) isnumeric(x)&&isvector(x)&&all(ismember(x,[10 30 50 100])));
addParameter(p,'Runs',5,integer); addParameter(p,'BaseSeed',20260919,integer);
addParameter(p,'Generations',250,integer); addParameter(p,'PopulationFactor',4,integer);
addParameter(p,'MinimumPopulation',40,@(x) integer(x)&&x>=4);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
algorithms={'EvolutionaryX','GA_Direct','JADE_Direct','MS_VND_Direct'};
config=rmfield(o,{'OutputRoot','ResumeDir'}); manifest=JRDProjectManifest(root);
if isempty(o.ResumeDir)
    out=CreatePaperOutput(root,'Experiment2_DirectPerformance',char(o.OutputRoot));
    Study=struct('SchemaVersion',1,'Experiment','Direct algorithm performance', ...
        'Status','running','Config',config,'Algorithms',{algorithms},'Manifest',manifest, ...
        'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
        'BaselineRationale',['GA is the basic evolutionary label baseline; JADE is the strongest adaptive-DE label baseline; ' ...
        'MS-VND is the structure-aware non-evolutionary baseline. All returned partitions are re-scored by the same grid inner solver.'], ...
        'BudgetCaveat','same population/generation level for evolutionary methods; VND receives the new solver group-evaluation count; work units remain structurally different');
    Study.Inputs=cell(numel(o.NList),1); Study.Records=cell(numel(o.NList),o.Runs,numel(algorithms)); Study.RawRows={};
else
    out=char(o.ResumeDir); loaded=load(fullfile(out,'study.mat'),'Study'); Study=loaded.Study;
    assert(isequaln(Study.Config,config)&&isequal(Study.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Resume configuration, source, or fixed data changed.');
end
rows=Study.RawRows; Study.Status='running';
SavePaperStudy(fullfile(out,'study.mat'),Study);
for ni=1:numel(o.NList)
    input=load(fullfile(root,sprintf('Data_N%d.mat',o.NList(ni))),'data'); d=input.data; Study.Inputs{ni}=d;
    population=max(o.MinimumPopulation,o.PopulationFactor*d.N);
    for r=1:o.Runs
        if all(~cellfun(@isempty,Study.Records(ni,r,:))), continue; end
        seed=mod(o.BaseSeed+1000003*d.N+r-1,2^32);
        answers=cell(1,4);
        answers{1}=EvolutionaryX_Direct(d,'Seed',seed,'PopulationSize',population, ...
            'Generations',o.Generations,'GridStep',o.GridStep);
        answers{2}=RunLegacyDirectBaseline('GA_Direct',d,'Seed',seed,'PopulationSize',population, ...
            'Generations',o.Generations,'GridStep',o.GridStep);
        answers{3}=RunLegacyDirectBaseline('JADE_Direct',d,'Seed',seed,'PopulationSize',population, ...
            'Generations',o.Generations,'GridStep',o.GridStep);
        evaluationBudget=max(1,answers{1}.Counters.GroupEvaluations);
        native=MS_VND_Direct(d,'Seed',seed,'MaxSeconds',Inf,'MaxEvaluations',evaluationBudget, ...
            'Starts',4,'ILSIterations',10);
        rescoreTimer=tic; common=EvaluateDirectGridPartition(native.GroupId,d,'GridStep',o.GridStep); rescoreRuntime=toc(rescoreTimer);
        answers{4}=struct('Algorithm','MS_VND_Direct','TotalCost',common.TotalCost, ...
            'CommonGridSolution',common,'NativeSolution',native, ...
            'NativeRuntimeSeconds',native.RuntimeSeconds,'CommonRescoreSeconds',rescoreRuntime, ...
            'RuntimeSeconds',native.RuntimeSeconds+rescoreRuntime, ...
            'ComparisonMeaning','VND partition re-optimized with common grid inner solver');
        for a=1:4
            Study.Records{ni,r,a}=answers{a}; answer=answers{a};
            if a==1, groupCount=answer.GroupCount;
            else, groupCount=answer.CommonGridSolution.GroupCount; end
            rows(end+1,:)={d.N,algorithms{a},r,seed,answer.TotalCost,answer.RuntimeSeconds,groupCount,population,o.Generations}; %#ok<AGROW>
            record=struct('N',d.N,'Algorithm',algorithms{a},'Run',r,'Seed',seed,'Answer',answer); %#ok<NASGU>
            save(fullfile(out,'raw',sprintf('N%d_%s_run%03d.mat',d.N,algorithms{a},r)),'record','-v7');
        end
        Study.RawRows=rows;
        SavePaperStudy(fullfile(out,'study.mat'),Study);
        fprintf('Experiment2 N=%d run=%d new-grid-TC=%.10f\n',d.N,r,answers{1}.TotalCost);
    end
end
Study.RawTable=cell2table(rows,'VariableNames',{'N','Algorithm','Run','Seed','TotalCost', ...
    'RuntimeSeconds','GroupCount','PopulationSize','Generations'});
summary={};
for n=unique(Study.RawTable.N)'
    for a=1:numel(algorithms)
        mask=Study.RawTable.N==n&strcmp(Study.RawTable.Algorithm,algorithms{a}); v=Study.RawTable.TotalCost(mask); t=Study.RawTable.RuntimeSeconds(mask);
        sigma=NaN; if numel(v)>1, sigma=std(v); end
        summary(end+1,:)={n,algorithms{a},numel(v),min(v),mean(v),median(v),sigma,max(v),100*sigma/mean(v),mean(t)}; %#ok<AGROW>
    end
end
Study.SummaryTable=cell2table(summary,'VariableNames',{'N','Algorithm','Runs','BestTC','MeanTC', ...
    'MedianTC','StdTC','WorstTC','CVPercent','MeanRuntimeSeconds'});
Study.Status='complete'; Study.CompletedAt=datestr(now,30);
writetable(Study.RawTable,fullfile(out,'raw_results.csv')); writetable(Study.SummaryTable,fullfile(out,'summary.csv'));
SavePaperStudy(fullfile(out,'study.mat'),Study);
end
