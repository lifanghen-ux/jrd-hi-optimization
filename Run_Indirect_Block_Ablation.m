function [Ablation,out]=Run_Indirect_Block_Ablation(varargin)
% Pre-registered paired multi-seed ablation. Time is diagnostic only.
root=Setup_JRD(); p=inputParser;
integer=@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v==fix(v)&&v>=1;
addParameter(p,'Phase','validation',@(v) ismember(v,{'validation','formal'}));
addParameter(p,'NList',[10 30 50 100],@(v) isnumeric(v)&&isvector(v)&&~isempty(v)&& ...
    all(ismember(v,[10 30 50 100]))&&numel(unique(v))==numel(v));
addParameter(p,'Runs',10,integer);
addParameter(p,'Starts',4,@(v) integer(v)&&v>=2);
addParameter(p,'ILSIterations',10,integer);
addParameter(p,'BaseSeed',20260909,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=0&&v==fix(v)&&v<2^32);
addParameter(p,'PerturbFraction',0.1,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0&&v<=1);
addParameter(p,'BlockValuesPerItem',3,integer);
addParameter(p,'BlockPartnersPerItem',2,integer);
addParameter(p,'BlockConflictPairLimit',200,@(v) isnumeric(v)&&isscalar(v)&&isfinite(v)&&v==fix(v)&&v>=0);
addParameter(p,'OutputRoot',fullfile(root,'Results_Ablation'),@ischar);
addParameter(p,'ResumeDir','',@ischar);
parse(p,varargin{:}); o=p.Results;
profiles={'coordinate','coordinate_swap','coordinate_swap_block','coordinate_swap_block_conflict'};
labels={'C','C+S','C+S+B','C+S+B+P'};
manifest=JRDProjectManifest(root);
if strcmp(o.Phase,'formal')
    gate=load(fullfile(root,'Validation_V1','completion_readiness.mat'),'readiness');
    assert(strcmp(gate.readiness.Status,'PASS')&&isequal(gate.readiness.Manifest,manifest), ...
        'JRD:StaleValidation','Run Test_JRD_All and Test_JRD_Completion first.');
    oldGate=load(fullfile(root,'Validation_V1','readiness.mat'),'readiness');
    assert(strcmp(oldGate.readiness.Status,'PASS')&&isequal(oldGate.readiness.Manifest,manifest), ...
        'JRD:StaleValidation','Legacy/math validation is stale. Run Test_JRD_All again.');
    assert(o.Runs>=30,'JRD:TooFewRuns','Formal ablation requires at least 30 paired seeds.');
end
config=rmfield(o,{'OutputRoot','ResumeDir'}); config.Profiles=profiles; config.Labels=labels;
config.PrimaryEndpoint='paired cost change and best feasible cost across seeds';
config.Interpretation='algorithm capability ablation, not a Direct-vs-Indirect strategy conclusion';
if isempty(o.ResumeDir)
    if ~isfolder(o.OutputRoot), mkdir(o.OutputRoot); end
    out=tempname(o.OutputRoot); mkdir(out);
    Ablation=struct('SchemaVersion',1,'Status','running','Config',config, ...
        'Manifest',manifest,'StartedAt',datestr(now,30),'Records',{{}}, ...
        'TimeRole','diagnostic only; no time/evaluation cutoff');
    Ablation.Inputs=cell(1,numel(o.NList));
    for j=1:numel(o.NList)
        loaded=load(fullfile(root,sprintf('Data_N%d.mat',o.NList(j))),'data'); Ablation.Inputs{j}=loaded.data;
    end
    Ablation.Records=cell(numel(profiles),numel(o.NList),o.Runs);
    JRDAtomicSave(fullfile(out,'ablation.mat'),Ablation);
