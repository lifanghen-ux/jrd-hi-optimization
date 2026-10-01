function Plot_Paper_Experiment2(Study,out)
%PLOT_PAPER_EXPERIMENT2 Table-3/Figure-6 style panels and common convergence.
% Cross-instance convergence uses percent gap to FINAL instance BKS, never
% pooled raw costs. Time is a performance axis, not a strategy cost criterion.
assert(strcmp(Study.Status,'complete'),'JRD:IncompletePlot','Plot final metrics only after all tasks complete.');
algorithms=Study.Algorithms; colors=lines(numel(algorithms));
fig=figure('Visible','off','Color','w','Position',[100 100 1100 360]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
metrics={'AverageRuntimeSeconds','BestCount','AverageGapPercent'};
labels={'Average runtime (seconds)','Best count (instances)','Average gap to instance BKS (%)'};
for panel=1:3
    subplot(1,3,panel); hold on;
    for a=1:numel(algorithms)
        rows=strcmp(Study.SummaryTable.Algorithm,algorithms{a});
        values=Study.SummaryTable(rows,:); [~,order]=sort(values.N); values=values(order,:);
        plot(values.N,values.(metrics{panel}),'-o','Color',colors(a,:), ...
            'DisplayName',algorithms{a},'LineWidth',1.2);
    end
    xlabel('N'); ylabel(labels{panel}); grid on;
    if panel==1, legend('Location','best','Interpreter','none'); end
end
exportgraphics(fig,fullfile(out,'performance_panels.png'),'Resolution',140);
savefig(fig,fullfile(out,'performance_panels.fig'));

scales=unique(Study.RawTable.N)'; curves=Study.ConvergenceTable;
convergence=figure('Visible','off','Color','w','Position',[100 100 850 280*numel(scales)]);
cleanupCurve=onCleanup(@() close(convergence)); %#ok<NASGU>
for ni=1:numel(scales)
    n=scales(ni); subplot(numel(scales),1,ni); hold on;
    maximum=max(curves.ElapsedSeconds(curves.N==n));
    axisTimes=linspace(0,max(maximum,eps),120);
    for a=1:numel(algorithms)
        rows=find(Study.RawTable.N==n&strcmp(Study.RawTable.Algorithm,algorithms{a}));
        runGaps=nan(numel(rows),numel(axisTimes));
        for r=1:numel(rows)
            raw=Study.RawTable(rows(r),:);
            selected=curves.N==n&strcmp(curves.Algorithm,algorithms{a})& ...
                strcmp(curves.InstanceID,raw.InstanceID{1})&curves.Run==raw.Run;
            checkpoints=curves(selected,:);
            [times,indices]=unique(checkpoints.ElapsedSeconds,'last');
            gap=100*(checkpoints.CommonBestTC(indices)-raw.ReferenceBestTC)/raw.ReferenceBestTC;
            available=axisTimes>=times(1);
            if numel(times)==1
                runGaps(r,available)=gap;
            else
                within=available&axisTimes<=times(end);
                runGaps(r,within)=interp1(times,gap,axisTimes(within),'previous');
                runGaps(r,axisTimes>times(end))=gap(end);
            end
        end
        % No value before a run's first checkpoint. Once stopped, its last
        % best feasible value is held; no extra search or time is fabricated.
        % Display only once every run has its first checkpoint: a changing
        % averaging cohort must not create artificial upward convergence.
        plot(axisTimes,mean(runGaps,1),'Color',colors(a,:), ...
            'DisplayName',algorithms{a},'LineWidth',1.2);
    end
    title(sprintf('N=%d: common grid convergence',n)); xlabel('Elapsed search time (seconds)');
    ylabel('Mean gap to BKS (%)'); grid on;
    legend('Location','best','Interpreter','none');
end
exportgraphics(convergence,fullfile(out,'common_convergence.png'),'Resolution',140);
savefig(convergence,fullfile(out,'common_convergence.fig'));
end
