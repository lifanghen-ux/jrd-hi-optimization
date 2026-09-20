function out=CreatePaperOutput(root,experimentName,outputRoot)
%CREATEPAPEROUTPUT Never overwrite an earlier experiment invocation.
if nargin<3||isempty(outputRoot), outputRoot=fullfile(root,'Results_Paper',experimentName); end
if ~isfolder(outputRoot), mkdir(outputRoot); end
out=tempname(outputRoot); mkdir(out); mkdir(fullfile(out,'raw'));
end
