# 实验3：策略成本比较（完整40次，辅助保留）

N=10/30/50/100；每规模原始固定输入，5seeds × Direct Evolutionary-X / Indirect原AHDE，共40次。G=100、P=4N，Direct GridStep=0.001。

展示：[comparison.csv](comparison.csv)、[paired_comparison.csv](paired_comparison.csv)、[raw_results.csv](raw_results.csv)；完整解：[study.mat](study.mat)、[raw/](raw/)；入口：[Run_Paper_Experiment3_StrategyComparison](../../Paper_Experiments/Run_Paper_Experiment3_StrategyComparison.m)。

这不是本次老师审阅的重点，但是真实已完成证据，未删除。G100的AHDE仍可能低估Indirect搜索质量；较大的Direct优势不能写成策略本身已被证明更优。后续主比较仍保留老师原AHDE，stronger Indirect只做robustness。

原始51个证据文件逐字节复制；不能在精简源码下跳过manifest继续旧批次。
