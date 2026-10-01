function [Study,out]=Profile_Paper_Solvers(varargin)
%PROFILE_PAPER_SOLVERS Real single-run timings, NOT formal performance evidence.
% Default jobs implement the requested 500-generation, 10N reference profile.
% No time-based stop, no automatic launch of a formal experiment follows this.
root=Setup_JRD(); p=inputParser;
positiveInt=@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=1&&x==fix(x);
addParameter(p,'Generations',500,positiveInt);
addParameter(p,'PopulationFactor',10,@(x) isnumeric(x)&&isscalar(x)&&x>0&&isfinite(x));
addParameter(p,'GridStep',0.001,@(x) isnumeric(x)&&isscalar(x)&&x>0&&isfinite(x));
addParameter(p,'Seed',20261001,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=1&&x<=2^32-1);
addParameter(p,'OutputRoot',fullfile(root,'Results_Profiling'),@(x) ischar(x)||isstring(x));
addParameter(p,'ResumeDir','',@(x) ischar(x)||isstring(x));
addParameter(p,'VNDStarts',4,@(x) positiveInt(x)&&x>=2);
addParameter(p,'VNDILSIterations',10,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0&&x==fix(x));
parse(p,varargin{:}); config=p.Results;
config=rmfield(config,{'OutputRoot','ResumeDir'});
manifest=JRDProjectManifest(root);
jobs={'EvolutionaryX',30;'EvolutionaryX',50;'EvolutionaryX',100; ...
    'GA',100;'JADE',100;'VND',100;'TeacherAHDE',100};
if strlength(string(p.Results.ResumeDir))>0
    out=char(p.Results.ResumeDir); loaded=load(fullfile(out,'profile.mat'),'Study'); Study=loaded.Study;
    assert(isequal(Study.Config,config)&&isequal(Study.SourceManifest,manifest), ...
        'JRD:StaleCheckpoint','Profile configuration/source changed. Start a new profile.');
else
    if ~isfolder(p.Results.OutputRoot), mkdir(p.Results.OutputRoot); end
    out=tempname(char(p.Results.OutputRoot)); mkdir(out); mkdir(fullfile(out,'raw'));
    Study=struct('Purpose','single-run wall-clock profiling; not formal evidence', ...
        'Config',config,'SourceManifest',manifest,'MATLABVersion',version, ...
        'StartedAt',datestr(now,30),'Records',{{}},'AllJobsCompleted',false);
    saveState();
end
fprintf('PROFILE_OUTPUT=%s\n',out);
for j=1:size(jobs,1)
    if numel(Study.Records)>=j && ~isempty(Study.Records{j}), continue; end
    name=jobs{j,1}; n=jobs{j,2}; population=max(4,round(config.PopulationFactor*n));
    inputPath=fullfile(root,sprintf('Data_N%d.mat',n)); loaded=load(inputPath,'data'); d=loaded.data;
    rawPath=fullfile(out,'raw',sprintf('%02d_%s_N%d.mat',j,name,n));
    if isfile(rawPath)
        recovered=load(rawPath,'Study'); record=recovered.Study;
        assert(strcmp(record.Algorithm,name)&&record.N==n&&record.Population==population&& ...
            record.Generations==config.Generations&&record.Seed==config.Seed&&record.GridStep==config.GridStep&& ...
            strcmp(record.InputSHA256,JRDFileSHA256(inputPath)), ...
            'JRD:StaleRawRecord','Profile raw task/input identity changed.');
        Study.Records{j}=record; saveState(); continue;
    end
    % Small same-implementation warm-up avoids charging MATLAB/JIT startup.
    tiny=d; tiny.N=4;
    for field={'D','sw','sr','hw','hr'}, tiny.(field{1})=tiny.(field{1})(1:4); end
    tiny.p=tiny.p(1:4,1:4);
    solve(name,tiny,4,1);
    fprintf('PROFILE_START job=%d/%d solver=%s N=%d P=%d G=%d %s\n', ...
        j,size(jobs,1),name,n,population,config.Generations,datestr(now,30));
    Study.CurrentJob=struct('Index',j,'Algorithm',name,'N',n,'StartedAt',datestr(now,30)); saveState();
    wall=tic; solution=solve(name,d,population,config.Generations); elapsed=toc(wall);
    parts=[solution.OrderingCost solution.DeliveryCost solution.WarehouseHoldingCost ...
        solution.RetailHoldingCost solution.PenaltyCost];
    assert(abs(sum(parts)-solution.TotalCost)<1e-8*max(1,solution.TotalCost));
    record=struct('Algorithm',name,'N',n,'Population',population,'Generations',config.Generations, ...
        'GridStep',config.GridStep,'Seed',config.Seed,'WallClockSeconds',elapsed, ...
        'SolverReportedSeconds',solution.RuntimeSeconds,'TC',solution.TotalCost, ...
        'Solution',solution,'InputSHA256',JRDFileSHA256(inputPath),'CompletedAt',datestr(now,30));
    if strcmp(name,'VND')
        record.BudgetDescription=sprintf('%d starts, %d ILS/start, %d uncached group-evaluation cap; population/generations not VND operators', ...
            config.VNDStarts,config.VNDILSIterations,population*(config.Generations+1));
    else
        record.BudgetDescription='10N population and 500 generations are reference operators, not equal objective work across different solvers';
    end
    Study.Records{j}=record;
    SavePaperStudy(rawPath,record);
    saveState();
    fprintf('PROFILE_DONE solver=%s N=%d wall=%.6f sec TC=%.12f\n',name,n,elapsed,solution.TotalCost);
end
Study.AllJobsCompleted=true; Study.CompletedAt=datestr(now,30); saveState();
    function solution=solve(name,data,population,generations)
        args={'Seed',config.Seed,'PopulationSize',population,'Generations',generations};
        if strcmp(name,'EvolutionaryX')
            solution=EvolutionaryX_Direct(data,args{:},'GridStep',config.GridStep);
        elseif strcmp(name,'TeacherAHDE')
            solution=RunTeacherAHDE(data,args{:});
        else
            solution=RunCommonDirectBaseline(name,data,args{:},'GridStep',config.GridStep, ...
                'VNDStarts',config.VNDStarts,'VNDILSIterations',config.VNDILSIterations, ...
                'VNDMaxGroupEvaluations',population*(generations+1));
        end
    end
    function saveState()
        SavePaperStudy(fullfile(out,'profile.mat'),Study);
        if isempty(Study.Records), return; end
        valid=Study.Records(~cellfun(@isempty,Study.Records)); rows=cell(numel(valid),10);
        for r=1:numel(valid)
            v=valid{r}; rows(r,:)={v.Algorithm,v.N,v.Population,v.Generations,v.GridStep,v.Seed, ...
                v.WallClockSeconds,v.SolverReportedSeconds,v.TC,v.BudgetDescription};
        end
        writetable(cell2table(rows,'VariableNames',{'Algorithm','N','Population','Generations','GridStep', ...
            'Seed','WallClockSeconds','SolverReportedSeconds','TC','BudgetDescription'}),fullfile(out,'timings.csv'));
    end
end
