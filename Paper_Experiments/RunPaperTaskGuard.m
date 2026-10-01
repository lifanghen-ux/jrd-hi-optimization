function [answer,failure]=RunPaperTaskGuard(taskFunction,continueOnTaskError)
%RUNPAPERTASKGUARD Record a local task failure; preserve fatal integrity errors.
assert(isa(taskFunction,'function_handle'),'JRD:TaskGuard','Expected a task function.');
if nargin<2, continueOnTaskError=false; end
assert(islogical(continueOnTaskError)&&isscalar(continueOnTaskError), ...
    'JRD:TaskGuard','ContinueOnTaskError must be a scalar logical.');
answer=[]; failure=[]; timer=tic;
try
    answer=taskFunction();
catch exception
    if ~continueOnTaskError||PaperTaskFailureIsFatal(exception), rethrow(exception); end
    failure=struct('Identifier',exception.identifier,'Message',exception.message, ...
        'Report',getReport(exception,'extended','hyperlinks','off'), ...
        'Stack',exception.stack,'At',datestr(now,30),'ElapsedSeconds',toc(timer), ...
        'IsGlobalBlocker',false);
end
end
