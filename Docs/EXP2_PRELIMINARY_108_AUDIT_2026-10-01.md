# Experiment 2：108 次 preliminary 结果只读审计

发布版导航：以下长目录是**原运行来源**，不在精简树中重建。当前直接打开[完整108次结果](../Results/Exp2_DirectPerformance/README.md)；源文件未改写，路径映射与哈希见[发布manifest](../Provenance/delivery_file_manifest.csv)。

审计日期：2026-10-01。审计仅读取现有 CSV/MAT 和源码 hash；未启动 MATLAB，未修改算法、数据或本批实验配置。

## 1. 最重要结论

108 个任务全部完成，没有失败或数据一致性异常。在本批预算和实例上，Evolutionary-X 的成本明显好于 GA/JADE partition adapters，但其相对 VND 的成本优势不成立。

同一实例、同一算法 seed 配对比较 Evo 与 VND：27 对中 VND 成本更低 26 对、并列 1 对，Evo 没有成本更低的任务。VND 在全部 9 个独立实例上命中本批 BKS；Evo 在 N=30 的一个实例上与 VND 并列命中。这里的 BKS 是本批算法共同找到的最好可行值，不是已证明全局最优。

## 2. 本批设计、计数和来源

- N=[30,50,100]；每规模 3 个独立 benchmark instances；每实例 3 个 algorithm seeds；4 个 Direct 算法，共 `3×3×3×4=108` 次任务。
- 进化算法 Generations=100、Population=4N：分别为 120、200、400；GridStep=0.001。
- VND 使用同一网格组成本核心、预设 starts/ILS 和未缓存组评价上限 `P×(G+1)`；上限分别为 12,120、20,200、40,400。不存在超限，但该计数单位与进化算法的外层分区评价不同，不能称严格等计算工作量。
- InstanceSource=generated、SFactor=0.3、BaseInstanceSeed=20261001、BaseSeed=20261001。实例生成沿用当前仓库数据规则，不改变原始 Data_N*.mat 或 penalty 生成规则。
- GA/JADE 是保留原搜索算子、使用 N 个有效连续标签坐标及公共网格适应度的 partition adapters，不是原历史 2N 代码原样复现。
- 新结果目录复用了原 12 次校准的完整已完成记录，再执行新增 96 个任务。`ReusedRecords=12`，parent 输入、任务身份和稳定 seed 保持一致；旧校准目录未被覆盖。
- 保存状态 `complete`；108 条 raw records、108 个 checkpoint 轨迹、36 条实例级汇总、12 条 N/算法汇总；`errors.csv` 为 0 条事件。
- Queue Git commit：`f8e9b9c302be7356da0054ca5fa29ece08e64928`。

结果公共父路径，相对于仓库根目录：

```text
Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/
  tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/
```

父路径下的原校准目录：

```text
Exp2_Calibration_12/tp1990b75a_dadf_48dc_b33e_22e31da7ba60/
```

父路径下的本批完整目录：

```text
Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/
```

主要文件：`raw_results.csv`、`instance_summary.csv`、`summary.csv`、`convergence.csv`、`task_status.csv`、`errors.csv`、`task_provenance.csv`、`study.mat` 和 `raw/`。

## 3. 完整性能表

平均 TC 为 CommonGridTC。Gap 以同一实例全算法/seed 的 BKS 为参考。BestCount 按每规模 3 个独立实例计数。稳定性栏为“平均实例内 StdTC / CV%”；秒数包含 search、postprocess 和最终验证，不含整组 CSV/Study/绘图开销。

