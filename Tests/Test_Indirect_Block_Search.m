function report=Test_Indirect_Block_Search()
root=Setup_JRD(); original=rng; cleanup=onCleanup(@() rng(original)); %#ok<NASGU>
% A pair-move trap: every single K change from ones is worse, while changing
% items 2 and 4 together is better. F is fixed to isolate the K mechanism.
d=struct('N',4,'D',100*ones(1,4),'sw',10*ones(1,4), ...
    'sr',10*ones(1,4),'hw',ones(1,4),'hr',ones(1,4), ...
    'S',100,'p',zeros(4),'KInf',1,'KSup',3,'FInf',1,'FSup',1);
d.p(1,2)=200; d.p(3,4)=200; d=NormalizeJRDData(d);
base=IndirectInnerExact(ones(4,1),d);
budget1=SearchBudget(Inf,Inf,'test_coordinate'); cache1=IndirectCostCache(d,budget1,1000);
o1=JRDSearchOptions('MaxSeconds',Inf,'IndirectNeighborhoodProfile','coordinate');
[single,info1]=VND_Indirect(base,cache1,o1);
budget2=SearchBudget(Inf,Inf,'test_block'); cache2=IndirectCostCache(d,budget2,1000);
o2=JRDSearchOptions('MaxSeconds',Inf,'IndirectNeighborhoodProfile','coordinate_swap_block', ...
    'BlockValuesPerItem',2,'BlockPartnersPerItem',2);
[block,info2]=VND_Indirect(base,cache2,o2);
assert(abs(single.TotalCost-base.TotalCost)<1e-10);
assert(block.TotalCost<single.TotalCost-1e-8&&info2.NeighborhoodAccepted(3)>0);
assert(info1.ExhaustedConfiguredNeighborhoods&&info2.ExhaustedConfiguredNeighborhoods);
% Multi-seed pipeline smoke test. This is a software test, not evidence.
folder=tempname; mkdir(folder);
[a,out]=Run_Indirect_Block_Ablation('NList',10,'Runs',3,'Starts',2, ...
    'ILSIterations',1,'BlockValuesPerItem',2,'BlockPartnersPerItem',1, ...
    'BlockConflictPairLimit',4,'OutputRoot',folder);
assert(strcmp(a.Status,'complete')&&height(a.RawTable)==12&&height(a.SummaryTable)==4);
assert(numel(unique(a.RawTable.Seed))==3&&all(a.RawTable.StartsCompleted==2));
[replayed,~]=Run_Indirect_Block_Ablation('NList',10,'Runs',3,'Starts',2, ...
    'ILSIterations',1,'BlockValuesPerItem',2,'BlockPartnersPerItem',1, ...
    'BlockConflictPairLimit',4,'ResumeDir',out);
assert(isequaln(a.RawTable,replayed.RawTable));
report=struct('Status','PASS','PairTrapCoordinateCost',single.TotalCost, ...
    'PairTrapBlockCost',block.TotalCost,'BlockAccepted',info2.NeighborhoodAccepted(3), ...
    'AblationSeeds',3,'AblationRows',height(a.RawTable),'FormalExperimentRun',false);
disp(report);
end
