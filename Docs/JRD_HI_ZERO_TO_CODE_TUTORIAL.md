# JRD-HI 零基础完整教程：从现实问题到 MATLAB 结果

这份教程不要求读者学过运筹优化、进化算法或 MATLAB。阅读目标是能够把下面这条链从头到尾讲清楚：

\[
\text{现实问题}\rightarrow\text{数学参数}\rightarrow\text{决策变量}
\rightarrow\text{算法}\rightarrow\text{MATLAB 调用}\rightarrow\text{CSV/MAT 结果}.
\]

## 一、现实中到底在优化什么

设一个中心仓库向多个零售点供应 N 种商品。每次补货和配送都会花钱；货物放在中心仓库或零售商处也会产生库存成本；某些不同种类的商品如果在同一次补货中混在一起，还会产生异质品冲突或额外处理成本。

我们要决定三件事：

1. 哪些商品一起补货；
2. 多久补一次；
3. 一次补来的货分几次送到零售商。

补得太频繁，订货和运输次数很多；补得太少，单次补得多，库存很高。优化就是在这些相反成本之间找平衡。

## 二、输入数据每一项是什么

每个 `Data_N*.mat` 中都有一个结构体 `data`。加载方式：

```matlab
loaded = load('Data_N10.mat','data');
data = loaded.data;
```

主要字段如下。

| 字段 | 含义 | 直观解释 |
|---|---|---|
| `N` | 商品数量 | N=10 表示 10 种商品 |
| `D(i)` | 商品 i 的需求率 | 每单位时间需要多少商品 i |
| `S` | 主补货启动成本 | 每开启一次联合补货事件都要付 |
| `sw(i)` | 商品 i 的次要订货成本 | 商品 i 参加一次补货要付 |
| `sr(i)` | 商品 i 的单次配送成本 | 从中心仓向零售端送一次要付 |
| `hw(i)` | 中心仓单位库存成本 | 商品 i 在仓库多放一单位时间的成本 |
| `hr(i)` | 零售端单位库存成本 | 商品 i 在零售端多放一单位时间的成本 |
| `p(i,j)` | 商品 i、j 同时补货的异质 penalty | 只有正上三角被模型采用 |
| `FInf,FSup` | 配送频率整数上下界 | 缺省为 1 到 20 |
| `KInf,KSup` | Indirect 的补货倍数上下界 | 缺省为 1 到 20 |

`NormalizeJRDData.m` 负责检查字段、把向量统一成列向量、建立 penalty 上三角矩阵和 LCM 表。它只产生内存副本，不会改写原始 MAT 文件。

## 三、最重要的符号

### 1. (T) 和 (T_k)

(T) 是时间长度。例如 (T=0.2) 可以理解为每 0.2 个时间单位出现一次基本补货时点。

- Indirect 只有一个公共基本周期 (T)。
- Direct 的第 k 组有自己的周期 (T_k)，不同组可以完全不同。

### 2. (K_i)

(K_i) 只属于 Indirect。商品 i 的实际补货周期是：

\[
K_iT.
\]

如果 (T=0.1)，(K_i=3)，商品 i 每 0.3 个时间单位补一次。

Direct 没有 (K_i)。Direct 已经允许每组直接拥有自己的 (T_k)，再乘一个整数 (K_i) 会改变策略定义，也会给 Direct 额外自由度，所以代码中明确不添加它。

### 3. (f_k) 和 (F_i)

它们表示一次补货周期内分几次配送。

- Direct：同一组共享 (f_k)。
- Indirect：每个商品使用 (F_i)。
- (f/F=1)：补到中心仓后只配送一次，称为不协同配送基准。
- (f/F>1)：分批配送，可能降低零售库存，但会增加配送次数。

### 4. (X\)、(G_k) 和 partition

Direct 的 (X) 是长度 N 的组标签向量。例：

```text
商品编号： 1 2 3 4 5
X：        1 1 2 3 2
```

它表示：

- (G_1=\{1,2\})
- (G_2=\{3,5\})
- (G_3=\{4\})

这里一个 partition 是“把全部商品分成互不重叠的非空组”的完整方案，不是指其中某一组。

`[1 1 2 3 2]` 与 `[7 7 4 9 4]` 是同一 partition，因为商品之间的同组关系完全相同。`CanonicalizePartition.m` 会把第二个自动改成第一个形式。

### 5. (p_{ij})

(p_{ij}>0) 表示商品 i 和 j 在同一补货事件出现时产生额外成本。代码沿用原模型约定，只读取 `p` 的正上三角，避免一对商品计算两次。

## 四、Direct 的成本公式

