# JRD-HI 开跑前最终审计

日期：2026-10-01。范围：修订实验 2/3/4、全套回归测试、最小管线实验、真实参考预算测速。实验 1 冻结。用户随后授权下午自动开展能完整结束的 preliminary；不自动运行论文 final formal benchmark。

## 1. 当前结论

代码与实验输出的必要工程修订已完成，最终全套 MATLAB R2024a 测试及无人值守门禁通过。新增的逐任务错误隔离、12→36/108复用和报告已验证。7项真实参考预算测速已完成，实测表见第6节。已满足开始preliminary的工程条件；不等于新算法性能或Direct策略优势得到正式统计证明。

## 2. 对上一份审计问题逐项闭环

| 原问题 | 处理结果及证据范围 |
|---|---|
| Direct/Indirect 模型定义依据，跨组 penalty、按组 S | 仅列风险，未改模型。需要老师确认，不能用工程修复替代定义。 |
| 离散 T 投影与字面枚举是否一致 | 独立公式穷举、周期边界、全部小规模非空子集验证通过；保留 enumerate。投影只是凸函数网格最低点的等价计算，不把输出 T 改成连续值。 |
| 新 Direct 标签、初始化、交叉/变异的组数倾向 | 规范标签和非空组仍成立；不同初始化/算子是新算法自身特征。是否提高成功率需后续多实例/多 seed 及预先固定的算法消融，不在本轮声称已证明。 |
| Exp2 原生目标与公共终点目标不同 | 正式 GA/JADE partition adapters、VND 和 Evolutionary-X 搜索过程全部用同一网格 evaluator；原历史原生搜索保留、单列，不混入正式指标。 |
| convergence 原生/网格混杂 | 四算法保存 checkpoint partition 与 CommonBestTC，独立重算全部测试 checkpoint；VND 不虚构代数。公共 CSV 与收敛图已输出。 |
| 同种群/代数误称完全等预算、VND 随 Direct 结果动态分配预算 | 预先固定 VND starts/ILS/未缓存组评价上限，取消依赖 Direct 实测计数。保存实际工作计数和时间；明确相同外层层级不等于同工作量。 |
| benchmark instance 与 algorithm seed 混淆 | Exp2 独立 InstanceSeed 和 AlgorithmSeed，保存每个实例及生成元数据。Exp3/4 明确当前每 N 只有一个冻结实例，不把多个 seed 称多个实例。 |
| 缺表3/图6式指标、稳定性、统一图 | AverageRuntime、BestCount、AverageGap、实例内 Std/CV、公共 Convergence 和 PNG/FIG 已实现。每实例 reference 是四算法全部 seed 最低 CommonGridTC，非全局证书。 |
| Direct 内层更充分可能低估 Indirect | 保持老师原 AHDE 主比较，披露不同变量结构/内部工作。已有 stronger Indirect / block-K 定位 supplementary；后续正式结论仍须稳健性检验，未擅自替换 AHDE。 |
| Exp4 AHDE_FixedF1 不只固定频率 | 主实验两情形现在均调用原 AHDE，仅 FixedF 情形的 FInf=FSup=1。N维版本只作 supplementary。 |
| Exp4 缺协同可行集 sanity | 两策略四情形各自重新优化；coordinated>fixed 标 heuristic_search_insufficiency，保存负 saving 和原解，不覆盖或偷偷注入 fixed 解。 |
| Exp4 缺五项 summary/diagnostics、完整方案 | TC、runtime、配对 saving、Std/CV、五项 costs、diagnostics、逐商品 solution、完整 MAT 均输出。 |
| 中途保存/partial seed 恢复未测 | 原子 raw 和 study、每 solver 边界保存、raw提交但study丢项恢复、配置变更拒绝及完整 resume 不重算已通过故障注入测试。算法调用内部未完成部分按原 seed 重算，不宣称逐代恢复原 AHDE。 |
| 正式预算未实测、大规模正式证据未完成 | 支持 pilot / paper-reference；执行 500代/10N/.001 真正测速。按最新授权在实测后自动选完整12/36/108 preliminary；formal预算仍未锁定，不把smoke/profile当论文证明。 |

## 3. 本轮代码与自主决定

### 实验 2

