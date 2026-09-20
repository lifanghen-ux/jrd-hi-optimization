function [Study,out]=Run_Paper_Experiment4_Coordination(varargin)
%RUN_PAPER_EXPERIMENT4_COORDINATION Quantify optimized f/F versus fixed one.
root=Setup_JRD(); p=inputParser;
integer=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1;
addParameter(p,'NList',[10 30 50 100],@(x) isnumeric(x)&&isvector(x)&&all(ismember(x,[10 30 50 100])));
addParameter(p,'Runs',30,integer); addParameter(p,'BaseSeed',20260919,integer);
addParameter(p,'Generations',500,integer); addParameter(p,'PopulationFactor',4,integer);
addParameter(p,'MinimumPopulation',40,@(x) integer(x)&&x>=4);
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'OutputRoot','',@(x) ischar(x)||isstring(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x)); parse(p,varargin{:}); o=p.Results;
cases={'Direct_Coordinated','Direct_F1','Indirect_Coordinated','Indirect_F1'};
config=rmfield(o,{'OutputRoot','ResumeDir'}); manifest=JRDProjectManifest(root);
if isempty(o.ResumeDir)
    out=CreatePaperOutput(root,'Experiment4_Coordination',char(o.OutputRoot));
    Study=struct('SchemaVersion',1,'Experiment','coordination value: optimized f/F versus one', ...
        'Status','running','Config',config,'Cases',{cases},'Manifest',manifest, ...
        'Source',PaperSourceSnapshot(root),'StartedAt',datestr(now,30), ...
        'Design',['Each case re-optimizes its outer decision because fixing frequency changes the best X or K. ' ...
        'Paired seeds and equal population/generation levels control randomness and outer search scale.']);
    Study.Inputs=cell(numel(o.NList),1); Study.Records=cell(numel(o.NList),o.Runs,4); Study.RawRows={}; Study.PairedRows={};
else
    out=char(o.ResumeDir); loaded=load(fullfile(out,'study.mat'),'Study'); Study=loaded.Study;
    assert(isequaln(Study.Config,config)&&isequal(Study.Manifest,manifest), ...
        'JRD:StaleCheckpoint','Resume configuration, source, or fixed data changed.');
end
rows=Study.RawRows; paired=Study.PairedRows; Study.Status='running';
SavePaperStudy(fullfile(out,'study.mat'),Study);
for ni=1:numel(o.NList)
    input=load(fullfile(root,sprintf('Data_N%d.mat',o.NList(ni))),'data'); d=input.data; Study.Inputs{ni}=d;
    population=max(o.MinimumPopulation,o.PopulationFactor*d.N);
    for r=1:o.Runs
        if all(~cellfun(@isempty,Study.Records(ni,r,:))), continue; end
        seed=mod(o.BaseSeed+1000003*d.N+r-1,2^32); answers=cell(1,4);
        answers{1}=EvolutionaryX_Direct(d,'Seed',seed,'PopulationSize',population,'Generations',o.Generations,'GridStep',o.GridStep);
        answers{2}=EvolutionaryX_Direct(d,'Seed',seed,'PopulationSize',population,'Generations',o.Generations,'GridStep',o.GridStep,'FixedF',1);
        answers{3}=RunTeacherAHDE(d,'Seed',seed,'PopulationSize',population,'Generations',o.Generations);
        answers{4}=RunTeacherAHDE(d,'Seed',seed,'PopulationSize',population,'Generations',o.Generations,'FixedF',1);
        for c=1:4
            Study.Records{ni,r,c}=answers{c}; a=answers{c};
            rows(end+1,:)={d.N,cases{c},r,seed,a.TotalCost,a.RuntimeSeconds,population,o.Generations}; %#ok<AGROW>
            record=struct('N',d.N,'Case',cases{c},'Run',r,'Seed',seed,'Answer',a); %#ok<NASGU>
            save(fullfile(out,'raw',sprintf('N%d_%s_run%03d.mat',d.N,cases{c},r)),'record','-v7');
        end
        paired(end+1,:)={d.N,r,seed,answers{1}.TotalCost,answers{2}.TotalCost, ...
            100*(answers{2}.TotalCost-answers{1}.TotalCost)/answers{2}.TotalCost, ...
            answers{3}.TotalCost,answers{4}.TotalCost, ...
            100*(answers{4}.TotalCost-answers{3}.TotalCost)/answers{4}.TotalCost}; %#ok<AGROW>
        Study.RawRows=rows; Study.PairedRows=paired;
        SavePaperStudy(fullfile(out,'study.mat'),Study);
        fprintf('Experiment4 N=%d run=%d Direct-saving=%.4f%% Indirect-saving=%.4f%%\n',d.N,r, ...
            100*(answers{2}.TotalCost-answers{1}.TotalCost)/answers{2}.TotalCost, ...
            100*(answers{4}.TotalCost-answers{3}.TotalCost)/answers{4}.TotalCost);
    end
end
Study.RawTable=cell2table(rows,'VariableNames',{'N','Case','Run','Seed','TotalCost','RuntimeSeconds','PopulationSize','Generations'});
Study.PairedSavings=cell2table(paired,'VariableNames',{'N','Run','Seed','DirectCoordinatedTC', ...
    'DirectF1TC','DirectCoordinationSavingPercent','IndirectCoordinatedTC','IndirectF1TC', ...
    'IndirectCoordinationSavingPercent'});
comparison={};
for n=unique(Study.RawTable.N)'
    values=cell(1,4);
    for c=1:4, values{c}=Study.RawTable.TotalCost(Study.RawTable.N==n&strcmp(Study.RawTable.Case,cases{c})); end
    comparison(end+1,:)={n,min(values{1}),min(values{2}),100*(min(values{2})-min(values{1}))/min(values{2}), ...
        min(values{3}),min(values{4}),100*(min(values{4})-min(values{3}))/min(values{4})}; %#ok<AGROW>
end
Study.Comparison=cell2table(comparison,'VariableNames',{'N','DirectCoordinatedBestTC','DirectF1BestTC', ...
    'DirectCoordinationSavingPercent','IndirectCoordinatedBestTC','IndirectF1BestTC','IndirectCoordinationSavingPercent'});
Study.Status='complete'; Study.CompletedAt=datestr(now,30);
writetable(Study.RawTable,fullfile(out,'raw_results.csv')); writetable(Study.PairedSavings,fullfile(out,'paired_savings.csv'));
writetable(Study.Comparison,fullfile(out,'comparison.csv'));
SavePaperStudy(fullfile(out,'study.mat'),Study);
end
