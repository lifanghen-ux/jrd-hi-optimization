# JRD-HI optimization in MATLAB

研究异质品联合补货—配送的 Direct 与 Indirect 策略。
目标是在相同模型、相同实例和可追溯计算预算下比较高质量成本解。
Direct 更优是待检验假设，不是程序中的约束。

## 当前状态

已实现两侧新求解器、精确数学验证、旧算法存储修复和新实验入口。
MATLAB R2024a 为本机验收环境。主要计算使用基础 MATLAB；
SHA-256 清单使用 MATLAB 自带 JVM。没有调用 Optimization Toolbox 或 Parallel Computing Toolbox。
正式实验尚未运行，具体测试结果见 IMPLEMENTATION_REPORT.md。

## 使用

在工程根目录执行：

    Setup_JRD;
    readiness = Test_JRD_All;

测试覆盖十套旧 fitness、小规模穷举、N=10 Direct 全局最优、种子重现、
预算终止、四规模短检查和结果管线。
Validation_V1/readiness.mat 绑定活动 MATLAB 文件及固定数据的 SHA-256。
更改代码或数据后，正式入口要求重新验证。

单个求解器：

    loaded = load('Data_N10.mat','data');
    d = loaded.data;
    direct = MS_VND_Direct(d,'Seed',42,'MaxSeconds',10);
    indirect = MS_VND_Indirect(d,'Seed',42,'MaxSeconds',10);
    exact = ExactDP_Direct(d);  % N<=16, exponential time

短管线验证：

    [R,out] = Run_Optimized_Experiment('Phase','validation', ...
        'NList',10,'Runs',2,'Seconds',2);

测试通过并确定正式预算后显式启动：

    [R,out] = Run_Optimized_Experiment('Phase','formal', ...
        'NList',[10 30 50 100],'Runs',30,'Seconds',60,'BaseSeed',20260909);

此示例是四个固定实例的稳定性研究，不是 120 个独立问题实例。
每个策略每次约 60 秒搜索，约需 4 小时搜索总量，另有启动、复算与保存开销。
协作式计时可能超出一个评价内核及收尾检查的时间，不是硬实时中断。

## 模块与原理

- Direct_V1：规范标签、精确 F/T、组缓存、贪心、多起点、四邻域、VND、ILS、子集 DP。
- Indirect_V1：固定 K 的精确 T/F 阈值扫描、整数 K 邻域、多起点、ILS。
- Shared：数据验证、预算、文件清单。
- Tests：数学、搜索、保存集成测试；Oracles 是旧 fitness 的测试副本。
- 根目录十个 GA/DE/ADE/AHDE/JADE 算法文件：历史基线，保持原搜索逻辑。
- Run_Batch_Experiment：旧五算法的代数/种群预算管线。
- Run_Optimized_Experiment：新 Direct/Indirect 等搜索时间管线。

沿用源码正上三角 penalty：Direct 只计同组 pair，Indirect 使用 LCM。
输入字段是 data.N/D/sw/sr/hw/hr/p/S，默认 K、F 均为 1..20。
归一化只建立内部副本，不改写 MAT。

Direct 枚举组内全部 F 并解析 T；商品分组仍是启发式。
Indirect 对固定 K 扫描全部 F 切换阈值，精确求 T/F；外层 K 仍是启发式。
ExactDP_Direct 提供小规模证书，新启发式不调用它，也不含 N=10 特判。

组评价与固定 K 联合评价是不同工作量，不能当作公平等评估预算。
分别记录 KernelEvaluations、InnerCandidates、CacheHits、邻域候选数及收敛。
等时间模式在达到配置起点数后继续新起点，直至时间预算耗尽。

## 结果与限制

每次实验创建唯一目录，保存输入/源码/哈希、seed、参数、完整解、
搜索/总耗时、收敛、raw MAT、汇总 MAT 和 CSV。
未完成任务以 NaN 表示，出错保留已完成任务。检查点保存进度，
当前不支持自动续跑中断目录。

Saving = 100*(TC_Indirect-TC_Direct)/TC_Indirect，正值为 Direct 更优。
DirectSeedWinRate 是同一固定实例上的种子胜率，不是独立实例胜率。
大规模解只能称 BKS，稳定命中不等于全局证书。

## 查看实验进度和结果

建议先运行上述 Test_JRD_All（本机约 1–3 分钟），再做四规模短验证：

    [check,checkDir] = Run_Optimized_Experiment('Phase','validation', ...
        'NList',[10 30 50 100],'Runs',2,'Seconds',2);

该短验证共 16 次求解，搜索预算合计约 32 秒，加上保存等开销。
通过后再手动运行上面的 formal 命令：4 个规模 × 30 个种子 × 2 个策略，
共 240 次求解，60 秒/次，合计约 4 小时加额外开销。不会自动启动。
每对 Direct/Indirect 使用同一数据和种子，交替先后顺序。

运行时 MATLAB 命令窗口每完成一次求解打印规模、策略、次数、成本和时间。
Results_Optimized 下最新的唯一目录中，raw 子目录每完成一次增加一个 MAT；
正式配置最终应有 240 个 raw 文件。results.mat 每次完成后更新，CSV 在全部完成后生成。
MATLAB 忙于运行时，可用 Windows 文件资源管理器查看文件进度。
保持电脑接通电源、不休眠；Ctrl+C 中断会保留此前保存的任务，但目前不支持自动续跑。

完成后，在同一 MATLAB 会话执行：

    disp(out);
    disp(R.SummaryTable);
    winopen(out);

summary.csv 汇总最低/平均/中位/最差成本、标准差、运行时间及配对节约率；
raw_results.csv 记录每个种子的两侧成本。Saving_Percent 为正表示 Direct 更优。
以后重新查看时，将下面路径替换为本次 out 显示的实际目录：

    saved = load(fullfile('本次结果目录','results.mat'),'Results');
    R = saved.Results;
    disp(R.SummaryTable);

查看第一个规模、第一次 Direct 求解的实际分组、频率、周期和收敛曲线：

    a = R.Records{2,1,1}.Answer;
    disp(a.Groups); disp(a.GroupF); disp(a.GroupT);
    plot(a.Convergence(:,1),a.Convergence(:,2));
    xlabel('Search time (seconds)'); ylabel('Best cost');

Records 的第一维 1=Indirect、2=Direct；第二维按 NList，第三维是运行编号。
新管线不自动导出图像。N=10 Direct 的已验证全局最优成本为 12059.2516110867；
其他大规模结果是当前最好可行解，不能仅凭重复运行稳定就称全局最优。
这轮先检验四个固定实例的搜索稳定性；若要支持不同规模普遍更优的猜想，
还需另行设计每规模多个独立实例及参数敏感性实验。

## 私有仓库

用户已确认创建并上传至 lifanghen-ux/jrd-hi-optimization，Private。
仓库地址：https://github.com/lifanghen-ux/jrd-hi-optimization 。
拟上传活动代码、五个固定数据、测试与文档。
不拟上传论文、签名图片、历史 ZIP/Excel/PNG、不可追溯零值 MAT 或自动生成目录。
保留基线源码原署名；未经权利人决定，不擅自附加开源许可证。
