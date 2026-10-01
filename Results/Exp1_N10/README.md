# 实验1：冻结的N=10正确性证据

原证书TC=12059.2627236542（GridStep=0.001），连续精确参考TC=12059.2516110867。G=250、P=80，5seeds（20260919至20260923）全部命中网格精确值，gap=0。本轮没有重跑冻结实验。

展示：[runs.csv](runs.csv)、[study.mat](study.mat)、[raw/](raw/)；入口：[Run_Paper_Experiment1_N10](../../Paper_Experiments/Run_Paper_Experiment1_N10.m)；网格证书：[ExactDP_DirectGrid](../../Evolutionary_Direct/ExactDP_DirectGrid.m)。

分组：{1,7,8,10}，T=0.326、f=2；{2,3,4,5,6,9}，T=0.190、f=2。

这里的exact指N10配置网格与频率域的精确最优，不能外推成N30/50/100全局证明。原始7个证据文件未改动。