给定第 k 组商品 (G_k)、周期 (T_k) 和配送频率 (f_k)，五类成本是：

### 1. 订货成本

\[
C_o^k=\frac{S+\sum_{i\in G_k}s_i^w}{T_k}.
\]

周期越短，单位时间内启动补货的次数越多，所以要除以 (T_k)。

### 2. 配送成本

\[
C_d^k=\frac{f_k\sum_{i\in G_k}s_i^r}{T_k}.
\]

一个周期送 (f_k) 次；周期越短，每单位时间配送次数也越多。

### 3. 中心仓库存成本

\[
C_{hw}^k=\sum_{i\in G_k}
\frac{(f_k-1)T_kD_ih_i^w}{2f_k}.
\]

如果 (f_k=1)，货物没有被分批留在中心仓等待后续配送，此项为 0。

### 4. 零售端库存成本

\[
C_{hr}^k=\sum_{i\in G_k}\frac{T_kD_ih_i^r}{2f_k}.
\]

配送次数增加时，每次送得更少，零售端平均库存下降。

### 5. 异质 penalty

\[
C_p^k=\frac{\sum_{i<j,\ i,j\in G_k}p_{ij}}{T_k}.
\]

Direct 中，不同组使用独立补货事件，因此跨组 penalty 被隔离；同组商品每次该组补货时相遇。

### 6. 总成本

\[
TC_{Direct}=\sum_k(C_o^k+C_d^k+C_{hw}^k+C_{hr}^k+C_p^k).
\]

程序把固定组与频率下的式子整理成：

\[
TC_k(T,f)=\frac{A_k(f)}{T}+\frac{B_k(f)T}{2}.
\]

其中：

\[
A_k(f)=S+\sum s_i^w+f\sum s_i^r+\sum p_{ij},
\]

\[
B_k(f)=\sum D_i\left(h_i^w+\frac{h_i^r-h_i^w}{f}\right).
\]

前半部分随 T 增大而下降，后半部分随 T 增大而上升，所以中间存在最低点。

### 一个三商品小例子

假设一组有商品 1 和 2：

- (S=100)
- (s_1^w+s_2^w=20)
- (s_1^r+s_2^r=10)
- (p_{12}=30)
- 选 (f=2)
- 计算得到 (B=400)

则 (A=100+20+2\times10+30=170)。如果网格候选 (T=0.9)：

\[
TC=170/0.9+400\times0.9/2=368.89.
\]

如果 (T=1.0)：

\[
TC=170/1+400\times1/2=370.
\]

所以在这两个网格点中 0.9 更好。真实代码对所有允许的 f 做同样比较，再选最低组合。

## 五、Indirect 的成本公式和 LCM

Indirect 有公共基本周期 (T)，商品 i 每 (K_iT) 补一次。

\[
C_o=\frac{S}{T}+\sum_i\frac{s_i^w}{K_iT},
\]

\[
C_d=\sum_i\frac{F_is_i^r}{K_iT},
\]

\[
C_{hw}=\sum_i\frac{(F_i-1)K_iTD_ih_i^w}{2F_i},
\]

\[
C_{hr}=\sum_i\frac{K_iTD_ih_i^r}{2F_i}.
\]

Penalty 是：

\[
C_p=\sum_{i<j}\frac{p_{ij}}{\operatorname{lcm}(K_i,K_j)T}.
\]

LCM 是最小公倍数。假设商品 1 每 (2T) 补一次，商品 2 每 (3T) 补一次：

```text
商品1：2T, 4T, 6T, 8T, ...
商品2：3T, 6T, 9T, ...
```

两者每 (6T) 同时出现，而 6 正是 lcm(2,3)。所以单位时间冲突频率是 (1/(6T))。

Indirect 总成本仍是五项之和。固定 (K,F) 后，也可写成 (A/T+BT/2)，老师 AHDE 用解析式：

\[
T^*=\sqrt{2A/B}
\]

求该 (K,F) 下最优公共 T。

## 六、为什么旧 Direct 搜索困难

旧 `GA_Direct.m`、`DE_Direct.m`、`ADE_Direct.m`、`AHDE_Direct.m`、`JADE_Direct.m` 使用 2N 个 0 到 1 的连续数。

前 N 个数通过：

```matlab
Group_Idx = floor(X(1:n) * n) + 1;
```

变成组号；后 N 个数变成“每个可能标签的频率”。问题包括：

