function [Results,resultDir]=Run_Optimized_Experiment(varargin)
% New-vs-new paired experiment. Defaults are a short validation, not a study.
root=Setup_JRD();
p=inputParser;
int=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=1&&x==fix(x);
addParameter(p,'Phase','validation',@(x) ismember(x,{'validation','formal'}));
addParameter(p,'NList',10,@(x) isnumeric(x)&&isvector(x)&&~isempty(x)&& ...
    all(ismember(x,[10 30 50 100]))&&numel(unique(x))==numel(x));
addParameter(p,'Runs',2,int);
addParameter(p,'Seconds',2,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'BaseSeed',20260909,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&& ...
    x>=0&&x==fix(x)&&x<=2^32-1);
addParameter(p,'OutputRoot',fullfile(root,'Results_Optimized'),@(x) ischar(x)||isstring(x));
parse(p,varargin{:}); config=p.Results;
manifest=JRDProjectManifest(root);
if strcmp(config.Phase,'formal')
    gatePath=fullfile(root,'Validation_V1','readiness.mat');
    assert(isfile(gatePath),'JRD:NotValidated','Run Test_JRD_All before a formal experiment.');
    gate=load(gatePath,'readiness');
    assert(strcmp(gate.readiness.Status,'PASS')&&isequal(gate.readiness.Manifest,manifest), ...
        'JRD:StaleValidation','Source/data changed after validation. Run Test_JRD_All again.');
    assert(config.Runs>=30,'JRD:TooFewRuns','Formal stability study requires >=30 seeds.');
end
if ~isfolder(config.OutputRoot), mkdir(config.OutputRoot); end
resultDir=tempname(config.OutputRoot); mkdir(resultDir); mkdir(fullfile(resultDir,'raw'));
Results=struct('SchemaVersion',1,'Status','running','Config',config, ...
    'Manifest',manifest,'StartedAt',datestr(now,30),'MATLABVersion',version, ...
    'BudgetMode','equal cooperative search time per strategy', ...
    'SavingDefinition','100*(Indirect-Direct)/Indirect', ...
    'DataScope','one existing instance per N; seed repeats are not instance repeats');
Results.Source=struct('RelativePath',{},'Text',{});
for j=1:numel(manifest)
    if endsWith(manifest(j).RelativePath,'.m')
        Results.Source(end+1)=struct('RelativePath',manifest(j).RelativePath, ...
            'Text',fileread(fullfile(root,manifest(j).RelativePath)));
    end
end
scales=config.NList(:)'; Results.Inputs=cell(1,numel(scales));
for j=1:numel(scales)
    input=load(fullfile(root,sprintf('Data_N%d.mat',scales(j))),'data');
    Results.Inputs{j}=input.data;
end
Results.Records=cell(2,numel(scales),config.Runs);
Results.TC_Indirect=nan(numel(scales),config.Runs);
Results.TC_Direct=nan(numel(scales),config.Runs);
rawRows=cell(numel(scales)*config.Runs,8); row=0;
save(fullfile(resultDir,'results.mat'),'Results','-v7');
try
    for j=1:numel(scales)
        d=Results.Inputs{j};
        for r=1:config.Runs
            % Unique paired seeds over this invocation (unless >2^32 jobs).
            seed=mod(config.BaseSeed+(j-1)*config.Runs+r-1,2^32);
            % Alternate execution order to reduce systematic ordering effects.
            order=1:2; if mod(r,2)==0, order=2:-1:1; end
            for s=order
                if s==1, solver=@MS_VND_Indirect; kind='Indirect';
                else, solver=@MS_VND_Direct; kind='Direct'; end
                answer=solver(d,'Seed',seed,'MaxSeconds',config.Seconds, ...
                    'UseTimeBudgetFully',true);
                record=struct('N',d.N,'Run',r,'Seed',seed,'Strategy',kind,'Answer',answer);
                Results.Records{s,j,r}=record;
                Results.(['TC_' kind])(j,r)=answer.TotalCost;
                save(fullfile(resultDir,'raw',sprintf('N%d_%s_run%03d.mat',d.N,kind,r)), ...
                    'record','-v7');
                save(fullfile(resultDir,'results.mat'),'Results','-v7');
                fprintf('validation=%d N=%d %s run=%d TC=%.10f search=%.3fs\n', ...
                    strcmp(config.Phase,'validation'),d.N,kind,r,answer.TotalCost,answer.SearchSeconds);
            end
            row=row+1; i=Results.Records{1,j,r}.Answer; dAnswer=Results.Records{2,j,r}.Answer;
            rawRows(row,:)={scales(j),r,seed,i.TotalCost,dAnswer.TotalCost, ...
                100*(i.TotalCost-dAnswer.TotalCost)/i.TotalCost,i.RuntimeSeconds,dAnswer.RuntimeSeconds};
        end
    end
    Results.Saving_Percent=100*(Results.TC_Indirect-Results.TC_Direct)./Results.TC_Indirect;
    Results.RawTable=cell2table(rawRows,'VariableNames', ...
        {'N','Run','Seed','TC_Indirect','TC_Direct','Saving_Percent','Runtime_Indirect','Runtime_Direct'});
    summary=cell(2*numel(scales),12); row=0;
    for j=1:numel(scales)
        for s=1:2
            kind='Indirect'; if s==2, kind='Direct'; end
            v=Results.(['TC_' kind])(j,:);
            runtimes=cellfun(@(r) r.Answer.RuntimeSeconds,Results.Records(s,j,:));
            sd=NaN; if config.Runs>1, sd=std(v,0); end
            row=row+1;
            summary(row,:)={scales(j),kind,config.Runs,min(v),mean(v),median(v), ...
                sd,max(v),mean(runtimes),100*sd/mean(v), ...
                mean(Results.Saving_Percent(j,:)),mean(Results.Saving_Percent(j,:)>0)};
        end
    end
    Results.SummaryTable=cell2table(summary,'VariableNames', ...
        {'N','Strategy','Runs','BestTC','MeanTC','MedianTC','StdTC','WorstTC', ...
        'MeanRuntimeSeconds','CV_Percent','MeanPairedSavingPercent','DirectSeedWinRate'});
    writetable(Results.RawTable,fullfile(resultDir,'raw_results.csv'));
    writetable(Results.SummaryTable,fullfile(resultDir,'summary.csv'));
    Results.Status='complete'; Results.CompletedAt=datestr(now,30);
    save(fullfile(resultDir,'results.mat'),'Results','-v7');
catch exception
    Results.Status='failed'; Results.Error=exception.message;
    save(fullfile(resultDir,'results.mat'),'Results','-v7'); rethrow(exception);
end
end
