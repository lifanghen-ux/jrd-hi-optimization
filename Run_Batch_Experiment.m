function [Results, resultDir] = Run_Batch_Experiment(varargin)
% Reproducible wrapper around the unchanged legacy search algorithms.
% Example smoke test:
% Run_Batch_Experiment('NList',10,'Gm',3,'NpFactor',1,'Plot',false);
% This runner uses generation/population budgets, NOT equal wall-clock or
% equal objective-evaluation budgets. Runtime includes only the solver call.
ip = inputParser;
positiveInteger = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && x == fix(x);
addParameter(ip, 'NList', [10 30 50 100], ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x) && all(ismember(x,[10 30 50 100])) && numel(unique(x)) == numel(x));
addParameter(ip, 'Gm', 1000, positiveInteger);
addParameter(ip, 'NpFactor', 20, positiveInteger);
addParameter(ip, 'Runs', 1, positiveInteger);
addParameter(ip, 'BaseSeed', 20260908, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0 && x == fix(x) && x <= 2^32-1);
addParameter(ip, 'OutputRoot', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(ip, 'Plot', true, @(x) islogical(x) && isscalar(x));
parse(ip, varargin{:});
config = ip.Results;
projectDir = fileparts(mfilename('fullpath'));
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath)); %#ok<NASGU>
originalRng = rng;
rngCleanup = onCleanup(@() rng(originalRng)); %#ok<NASGU>
addpath(projectDir, '-begin');
if isempty(config.OutputRoot)
    config.OutputRoot = fullfile(projectDir, 'Results_Fixed');
end
if ~isfolder(config.OutputRoot), mkdir(config.OutputRoot); end
% A new directory for every invocation, including repeated runs with a seed.
resultDir = tempname(config.OutputRoot);
mkdir(resultDir);
mkdir(fullfile(resultDir,'raw'));

names = {'ADE','AHDE','GA','DE','JADE'};
scales = config.NList(:)';
na = numel(names); ns = numel(scales); nr = config.Runs;
Results = struct('SchemaVersion',2,'Status','running','Config',config, ...
    'N_list',scales,'alg_names',{names},'StartedAt',datestr(now,30), ...
    'MATLABVersion',version,'MATLABRelease',version('-release'), ...
    'ResultDir',resultDir,'BudgetMode','generations_and_population', ...
    'SavingDefinition','100 * (TC_Indirect - TC_Direct) / TC_Indirect');
Results.TC_Indirect = nan(na,ns,nr);
Results.TC_Direct = nan(na,ns,nr);
Results.Runtime_Indirect = nan(na,ns,nr);
Results.Runtime_Direct = nan(na,ns,nr);
Results.Seed = nan(na,ns,nr);
Results.Solutions_Indirect = cell(na,ns,nr);
Results.Solutions_Direct = cell(na,ns,nr);
Results.Inputs = cell(1,ns);
Results.InputPaths = cell(1,ns);
% Preserve exact input values and source text used by this run.
sourceNames = [strcat(names,'.m'),strcat(names,'_Direct.m'), ...
    {'Run_Batch_Experiment.m','Describe_Legacy_Solution.m','Main_Batch_Experiment.m'}];
Results.Source = struct;
for k = 1:numel(sourceNames)
    sourcePath = fullfile(projectDir,sourceNames{k});
    [~,key] = fileparts(sourcePath);
    Results.Source.(key) = fileread(sourcePath);
end
for j = 1:ns
    filename = fullfile(projectDir,sprintf('Data_N%d.mat',scales(j)));
    loaded = load(filename,'data');
    d = loaded.data;
    required = {'N','S','D','sw','sr','hw','hr','p'};
    assert(all(isfield(d,required)), 'JRD:MissingData', 'Missing data fields.');
    assert(d.N == scales(j) && isequal(size(d.p),[d.N,d.N]), ...
        'JRD:DataShape','Dataset size does not match N.');
    for field = {'D','sw','sr','hw','hr'}
        v = d.(field{1});
        assert(numel(v)==d.N && all(isfinite(v(:))) && all(v(:)>0), ...
            'JRD:DataValues','Invalid data vector.');
    end
    assert(isscalar(d.S) && isfinite(d.S) && d.S>0 && all(isfinite(d.p(:))), ...
        'JRD:DataValues','Invalid setup cost or penalty.');
    Results.Inputs{j} = d;
    Results.InputPaths{j} = filename;
end
Results.KInf = 1; Results.KSup = 20;
Results.FInf = 1; Results.FSup = 20;
save(fullfile(resultDir,'results.mat'),'Results','-v7');

