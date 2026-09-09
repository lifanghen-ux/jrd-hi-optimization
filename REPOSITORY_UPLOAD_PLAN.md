# 已确认的上传清单

目标 GitHub 账号：lifanghen-ux（用户已确认）。
新仓库名称：jrd-hi-optimization。
可见性：Private。
用户已授权创建并上传；2026-09-09 已创建远程私有仓库。

## 拟上传

1. 活动 MATLAB 源码，包括原十个搜索算法和本轮新增 Direct/Indirect/Shared/Tests。
2. 五个固定数据：Data_N10.mat、Data_N30.mat、Data_N50.mat、Data_N100.mat、testDataN6_Paper.mat。
3. README.md、CODE_AUDIT.md、CODE_MAP.md、IMPLEMENTATION_REPORT.md、本上传方案和 .gitignore。
4. 测试内保留预期值与数学参照，保留旧源码原作者署名。

当前 59 个活动源码文件：

- ADE_Direct.m
- ADE.m
- AHDE_Direct.m
- AHDE.m
- DE_Direct.m
- DE.m
- Describe_Legacy_Solution.m
- Fitness_Indirect.m
- GA_Direct.m
- GA.m
- Generate_Data.m
- Generate_Large_Data.m
- JADE_Direct.m
- JADE.m
- Main_ADE_Test.m
- Main_All_Algorithms_Test.m
- Main_Batch_Experiment.m
- Main_Verify.m
- Run_Batch_Experiment.m
- Run_Optimized_Experiment.m
- Setup_JRD.m
- Test_Storage_Fix.m
- Shared/JRDFileSHA256.m
- Shared/JRDProjectManifest.m
- Shared/JRDSearchOptions.m
- Shared/NormalizeJRDData.m
- Shared/SearchBudget.m
- Direct_V1/BestNeighbor_Direct.m
- Direct_V1/CanonicalizePartition.m
- Direct_V1/DirectState.m
- Direct_V1/ExactDP_Direct.m
- Direct_V1/GroupCostCache.m
- Direct_V1/GroupCostExact.m
- Direct_V1/GroupCostFixedF.m
- Direct_V1/Init_Greedy.m
- Direct_V1/MS_VND_Direct.m
- Direct_V1/PartitionCost.m
- Direct_V1/PerturbPartition.m
- Direct_V1/VND_Direct.m
- Indirect_V1/IndirectCostCache.m
- Indirect_V1/IndirectCostFixed.m
- Indirect_V1/IndirectInnerExact.m
- Indirect_V1/IndirectInnerKernel.m
- Indirect_V1/MS_VND_Indirect.m
- Indirect_V1/VND_Indirect.m
- Tests/Test_JRD_All.m
- Tests/Test_JRD_Mathematics.m
- Tests/Test_JRD_Search.m
- Tests/Test_N10_HitRate.m
- Tests/Oracles/Legacy_ADE_Direct.m
- Tests/Oracles/Legacy_ADE.m
- Tests/Oracles/Legacy_AHDE_Direct.m
- Tests/Oracles/Legacy_AHDE.m
- Tests/Oracles/Legacy_DE_Direct.m
- Tests/Oracles/Legacy_DE.m
- Tests/Oracles/Legacy_GA_Direct.m
- Tests/Oracles/Legacy_GA.m
- Tests/Oracles/Legacy_JADE_Direct.m
- Tests/Oracles/Legacy_JADE.m

## 不上传

- Backups、Results_Fixed、Results_Optimized、Validation_V1 等自动生成目录。
- 原始 ZIP、论文 PDF/DOCX、签名照片、历史 Excel/PNG。
- 两个历史结果 MAT，其中全算法结果的成本为零，不能作为新算法证据。
- 机器凭据、账号令牌和无关文件。

全部原始文件仍保留在本地，这只是上传白名单。
正式实验结果后续单独整理，不自动提交全部日志。
当前不附加开源许可证，避免擅自更改来源代码的许可。

## 上传后验证

按用户已确认的仓库名称、Private 可见性和本清单执行提交与推送。
校验上传文件清单；MATLAB 环境运行 Setup_JRD / Test_JRD_All。
未通过代码/数据哈希绑定验收前，不启动 formal 模式。
正式预算和独立实例方案在上传后确定，本轮未启动正式实验。
