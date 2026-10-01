# JRD-HI：会议要求、四项实验设计与代码进度——供 ChatGPT 审核

整理日期：2026-09-30。实现版本：Git 分支 `codex/paper-evolutionary`，提交 `989e229a82c2eed245ca09c14fa4182e82926f68`。

本文可单独上传给 ChatGPT。它区分老师要求、实现者的设计决定、已有证据和尚未完成的工作。本文依据用户在本任务中转述的最新会议要求，未取得独立会议录音或逐字纪要；不能把下文的工程选择当作老师原话。

## 1. 请审核者先了解的结论

研究目标仍是比较 JRD-HI 中 Direct 与 Indirect 两种策略可达到的最低总成本。会议后主求解器确定为：Direct 使用新 evolutionary-X 分组算法，Indirect 使用老师原始 AHDE。

四项实验代码已实现，并通过基本 MATLAB 执行与结果保存测试。N=10 已完成 5 个种子的网格精确验证；N=30/50/100 的正式多种子算法性能、策略比较和配送协同实验尚未运行。目前不能声称大规模算法优越性或策略优越性已经得到正式证实。

请重点审核：模型解释是否成立、Direct 网格求解是否符合老师意图、实验 2 baseline 与预算是否合理、实验 3 是否会因 Indirect 搜索不足产生倾斜、实验 4 固定 F=1 的 AHDE 是否需要进一步统一实现。

## 2. 用户转述的老师最新要求

### 2.1 Direct 必须重新设计主算法

Direct 的决策结构为：

\[
X/\{G_k\},\quad T_k,\quad f_k.
\]

Direct 不存在商品补货倍数 K_i。

老师要求外层采用进化编码搜索商品分组 X；给定一个分组后，计算各组 T_k、f_k。T_k 按离散网格取值，例如 0.001、0.002……；给定 T_k 后寻找最佳 f_k。细化 T 网格应使目标值逼近最优。再把该分组总成本交回外层继续进化。

已有 Direct VND/ILS、ExactDP、解析 T 不删除，允许用作基准、正确性验证或辅助工具。新的 evolutionary-X 方法成为 Direct 主算法。

### 2.2 Indirect 主实验使用老师 AHDE

Indirect 的决策结构为：

T,\quad K_i,\quad F_i.

主比较调用仓库中的老师 `AHDE.m`。已有 Indirect VND、completed-search、block-K 消融保留，用作补充稳健性分析及检查 AHDE 是否低估 Indirect，不替代主比较中的 AHDE。

### 2.3 四类实验

1. N=10 小规模可复现验证：完整保存输入、参数、seed、最终方案、周期、配送频率和成本；用精确结果检查新 Direct。
2. N=30/50/100 大规模 Direct 算法性能：报告目标值、时间、稳定性、收敛和代表算法对比。
3. Direct 与 Indirect 完整策略比较：新 evolutionary-X Direct 对老师 AHDE Indirect。
4. 配送协同价值：Direct 和 Indirect 各自比较可优化 f/F 与固定 f/F=1。

### 2.4 项目边界和公平性原则

- 不改原始成本模型、原始 Data_N*.mat，不放大 Penalty。
- 不给 Direct 添加 K_i，不删除老师原 AHDE，不覆盖历史结果。
- 时间用于报告算法性能，不参与策略成本判优，也不作为新主算法的主终止条件。
- 两侧统一搜索层级，保留变量结构差异，不追求完全对称。
- 尽量控制求解器、随机性、计算预算对成本比较的影响。
- 大规模启发式最好解不能写成已证明的全局最优。

## 3. 成本模型与符号

N 为商品数；D_i 为需求率；S 为主订货启动成本；s_i^w 为商品次要订货成本；s_i^r 为配送成本；h_i^w、h_i^r 分别为中心仓与零售端持有成本；p_ij 为异质品同时补货 penalty。

实现沿用正上三角 penalty 约定：对 i<j，只计 p_ij>0，不重复计算对称项。数据规范化只建立内存副本。

### 3.1 Direct

X 是全部商品的分区，G_k 是其中一个非空组。各组有独立周期 T_k 和共享配送频率 f_k。

