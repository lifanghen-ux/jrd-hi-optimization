function SavePaperStrategyRecord(path,record)
%SAVEPAPERSTRATEGYRECORD Atomic raw solution save, independent of study.mat.
folder=fileparts(path); if ~isfolder(folder), mkdir(folder); end
temporary=[tempname(folder),'.mat']; save(temporary,'record','-v7');
[ok,message]=movefile(temporary,path,'f');
assert(ok,'JRD:ResultWrite','%s',message);
end