- `RunCommonDirectBaseline.m`：GA/JADE 保留原搜索算子，使用 N 个有效连续分组标签坐标；T/f 由共同 evaluator 优化。明确命名为 partition adapters，不声称原历史 2N 代码原样复现。理由：新 Direct 主问题只搜索 X，不应该让部分正式 baseline 额外承担已被共同内层消去的频率坐标。
- `CommonGridVNDCostCache.m`：保留旧结构邻域，换同一网格组成本。预算默认 P*(G+1) 个未缓存组评价、4 starts、每 start 10 ILS，属于预先固定参考，不是严格等工作量或已验证最优参数。
- `GeneratePaperBenchmarkInstance.m`：新内存实例，需求/成本/penalty 抽样规则沿用仓库，原 Data 不动。SFactor 是显式实例场景；默认 .3，参考场景 .1–.5，不改变模型函数。
- `Run_Paper_Experiment2_DirectPerformance.m`：schema2；多实例和多 seed 分开；BKS/gap、实例内稳定性、原子记录及恢复；最终 partition 统一重算；保存 search/postprocess/validation/write 耗时。
- `Plot_Paper_Experiment2.m`：平均时间、BestCount、AverageGap 三面板；多实例收敛使用每实例最终 BKS 的百分比 gap，不混合不同实例绝对成本。首次 checkpoint 前不虚构值，停止后保留最终最好值，横轴为实测搜索时间。
- `RunLegacyDirectBaseline.m`：历史 native 及公共后处理保留，增加非主指标标识。

所有正式 TC 与 CommonBestTC 均使用 DirectGridPartitionCost。NativeContinuousTC 是“同一最终 X 的连续 T 重优化辅助值”，不是历史原生成本，更不是另一项主指标。历史 NativeTotalCost 单独保留。

### 实验 3/4

- `RunTeacherAHDE.m`：coordinated/fixed 同一原 AHDE，固定只改变 F 边界；保存 2N 维结构、实际边界、评价数、完整逐代 T/K/F、重算和约束断言。
- `Run_Paper_Experiment3_StrategyComparison.m`、`Run_Paper_Experiment4_Coordination.m`：单 solver 边界保存、配对输出、参考预算/随机性说明、schema2、MaxNewSolves 故障模拟。
- `PaperStrategyOutputs.m`：五项成本/汇总/配对差/节约率/完整方案/收敛统一导出。
- `PaperCoordinationSanity.m`：理论可行域嵌套异常标记，容差相对 1e-9。
- `SavePaperStrategyRecord.m`、`RecoverPaperStrategyRecord.m`：原子记录与 raw-only 恢复。
- `AHDE_FixedF1.m`：仅修改用途注释，核心实现保留 supplementary，不进入主结论。

### 共同效率、验证与隔离

- `DirectGridGroupKernel.m`、`DirectGridGroupCost.m`、`DirectGridCostCache.m`：规范化只在公共入口/缓存创建时执行，避免每 cache miss 重建全数据。保留原系数、网格和五项公式；独立 kernel/public/cache 严格相等测试通过。
- `DirectGridPartitionCost.m`：可选 fitness 模式省掉整套方案装配，使用同一个组核；完整/轻量 TC 严格相等。
- `EvolutionaryX_Direct.m`：采用轻量评价、保存每代 best partition/CommonBestTC；没有改变初始化、交叉、变异、精英强化与变量结构。计时包含最终完整解装配。
- `Run_Preliminary_Audit_Tests.m`、`Test_Preliminary_Readiness.m`：隔离新测试目录、冻结原件 SHA256、完整 smoke/resume 门禁。旧测试只增加可选输出目录，避免覆盖历史验证文件。
- `Profile_Paper_Solvers.m`：串行真实测速、微型同实现 warm-up、增量结果与完整 solution 保存；不以时间终止、不自动接正式实验。
- `.gitignore`、`PAPER_MAINLINE.md`：新区结果隔离和最新入口说明。

测试过程中修复了测试入口路径/静态 evalc 变量问题，以及 Exp2 nested export 覆盖 parent answer 的管线缺陷。最终整套测试重新执行并全部通过，而非只修文字说明。

## 4. 明确没有修改的内容

Direct 跨 group penalty 仍按原实现为 0；S 仍按每 group replenishment event 分别收费；Direct 没有 K；Indirect 仍为 T/K/F；原模型函数、原 Data_N10/30/50/100、penalty 值和采样法、老师原 AHDE 核心均不变。N10 冻结证书/5 seeds 文件哈希保持不变，未调用 Experiment1 runner。

仍应向老师确认：独立组在时间上相遇是否产生跨组 penalty，以及按组 S 的事件定义。策略比较用不同求解器，不能把找到的可行解差直接写成两个模型的全局最优值差。

