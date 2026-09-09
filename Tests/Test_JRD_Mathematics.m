function report=Test_JRD_Mathematics()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); Setup_JRD();
originalPath=path; pathCleanup=onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(root,'Tests','Oracles'));
originalRng=rng; rngCleanup=onCleanup(@() rng(originalRng)); %#ok<NASGU>
rng(732,'twister'); wall=tic;
loaded=load(fullfile(root,'Data_N10.mat'),'data'); d=NormalizeJRDData(loaded.data);
names={'GA','DE','ADE','AHDE','JADE'};
lcmTable=zeros(d.KSup);
for i=1:d.KSup, for j=1:d.KSup, lcmTable(i,j)=lcm(i,j); end, end
maxFixedError=0; maxIndirectError=0; maxTError=0; rawTError=0;
for repetition=1:40
    ids=randi(d.N,1,d.N); F=randi([d.FInf,d.FSup],d.N,1);
    X=[(ids(:)-0.5)/d.N;(F-d.FInf+0.5)/(d.FSup-d.FInf+1)];
    fixed=0;
    for q=unique(ids)
        idx=find(ids==q); [c,T,A,B]=GroupCostFixedF(idx,d,F(q)); fixed=fixed+c;
        rawNumeric=fminbnd(@(t) A/t+B*t/2,T/4,T*4,optimset('TolX',1e-14,'Display','off'));
        rawTError=max(rawTError,abs(rawNumeric-T));
        % Algebraically identical objective minus a constant:
        % (sqrt(A/t)-sqrt(B*t/2))^2 = A/t+B*t/2-sqrt(2*A*B).
        % This avoids loss of curvature from a large constant near the minimum.
        numeric=fminbnd(@(t) (sqrt(A/t)-sqrt(B*t/2))^2, ...
            T/4,T*4,optimset('TolX',1e-14,'Display','off'));
        maxTError=max(maxTError,abs(numeric-T));
        [exact,bf,bt]=GroupCostExact(idx,d);
        assert(exact<=c+1e-10*max(1,c));
        assert(abs(GroupCostFixedF(idx,d,bf)-exact)<1e-9 && bt>0);
    end
    for a=1:numel(names)
        oracle=str2func(['Legacy_' names{a} '_Direct']);
        args={X,d.KInf,d.KSup,d.FInf,d.FSup,d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N};
        if ~strcmp(names{a},'JADE'), args{end+1}=[]; end
        value=oracle(args{:});
        maxFixedError=max(maxFixedError,abs(value-fixed)/max(1,abs(value)));
    end
    relabeled=ids*7+15;
    one=PartitionCost(ids,d); two=PartitionCost(relabeled,d);
    assert(abs(one.TotalCost-two.TotalCost)<1e-9 && isequal(one.GroupId,two.GroupId));
    assert(one.TotalCost<=fixed+1e-9);
    K=randi([d.KInf,d.KSup],d.N,1);
    X=[(K-d.KInf+0.5)/(d.KSup-d.KInf+1);(F-d.FInf+0.5)/(d.FSup-d.FInf+1)];
    value=IndirectCostFixed(K,F,d);
    for a=1:numel(names)
        oracle=str2func(['Legacy_' names{a}]);
        old=oracle(X,d.KInf,d.KSup,d.FInf,d.FSup, ...
            d.sw,d.D,d.sr,d.hw,d.hr,d.S,d.p,d.N,lcmTable);
        maxIndirectError=max(maxIndirectError,abs(old-value)/max(1,value));
    end
    inner=IndirectInnerExact(K,d);
    assert(inner.TotalCost<=value+1e-9);
end
fprintf('Math diagnostics fixed=%.3g indirect=%.3g T=%.3g\n', ...
    maxFixedError,maxIndirectError,maxTError);
assert(maxFixedError<1e-10 && maxIndirectError<1e-10 && maxTError<1e-8);
% Tiny exhaustive fixed-K checks: all legal F, including equal/negative hr-hw.
small=d; small.N=3;
for name={'D','sw','sr','hw','hr'}, small.(name{1})=d.(name{1})(1:3); end
small.p=d.p(1:3,1:3); small.FInf=1; small.FSup=4;
maxInnerError=0;
for mode=1:4
    s=small;
    if mode==2, s.hr=s.hw; end
    if mode==3, s.hr=s.hw*0.8; end
    if mode==4, s.FInf=2; end
    for repetition=1:8
        K=randi([1,4],3,1); exact=IndirectInnerExact(K,s);
        brute=Inf;
        for a=s.FInf:s.FSup, for b=s.FInf:s.FSup, for c=s.FInf:s.FSup
            brute=min(brute,IndirectCostFixed(K,[a;b;c],s));
        end, end, end
        maxInnerError=max(maxInnerError,abs(exact.TotalCost-brute)/max(1,brute));
    end
end
assert(maxInnerError<1e-10);
% Label/F binding is covered by storage tests; cache isolation and bounds here.
[emptyCost,~,~]=GroupCostExact([],d); assert(emptyCost==0);
b=SearchBudget(Inf,Inf,'direct_group'); cache=GroupCostCache(d,b,2);
c1=cache.Get([1,3]); c2=cache.Get([3,1]); assert(c1==c2 && b.CacheHits==1);
cache.Get(2); cache.Get(4); assert(cache.Entries.Count<=2 && b.CacheResets==1);
different=d; different.S=d.S*2;
assert(GroupCostExact([1,3],different)>c1);
restricted=d; restricted.FInf=3; restricted.FSup=3;
[c,f]=GroupCostExact([1,2],restricted); assert(f==3);
assert(abs(c-GroupCostFixedF([1,2],restricted,3))<1e-9);
badCases={@() PartitionCost({[1,2],2:10},d), ...
    @() CanonicalizePartition([1,0]),@() GroupCostExact([1,1],d), ...
    @() IndirectInnerExact(zeros(d.N,1),d)};
for i=1:numel(badCases)
    threw=false; try, badCases{i}(); catch, threw=true; end
    assert(threw,'Invalid input was accepted.');
end
% N=10 full DP, not called inside the heuristic.
exact=ExactDP_Direct(d);
assert(abs(exact.TotalCost-12059.2516110867)<1e-8);
assert(abs(exact.DPValue-exact.TotalCost)<1e-9);
assert(isequal(exact.GroupF,[2,2]));
% Independent restricted-growth partition enumeration at N=6.
s=d; s.N=6;
for name={'D','sw','sr','hw','hr'}, s.(name{1})=d.(name{1})(1:6); end
s.p=d.p(1:6,1:6);
dp6=ExactDP_Direct(s); brute6=Inf; labels=ones(1,6); partitions=0;
enumerate(2,1);
assert(abs(brute6-dp6.TotalCost)<1e-8 && partitions==203);
report=struct('Status','PASS','FixedFRelativeError',maxFixedError, ...
    'IndirectRelativeError',maxIndirectError,'TAbsoluteError',maxTError, ...
    'IndirectInnerRelativeError',maxInnerError,'RawObjectiveTError',rawTError,'N10Exact',exact, ...
    'N6EnumeratedPartitions',partitions,'RuntimeSeconds',toc(wall), ...
    'MATLABVersion',version,'CompletedAt',datestr(now,30));
disp(rmfield(report,'N10Exact'));
    function enumerate(position,maximum)
        if position>6
            value=PartitionCost(labels,s); brute6=min(brute6,value.TotalCost);
            partitions=partitions+1; return;
        end
        for label=1:maximum+1
            labels(position)=label; enumerate(position+1,max(maximum,label));
        end
    end
end