1. 连续数发生小变化时，floor 后组号可能完全不变，算法以为自己在移动，实际 partition 没变。
2. 跨过一个 floor 边界时，商品又会突然跳到另一组，邻近连续点不再对应邻近分组。
3. 标签 1 和标签 7 没有大小或距离意义，但 DE 会对它们做加减。
4. 同一 partition 有很多标签排列，浪费评价次数。
5. 允许 N 个标签却常只使用其中少数，未使用标签形成空组；空组不产生成本，但后半染色体仍为它保存频率位。
6. 频率按“原标签”绑定。仅仅改标签编号就可能把同一个实际组绑定到另一个频率位。

因此旧算法的好坏容易受标签偶然性、空位和初始化影响，而不是只反映 partition 的质量。

## 七、新 evolutionary Direct 的完整流程

入口：

```matlab
answer = EvolutionaryX_Direct(data, ...
    'Seed',42,'PopulationSize',80,'Generations',250,'GridStep',0.001);
```

### 步骤 1：读数据和参数

`DirectEvolutionOptions.m` 检查 seed、种群、代数、网格步长、频率集合、缓存上限等参数。默认没有时间终止。

### 步骤 2：初始化多个 partition

种群中包含：

- 全部商品一组；
- 每个商品单独一组；
- 按真实网格组成本做的确定性贪心；
- 随机顺序和随机候选的贪心；
- 多个不同组数的随机 partition。

这样不是武断地规定“初始组必须大”或“必须小”，而是同时覆盖两个极端和中间状态。

### 步骤 3：规范标签

每个候选都调用 `CanonicalizePartition.m`。规范化只改编号，不改谁和谁同组。它保证没有空组和标签等价重复。

### 步骤 4：评价一个 partition

`DirectGridPartitionCost.m` 把 X 变成 `Groups`，逐组调用 `DirectGridCostCache.Get`。

缓存未命中时，`DirectGridGroupCost.m`：

1. 计算该组 penalty 系数；
2. 遍历允许的整数 f；
3. 对每个 f 在离散 T 网格上找最低值；
4. 在所有 f 中再取最低；
5. 返回 T、f、组成本和五项分解。

同一商品子集以后再次出现时，直接读取缓存。

### 步骤 5：选择

锦标赛选择随机抽几个候选，让其中成本最低者成为父代。成本越低，被选中的机会越大，但其他候选仍有机会，能保持多样性。

### 步骤 6：交叉

`CrossoverDirectPartition.m` 从父代 A 选若干完整组先放入子代，再用父代 B 的组关系组织尚未放入的商品。它操作的是实际商品集合，不对标签数值求平均。

### 步骤 7：变异和扰动

`MutateDirectPartition.m` 随机做一种：

- relocate：把一个商品搬到其他组或新组；
- merge：合并两组；
- split：把一个至少含两件商品的组拆成两组；
- swap：交换两个不同组的商品。

“扰动”就是主动改变当前解，使搜索离开原来的局部低谷。它不是改输入数据，也不是放大 penalty。

### 步骤 8：精英和局部强化

成本最低的若干候选原样进入下一代，防止好解丢失。对少数精英额外尝试几次上述结构变异，只有变好才接受，相当于轻量局部搜索。

### 步骤 9：迭代和输出

重复选择—交叉—变异—评价，直到代数完成或达到用户明确设置的停滞代数。输出 `Convergence` 表，每代保存最好成本、平均成本、不同 partition 数、组评价数、缓存命中和耗时。

### 网格投影为什么仍是精确网格搜索

固定 f 后，(A/T+BT/2) 是先降后升的凸函数。网格最优点一定是连续最低点左右两个相邻网格点之一。默认 `projection` 只评价这两点，所得答案与把 0.001、0.002……全部列出来完全相同；`enumerate` 模式用于逐点复核。

## 八、老师 AHDE 的完整流程

主入口不是改写的版本，而是：

```matlab
answer = RunTeacherAHDE(data, ...
    'Seed',42,'PopulationSize',80,'Generations',250);
```

wrapper 固定随机种子后调用原 `AHDE.m`。

### 1. 连续染色体

每个个体有 2N 个 0 到 1 的实数：

- 前 N 个映射成整数 (K_i)；
- 后 N 个映射成整数 (F_i)。

映射使用 floor，例如区间被切成 20 个小格，每个小格对应整数 1 到 20。

### 2. 评价

给定 K、F 后：

1. 用 LCM 表求 penalty 系数；
2. 用解析式求该 K、F 下最优 T；
3. 计算五项成本。

### 3. 差分变异

AHDE 从三个其他个体取向量，用“一个个体 + 系数 × 两个个体之差”产生变异向量。变异系数随代数自适应变化。

### 4. 交叉

父代和变异向量按坐标混合，至少保留一个强制坐标。这里项目保持老师原代码的实际判断方向，不自行改成教科书写法。

### 5. 选择

