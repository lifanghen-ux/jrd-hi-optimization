# JRD-HI：2026-10-01 开跑审计与 preliminary 结果汇报

> 最新状态（2026-10-01 晚间读取）：后台于 **15:02:35 全部完成**。Exp2/3/4 共 **164 个独立求解，失败 0、待运行 0**，约 98 分钟；7 项 profiling 另计。没有启动论文最终 formal benchmark。

## 1. 负责人先读：目前能说什么

- Exp1 原有 N=10 网格精确证书和 5 seeds 证据保持冻结，没有重新执行长实验。
- Exp2 已完成 **108/108**：3 个规模 × 每规模 3 个独立实例 × 每实例 3 个算法 seeds × 4 个算法，失败 0。
- Exp3 已完成 **40/40**：N=10/30/50/100，各 5 seeds，Direct Evolutionary-X 对老师原 AHDE，失败 0。
- Exp4 已完成 **16/16**：4 个规模 × 1 seed × 4 个情形；预算为 500 generations、population=10N，失败 0。
- 最重要的算法发现：Evolutionary-X 比 GA/JADE 好，但本批中 **VND 成本更低且更稳定**。不能据此宣称新算法已全面领先。
- 最重要的策略发现：Exp3 的全部 20 个配对 seed 中 Direct 成本更低；这是指定求解器、当前预算、每规模一个固定实例下的可行成本结果，**不是两个策略全局最优值差的证明**。

本轮科学代码、实验配置与源码快照对应 Git `f8e9b9c302be7356da0054ca5fa29ece08e64928`。之后的 `a95ea806954b9eb2d43515261e31d49aac905a7a` 只修实时监视器终止阶段的剩余计数显示，没有修改 MATLAB 科学源码、模型或运行预算。文档更新提交也不代表求解器变化。

## 2. 实验前问题是否解决

| 原问题 | 本轮处理 | 状态/边界 |
|---|---|---|
| Exp2 混用 native 与 grid 目标 | 最终 partition 全部通过 `DirectGridPartitionCost` 得到 CommonGridTC；native 另存 | 已解决 |
| 收敛曲线目标不一致 | 保存 checkpoint partition，统一 CommonBestTC；时间横轴不伪装 VND generations | 已解决 |
| instance 与算法 seed 混淆 | 两个独立实验轴、固定派生规则与逐任务记录 | 已解决 |
| 缺少论文式性能输出 | Average Runtime、实例级 BestCount、同实例 BKS Average Gap、实例内 Std/CV、公共收敛图 | 已解决 |
| 旧 GA/JADE 变量不适合新的 Direct | 保留旧文件；正式比较增加只编码 Direct partition 的适配器 | 已解决；适配后的算法不是未经改动的旧 2N 染色体程序 |
| VND 与进化算法没有相同自然代数 | 共用成本评价，并按 P/G 预设评价 cap；4 starts、10 ILS | 已控制并披露；不是严格等计算工作量 |
| Exp3 错换主 Indirect 算法 | 主线仍为老师原 AHDE，stronger Indirect/block-K 仅 supplementary | 已解决 |
| Exp4 固定频率用了不同 AHDE 核心 | coordinated/fixed 都调用同一原 AHDE，fixed 只令 FInf=FSup=1 | 已解决；旧 AHDE_FixedF1 保留作补充 |
| Direct 固定频率是否换算法 | 同一 Evolutionary-X 实现，只改 f 可行域；四情形各自重新优化外层 | 已解决 |
| coordinated 比 fixed 更差被当成模型结果 | 保留真实结果，自动标记 heuristic_search_insufficiency/anomaly | 已解决 |
| 持续保存与关机恢复 | 每 task raw MAT + study checkpoint + CSV；原子保存、raw orphan 恢复、source/config guard | 测试通过；恢复限制见第 9 节 |
| 单任务失败停止整批 | 记录独立任务错误并继续；成本/输入/存储等全局一致性错误阻断 | 测试通过，本批目前未出现任务错误 |
| 耗时依赖纯理论推算 | 7 个参考配置真实串行 wall-clock，再用真实 12-task calibration 选择规模 | 已解决 |

### 自主工程决定及原因

