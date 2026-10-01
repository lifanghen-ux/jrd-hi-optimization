# 清理清单与恢复方法（2026-10-01）

## 清理边界

本轮只整理老师审阅版分支 codex/teacher-review-20261001。删除下列67个已跟踪路径，使默认仓库不再混合旧入口/历史研究/重复文档；没有删除原研究工作目录、历史实验目录、Git历史或有效的完成结果。源码清理不是宣称旧研究“无效”。

保留四个原始Data_N*.mat、原AHDE、当前Direct成本内核、四个论文实验入口、主线测试及必要辅助工具。Setup_JRD与JRDProjectManifest仅更新活动目录，其他保留的科学.m文件与原研究代码逐字节相同。

完整源码恢复引用：

- 分支 [codex/paper-evolutionary](https://github.com/lifanghen-ux/jrd-hi-optimization/tree/codex/paper-evolutionary)。
- 清理前tag [archive/pre-teacher-cleanup-20261001](https://github.com/lifanghen-ux/jrd-hi-optimization/tree/archive/pre-teacher-cleanup-20261001)。
- 实验队列科学来源commit f8e9b9c302be7356da0054ca5fa29ece08e64928。
- 本机额外保存清理前Git bundle；原研究目录保留所有被Git忽略的历史结果。

历史resume应在完整原源码下进行。精简导致manifest改变，拒绝旧批次resume是正确保护；不重写旧manifest、不绕开一致性校验。完成证据复制后仍可load阅读。

## 分类理由

| 类别 | 处理理由 |
|---|---|
| 根目录旧GA/DE/ADE/JADE等 | 当前Exp2用公共目标partition adapters，不直接调用旧2N搜索；原AHDE保留 |
| Indirect_V1 / block-K / completed-search | 历史robustness研究，未进入这次Exp2/4展示依赖 |
| AHDE_FixedF1、RunLegacyDirectBaseline | 不再是正式主线；前者与原AHDE不止频率域不同 |
| 旧Main/Run入口、后台启动监控 | 与当前runner重复或已完成队列专用，避免误跑 |
| Tests/Oracles与旧全套测试 | 依赖完整历史源码，留完整分支；精简版使用当前paper gates |
| 旧审计/展示/上传计划文档 | 多处旧路径与主线变化，退出默认展示；保留有效协议和原结果审计 |

## 本次从默认展示树移除的67个路径

```text
ADE.m
ADE_Direct.m
AHDE_Direct.m
CODE_AUDIT.md
CODE_MAP.md
COMPLETION_SEARCH_DESIGN.md
DE.m
DE_Direct.m
Describe_Legacy_Solution.m
Docs/CHATGPT_REVIEW_MEETING_AND_EXPERIMENTS_2026-09-30.md
Docs/FOUR_EXPERIMENTS_MEETING_DEMO_2026-10-01.md
Docs/JRD_HI_ZERO_TO_CODE_TUTORIAL.md
Docs/PRELIMINARY_EVENING_REPORT_2026-10-01.md
Docs/PRE_RUN_AUDIT_2026-10-01.md
Docs/PROJECT_STATUS_2026-09-20.md
Docs/UNATTENDED_PRELIMINARY_2026-10-01.md
GA.m
GA_Direct.m
Generate_Data.m
IMPLEMENTATION_REPORT.md
INDIRECT_BLOCK_K_ABLATION.md
Indirect_V1/IndirectCostCache.m
Indirect_V1/IndirectCostFixed.m
Indirect_V1/IndirectInnerExact.m
Indirect_V1/IndirectInnerKernel.m
Indirect_V1/MS_VND_Indirect.m
Indirect_V1/VND_Indirect.m
JADE.m
JADE_Direct.m
Main_ADE_Test.m
Main_All_Algorithms_Test.m
Main_Batch_Experiment.m
Main_Verify.m
PAPER_MAINLINE.md
Paper_Experiments/AHDE_FixedF1.m
Paper_Experiments/RunLegacyDirectBaseline.m
Paper_Experiments/Run_Unattended_Preliminary_Queue.m
Paper_Experiments/Start_JRD_Preliminary_Queue.ps1
Paper_Experiments/Start_JRD_Reference_Exp3.ps1
Paper_Experiments/Watch_JRD_Preliminary_Queue.ps1
Paper_Experiments/Write_Unattended_Preliminary_Report.m
REPOSITORY_UPLOAD_PLAN.md
Run_Batch_Experiment.m
Run_Indirect_Block_Ablation.m
Run_Optimized_Experiment.m
Run_Strategy_Experiment.m
Shared/JRDCompleteSearch.m
Shared/JRDStrategyBounds.m
Test_Storage_Fix.m
Tests/Oracles/Legacy_ADE.m
Tests/Oracles/Legacy_ADE_Direct.m
Tests/Oracles/Legacy_AHDE.m
Tests/Oracles/Legacy_AHDE_Direct.m
Tests/Oracles/Legacy_DE.m
Tests/Oracles/Legacy_DE_Direct.m
Tests/Oracles/Legacy_GA.m
Tests/Oracles/Legacy_GA_Direct.m
Tests/Oracles/Legacy_JADE.m
Tests/Oracles/Legacy_JADE_Direct.m
Tests/Test_Indirect_Block_Search.m
Tests/Test_JRD_All.m
Tests/Test_JRD_Completion.m
Tests/Test_JRD_Mathematics.m
Tests/Test_JRD_Search.m
Tests/Test_N10_HitRate.m
Tests_Paper/Run_Preliminary_Audit_Tests.m
Tests_Paper/Test_Unattended_Queue.m
```

## 结果筛选

上传原样完成证据：Exp1 7文件、Exp2 130文件、Exp3 51文件、Exp4 29文件、profiling 10文件；计227个原始证据文件，另有新增索引与验证manifest。

不上传未执行计划、Gen1/2 smoke目录、已被108次复用的12次校准重复目录、启动日志与其他无关历史结果。它们仍保留本机；校准记录不是无效，也不能在总次数中重复相加。旧Exp4 Schema1 smoke不适合作为修正后同一AHDE两频率域的主证据。

源路径→发布路径、SHA256、字节数见 [delivery_file_manifest.csv](../Provenance/delivery_file_manifest.csv)。代码保留校验见 [active_source_manifest.csv](../Provenance/active_source_manifest.csv)。发布检查见 [release_validation.json](../Provenance/release_validation.json)。

本轮没有新正式长实验，没有重新制造数据、放大penalty或删掉不利结果。