\[
C_o=\sum_k\frac{S+\sum_{i\in G_k}s_i^w}{T_k},
\]

\[
C_d=\sum_k\frac{f_k\sum_{i\in G_k}s_i^r}{T_k},
\]

\[
C_{hw}=\sum_k\sum_{i\in G_k}\frac{(f_k-1)T_kD_ih_i^w}{2f_k},\qquad
C_{hr}=\sum_k\sum_{i\in G_k}\frac{T_kD_ih_i^r}{2f_k},
\]

\[
C_p=\sum_k\frac{\sum_{i<j,\ i,j\in G_k}\max(p_{ij},0)}{T_k}.
\]

TC 为上述五项之和。按组整理：

\[
A_k(f)=S+\sum_{i\in G_k}s_i^w+f\sum_{i\in G_k}s_i^r+
\sum_{i<j,\ i,j\in G_k}\max(p_{ij},0),
\]

\[
B_k(f)=\sum_{i\in G_k}D_i\left(h_i^w+\frac{h_i^r-h_i^w}{f}\right),\quad
TC_k(T,f)=\frac{A_k(f)}{T}+\frac{B_k(f)T}{2}.
\]

需要模型审核：当前 Direct 只计算同组 penalty，跨组视为隔离，S 按每个组的补货事件收费。这一假设沿用已有 Direct 代码；仍需老师确认独立组即使时间上相遇，是否也应被视为独立事件及不产生跨组 penalty。代码延续不能代替模型依据。

### 3.2 Indirect

商品 i 的实际补货周期为 K_iT，公共基本周期为 T。

\[
C_o=\frac{S}{T}+\sum_i\frac{s_i^w}{K_iT},\quad
C_d=\sum_i\frac{F_is_i^r}{K_iT},
\]

\[
C_{hw}=\sum_i\frac{(F_i-1)K_iTD_ih_i^w}{2F_i},\quad
C_{hr}=\sum_i\frac{K_iTD_ih_i^r}{2F_i},
\]

\[
C_p=\sum_{i<j}\frac{\max(p_{ij},0)}{\operatorname{lcm}(K_i,K_j)T}.
\]

LCM 为最小公倍数：若 K_i=2、K_j=3，两种商品每 6T 同时补货。固定 K、F 时，老师 AHDE 用解析式 T*=sqrt(2A/B) 计算最佳公共 T。

默认 K、F/f 整数范围为 1…20，实际以数据及配置为准。

## 4. 实现者选择的新 Direct 方案

以下是工程选择，不是老师逐项指定的要求。

1. 长度 N 的整数染色体只表示商品所属组。标签按首次出现顺序规范化，例如 [7,7,3] 转为 [1,1,2]。标签置换不会重复表示同一分区；不存在空组频率位。
2. 初始化包括全部一组、全部单独成组、确定性贪心、随机贪心、不同组数的随机分区。
3. 锦标赛选择；交叉保留实际商品组块；变异包含搬移、合并、拆分、跨组交换。
4. 精英保留，并对部分精英进行少量随机邻域强化。
5. 所有候选分区使用相同网格组成本评价；商品子集缓存绑定一份数据和一套参数。
6. 按预设代数终止，可选停滞代数；不按运行时间终止。

调用链：

```text
EvolutionaryX_Direct
  → NormalizeJRDData / DirectEvolutionOptions
  → 初始化、选择、交叉、变异、精英强化
  → DirectGridPartitionCost
      → DirectGridCostCache.Get
          → DirectGridGroupCost
  → 最终 Groups / GroupT / GroupF / 五项成本 / Convergence
```

### 4.1 T 网格的实现方式

支持 `GridMethod='enumerate'`，完整枚举所有 T 网格点与允许的整数 f。

默认 `projection` 利用固定 f 时函数 A/T+BT/2 的严格凸性：连续最低点为 sqrt(2A/B)，离散网格最低点必在其两侧相邻网格点中，或在范围边界。对每个 f 检查这两个 T，再选择最低的 f。

