function [bestTC,bestT,bestK,bestF,TCArray,KArray,TArray]=AHDE_FixedF1( ...
    Gm,Np,KSup,KInf,sw,di,sr,hw,hr,S,pij,n)
%AHDE_FIXEDF1 Supplementary reduced-dimension K search with F fixed to one.
% This implementation changes chromosome dimension and random consumption.
% It is NOT used by the primary Experiment 4. Its two Indirect cases both
% call the original AHDE.m; fixed-F is obtained solely by FInf=FSup=1.
assert(Np>=4&&Gm>=1,'JRD:AHDEConfig','AHDE requires Np>=4 and Gm>=1.');
Fmin=0.2; Fmax=1.2; CR=0.2; X=rand(n,Np);
trialMutation=zeros(n,Np); trial=zeros(n,Np); scores=zeros(1,2*Np);
lcmArray=zeros(KSup,KSup);
for a=1:KSup, for b=1:KSup, lcmArray(a,b)=lcm(a,b); end, end
TCArray=zeros(1,Gm); KArray=cell(1,Gm); TArray=zeros(1,Gm);
for generation=1:Gm
    for i=1:Np
        pool=randperm(Np); pool(pool==i)=[];
        factor=Fmin+(Fmax-Fmin)*exp(1-Gm/(Gm+1-generation));
        trialMutation(:,i)=X(:,pool(1))+factor*(X(:,pool(2))-X(:,pool(3)));
        outside=trialMutation(:,i)>1|trialMutation(:,i)<0;
        trialMutation(outside,i)=rand(sum(outside),1);
    end
    for i=1:Np
        trial(:,i)=trialMutation(:,i); forced=randi(n);
        keepParent=rand(n,1)<=CR; keepParent(forced)=true;
        trial(keepParent,i)=X(keepParent,i);
    end
    for i=1:Np
        scores(i)=fitnessValue(trial(:,i)); scores(Np+i)=fitnessValue(X(:,i));
    end
    [sorted,index]=sort(scores); combined=[trial,X]; X=combined(:,index(1:Np));
    TCArray(generation)=sorted(1);
    [KArray{generation},TArray(generation)]=decodeValue(X(:,1));
end
bestTC=TCArray(end); bestK=KArray{end}; bestT=TArray(end); bestF=ones(n,1);
    function value=fitnessValue(chromosome)
        [K,T,A,B]=decodeValue(chromosome); %#ok<ASGLU>
        value=A/T+B*T/2;
    end
    function [K,T,A,B]=decodeValue(chromosome)
        K=min(KSup,floor(chromosome*(KSup-KInf+1))+KInf);
        penalty=0;
        for u=1:n-1
            for v=u+1:n
                if pij(u,v)>0, penalty=penalty+pij(u,v)/lcmArray(K(u),K(v)); end
            end
        end
        A=S+sum((sw+sr)./K)+penalty;
        B=sum(hr.*K.*di); % F=1 makes the warehouse term zero.
        T=sqrt(2*A/B);
    end
end
