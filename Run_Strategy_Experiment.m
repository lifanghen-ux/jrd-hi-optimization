function [Study,out]=Run_Strategy_Experiment(varargin)
% Completion-based strategy comparison. Time is diagnostic only.
root=Setup_JRD(); p=inputParser;
integer=@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v==fix(v)&&v>=1;
schedule=@(v) isnumeric(v)&&isvector(v)&&~isempty(v)&&all(isfinite(v))&&all(v==fix(v))&&all(v>=1)&&all(diff(v)>=0);
addParameter(p,'Phase','validation',@(v) ismember(v,{'validation','formal'}));
addParameter(p,'NList',[10 30 50 100],@(v) isnumeric(v)&&isvector(v)&&~isempty(v)&&all(ismember(v,[10 30 50 100]))&&numel(unique(v))==numel(v));
addParameter(p,'Runs',30,integer);
addParameter(p,'StartsSchedule',[4 8 16],@(v) schedule(v)&&all(v>=2));
addParameter(p,'PerturbSchedule',[10 20 40],schedule);
addParameter(p,'BaseSeed',20260909,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=0&&v==fix(v)&&v<2^32);
addParameter(p,'StableLevels',2,integer);
addParameter(p,'RelativeImprovementTolerance',1e-6,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0);
addParameter(p,'RelativeSpreadTolerance',1e-3,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0);
addParameter(p,'PerturbFraction',0.1,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0&&v<=1);
addParameter(p,'IndirectNeighborhoodProfile','coordinate_swap_block_conflict',@(v) ischar(v)&& ...
    ismember(v,{'coordinate','coordinate_swap','coordinate_swap_block', ...
    'coordinate_swap_block_conflict'}));
addParameter(p,'BlockValuesPerItem',3,integer);
addParameter(p,'BlockPartnersPerItem',2,integer);
addParameter(p,'BlockConflictPairLimit',200,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v==fix(v)&&v>=0);
addParameter(p,'OutputRoot',fullfile(root,'Results_Completion'),@ischar);
addParameter(p,'ResumeDir','',@ischar);
parse(p,varargin{:}); o=p.Results; levels=numel(o.StartsSchedule);
assert(levels==numel(o.PerturbSchedule),'JRD:Schedule','Schedules must have equal lengths.');
assert(levels>=o.StableLevels+1,'JRD:Schedule','Need a baseline plus the required stability levels.');
manifest=JRDProjectManifest(root);
if strcmp(o.Phase,'formal')
    assert(all(diff(o.StartsSchedule)>0 | diff(o.PerturbSchedule)>0), ...
        'JRD:Schedule','Formal levels must increase starts or perturbations, not repeat identical work.');
    gate=load(fullfile(root,'Validation_V1','completion_readiness.mat'),'readiness');
    assert(strcmp(gate.readiness.Status,'PASS')&&isequal(gate.readiness.Manifest,manifest), ...
        'JRD:StaleValidation','Run Test_JRD_Completion and Test_JRD_All before formal use.');
    oldGate=load(fullfile(root,'Validation_V1','readiness.mat'),'readiness');
    assert(strcmp(oldGate.readiness.Status,'PASS')&&isequal(oldGate.readiness.Manifest,manifest),'JRD:StaleValidation','Legacy/math validation is stale.');
    assert(o.Runs>=30,'JRD:TooFewRuns','Formal study requires >=30 seeds.');
end
config=rmfield(o,{'ResumeDir','OutputRoot'}); kinds={'Indirect','Direct'};
if isempty(o.ResumeDir)
    if ~isfolder(o.OutputRoot), mkdir(o.OutputRoot); end
    out=tempname(o.OutputRoot); mkdir(out);
    Study=struct('SchemaVersion',2,'Status','running','Config',config,'Manifest',manifest, ...
        'StartedAt',datestr(now,30),'LevelsCompleted',0,'Records',{{}},'Summary',[], ...
        'StopReason','','Optimality','heuristic comparison unless bounds separate', ...
        'TimeRole','diagnostic only; no time or evaluation cutoff','StableCount',zeros(2,numel(o.NList)));
    Study.Inputs=cell(1,numel(o.NList)); Study.Bounds=Study.Inputs;
    Study.Source=struct('RelativePath',{},'Text',{});
    for j=1:numel(manifest)
        if endsWith(manifest(j).RelativePath,'.m')
            Study.Source(end+1)=struct('RelativePath',manifest(j).RelativePath,'Text',fileread(fullfile(root,manifest(j).RelativePath)));
        end
    end
    for j=1:numel(o.NList)
        loaded=load(fullfile(root,sprintf('Data_N%d.mat',o.NList(j))),'data');
        Study.Inputs{j}=loaded.data; Study.Bounds{j}=JRDStrategyBounds(loaded.data);
    end
    Study.Records=cell(levels,2,numel(o.NList),o.Runs);
    Study.CumulativeBest=Inf(2,numel(o.NList)); Study.BestAnswers=cell(2,numel(o.NList));
    JRDAtomicSave(fullfile(out,'study.mat'),Study);