else
    out=o.ResumeDir; loaded=load(fullfile(out,'ablation.mat'),'payload'); Ablation=loaded.payload;
    assert(isequal(Ablation.Config,config)&&isequal(Ablation.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Ablation configuration/source/data mismatch.');
    if strcmp(Ablation.Status,'complete'), return; end
end
for j=1:numel(o.NList)
    n=o.NList(j);
    for r=1:o.Runs
        seed=mod(o.BaseSeed+1000003*n+r-1,2^32);
        order=circshift(1:numel(profiles),mod(r-1,numel(profiles)));
        for q=order
            if isempty(Ablation.Records{q,j,r})
                checkpoint=fullfile(out,'tasks',sprintf('N%d_%s_R%03d.mat',n,labels{q},r));
                answer=JRDCompleteSearch(Ablation.Inputs{j},'Indirect','Seed',seed, ...
                    'Starts',o.Starts,'ILSIterations',o.ILSIterations, ...
                    'PerturbFraction',o.PerturbFraction, ...
                    'IndirectNeighborhoodProfile',profiles{q}, ...
                    'BlockValuesPerItem',o.BlockValuesPerItem, ...
                    'BlockPartnersPerItem',o.BlockPartnersPerItem, ...
                    'BlockConflictPairLimit',o.BlockConflictPairLimit,'Checkpoint',checkpoint);
                Ablation.Records{q,j,r}=answer;
                JRDAtomicSave(fullfile(out,'ablation.mat'),Ablation);
            end
        end
    end
end
raw=cell(numel(profiles)*numel(o.NList)*o.Runs,24); row=0;
summary=cell(numel(profiles)*numel(o.NList),15); sr=0;
for j=1:numel(o.NList)
    costs=zeros(numel(profiles),o.Runs);
    for q=1:numel(profiles)
        for r=1:o.Runs
            a=Ablation.Records{q,j,r}; d=JRDAnalyzeSolution(Ablation.Inputs{j},a,'Indirect');
            costs(q,r)=a.TotalCost; row=row+1;
            raw(row,:)={o.NList(j),r,a.Options.Seed,labels{q},profiles{q},a.TotalCost, ...
                d.OrderingCost,d.DeliveryCost,d.WarehouseHoldingCost,d.RetailHoldingCost,d.PenaltyCost, ...
                d.GroupOrKClassCount,d.DifferentKEdgeRate,d.PenaltyCoefficientAttenuation, ...
                a.StartsCompleted,a.Perturbations,a.LocalSearchesCompleted,a.RuntimeSeconds, ...
                a.NeighborhoodCandidates(1),a.NeighborhoodCandidates(2), ...
                a.NeighborhoodCandidates(3),a.NeighborhoodCandidates(4), ...
                a.NeighborhoodAccepted(3),a.NeighborhoodAccepted(4)};
        end
        v=costs(q,:); paired=NaN(1,o.Runs); win=NaN;
        if q>1
            paired=100*(costs(q-1,:)-v)./costs(q-1,:); win=mean(v<costs(q-1,:)-1e-10*max(1,costs(q-1,:)));
        end
        sr=sr+1; summary(sr,:)={o.NList(j),labels{q},profiles{q},o.Runs,min(v),mean(v),median(v),std(v),max(v), ...
            100*std(v)/mean(v),mean(paired,'omitnan'),median(paired,'omitnan'),win, ...
            sum(cellfun(@(a) a.NeighborhoodAccepted(3),Ablation.Records(q,j,:))), ...
            sum(cellfun(@(a) a.NeighborhoodAccepted(4),Ablation.Records(q,j,:)))};
    end
end
Ablation.RawTable=cell2table(raw,'VariableNames',{'N','Run','Seed','Label','Profile','TotalCost', ...
    'OrderingCost','DeliveryCost','WarehouseHoldingCost','RetailHoldingCost','PenaltyCost', ...
    'KClassCount','DifferentKEdgeRate','PenaltyCoefficientAttenuation','StartsCompleted', ...
    'Perturbations','LocalSearchesCompleted','RuntimeSeconds','CoordinateCandidates','SwapCandidates', ...
    'UninformedBlockCandidates','ConflictBlockCandidates','UninformedBlockAccepted','ConflictBlockAccepted'});
Ablation.SummaryTable=cell2table(summary,'VariableNames',{'N','Label','Profile','Runs','BestTC','MeanTC', ...
    'MedianTC','StdTC','WorstTC','CV_Percent','MeanPairedImprovementPercent', ...
    'MedianPairedImprovementPercent','PairedWinRate','UninformedBlockAccepted','ConflictBlockAccepted'});
Ablation.Status='complete'; Ablation.CompletedAt=datestr(now,30);
JRDAtomicSave(fullfile(out,'ablation.mat'),Ablation);
writetable(Ablation.RawTable,fullfile(out,'raw_results.csv'));
writetable(Ablation.SummaryTable,fullfile(out,'summary.csv'));
fprintf('Indirect block-K ablation complete: %s\n',out);
end
