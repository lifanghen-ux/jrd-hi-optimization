function [result,intervals] = IndirectInnerKernel(K,d)
% Exact joint T/F minimization for fixed integer K by frequency breakpoints.
% d must be normalized by the public API or per-search cache.
K=K(:);
F=repmat(d.FInf,d.N,1);
delta=K.*d.D.*(d.hr-d.hw);
alpha=d.sr./K;
indices=sub2ind(size(d.LcmTable),K(d.PairI),K(d.PairJ));
penalty=sum(d.PairPenalty./d.LcmTable(indices));
A=d.S+sum((d.sw+F.*d.sr)./K)+penalty;
B=sum(K.*d.D.*d.hw+delta./F);
threshold=[]; item=[];
for i=1:d.N
    if delta(i)>0
        fs=d.FInf:d.FSup-1;
        threshold=[threshold,sqrt(2*alpha(i)*fs.*(fs+1)/delta(i))]; %#ok<AGROW>
        item=[item,repmat(i,1,numel(fs))]; %#ok<AGROW>
    end
end
[threshold,order]=sort(threshold); item=item(order);
edges=[threshold,Inf];
left=0; best=Inf; bestF=F; bestT=NaN;
intervals=numel(edges);
for e=1:intervals
    right=edges(e);
    t=min(max(sqrt(2*A/B),left),right);
    cost=A/t+B*t/2;
    if cost<best
        best=cost; bestF=F; bestT=t;
    end
    if e<intervals
        i=item(e); old=F(i);
        F(i)=old+1; A=A+alpha(i);
        B=B+delta(i)*(1/(old+1)-1/old);
        left=right;
    end
end
% Recompute without cumulative updates to remove sweep roundoff.
A=d.S+sum((d.sw+bestF.*d.sr)./K)+penalty;
B=sum(K.*d.D.*(d.hw+(d.hr-d.hw)./bestF));
cost=A/bestT+B*bestT/2;
result=struct('TotalCost',cost,'K',K,'F',bestF,'T',bestT, ...
    'Certificate','exact T/F optimum conditional on this K');
end
