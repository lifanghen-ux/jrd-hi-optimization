# Experiment 2：VND 邻域定义与实现审阅说明

审阅日期：2026-10-01。本说明依据当前源码，只新增文档；未修改模型、算法、原始数据或实验结果，未启动新实验。

## 1. 先明确审阅对象

本批 108 次 Experiment 2 中的 `MS_VND_Direct`，实际由 [RunCommonDirectBaseline.m](../Paper_Experiments/RunCommonDirectBaseline.m#L29) 的 VND 分支运行。它复用历史 [BestNeighbor_Direct.m](../Direct_V1/BestNeighbor_Direct.m#L1) 的四个结构邻域，通过新的 [CommonGridVNDCostCache.m](../Paper_Experiments/CommonGridVNDCostCache.m#L1) 接入与 Evo/GA/JADE 相同的网格组成本核心。

本批没有直接调用历史 [VND_Direct.m](../Direct_V1/VND_Direct.m#L1)。适配器中的 `descend` 重新实现相同的邻域顺序和改进后重启规则，以记录公共目标收敛及 checkpoints。历史 `VND_Direct`、`MS_VND_Direct` 和连续 T 的组成本代码仍保留，不应把两条调用链混写。

```text
Run_Paper_Experiment2_DirectPerformance
  → RunCommonDirectBaseline('MS_VND_Direct', ...)
    → DirectState / Init_Greedy / PerturbPartition
    → 内部 descend
      → BestNeighbor_Direct：relocate → merge → swap → split
        → CommonGridVNDCostCache.Get
          → DirectGridCostCache.Get
            → DirectGridGroupKernel：优化该组网格 T 和整数 f
  → EvaluateDirectGridPartition：独立重算最终公共成本
```

源码依据：[runner 第171–179行](../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m#L171)、[适配器第180–198行](../Paper_Experiments/RunCommonDirectBaseline.m#L180)。历史调用链则是 [MS_VND_Direct.m 第25行](../Direct_V1/MS_VND_Direct.m#L25) 调用 `VND_Direct`，并在第49行以连续 T 的 `PartitionCost` 重算；它不是本批正式网格性能基线的直接入口。

VND 的外层变量仅为商品 partition，即 `X/{G_k}`；没有 Direct 的 `K_i`。给定一个组以后，其 T 和 f 都重新优化，绝不是搬动商品后沿用原组周期。

## 2. 四个邻域：用一个可以看懂的分组说明

以 6 件商品的当前方案为例：`{{1,2,3,4},{5,6}}`。下面四行是不同候选操作，不是顺次执行，也不预先假定哪一行会降低成本。最终是否接受，完全由统一组成本计算决定。

| 邻域 | 做什么 | 一个候选结果 | 修改成本的组 |
|---|---|---|---|
| relocate | 把一件商品搬到另一现有组，或独立新建一组 | 商品4搬到第二组：`{{1,2,3},{4,5,6}}` | 来源组和目标组 |
| merge | 合并两整个组 | `{{1,2,3,4,5,6}}` | 合并后的新组；删除组成本置0 |
| swap | 两个不同组各选一件商品，互换 | 商品4与5交换：`{{1,2,3,5},{4,6}}` | 两个交换组 |
| split | 把一个较大组分成两个非空组 | 首组拆为：`{{1,2},{3,4},{5,6}}` | 两个拆分后的组 |

### 2.1 relocate：单商品迁移，包括独立成组

[BestNeighbor_Direct.m 第7–19行](../Direct_V1/BestNeighbor_Direct.m#L7) 遍历每个来源组、其中每件商品和所有目标组。目标还包括 `m+1`，表示创建一个新组。跳过原组本身；若来源本来只有这一件商品，则跳过“搬到一个新单品组”的等价重复操作。

如果单品来源组的商品搬入已有组，来源组暂时变为空组，组成本为0；候选被接受时再删除空组。因此 relocate 可增加、保持或减少组数。比如 `{{1},{2,3}}` 中商品1搬入第二组后，正式状态是 `{{1,2,3}}`，而不是保存一个空组。

在预算未中断的情况下，这个邻域会检查代码定义的全部单商品迁移候选；它不同时搬动多件商品。

### 2.2 merge：两整组的合并

[第20–27行](../Direct_V1/BestNeighbor_Direct.m#L20) 遍历所有无序组对 `a<b`。只重新计算合并组的成本，把另一组置空并将其成本置0。未中断时覆盖全部两组合并，但不直接同时合并三组或更多组。

### 2.3 swap：跨组单商品交换

[第28–41行](../Direct_V1/BestNeighbor_Direct.m#L28) 遍历所有无序组对，再遍历两组中的商品对。因此一个完整扫描覆盖所有跨组的一对一交换，不改变组数，也不会产生空组。不包括“两件商品换另外两件商品”等块交换。

### 2.4 split：有意限制的二分邻域，不是全部二分穷举

[第42–69行](../Direct_V1/BestNeighbor_Direct.m#L42) 只对组大小 `q≥4` 的组执行以下三类候选：

1. **所有两商品拆出。** 枚举原组中全部 `q(q−1)/2` 个商品对，将这一对放入一个组，其余 `q−2` 件放入另一个组。这类候选的两侧都至少有2件商品。q=4时，互为补集的商品对会重复表示同一个无标签二分；源码没有将这些候选全局去重，缓存可避免重复的组核计算。
2. **最大惩罚边引导的贪心二分。** 取组内 `PSym` 中惩罚最大的一对商品，把它们作为左右两组的种子；随后按当前商品顺序，计算商品放入左、右组分别新增的组内惩罚，放入较小的一侧，相等时放左侧。这是惩罚图启发式分离，不是求解 minimum cut/max cut，也不是整体最优二分。它只用惩罚来构造候选，接受时仍评估完整五项成本。该构造可能得到 `1/(q−1)` 的不平衡拆分。若全部惩罚为0，`max` 默认命中对角元素，`i==j`，这类候选不生成。
3. **少量随机二分。** 每组随机打乱商品顺序，再在 `[2,q−2]` 中随机选切点。每次扫描默认6次，因此这类候选两側至少各有2件。不同 trial 可能重复。

源码依据：两商品枚举第47–50行；惩罚贪心第53–64行；随机候选第66–68行；6次默认值见 [JRDSearchOptions.m 第12行](../Shared/JRDSearchOptions.m#L12)。

q件商品的全部无标签、非空二分有 `2^(q−1)−1` 种。当前 split 并未枚举这个全集，例如 q≥6 时不能保证检查每一种3/3或更大块二分。q=2、3的组完全跳过 split，但其1/(q−1)拆分可以通过 relocate 到新组检查。对较大组，所有单商品拆出也由 relocate 覆盖；split 主要补充不能靠“一步单商品迁移”完成的结构变化。

## 3. best-improvement 与邻域重启怎样执行

每次 `BestNeighbor_Direct` 固定输入状态，扫描某一种邻域，并保存目前找到的最低成本候选；它不是找到第一处改善就立即返回。只有满足

```text
candidateTC < incumbentTC − Tolerance × max(1, |incumbentTC|)
```

才更新 incumbent。默认 `Tolerance=1e-11`。因此“最好”是容差意义下、实际生成且完成评价的候选中最好；极接近的值可能受容差和遍历顺序影响。依据：[BestNeighbor 第83–91行](../Direct_V1/BestNeighbor_Direct.m#L83)、[JRDSearchOptions 第13行](../Shared/JRDSearchOptions.m#L13)。

VND 按 `relocate → merge → swap → split` 扫描。某邻域产生严格改善就接受新状态，并从 relocate 重新开始；没有改善才进入下一个邻域。四类全部没有改善以后，该次下降结束。历史实现见 [VND_Direct 第2–20行](../Direct_V1/VND_Direct.m#L2)，本批实现见 [RunCommonDirectBaseline 第180–198行](../Paper_Experiments/RunCommonDirectBaseline.m#L180)。

预算在邻域中途耗尽时，返回的是已评价前缀中的最好候选，未扫描部分不作任何最优性声明。适配器先保留其中已经发现的改善，再设置 `BudgetStopped` 并结束外层搜索。即使没有耗尽预算，“四邻域无改善”也只是当前限定邻域、当前随机 split 样本下的停止条件，不是所有分组的全局证书。

## 4. 多起点与 ILS：怎样离开当前局部盆地

本批最多4个起点，每个完成下降后最多10次 ILS 扰动再下降；预算可使实际完成数少于上限。依据：[适配器第39–54行](../Paper_Experiments/RunCommonDirectBaseline.m#L39)。

| 起点 | 实际初始化 |
|---|---|
| 1 | 全部商品同组；这是搜索前先保存的可行 incumbent |
| 2 | 每件商品独立成组 |
| 3 | 确定性贪心：按商品编号依次加入最小增量成本的现有组，或独立新组 |
| 4 | 随机化贪心：随机商品顺序，每一步从增量成本最好的至多3个位置中随机选一个 |

贪心的增量不是只比较 penalty，而是 `C(旧组∪{商品})−C(旧组)` 或新单品组的完整成本。依据：[Init_Greedy.m 第3–18行](../Direct_V1/Init_Greedy.m#L3)。

ILS 每次默认连续尝试3次随机单商品迁移，不要求扰动本身立即降成本。先以20%概率从全局 best 状态重新出发，否则从当前局部状态出发，然后扰动、重新求组成本、再做一轮 VND。即使当前路径变差，全局 best 也不会被更差方案覆盖。依据：[适配器第46–52行](../Paper_Experiments/RunCommonDirectBaseline.m#L46)、[PerturbPartition.m](../Direct_V1/PerturbPartition.m#L4)、[PerturbMoves 默认值](../Shared/JRDSearchOptions.m#L10)。

每次扰动可搬到现有组或新组；若商品原来是单品组，不执行“换一个新单品标签”的等价动作。最多3次迁移不保证3个不同商品，也不保证最终 partition 一定不同：迁移可能互相抵消，或没有合法目标而跳过。因此 ILS 是跳出局部区域的启发式机制，不是遍历所有扰动。

## 5. 空组、排序和标签规范

内部状态为 `Groups`、每组标量 `Costs`、`TotalCost`。初始化由 [DirectState.m 第2–7行](../Direct_V1/DirectState.m#L2) 删除空组、排序组内商品，再按各组最小商品编号排序组的顺序。被接受的邻域候选同样处理，见 [BestNeighbor 第87–91行](../Direct_V1/BestNeighbor_Direct.m#L87)。

空组只是在迁移或合并候选构造时的临时占位，`CommonGridVNDCostCache.Get([])` 返回成本0，T/f 为NaN，不占用一个真实频率变量，也不调用组成本核。正式保存的 partition 没有空组。

标签规范遵循商品首次出现顺序，例如标签 `[9,9,2,2,7,7]` 变成 `[1,1,2,2,3,3]`，表示同一个分组而不是新解。依据：[CanonicalizePartition.m](../Direct_V1/CanonicalizePartition.m#L1)。扰动每一步和结束时都规范化；最终 `labelsOf` 也规范化，见 [适配器第200行](../Paper_Experiments/RunCommonDirectBaseline.m#L200)。

这解决组编号置换问题，但不代表所有等价候选都只扫描一次。缓存 key 按排序后的商品集合生成，可复用重复组的内部最优成本；邻域候选计数仍可包含重复候选。

## 6. 增量成本：改哪几个组，重新计算哪几个组

若当前成本是 `TC=Σ C(G)`，relocate 的候选成本就是保留未修改组成本，只替换来源和目标组；merge 只替换合并组并减掉删除组；swap/split 分别替换两个变化组。这就是增量评价，不是每个候选都重新评估全部 N 件商品。

准确地说，`DirectState` 只携带组总成本，不携带每组五项成本向量。每次缓存 miss，公共组核会重新求该变化组的 T/f 和五项成本，并缓存完整组 detail；未变化组的最优 T/f 与费用无需改变，因为当前 Direct 模型在给定 partition 下按组可分。最终再用公共 partition evaluator 汇总完整五项成本，检查其和等于 TC。依据：[BestNeighbor 第13–16行](../Direct_V1/BestNeighbor_Direct.m#L13)、[DirectGridPartitionCost.m 第25–43行](../Evolutionary_Direct/DirectGridPartitionCost.m#L25)。

组 G 的核使用：

```text
P(G) = Σ(i<j，i,j∈G) p_ij
A(f) = S + Σ(i∈G) sw_i + P(G) + f × Σ(i∈G) sr_i
B(f) = Σ(i∈G) D_i hw_i + Σ(i∈G) D_i(hr_i−hw_i)/f
C(G,T,f) = A(f)/T + B(f)T/2
```

对可行整数 f 逐个检查；本批数据未指定其他边界时为1至20。T 网格为0.001的整数倍，默认最小值0.001，自动上界包含每个 f 的连续最优点及其相邻网格。源码采用 `projection`：对固定 f 的凸函数，只比较连续最优点 `sqrt(2A/B)` 两旁的可行网格点，结果等价于配置网格上的完整枚举，不是使用连续 T 冒充网格目标。还保留 `enumerate` 模式供验证。依据：[DirectGridGroupKernel 第5–34行](../Evolutionary_Direct/DirectGridGroupKernel.m#L5)、[DirectEvolutionOptions 第17–23行](../Evolutionary_Direct/DirectEvolutionOptions.m#L17)、[NormalizeJRDData 第18–24行](../Shared/NormalizeJRDData.m#L18)。

五项成本分别为：

```text
订货      (S + Σsw_i)/T
配送      f × Σsr_i/T
中心仓    Σ[(f−1)T D_i hw_i/(2f)]
零售库存  Σ[T D_i hr_i/(2f)]
异质惩罚  P(G)/T
```

依据：[组核第36–43行](../Evolutionary_Direct/DirectGridGroupKernel.m#L36)。本文只记录现有模型，没有更改跨组 penalty、每组 S 收费或原始 penalty 数值。

## 7. 本批 108 次的预算：计什么、不计什么

本批为 N=30/50/100，各3个独立实例、各3个 algorithm seeds、4算法，共108次。正式详情见 [108次审计报告](EXP2_PRELIMINARY_108_AUDIT_2026-10-01.md)。实验入口的 pilot 默认配置和传参依据为 [runner 第19–30行](../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m#L19)、[第85–87行](../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m#L85)、[第171–174行](../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m#L171)。

| 项目 | 本批设置或解释 |
|---|---|
| 进化算法配置 | Generations=100、Population=4N，即120/200/400 |
| 公共网格 | GridStep=0.001 |
| VND 最大起点/每起点 ILS | 4 / 10；不是“运行100代” |
| 每次扰动 | PerturbMoves=3 |
| 每组每次扫描随机 split | SplitTrials=6 |
| 搜索时间上限 | Inf；时间记录用于算法性能，不作为本批主终止条件 |
| VND 搜索核评价上限 | `P×(G+1)`，分别12,120 / 20,200 / 40,400 |
| VND 停止 | 预设 starts/ILS 完成，或下一个未缓存组核即将超出 cap |

`SearchBudget.Evaluations` 每次 **未命中缓存的非空组成本核调用** 加1；命中缓存不消耗这个 cap。一次邻域候选可能触发0、1或2次未缓存组核，重复组/空组可不消耗。初始化、贪心构造和扰动涉及的未缓存组同样消耗预算。达到 cap 后仍可处理缓存命中，遇到下一次 miss 才停止。依据：[CommonGridVNDCostCache 第13–24行](../Paper_Experiments/CommonGridVNDCostCache.m#L13)、[SearchBudget 第27–32行](../Shared/SearchBudget.m#L27)。

区分以下计数，不可互相替代：

- `NeighborCandidates`：完成 `consider` 的邻域候选次数，含可能的等价重复；不包含只算了一部分组就中断的候选。
- `PartitionEvaluations`：适配器把邻域候选数和状态/checkpoint记录次数累计，不是每次都完整调用公共 partition evaluator；GA/JADE 的同名字段则数其染色体评价，语义不能当作严格等工作量。
- `Details.Budget.KernelEvaluations`：VND 搜索阶段实际消耗 cap 的组核次数。
- `Counters.GroupEvaluations/GroupRequests/CacheHits`：公共组缓存统计。`GroupEvaluations` 是 miss 次数，`GroupRequests` 包含 hit。缓存被容量限制清空后，同一个组可能再次 miss。
- `GridCandidatesChecked/InnerCandidates`：组核内部实际检查的 T/f 候选数；默认 projection 每个 f 检查两点，不等于完整 T 网格长度。

最终解的完整 detail 装配和 runner 的独立公共重算在搜索后进行，不用来延长结构搜索，也不消耗已冻结的搜索 budget snapshot。顶层缓存 counters 是适配器最终装配后的统计；如最后装配遇到被逐出的组而重新计算，可能比搜索阶段 snapshot 多，不能仅凭顶层数推断搜索超 cap。依据：[适配器第58行](../Paper_Experiments/RunCommonDirectBaseline.m#L58)、[第127–140行](../Paper_Experiments/RunCommonDirectBaseline.m#L127)、[runner 第177–187行](../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m#L177)。

因此，本批做到的是 **共同目标函数 + 预先确定的预算规则 + 报告实际工作量**，不是进化算法与 VND 严格等计算工作量。VND 并没有以 Evo 观察到的耗时或成绩动态增加自己的预算。

## 8. 应怎样解读优点、限制和后续核查

结构邻域直接操作“谁与谁同组”，避免对组号做没有实际分组含义的连续距离计算；变化组的内部 T/f 每次统一优化；缓存和增量评价让大量候选不必重算全 partition；多起点与允许暂时变差的 ILS 提供不同搜索路径。这些是实现机制，不是无条件性能优越的数学证明。

当前需要如实保留的限制：

1. split 有范围限制和随机样本，不能称全 split 穷举；没有块交换/任意多商品重分配的一步邻域。
2. cap 可截断邻域、初始化或某起点/ILS；应检查每次解的 `BudgetStopped`、`StartsStarted/Completed`、`Perturbations` 和实际核评价数，不能只写“4起点全部充分优化”。`StartsCompleted` 在本批代码中指该起点的首次下降完成，不代表随后10次 ILS 全部完成。
3. 即使完整结束，也只能得到启发式可行解；预算、初始化、随机 split、容差和遍历顺序都可能影响结果，不保证全局最优。
4. `DirectState` 本身负责排序和组成本，不单独断言全体商品跨组无遗漏/无重复；正常构造和邻域操作保持 partition，最终公共 evaluator 则检查完整 partition。独立复用该内部函数时，调用方仍须保证有效输入。
5. 缓存容量清空会改变重复计算数量，重复候选会影响运行时间；预算 snapshot 的 `CacheResets` 不由此适配器同步更新，真实缓存重置应查看顶层 `Counters.CacheResets`，不能将前者的0解读成必然没有重置。
6. 在共同网格下 VND 找到更低成本，说明有更好的可行 partition 被它发现；不能仅凭这一现象认定某个算子是唯一原因。需要预先规划同数据/seed的邻域、初始化、ILS与强化消融，不能根据结果单侧追加预算或覆盖本批记录。

本批已完成结果为 VND 对 Evo 的27个配对中26胜、1平；这不改变主策略比较仍采用新 Evo Direct 和老师原 AHDE Indirect 的安排，也不构成 Direct/Indirect 策略胜负或全局最优证明。

老师审阅可优先打开：[四邻域候选生成](../Direct_V1/BestNeighbor_Direct.m#L1)、[实际 VND 外层/ILS 与重启](../Paper_Experiments/RunCommonDirectBaseline.m#L29)、[共同组成本核](../Evolutionary_Direct/DirectGridGroupKernel.m#L1)、[完整108次结果审计](EXP2_PRELIMINARY_108_AUDIT_2026-10-01.md)。