遍历 f、对每个 f 求最佳网格 T，与遍历 T、对每个 T 求最佳 f，在同一可行集合上最小化的结果相同。最终输出仍为离散 T。

未提供 TMax 时，默认范围为 TMin=网格步长，上界取所有允许 f 的连续最低点最大值向上取整后再加一个网格步长。这个范围覆盖所有 f 的网格最低点，避免任意截断。

需要审核：老师是否接受使用解析最低点定位网格邻点、从而跳过完整逐点扫描？数学结果等价，但执行方式与字面“逐点枚举”有差别。实现保留完整枚举模式可复核。

只有细网格包含粗网格时，才保证离散最优值单调不增；任意步长变化不能直接声称单调。

## 5. 四项实验的具体设计与实现程度

### 实验 1：N=10 可复现验证

入口：`Run_Paper_Experiment1_N10.m`。

- 固定 `Data_N10.mat`，记录全部配置和源码快照。
- 对比连续 T ExactDP、离散网格 ExactDP 和 evolutionary-X。
- 用 literal enumeration 重算网格 DP 胜出分区，检查快速网格内层。
- 每次保存分组、T、f、五项成本、seed、收敛、运行时间。
- 核查同种子复现和网格最优命中率。

实际完成：80 个体、250 代、步长 0.001、5 个 seed。

| Seed | TC | 网格最优差距 | 非空组数 | 秒 | 未缓存组评价 |
|---|---:|---:|---:|---:|---:|
| 20260919 | 12059.2627236542 | 0% | 2 | 12.3594572 | 1006 |
| 20260920 | 12059.2627236542 | 0% | 2 | 12.6033347 | 1007 |
| 20260921 | 12059.2627236542 | 0% | 2 | 12.0120070 | 1011 |
| 20260922 | 12059.2627236542 | 0% | 2 | 12.0133340 | 1008 |
| 20260923 | 12059.2627236542 | 0% | 2 | 11.7622063 | 999 |

连续 T 精确值为 12059.2516110867，0.001 网格精确值为 12059.2627236542。5/5 次命中的是给定 f 范围、给定网格下的全局最优。5 个 seed 不能推出对所有实例都可靠。

状态：已完成小规模验证。结果文件见第 10 节。

### 实验 2：N=30/50/100 新 Direct 算法性能

入口：`Run_Paper_Experiment2_DirectPerformance.m`。

已选择基线：新 EvolutionaryX、旧 GA_Direct、旧 JADE_Direct、结构化 MS_VND_Direct。GA 代表基本遗传搜索；JADE 代表自适应差分进化家族；VND 代表直接操作分组的非进化方法。尚无证据证明 JADE 是此仓库中“最强旧算法”，不能仅据算法名称如此描述。

当前比较方式：旧 GA/JADE/VND 搜索得到最终分区后，用新网格内层重新优化 T/f 并计分，同时保存原生解与原生成本。原算法搜索时的适应度与最终公共网格评价不同，因此“共同后处理分区质量”与“原生端到端算法质量”应分开报告。

预算：进化算法用相同种群/代数；VND 的组核评价上限取新算法该次未缓存组评价数，配置 Starts=4、ILSIterations=10。VND 可能在达到上限前完成所有配置任务，且内层工作量不同，所以并非严格等预算实验。旧算法的频率搜索、新算法精确内层及精英强化也使相同代数不能代表相同计算。

指标：最好/均值/中位数/最差成本、标准差、变异系数、运行时间和收敛。新算法收敛曲线为网格成本；旧 GA/JADE 曲线仍是原生目标，VND 保存原生历史。当前没有逐代统一网格重算曲线，也没有统一导出的 convergence.csv/收敛图。

当前默认：N=[30,50,100]，Runs=5，Generations=250，Population=max(40,4N)，GridStep=0.001。

状态：runner 和 N=10、1–2 代烟雾测试完成；N=30/50/100 正式性能与稳定性证据未完成。

### 实验 3：完整策略成本比较

入口：`Run_Paper_Experiment3_StrategyComparison.m`。

