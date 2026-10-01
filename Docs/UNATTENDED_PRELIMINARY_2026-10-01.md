# JRD-HI：2026-10-01 无人值守 preliminary 执行说明

本文记录今天用户最新授权下的执行方案。用户暂时离线，授权完成真实 profiling 后自动运行一批 preliminary experiments，并在返回前保存可以直接阅读的结果。本文是执行协议，不表示任何未实测时间、未运行实验或未完成结果已经得到验证。

后台入口为 `Paper_Experiments/Start_JRD_Preliminary_Queue.ps1`，隐藏启动MATLAB及监视器，保存独立启动日志和PID。监视器仅在进程存活期间请求Windows保持系统唤醒，不更改永久电源设置；关机/断电仍需要断点续跑。所有路径都保存在本次 `launch.json`，便于查证。

## 执行范围与顺序

首先完成 `Profile_Paper_Solvers` 的真实单次 wall-clock 测量，保留求解完整解、五项成本、源码与原始数据追踪。Profiling 用于了解当前机器实际速度，不用单次最好值证明算法优越性。

接下来优先执行实验 2。第一批为完整的 12-task calibration：N=30/50/100，每个规模 1 个独立实例、每个实例 1 个算法 seed、4 个 Direct 算法，统一采用 `Generations=100`、`Population=4N`、`GridStep=0.001`。这里的 12 条记录是 12 次求解，不是 12 个独立实例。

calibration 完整成功后，根据实际总耗时和剩余窗口，决定是否扩展为 36 或 108 条记录。36 对应每个 N 3 个实例、每个实例 1 个算法 seed；108 对应每个 N 3 个实例、每个实例 3 个算法 seed。扩展保持相同算法预算、网格和稳定的 task seed，只增加实例或重复次数。已有匹配的成功任务直接复用，保留来源，既不重新搜索，也不把同一个解重复计作新的独立任务。

若 calibration 仍有失败，它不能被当作完整的 12-task 速度证据。队列保留失败记录并避免据此盲目扩大实验规模。实际复用数以成功匹配任务为准。

实验 2 结束后，根据剩余时间安排实验 3，再安排实验 4。实验 3/4 优先使用参考预算 `Generations=500`、`Population=10N`；只有预测完整阶段能够容纳时才启动。若参考预算不能容纳，则考虑两侧共同使用 `Generations=100`、`Population=4N` 的 pilot。各阶段的实际预算必须随结果保存，不能把 pilot 的结论混同为参考预算或正式统计证据。

## 时间窗口怎样使用

扩展阶段的估算以 calibration 实际总耗时为基础，包含当时的结果整理和保存开销，再乘以 `1.7` 留出 70% 时间余量。策略实验的估算结合实际 profiling，并记录保守估计的依据。队列为汇报预留 15 分钟。

软截止只用于决定是否启动新的完整阶段。已经开始的 solver 按预先规定的代数、种群或评价预算完成；不会因为截止时间而中断，也不会根据 Direct/Indirect 的输赢增加一侧预算。实际运行可能超过估算，保存的 wall-clock 才是事实。

本协议没有把时间作为策略成本优劣指标。时间用于机器负载、可运行性和算法性能报告；策略判优仍依据同一原始模型中的可行总成本。

## 比较和模型保持规则

实验 2 的正式目标值和收敛统一使用 `CommonGridTC` / `CommonBestTC`，即共同的 Direct partition 网格评价。原生或连续周期辅助成本另列，不能混作正式性能目标。

实验 3 的主比较为新 Evolutionary-X Direct 对老师原 AHDE Indirect。实验 4 的两个 Indirect 情形调用同一原 AHDE，固定频率情形仅将 `FInf=FSup=1`；两个 Direct 情形也调用同一实现，仅改变 f 的可行域。四种情形分别重新优化外层决策。

不修改原始成本模型、Data_N*.mat、penalty 数值及生成逻辑、跨组 penalty 规则、S 收费方式或老师 AHDE 核心机制。Direct 不增加 K。历史结果和 N=10 Experiment 1 证书保持原样。

