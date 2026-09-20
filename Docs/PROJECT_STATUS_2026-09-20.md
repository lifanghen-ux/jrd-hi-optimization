# JRD-HI 项目状态与论文主线（2026-09-20）

## 1. 最终研究问题

在不改变同一套成本参数的前提下，比较两种补货—配送组织方式能够达到的最低总成本：

- Direct：直接把商品划成若干组 (X/\{G_k\})，每组独立选择补货周期 (T_k) 和配送频率 (f_k)，不存在 (K_i)。
- Indirect：全体商品共享基本周期 (T)，商品 (i) 通过整数倍数 (K_i) 形成实际补货周期 (K_iT)，并选择配送频率 (F_i)。

论文要检验的是“哪种策略得到的最好可行成本更低”，不是用运行时间判优，也不能把大规模启发式最好值写成已证明的全局最优。

## 2. 老师本次要求带来的主线变化

此前主比较曾使用 Direct/Indirect 两侧的 VND/ILS 或 completed-search。现在主线改为：

1. Direct 主算法必须是新的 evolutionary-(X)：外层只搜索商品分组，内层在给定组后求 (T_k,f_k)。
2. Direct 的 (T_k) 必须落在指定离散网格；网格越细，结果应从上方逼近连续周期最优值。
3. Indirect 主算法改回老师提供且保持不变的 `AHDE.m`。
4. VND/ILS、ExactDP、completed-search 和 block-K 不删除，但分别降为 baseline、正确性验证或补充稳健性分析。
5. 新增“协同配送（频率可优化）与不协同配送（频率固定为 1）”实验。

## 3. 历史代码现在如何定位

| 代码/结果 | 新定位 | 是否作为论文主比较 |
|---|---|---|
| 根目录 `AHDE.m` | 老师原始 Indirect 求解器 | 是，Indirect 主算法 |
| `Evolutionary_Direct/` | 新增 evolutionary-(X) + 网格内层 | 是，Direct 主算法 |
| `GA_Direct.m` | 基本遗传算法、连续标签旧编码 | 实验 2 baseline |
| `JADE_Direct.m` | 较强的自适应差分进化旧编码 | 实验 2 baseline |
| `Direct_V1/MS_VND_Direct.m` | 结构感知的非进化搜索 | 实验 2 baseline / 稳健性 |
| `Direct_V1/ExactDP_Direct.m` | 连续 (T) 的小规模精确证书 | correctness validation |
| `Evolutionary_Direct/ExactDP_DirectGrid.m` | 新增离散 (T) 网格精确证书 | 实验 1 correctness validation |
| `Indirect_V1/` | 新 Indirect VND/内层精确化 | supplementary / 检查 AHDE 是否低估 |
| `Run_Optimized_Experiment.m` 等时间结果 | 历史实验 | 不作为新主线正式证据 |
| `Run_Strategy_Experiment.m` completed-search | 搜索充分性研究 | supplementary；现有正式目录状态为 `schedule_exhausted_not_stable` |
| `Run_Indirect_Block_Ablation.m` | Indirect 块 (K) 搜索诊断 | supplementary；2026-09-20 12:38 检查为 381/480，状态 `running`，后台 MATLAB 仍在继续 |

旧 completed-search 的最好可行值曾显示 Direct 优势随 N 增大，但该研究尚未满足稳定终止条件，而且 Indirect 不是老师指定的主 AHDE，因此只能作为历史线索，不能直接替代新实验 3。

## 4. 本轮实际实现

### 4.1 新 Direct 主求解器

入口：`Evolutionary_Direct/EvolutionaryX_Direct.m`。

- 染色体是长度 N 的商品组标签向量，只表达 (X/\{G_k\})。
- 每次都转成 restricted-growth 规范标签，因此 `[1 1 2]`、`[7 7 3]` 只保留一个等价表示；没有空组，也没有空组频率变量。
- 初始化同时放入全体一组、全部单独成组、确定性贪心、随机化贪心和随机分区，避免初始组数过小或过大造成单向偏置。
- 锦标赛选择；组块交叉保留父代的真实商品集合，而不是对无语义标签做数值插值。
- 变异包含搬移、合并、拆分和跨组交换；精英保留保证当代最好值不丢失；精英随机邻域强化提供局部精修。
- 主终止条件是代数，可选停滞代数；没有时间上限，运行时间只记录。

