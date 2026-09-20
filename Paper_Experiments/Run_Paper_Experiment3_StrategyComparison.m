function [Study,out]=Run_Paper_Experiment3_StrategyComparison(varargin)
%RUN_PAPER_EXPERIMENT3_STRATEGYCOMPARISON New Direct versus teacher AHDE.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'NList',[10 30 50 100],@(x) isnumeric(x)&&isvector(x)&&all(ismember(x,[10 30 50 100])));
addParameter(p,'Runs',30,integer); addParameter(p,'BaseSeed',20260919,integer);
addParameter(p,'Generations',500,integer); addParameter(p,'PopulationFactor',4,integer);
addParameter(p,'MinimumPopulation',40,@(x) integer(x)&&x>=4);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
strategies={'DirectEvolutionaryX','IndirectTeacherAHDE'}; config=rmfield(o,{'OutputRoot','ResumeDir'}); manifest=JRDProjectManifest(root);
if isempty(o.ResumeDir)
    out=CreatePaperOutput(root,'Experiment3_StrategyComparison',char(o.OutputRoot));
    Study=struct('SchemaVersion',1,'Experiment','Direct versus Indirect strategy cost', ...
        'Status','running','Config',config,'Strategies',{strategies},'Manifest',manifest, ...
        'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
        'FairnessRule','same instance, seed, population and generation level; variable structures and inner work intentionally remain different', ...
        'TimeRole','runtime is reported but never decides which strategy has lower cost', ...
        'ClaimBoundary','large-scale values are best feasible costs, not proven global optima');
    Study.Inputs=cell(numel(o.NList),1); Study.Records=cell(numel(o.NList),o.Runs,2); Study.RawRows={}; Study.DiagnosticRows={};
else
    out=char(o.ResumeDir); loaded=load(fullfile(out,'study.mat'),'Study'); Study=loaded.Study;
    assert(isequaln(Study.Config,config)&&isequal(Study.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Resume configuration, source, or fixed data changed.');
end
rows=Study.RawRows; diagnostics=Study.DiagnosticRows; Study.Status='running';
SavePaperStudy(fullfile(out,'study.mat'),Study);
for ni=1:numel(o.NList)
    input=load(fullfile(root,sprintf('Data_N%d.mat',o.NList(ni))),'data'); d=input.data; Study.Inputs{ni}=d;
    population=max(o.MinimumPopulation,o.PopulationFactor*d.N);
    for r=1:o.Runs
        if all(~cellfun(@isempty,Study.Records(ni,r,:))), continue; end
        seed=mod(o.BaseSeed+1000003*d.N+r-1,2^32);
        % Alternate execution order only to reduce systematic machine-state effects.
        if mod(r,2), order=1:2; else, order=2:-1:1; end
        answers=cell(1,2);
        for s=order
            if s==1
                answers{s}=EvolutionaryX_Direct(d,'Seed',seed,'PopulationSize',population, ...
                    'Generations',o.Generations,'GridStep',o.GridStep);
            else
                answers{s}=RunTeacherAHDE(d,'Seed',seed,'PopulationSize',population,'Generations',o.Generations);
            end
        end
        strategyKind={'Direct','Indirect'};
        for s=1:2
            Study.Records{ni,r,s}=answers{s}; a=answers{s}; z=JRDAnalyzeSolution(d,a,strategyKind{s});
            rows(end+1,:)={d.N,strategies{s},r,seed,a.TotalCost,a.RuntimeSeconds,population,o.Generations}; %#ok<AGROW>
            diagnostics(end+1,:)={d.N,strategies{s},r,z.TotalCost,z.OrderingCost,z.DeliveryCost, ...
                z.WarehouseHoldingCost,z.RetailHoldingCost,z.PenaltyCost,z.GroupOrKClassCount, ...
                z.StrictEdgeIsolationRate,z.WeightedEdgeIsolationRate,z.DifferentKEdgeRate,z.PenaltyCoefficientAttenuation}; %#ok<AGROW>
            record=struct('N',d.N,'Strategy',strategies{s},'Run',r,'Seed',seed,'Answer',a,'Diagnostics',z); %#ok<NASGU>
            save(fullfile(out,'raw',sprintf('N%d_%s_run%03d.mat',d.N,strategies{s},r)),'record','-v7');
        end
        Study.RawRows=rows; Study.DiagnosticRows=diagnostics;
        SavePaperStudy(fullfile(out,'study.mat'),Study);
        fprintf('Experiment3 N=%d run=%d Direct=%.10f Indirect=%.10f saving=%.4f%%\n', ...
            d.N,r,answers{1}.TotalCost,answers{2}.TotalCost,100*(answers{2}.TotalCost-answers{1}.TotalCost)/answers{2}.TotalCost);
    end
end
Study.RawTable=cell2table(rows,'VariableNames',{'N','Strategy','Run','Seed','TotalCost','RuntimeSeconds','PopulationSize','Generations'});
Study.Diagnostics=cell2table(diagnostics,'VariableNames',{'N','Strategy','Run','TotalCost','OrderingCost', ...
    'DeliveryCost','WarehouseHoldingCost','RetailHoldingCost','PenaltyCost','GroupOrKClassCount', ...
    'StrictEdgeIsolationRate','WeightedEdgeIsolationRate','DifferentKEdgeRate','PenaltyCoefficientAttenuation'});
comparison={}; summary={};
for n=unique(Study.RawTable.N)'
    direct=Study.RawTable.TotalCost(Study.RawTable.N==n&strcmp(Study.RawTable.Strategy,strategies{1}));
    indirect=Study.RawTable.TotalCost(Study.RawTable.N==n&strcmp(Study.RawTable.Strategy,strategies{2}));
    comparison(end+1,:)={n,min(direct),min(indirect),100*(min(indirect)-min(direct))/min(indirect),mean(direct<indirect)}; %#ok<AGROW>
    for s=1:2
        mask=Study.RawTable.N==n&strcmp(Study.RawTable.Strategy,strategies{s}); v=Study.RawTable.TotalCost(mask); t=Study.RawTable.RuntimeSeconds(mask);
        sigma=NaN; if numel(v)>1, sigma=std(v); end
        summary(end+1,:)={n,strategies{s},numel(v),min(v),mean(v),median(v),sigma,max(v),100*sigma/mean(v),mean(t)}; %#ok<AGROW>
    end
end
Study.Comparison=cell2table(comparison,'VariableNames',{'N','DirectBestTC','IndirectBestTC','DirectSavingPercent','DirectPairedSeedWinRate'});
Study.SummaryTable=cell2table(summary,'VariableNames',{'N','Strategy','Runs','BestTC','MeanTC','MedianTC','StdTC','WorstTC','CVPercent','MeanRuntimeSeconds'});
Study.Status='complete'; Study.CompletedAt=datestr(now,30);
writetable(Study.RawTable,fullfile(out,'raw_results.csv')); writetable(Study.SummaryTable,fullfile(out,'summary.csv'));
writetable(Study.Comparison,fullfile(out,'comparison.csv')); writetable(Study.Diagnostics,fullfile(out,'diagnostics.csv'));
SavePaperStudy(fullfile(out,'study.mat'),Study);
end
