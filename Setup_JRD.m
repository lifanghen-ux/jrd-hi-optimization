function root = Setup_JRD()
% Add only active code folders, never backups or historical result folders.
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'Shared'),fullfile(root,'Direct_V1'), ...
    fullfile(root,'Indirect_V1'),fullfile(root,'Evolutionary_Direct'), ...
    fullfile(root,'Paper_Experiments'),fullfile(root,'Tests'),fullfile(root,'Tests_Paper'));
end
