# JRD-HI 四个实验：会议汇报与点击展示

截至2026-10-01：四类实验已经具备可展示结果。Exp1是冻结的小规模正确性证据；Exp2/3/4是已完整完成的preliminary，不是论文最终formal benchmark。本页按“结果呈现—设计思路—当前方向—入口/算法/数据链路”组织，所有本地链接用于当前电脑直接查看。

| 实验 | 要回答的问题 | 当前进度 | 本批配置 |
|---|---|---|---|
| 1：N=10 | 新Direct是否算对、能否命中小规模精确值 | 网格证书+5/5 seeds命中，保持冻结 | P=80、G=250、T网格=.001 |
| 2：N=30/50/100 | 新Direct求解算法是否优于代表基线 | 108/108成功 | 3实例/N×3seeds×4算法；P=4N、G=100 |
| 3：两策略成本 | Evolutionary-X Direct与原AHDE Indirect谁找到更低成本 | 40/40成功 | 4规模×5seeds×2策略；P=4N、G=100 |
| 4：协同配送 | 可优化频率与固定频率1分别能降低多少成本 | 16/16成功 | 4规模×1seed×4情形；P=10N、G=500 |

Exp2/3/4共164个独立求解，失败0，后台于15:02全部结束。Exp2的12次calibration复用于108批中，不重复计数。运行时间用于性能报告和排程，不用来判定Direct/Indirect策略谁成本更低。

会议建议顺序：Exp1证明正确性 → Exp2检验算法能力 → Exp3比较策略成本 → Exp4解释配送协同收益。不要把四个实验的不同预算、不同实例或不同seed数混成一个统一统计。

## 实验1：N=10 小规模可复现验证

### 1. 先展示结果

配置T网格和整数f∈{1,…,20}下的Direct全局精确值为 **12059.2627236542**。5个算法seeds（20260919–20260923）全部命中，GridOptimalityGapPercent=0，HitGridOptimum=1。

| 组 | 商品编号 | 周期T_k | 配送频率f_k | 组成本 |
|---|---|---:|---:|---:|
| G1 | 1、7、8、10 | 0.326 | 2 | 3652.351871 |
| G2 | 2、3、4、5、6、9 | 0.190 | 2 | 8406.910852 |

f=2表示一个组的补货周期内配送两次；T沿用原数据模型的时间单位，不擅自解释为天。这里Direct没有K。

| 订货 | 配送 | 中心仓库存 | 零售库存 | Penalty |
|---:|---:|---:|---:|---:|
| 4627.704230 | 1393.773465 | 2402.466263 | 3635.318766 | 0 |

五项成本之和等于TC（表中四舍五入可能有最后一位误差）。连续T精确值为12059.2516110867，作为更低的连续放宽参考单列；网格值不是连续域全局最优值。

现场先打开 [五次运行结果 runs.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/runs.csv)，指给老师看Gap=0、Hit=1和GroupCount=2；再查看 [完整精确解及五次方案 study.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/study.mat)。

### 2. 设计思路

先计算N=10全部1023个非空商品子集的最优组成本，再用subset-partition动态规划寻找全局最优partition。对每个组按整数f和离散T网格优化，不给Direct加入K。然后用Evolutionary-X的5个独立seeds重复求解同一输入，和网格精确证书比较。

内层生产计算使用凸函数的相邻网格候选投影：固定f时组成本为A/T+B*T/2，极小点为sqrt(2A/B)，检查相邻网格点和边界可得到同一网格最优值。已用字面网格枚举独立复核，不是将T偷换为连续值。

### 3. 当前方向

正确性目标已达成，保留原证书和结果不重跑长实验。以后改搜索或加速实现时继续用这套精确证据和枚举一致性测试守住成本正确性。结论仅覆盖此N=10输入及配置的T网格/f可行域，不扩张为大规模全局最优证明。

可直接汇报：“在N=10固定实例上，新Direct五次独立运行均命中离散网格精确最优值，分组、周期、频率和五项成本完整可复现。”

