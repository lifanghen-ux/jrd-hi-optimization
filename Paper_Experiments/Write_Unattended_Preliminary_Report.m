function Write_Unattended_Preliminary_Report(Queue,out)
%WRITE_UNATTENDED_PRELIMINARY_REPORT Readable index; scientific results in CSV/MAT.
path=fullfile(out,'REPORT.md'); temporary=[tempname(out),'.md'];
fid=fopen(temporary,'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'# JRD-HI 下午无人值守 preliminary 汇报\n\n');
fprintf(fid,'状态：%s。更新：%s。Git：%s。\n\n',Queue.Status,datestr(now,31),Queue.GitCommit);
fprintf(fid,'目标：完成可审计的一批 preliminary，非论文 final formal benchmark。Exp1保持冻结。\n\n');
fprintf(fid,'当前阶段：%s。已提交的独立完成任务：%d。软截止：%s（只决定新阶段，不中断solver）。\n\n', ...
    Queue.CurrentStage,Queue.CommittedUniqueTasks,Queue.Deadline);
fprintf(fid,'当前阶段逐任务实时数见 live_progress.md；完整科学配置/源码在queue.mat及各study.mat。\n\n');
fprintf(fid,'## Profiling\n\n真实单次wall-clock见profiling_summary.csv；原完整解：%s。\n\n',Queue.ProfileDirectory);
profile=readtable(fullfile(out,'profiling_summary.csv'));
fprintf(fid,'|算法|N|Pop|Gen|真实秒|\n|---|---:|---:|---:|---:|\n');
for j=1:height(profile)
    fprintf(fid,'|%s|%d|%d|%d|%.3f|\n',profile.Algorithm{j},profile.N(j), ...
        profile.Population(j),profile.Generations(j),profile.WallClockSeconds(j));
end
fprintf(fid,'\nGA/JADE为正式Direct partition adapters。VND无自然代数；P/G只用于派生cap。AHDE的T仍原解析，不使用Direct网格。\n\n');
if isfield(Queue,'Exp2Choice')
    z=Queue.Exp2Choice;
    fprintf(fid,'Exp2选择：%d条记录（%d instances/N × %d seeds/instance × 3N × 4alg）。12条校准真实总秒%.3f；70%%时间余量。\n\n', ...
        z.TotalTasks,z.Instances,z.Runs,z.CalibrationWallSeconds);
end
fprintf(fid,'## 已运行阶段\n\n|阶段|状态|完成/计划|复用|失败|本阶段秒|目录|\n|---|---|---:|---:|---:|---:|---|\n');
for j=1:numel(Queue.Stages)
    stage=Queue.Stages{j};
    fprintf(fid,'|%s|%s|%d/%d|%d|%d|%.1f|%s|\n',stage.Name,stage.Status, ...
        stage.CompletedTasks,stage.ExpectedTasks,stage.ReusedTasks,stage.FailedTasks,stage.WallClockSeconds,stage.Directory);
end
fields={'Exp2Directory','Exp3Directory','Exp4Directory'};
for k=1:numel(fields)
    if ~isfield(Queue,fields{k})||isempty(Queue.(fields{k})), continue; end
    directory=Queue.(fields{k}); saved=load(fullfile(directory,'study.mat'),'Study'); study=saved.Study;
    fprintf(fid,'\n## %s\n\n状态：%s。结果目录：%s\n\n',fields{k},study.Status,directory);
    if isfield(study,'SummaryTable')
        table=study.SummaryTable; text=evalc('disp(table)'); fprintf(fid,'```text\n%s```\n\n',text);
    end
    if isfield(study,'Comparison')
        table=study.Comparison; text=evalc('disp(table)'); fprintf(fid,'```text\n%s```\n\n',text);
    end
    if isfield(study,'PairedSummary')
        table=study.PairedSummary; text=evalc('disp(table)'); fprintf(fid,'```text\n%s```\n\n',text);
    end
    fprintf(fid,'关键文件：summary.csv、raw_results.csv、study.mat、raw/*.mat、task_status.csv、failed_tasks.csv；CSV完整解/五成本见各目录。\n\n');
    if isfield(study,'FailedTaskTable'), failures=study.FailedTaskTable;
    elseif isfield(study,'FailedTasks'), failures=study.FailedTasks;
    else, failures=[]; end
    if height(failures)>0
        fprintf(fid,'未解决失败数：%d；不要把缺失任务当完整配对。\n\n',height(failures));
    end
end
fprintf(fid,'## 未运行/异常\n\n');
for j=1:numel(Queue.Skipped), fprintf(fid,'- %s\n',Queue.Skipped{j}); end
if isfield(Queue,'Blocker'), fprintf(fid,'全局阻断：[%s] %s\n',Queue.Blocker.Identifier,Queue.Blocker.Message); end
fprintf(fid,'\n结论边界：BKS是启发式最好可行值；只有小规模网格证书可证明网格全局最优。不同instance与algorithm seed分开。Std/CV在同实例内计算。Exp3/4仅固定实例初步趋势。协同高于固定解是search insufficiency，不是模型结论。所有原始Data/penalty/S定义/AHDE核心保持不变。\n');
clear cleanup;
[ok,message]=movefile(temporary,path,'f'); assert(ok,'JRD:ResultWrite','%s',message);
end
