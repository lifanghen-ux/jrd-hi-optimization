function Study=PaperStrategyOutputs(Study,out)
%PAPERSTRATEGYOUTPUTS Rebuild all Exp3/4 output from committed solution records.
% Tables are never incrementally appended, so resuming a partial seed cannot
% duplicate rows. Complete X/T/f or T/K/F solutions also remain in study.mat.
isCoordination=strcmp(Study.ExperimentKind,'Exp4');
if isCoordination, names=Study.Cases; else, names=Study.Strategies; end
rawNames={'N','InstanceId','Strategy','Run','Seed','TotalCost','RuntimeSeconds', ...
    'PopulationSize','Generations','OrderingCost','DeliveryCost', ...
    'WarehouseHoldingCost','RetailHoldingCost','PenaltyCost','CostSumError','PairComplete'};
diagnosticNames={'N','InstanceId','Strategy','Run','Seed','TotalCost', ...
    'OrderingCost','DeliveryCost','WarehouseHoldingCost','RetailHoldingCost', ...
    'PenaltyCost','GroupOrKClassCount','StrictEdgeIsolationRate', ...
    'WeightedEdgeIsolationRate','DifferentKEdgeRate','PenaltyCoefficientAttenuation'};
curveNames={'N','InstanceId','Strategy','Run','Seed','Generation','BestTC','ElapsedSeconds','ObjectiveDefinition'};
solutionNames={'N','InstanceId','Strategy','Run','Seed','Item','GroupId','ReplenishmentPeriod','Frequency','K','BaseT'};
raw=cell(0,numel(rawNames)); diagnostic=cell(0,numel(diagnosticNames));
curves=cell(0,numel(curveNames)); solutions=cell(0,numel(solutionNames));
for ni=1:numel(Study.Config.NList)
    if isempty(Study.Inputs{ni}), continue; end
    d=NormalizeJRDData(Study.Inputs{ni}); instance=sprintf('FixedData_N%d',d.N);
    population=max(Study.Config.MinimumPopulation,Study.Config.PopulationFactor*d.N);
    for r=1:Study.Config.Runs
        for c=1:numel(names)
            a=Study.Records{ni,r,c}; if isempty(a), continue; end
            direct=startsWith(names{c},'Direct'); kind='Indirect'; if direct, kind='Direct'; end
            z=JRDAnalyzeSolution(d,a,kind);
            sumError=abs(z.OrderingCost+z.DeliveryCost+z.WarehouseHoldingCost+z.RetailHoldingCost+z.PenaltyCost-a.TotalCost);
            raw(end+1,:)={d.N,instance,names{c},r,a.Seed,a.TotalCost,a.RuntimeSeconds, ...
                population,Study.Config.Generations,z.OrderingCost,z.DeliveryCost, ...
                z.WarehouseHoldingCost,z.RetailHoldingCost,z.PenaltyCost,sumError, ...
                all(~cellfun(@isempty,Study.Records(ni,r,:)))}; %#ok<AGROW>
            diagnostic(end+1,:)={d.N,instance,names{c},r,a.Seed,a.TotalCost, ...
                z.OrderingCost,z.DeliveryCost,z.WarehouseHoldingCost,z.RetailHoldingCost,z.PenaltyCost, ...
                z.GroupOrKClassCount,z.StrictEdgeIsolationRate,z.WeightedEdgeIsolationRate, ...
                z.DifferentKEdgeRate,z.PenaltyCoefficientAttenuation}; %#ok<AGROW>
            if direct
                generation=a.Convergence.Generation; cost=a.Convergence.BestTC;
                elapsed=a.Convergence.ElapsedSeconds;
                group=a.GroupId(:); period=a.GroupT(group); frequency=a.GroupF(group);
                kval=nan(d.N,1); base=nan(d.N,1);
            else
                generation=(1:numel(a.ConvergenceTC))'; cost=a.ConvergenceTC(:);
                elapsed=nan(size(cost)); % Original AHDE does not measure per-generation time.
                group=nan(d.N,1); period=a.K(:)*a.T; frequency=a.F(:);
                kval=a.K(:); base=repmat(a.T,d.N,1);
            end
            for q=1:numel(cost)
                curves(end+1,:)={d.N,instance,names{c},r,a.Seed,generation(q),cost(q),elapsed(q), ...
                    [kind,' model TC (five original cost components)']}; %#ok<AGROW>
            end
            for item=1:d.N
                solutions(end+1,:)={d.N,instance,names{c},r,a.Seed,item,group(item),period(item), ...
                    frequency(item),kval(item),base(item)}; %#ok<AGROW>
            end
        end
    end
