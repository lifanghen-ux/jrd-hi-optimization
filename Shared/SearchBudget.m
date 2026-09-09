classdef SearchBudget < handle
    % Cooperative stop at evaluator boundaries; one kernel can overrun time.
    properties
        Timer
        MaxSeconds
        MaxEvaluations
        Kind
        Requests = 0
        Evaluations = 0
        CacheHits = 0
        InnerCandidates = 0
        CacheResets = 0
    end
    methods
        function obj = SearchBudget(seconds,evaluations,kind)
            obj.Timer = tic;
            obj.MaxSeconds = seconds;
            obj.MaxEvaluations = evaluations;
            obj.Kind = kind;
        end
        function Check(obj)
            % Always allow one initial evaluation to obtain a feasible result.
            if obj.Evaluations>0 && toc(obj.Timer)>=obj.MaxSeconds
                error('JRD:BudgetExceeded','Wall-clock budget reached.');
            end
        end
        function Begin(obj)
            obj.Check();
            if obj.Evaluations>=obj.MaxEvaluations
                error('JRD:BudgetExceeded','Kernel evaluation budget reached.');
            end
            obj.Evaluations = obj.Evaluations+1;
        end
        function s = Snapshot(obj)
            s = struct('ElapsedSeconds',toc(obj.Timer),'Kind',obj.Kind, ...
                'Requests',obj.Requests,'KernelEvaluations',obj.Evaluations, ...
                'InnerCandidates',obj.InnerCandidates,'CacheHits',obj.CacheHits, ...
                'CacheResets',obj.CacheResets);
        end
    end
end