AHDE 把 Np 个父代和 Np 个试验个体放在一起，按成本排序，保留最好的 Np 个进入下一代。

### 6. (F=1) 版本

`AHDE_FixedF1.m` 只保留 N 个 K 坐标，所有 F 固定为 1。它仍使用相同的自适应差分变异、交叉和联合选择。

## 九、MATLAB 代码从哪里开始

先切换到仓库根目录，然后：

```matlab
Setup_JRD;
```

它把以下活动目录加入 MATLAB path：

```text
根目录
├─ Shared/                 数据、清单、诊断和通用工具
├─ Direct_V1/              旧结构化 Direct VND/ILS 与连续 T ExactDP
├─ Indirect_V1/            旧结构化 Indirect VND 与 block-K
├─ Evolutionary_Direct/    新 Direct 主算法
├─ Paper_Experiments/      AHDE adapter 和四类论文实验
├─ Tests/                  原有测试
└─ Tests_Paper/            新论文主线测试
```

### 新 Direct 单次调用链

```text
EvolutionaryX_Direct
  → NormalizeJRDData
  → DirectEvolutionOptions
  → 初始化 X
  → DirectGridPartitionCost
      → DirectGridCostCache.Get
          → DirectGridGroupCost
  → 选择 / CrossoverDirectPartition / MutateDirectPartition
  → DirectGridPartitionCost 重复评价
  → answer
```

### Indirect 单次调用链

```text
RunTeacherAHDE
  → NormalizeJRDData
  → rng(seed)
  → 原 AHDE.m
      → 连续染色体解码 K,F
      → LCM penalty
      → 解析 T
      → 五项成本
  → Fitness_Indirect 复算
  → answer
```

## 十、四类实验各自在证明什么

### 实验 1：N=10 正确性和复现

```matlab
[Study,out] = Run_Paper_Experiment1_N10;
```

它回答：公式是否一致、网格计算是否正确、新进化搜索能否找到已知精确答案、同 seed 是否复现。

连续 ExactDP 是连续 T 下界；网格 ExactDP 是新模型的严格证书；进化算法命中网格 DP 才能说该次命中网格全局最优。

### 实验 2：新 Direct 算法性能

```matlab
[Study,out] = Run_Paper_Experiment2_DirectPerformance( ...
    'NList',[30 50 100],'Runs',5,'Generations',250);
```

比较：

- 新 `EvolutionaryX_Direct`；
- 旧基本 `GA_Direct`；
- 旧自适应 `JADE_Direct`；
- 结构化非进化 `MS_VND_Direct`。

旧算法最终 partition 会用新网格内层重新计分，减少不同 T/f 内层公式对 partition 比较的干扰。原生成本和原生解仍保存在 raw MAT 中。

### 实验 3：两种策略成本

```matlab
[Study,out] = Run_Paper_Experiment3_StrategyComparison( ...
    'NList',[10 30 50 100],'Runs',30,'Generations',500);
```

只把新 Direct 与老师 AHDE 放入主比较。正的：

\[
100\frac{TC_{Indirect}-TC_{Direct}}{TC_{Indirect}}
\]

表示 Direct 成本更低。

### 实验 4：配送协同价值

```matlab
[Study,out] = Run_Paper_Experiment4_Coordination( ...
    'NList',[10 30 50 100],'Runs',30,'Generations',500);
```

分别重优化四种情形：Direct 可调 f、Direct f=1、Indirect 可调 F、Indirect F=1。节约率：

\[
100\frac{TC_{F=1}-TC_{coordinated}}{TC_{F=1}}.
\]

短跑中此值可能为负，因为启发式搜索没有充分收敛；正式多 seed 和充足代数后才解释模型含义。

## 十一、seed、稳定性和“全局最优”

随机种子 seed 是随机数发生器的起点。相同数据、代码、参数和 seed 应产生相同初始种群及搜索轨迹。不同 seed 相当于从不同随机起点搜索。

多 seed 的作用是测算法稳定性：最好值、平均值、标准差、最坏值。它不会把同一个 N 的固定数据变成多个独立实例。

- N=10 网格 DP 可以给全局证书。
- N=30/50/100 只能称最好可行值或 BKS。
- 多次都得到同一数值说明稳定，但不等于数学证明。

## 十二、输出文件怎样看

每次 runner 创建全新目录，不覆盖旧结果。常见内容：

