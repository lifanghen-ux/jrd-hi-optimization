function report=Test_Paper_Revision(outputRoot)
%TEST_PAPER_REVISION Mathematical and reproducibility gates for new mainline.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); Setup_JRD(); wall=tic;
loaded=load(fullfile(root,'Data_N10.mat'),'data'); d=NormalizeJRDData(loaded.data);
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); %#ok<NASGU>
groups={[1 2 3],[2 5 7 9],1:10}; maxGridError=0;
for q=1:numel(groups)
    projected=EvaluateDirectGridPartition(makePartition(groups{q},d.N),d,'GridStep',0.01,'GridMethod','projection');
    enumerated=EvaluateDirectGridPartition(makePartition(groups{q},d.N),d,'GridStep',0.01,'GridMethod','enumerate');
    maxGridError=max(maxGridError,abs(projected.TotalCost-enumerated.TotalCost));
end
assert(maxGridError<1e-9,'JRD:GridMismatch','Projection must equal literal grid enumeration.');
partition=PartitionCost(ones(1,d.N),d).GroupId;
coarse=EvaluateDirectGridPartition(partition,d,'GridStep',0.01);
medium=EvaluateDirectGridPartition(partition,d,'GridStep',0.005);
fine=EvaluateDirectGridPartition(partition,d,'GridStep',0.001);
continuous=PartitionCost(partition,d);
assert(coarse.TotalCost+1e-9>=medium.TotalCost&&medium.TotalCost+1e-9>=fine.TotalCost&& ...
    fine.TotalCost+1e-9>=continuous.TotalCost,'JRD:GridConvergence','Nested grids did not converge from above.');
exactContinuous=ExactDP_Direct(d); exactGrid=ExactDP_DirectGrid(d,'GridStep',0.01);
assert(exactGrid.TotalCost>=exactContinuous.TotalCost-1e-8&& ...
    (exactGrid.TotalCost-exactContinuous.TotalCost)/exactContinuous.TotalCost<1e-3);
args={'Seed',818,'PopulationSize',10,'Generations',3,'GridStep',0.01,'IntensifyTrials',1};
first=EvolutionaryX_Direct(d,args{:}); second=EvolutionaryX_Direct(d,args{:});
assert(first.TotalCost==second.TotalCost&&isequal(first.GroupId,second.GroupId)&& ...
    isequal(rng,oldRng)&&~isfield(first,'K'),'JRD:Reproducibility','Direct replay failed.');
assert(abs(first.TotalCost-sum([first.OrderingCost,first.DeliveryCost, ...
    first.WarehouseHoldingCost,first.RetailHoldingCost,first.PenaltyCost]))<1e-8);
ahde=RunTeacherAHDE(d,'Seed',919,'PopulationSize',8,'Generations',2);
ahdeReplay=RunTeacherAHDE(d,'Seed',919,'PopulationSize',8,'Generations',2);
fixed=RunTeacherAHDE(d,'Seed',919,'PopulationSize',8,'Generations',2,'FixedF',1);
assert(ahde.TotalCost==ahdeReplay.TotalCost&&isequal(ahde.K,ahdeReplay.K)&&all(fixed.F==1));
assert(abs(Fitness_Indirect(ahde.T,ahde.K,ahde.F,d)-ahde.TotalCost)<1e-8&& ...
    abs(Fitness_Indirect(fixed.T,fixed.K,fixed.F,d)-fixed.TotalCost)<1e-8);
report=struct('Status','PASS','MaxGridEnumerationError',maxGridError, ...
    'ExactContinuousTC',exactContinuous.TotalCost,'ExactGridTC',exactGrid.TotalCost, ...
    'EvolutionarySmokeTC',first.TotalCost,'AHDETeacherSmokeTC',ahde.TotalCost, ...
    'AHDEFixedF1SmokeTC',fixed.TotalCost,'RuntimeSeconds',toc(wall), ...
    'MATLABVersion',version,'CompletedAt',datestr(now,30));
if nargin<1, outputRoot=fullfile(root,'Validation_Paper'); end
out=outputRoot; if ~isfolder(out), mkdir(out); end
save(fullfile(out,'paper_revision.mat'),'report','-v7'); disp(report);
    function ids=makePartition(group,n)
        remaining=setdiff(1:n,group); ids=zeros(1,n); ids(group)=1;
        for z=1:numel(remaining), ids(remaining(z))=z+1; end
        ids=CanonicalizePartition(ids);
    end
end
