# 实验2：Direct算法性能（完整108次）

N=30/50/100 × 每规模3个独立实例 × 每实例3个算法seed × 4算法。G=100、P=4N、GridStep=0.001，generated instances，SFactor=0.3，BaseInstanceSeed=BaseSeed=20261001。记录来源commit：f8e9b9c302be7356da0054ca5fa29ece08e64928。

## 现场展示顺序

1. 看图：[performance_panels.png](performance_panels.png)、[common_convergence.png](common_convergence.png)。
2. 看汇总：[summary.csv](summary.csv)、[instance_summary.csv](instance_summary.csv)。
3. 查每次：[raw_results.csv](raw_results.csv)、[convergence.csv](convergence.csv)。
4. 查完整解：[study.mat](study.mat)、[raw/](raw/)，输入见[instances/](instances/)。
5. 查任务与来源：[task_status.csv](task_status.csv)、[task_provenance.csv](task_provenance.csv)、[failed_tasks.csv](failed_tasks.csv)。

对应源码：[runner](../../Paper_Experiments/Run_Paper_Experiment2_DirectPerformance.m)、[Evolutionary-X](../../Evolutionary_Direct/EvolutionaryX_Direct.m)、[GA/JADE/VND适配器](../../Paper_Experiments/RunCommonDirectBaseline.m)、[四邻域](../../Direct_V1/BestNeighbor_Direct.m)。详见[VND定义说明](../../Docs/VND_NEIGHBORHOODS_TEACHER_REVIEW.md)。

CommonGridTC与CommonBestTC为统一目标。BestCount按instance统计；AverageGap基于各instance本批最低值；Std/CV是instance内seed稳定性。汇总MeanTC跨随机实例，不能代替同实例配对比较。

27对Evo/VND中VND赢26、并列1；本批VND优于Evo，不是全局最优证明。VND的未缓存组评价预算与进化算法的partition评价并非完全等计算工作量。

原始130个证据文件逐字节复制，没有重算、删掉不利记录或修改旧manifest。校准12次已复用在108次中，不能再另加12次。精简源码仅用于新运行；旧批次resume必须在完整原源码快照执行。