### 4. 实验入口、算法与数据链路

| 要打开什么 | 实际文件 | 展示重点 |
|---|---|---|
| 原输入 | [Data_N10.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Data_N10.mat) | 数据未修改 |
| 实验入口 | [Run_Paper_Experiment1_N10.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/Run_Paper_Experiment1_N10.m) | 先精确求解，再跑5seeds并比较gap |
| 新Direct主算法 | [EvolutionaryX_Direct.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/EvolutionaryX_Direct.m) | 外层进化搜索分组X |
| 网格精确证书 | [ExactDP_DirectGrid.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/ExactDP_DirectGrid.m) | 全部子集及partition动态规划 |
| 连续参考 | [ExactDP_Direct.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Direct_V1/ExactDP_Direct.m) | 连续T参考，不混作网格结果 |
| 公共分区评价 | [DirectGridPartitionCost.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/DirectGridPartitionCost.m) | 将X转成组并累加五成本 |
| 组内T/f计算 | [DirectGridGroupKernel.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/DirectGridGroupKernel.m) | 网格候选、频率、五成本 |
| 运行数字 | [runs.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/runs.csv) | Seed、TC、Gap、命中、组数、时间 |
| 单次原始解 | [N10_run001.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/raw/N10_run001.mat) | 第一次运行的record/Answer |
| 完整证据 | [study.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/study.mat) | Input、Config、ExactGrid、ExactContinuous、Runs、Source |

调用顺序：输入 → Exp1 runner → ExactDP_DirectGrid / EvolutionaryX_Direct → 公共partition与group评价 → runs.csv / study.mat。冻结study中的Source是当时版本的追踪依据；下面当前同名源文件用于讲解当前实现，不把后来工程提速版本冒充原运行快照。

若MAT文件不能直接预览，在MATLAB中只读查看：

```matlab
S = load('D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/study.mat','Study');
S.Study.ExactGrid
S.Study.Runs{1}
```

## 实验2：N=30/50/100 的Direct算法性能

### 1. 先展示结果

完整108条：每N 3个独立benchmark instances，每instance 3个算法seeds，比较Evolutionary-X、GA、JADE、VND。T网格=.001，G=100，P=4N；这是完整pilot，不是500/10N正式统计。

| N | 算法 | 平均CommonGridTC | 平均Gap% | BestCount/3 | 平均秒 | 实例内CV%均值 |
|---|---|---:|---:|---:|---:|---:|
| 30 | Evolutionary-X | 43393.20 | 1.454 | 1 | 7.17 | 1.144 |
| 30 | GA | 47905.73 | 11.964 | 0 | 4.63 | 1.973 |
| 30 | JADE | 56836.01 | 32.820 | 0 | 9.32 | 1.327 |
| 30 | VND | 42787.79 | 0.032 | 3 | 6.65 | 0.029 |
| 50 | Evolutionary-X | 80128.60 | 6.117 | 0 | 15.95 | 1.289 |
| 50 | GA | 95505.49 | 26.460 | 0 | 12.74 | 0.841 |
| 50 | JADE | 116793.78 | 54.719 | 0 | 25.06 | 1.110 |
| 50 | VND | 75616.60 | 0.164 | 3 | 13.24 | 0.146 |
| 100 | Evolutionary-X | 190488.74 | 12.048 | 0 | 50.74 | 1.569 |
| 100 | GA | 262421.38 | 54.363 | 0 | 54.94 | 2.088 |
| 100 | JADE | 311441.20 | 83.236 | 0 | 114.59 | 1.952 |
| 100 | VND | 171152.73 | 0.698 | 3 | 14.45 | 0.612 |

Gap参考是同一instance上全部算法/全部seeds找到的最低CommonGridTC（BKS），不是已知全局最优。BestCount数命中BKS的实例，分母3，并列允许同时计数。Std/CV先在同一实例不同seeds间计算，再跨实例平均，不把输入实例差异混进算法稳定性。