1. **先用 G=100、P=4N 的完整 12-task calibration，再扩至 108**：保证多实例、多 seeds 的完整结果能在用户离线窗口内结束，而不是把 500/10N 当成未经测速的固定正式预算。扩展只增加实例/重复次数，不更改算法或目标；12 个匹配任务只读复用，不重复计为新实验。
2. **Direct 网格的等价投影与缓存**：对固定 f，代码中的组成本关于 T 为 A/T+B*T/2，连续极小点为 sqrt(2A/B)；在规定网格上检查该点的相邻网格点与边界即可得到同一离散网格最优值。不是改用连续 T；独立枚举测试验证数值等价。缓存/预处理避免每次组评价重复构建全量数据。
3. **不根据输赢调预算**：Exp2 四算法预先固定同一公共网格口径；Exp3/4 每阶段各情形采用预先固定的共同 P/G。不同算法/变量结构仍保留，不声称同 P/G 就严格等工作量。
4. **保守排程**：估计加 70% 耗时余量并保留 15 分钟汇报窗口。软截止只决定是否启动新阶段，不中断正在搜索的 solver，也不参与策略成本判优。

## 3. 实际执行批次、预算与耗时

| 阶段 | 计划/完成 | 科学配置 | 实际阶段 wall-clock |
|---|---:|---|---:|
| Exp2 calibration | 12/12 | G100、P4N、grid .001；1 instance/N、1 seed | 340.095 s，5.67 min |
| Exp2 扩展 | 108/108，含复用 12 | 同预算；3 instances/N、3 seeds/instance | 2768.859 s，46.15 min（新增 96 次及扩展导出） |
| Exp2 总计 | 108 个独立求解 | calibration + 扩展，不能把复用再计一次 | 3108.954 s，51.82 min |
| Exp3 | 40/40 | G100、P4N、grid .001；4N、5 seeds | 428.193 s，7.14 min |
| Exp4 | 16/16 | G500、P10N、grid .001；4N、1 seed | 2334.527 s，38.91 min |

队列从 13:24:34 到 15:02:35，实际约 98.02 分钟；逐阶段总 wall-clock 与队列总时间的少量差异来自阶段选择及队列保存等开销。12 个 calibration 结果已计入 Exp2 的 108，不能再将它们重复计入独立完成任务。

Exp2 数据种子与算法种子分别保存；`SFactor=0.3`，本批不跨 S/penalty 情景。Exp3/4 使用原 Data_N10/30/50/100：每规模仅一个固定输入，多 seeds 不等于多个独立数据实例。

### 12 / 36 / 108 的本机排程依据

同一 G100/P4N preliminary 预算：12 次整批真实用时 5.67 分钟；36 次按当时 calibration 外推约 17.00 分钟，含 ×1.7 余量约 28.91 分钟，**36 不是单独实跑整批**；108 次最终真实整批 51.82 分钟。不能把这些时间套用到 G500/P10N formal benchmark。

### 参考预算 profiling：真实单次，不是估计

机器为 Ryzen 7 8845H（8 物理核/16 逻辑线程）、约 29.8 GB RAM、MATLAB R2024a。参考 G500、P10N、grid .001，原输入、seed=20261001，串行执行。

| 算法 | N | wall-clock 秒 | 分钟 |
|---|---:|---:|---:|
| Evolutionary-X | 30 | 84.887 | 1.41 |
| Evolutionary-X | 50 | 189.348 | 3.16 |
| Evolutionary-X | 100 | 690.363 | 11.51 |
| GA Direct partition adapter | 100 | 324.118 | 5.40 |
| JADE Direct partition adapter | 100 | 1214.337 | 20.24 |
| VND common grid | 100 | 112.077 | 1.87 |
| Teacher original AHDE | 100 | 190.219 | 3.17 |

这是完整 solver call（含最终方案装配）的 wall-clock，不含 MATLAB 启动、输入加载、预热和写盘。VND 不是天然 P/G 算法，该配置对应预设组评价 cap。AHDE 原解析 T 不强行套 Direct 的 T 网格。

测速完整源码/输入证明保存在原 profiling 目录的 `profiling_source_provenance.mat`：求解器及实际调用依赖与开测 manifest 匹配；测试/runner 在后续审计中改过，不能谎称 profiling 测过最终仓库所有文件。

## 4. Exp2：新 Direct 算法性能的真实发现

下表 Gap 是同一 instance 上全算法、全 seeds 找到的 BKS 的百分比距离；不是离已知全局最优的距离。每行 3 独立实例 × 3 seeds = 9 次；BestCount 按实例计，分母 3。