### 4.2 网格内层与效率优化

入口：`DirectGridGroupCost.m`、`DirectGridCostCache.m`、`DirectGridPartitionCost.m`。

固定组 (G_k) 和频率 (f) 后：

\[
A_k(f)=S+\sum_{i\in G_k}s_i^w+f\sum_{i\in G_k}s_i^r+
\sum_{i<j,\ i,j\in G_k}p_{ij},
\]

\[
B_k(f)=\sum_{i\in G_k}D_i\left(h_i^w+\frac{h_i^r-h_i^w}{f}\right),
\qquad
TC_k(T,f)=\frac{A_k(f)}{T}+\frac{B_k(f)T}{2}.
\]

`GridMethod='enumerate'` 会逐点枚举全部 (T)。默认 `projection` 利用上述函数对 (T>0) 严格凸的性质，只检查连续最低点左右两个网格点；它返回的仍是离散网格点，而且与完整枚举严格等价。这样遵守离散网格模型，同时把 N=100 中大量重复内层计算降到可接受水平。测试实测两种实现最大差为 (1.819\times10^{-12})。

每个商品子集的最优组成本、(T_k,f_k) 和五项成本都会缓存。相同组在不同候选分区中再次出现时直接复用，不改变目标函数。

### 4.3 小规模网格精确证书

`ExactDP_DirectGrid.m` 为 N≤16 枚举所有商品子集的网格组成本，再用集合划分动态规划求全局最优。它证明的是“给定网格和频率集合下的全局最优”，不是连续 (T) 模型的精确值。

### 4.4 Indirect AHDE 接入

`RunTeacherAHDE.m` 在固定 seed 后直接调用根目录老师原 `AHDE.m`，并用 `Fitness_Indirect.m` 重算五项成本。原文件没有修改。

实验 4 的 (F_i=1) 不能直接用原始 2N 维 AHDE 表示，因此新增 `AHDE_FixedF1.m`：保留老师 AHDE 的自适应差分变异、交叉和父子联合选择，只搜索 N 维 (K_i)，并令所有 (F_i=1)。这样是在同一搜索框架中施加实验约束，而不是更改成本模型。

## 5. 四类论文实验状态

| 实验 | 入口 | 当前状态 |
|---|---|---|
| 1. N=10 可复现验证 | `Run_Paper_Experiment1_N10` | 已完成 5 个正式 seed；5/5 命中 0.001 网格精确最优 |
| 2. N=30/50/100 Direct 性能 | `Run_Paper_Experiment2_DirectPerformance` | runner 与四算法烟雾测试通过；正式多种子尚未跑 |
| 3. Direct vs Indirect | `Run_Paper_Experiment3_StrategyComparison` | runner、AHDE 接入、诊断表和保存通过；正式多种子尚未跑 |
| 4. 协同 vs (f/F=1) | `Run_Paper_Experiment4_Coordination` | 四种情形与配对节约率输出通过；正式多种子尚未跑 |

实验 1 结果：

- 连续 (T) 的旧 Direct 全局精确值：`12059.2516110867`。
- 0.001 网格 Direct 全局精确值：`12059.2627236542`。
- 5 个 seed 的 evolutionary-(X)：全部得到 `12059.2627236542`，全部为 2 组。
- 单次约 11.8–12.6 秒，约 999–1011 个未缓存组评价。
- 结果目录：`Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440`。

## 6. 测试状态

`Tests_Paper/Test_Paper_Revision.m` 已在 MATLAB R2024a 通过：