Direct 使用新 evolutionary-X；Indirect wrapper 直接调用原 AHDE。两侧相同数据、seed、种群、代数，交替运行顺序。相同 seed 是复现控制，不保证两种算法获得相同随机轨迹。

输出单次与汇总成本、时间、五项分解、分组/不同 K 类数、Direct 边隔离率、Indirect LCM penalty 衰减。

\[
Saving=100(TC_{Indirect}-TC_{Direct})/TC_{Indirect}.
\]

当前 comparison.csv 比较两侧跨 seed 最好可行值，并报告配对 seed 胜率；尚未形成包含配对成本差完整分布或区间估计的正式统计分析。

当前默认：N=[10,30,50,100]，Runs=30，Generations=500，Population=max(40,4N)，GridStep=0.001。

状态：N=10 的 1–2 代和 N=30/50/100 各 1 seed、1 代烟雾测试通过；正式策略结论未完成。不得把这些短跑 Direct 优势百分比当作论文主结论。

### 实验 4：配送协同价值

入口：`Run_Paper_Experiment4_Coordination.m`。

四种情形分别重优化：Direct 可调 f、Direct f=1、Indirect 可调 F、Indirect F=1。固定频率后最优 X/K 可能变化，故重新搜索外层。

\[
Saving_{coord}=100(TC_{f/F=1}-TC_{coordinated})/TC_{f/F=1}.
\]

当前支持 raw_results.csv、paired_savings.csv 和跨 seed 最好成本 comparison.csv；原始 MAT 中保存完整解和五项成本。当前 runner 没有实验 4 专用的均值/标准差 summary.csv 或统一五项成本 diagnostics.csv，后续仍需汇总。

当前默认与实验 3 相同。状态：N=10、1–2 代管线和断点恢复已测试；正式多种子实验未运行。短跑中曾出现 Indirect 可调 F 成本高于 F=1，反映启发式搜索不足；若可行集合嵌套且充分最优，可调 F 的最优成本不应更高。

#### 需要优先审核的固定 F AHDE 差异

现有 `AHDE_FixedF1.m` 缩成 N 维 K 染色体，采用同类自适应差分变异、交叉和联合选择；但它并非原 AHDE 仅改变一个参数：

- 原版越界修复将矩阵中越界元素赋成同一个随机标量；受限版给当前个体越界元素独立随机值。
- 受限版 K 解码增加上界裁剪；原版 X=1 时 floor 可能产生上界+1。
- 抽样与交叉的随机数消费方式改变。

原 AHDE 通过 FInf=FSup=1 即可在原 2N 染色体中令 F 恒为 1。因此过去“原版不能固定 F=1”的说法不准确。可供审核的改进选择：主协同比较用原 AHDE 两次，只把频率上下界改成 1；现 N 维受限版作为额外效率/稳健性实验。这能减少实现差异，同时会保留无效 F 坐标，是否采用需评估。

## 6. 历史工作重新定位

| 历史模块 | 会议后角色 |
|---|---|
| GA/DE/ADE/AHDE/JADE 旧算法 | 历史复现及 baseline 候选 |
| Direct VND/ILS | 非进化 baseline、稳健性检查 |
| 连续 T ExactDP | 小规模连续模型正确性证书 |
| 新网格 ExactDP | 小规模新网格模型证书 |
| Indirect VND、内层精确化 | 检查主 AHDE 搜索是否低估 Indirect |
| 60s 等时间实验 | 历史结果；不作为新主线直接证据 |
| completed-search | 补充搜索充分性研究；已有指定目录是 schedule_exhausted_not_stable |
| block-K 消融 | 补充检验 Indirect 外层 K 的搜索能力 |

2026-09-30 文件检查：block-K tasks 目录有 391 个 .mat，最新文件为 N100_C+S+B+P_R008.mat，最后更新时间 2026-09-20 23:29:32；计划总数 480。391 表示存在任务文件，任务可能保存中间状态，不能把文件数无条件写成完成数。本次未重新加载全部任务确认最终完成标志。检查时无 MATLAB 进程，应按中断任务处理。

## 7. 已完成修改与测试，哪些仍缺