| N | 算法 | 平均 CommonGridTC | 平均 Gap % | BestCount | 平均秒 |
|---|---|---:|---:|---:|---:|
| 30 | Evolutionary-X | 43393.20 | 1.454 | 1/3 | 7.17 |
| 30 | GA | 47905.73 | 11.964 | 0/3 | 4.63 |
| 30 | JADE | 56836.01 | 32.820 | 0/3 | 9.32 |
| 30 | VND | 42787.79 | 0.032 | 3/3 | 6.65 |
| 50 | Evolutionary-X | 80128.60 | 6.117 | 0/3 | 15.95 |
| 50 | GA | 95505.49 | 26.460 | 0/3 | 12.74 |
| 50 | JADE | 116793.78 | 54.719 | 0/3 | 25.06 |
| 50 | VND | 75616.60 | 0.164 | 3/3 | 13.24 |
| 100 | Evolutionary-X | 190488.74 | 12.048 | 0/3 | 50.74 |
| 100 | GA | 262421.38 | 54.363 | 0/3 | 54.94 |
| 100 | JADE | 311441.20 | 83.236 | 0/3 | 114.59 |
| 100 | VND | 171152.73 | 0.698 | 3/3 | 14.45 |

不同 instance 的均值 TC 是描述量；主要可比性能指标是实例内归一化 Gap、BestCount 与稳定性。Std/CV 在实例内按 seeds 计算，再跨实例平均，不能把数据差异混进算法随机稳定性。

27 个 Evo/VND 同实例、同 seed 配对：VND 26 胜、1 平，Evo 0 胜。Evo 平均成本相对 VND 高出 N30/50/100 分别 **1.415% / 5.967% / 11.298%**。VND 在全部 9 个实例中找到 BKS；Evo 仅在一个 N30 实例并列。

独立只读审计：108 条完整记录、13,501 个公共 checkpoint 全部非增，最终 checkpoint 与最终 TC 最大差 1.02e-10，五项成本求和误差最大 8.15e-10；BKS/Gap/计数/均值/Std/CV/时间均独立重算匹配。12 个任务复用 provenance 保留，源码快照与 manifest 匹配。

**结论**：公共评价与结果管线已可用，Evo 对 GA/JADE 有 preliminary 优势，但尚不能支持其优于代表性 VND。下一步应预先设计“纯 Evo / Evo+结构局部改进 / VND”的消融和新实例验证，而不是隐去 VND、增大 penalty 或把本批已运行代码替换后仍当同一结果。

完整稳定性表及核验细节见 `Docs/EXP2_PRELIMINARY_108_AUDIT_2026-10-01.md`。

## 5. Exp3：Direct 与老师原 AHDE Indirect

Saving(best) = 100 × (IndirectBestTC−DirectBestTC) / IndirectBestTC；Mean paired saving 先按每个完整 seed 配对计算，再平均，两者不能混用。

| N | Direct 最好可行 TC | Indirect 最好可行 TC | Saving(best) % | 平均配对 Saving % |
|---|---:|---:|---:|---:|
| 10 | 12059.26 | 13112.33 | 8.031 | 8.510 |
| 30 | 46734.36 | 63856.28 | 26.813 | 26.633 |
| 50 | 79143.93 | 112213.06 | 29.470 | 28.623 |
| 100 | 168041.85 | 248519.90 | 32.383 | 31.011 |

全部 20 个配对 seed 中 Direct 较低。两侧均 G100/P4N，但 AHDE 与 Evo 的搜索操作、变量结构、实际评价成本不同；这不是严格等工作量或相同随机轨迹的实验。N100 平均 solver 秒约为 Direct 49.39、Indirect 7.27。

此时可以汇报“本批固定实例、指定求解器及预算下 Direct 找到更低成本”，不能写成“已经证明 Direct 全局最优成本在所有实例低于 Indirect”。stronger Indirect / block-K 仍需要补充验证以检查原 AHDE 是否低估了 Indirect 可达质量。

收敛审计还发现，20 次 AHDE pilot 的最后改善均发生在第 93–100 代，最后 20 代仍改善约 1.04%–4.77%。所以 **G100 不是充分收敛证据**。此前考虑的“Exp3 G500/P10N、3 seeds 独立补充批次”没有启动：会话额度中断了后续人工编排，但已启动的后台队列不受影响并完整结束。该补充批次不能计入结果，也不能把 Exp4 的单 seed 直接当作它已完成。现已超过原离线窗口，本次不自动再开长跑。

