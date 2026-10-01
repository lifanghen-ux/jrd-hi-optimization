# 实验4：配送协同价值（完整16次）

N=10/30/50/100；每规模原始固定输入1个、1seed；四种情形全部重新求解。G=500，P=10N，Direct GridStep=0.001；BaseSeed=20261003。来源commit：f8e9b9c302be7356da0054ca5fa29ece08e64928。

## 现场展示顺序

1. 协同节省：[paired_summary.csv](paired_summary.csv)、[paired_savings.csv](paired_savings.csv)。
2. 每次TC/runtime/五项成本：[raw_results.csv](raw_results.csv)、[diagnostics.csv](diagnostics.csv)。
3. 每件商品周期与频率：[solution_items.csv](solution_items.csv)；完整solution：[study.mat](study.mat)、[raw/](raw/)。
4. 搜索不足标记：[anomalies.csv](anomalies.csv)；进度/失败：[task_status.csv](task_status.csv)、[failed_tasks.csv](failed_tasks.csv)。

对应源码：[实验入口](../../Paper_Experiments/Run_Paper_Experiment4_Coordination.m)、[两侧分派](../../Paper_Experiments/RunPaperStrategyCase.m)、[Direct同一算法](../../Evolutionary_Direct/EvolutionaryX_Direct.m)、[AHDE包装](../../Paper_Experiments/RunTeacherAHDE.m)、[原AHDE](../../AHDE.m)。

Indirect coordinated与fixed-F都调用原AHDE，fixed只令FInf=FSup=1；不是AHDE_FixedF1。Direct仅改f可行域。fixed解中的频率全部严格为1；本批无coordinated比fixed更贵的异常。

| N | Direct Saving % | Indirect Saving % |
|---|---:|---:|
| 10 | 3.005411 | 4.362021 |
| 30 | 4.640932 | 6.437294 |
| 50 | 5.556596 | 7.021102 |
| 100 | 6.194966 | 6.924325 |

Saving=100×(fixedTC−coordinatedTC)/fixedTC。每规模每策略仅1对，因此Std为NaN是合理的，不代表计算错误；当前只能报告preliminary趋势。

原始29个证据文件逐字节复制。旧完成结果只读审阅，旧批次resume需原完整源码快照。
