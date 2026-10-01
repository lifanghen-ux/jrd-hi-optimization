function answer=RecoverPaperStrategyRecord(path,data,name,run,seed,population,generations,gridStep)
%RECOVERPAPERSTRATEGYRECORD Recover a raw commit made just before study.mat.
loaded=load(path,'record'); record=loaded.record;
actualName='';
if isfield(record,'Strategy'), actualName=record.Strategy; end
if isfield(record,'Case'), actualName=record.Case; end
assert(record.N==data.N&&record.Run==run&&record.Seed==seed&&strcmp(actualName,name), ...
    'JRD:StaleRawRecord','Raw solution identity does not match this checkpoint.');
answer=record.Answer;
assert(answer.Seed==seed&&answer.Options.PopulationSize==population&&answer.Options.Generations==generations, ...
    'JRD:StaleRawRecord','Raw solution budget/seed does not match this checkpoint.');
kind='Indirect';
if startsWith(name,'Direct')
    kind='Direct';
    assert(answer.Options.GridStep==gridStep,'JRD:StaleRawRecord','Raw Direct grid step changed.');
end
if endsWith(name,'_F1')
    assert(isequal(answer.Options.FixedF,1),'JRD:StaleRawRecord','The fixed-frequency case is mislabeled.');
elseif isfield(answer.Options,'FixedF')
    assert(isempty(answer.Options.FixedF),'JRD:StaleRawRecord','A coordinated case has a fixed frequency option.');
end
JRDAnalyzeSolution(data,answer,kind);
end