end
Study.RawTable=cell2table(raw,'VariableNames',rawNames);
Study.Diagnostics=cell2table(diagnostic,'VariableNames',diagnosticNames);
Study.ConvergenceTable=cell2table(curves,'VariableNames',curveNames);
Study.SolutionItems=cell2table(solutions,'VariableNames',solutionNames);
summary=cell(0,10);
for n=unique(Study.RawTable.N)'
    for c=1:numel(names)
        % Primary aggregates use exactly the same successful seed pairs for
        % all compared cases; partial solver results remain in raw_results.
        mask=Study.RawTable.N==n&strcmp(Study.RawTable.Strategy,names{c})&Study.RawTable.PairComplete;
        values=Study.RawTable.TotalCost(mask); runtime=Study.RawTable.RuntimeSeconds(mask);
        if isempty(values), continue; end
        sigma=NaN; if numel(values)>1, sigma=std(values); end
        summary(end+1,:)={n,names{c},numel(values),min(values),mean(values),median(values), ...
            sigma,max(values),100*sigma/mean(values),mean(runtime)}; %#ok<AGROW>
    end
end
Study.SummaryTable=cell2table(summary,'VariableNames',{'N','Strategy','Runs','BestTC', ...
    'MeanTC','MedianTC','StdTC','WorstTC','CVPercent','AverageRuntimeSeconds'});
if isCoordination
    paired=cell(0,13); comparison=cell(0,9);
    for ni=1:numel(Study.Config.NList)
        n=Study.Config.NList(ni);
        for r=1:Study.Config.Runs
            answers=reshape(Study.Records(ni,r,:),1,[]);
            if any(cellfun(@isempty,answers)), continue; end
            dc=PaperCoordinationSanity(answers{1}.TotalCost,answers{2}.TotalCost);
            ic=PaperCoordinationSanity(answers{3}.TotalCost,answers{4}.TotalCost);
            paired(end+1,:)={n,r,answers{1}.Seed,dc.CoordinatedTC,dc.FixedTC,dc.SavingPercent, ...
                ic.CoordinatedTC,ic.FixedTC,ic.SavingPercent,dc.IsAnomaly,ic.IsAnomaly,dc.Status,ic.Status}; %#ok<AGROW>
        end
    end
    Study.PairedSavings=cell2table(paired,'VariableNames',{'N','Run','Seed','DirectCoordinatedTC', ...
        'DirectF1TC','DirectCoordinationSavingPercent','IndirectCoordinatedTC','IndirectF1TC', ...
        'IndirectCoordinationSavingPercent','DirectHeuristicAnomaly','IndirectHeuristicAnomaly', ...
        'DirectSearchStatus','IndirectSearchStatus'});
    for n=unique(Study.PairedSavings.N)'
        m=Study.PairedSavings.N==n;
        dc=PaperCoordinationSanity(min(Study.PairedSavings.DirectCoordinatedTC(m)),min(Study.PairedSavings.DirectF1TC(m)));
        ic=PaperCoordinationSanity(min(Study.PairedSavings.IndirectCoordinatedTC(m)),min(Study.PairedSavings.IndirectF1TC(m)));
        comparison(end+1,:)={n,dc.CoordinatedTC,dc.FixedTC,dc.SavingPercent, ...
            ic.CoordinatedTC,ic.FixedTC,ic.SavingPercent,dc.IsAnomaly,ic.IsAnomaly}; %#ok<AGROW>
    end
    Study.Comparison=cell2table(comparison,'VariableNames',{'N','DirectCoordinatedBestTC','DirectF1BestTC', ...
        'DirectCoordinationSavingPercent','IndirectCoordinatedBestTC','IndirectF1BestTC', ...
        'IndirectCoordinationSavingPercent','DirectBestCostAnomaly','IndirectBestCostAnomaly'});
    anomalyNames={'N','Run','Seed','DirectHeuristicAnomaly','IndirectHeuristicAnomaly','DirectSearchStatus','IndirectSearchStatus'};
    Study.Anomalies=Study.PairedSavings(:,anomalyNames);
    pairedSummary=cell(0,9);
    for n=unique(Study.PairedSavings.N)'
        m=Study.PairedSavings.N==n;
        for strategy={'Direct','Indirect'}
            column=Study.PairedSavings.([strategy{1},'CoordinationSavingPercent']); v=column(m);
            column=Study.PairedSavings.([strategy{1},'HeuristicAnomaly']); anomaly=column(m);
            sigma=NaN; if numel(v)>1, sigma=std(v); end
            pairedSummary(end+1,:)={n,strategy{1},numel(v),mean(v),median(v),sigma,min(v),max(v),sum(anomaly)}; %#ok<AGROW>
        end
    end
    Study.PairedSummary=cell2table(pairedSummary,'VariableNames',{'N','Strategy','Pairs','MeanSavingPercent', ...
        'MedianSavingPercent','StdSavingPercent','MinSavingPercent','MaxSavingPercent','HeuristicAnomalyCount'});
    atomicWrite(Study.PairedSavings,fullfile(out,'paired_savings.csv'));
    atomicWrite(Study.Anomalies,fullfile(out,'anomalies.csv'));