try
    for j = 1:ns
        d = Results.Inputs{j};
        n = d.N; np = config.NpFactor*n;
        for a = 1:na
            for r = 1:nr
                seed = mod(config.BaseSeed + 100000*n + 1000*a + r-1,2^32);
                Results.Seed(a,j,r) = seed;
                for strategy = {'Indirect','Direct'}
                    kind = strategy{1};
                    algorithm = names{a};
                    if strcmp(kind,'Direct'), algorithm = [algorithm '_Direct']; end
                    solver = str2func(algorithm);
                    % Check path resolution to avoid running an unrelated GA/DE.
                    assert(strcmpi(which(algorithm),fullfile(projectDir,[algorithm '.m'])), ...
                        'JRD:ShadowedAlgorithm','Unexpected algorithm on MATLAB path.');
                    rng(seed,'twister');
                    rngBefore = rng;
                    timer = tic;
                    [tc,t,k,f,curve] = solver(config.Gm,np,20,1,20,1, ...
                        d.sw(:),d.D(:),d.sr(:),d.hw(:),d.hr(:),d.S,d.p,n);
                    runtime = toc(timer);
                    rngAfter = rng;
                    solution = Describe_Legacy_Solution(kind,k,f,t,d);
                    assert(isscalar(tc) && isfinite(tc) && tc>0 && ...
                        abs(solution.RecomputedTC-tc) <= 1e-10*max(1,abs(tc)), ...
                        'JRD:CostMismatch','Returned cost does not match the stored solution.');
                    assert(numel(curve)==config.Gm && all(isfinite(curve(:))) && ...
                        abs(min(curve)-tc)<=1e-10*max(1,abs(tc)), ...
                        'JRD:InvalidCurve','Invalid convergence curve.');
                    record = struct('Algorithm',algorithm,'Strategy',kind,'N',n, ...
                        'Run',r,'Seed',seed,'BestTC',tc,'RuntimeSeconds',runtime, ...
                        'Gm',config.Gm,'Np',np,'Solution',solution, ...
                        'ConvergenceTC',curve(:)','RngBefore',rngBefore, ...
                        'RngAfter',rngAfter,'CompletedAt',datestr(now,30));
                    Results.(['TC_' kind])(a,j,r) = tc;
                    Results.(['Runtime_' kind])(a,j,r) = runtime;
                    Results.(['Solutions_' kind]){a,j,r} = record;
                    rawPath = fullfile(resultDir,'raw', ...
                        sprintf('N%d_%s_run%03d.mat',n,algorithm,r));
                    save(rawPath,'record','-v7');
                    % Checkpoint completed jobs; NaN marks jobs not yet run.
                    save(fullfile(resultDir,'results.mat'),'Results','-v7');
                    fprintf('N=%d %s run=%d seed=%u TC=%.10f time=%.3fs\n', ...
                        n,algorithm,r,seed,tc,runtime);
                end
            end
        end
    end
    Results.Saving_Percent = 100*(Results.TC_Indirect-Results.TC_Direct)./Results.TC_Indirect;
    rawRows = cell(na*ns*nr,10);
    summaryRows = cell(2*na*ns,11);
    row = 0; srow = 0;
    for j = 1:ns
        for a = 1:na
            for r = 1:nr
                row = row+1;
                rawRows(row,:) = {scales(j),names{a},r,Results.Seed(a,j,r), ...
                    Results.TC_Indirect(a,j,r),Results.TC_Direct(a,j,r), ...
                    Results.Runtime_Indirect(a,j,r),Results.Runtime_Direct(a,j,r), ...
                    Results.Saving_Percent(a,j,r),config.Gm};
            end
            for strategy = {'Indirect','Direct'}
                kind = strategy{1};
                values = reshape(Results.(['TC_' kind])(a,j,:),[],1);
                times = reshape(Results.(['Runtime_' kind])(a,j,:),[],1);
                sampleStd = NaN;
                if nr>1, sampleStd = std(values,0); end
                srow = srow+1;
                summaryRows(srow,:) = {scales(j),names{a},kind,nr,min(values), ...
                    mean(values),median(values),sampleStd,max(values), ...
                    mean(times),100*sampleStd/mean(values)};
            end
        end
    end
    Results.RawTable = cell2table(rawRows,'VariableNames', ...
        {'N','Algorithm','Run','Seed','TC_Indirect','TC_Direct', ...
        'Runtime_Indirect','Runtime_Direct','Saving_Percent','Gm'});
    Results.SummaryTable = cell2table(summaryRows,'VariableNames', ...
        {'N','Algorithm','Strategy','Runs','BestTC','MeanTC','MedianTC', ...
        'StdTC','WorstTC','MeanRuntimeSeconds','CV_Percent'});
    writetable(Results.RawTable,fullfile(resultDir,'raw_results.csv'));
    writetable(Results.SummaryTable,fullfile(resultDir,'summary.csv'));
    if config.Plot
        fig = figure('Visible','off','Position',[100 100 1100 700]);
        figureCleanup = onCleanup(@() close(fig)); %#ok<NASGU>
        for j = 1:ns
            subplot(ceil(ns/2),min(2,ns),j);
            bar([mean(Results.TC_Indirect(:,j,:),3),mean(Results.TC_Direct(:,j,:),3)]);
            set(gca,'XTick',1:na,'XTickLabel',names);
            title(sprintf('N = %d, mean of %d run(s)',scales(j),nr));
            ylabel('Total cost'); legend('Indirect','Direct','Location','best'); grid on;
        end
        savefig(fig,fullfile(resultDir,'comparison.fig'));
        print(fig,fullfile(resultDir,'comparison.png'),'-dpng','-r150');
    end
    Results.Status = 'complete';
    Results.CompletedAt = datestr(now,30);
    save(fullfile(resultDir,'results.mat'),'Results','-v7');
catch exception
    Results.Status = 'failed';
    Results.ErrorIdentifier = exception.identifier;
    Results.ErrorMessage = exception.message;
    save(fullfile(resultDir,'results.mat'),'Results','-v7');
    rethrow(exception);
end
end
