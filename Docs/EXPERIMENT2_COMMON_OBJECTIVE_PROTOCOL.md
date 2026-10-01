# Experiment 2：公共目标、多实例性能比较口径

修订日期：2026-10-01。本文是开跑前工程决定，不是老师逐字会议纪要。

## 1. 四个比较算法及统一适应度

正式主表比较 Evolutionary-X、GA partition adapter、JADE partition adapter 和 grid-VND。
每个候选分区都使用 `DirectGridPartitionCost` 对同样的 T 网格、同样的整数配送频率范围求最小组成本。搜索过程、最后目标、收敛曲线均为同一个 `CommonGridTC`。

GA/JADE adapter 保留原来的选择、交叉、变异、联合精英选择或成功参数自适应，但将染色体改为 N 个有效连续标签坐标。标签仍用 floor 解码为商品分组并规范化。T/f 由公共 evaluator 优化，因此不再在染色体中保留 N 个无效频率坐标。这是适用于新 Direct 问题的算法适配，不应在论文中写成“原历史 2N 代码原封不动运行”。GA、JADE 不加入 Evolutionary-X 的贪心初始化或组块交叉，这些属于被比较算法的实际设计差别。

grid-VND 复用现有搬移、合并、交换、拆分邻域，替换组缓存为同一网格成本核心。原 `GA_Direct.m`、`JADE_Direct.m`、`MS_VND_Direct.m` 完全保留。`RunLegacyDirectBaseline` 仅为历史 native objective 复现及最终分区公共重评分，不能把其原生收敛曲线加入正式公共目标曲线。

`NativeContinuousTC` 表示对同一个最终分区改用连续 T 后重优化的辅助值，不是另一个正式指标，也不是原历史算法的原生成本。其字段和正式 `CommonGridTC` 分开保存。

## 2. 预算能够控制什么

进化算法使用同一个 population 和 generation 层级。Evolutionary-X 有种群去重、组块交叉和精英强化，GA/JADE 的单次评价成本和搜索工作仍不同，因此不能称为严格等工作量实验。

VND 预先配置 starts、ILS 次数和未缓存组评价上限。默认上限为 `PopulationSize*(Generations+1)`，不再读取 Evolutionary-X 实际效果或计数后动态分配。VND 的计数单位是未缓存组评价，进化算法的外层单位是分区评价，二者也不能称为严格等预算。

必须同时报告 search seconds、postprocess seconds、validation seconds、实际 partition evaluations、group evaluations 和 group requests。`AverageRuntimeSeconds` 包含求解、最终重算及一致性验证；原始 MAT 写入耗时另列 `RawWriteSeconds`，整组 CSV/Study 聚合写入不计入 solver runtime。

`Design='pilot'` 的默认仅是短期调试起点：100 代、种群 4N（至少 40）、3 独立实例、3 算法 seed、SFactor=0.3。

`Design='paper-reference'` 支持 500 代、种群 10N、每个 N/S 场景 20 独立实例、SFactor=[.1 .2 .3 .4 .5]、每实例 1 算法 seed。此配置保留老师 2024 论文的性能证明结构，但最终正式预算仍应先通过实测和 pilot 收敛验证。

默认 N=[30,50,100] 时 reference 配置为 300 个独立实例；若显式设置 N=[10,30,50,100] 则为 400 个。多算法 seed 可独立增加，不能将其误算为新的 benchmark instance。

## 3. 实例生成和原始数据保护

`GeneratePaperBenchmarkInstance(n,InstanceSeed,'SFactor',...)` 只返回新结构，不写原始 `Data_N*.mat`。需求、订货、库存、配送和 penalty 的抽样顺序及规则全部沿用当前 `Generate_Large_Data.m`。Penalty 发生概率仍为 .1，发生时金额仍为 `(sw_i+sw_j)*(1.2+.8*rand)`。

显式 SFactor 是 benchmark 场景参数，默认 .3，与原生成器一致。论文表 2 的配送比例上限和仓库现有生成器有差异：仓库使用 .10–.38；本轮保留仓库逻辑，不擅自改成论文范围。结果必须称“按当前仓库数据规则生成的独立 benchmark”，不能写为逐项完全复刻论文数据分布。

`InstanceSource='fixed','Instances',1,'SFactors',.3` 读取冻结 Data_N*.mat，不重缩放 S，不改变输入。fixed 模式 `InstanceSeed=NaN`，生成模式每个 N/S/实例用独立 InstanceSeed。AlgorithmSeed 单独派生；同一实例内各算法配对同一个 AlgorithmSeed 用于复现控制，这不表示随机路径相同。

所有实例保存于新结果目录的 `instances/`，Study 中保留输入和生成元数据；原数据目录不会被覆盖。

## 4. 表 3 类指标

每个 InstanceID 的 reference best 定义为全部算法、全部算法 seed 的最低 `CommonGridTC`，即 BKS，不是全局最优证明。

每次运行的 gap 为 `100*(CommonGridTC-ReferenceBestTC)/ReferenceBestTC`。先在同一实例同一算法上平均各 seed 的 gap，再跨独立实例平均，得到 `AverageGapPercent`。

`BestCount` 统计某算法的“跨 seed 最好值”命中该实例 BKS 的实例数。`RunBestCount` 另外统计命中的独立求解次数。命中容差为 `BestRelativeTolerance*max(1,abs(BKS))`，默认相对容差 1e-9。并列命中允许多个算法同时计数。

同一 InstanceID、同一算法、多 AlgorithmSeed 的 TC 标准差和变异系数才衡量随机搜索稳定性。它们在 `instance_summary.csv` 中分别为 `StdTC`、`CVPercent`。N 级 summary 中使用 `AverageWithinInstanceStdTC` 和 `AverageWithinInstanceCVPercent`；不会把不同实例的绝对 TC 方差解释为算法随机不稳定。只有一个 AlgorithmSeed 时稳定性指标为 NaN，必须增加 seed 后才能研究此问题。