| 文件 | 内容 |
|---|---|
| `study.mat` | 完整配置、输入数据、源码快照、每次完整解、表格和状态 |
| `raw/*.mat` | 每一个 N、算法/策略、seed 的单独记录 |
| `raw_results.csv` | 每次运行的一行摘要 |
| `summary.csv` | 每个 N、算法/策略的最好、均值、中位数、标准差、最坏值、耗时 |
| `comparison.csv` | Direct/Indirect 或协同/不协同的最终比较 |
| `diagnostics.csv` | 五项成本、组数、边隔离率、LCM penalty 衰减等 |
| `paired_savings.csv` | 实验 4 同 seed 的协同节约率 |

### 实验 1 `runs.csv`

- `Run`：第几次；
- `Seed`：随机种子；
- `TotalCost`：新 Direct 最终 TC；
- `GridOptimalityGapPercent`：相对网格 DP 证书的差距；
- `HitGridOptimum`：是否命中证书；
- `GroupCount`：非空组数；
- `RuntimeSeconds`：总耗时；
- `GroupEvaluations`：真正计算过多少个未缓存商品子集。

### 实验 2/3 `raw_results.csv`

- `N`：商品规模；
- `Algorithm` 或 `Strategy`：求解器；
- `Run`、`Seed`：重复编号与种子；
- `TotalCost`：最终成本；
- `RuntimeSeconds`：诊断耗时；
- `PopulationSize`、`Generations`：外层搜索级别。

### `summary.csv`

- `BestTC`：所有 seed 的最低成本；
- `MeanTC`、`MedianTC`：平均和中位数；
- `StdTC`：标准差；
- `WorstTC`：最高成本；
- `CVPercent=100×Std/Mean`：相对波动；
- `MeanRuntimeSeconds`：平均耗时，只报告，不用于策略判优。

### `diagnostics.csv`

- `OrderingCost`：主启动 + 商品次要订货；
- `DeliveryCost`：配送；
- `WarehouseHoldingCost`：中心仓库存；
- `RetailHoldingCost`：零售库存；
- `PenaltyCost`：异质冲突；
- `GroupOrKClassCount`：Direct 的组数，或 Indirect 中不同 K 值的种类数；
- `StrictEdgeIsolationRate`：Direct 中正 penalty 边被分到不同组的比例；
- `WeightedEdgeIsolationRate`：按 penalty 大小加权的隔离比例；
- `DifferentKEdgeRate`：Indirect 中正 penalty 商品对取不同 K 的比例；
- `PenaltyCoefficientAttenuation`：LCM 相对未衰减 penalty 系数降低了多少。

## 十三、怎样查看一个完整解

```matlab
saved = load(fullfile(out,'study.mat'),'Study');
Study = saved.Study;

% 实验 3：第一个 N、第一次、Direct
a = Study.Records{1,1,1};
disp(a.TotalCost);
disp(a.Groups);
disp(a.GroupT);
disp(a.GroupF);
disp(a.Convergence);
```

Indirect：

```matlab
b = Study.Records{1,1,2};
disp(b.TotalCost);
disp(b.T);
disp(b.K);
disp(b.F);
plot(b.ConvergenceTC);
```

Direct 的 `GroupT(g)`、`GroupF(g)` 属于 `Groups{g}`；Indirect 的 `K(i)`、`F(i)` 属于商品 i。

## 十四、推荐的实际执行顺序

```matlab
Setup_JRD;
Test_Paper_Revision;                       % 先过数学和复现门禁
[E1,out1] = Run_Paper_Experiment1_N10;    % 小规模证书
[P2,out2] = Run_Paper_Experiment2_DirectPerformance( ...
    'NList',[30 50 100],'Runs',5,'Generations',250); % pilot
```

观察实验 2 收敛曲线后，在看 Direct/Indirect 输赢之前固定正式参数，再运行：

```matlab
[E2,out2] = Run_Paper_Experiment2_DirectPerformance( ...
    'NList',[30 50 100],'Runs',30,'Generations',500);
[E3,out3] = Run_Paper_Experiment3_StrategyComparison( ...
    'NList',[10 30 50 100],'Runs',30,'Generations',500);
[E4,out4] = Run_Paper_Experiment4_Coordination( ...
    'NList',[10 30 50 100],'Runs',30,'Generations',500);
```

最后记住三条边界：不改原始数据、不用运行时间判策略优劣、大规模结果不写成已证明全局最优。

如果实验 2–4 因关机中断，记住 MATLAB 当时显示的 `out` 目录，并用完全相同参数加上 `ResumeDir`：

```matlab
[E3,out3] = Run_Paper_Experiment3_StrategyComparison( ...
    'NList',[10 30 50 100],'Runs',30,'Generations',500, ...
    'ResumeDir','上次的完整结果目录');
```

程序会核对参数、源码哈希和固定数据；任何一项变化都会拒绝把新旧结果混在一起。