原 AHDE 连续坐标恰为 1 时 floor 可能得到整数上界+1。本轮只用断言暴露异常，不改解码/越界修复、不裁剪方案。固定 F=1 测试没有触发这一边界问题。

仓库生成器的 sr/sw 范围 .10–.38 与论文表2 .10–.30 不一致；本轮保留仓库生成逻辑，只披露差异，不能称逐项完全复刻论文数据分布。

## 5. 完整 MATLAB 测试结果

最终成功验证目录：

```text
Validation_Preliminary/tp0cff252d_c329_4b72_9794_946dba174141/
  audit_tests.mat                 变量名 Study，完整门禁报告/源码与保护文件hash
  legacy_all.txt                  全旧数学/搜索/存储测试日志
  completed_search.txt            完成策略/block-K/恢复测试日志
  paper_revision.txt              新主线数学测试日志
  preliminary_readiness.txt       Exp2/3/4 smoke/resume日志
  legacy/                         完整旧测试报告
  paper/                          新主线数学报告
  preliminary/...                 新门禁和smoke CSV/MAT/PNG/FIG
```

| 测试套件 | 状态 | 实测秒 |
|---|---|---:|
| Test_JRD_All | PASS | 30.886 |
| Test_JRD_Completion | PASS | 27.041 |
| Test_Paper_Revision | PASS | 1.084 |
| Test_Preliminary_Readiness | PASS | 17.385 |

- 投影与完整枚举最大差约 1.819e-12；独立小模型穷举最大差约 2.274e-13。
- Exp2：2 个独立实例 × 2 算法 seeds × 4 算法 = 16 条 smoke solver 记录；公共终点、所有 checkpoint、BKS/gap、实例内 Std/CV、图保存通过。
- Exp3：2 条；Exp4：4 条；全部五项成本与 TC 一致，完整逐商品方案及 CSV/MAT 保存通过。
- Exp4 原 AHDE 固定 F 的最终及每一代 F 全为严格整数 1；wrapper 与同 seed 原 AHDE 直接调用逐项重现。
- 三 runner：半个 seed 后暂停续跑、完整 resume 不重算、raw已提交而study丢项恢复、变更预算拒绝通过。
- smoke 中 Indirect coordinated TC 高于 fixed TC 的异常已如实输出，不隐藏、不当作模型协同负收益证明。
- PNG 图经视觉检查能正常读取；其 N10 微预算数值仅用来测试管线，不属于冻结 Experiment1，不构成性能/策略结论。

## 6. 真实 wall-clock profiling

最终开跑门禁于13:22:33完成，保存于 `Validation_Preliminary/tp3795fc51_b18b_4252_87f1_a9f41ebc74d0/`：legacy_all 30.770s、completed_search 27.765s、paper_revision 1.144s、preliminary_readiness 28.156s，全部PASS；额外 `Test_Unattended_Queue` 3.204s PASS（synthetic及真实已完成profile仅DryRun，执行solver任务0）。验证包括逐任务失败后继续、失败重试不重算成功任务、扩展只读复用、AHDE同实现固定F、公共全部checkpoint及五成本、存储/resume。Windows PowerShell5/7 parser通过，监视器在真实DryRun目录执行成功。

保留了失败测试目录作为开发轨迹：一处是匿名error注入被请求返回值触发MATLAB:maxlhs，已改为声明输出的测试helper；另一处是PS5按ANSI解码无BOM中文脚本，监视器源改ASCII兼容。二者均为测试/运行工程问题，未改成本或solver。收敛曲线固定平均cohort避免人为上跳，短轴标题避免裁切。

机器：AMD Ryzen 7 8845H，8物理核/16逻辑线程，约29.8GB内存，Windows，MATLAB R2024a。每个 job 串行执行，不并发争用 CPU；一次独立 seed=20261001，原冻结 Data_N*.mat。

参考：Generations=500、Population=10N、GridStep=.001；Evolutionary-X 使用等价 grid projection，并非连续 T 放宽。VND 无种群/代数运算，采用同参考 P/G 派生的预设组评价 cap，4 starts/10 ILS。AHDE 仍原版，T 为它自己的原解析 T，不强加 Direct 网格。

外部 tic/toc 记录整个 solver call（含最后解装配/一致性处理）；不含输入加载、微型warm-up、磁盘保存和 MATLAB 启动。所有完整 solution 和源码/输入 SHA 保存在：

```text
Results_Profiling/tp6c56a870_ff62_4eb7_81d4_6a49d9f6fc62/
  profile.mat    变量名 Study，参数/源码hash/当前job/逐job记录
  timings.csv    真实计时汇总
  raw/*.mat      变量名 Study，单job完整 record/Solution
```

