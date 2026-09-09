% 文件名: Generate_Data.m
function Generate_Data(outputDir)
    if nargin<1, outputDir = fileparts(mfilename('fullpath')); end
    outputPath = fullfile(outputDir,'testDataN6_Paper.mat');
    assert(~isfile(outputPath),'JRD:ExistingData', ...
        'Dataset already exists; choose a new output directory: %s',outputPath);
    if ~isfolder(outputDir), mkdir(outputDir); end
    % 1. 基础成本参数 (来自论文表4)
    S = 200;
    D = [10000, 5000, 3000, 1000, 600, 200];
    sw = [45, 46, 47, 44, 45, 47];
    sr = [5, 5, 5, 5, 5, 5];
    hw = [1, 1, 1, 1, 1, 1];
    hr = [1.5, 1.5, 1.5, 1.5, 1.5, 1.5];
    N = 6;

    % 2. 异质品惩罚成本矩阵 (来自论文表5)
    % 只需要填写上三角矩阵即可 (i < j)
    p = zeros(N, N);
    p(1,2) = 40;
    p(1,5) = 75;
    p(2,3) = 35;
    p(3,5) = 45;
    p(5,6) = 20;

    % 3. 保存为结构体，方便传递
    data.S = S; 
    data.D = D; 
    data.sw = sw; 
    data.sr = sr;
    data.hw = hw; 
    data.hr = hr; 
    data.p = p; 
    data.N = N;

    save(outputPath, 'data');
    fprintf('Saved dataset: %s\n',outputPath);
end