结果显示Evo优于GA/JADE，但VND对Evo的27个配对为26胜1平，Evo无胜。不能说新算法已性能领先。

老师看图先点 [性能三联图：Runtime / BestCount / Gap](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/performance_panels.png)，再点 [公共目标收敛图](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/common_convergence.png)；对应数字是 [summary.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/summary.csv)。

### 2. 设计思路

独立实例和算法随机seed分开。四种算法只搜索Direct的partition X，内层T/f由同一DirectGridPartitionCost计分；最终CommonGridTC和所有checkpoint的CommonBestTC都使用同一网格目标。native连续辅助成本另存，不能混入主性能排名。

Evolutionary-X：多种分组粒度初始化 → 规范化组标签 → 内层网格评价 → 选择/交叉/变异与轻量强化 → 精英保留迭代。GA/JADE使用保留旧算子思路的N维partition适配器，不是将历史2N染色体原样套到Direct。VND使用迁移、合并、交换、拆分等结构邻域和多起点扰动。

VND无自然种群/代数，P/G用于派生预设组评价cap。相同公共目标已控制，但其评价计数与进化算法partition评价不是同一种工作单位，不能写成严格等计算工作量。收敛按真实搜索耗时展示，不伪造VND的generations。

### 3. 当前方向

优先预先设计纯Evo、Evo+受限结构局部改进、VND的消融，再用新独立实例验证。报告新增评价数与时间，不能看到输赢后只给某方法加预算。算法质量改进和收敛pilot完成后再锁定正式预算、实例数及seeds，不隐去强基线VND。

可直接汇报：“已经完成统一网格目标下的108次性能preliminary。Evo优于GA/JADE，但仍明显弱于结构VND，下一步重点是改进分组搜索，而非直接宣称算法优秀或盲目扩大实验。”

### 4. 实验入口、算法与数据链路

| 要打开什么 | 实际文件 | 展示重点 |
|---|---|---|
| 实验入口 | [Run_Paper_Experiment2_DirectPerformance.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m) | 实例×seeds×算法、统一终点和收敛 |
| benchmark生成 | [GeneratePaperBenchmarkInstance.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/GeneratePaperBenchmarkInstance.m) | 独立data seed，不改原Data_N*.mat |
| 已保存实例示例 | [N30 instance1](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/instances/N30_S030_Q01_I001.mat) | 本批SFactor=.3，原始输入可追踪 |
| 新Direct主算法 | [EvolutionaryX_Direct.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/EvolutionaryX_Direct.m) | 初始化、选择、交叉、变异、迭代 |
| GA/JADE/VND分发 | [RunCommonDirectBaseline.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/RunCommonDirectBaseline.m) | 当前正式适配器及VND配置 |
| VND结构邻域 | [BestNeighbor_Direct.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Direct_V1/BestNeighbor_Direct.m) | 改动受影响的组、增量评价 |
| 共同目标 | [DirectGridPartitionCost.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/DirectGridPartitionCost.m) / [DirectGridGroupKernel.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/DirectGridGroupKernel.m) | 同一T/f与五成本口径 |
| 展示图表 | [性能图](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/performance_panels.png) / [收敛图](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/common_convergence.png) | 三规模性能和公共收敛 |
| 汇总数字 | [summary.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/summary.csv) / [instance_summary.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/instance_summary.csv) | Runtime、BestCount、Gap、Std/CV、逐实例结果 |
| 单次与收敛原表 | [raw_results.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/raw_results.csv) / [convergence.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/convergence.csv) | instance seed、algorithm seed、CommonGridTC、五成本、CommonBestTC |
| 完整商品方案 | [study.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/study.mat) | 分组、T、f、输入、参数、源码、checkpoints；单次完整方案在raw MAT中 |
| 复用和完成追踪 | [task_provenance.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/task_provenance.csv) / [task_status.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/task_status.csv) | 12条calibration只读复用；108条成功 |

