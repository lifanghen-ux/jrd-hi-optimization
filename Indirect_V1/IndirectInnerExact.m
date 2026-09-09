function result = IndirectInnerExact(K,data)
d=NormalizeJRDData(data);
validateattributes(K,{'numeric'},{'vector','numel',d.N,'finite','integer','>=',d.KInf,'<=',d.KSup});
[result,result.Intervals]=IndirectInnerKernel(K,d);
end