- 网格投影与逐点枚举等价；
- 0.01 → 0.005 → 0.001 的嵌套网格成本不增，并从上方逼近连续值；
- 新离散 DP 不低于连续 DP，差距合理；
- evolutionary-(X) 同 seed 完全复现且输出中不存在 `K`；
- Direct 五项成本之和等于 TC；
- 老师 AHDE wrapper 同 seed 复现，结果可由旧 fitness 重算；
- (F=1) AHDE 的全部频率确实为 1；
- 四个实验入口都已生成 MAT、raw MAT 和 CSV。

静态检查仅剩预分配、旧式时间字符串和为兼容原 AHDE 签名而保留的未使用参数提示，没有语法或运行错误。

## 7. 为什么这样设计

1. 规范化分区编码直接消除标签置换和空组，不把搜索预算浪费在同一分组的不同编号上。
2. 交叉与变异作用于“组”本身，搜索动作与决策结构一致，避免旧 DE 对 floor 标签做微小连续扰动却不改变分组。
3. 内层对每个外层 X 都求同一网格上的最优 (T_k,f_k)，外层适应度不受随意频率位或空组位污染。
4. 凸性投影与全枚举数学等价；保留全枚举模式和测试，既满足老师的离散网格要求，又支持大规模实验。
5. N=10 同时使用连续 DP、网格 DP和启发式命中率，分别检查公式、离散化和搜索能力，避免“启发式多跑几次就当全局最优”。
6. Direct 与 AHDE 使用同一 seed、种群和代数层级；不强求变量结构和一次评价工作量完全对称。时间只报告，不参与策略判优。

## 8. 仍存在的风险

- 只有每个 N 一个固定实例。多 seed 测的是算法稳定性，不等于多个独立问题实例上的统计普遍性。
- N=30/50/100 没有全局证书，只能报告 BKS（best known feasible solution）。
- AHDE 原始连续编码经 `floor` 映射，且交叉方向与常见 DE 写法不同；因老师要求保留原算法，本轮没有悄悄修正。需要通过多 seed 和 Indirect VND/block-K 补充实验判断 AHDE 是否严重低估。
- “相同种群与代数”只控制外层搜索层级，不代表两侧目标评价次数和难度相同。应同时公开运行时间、收敛曲线和评价计数。
- 网格 0.001 的误差已在 N=10 很小，但仍应在代表解上补做 0.01/0.005/0.001 敏感性表。
- block-K 消融未完成；2026-09-20 12:38 检查为 381/480 且后台仍在运行。它不是新主线前置条件，但完成后能加强对 AHDE 搜索充分性的讨论。

## 9. 下一步执行顺序

1. 先用实验 2 在 N=30/50/100 做 5 个 seed 的 pilot，观察收敛是否在 250 代前平台化。
2. 根据 pilot 预先固定正式代数、种群和 seed 数；不要看完策略输赢后再调预算。
3. 跑实验 2 正式 Direct 性能，确认新算法相对 GA/JADE/VND 的质量和稳定性。
4. 用同一固定外层层级跑实验 3 的 30 seeds，主表只比较新 Direct 与老师 AHDE。
5. 跑实验 4 的 30 seeds；报告每个 seed 的配对节约率及最好/均值/标准差。
6. 最后继续完成 block-K 的剩余任务，把它作为 AHDE 充分性的补充证据，而不是替代主表。
7. 若论文需要跨实例结论，再新增不同随机实例；不得把一个固定实例的 30 seeds 写成 30 个实例。

建议 pilot 命令：

```matlab
Setup_JRD;
[P2,out2] = Run_Paper_Experiment2_DirectPerformance( ...
    'NList',[30 50 100],'Runs',5,'Generations',250);
```

正式参数应在 pilot 后锁定。当前 runner 的默认正式规模为实验 3/4 各 30 seeds、500 代；这会是长任务，启动前应确认供电、休眠设置和磁盘空间。

实验 2–4 每完成一个 seed 都更新 `study.mat`。关机或 MATLAB 中断后，以完全相同的参数增加 `ResumeDir` 即可跳过已经完成的 seed：

```matlab
[E3,out3] = Run_Paper_Experiment3_StrategyComparison( ...
    'NList',[10 30 50 100],'Runs',30,'Generations',500, ...
    'ResumeDir','上次结果目录');
```
