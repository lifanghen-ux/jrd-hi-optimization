function report = Test_Storage_Fix()
% Integration checks for the new result pipeline using tiny N=10 budgets.
projectDir = fileparts(mfilename('fullpath'));
testRoot = tempname(fullfile(projectDir,'Results_Fixed'));
if ~isfolder(fullfile(projectDir,'Results_Fixed'))
    mkdir(fullfile(projectDir,'Results_Fixed'));
end
mkdir(testRoot);
beforeInputs = cell(1,4);
scales = [10 30 50 100];
for j=1:4
    beforeInputs{j} = load(fullfile(projectDir,sprintf('Data_N%d.mat',scales(j))));
end
rngState = rng;
args = {'NList',10,'Gm',3,'NpFactor',1,'Runs',2, ...
    'BaseSeed',4242,'OutputRoot',testRoot};
[first,firstDir] = Run_Batch_Experiment(args{:},'Plot',true);
assert(isequal(rng,rngState),'Caller RNG was changed.');
[second,secondDir] = Run_Batch_Experiment(args{:},'Plot',false);
assert(~strcmp(firstDir,secondDir),'Repeated invocation overwrote a run.');
assert(isequal(first.TC_Indirect,second.TC_Indirect) && ...
    isequal(first.TC_Direct,second.TC_Direct),'Seed replay was not reproducible.');
loaded = load(fullfile(firstDir,'results.mat'),'Results');
assert(strcmp(loaded.Results.Status,'complete'));
assert(isequal(loaded.Results.TC_Direct,first.TC_Direct));
assert(all(first.TC_Indirect(:)>0) && all(first.TC_Direct(:)>0));
raw = readtable(fullfile(firstDir,'raw_results.csv'));
assert(height(raw)==10 && all(abs(raw.Saving_Percent - ...
    100*(raw.TC_Indirect-raw.TC_Direct)./raw.TC_Indirect)<1e-9));
assert(isfile(fullfile(firstDir,'comparison.png')) && ...
    isfile(fullfile(firstDir,'comparison.fig')));
files = dir(fullfile(firstDir,'raw','*.mat'));
assert(numel(files)==20);
for j=1:numel(files)
    job = load(fullfile(files(j).folder,files(j).name),'record');
    rc = job.record;
    assert(abs(rc.BestTC-rc.Solution.RecomputedTC)<1e-8);
    assert(numel(rc.ConvergenceTC)==3);
    if strcmp(rc.Strategy,'Direct')
        assert(all(rc.Solution.GroupT>0));
        assert(isequal(sort([rc.Solution.Groups{:}]),1:10));
    end
end
% Noncontiguous labels and F-label association must be preserved.
d = beforeInputs{1}.data;
ids = [7 3 3 3 3 3 7 7 3 7]';
freq = ones(10,1); freq(7)=2; freq(3)=3;
one = Describe_Legacy_Solution('Direct',ids,freq,0,d);
ids2 = [1 2 2 2 2 2 1 1 2 1]';
freq2 = ones(10,1); freq2(1)=2; freq2(2)=3;
two = Describe_Legacy_Solution('Direct',ids2,freq2,0,d);
assert(isequal(one.GroupF,[2;3]) && isequal(one.GroupId,ids2));
assert(abs(one.RecomputedTC-two.RecomputedTC)<1e-10);
% Existing datasets must be rejected before a generator can overwrite them.
for generator = {@Generate_Data,@Generate_Large_Data}
    rejected = false;
    try
        generator{1}(projectDir);
    catch exception
        rejected = strcmp(exception.identifier,'JRD:ExistingData');
    end
    assert(rejected,'Generator did not protect existing data.');
end
for j=1:4
    after = load(fullfile(projectDir,sprintf('Data_N%d.mat',scales(j))));
    assert(isequaln(beforeInputs{j},after),'An original dataset was changed.');
end
report = struct('Status','PASS','SolverCalls',40,'N',10, ...
    'Gm',3,'Np',10,'Runs',2,'OutputDir',testRoot, ...
    'FirstRunDir',firstDir,'ReplayRunDir',secondDir, ...
    'MATLABVersion',version,'CompletedAt',datestr(now,30));
save(fullfile(testRoot,'storage_test_report.mat'),'report');
disp(report);
end
