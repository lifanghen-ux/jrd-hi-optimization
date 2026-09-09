function d = NormalizeJRDData(input)
% Internal copy; preserve the legacy convention: positive upper triangle only.
required = {'N','D','sw','sr','hw','hr','S','p'};
assert(isstruct(input) && isscalar(input) && all(isfield(input,required)), ...
    'JRD:InvalidData','Expected one data struct with all model fields.');
d = input;
validateattributes(d.N,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(d.S,{'numeric'},{'scalar','positive','finite'});
for name = {'D','sw','sr','hw','hr'}
    value = d.(name{1});
    validateattributes(value,{'numeric'},{'vector','numel',d.N,'positive','finite','real'});
    d.(name{1}) = double(value(:));
end
validateattributes(d.p,{'numeric'},{'size',[d.N,d.N],'finite','real'});
d.PUpper = max(triu(double(d.p),1),0);
d.PSym = d.PUpper + d.PUpper';
for name = {'FInf','KInf'}
    if ~isfield(d,name{1}), d.(name{1}) = 1; end
end
for name = {'FSup','KSup'}
    if ~isfield(d,name{1}), d.(name{1}) = 20; end
end
for name = {'FInf','FSup','KInf','KSup'}
    validateattributes(d.(name{1}),{'numeric'},{'scalar','positive','integer','finite'});
end
assert(d.FInf<=d.FSup && d.KInf<=d.KSup,'JRD:InvalidBounds','Invalid integer bounds.');
[d.PairI,d.PairJ,d.PairPenalty]=find(d.PUpper);
[i,j]=ndgrid(1:d.KSup,1:d.KSup);
d.LcmTable=(i.*j)./gcd(i,j);
end
