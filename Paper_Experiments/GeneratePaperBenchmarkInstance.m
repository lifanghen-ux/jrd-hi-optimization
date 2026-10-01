function [data,generation]=GeneratePaperBenchmarkInstance(n,instanceSeed,varargin)
%GENERATEPAPERBENCHMARKINSTANCE Independent instance; never writes Data_N*.mat.
% Sampling (including penalty probability/magnitude) is unchanged from
% Generate_Large_Data. SFactor is an explicit benchmark scenario parameter.
validateattributes(n,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(instanceSeed,{'numeric'},{'scalar','integer','>=',0,'<=',2^32-1});
p=inputParser; addParameter(p,'SFactor',0.3,@(x) isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
parse(p,varargin{:}); o=p.Results;
prior=rng; cleanup=onCleanup(@() rng(prior)); %#ok<NASGU>
rng(instanceSeed,'twister');
data.N=n;
data.D=randi([500 5000],1,n);
data.sw=randi([40 100],1,n);
data.hw=0.5+2.5*rand(1,n);
data.hr=data.hw.*(1.2+0.8*rand(1,n));
data.sr=data.sw.*(0.1+0.28*rand(1,n));
data.p=zeros(n,n);
for i=1:n-1
    for j=i+1:n
        if rand()<0.1
            data.p(i,j)=(data.sw(i)+data.sw(j))*(1.2+0.8*rand());
        end
    end
end
data.S=o.SFactor*sum(data.sw);
generation=struct('Generator','GeneratePaperBenchmarkInstance', ...
    'SamplingReference','Generate_Large_Data unchanged demand/cost/penalty sampling', ...
    'InstanceSeed',instanceSeed,'SFactor',o.SFactor,'MATLABVersion',version, ...
    'RngStateAfterInstance',rng,'PenaltyProbability',0.1, ...
    'PenaltyMagnitudeFactorRange',[1.2 2.0]);
end