else
    paired=cell(0,9); comparison=cell(0,8);
    for ni=1:numel(Study.Config.NList)
        n=Study.Config.NList(ni);
        for r=1:Study.Config.Runs
            a=Study.Records{ni,r,1}; b=Study.Records{ni,r,2};
            if isempty(a)||isempty(b), continue; end
            paired(end+1,:)={n,r,a.Seed,a.TotalCost,b.TotalCost,b.TotalCost-a.TotalCost, ...
                100*(b.TotalCost-a.TotalCost)/b.TotalCost,a.RuntimeSeconds,b.RuntimeSeconds}; %#ok<AGROW>
        end
    end
    Study.PairedComparison=cell2table(paired,'VariableNames',{'N','Run','Seed','DirectTC','IndirectTC', ...
        'IndirectMinusDirectTC','DirectSavingPercent','DirectRuntimeSeconds','IndirectRuntimeSeconds'});
    for n=unique(Study.PairedComparison.N)'
        m=Study.PairedComparison.N==n; a=Study.PairedComparison.DirectTC(m); b=Study.PairedComparison.IndirectTC(m);
        delta=Study.PairedComparison.IndirectMinusDirectTC(m); saving=Study.PairedComparison.DirectSavingPercent(m);
        sigma=NaN; if numel(delta)>1, sigma=std(delta); end
        comparison(end+1,:)={n,min(a),min(b),100*(min(b)-min(a))/min(b),mean(a<b),mean(delta),sigma,mean(saving)}; %#ok<AGROW>
    end
    Study.Comparison=cell2table(comparison,'VariableNames',{'N','DirectBestTC','IndirectBestTC', ...
        'DirectSavingPercent','DirectPairedSeedWinRate','MeanPairedCostDifference','StdPairedCostDifference','MeanPairedSavingPercent'});
    atomicWrite(Study.PairedComparison,fullfile(out,'paired_comparison.csv'));
end
atomicWrite(Study.RawTable,fullfile(out,'raw_results.csv'));
atomicWrite(Study.SummaryTable,fullfile(out,'summary.csv'));
atomicWrite(Study.Comparison,fullfile(out,'comparison.csv'));
atomicWrite(Study.Diagnostics,fullfile(out,'diagnostics.csv'));
atomicWrite(Study.ConvergenceTable,fullfile(out,'convergence.csv'));
atomicWrite(Study.SolutionItems,fullfile(out,'solution_items.csv'));
if isCoordination, atomicWrite(Study.PairedSummary,fullfile(out,'paired_summary.csv')); end
% Planned task status is exported even if there are no successful solutions.
taskRows=cell(0,11);
for ni=1:numel(Study.Config.NList)
    n=Study.Config.NList(ni);
    for r=1:Study.Config.Runs
        seed=mod(Study.Config.BaseSeed+1000003*n+r-1,2^32);
        for c=1:numel(names)
            status='pending'; identifier=''; message=''; tc=NaN; attempts=0;
            if isfield(Study,'AttemptCounts'), attempts=Study.AttemptCounts(ni,r,c); end
            if ~isempty(Study.Records{ni,r,c})
                status='complete'; tc=Study.Records{ni,r,c}.TotalCost;
            elseif isfield(Study,'Failures')&&~isempty(Study.Failures{ni,r,c})
                status='failed'; failure=Study.Failures{ni,r,c};
                identifier=failure.Identifier; message=failure.Message;
            end
            taskRows(end+1,:)={n,sprintf('FixedData_N%d',n),names{c},r,seed,status,attempts,tc,identifier,message,Study.Status}; %#ok<AGROW>
        end
    end
end
Study.TaskTable=cell2table(taskRows,'VariableNames',{'N','InstanceId','Strategy','Run','Seed', ...
    'Status','Attempts','TotalCost','ErrorIdentifier','ErrorMessage','StudyStatus'});
Study.FailedTasks=Study.TaskTable(strcmp(Study.TaskTable.Status,'failed'),:);
atomicWrite(Study.TaskTable,fullfile(out,'task_status.csv'));
atomicWrite(Study.FailedTasks,fullfile(out,'failed_tasks.csv'));
errorRows=cell(0,11);
if isfield(Study,'ErrorRecords')
    for e=1:numel(Study.ErrorRecords)
        error=Study.ErrorRecords(e);
        errorRows(end+1,:)={error.N,error.Strategy,error.Run,error.Seed,error.Attempt, ...
            error.Identifier,error.Message,error.OccurredAt,error.IsGlobalBlocker,error.Resolved,error.ElapsedSeconds}; %#ok<AGROW>
    end
end
Study.ErrorTable=cell2table(errorRows,'VariableNames',{'N','Strategy','Run','Seed','Attempt', ...
    'ErrorIdentifier','ErrorMessage','OccurredAt','IsGlobalBlocker','Resolved','ElapsedSeconds'});
atomicWrite(Study.ErrorTable,fullfile(out,'errors.csv'));
end

function atomicWrite(value,path)
temporary=[tempname(fileparts(path)),'.csv']; writetable(value,temporary);
[ok,message]=movefile(temporary,path,'f'); assert(ok,'JRD:ResultWrite','%s',message);
end
