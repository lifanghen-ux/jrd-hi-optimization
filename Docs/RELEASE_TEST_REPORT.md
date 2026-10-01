# 精简发布版测试报告

2026-10-01，MATLAB R2024a，工作目录为独立的teacher-review发布树。未修改或覆盖已有实验结果。

| 测试 | 结果 | 实测耗时 |
|---|---|---:|
| Test_Paper_Revision | PASS | 4.015 s |
| Test_Preliminary_Readiness（含Exp2/3/4 smoke与失败恢复） | PASS | 54.431 s |
| Test_Paper_Task_Failure_Recovery（由readiness内部调用） | PASS | 12.161 s（已含于上项） |

覆盖：网格projection与字面枚举等价、嵌套网格趋势、小例精确解、seed复现和RNG恢复、Direct无K、五项成本和、原AHDE复现、fixed-F=1、跨实例生成、公共目标checkpoint、三实验输出、resume预算变化拒绝、solver-boundary/raw orphan恢复、单任务失败继续、异常标记及冻结文件保护。

Exp4的极小预算smoke中曾出现coordinated比fixed更贵；sanity正确标记为搜索不足，这不是正式16次结果。正式16次结果没有该异常。不能将smoke中几代的数字用于论文结论。

发布证据另由[Verify_Teacher_Delivery.ps1](../Tools/Verify_Teacher_Delivery.ps1)检查227个原始文件SHA256、原模型/数据保护、108/40/16任务完整性、fixed频率及公共收敛终点，生成[release_validation.json](../Provenance/release_validation.json)。

本轮复测没有重跑Exp1冻结的5seed长实验，没有自动开始新的正式benchmark。
