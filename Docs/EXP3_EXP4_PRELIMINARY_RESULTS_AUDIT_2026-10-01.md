# Exp3 / Exp4 preliminary 完整结果审计

审计日期：2026-10-01。后台两实验均完整结束；本文件根据实际 CSV/MAT、独立原输入成本重算和源码哈希核验记录整理，不包含未启动的补充实验。

## 1. 范围与预算

| 实验 | 完成 | 数据轴 | 算法重复 | 预算 |
|---|---:|---|---:|---|
| Exp3 | 40/40，0失败 | 原 Data_N10/30/50/100，每N一个固定实例 | 每策略5 seeds | G100、P4N、grid .001 |
| Exp4 | 16/16，0失败 | 同四份原固定输入 | 每情形1 seed | G500、P10N、grid .001 |

Exp3 两侧为新 Evolutionary-X Direct 和老师原 AHDE Indirect。Exp4 四情形为 Direct coordinated、Direct f=1、Indirect coordinated、Indirect F=1，各自重新优化外层。

同一阶段的两侧/四情形采用共同 generation/population 层级，但变量结构、搜索算子和实际评价工作不同，不能称严格等工作量或相同随机轨迹。AHDE 的 T 仍为原方法计算；Direct T 用公共离散网格。

数据、成本模型、penalty、Direct 的 S/跨组 penalty 定义和原 AHDE 搜索机制均未修改。源码/输入 manifest 与当前文件匹配，科学快照提交为 f8e9b9c302be7356da0054ca5fa29ece08e64928。

## 2. Exp3 策略结果

Saving(best) = 100×(IndirectBestTC−DirectBestTC)/IndirectBestTC。平均配对 saving 则对每个完整 seed 的 saving 取均值，不能与前者混用。

| N | Direct best TC | Indirect best TC | Saving(best)% | Mean paired saving% |
|---|---:|---:|---:|---:|
| 10 | 12059.262724 | 13112.331607 | 8.0311 | 8.5096 |
| 30 | 46734.363042 | 63856.284083 | 26.8132 | 26.6328 |
| 50 | 79143.928809 | 112213.064520 | 29.4700 | 28.6234 |
| 100 | 168041.848664 | 248519.897877 | 32.3829 | 31.0110 |

20个完整配对中 Direct 全部更低。核验40个 raw MAT、1,900条逐商品 solution 行齐全；Direct 保存 X/groups/T/f，不含 K；Indirect 保存合法 T/K/F。

从原 Data 独立重算五项成本最大差约4.37e-11，CSV五项和与TC最大差约4.07e-10，属于双精度/文本导出误差。收敛曲线均非增、终点与raw TC一致。seed与P/G一致，原AHDE源码及2N编码未变。

**重要限制**：20次AHDE在第93–100代仍出现最后改善，末20代改善约1.04%–4.77%。G100不是充分收敛证明。这是每N一个固定实例、指定solver和pilot预算下的最好可行成本比较，不是全局策略优劣证明；stronger Indirect/block-K仍需补充。

## 3. Exp4 协同配送结果

Saving = 100×(fixed TC−coordinated TC)/fixed TC。

| N | 策略 | coordinated TC | fixed TC | Saving% |
|---|---|---:|---:|---:|
| 10 | Direct | 12059.262724 | 12432.923149 | 3.0054 |
| 10 | Indirect | 12578.206003 | 13151.894450 | 4.3620 |
| 30 | Direct | 46819.981908 | 49098.615198 | 4.6409 |
| 30 | Indirect | 58635.535519 | 62669.773233 | 6.4373 |
| 50 | Direct | 78494.146947 | 83112.365550 | 5.5566 |
| 50 | Indirect | 106076.704167 | 114086.858641 | 7.0211 |
| 100 | Direct | 159852.046304 | 170408.813598 | 6.1950 |
| 100 | Indirect | 235386.503243 | 252897.982091 | 6.9243 |

完整16个raw/solution通过核验，从原输入独立重算五成本与TC最大差1.46e-11。8个fixed最终方案频率全部严格1；原AHDE fixed的500代checkpoint共95,000个F值全部为1。两种Indirect调用同一原AHDE，fixed只设FInf=FSup=1，未调用AHDE_FixedF1作为主算法。两个Direct也使用同一Evolutionary-X实现，仅f可行域不同。

8个配对均coordinated不高于fixed，anomaly=0。这不证明启发式每次都达到各域全局最优，只表示本批未发现nesting violation。每N每情形仅1seed，Std/CV不能作为稳定性结论，单配对Std=NaN是正确的缺失统计表示。

## 4. 同输入、同seed的预算响应观察

Exp4 coordinated使用的seed恰对应Exp3各N的run2：Exp3 BaseSeed=20261002、run2；Exp4 BaseSeed=20261003、run1；两者均按BaseSeed+1000003*N+run−1派生。输入与科学源码相同。因此可观察该固定seed的预算响应，但不能将它当成独立的多seed预算实验。

| N | Direct TC降低% | AHDE TC降低% |
|---|---:|---:|
| 10 | 0.0000 | 5.7044 |
| 30 | 1.6431 | 8.1758 |
| 50 | 3.7177 | 6.0443 |
| 100 | 6.3670 | 5.9046 |

预算变化同时涉及P和G，不是只改变一个因素的消融；P变化也使随机数轨迹不同。两侧均有可达质量提升，不能把pilot成本差视为纯粹策略结构效应。Exp4部分AHDE仍在第481–500代改善，500代也不是已证明充分收敛。

## 5. 保存、追踪与未做事项

共同结果根目录：

```text
Results_Unattended/Launch_20261001_132424_516_5c284a72/
  queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8/
    Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc/
    Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad/
```

各目录的study.mat/raw/*.mat包含完整输入、参数、seed、方案、成本和源码；raw_results.csv/solution_items.csv为逐次成本及商品方案；task_status.csv/failed_tasks.csv/errors.csv给出任务与错误状态。Exp3重点看comparison.csv/paired_comparison.csv；Exp4重点看paired_savings.csv/paired_summary.csv/anomalies.csv。

后台Exp3约7.14分钟、Exp4约38.91分钟，均没有时间截断。恢复单位为完整solver call，未完成的一次重跑，不声称能从原AHDE中间代恢复。

未启动Exp3 reference预算3seeds新批次，也未启动formal benchmark。可选reference launcher的DryRun目录只是工程测试，MATLAB PID为空，不算任何新实验。此次只完成数据审计与文档，不修改模型/算法或现存结果。
