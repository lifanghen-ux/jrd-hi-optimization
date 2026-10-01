# JRD-HI：老师审阅版（2026-10-01）

本公开仓库默认展示**当前可运行主线 + 已完成实验证据**。本次整理不修改成本模型、原始数据、Direct 的 S/penalty 定义或老师 AHDE 的搜索机制。

## 先看这三处

1. **[VND 四类邻域、例子、停止条件与真实调用链](Docs/VND_NEIGHBORHOODS_TEACHER_REVIEW.md)**。
2. **[实验2：Direct 算法性能结果（108 次）](Results/Exp2_DirectPerformance/README.md)**。
3. **[实验4：配送协同价值结果（16 次）](Results/Exp4_Coordination/README.md)**。

### 实验2：Direct 算法性能

N=30/50/100；每规模3个独立实例，每实例3个算法seed；Evolutionary-X、GA、JADE、VND，共108次。G=100，进化种群P=4N，GridStep=0.001。

所有最终值采用 CommonGridTC，所有收敛轨迹采用 CommonBestTC，同一网格组成本核心；连续 native 值另存，不混作正式指标。这里的 GA/JADE 是 partition adapters，不是旧 2N 代码原样运行。VND预算按未缓存组内核评价计数，不能称四算法严格等算力。

| N | Evo 平均TC | VND 平均TC | Evo Average Gap % | VND Average Gap % |
|---|---:|---:|---:|---:|
| 30 | 43,393.20 | 42,787.79 | 1.454 | 0.032 |
| 50 | 80,128.60 | 75,616.60 | 6.117 | 0.164 |
| 100 | 190,488.74 | 171,152.73 | 12.048 | 0.698 |

**本批27对Evo/VND配对中，VND赢26对、并列1对。不能报告“Evo已优于VND”，也不能把本批reference best称为全局最优。** Average Gap参照同一实例全部算法/seed最低CommonGridTC。

入口：[Run_Paper_Experiment2_DirectPerformance](Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m)；核心：[EvolutionaryX_Direct](Evolutionary_Direct/EvolutionaryX_Direct.m)、[RunCommonDirectBaseline](Paper_Experiments/RunCommonDirectBaseline.m)、[BestNeighbor_Direct](Direct_V1/BestNeighbor_Direct.m)。

### 实验4：配送协同价值

N=10/30/50/100；原始固定实例，每规模1seed；Direct coordinated / f=1、Indirect coordinated / F=1，共16次。G=500，P=10N，Direct GridStep=0.001。四种情形分别重新优化外层变量。

Indirect两情形均调用[老师原AHDE](AHDE.m)，fixed仅令FInf=FSup=1；Direct两情形使用同一Evolutionary-X，仅改变频率可行域。

| N | Direct 协同节省 % | Indirect 协同节省 % |
|---|---:|---:|
| 10 | 3.005 | 4.362 |
| 30 | 4.641 | 6.437 |
| 50 | 5.557 | 7.021 |
| 100 | 6.195 | 6.924 |

全部fixed解频率严格为1；本批无coordinated TC > fixed TC异常。**仅1seed，是初步趋势，不是稳定性或全局最优证明。**

入口：[Run_Paper_Experiment4_Coordination](Paper_Experiments/Run_Paper_Experiment4_Coordination.m)；AHDE边界包装：[RunTeacherAHDE](Paper_Experiments/RunTeacherAHDE.m)。

## 其他已完成证据

- [实验1：N10冻结精确网格证书与5seeds](Results/Exp1_N10/README.md)：5/5命中TC=12059.2627236542。
- [实验3：Direct/原AHDE策略比较40次](Results/Exp3_StrategyComparison/README.md)：G100/P4N，属于preliminary，不证明策略全局支配。
- [实测profiling](Results/Profiling/README.md)：G500/P10N的7次真实wall-clock记录。
- [源码与数据调用地图](Docs/CODE_AND_RESULTS_MAP.md)；[清理与恢复清单](Docs/CLEANUP_MANIFEST_2026-10-01.md)。

## 打开与运行

MATLAB R2024a中将当前目录设为本仓库根目录，先运行：

```matlab
Setup_JRD;
Test_Paper_Revision(fullfile(pwd,'Validation_Delivery','Revision'));
Test_Preliminary_Readiness('OutputRoot',fullfile(pwd,'Validation_Delivery','Readiness'));
```

如需新的试运行，请使用新的OutputRoot，勿覆盖Results中的已完成证据：

```matlab
help Run_Paper_Experiment2_DirectPerformance
help Run_Paper_Experiment4_Coordination
```

runner的inputParser列出完整参数与默认预算。不要不看配置就直接启动默认长跑。

## 历史保存与resume

精简版移除了当前展示不依赖的旧算法、旧入口、重复审计文档和完整legacy测试；这些是**历史研究内容，不等于数学无效**。67个移除路径、恢复引用及未采用数据见[清理清单](Docs/CLEANUP_MANIFEST_2026-10-01.md)。完整研究分支与清理前tag仍保留；本机原研究目录和历史结果没有删除。

Results中的CSV/MAT/实例/图按原文件复制，未重写历史study或manifest。**源码精简使source manifest改变，旧完成批次只读审阅；若要继续旧批次，应切回原完整源码快照。** 新源码的新实验写到新目录，源一致性检查继续有效，不关闭StaleCheckpoint检查。
