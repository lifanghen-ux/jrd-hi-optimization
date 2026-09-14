# 间接侧块 K 搜索：预注册消融与多种子验证

## 研究问题

在不修改任何 Data_N*.mat、Penalty、K/F 边界或成本公式的条件下，检验联合改变两个 K 是否能跨过单 K 局部最优障碍，并区分普通块搜索与 Penalty 引导本身的增益。

本实验只比较 Indirect 求解器版本。它回答“块 K 是否改善间接侧搜索能力”，不直接回答 Direct 与 Indirect 哪个策略最优成本更低。完成后再用独立种子运行策略比较。

## 冻结的四级消融

按下面顺序累计增加邻域，不在看过结果后更换定义：

| 标签 | profile | 邻域 |
|---|---|---|
| C | coordinate | 对每个商品穷举 K=1..20 的其他值 |
| C+S | coordinate_swap | C + 交换任意两个商品的 K |
| C+S+B | coordinate_swap_block | C+S + 不读取 Penalty 的双 K 块搜索 |
| C+S+B+P | coordinate_swap_block_conflict | C+S+B + 高 Penalty 边双 K 块搜索 |

双 K 值不是穷举 20×20。每次坐标扫描会为每个商品记录成本最有希望的 3 个非当前 K；块邻域联合测试两个商品的 3×3 组合，且二者必须同时改变。

普通块 B 使用固定循环商品配对，每个商品连接后续 2 个编号，完全不读取 Penalty。冲突块 P 对正 Penalty 边按权重从高到低排序，最多取 200 对。所有规则确定且写入结果配置。

当块移动改善成本后，VND 回到单坐标邻域重新搜索，直至该 profile 的全部配置邻域均无改进。块候选数和块接受次数分别记录，不能只根据最终成本猜测块操作是否真正发挥作用。

## 随机性与计算任务

四个 profile 对同一 N、同一 run 使用同一个 seed，并采用相同起点数、每起点扰动数、扰动比例和内层精确 F/T 计算。profile 执行顺序随 run 循环轮换，时间只作诊断，不作停止或优劣指标。

正式消融预注册为：

- 固定数据：Data_N10、N30、N50、N100，各一个现有实例；
- 30 个配对种子；
- 每个 profile、每个规模、每个种子：4 个起点，每起点 10 次有效扰动；
- 共 4×4×30=480 个完整求解任务；
- 每个任务完成 44 次完整局部搜索，不设时间或评价次数截断；
- BaseSeed=20260909；
- 不修改 Penalty，不生成新数据。

这四个规模仍各只有一个实例。30 个种子衡量搜索随机性，不是30个独立问题实例。

## 预先规定的输出与判断

主要输出：每 profile 的跨种子 Best、Mean、Median、Std、Worst；相对前一级的配对平均/中位成本改善率和配对胜率。

辅助输出：四类邻域候选数、两类块邻域接受次数、五项成本、K 类数、冲突边两端 K 不同率及 Penalty 系数衰减率。

解释规则：

1. 若块邻域接受次数为 0，不能声称块搜索改善了该规模。
2. 若 Best 降低但配对中位改善接近 0，应解释为偶发逃逸能力，不称稳定提升。
3. 若中位成本降低且多数配对种子改善，可认为该块组件提升当前 Indirect 求解器。
4. 若加入 P 才改善，只说明读取 Penalty 的结构引导有效；这属于求解算法能力，不改变成本公式。
5. 若更复杂 profile 反而变差，保留结果，不删除该层，也不临时调整 Penalty、候选数或种子。
6. 不对多个版本做事后挑选显著性阈值；本轮以成本大小和配对分布作算法诊断。

最终策略比较 profile 的选择规则：先看四个规模的配对中位改善和最差退化，选择在多数规模不退化且能降低最好可行成本的最简单 profile。若结论不一致，保留 C+S 基线与最好块版本两套进入独立种子确认，不自行宣布唯一胜者。

## 测试和实验命令

本轮代码测试，不是研究证据：

```matlab
Setup_JRD;
Test_JRD_All;
Test_JRD_Completion;
```

用户确认后，先启动正式块 K 消融：

```matlab
[Ablation,out] = Run_Indirect_Block_Ablation( ...
    'Phase','formal','NList',[10 30 50 100], ...
    'Runs',30,'Starts',4,'ILSIterations',10, ...
    'BaseSeed',20260909,'BlockValuesPerItem',3, ...
    'BlockPartnersPerItem',2,'BlockConflictPairLimit',200);
```

输出目录 Results_Ablation 下保存 ablation.mat、raw_results.csv、summary.csv 和每个任务的检查点。中断后以相同参数增加 `ResumeDir`，指向实际输出目录。

消融完成并按冻结规则选定 profile 后，最终 Direct/Indirect 比较使用另一组尚未用于选择的种子，例如 BaseSeed=30260909，并在 `Run_Strategy_Experiment` 中明确传入 `IndirectNeighborhoodProfile`。不得用消融种子上的最好表现直接作为独立确认结果。

## 限制

统一任务层级不等于两侧求解器性能完全相同。双 K 块只覆盖预定义商品对和每个商品最有希望的少量 K，不是全部多商品 K 组合。若本次仍显示 Indirect 对块宽度或 K 上界敏感，应另行预注册后续实验版本，不能在当前批次中途改规则。