启动队列时记录 Git 提交、源码与数据 manifest 和源码快照。恢复要求对应阶段的科学配置、源码和数据匹配。运行期间源码保持冻结，避免把不同版本结果混在一个 study 中。

## 保存、错误与恢复

每完成一个独立 solver，保存完整 raw MAT、更新 study checkpoint，并同步 CSV。源码快照、原始输入、算法配置、seed、最终方案和五项成本都随结果保存。未完整配对的成功解仍保留在原始结果中，不能填造缺失成本。

无人值守阶段启用 `ContinueOnTaskError=true`。单个独立任务的运行错误会记录下来，继续其它任务。原 AHDE 偶发解码越界会被 wrapper 拦住；该次非法结果不作为可行成本发布，任务失败记录保留。输入、schema、模型/成本一致性或结果写入等全局问题则阻断队列，保存错误并报告，不继续生成不可信结果。

`complete` 表示相应计划全部成功。`completed_with_failures` 表示计划已执行，但仍有失败。`blocked_global_error` 表示全局一致性问题停止了队列。软窗口不足时可以出现 `not_started_insufficient_window` 或阶段被列入未启动清单。

当前 Queue 对已经处于 `completed_with_failures` 的 terminal 阶段不会自动重复执行。需要重试失败 slot 时，直接调用该阶段原 runner，提供相同科学配置和 `ResumeDir`，并设置 `RetryFailedTasks=true`。成功任务保持复用；重试成功后当前失败清除，历史错误标为 resolved。设置 `RetryFailedTasks=false` 可保留失败 slot 并继续其它尚未完成任务。

Exp3/4 主汇总使用完整配对 seed，协同收益中出现 coordinated TC 高于 fixed TC 会标为 `heuristic_search_insufficiency`，保留原值和负节约率。不能将异常裁剪成零或偷换为固定解。

## 返回后怎样阅读

从队列输出目录的 `REPORT.md` 开始，它给出阶段目录、实际预算、完成状态、profiling 入口和可读汇总。它是索引；科学证据仍在各阶段的 CSV/MAT 中。

- `live_progress.md` / `live_progress.json`：监视器根据当前 task CSV 更新的运行近况。预计剩余时间只是估算。
- `queue.mat` / `queue_state.json`：队列配置、选择理由、阶段状态、源码追踪、已提交任务数与阻断信息。
- `profiling_summary.csv`：真实单次 wall-clock；原 profiling 目录保存完整解。
- `task_status.csv`：每个计划 task 的 complete、failed 或 pending 状态。
- `failed_tasks.csv` / `errors.csv`：当前失败与历史错误，含重试是否解决。
- `raw_results.csv`：逐次成本、时间、实例与算法 seed；Exp3/4 还包含五项成本和配对完整性标志。
- `summary.csv`：对应阶段定义下的算法或策略汇总。Std/CV 需要足够重复次数，单 seed 不能提供稳定性结论。
- `convergence.csv`：预先统一口径的收敛数据；AHDE 没有真实逐代时间时留 NaN，不伪造时间轨迹。
- `study.mat` / `raw/*.mat`：完整输入、配置、seed、X/groups/T/f 或 T/K/F、成本、收敛和追踪信息。
- Exp3 的 `paired_comparison.csv`，Exp4 的 `paired_savings.csv`、`paired_summary.csv`、`anomalies.csv`：配对成本差、协同收益与异常。
- 扩展 Exp2 的 `task_provenance.csv`：哪些 task 被复用、来自哪个父目录。

读取时先检查状态和 task 数，再看科学配置、配对完整性和成本。不能仅看目录中文件数量就认定全部 task 成功。

## Preliminary 的结论边界

今天的运行用于获得可审计的初步结果、发现实现或搜索不足、判断预算和收敛是否合适。它不能直接替代最终的多实例、多种子正式 benchmark。

独立 benchmark instance 与算法 random seed 是不同实验轴；同一实例多 seed 只评价求解器的随机稳定性。N=30/50/100 结果称为最好可行值或 BKS，不能称为已证明全局最优。只有已有小规模网格精确证书支持相应网格上的全局最优声明。