对应可选启动脚本 `Paper_Experiments/Start_JRD_Reference_Exp3.ps1` 已准备，PowerShell 5.1/7 语法及 DryRun 通过，DryRun 的 MATLAB PID 均为空、实际 solver 次数为 0。它尚未实际运行验证 hidden worker 的整批生命周期，不能把这些准备目录视为实验结果；原 MATLAB 科学源码不受影响。

## 6. Exp4：协同配送与固定频率

全部 16 次完成。Saving = 100 × (fixed TC−coordinated TC)/fixed TC。各情形都重新优化外层变量，不是把同一最终解的频率直接改为 1 后计分。

| N | 策略 | coordinated TC | fixed f/F=1 TC | 协同 Saving % |
|---|---|---:|---:|---:|
| 10 | Direct | 12059.26 | 12432.92 | 3.005 |
| 10 | Indirect | 12578.21 | 13151.89 | 4.362 |
| 30 | Direct | 46819.98 | 49098.62 | 4.641 |
| 30 | Indirect | 58635.54 | 62669.77 | 6.437 |
| 50 | Direct | 78494.15 | 83112.37 | 5.557 |
| 50 | Indirect | 106076.70 | 114086.86 | 7.021 |
| 100 | Direct | 159852.05 | 170408.81 | 6.195 |
| 100 | Indirect | 235386.50 | 252897.98 | 6.924 |

8 个配对均未发现 coordinated 高于 fixed 的 nesting violation，anomaly=0。它们只是单 seed 初步可行解，不提供 Std/CV 或稳定性结论；CSV 中单配对标准差为 NaN 是正确表示，不填零伪造稳定性。

完整结果只读审计通过：16 个 raw 和完整方案均齐全，从原输入独立重算五项成本与 TC 最大误差 1.46e-11；8 个 fixed 最终方案的频率全部严格为 1。原 AHDE fixed 的 500 代 checkpoint 共 95,000 个 F 值全部为 1；源码/数据 manifest 与当前文件一致，原 AHDE 未变。详见 `Docs/EXP3_EXP4_PRELIMINARY_RESULTS_AUDIT_2026-10-01.md`。

Indirect 两情形均为原 AHDE，fixed 仅 FInf=FSup=1；Direct 两情形为同一 Evolutionary-X，仅 f 可行域变化。Exp4 的 500/10N 比 Exp3 pilot 更强、seed 数又更少，所以不能跨实验拼接 TC 来制造一个“统一预算的策略比较表”。

补充可追踪的预算响应观察：Exp4 coordinated 的算法 seed 恰对应各 N 的 Exp3 run2，输入/源码也相同。该预先固定 seed 下，预算由 G100/P4N 增至 G500/P10N，AHDE 在 N10/30/50/100 的 TC 分别下降约 5.70%/8.18%/6.04%/5.90%，Direct 分别下降 0%/1.64%/3.72%/6.37%。这说明两侧搜索质量都受预算影响；单个匹配 seed 不能替代多 seed 正式预算响应实验。Exp4 部分 AHDE 仍在第 481–500 代改善，因此连 500 代也不能被称作已证明充分收敛。

## 7. 测试和保护边界

最终完整门禁目录 `Validation_Preliminary/tp3795fc51_b18b_4252_87f1_a9f41ebc74d0/`：

| 测试 | 状态 | 秒 |
|---|---|---:|
| 全 legacy 数学/求解/存储 | PASS | 30.770 |
| completed-search / block-K / resume | PASS | 27.765 |
| 新主线数学等价性 | PASS | 1.144 |
| Exp2/3/4 smoke、公共收敛、五成本、resume | PASS | 28.156 |
| Unattended queue 额外测试 | PASS | 3.204 |

测试包含暂停/续跑、不重算已完成任务、raw orphan 恢复、参数或源码不匹配拒绝、失败后继续及重试、统一公共 checkpoint、原 AHDE 同 seed 重现、Fixed F 每代严格为 1。真实队列采用同一最终门禁科学源码。

明确没有修改：原 Data_N*.mat、成本模型、penalty 数值/生成逻辑、Direct 跨 group penalty=0、按 group replenishment event 收 S 的现有规则、Direct 不含 K、Indirect T/K/F、老师原 AHDE 搜索机制，以及历史实验结果。

Exp1 冻结证书：网格精确 TC=12059.2627236542；已有 5/5 seeds 命中。连续精确值 12059.2516110867 单独保留，不能与 grid certificate 混称同一精度证书。

## 8. 仍需老师确认的模型定义及实验风险