调用顺序：generator → runner → Evo或RunCommonDirectBaseline → DirectGridPartitionCost / cache / group kernel → 最终公共重算 → raw/study → summary与Plot_Paper_Experiment2两图。

## 实验3：Direct与Indirect完整策略成本比较

### 1. 先展示结果

完整40条：N=10/30/50/100，每N原固定实例，各5个paired seeds，两策略P=4N、G=100。Direct=新Evolutionary-X；Indirect=老师原AHDE。

| N | Direct最好可行TC | Indirect最好可行TC | 最好值Saving% | 平均配对Saving% |
|---|---:|---:|---:|---:|
| 10 | 12059.26 | 13112.33 | 8.03 | 8.51 |
| 30 | 46734.36 | 63856.28 | 26.81 | 26.63 |
| 50 | 79143.93 | 112213.06 | 29.47 | 28.62 |
| 100 | 168041.85 | 248519.90 | 32.38 | 31.01 |

最好值Saving=100×(IndirectBest−DirectBest)/IndirectBest，两侧best可能来自不同seeds。平均配对Saving先按同seed计算再平均，不能混称一个指标。20个配对均Direct更低。

老师现场先点 [策略汇总 comparison.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/comparison.csv)，再看 [逐seed配对 paired_comparison.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/paired_comparison.csv)。这批只支持“指定实例/solver/预算下Direct找到更低成本”，不能说“已证明Direct全局最优成本更低32%”。

### 2. 设计思路

两侧使用同一原始输入、paired seed和同层级P/G；保留Direct的X/groups/T_k/f_k与Indirect的T/K_i/F_i变量结构差异，不强求完全对称。Direct外层进化分组、内层精确网格T/f；Indirect由原AHDE搜索2N连续编码、解码K/F并计算原T。

RunTeacherAHDE只负责seed、参数、完整解记录和合法性/成本复核，不替换原AHDE搜索机制。两侧最终TC均拆成订货、配送、中心仓库存、零售库存、penalty，并保存完整方案。相同seed不等于不同算法有相同随机轨迹，同P/G也不等于相同实际评价工作。

### 3. 当前方向

20次AHDE pilot最后改善均发生在第93–100代，末20代还改善约1.04%–4.77%，不能认为Indirect已经充分搜索。下一步应做预先固定的更强共同预算和多seed验证；block-K/stronger Indirect用于robustness，不能擅自替代原AHDE主比较算法。

计划中的G500/P10N、3seed新Exp3批次尚未启动。Exp4的单seed高预算结果可观察预算响应，但不替代这一多seed实验，也不与Exp3混成同一预算汇总。

可直接汇报：“5 seeds的固定实例比较中Direct成本均更低，但AHDE末段仍改善，现阶段是初步趋势，后续要检验Indirect搜索充分性和预算响应。”

### 4. 实验入口、算法与数据链路

| 要打开什么 | 实际文件 | 展示重点 |
|---|---|---|
| 实验入口 | [Run_Paper_Experiment3_StrategyComparison.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/Run_Paper_Experiment3_StrategyComparison.m) | paired seeds、两策略、原数据、保存/resume |
| 统一case分发 | [RunPaperStrategyCase.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/RunPaperStrategyCase.m) | Direct/Indirect调用与独立复核 |
| Direct主算法 | [EvolutionaryX_Direct.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/EvolutionaryX_Direct.m) | X → groups → 网格T/f → TC |
| Indirect适配层 | [RunTeacherAHDE.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/RunTeacherAHDE.m) | 参数/seed、解码界检查、完整方案 |
| 老师原算法 | [AHDE.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/AHDE.m) | 原fitness/decode与搜索机制未改 |
| Indirect最终成本复算 | [Fitness_Indirect.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Fitness_Indirect.m) | T/K/F对应TC及五成本 |
| 两侧独立成本/诊断 | [JRDAnalyzeSolution.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Shared/JRDAnalyzeSolution.m) | 五成本、Direct组数/边隔离、Indirect K类/衰减 |
| 主结果与配对 | [comparison.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/comparison.csv) / [paired_comparison.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/paired_comparison.csv) | best Saving与paired Saving区分 |
| 单次成本及稳定性 | [raw_results.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/raw_results.csv) / [summary.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/summary.csv) | TC、五成本、seed、时间、Std/CV |
| 分组/周期/频率 | [solution_items.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/solution_items.csv) | 商品级Direct T/f或Indirect T/K/F |
| 收敛及机制 | [convergence.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/convergence.csv) / [diagnostics.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/diagnostics.csv) | AHDE末段改善、成本/冲突诊断 |
| 全部原始证据 | [study.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/study.mat) / [task_status.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/task_status.csv) | 输入、Config、Records、Source、40条完成 |