7项测速于13:12前全部完成。真实wall-clock：

|算法|N|秒|分钟|
|---|---:|---:|---:|
|Evolutionary-X|30|84.887|1.41|
|Evolutionary-X|50|189.348|3.16|
|Evolutionary-X|100|690.363|11.51|
|GA partition adapter|100|324.118|5.40|
|JADE partition adapter|100|1214.337|20.24|
|VND common grid|100|112.077|1.87|
|Teacher original AHDE|100|190.219|3.17|

测速不是性能实验：同一N100冻结实例上，VND TC=153826.46，比Evolutionary-X的160991.86低；该现象必须如实报告，不因目标是新算法就隐藏。JADE的247384.77明显偏高，是否是连续标签搜索的结构性问题需多实例实验判断，不能仅凭一次测量宣称因果。

当前不得将这些500/10N单次时间线性称为12/36/108的准确实测总时间：部分baseline只测N100，生成实例/缓存命中也会变化。先实际完成G100/P4N的12条pilot，用整批实测（包含结果导出）估计同预算36/108，预计范围、已完成/失败数持续记录在queue的REPORT/live_progress。不能用一个seed的TC证明大规模算法优越性。

## 7. 论文参考与下一步边界

依据本地王思睿等2024论文 §5.1、表3、图6（印刷页223–224，PDF第6–7页）：4种 n × 5种 S比例 × 20独立实例 = 400；参考500代/10N；BestCount和gap以全部比较算法找到的最好值定义。论文约3.3秒的算法是 Lipschitz EV，不是仓库这份原 AHDE；论文 AHDE N100约132–135秒，不能直接把EV时间当老师AHDE时间来比较。

当前正式主线仍是 Direct新Evolutionary-X vs Indirect原AHDE；block-K/completed-search/stronger Indirect 为稳健性补充；连续/网格ExactDP为小规模 correctness；等时间历史结果不移植为新主结论。

后续顺序：先以预先固定的短预算做多实例、多seed preliminary，检查收敛/稳定性/异常；再锁定正式预算；再运行大规模性能、策略/协同及 stronger Indirect 稳健性。时间仅用于性能/排程，不用于策略成本优劣判断。

最新授权：完成测速和最终回归后自动启动 `Run_Unattended_Preliminary_Queue`。先G100/P4N/.001完整12-run校准；只有全部12条成功，才根据本机整批实际耗时×1.7判断是否以相同预算扩成36/108（已完成任务只读复用）。Exp3/4优先参考500/10N预算，不能可靠fit时可用双方共同pilot预算，分别选择3/5或1–3seeds。软截止16:50只判断能否启动新的完整阶段，不打断任何成本求解。详见 `UNATTENDED_PRELIMINARY_2026-10-01.md`；最终结果入口是每个queue目录的 `REPORT.md`、`live_progress.md` 及逐阶段CSV/MAT。

## 8. 当天下午实际完成结果（晚间更新）

后台队列于2026-10-01 15:02:35完整结束，164个独立solver任务成功、0失败、0待运行，约98分钟。Exp2的12条calibration只读复用到108条扩展，不能重复计数。

- Exp2：108/108，G100/P4N/.001，3独立instances/N × 3 seeds × 4算法。公共13,501 checkpoint均非增，终点匹配；Evo优于GA/JADE，但VND对Evo为26胜1平，不能宣称新Evo全面领先。
- Exp3：40/40，G100/P4N，4N×5 seeds×2策略，20完整paired均Direct更低。AHDE最后20代仍普遍改善，pilot不能称充分收敛，也不能当全局策略证明。
- Exp4：16/16，G500/P10N，4N×1seed×4情形；8paired协同找到更低成本，anomaly=0。fixed最终及原AHDE全部500代F均严格1，五成本独立重算通过。
- 7项reference profiling全部完成。未自动启动formal；考虑的额外Exp3 reference3seeds尚未启动，其launcher仅语法/DryRun验证，不能当作已跑实验。

可直接给负责人/老师阅读的完整结果、真实用时与下一步风险见 `PRELIMINARY_EVENING_REPORT_2026-10-01.md`，逐项数据核验见 `EXP2_PRELIMINARY_108_AUDIT_2026-10-01.md` 与 `EXP3_EXP4_PRELIMINARY_RESULTS_AUDIT_2026-10-01.md`。旧章节保留作为开跑前审计轨迹，不将后来完成的结果冒写为开跑前已知。
