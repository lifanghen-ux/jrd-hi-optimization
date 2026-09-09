# 活动 MATLAB 调用关系

    Setup_JRD
      Shared / Direct_V1 / Indirect_V1 / Tests
      不递归添加 Backups

    Run_Optimized_Experiment
      JRDProjectManifest -> 代码/数据 SHA-256
      读取 Data_N10/N30/N50/N100.mat
      MS_VND_Direct
        全并 / 全拆 / Init_Greedy
        VND_Direct -> BestNeighbor_Direct
          relocate / merge / swap / split
        PerturbPartition -> 再次 VND
        GroupCostCache -> 枚举 F + 解析 T
      MS_VND_Indirect
        全 KInf / 独立周期比 / 随机 K
        VND_Indirect -> 单坐标全取值 / 双商品 K 交换
        随机多坐标扰动 -> 再次 VND
        IndirectCostCache -> IndirectInnerKernel
          按全部频率切换阈值分段 -> 精确 T/F
      唯一输出目录
        raw/*.mat / results.mat / raw_results.csv / summary.csv

    Test_JRD_All
      Test_JRD_Mathematics
        Oracles/Legacy_* -> 新旧一致性
        fminbnd -> 解析 T
        全频率穷举 -> IndirectInnerExact
        ExactDP_Direct + N6 独立划分穷举
      Test_JRD_Search -> 重现 / 预算 / 邻域 / 四规模短检查 / 新管线
      Test_Storage_Fix -> 旧管线短集成测试
      Validation_V1/readiness.mat

    Main_Batch_Experiment -> Run_Batch_Experiment
      旧 GA/DE/ADE/AHDE/JADE 及其 Direct 版本
      Describe_Legacy_Solution -> 复算固定解、保存真实 GroupT
      Results_Fixed/

    Main_Verify -> Fitness_Indirect
    Main_ADE_Test -> ADE
    Main_All_Algorithms_Test -> ADE/AHDE/GA/DE
    Generate_Data / Generate_Large_Data -> 输出目录、已有文件保护

ExactDP_Direct 仅作基准，不在 Direct 启发式的调用链中。
GroupCostFixedF 与 IndirectCostFixed 是公共 checked 复算接口。
所有缓存每次求解新建，绑定数据与边界，不跨实例或 run 重用。
