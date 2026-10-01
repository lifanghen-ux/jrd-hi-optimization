# 真实wall-clock profiling（7次）

配置G=500、P=10N、Direct GridStep=0.001，固定原始实例，每项1次测量，不能代替多seed稳定性实验。

展示：[timings.csv](timings.csv)；完整记录：[profile.mat](profile.mat)、[raw/](raw/)；启动源码来源：[profiling_source_provenance.mat](profiling_source_provenance.mat)；入口：[Profile_Paper_Solvers](../../Paper_Experiments/Profile_Paper_Solvers.m)。

| 算法 | N | Wall-clock seconds |
|---|---:|---:|
| Evolutionary-X | 30 | 84.887 |
| Evolutionary-X | 50 | 189.348 |
| Evolutionary-X | 100 | 690.363 |
| GA adapter | 100 | 324.118 |
| JADE adapter | 100 | 1214.337 |
| VND | 100 | 112.077 |
| Teacher AHDE | 100 | 190.219 |

profiling早于队列最终工程修订；见原MAT启动来源，不假定其整个旧manifest与当前精简版相同。原始10个证据文件保留，无本机启动日志或凭据。
