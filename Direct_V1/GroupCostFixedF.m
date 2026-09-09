function [cost,T,A,B] = GroupCostFixedF(items,d,f)
% Public checked evaluator; the fast cache uses the same algebra.
d = NormalizeJRDData(d);
if isempty(items), cost=0; T=NaN; A=0; B=0; return; end
validateattributes(items,{'numeric'},{'vector','integer','>=',1,'<=',d.N});
assert(numel(unique(items))==numel(items),'JRD:DuplicateItem','Repeated item in a group.');
validateattributes(f,{'numeric'},{'scalar','integer','>=',d.FInf,'<=',d.FSup});
items = sort(items(:));
A = d.S + sum(d.sw(items)) + f*sum(d.sr(items)) + ...
    sum(sum(d.PUpper(items,items)));
B = sum(d.D(items).*(d.hw(items)+(d.hr(items)-d.hw(items))/f));
T = sqrt(2*A/B);
cost = A/T+B*T/2;
end
