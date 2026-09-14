function JRDAtomicSave(path,payload)
% Recoverable same-directory checkpoint. Never expose a half-written target.
folder=fileparts(path); if ~isfolder(folder), mkdir(folder); end
temporary=[tempname(folder),'.mat'];
save(temporary,'payload','-v7');
if isfile(path), copyfile(path,[path,'.previous'],'f'); end
[ok,message]=movefile(temporary,path,'f');
assert(ok,'JRD:CheckpointWrite','%s',message);
end