1. Direct 独立 group 在实际时间上相遇时是否仍无跨组 penalty，以及 S 是否按每个 group 事件独立收费。这是模型语义问题，本轮不改。
2. 大规模均为最好可行解/BKS，不是全局最优证书；不同求解器可能改变找到的策略成本差。
3. Exp2 仅 3 instances/N、单个 SFactor=.3；Exp3/4 每 N 一个原实例。正式论文仍需独立实例和多 seeds。
4. 仓库 sr/sw 采样 .10–.38 与论文 .10–.30 有区别；本轮保留已有生成逻辑并披露，不声称完全复刻论文数据分布。
5. AHDE floor 编码在连续值恰到上界可能越界；本轮只检测/记录失败，不改其核心或把非法解裁剪后当合法结果。
6. 同 P/G 不等于严格等评价数或等 CPU 工作量。runtime 是算法性能指标和排程依据，不是 Direct/Indirect 策略优劣的定义。

论文 §5.1、表3/图6 的多实例、BestCount、Average Gap、Average Runtime 性能逻辑已继承，未机械把旧 2N 决策变量加到 Direct。老师论文的 Lipschitz EV 与本仓库 AHDE 不是同一个算法，不能把 EV 的几秒时间当作 AHDE 参考时间。

## 9. 如何查看、保存与恢复

本批总目录：

```text
Results_Unattended/Launch_20261001_132424_516_5c284a72/
  launch.json / stdout.log / stderr.log
  queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/
    REPORT.md                    自动结果索引
    queue.mat / queue_state.json 配置、选择理由、source、阶段状态
    profiling_summary.csv        7 个真实测速结果
    live_progress.md/.json       已完成、失败、剩余估计（不是事实时间）
    Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815/
    Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/
    Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/
```

各阶段首先看 task_status.csv 与 failed_tasks.csv，再看 summary.csv。Exp2 看 instance_summary.csv、performance_panels.png、common_convergence.png；Exp3 看 comparison.csv、paired_comparison.csv；Exp4 看 paired_summary.csv、paired_savings.csv、anomalies.csv。

逐次 TC/五成本/时间/instance/seed 在 raw_results.csv；完整输入和方案、参数、收敛与源码在 study.mat 及 raw/*.mat，变量名为 Study。Exp2 的 task_provenance.csv 区分 12 个复用任务与 96 个新任务。Raw MAT 每任务提交，不依赖整批最后一次写盘。

恢复要求保留原科学源码与参数。队列软截止后、或 terminal 阶段有失败需重试时，直接使用对应实验 runner 的 ResumeDir 和原 BudgetArguments，必要时 RetryFailedTasks=true；不要以修改 deadline/参数/源文件的方式绕过配置匹配，也不要另起“同名”结果覆盖历史。原 study/raw 保留即可恢复已完成结果。

恢复粒度是一整次 solver call，并不是 AHDE/GA/JADE 的中间 generation。源文件匹配包括已追踪的测试 .m；以后改代码仍需从原提交的独立 worktree 恢复旧实验。队列级的 terminal 失败阶段不会自动重试，单 runner 补跑后也不会自动改写旧 queue 的阶段计数。这些限制不影响本次已全部成功的结果，但必须与“随时从中间代续算”区分。

## 10. 下一步建议及给老师的简洁汇报

优先顺序：

1. 先讨论新 Evo 在 Exp2 明显弱于 VND，预先确定结构局部改进消融与 held-out 新实例，而不是马上扩 formal 次数。
2. 使用更高预算及 stronger Indirect / block-K 对原 AHDE 做稳健性检查，仍不替换论文主算法。
3. 确认 Direct 的 S 与跨组 penalty 模型定义；固定正式数据轴、预算、seed 数和统计口径后再启动 formal。
4. Exp4 增加 seeds 和实例，检查协同搜索异常及重复性。

可用汇报语言：

> 已完成最新主线的工程审计，统一了 Direct 算法性能比较的目标函数和收敛口径，保留老师原 AHDE 作为 Indirect 主算法，并将固定配送频率实验改为同一求解器仅限制频率。全部单元与烟雾/恢复测试通过。今天已完成 108 次多实例 Direct 性能 preliminary、40 次两策略比较和 16 次协同配送比较，零失败。新 Evolutionary-X 明显优于 GA/JADE，但目前仍弱于 VND；固定实例上 Direct 找到的成本低于原 AHDE Indirect，协同配送也找到更低成本，但尚不能作为全局策略优劣证明。下一步优先改进并验证 Evo 搜索质量、补做 Indirect 更充分预算及稳健性验证，再锁定正式实验。