else
    out=o.ResumeDir; loaded=load(fullfile(out,'study.mat'),'payload'); Study=loaded.payload;
    previous=Study.Config;
    % Permit only a prefix-preserving schedule extension. Existing work is reused.
    oldLevels=numel(previous.StartsSchedule);
    assert(levels>=oldLevels&&isequal(previous.StartsSchedule,o.StartsSchedule(1:oldLevels))&& ...
        isequal(previous.PerturbSchedule,o.PerturbSchedule(1:oldLevels))&& ...
        isequal(rmfield(previous,{'StartsSchedule','PerturbSchedule'}),rmfield(config,{'StartsSchedule','PerturbSchedule'}))&& ...
        isequal(Study.Manifest,manifest),'JRD:StaleCheckpoint','Resume configuration/source/data mismatch.');
    if levels>oldLevels
        Study.Records(levels,2,numel(o.NList),o.Runs)={[]}; Study.Config=config;
    elseif strcmp(Study.Status,'search_stable')||Study.LevelsCompleted==levels, return;
    end
end
Study.Status='running'; JRDAtomicSave(fullfile(out,'study.mat'),Study);
for level=Study.LevelsCompleted+1:levels
    % Persist the pre-level baseline: resuming midway must not mistake the
    % already saved within-level improvements for zero improvement.
    if ~isfield(Study,'ActiveLevel')||Study.ActiveLevel~=level
        Study.ActiveLevel=level; Study.LevelBaseline=Study.CumulativeBest;
        JRDAtomicSave(fullfile(out,'study.mat'),Study);
    end
    previousBest=Study.LevelBaseline; levelRows=cell(0,12); spread=zeros(size(previousBest));
    for j=1:numel(o.NList)
        n=o.NList(j);
        for r=1:o.Runs
            % N-based seeds do not change when NList order or Runs changes.
            seed=mod(o.BaseSeed+1000003*n+r-1,2^32);
            order=1:2; if mod(r+level,2)==0, order=2:-1:1; end
            for s=order
                if isempty(Study.Records{level,s,j,r})
                    file=fullfile(out,'tasks',sprintf('L%02d_N%d_%s_R%03d.mat',level,n,kinds{s},r));
                    answer=JRDCompleteSearch(Study.Inputs{j},kinds{s},'Seed',seed, ...
                        'Starts',o.StartsSchedule(level),'ILSIterations',o.PerturbSchedule(level), ...
                        'PerturbFraction',o.PerturbFraction, ...
                        'IndirectNeighborhoodProfile',o.IndirectNeighborhoodProfile, ...
                        'BlockValuesPerItem',o.BlockValuesPerItem, ...
                        'BlockPartnersPerItem',o.BlockPartnersPerItem, ...
                        'BlockConflictPairLimit',o.BlockConflictPairLimit,'Checkpoint',file);
                    Study.Records{level,s,j,r}=answer;
                    if answer.TotalCost<Study.CumulativeBest(s,j)
                        Study.CumulativeBest(s,j)=answer.TotalCost; Study.BestAnswers{s,j}=answer;
                    end
                    JRDAtomicSave(fullfile(out,'study.mat'),Study);
                end
            end
        end
        for s=1:2
            answers=Study.Records(level,s,j,:); costs=cellfun(@(a) a.TotalCost,answers); costs=costs(:);
            spread(s,j)=(max(costs)-min(costs))/max(1,abs(min(costs)));
            improvement=(previousBest(s,j)-Study.CumulativeBest(s,j))/max(1,abs(previousBest(s,j)));
            if level>1 && improvement<=o.RelativeImprovementTolerance
                Study.StableCount(s,j)=Study.StableCount(s,j)+1;
            else, Study.StableCount(s,j)=0; end
            lb=Study.Bounds{j}.([kinds{s},'LowerBound']);
            gap=max(0,(Study.CumulativeBest(s,j)-lb)/max(1,abs(Study.CumulativeBest(s,j))));
            levelRows(end+1,:)={level,n,kinds{s},o.Runs,min(costs),mean(costs),max(costs), ...
                Study.CumulativeBest(s,j),spread(s,j),Study.StableCount(s,j),lb,gap};
        end
    end
    t=cell2table(levelRows,'VariableNames',{'Level','N','Strategy','Runs','LevelBestTC','LevelMeanTC', ...
        'LevelWorstTC','CumulativeBestTC','RelativeSeedSpread','StableLevels','LowerBound','RelativeBoundGap'});
    if isempty(Study.Summary), Study.Summary=t; else, Study.Summary=[Study.Summary;t]; end
    Study.LevelsCompleted=level; Study.LastRelativeSeedSpread=spread;
    Study.Comparison=table(o.NList(:),Study.CumulativeBest(1,:)',Study.CumulativeBest(2,:)', ...
        100*(Study.CumulativeBest(1,:)'-Study.CumulativeBest(2,:)')./Study.CumulativeBest(1,:)', ...
        'VariableNames',{'N','IndirectBestTC','DirectBestTC','BestCostSavingPercent'});
    conclusions=cell(numel(o.NList),1);
    for j=1:numel(o.NList)
        b=Study.Bounds{j}; margin=1e-9*max(1,max(Study.CumulativeBest(:,j)));
        if Study.CumulativeBest(2,j)<b.IndirectLowerBound-margin
            conclusions{j}='Direct optimal cost lower, separated by bound';
        elseif Study.CumulativeBest(1,j)<b.DirectLowerBound-margin
            conclusions{j}='Indirect optimal cost lower, separated by bound';
        elseif ~isempty(b.DirectExact)&&~isempty(b.IndirectExact)
            delta=b.IndirectExact.TotalCost-b.DirectExact.TotalCost;
            if abs(delta)<=margin, conclusions{j}='Exact costs equal within numerical tolerance';
            elseif delta>0, conclusions{j}='Direct exact optimal cost lower';
            else, conclusions{j}='Indirect exact optimal cost lower'; end
        else, conclusions{j}='Unproven optimal ordering; compare best feasible costs only'; end
    end
    Study.Comparison.Conclusion=conclusions;
    diagnostics=cell(2*numel(o.NList),18); diagnosticRow=0;
    for j=1:numel(o.NList)
        for s=1:2
            diagnosticRow=diagnosticRow+1;
            z=JRDAnalyzeSolution(Study.Inputs{j},Study.BestAnswers{s,j},kinds{s});
            diagnostics(diagnosticRow,:)={z.N,z.Strategy,z.TotalCost,z.OrderingCost, ...
                z.DeliveryCost,z.WarehouseHoldingCost,z.RetailHoldingCost,z.PenaltyCost, ...
                z.MajorOrderingCost,z.MinorOrderingCost,z.PositivePenaltyEdges, ...
                z.GroupOrKClassCount,z.StrictEdgeIsolationRate,z.WeightedEdgeIsolationRate, ...
                z.DifferentKEdgeRate,z.PenaltyCoefficientAttenuation, ...
                Study.BestAnswers{s,j}.StartsCompleted,Study.BestAnswers{s,j}.Perturbations};
        end
    end
    Study.Diagnostics=cell2table(diagnostics,'VariableNames',{'N','Strategy','TotalCost', ...
        'OrderingCost','DeliveryCost','WarehouseHoldingCost','RetailHoldingCost','PenaltyCost', ...
        'MajorOrderingCost','MinorOrderingCost','PositivePenaltyEdges','GroupOrKClassCount', ...
        'StrictEdgeIsolationRate','WeightedEdgeIsolationRate','DifferentKEdgeRate', ...
        'PenaltyCoefficientAttenuation','StartsCompleted','Perturbations'});
    % If an exact answer is known, do not accept stable-but-wrong heuristic
    % costs as sufficient search. The exact answer is never injected.
    certificateReached=true;
    for j=1:numel(o.NList)
        for s=1:2
            exact=Study.Bounds{j}.([kinds{s},'Exact']);
            if ~isempty(exact)
                certificateReached=certificateReached && ...
                    (Study.CumulativeBest(s,j)-exact.TotalCost)/max(1,abs(exact.TotalCost))<=o.RelativeImprovementTolerance;
            end
        end
    end
    Study.KnownCertificatesReached=certificateReached;
    stable=all(Study.StableCount(:)>=o.StableLevels)&&all(spread(:)<=o.RelativeSpreadTolerance)&&certificateReached;
    if stable, Study.Status='search_stable'; Study.StopReason='joint cost stability and seed-spread criteria; not global proof';
    elseif level==levels, Study.Status='schedule_exhausted_not_stable'; Study.StopReason='all configured tasks complete; extend schedule before claiming stability'; end
    JRDAtomicSave(fullfile(out,'study.mat'),Study);
    writetable(Study.Summary,fullfile(out,'summary.csv'));
    writetable(Study.Comparison,fullfile(out,'comparison.csv'));
    writetable(Study.Diagnostics,fullfile(out,'diagnostics.csv'));
    fprintf('Level %d completed: %s. Results: %s\n',level,Study.Status,out);
    if stable, break; end
end
end