| N | 算法 | 平均 TC | Gap% | BestCount | 平均秒 | StdTC / CV% |
|---|---|---:|---:|---:|---:|---:|
| 30 | Evo | 43,393.20 | 1.454 | 1/3 | 7.17 | 500.35 / 1.144 |
| 30 | GA | 47,905.73 | 11.964 | 0/3 | 4.63 | 959.80 / 1.973 |
| 30 | JADE | 56,836.01 | 32.820 | 0/3 | 9.32 | 759.49 / 1.327 |
| 30 | VND | 42,787.79 | 0.032 | 3/3 | 6.65 | 12.03 / 0.029 |
| 50 | Evo | 80,128.60 | 6.117 | 0/3 | 15.95 | 1,047.25 / 1.289 |
| 50 | GA | 95,505.49 | 26.460 | 0/3 | 12.74 | 819.64 / 0.841 |
| 50 | JADE | 116,793.78 | 54.719 | 0/3 | 25.06 | 1,291.07 / 1.110 |
| 50 | VND | 75,616.60 | 0.164 | 3/3 | 13.24 | 104.69 / 0.146 |
| 100 | Evo | 190,488.74 | 12.048 | 0/3 | 50.74 | 3,052.46 / 1.569 |
| 100 | GA | 262,421.38 | 54.363 | 0/3 | 54.94 | 5,477.35 / 2.088 |
| 100 | JADE | 311,441.20 | 83.236 | 0/3 | 114.59 | 6,102.82 / 1.952 |
| 100 | VND | 171,152.73 | 0.698 | 3/3 | 14.45 | 1,080.77 / 0.612 |

Evo 与 VND 的配对结果：

| N | Evo 更低 | 并列 | VND 更低 | Evo 平均 TC 高于 VND |
|---|---:|---:|---:|---:|
| 30 | 0 | 1 | 8 | 1.4149% |
| 50 | 0 | 0 | 9 | 5.9669% |
| 100 | 0 | 0 | 9 | 11.2975% |

最后一列为 `(平均TC_Evo−平均TC_VND)/平均TC_VND`，不同于逐任务、逐实例的 BKS Gap。逐配对差百分比的均值分别为 1.4215%、5.9422%、11.2833%，因分母逐任务变化，和均值成本的比例不必完全相等。

108 条记录的 Runtime 合计为 `2965.2884913 秒`，约 49 分 25 秒，其中包含原 12 次校准的已复用 runtime。新增 96 个任务对应的求解 runtime 约 44 分钟。此数值不是包含全部序列化、汇总和绘图的阶段 wall-clock。

## 4. 指标的准确含义

**CommonGridTC**：所有算法返回的分区 X 均使用同一个 `DirectGridPartitionCost`、同一 T 网格及整数 f 可行域计分。正式表和收敛不混用 native objective。`NativeContinuousTC` 只作为同一最终分区的连续 T 辅助值保存。

**Average Gap**：同一个 InstanceID 的全部算法、全部 algorithm seeds 最低 CommonGridTC 为 reference BKS。每个任务计算 `100×(CommonGridTC−BKS)/BKS`，先在同实例平均 seeds，再跨实例平均。不能用一个规模所有不同实例的最低绝对 TC 作为共同参考。

**BestCount**：某算法跨 seed 的最好成本命中实例 BKS 的实例数，容差为 `1e-9×max(1,abs(BKS))`。并列允许两个算法同时计数；所以 N=30 的 Evo=1、VND=3 不矛盾。`RunBestCount` 另统计命中的单次任务数：VND 在 N=30/50/100 分别为 6/6/5，Evo 在 N=30 为 1、其它规模为 0。

**StdTC / CV**：先在同实例、同算法的 3 个 seeds 上计算样本标准差和 `100×StdTC/MeanTC`，再对 3 个实例取平均。它们描述搜索随机性。跨实例的原始 TC 差异来自输入差异，不能解释成算法不稳定。

**Convergence**：所有 checkpoint 的纵轴都为公共 CommonBestTC。VND 的 checkpoint 不是进化代数；应按明确的 elapsed seconds 或工作计数展示，而不把一条 VND 记录等同一代。

## 5. 独立只读核验