| 内容 | 当前证据 |
|---|---|
| evolutionary-X Direct / 组编码 / 交叉变异 / 缓存 | 已实现并运行 |
| 网格快速解与完整枚举 | 测试最大成本差 1.819×10^-12 |
| 嵌套网格收敛、五项成本、seed 复现 | MATLAB R2024a 测试通过 |
| N=10 网格证书 | 5/5 seeds 命中 |
| 原 AHDE wrapper 与成本复算 | 已通过测试 |
| 固定 F=1 受限版 | 可运行、约束正确；与原版搜索实现差异仍需审核 |
| 四实验结果保存、源码与输入快照 | 已实现 |
| 实验 2–4 ResumeDir | 已执行完整任务恢复测试；逐 seed 恢复 |
| 真正中途断电/部分 seed 恢复 | 尚无完整故障注入验证；当前未完成 seed 会重算 |
| 大规模正式性能/策略/协同证据 | 未完成 |
| 正式预算 pilot / 统计分析 / 绘图 | 未完成 |

本文件整理未运行新长实验，也未修改求解器；最新结果文件仍为 9 月 19–20 日的验证与烟雾测试。

## 8. 关于老师问“为什么跑一两个小时”

必须报告单次求解、单规模多 seed、整套实验三种时间。

已有可靠实测只有 N=10：80 个体、250 代、0.001 网格约 12 秒/seed。没有正式 N=100 数据可证明单次只需几分钟或必须数小时。

实验 3 默认 4 规模×30 seeds×2 策略=240 次求解；实验 4 为 4×30×4=480 次。小时级总时长可由大量重复求解累积，但不能据此解释所有旧长实验：旧 block-K/completed-search 的完整邻域和多起点搜索也可能使单任务很长，需要日志核实。

新 Direct 对每个分区评价多个组和 f，伴随规范化、缓存查询及强化；AHDE 对 K/F 解析求 T，并逐 pair 计算 penalty。实际快慢应靠测量而非仅凭变量结构推断。Direct 当前默认 projection 不会扫描全部 T 点，不能用“每次都扫巨大 T 网格”解释默认实现耗时。

建议正式运行前用 pilot 分别测量求解、后处理、保存时间与收敛平台，决定种群和代数；不根据策略输赢追加不对称预算。

## 9. 给 ChatGPT 的具体审核任务

请按“已确认正确 / 需修改 / 需数学依据 / 需补充实验”输出，标明优先级和对应文件；不要假定未完成的大规模实验已有结论。

1. 审核上述 Direct 和 Indirect 五项成本、S 收费、跨组 penalty 隔离的模型解释，指出哪些需论文或老师确认。
2. 审核离散 T 邻点投影是否与全枚举等价，动态上界是否充分，及是否满足老师实验意图。
3. 审核规范分区交叉/变异与初始化是否偏置组数，是否需要进化模块消融。
4. 审核实验 2 的 GA/JADE/VND 选择、原生与后处理成本口径、预算、收敛曲线能否支持“新算法更优秀”。
5. 审核实验 3 如何减少“Direct 内层精确、Indirect 仍同时搜索 K/F”导致的求解器倾斜；建议保持主 AHDE 的补充验证。
6. 优先审查实验 4 两个 AHDE 实现差异；评估改为原 AHDE FInf=FSup=1 的方案，并提出约束嵌套的验证方法。
7. 建议可预先固定的 pilot/正式种群、代数与 seed 设计，以及成本差、稳定性和时间的统计口径。当前参数是默认值，尚未通过大规模 pilot 验证。
8. 评估单实例多 seed 能支持的结论范围及跨实例实验需求。
9. 审查结果保存、断点续跑和证据追踪是否充分，指出正式绘图和汇总缺口。
10. 最后给出正式跑实验之前必须修改的短清单，不以放大 Penalty 或增加 Direct 变量获得优势。

## 10. 文件清单、位置与建议附件

### 10.1 仓库与代码位置

私有 GitHub 仓库：https://github.com/lifanghen-ux/jrd-hi-optimization 。本文实现提交在本地独立分支，之前未推送；本次未查询远端，ChatGPT 不应假定远端可见此分支。审核时上传相关文件即可。

