# 源码与结果地图

此页用于直接点开代码和数据；不替代VND详细审阅说明。

## 实验2：Direct性能调用链

```text
Run_Paper_Experiment2_DirectPerformance
  ├─ GeneratePaperBenchmarkInstance：独立instance与data seed
  ├─ PaperExperiment2AlgorithmSeed：稳定algorithm seed
  ├─ EvolutionaryX_Direct：canonical X、交叉、变异、选择
  └─ RunCommonDirectBaseline
       ├─ GA / JADE：连续标签partition适配器
       └─ VND：内部descend → BestNeighbor_Direct
            → CommonGridVNDCostCache → DirectGridGroupKernel
所有算法 → EvaluateDirectGridPartition → DirectGridPartitionCost
          → DirectGridCostCache → DirectGridGroupKernel
输出 → raw MAT → study MAT / raw CSV / summary / common convergence
```

| 职责 | 打开文件 |
|---|---|
| 实验入口、任务调度与保存 | [Run_Paper_Experiment2_DirectPerformance](../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m) |
| Evolutionary-X主算法 | [EvolutionaryX_Direct](../Evolutionary_Direct/EvolutionaryX_Direct.m) |
| 交叉与变异 | [CrossoverDirectPartition](../Evolutionary_Direct/CrossoverDirectPartition.m)、[MutateDirectPartition](../Evolutionary_Direct/MutateDirectPartition.m) |
| GA/JADE/VND当前适配器 | [RunCommonDirectBaseline](../Paper_Experiments/RunCommonDirectBaseline.m) |
| 四类结构邻域 | [BestNeighbor_Direct](../Direct_V1/BestNeighbor_Direct.m) |
| 分组标准化、增量组成本 | [DirectState](../Direct_V1/DirectState.m)、[CommonGridVNDCostCache](../Paper_Experiments/CommonGridVNDCostCache.m) |
| 扰动、多起点初始化 | [PerturbPartition](../Direct_V1/PerturbPartition.m)、[Init_Greedy](../Direct_V1/Init_Greedy.m) |
| 公共目标与组内T/f | [DirectGridPartitionCost](../Evolutionary_Direct/DirectGridPartitionCost.m)、[DirectGridGroupKernel](../Evolutionary_Direct/DirectGridGroupKernel.m) |
| 实例与seed | [GeneratePaperBenchmarkInstance](../Paper_Experiments/GeneratePaperBenchmarkInstance.m)、[PaperExperiment2AlgorithmSeed](../Paper_Experiments/PaperExperiment2AlgorithmSeed.m) |
| 图与收敛 | [Plot_Paper_Experiment2](../Paper_Experiments/Plot_Paper_Experiment2.m) |
| 完整结果 | [Exp2结果索引](../Results/Exp2_DirectPerformance/README.md) |

注意：历史[MS_VND_Direct](../Direct_V1/MS_VND_Direct.m)与[VND_Direct](../Direct_V1/VND_Direct.m)是辅助连续T基线，不是本批正式网格VND入口。当前GA/JADE不用已归档的根目录旧GA_Direct/JADE_Direct。

## 实验4：配送协同调用链

```text
Run_Paper_Experiment4_Coordination
  → RunPaperStrategyCase
    ├─ Direct → EvolutionaryX_Direct（正常f边界 / FixedF=1）
    └─ Indirect → RunTeacherAHDE → 同一AHDE
                 （正常F边界 / FInf=FSup=1）
                 → Fitness_Indirect
  → JRDAnalyzeSolution：五项成本与完整解诊断
  → PaperCoordinationSanity：coordinated是否比fixed更差
  → raw MAT / solution_items CSV / paired_savings / anomalies
```

入口：[实验4runner](../Paper_Experiments/Run_Paper_Experiment4_Coordination.m)；两侧分派：[RunPaperStrategyCase](../Paper_Experiments/RunPaperStrategyCase.m)；原AHDE：[AHDE.m](../AHDE.m)；包装：[RunTeacherAHDE](../Paper_Experiments/RunTeacherAHDE.m)；Indirect成本：[Fitness_Indirect](../Fitness_Indirect.m)；可行域sanity：[PaperCoordinationSanity](../Paper_Experiments/PaperCoordinationSanity.m)；[实验4结果索引](../Results/Exp4_Coordination/README.md)。

## 数据列怎样读

- TC / TotalCost / CommonGridTC：相应口径下总成本；CommonGridTC才是Exp2正式比较值。
- NativeContinuousTC：同一最终partition在连续T下的辅助成本，不能与网格目标混比较。
- OrderingCost、DeliveryCost、WarehouseHoldingCost、RetailHoldingCost、PenaltyCost：五项分解，其和应为TC。
- InstanceSeed：输入实例生成；AlgorithmSeed/Seed：算法随机性；两者不是一个东西。
- GapPercent：同一instance相对本批reference best的百分比差距，不是global optimality gap。
- RuntimeSeconds：求解及相应重算/验证的实测记录；SearchSeconds等细列见Exp2原始CSV。
- CommonBestTC：统一口径的checkpoint best成本；Checkpoint序号不能误读为四算法相同工作量。
- SavingPercent：Exp4为100×(fixed−coordinated)/fixed；Exp3策略节省参见原CSV与协议。
- HeuristicAnomaly：coordinated可行域包含fixed但求解值反而更高，只能标记搜索不足。

CSV用于数字展示；raw/*.mat与study.mat保留完整solution、配置、seed、checkpoint和source manifest。MATLAB可用`whos('-file',path)`先查看变量名，再load；不要假定所有MAT都使用同一个变量名。
