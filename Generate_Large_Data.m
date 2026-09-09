% 文件名: Generate_Large_Data.m
function Generate_Large_Data(outputDir,seed)
    if nargin<1, outputDir = fileparts(mfilename('fullpath')); end
    if nargin<2, seed = 20260908; end
    validateattributes(seed,{'numeric'},{'scalar','integer','>=',0,'<=',2^32-1});
    N_list = [10, 30, 50, 100];
    % Preflight every target before creating any new dataset.
    for n = N_list
        filename = fullfile(outputDir,sprintf('Data_N%d.mat',n));
        assert(~isfile(filename),'JRD:ExistingData', ...
            'Dataset already exists; choose a new output directory: %s',filename);
    end
    if ~isfolder(outputDir), mkdir(outputDir); end
    priorRng = rng;
    rngCleanup = onCleanup(@() rng(priorRng)); %#ok<NASGU>
    rng(seed,'twister');
    generation.N_list = N_list;
    generation.Seed = seed;
    generation.MATLABVersion = version;
    
    for n = N_list
        data.N = n;
        % 根据论文表2的规则生成随机数据
        data.D = randi([500, 5000], 1, n);               % 需求率 [500, 5000]
        data.sw = randi([40, 100], 1, n);                % 次要订货成本 [40, 100]
        data.hw = 0.5 + 2.5 * rand(1, n);                % 中心仓库存成本 [0.5, 3.0]
        data.hr = data.hw .* (1.2 + 0.8 * rand(1, n));   % 零售商库存成本是中心仓的 [1.2,2.0) 倍
        data.sr = data.sw .* (0.1 + 0.28 * rand(1, n));  % 配送成本是次要订货的 0.1~0.38 倍
        
        % 异质品惩罚成本矩阵 (发生概率 0.1)
        p = zeros(n, n);
        for i = 1:n-1
            for j = i+1:n
                if rand() < 0.1 % 10% 的概率触发惩罚
                    % 惩罚值为两物品次要订货成本之和的 1.2~2 倍
                    p(i,j) = (data.sw(i) + data.sw(j)) * (1.2 + 0.8 * rand());
                end
            end
        end
        data.p = p;
        
        % 主要订货成本 S 取次要订货成本之和的 0.3 倍 (中间值)
        data.S = 0.3 * sum(data.sw);
        
        % 保存数据
        filename = fullfile(outputDir,sprintf('Data_N%d.mat', n));
        generation.RngStateAfterInstance = rng;
        save(filename, 'data','generation');
        fprintf('✅ 已成功生成大规模算例: %s\n', filename);
    end
end
