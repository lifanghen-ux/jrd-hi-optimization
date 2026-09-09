function [cost,T,A,B] = IndirectCostFixed(K,F,data)
d=NormalizeJRDData(data);
K=K(:); F=F(:);
validateattributes(K,{'numeric'},{'numel',d.N,'integer','>=',d.KInf,'<=',d.KSup});
validateattributes(F,{'numeric'},{'numel',d.N,'integer','>=',d.FInf,'<=',d.FSup});
penalty=0;
[i,j,value]=find(d.PUpper);
for q=1:numel(value), penalty=penalty+value(q)/lcm(K(i(q)),K(j(q))); end
A=d.S+sum((d.sw+F.*d.sr)./K)+penalty;
B=sum(K.*d.D.*(d.hw+(d.hr-d.hw)./F));
T=sqrt(2*A/B); cost=A/T+B*T/2;
end