调用顺序：原Data → Exp3 runner → RunPaperStrategyCase → Evo或RunTeacherAHDE→原AHDE → 最终成本/诊断复核 → PaperStrategyOutputs → CSV与MAT。AHDE搜索时用其原内置fitness，Fitness_Indirect是最终复核，不能把两者说成同一次函数调用。

## 实验4：协同配送与不协同配送

### 1. 先展示结果

完整16条：4个规模×1seed×4情形；共同P=10N、G=500。Saving=100×(fixed TC−coordinated TC)/fixed TC。

| N | 策略 | 协同TC | f/F=1 TC | 配送协同Saving% |
|---|---|---:|---:|---:|
| 10 | Direct | 12059.26 | 12432.92 | 3.01 |
| 10 | Indirect | 12578.21 | 13151.89 | 4.36 |
| 30 | Direct | 46819.98 | 49098.62 | 4.64 |
| 30 | Indirect | 58635.54 | 62669.77 | 6.44 |
| 50 | Direct | 78494.15 | 83112.37 | 5.56 |
| 50 | Indirect | 106076.70 | 114086.86 | 7.02 |
| 100 | Direct | 159852.05 | 170408.81 | 6.19 |
| 100 | Indirect | 235386.50 | 252897.98 | 6.92 |

8个配对都找到协同成本较低的解，anomaly=0。8个fixed最终方案的频率全部严格1，原AHDE fixed的95,000个历史F值也全部1。单seed不能评价稳定性，Std=NaN不是错误或“稳定性完美”。

老师先打开 [逐配对协同收益 paired_savings.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/paired_savings.csv) / [收益汇总 paired_summary.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/paired_summary.csv)，再打开 [异常检查 anomalies.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/anomalies.csv)。

### 2. 设计思路

Direct两个情形调用同一Evolutionary-X，只将固定情形f可行域设为{1}；Indirect两个情形调用同一老师原AHDE，只将固定情形FInf=FSup=1。四种情形各自重新优化外层分组或K/T，不是仅把原最优解的频率改成1。

coordinated可行域包含fixed可行域，所以真正全局最优coordinated成本不应更高。若启发式找到coordinated>fixed，自动标记heuristic_search_insufficiency/anomaly，并保留负Saving，不解释为模型协同负收益。

旧AHDE_FixedF1.m仅保留supplementary，不用于这次主结论。f/F=1时模型的中心仓库存项自然为0，零售/订货/配送/penalty仍需重新计算。

### 3. 当前方向

先将此单seed结果作为趋势展示，再增加独立实例和重复seeds检验收益稳定性。500代部分AHDE末段仍有改善，不能称充分收敛或全局最优。保持同算法仅频率域不同的口径，继续保留异常检查。

可直接汇报：“同求解器仅限制频率的四情形比较已经完成。本批Direct协同节约约3.0%–6.2%，Indirect约4.4%–7.0%，无嵌套异常；目前仅1seed，仍需重复验证。”

### 4. 实验入口、算法与数据链路

