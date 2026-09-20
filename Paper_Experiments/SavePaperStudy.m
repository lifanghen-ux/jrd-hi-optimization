function SavePaperStudy(path,Study)
%SAVEPAPERSTUDY Atomic same-directory save using a stable variable name.
folder=fileparts(path); if ~isfolder(folder), mkdir(folder); end
temporary=[tempname(folder),'.mat']; save(temporary,'Study','-v7');
[ok,message]=movefile(temporary,path,'f'); assert(ok,'JRD:ResultWrite','%s',message);
end