| 检查 | 结果 |
|---|---|
| 设计计数与维度 | 108=3规模×3实例×3seeds×4算法，全部匹配 |
| 五项成本之和与 TC | 最大绝对差 `8.15e-10`，无负成本 |
| 公共收敛 | 13,501 个 checkpoint 全部非增，最大上升为 0 |
| checkpoint 终点与 raw TC | 最大差 `1.02e-10` |
| BKS 与 Gap 独立重算 | 最大字段差 `8.25e-13` |
| 实例内样本 Std 独立重算 | 最大差 `4.69e-10` |
| 实例内 CV 独立重算 | 最大差 `3.30e-13` |
| Summary 的均值、Gap、Std/CV、runtime | 均独立重算匹配，浮点差小于 `1e-9` |
| BestCount / RunBestCount | 独立计数全部匹配 |
| 预算和 seed | G=100、P=4N、GridStep=.001；稳定任务 seed 派生全部匹配 |
| VND 组评价上限 | 无超限 |
| NativeContinuousTC 与 CommonGridTC | 未出现连续 T 辅助值高于网格值 |
| 失败与完成状态 | 0 错误；complete；全部 InstanceComplete=true |
| 来源 metadata | 12 次任务复用、parent 和稳定 seed policy 均保留 |
| 当前源码/数据 manifest | 118 个记录路径的 SHA256 均与当前文件一致 |
| 源码 Text metadata | 113 条 Text 非空，所带 SHA256 与 manifest 对应一致 |

所有误差均处于 CSV 小数保存和双精度浮点量级，没有发现足以改变性能结论的结果保存、费用或统计口径问题。

## 6. 为什么不能宣称“新 Evo 性能领先”

本批 VND 在全部规模上的平均 TC、平均 runtime 和平均实例内 CV 都优于 Evo。Evo 的平均 BKS Gap 从 N=30 的约 1.45% 上升到 N=100 的约 12.05%，需要进一步检查结构搜索能力。只能说当前 Evo 优于本批 GA/JADE 标签适配器，不能据此省略更强的 VND 基线。

每规模只有 3 个独立实例和每实例 3 个 seeds，且只是 G=100、P=4N 的 preliminary 预算。尚不能把此批结果推广到全部异质品实例，也不能反向证明 Evo 在更充分预算下永远不如 VND。500 代/10N 单次 profiling 主要回答运行成本，不能替代本批多实例性能结果。

本批四个方法全部都是 Direct 求解算法。它不能单独证明 Direct 策略比 Indirect 策略更优。正在运行的 Exp3 仍使用新 Evo Direct 对老师原 AHDE Indirect；本批发现说明 Direct 搜索不足也可能影响策略比较，需要用预先确定的补充证据解释。

## 7. 下一步预先规划；不改变当前批次

建议在下一份独立设计和新结果目录中预先固定 Evo 的结构局部搜索消融：现有轻量随机强化、关闭强化、加入有限且明确计数的 VND 结构强化等版本。统一公共 evaluator、数据和 seeds，单独报告增加的组评价/候选数/runtime，再检验成本改善来自哪项搜索设计。不要看到某实例输赢后临时只给一侧加预算。

同时保留纯 VND 基线，检查 Evo 收敛、组数和局部结构改进空间；更充分的 evolution 预算必须先依据收敛 pilot 决定。原 108 次记录和本批结论应保留，不能通过替换求解器后覆盖原结果来形成“新算法始终领先”的叙述。

策略成本比较继续遵守主线：Direct=Evolutionary-X，Indirect=老师原 AHDE。已有更强 Indirect VND、completed-search 和 block-K 作为 robustness/supplementary 检查 AHDE 搜索不足。补充分析可报告不同求解器找到的更低可行值，但不擅自替换主比较中的老师 AHDE，也不把启发式最好值称全局最优。

本报告只规划后续研究，不修改当前运行中的 Exp3/Exp4 或已经完成的 Exp2 配置。