最新代码工作树：

```text
D:\chalotte\OneDrive\문서\ChatGPT\siri\jrd_paper_worktree
```

历史工程和结果：

```text
D:\chalotte\OneDrive\桌面\留学\竞赛类\matlab\JRD_Validation_N6
```

### 10.2 关键代码附件（相对最新代码根目录）

| 文件/目录 | 用途 |
|---|---|
| Evolutionary_Direct/EvolutionaryX_Direct.m | 新 Direct 外层主算法 |
| Evolutionary_Direct/DirectEvolutionOptions.m | 种群、代数、网格、频率等配置 |
| Evolutionary_Direct/DirectGridGroupCost.m | 核心 T/f 与五项组成本 |
| Evolutionary_Direct/DirectGridPartitionCost.m | X→groups→TC |
| Evolutionary_Direct/DirectGridCostCache.m | 子集成本缓存 |
| Evolutionary_Direct/CrossoverDirectPartition.m | 组块交叉 |
| Evolutionary_Direct/MutateDirectPartition.m | 搬移/合并/拆分/交换 |
| Evolutionary_Direct/RandomCanonicalPartition.m、GreedyGridPartition.m | 初始化 |
| Evolutionary_Direct/ExactDP_DirectGrid.m | 网格精确证书 |
| Direct_V1/CanonicalizePartition.m | 等价标签规范化 |
| Direct_V1/ExactDP_Direct.m、MS_VND_Direct.m | 旧精确证书与 baseline |
| AHDE.m、Fitness_Indirect.m | 老师主算法和原成本公式 |
| Paper_Experiments/RunTeacherAHDE.m | 原 AHDE 调用与重算 |
| Paper_Experiments/AHDE_FixedF1.m | 待重点审查的 F=1 版本 |
| Paper_Experiments/RunLegacyDirectBaseline.m | 旧算法原生解和公共网格后处理 |
| Paper_Experiments/Run_Paper_Experiment1_N10.m | 实验 1 |
| Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m | 实验 2 |
| Paper_Experiments/Run_Paper_Experiment3_StrategyComparison.m | 实验 3 |
| Paper_Experiments/Run_Paper_Experiment4_Coordination.m | 实验 4 |
| Shared/NormalizeJRDData.m、JRDAnalyzeSolution.m、JRDProjectManifest.m | 数据、诊断与追踪 |
| Tests_Paper/Test_Paper_Revision.m | 新主线数学与复现门禁 |

### 10.3 文档附件

- 本文件：会议要求、方案、进度和审核问题的主材料。
- `Docs/JRD_HI_ZERO_TO_CODE_TUTORIAL.md`：完整数学与代码调用链教程。
- `Docs/PROJECT_STATUS_2026-09-20.md`：当时状态报告；其 block-K 时间状态已过期，应以本文件说明为准。
- `PAPER_MAINLINE.md`：快速入口。
- `COMPLETION_SEARCH_DESIGN.md`、`INDIRECT_BLOCK_K_ABLATION.md`：历史补充分析设计。

### 10.4 已验证数据附件

N=10 主要验证目录（相对最新代码根目录）：

```text
Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440/
  runs.csv           5 个 seed 的证书差距与耗时
  study.mat          输入、配置、源码快照、精确证书、完整解
  raw/               单 seed 完整记录
Validation_Paper/paper_revision.mat
```

建议审核数学模型时一并上传原论文及老师材料；MATLAB 执行验证则附原 `Data_N10.mat`。原数据保持不变。ChatGPT 仅收到本文时能够审设计和公式，但不能替代逐行源码审核或 MATLAB 执行。

## 11. 本文希望得到的审核产出

请给出：四实验是否满足会议要求、当前能接受的实现、必须修正的公平性问题、正式实验前的最小修改方案、推荐 pilot 设计以及允许写入论文的结论边界。

后续执行顺序拟为：先修订必要的实验公平性和输出口径，再跑大规模 pilot；根据收敛与稳定性锁定正式参数；最后形成实验 2、3、4 正式证据和补充 Indirect 稳健性结果。
