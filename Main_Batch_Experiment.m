% Run the existing five algorithms with reproducible, traceable storage.
% Change N_list to [10, 30, 50, 100] for all four existing instances.
clc; clear; close all;
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir);
N_list = [100];
Gm = 1000;
NpFactor = 20;
Runs = 1; % Use 30 for a formal repeated-run experiment.
BaseSeed = 20260908;
[Results, ResultDir] = Run_Batch_Experiment( ...
    'NList', N_list, 'Gm', Gm, 'NpFactor', NpFactor, ...
    'Runs', Runs, 'BaseSeed', BaseSeed);
fprintf('Saved results to: %s\n', ResultDir);