| 要打开什么 | 实际文件 | 展示重点 |
|---|---|---|
| 实验入口 | [Run_Paper_Experiment4_Coordination.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/Run_Paper_Experiment4_Coordination.m) | 四情形重优化与paired Saving |
| 四情形分发 | [RunPaperStrategyCase.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/RunPaperStrategyCase.m) | 固定频率只传FixedF=1 |
| Direct同一主算法 | [EvolutionaryX_Direct.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Evolutionary_Direct/EvolutionaryX_Direct.m) | coordinated/f=1同实现 |
| Indirect同一适配器 | [RunTeacherAHDE.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/RunTeacherAHDE.m) | fixed时只设FInf=FSup=1 |
| 老师原AHDE | [AHDE.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/AHDE.m) | 两情形同2N结构、核心不改 |
| nesting sanity check | [PaperCoordinationSanity.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Paper_Experiments/PaperCoordinationSanity.m) | co>fixed标搜索不足 |
| 协同主结果 | [paired_savings.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/paired_savings.csv) / [paired_summary.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/paired_summary.csv) | 每策略fixed与co配对，不混为Exp3策略Saving |
| 异常 | [anomalies.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/anomalies.csv) | 本批全0，保留检查 |
| 单次五成本 | [raw_results.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/raw_results.csv) | 核查各成本项及TC |
| 完整商品方案 | [solution_items.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/solution_items.csv) | 固定频率严格1、最终T/K或groups |
| 历史轨迹和原始证据 | [convergence.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/convergence.csv) / [study.mat](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/study.mat) | 曲线、每代F、Config、完整解、Source |
| 完成数与错误状态 | [task_status.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/task_status.csv) / [failed_tasks.csv](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/failed_tasks.csv) | 16条成功，无失败 |

调用顺序：原Data → Exp4 runner → case分发（仅改变频率域）→ 同一Direct/同一原AHDE各自搜索 → 五成本复核 → PaperCoordinationSanity → paired_savings / anomalies / 完整MAT。

## 汇报收尾与通用点击入口

可用总结：“四类实验已经建立从数学、求解器到原始方案的可追踪链路。小规模正确性证据完成；108次Direct性能比较提示新Evo尚弱于VND；策略和协同实验出现有利于Direct及配送协同的初步趋势，但Indirect收敛不足、实例和重复次数仍有限。因此下一步先改进Evo搜索并补充Indirect稳健性，再锁定formal设计。”

- [项目完整晚间汇报](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Docs/PRELIMINARY_EVENING_REPORT_2026-10-01.md)；[Exp2完整审计](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Docs/EXP2_PRELIMINARY_108_AUDIT_2026-10-01.md)；[Exp3/4完整审计](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Docs/EXP3_EXP4_PRELIMINARY_RESULTS_AUDIT_2026-10-01.md)。
- [7项真实profiling汇总](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/profiling_summary.csv)：参考500/10N，Evo N30/50/100分别84.89/189.35/690.36秒；AHDE N100约190.22秒。单次测速不代替多实例性能实验。
- [MATLAB路径初始化 Setup_JRD.m](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Setup_JRD.m)；[后台批次总报告](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/REPORT.md)；[完成状态](D:/chalotte/OneDrive/문서/ChatGPT/siri/jrd_paper_worktree/Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/live_progress.md)。
- [私有源代码仓库](https://github.com/lifanghen-ux/jrd-hi-optimization)：本页引用当前本地代码和结果，本轮不自动push；GitHub不保证包含本地未上传结果。

CSV可直接查看数字，PNG可直接展示，.m链接用于阅读源码。MAT是二进制结果，需在MATLAB中load；主要study.mat变量名为Study，Exp1单次raw变量为record。查历史结果以保存的Input/Config/Source/Manifest为准。

链接是当前电脑的绝对本地路径。如果将本文发给老师在另一台电脑打开，需要同时提供对应源代码与结果并调整路径；仅发送MD不会让另一台电脑访问D盘。各runner默认参数可能更大，**打开源码查看不等于运行：现场不要按默认值直接启动长实验**。本次整理不改模型、源算法或原结果，也不新增实验。

