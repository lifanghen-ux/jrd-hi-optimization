function Study=ResolvePaperStrategyTaskError(Study,ni,run,caseIndex,name)
%RESOLVEPAPERSTRATEGYTASKERROR Clear current failure, retain resolved history.
Study.Failures{ni,run,caseIndex}=[];
for e=1:numel(Study.ErrorRecords)
    record=Study.ErrorRecords(e);
    if record.N==Study.Config.NList(ni)&&record.Run==run&&strcmp(record.Strategy,name)&&~record.Resolved
        Study.ErrorRecords(e).Resolved=true;
        Study.ErrorRecords(e).ResolvedAt=datestr(now,30);
    end
end
end