## 5. 收敛和复算

GA/JADE 每代保存 best partition；VND 每个接受状态/阶段保存 best partition；Evolutionary-X 保存各代 checkpoint。其 `CommonBestTC` 都来自同一网格目标，可随时利用 `CheckpointPartitions` 独立重算。

`convergence.csv` 中保留 CommonBestTC、ElapsedSeconds 和 GroupEvaluations。VND 没有自然的“代”，其 Generation 为 NaN、CheckpointUnit 为 VND checkpoint；不能把一个 VND checkpoint 机械等同一代进化搜索。绘图可选择真实 elapsed seconds 或明确的工作计数，并披露对应坐标口径。

全部任务完成后，`Plot_Paper_Experiment2` 输出 `performance_panels.png/.fig`（平均时间、BestCount、AverageGap 三面板）和 `common_convergence.png/.fig`。收敛图把每个 checkpoint 的 CommonBestTC 转为相对该实例最终 BKS 的百分比 gap，再跨实例和算法 seed 平均，避免将不同实例的绝对成本混成曲线。横轴是实际保存的 search elapsed seconds；首次 checkpoint 前不虚构数据，算法停止后仅保持其最后最好值。图不把时间引入策略成本判优，也不把 VND checkpoint 称为进化代数。

## 6. 保存、恢复和证据范围

每个完整 solver call 后先原子提交 raw MAT，再更新 Study 和 CSV。若关机发生在 raw 写完而 Study 更新之前，恢复时验证 raw 的输入、配置、源码 manifest、实例、算法和 seed，再复算 CommonGridTC，直接恢复已经完成的任务。未完成的 solver call 会按同 seed 重算。

`MaxNewSolves` 可在任务边界暂停，仅用于管线测试或控制本次执行任务数，不属于算法预算；它不进入 Config，因此 Resume 不必重复相同上限。设为 0 只初始化/刷新输出，不运行 solver。旧 schema1 实验结果不与新 schema2 混合。

正在运行时，BKS 根据目前已返回任务更新；`InstanceComplete=false` 表示该实例全部算法/seed 尚未完成。这些中间文件不能写作正式性能结论。

## 7. 入口示例（本轮不自动启动）

```matlab
Setup_JRD;
% 最小烟雾测试，不是论文证据
[study,out]=Run_Paper_Experiment2_DirectPerformance( ...
    'NList',10,'Instances',2,'Runs',2,'Generations',2, ...
    'PopulationFactor',1,'MinimumPopulation',8,'GridStep',.01);

% 后续 preliminary 例：全部参数应预先固定
[study,out]=Run_Paper_Experiment2_DirectPerformance( ...
    'NList',[30 50 100],'Instances',3,'Runs',3, ...
    'Generations',100,'PopulationFactor',4,'GridStep',.001);

% 恢复时重复影响数学/算法的参数，传入同一个 out
[study,out]=Run_Paper_Experiment2_DirectPerformance( ...
    'NList',[30 50 100],'Instances',3,'Runs',3, ...
    'Generations',100,'PopulationFactor',4,'GridStep',.001,'ResumeDir',out);
```

正式结果文件：`raw_results.csv`（逐 solver call）、`instance_summary.csv`（实例内稳定性）、`summary.csv`（N 级指标）、`convergence.csv`（统一目标曲线）、`study.mat`（全部输入、源码、参数、完整解和 checkpoint）。

## 8. 无人值守任务失败和扩展

`ContinueOnTaskError=true` 会记录一个独立任务的非模型异常，然后继续其它实例/seed/算法。原始输入不合法、模型或费用不一致、源码/checkpoint 不匹配、保存失败仍会停止整个队列。这些错误不能被“继续运行”开关掩盖。老师 AHDE 偶发连续坐标恰好到上边界而导致解码越界时，非法解会被 wrapper 拦住；该 seed 可标记局部失败，而其它独立 seed 继续。

失败状态持久保存在 `Study.Failures`（当前未解决）、`ErrorRecords`（全部历史事件）、`AttemptCounts`（真实 solver 尝试次数）。输出新增 `task_status.csv`、`failed_tasks.csv`、`errors.csv`。有失败时最终 Status 为 `completed_with_failures`，没有假称完成，也不生成最终性能图；对应实例的 `InstanceComplete` 仍为 false。

恢复默认 `RetryFailedTasks=true`，只重试尚缺的/失败的任务；已经成功的任务保持原始解、runtime 和收敛。成功重试后，当前失败状态清除，历史错误标记 `Resolved` 而不删除。`RetryFailedTasks=false` 则继续其余任务并暂时跳过当前失败。Continue/Retry 是执行控制，不进入数学/算法 Config。

可以在新目录里从 12 次校准扩展到更多独立实例和 seed：

```matlab
[expanded,newOut]=Extend_Paper_Experiment2_Preliminary(calibrationOut, ...
    'Instances',3,'Runs',3);
```

该函数只准备结果，不启动搜索。它严格核对 parent 的源码/data manifest、每个匹配实例的全部输入和生成元数据、算法、预算和 seed，仅允许 Instances/Runs 增加。已完成匹配记录及原子 raw 会被复制到新目录；旧目录始终只读。新 Study 记录 ParentDir、TaskProvenance、ReusedRecords；再用完全相同新 Config 的 runner ResumeDir 执行新增任务。

AlgorithmSeed 使用稳定的 N/InstanceSeed/run 身份计算，不依赖全局 scenario 行号。因此增加实例后原任务的随机流不变。扩展期间源代码若变化会被拒绝，不能混合不同 solver 版本的结果。
