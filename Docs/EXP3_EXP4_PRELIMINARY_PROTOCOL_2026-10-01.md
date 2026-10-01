# 实验 3/4 开跑前工程修订口径

日期：2026-10-01。本文记录实现，不代表正式长实验已完成。

## 实验 3：主策略比较

Direct 主算法仍是 `EvolutionaryX_Direct`；Indirect 主算法仍是未经修改的 `AHDE.m`，通过 `RunTeacherAHDE` 调用。更强的 Indirect 搜索仅用于补充稳健性分析。

两侧使用同一原始实例、配对的算法 seed、相同种群规模与代数层级。相同 seed 使每次运行可以复现，不代表不同算法具有相同随机轨迹。相同种群和代数不代表相同成本评价次数或相同工作量：原 AHDE 每代评价 2×Population 个连续染色体，Direct 还包含分组缓存和精英强化。所有运行记录时间，但不以时间判定策略成本优劣。

原始 `Data_N*.mat` 每个 N 是一个 benchmark instance。30 个算法 seed 是同一个实例的重复运行，不是 30 个独立实例；结果字段 `InstanceId=FixedData_N*` 对此明确区分。

`comparison.csv` 汇报跨 seed 的最好可行成本，同时报告配对成本差的均值、标准差与配对节约率均值。`paired_comparison.csv` 保存每对 seed 的两个 TC、成本差、节约率及真实单次运行时间。大规模结果不能称为已证明全局最优。

## 实验 4：只改变频率可行域

四种情形分别重新优化外层变量：Direct 可优化 f、Direct 固定 f=1、Indirect 可优化 F、Indirect 固定 F=1。

两个 Direct 情形调用同一 `EvolutionaryX_Direct`，除 `FixedF=1` 外所有算法参数一致。两个 Indirect 情形调用同一原始 `AHDE.m`；固定情形只传入 `FInf=FSup=1`。原 AHDE 的 2N 维染色体、越界修复、交叉、选择等机制保持一致。`AHDE_FixedF1.m` 保留作为 supplementary，不进入主结果。

可调频率可行集合包含固定为 1 的集合。若启发式找到的 coordinated TC 高于对应 fixed TC，`PaperCoordinationSanity` 将其标为 `heuristic_search_insufficiency`。异常值仍原样保存，既不裁剪节约率，也不把固定解偷换为协同解。数值容差为 `1e-9*max(1,TCcoord,TCfixed)`。

`paired_savings.csv` 保存配对协同收益、两侧异常标志与状态；`paired_summary.csv` 保存节约率均值、标准差、范围及异常计数；`anomalies.csv` 明确列出每对运行的检查状态。`comparison.csv` 另报告跨 seed 最好成本的协同比较与异常。

## 输出与恢复

实验 3/4 通用输出：

- `study.mat`：完整配置、源码/数据 manifest、原始输入和每个已完成 solver 的完整 solution。
- `raw/*.mat`：单次原始完整解、身份与五项成本诊断；原子保存。
- `raw_results.csv`：TC、运行时间、五项成本及五项之和误差。
- `summary.csv`：最好/均值/中位数/样本标准差/最差/CV/平均运行时间。只有一个 seed 时样本 Std、CV 为 NaN。
- `diagnostics.csv`：五项成本、组数或 K 类数、边隔离率与 Indirect penalty 衰减。
- `convergence.csv`：各策略自身原成本模型的 TC 收敛。AHDE 未采集逐代时间，其逐代时间字段为 NaN，不用插值伪造。
- `solution_items.csv`：逐商品的组号、实际补货周期、频率，以及仅对 Indirect 存在的 K 和公共 T。完整组解仍在 MAT 中。

每完成一个 solver 即保存，因此一次 seed 中两侧或四种情形只完成部分时也可续跑。`ResumeDir` 要求配置、源码、数据完全匹配。若原始 raw 已提交但 study 未提交，恢复会校验身份、预算、seed、网格和五项成本后回收 raw；已完成 solver 不重算。原 AHDE 不提供代内 checkpoint，关机发生在 AHDE 调用内部时，只重跑这个未完成调用。

新增操作参数 `MaxNewSolves` 可在 solver 边界停止，用于故障注入测试；它不属于数学或算法配置，不影响 resume 匹配。历史 SchemaVersion=1 目录需要原版本 runner，不能与新 SchemaVersion=2 混合。

无人值守时可设 `ContinueOnTaskError=true`。单个独立 solver 的运行错误会记录到 `Failures` 当前状态和 `ErrorRecords` 历史中，然后继续其它任务；输入、源码/schema、模型/成本一致性或结果写入错误仍属于全局阻断，保存错误后重抛。默认关闭该选项以保持交互时及时显露失败。

`RetryFailedTasks=true` 默认在 resume 时重试失败 slot，成功后清除当前失败并将历史标记为 resolved；设为 false 时跳过这些 slot，同时保留其它成功结果。它与 `ContinueOnTaskError`、`MaxNewSolves` 一样是操作控制，不参与数学/算法配置匹配。全部成功状态为 `complete`，执行完计划但仍有失败时为 `completed_with_failures`；全局阻断为 `blocked_global_error`。

每完成一个 solver 都同步原始 MAT 和 CSV。`task_status.csv` 列出全部计划任务的完成/失败/待运行状态，`failed_tasks.csv` 列出当前失败，`errors.csv` 保留历史。原始结果的 `PairComplete` 表示该 seed 的所有比较情形是否成功；主 summary 和 comparison 只使用完整配对 seed，避免因某一算法失败而在不同样本上比较均值。未配对的成功结果仍保存于原始文件，不填造成本。

## 参考预算与待实测部分

默认 `PopulationFactor=10`、`Generations=500`、`GridStep=0.001` 被明确记录为老师论文参考预算。参数可缩小用于 pilot；本文件不认定参考预算就是正式预算。正式多规模多种子实验须在真实 wall-clock profiling 和收敛检查后再启动。

原 AHDE 的 floor 解码在连续分量恰好为 1 时可能产生整数上界+1。这次只在 wrapper 增加显式边界断言；没有裁剪结果或修改老师的核心机制。如果断言触发，应报告原算法边界问题并由老师决定修订。

本轮没有改变跨组 penalty 规则、每组 S 收费、任何变量结构、原始成本模型、原始数据或 penalty 生成逻辑。
