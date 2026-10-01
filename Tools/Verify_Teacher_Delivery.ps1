param(
    [Parameter(Mandatory=$true)][string]$ResearchRoot,
    [string]$ReleaseRoot=(Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference='Stop'
function Get-SharedSHA256([string]$LiteralPath){
    # Permit read-only verification while Excel/OneDrive has the file open.
    for($attempt=1;$attempt -le 3;$attempt++){
        $stream=$null; $hasher=$null
        try{
            $before=Get-Item -LiteralPath $LiteralPath
            $beforeLength=$before.Length; $beforeWrite=$before.LastWriteTimeUtc
            $stream=[System.IO.File]::Open($LiteralPath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            $hasher=[System.Security.Cryptography.SHA256]::Create()
            $value=([System.BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','')
            $after=Get-Item -LiteralPath $LiteralPath
            if($beforeLength -ne $after.Length -or $beforeWrite -ne $after.LastWriteTimeUtc){throw "File changed while verifying: $LiteralPath"}
            return $value
        }catch{
            if($attempt -eq 3){throw}
            Start-Sleep -Milliseconds 500
        }finally{
            if($stream){$stream.Dispose()}
            if($hasher){$hasher.Dispose()}
        }
    }
}
$research=(Resolve-Path -LiteralPath $ResearchRoot).Path
$release=(Resolve-Path -LiteralPath $ReleaseRoot).Path
$queue='Results_Unattended/Launch_20261001_132424_516_5c284a72/queue/tp036a971b_6f0e_4e58_8004_c9acbad7dbe8'
$mappings=@(
    @('Results_Paper/Experiment1_N10/tp3868eb85_8520_4b45_80bf_e78405f24440','Results/Exp1_N10'),
    @(($queue+'/Exp2_Selected_108/tp17fc9f8a_8163_474e_b7f9_30461d204815'),'Results/Exp2_DirectPerformance'),
    @(($queue+'/Exp3_Preliminary/tp8bf3e3a3_d897_4509_bb0f_4ef46a1339cc'),'Results/Exp3_StrategyComparison'),
    @(($queue+'/Exp4_Preliminary/tp8e1c1f75_f70d_432f_9916_fd0ce1f981ad'),'Results/Exp4_Coordination'),
    @('Results_Profiling/tp6c56a870_ff62_4eb7_81d4_6a49d9f6fc62','Results/Profiling')
)
$fileRows=foreach($mapping in $mappings){
    $sourceFolder=Join-Path $research $mapping[0]
    $targetFolder=Join-Path $release $mapping[1]
    foreach($source in Get-ChildItem -LiteralPath $sourceFolder -File -Recurse){
        $relative=$source.FullName.Substring($sourceFolder.Length+1).Replace('\','/')
        $target=Join-Path $targetFolder $relative
        if(-not(Test-Path -LiteralPath $target -PathType Leaf)){throw "Missing copied evidence: $target"}
        $originalHash=Get-SharedSHA256 $source.FullName
        $copiedHash=Get-SharedSHA256 $target
        if($originalHash -ne $copiedHash){throw "Evidence changed: $target"}
        [pscustomobject]@{
            SourcePath=($mapping[0]+'/'+$relative)
            ReleasePath=($mapping[1]+'/'+$relative)
            Bytes=$source.Length
            SHA256=$copiedHash
        }
    }
}
if(@($fileRows).Count -ne 227){throw 'Expected exactly 227 original evidence files'}
$sourceRows=foreach($source in Get-ChildItem -LiteralPath $release -Filter '*.m' -File -Recurse){
    $relative=$source.FullName.Substring($release.Length+1).Replace('\','/')
    $oldFile=Join-Path $research $relative
    $oldHash=Get-SharedSHA256 $oldFile
    $newHash=Get-SharedSHA256 $source.FullName
    $engineeringOnly=$relative -in @('Setup_JRD.m','Shared/JRDProjectManifest.m')
    if(($newHash -ne $oldHash) -and -not $engineeringOnly){throw "Scientific MATLAB source changed: $relative"}
    [pscustomobject]@{RelativePath=$relative;OriginalSHA256=$oldHash;ReleaseSHA256=$newHash;Changed=$newHash -ne $oldHash;Reason=$(if($engineeringOnly){'Active-folder packaging only'}else{'Unchanged scientific source'})}
}
$protected=@{
    'AHDE.m'='D1BA45F4B91C1C36FE8F9E52A9931229BBA42B9A0ED1FA6FD75489EF1F73F3BE'
    'Data_N10.mat'='4153BBD3302EF7D0E4BEB8F197B7513116944AE4F0DB58EF2624CF82C067F7B6'
    'Data_N30.mat'='70C9CDC4186214B3BAA7C8A3878F21E2B241B2E77D8FF409EEAD6D6E0941F9FD'
    'Data_N50.mat'='C6CD72516E0CEA7E0374038DF976BAF1A72F75C568614D4BF4A76DF9156D6DF8'
    'Data_N100.mat'='F0F692635058B809CB81A87989E091A454DCC160C9F7B043022C60581B6AE2EB'
    'Results/Exp1_N10/runs.csv'='16741F91930B1AFBB4EA9A90D497C355B1832CA0DA971F365096109D7A94B5C1'
    'Results/Exp1_N10/study.mat'='5F87AC294B40EF4476B12E70C443CA77DB6C4C0A896D834E92B3F02A76B507B6'
}
foreach($path in $protected.Keys){
    if((Get-SharedSHA256 (Join-Path $release $path)) -ne $protected[$path]){throw "Protected file changed: $path"}
}
$e2=@(Import-Csv -LiteralPath (Join-Path $release 'Results/Exp2_DirectPerformance/raw_results.csv'))
$e4=@(Import-Csv -LiteralPath (Join-Path $release 'Results/Exp4_Coordination/raw_results.csv'))
if($e2.Count -ne 108 -or $e4.Count -ne 16){throw 'Wrong completed task count'}
$maxCostError=0.0
foreach($case in @(@{Rows=$e2;Cost='CommonGridTC'},@{Rows=$e4;Cost='TotalCost'})){
    foreach($row in $case.Rows){
        $sum=0.0
        foreach($part in @('OrderingCost','DeliveryCost','WarehouseHoldingCost','RetailHoldingCost','PenaltyCost')){$sum += [double]$row.$part}
        $error=[math]::Abs($sum-[double]$row.($case.Cost))
        $maxCostError=[math]::Max($maxCostError,$error)
        if($error -gt 0.000001){throw 'Five-part cost sum mismatch'}
    }
}
$fixed=@(Import-Csv -LiteralPath (Join-Path $release 'Results/Exp4_Coordination/solution_items.csv') | Where-Object { $_.Strategy -match '_F1$' })
if($fixed.Count -ne 380){throw 'Expected 380 fixed-frequency item records'}
if(@($fixed|Where-Object{[double]$_.Frequency -ne 1}).Count -ne 0){throw 'Fixed-frequency solution is not exactly one'}
$anomalies=@(Import-Csv -LiteralPath (Join-Path $release 'Results/Exp4_Coordination/anomalies.csv') | Where-Object {[int]$_.DirectHeuristicAnomaly -ne 0 -or [int]$_.IndirectHeuristicAnomaly -ne 0})
if($anomalies.Count -ne 0){throw 'Coordination result contains a heuristic anomaly; report before publishing'}
foreach($folder in @('Exp2_DirectPerformance','Exp3_StrategyComparison','Exp4_Coordination')){
    $statuses=@(Import-Csv -LiteralPath (Join-Path $release "Results/$folder/task_status.csv"))
    if(@($statuses|Where-Object{$_.Status -ne 'complete'}).Count -ne 0){throw "Incomplete task: $folder"}
}
$trace=@(Import-Csv -LiteralPath (Join-Path $release 'Results/Exp2_DirectPerformance/convergence.csv'))
$finalError=0.0
foreach($group in $trace | Group-Object InstanceID,Algorithm,Run){
    $ordered=@($group.Group | Sort-Object {[int]$_.Checkpoint})
    for($j=1;$j -lt $ordered.Count;$j++){
        if([double]$ordered[$j].CommonBestTC -gt [double]$ordered[$j-1].CommonBestTC + 0.000001){throw 'Increasing common best-cost trace'}
    }
    $last=$ordered[-1]
    $record=@($e2|Where-Object{$_.InstanceID -eq $last.InstanceID -and $_.Algorithm -eq $last.Algorithm -and $_.Run -eq $last.Run})
    if($record.Count -ne 1){throw 'Convergence endpoint has no unique raw record'}
    $error=[math]::Abs([double]$last.CommonBestTC-[double]$record[0].CommonGridTC)
    $finalError=[math]::Max($finalError,$error)
    if($error -gt 0.000001){throw 'Common convergence endpoint differs from CommonGridTC'}
}
$out=Join-Path $release 'Provenance'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$fileRows | Export-Csv -LiteralPath (Join-Path $out 'delivery_file_manifest.csv') -NoTypeInformation -Encoding UTF8
$sourceRows | Export-Csv -LiteralPath (Join-Path $out 'active_source_manifest.csv') -NoTypeInformation -Encoding UTF8
@{Status='CHECKING_LINKS'} | ConvertTo-Json | Out-File -LiteralPath (Join-Path $out 'release_validation.json') -Encoding UTF8
$brokenLinks=@()
$linkCount=0
foreach($doc in Get-ChildItem -LiteralPath $release -Filter '*.md' -File -Recurse){
    $content=Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
    foreach($link in [regex]::Matches($content,'\]\(([^\)]+)\)')){
        $target=$link.Groups[1].Value
        if($target -match '^[a-z]+:' -or $target.StartsWith('#')){continue}
        $target=($target -split '#')[0].Trim('<','>')
        $local=Join-Path $doc.DirectoryName $target
        $linkCount++
        if(-not(Test-Path -LiteralPath $local)){$brokenLinks+=($doc.Name+': '+$target)}
    }
}
if($brokenLinks.Count -gt 0){throw ("Broken document links: "+($brokenLinks -join '; '))}
$report=[ordered]@{
    Status='PASS'
    VerifiedAt=(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    EvidenceFiles=$fileRows.Count
    EvidenceBytes=($fileRows | Measure-Object Bytes -Sum).Sum
    ScientificQueueCommit='f8e9b9c302be7356da0054ca5fa29ece08e64928'
    Exp2Tasks=$e2.Count
    Exp3Tasks=40
    Exp4Tasks=$e4.Count
    FixedFrequencyItemRecords=$fixed.Count
    CoordinationAnomalies=$anomalies.Count
    MaxFivePartCostSumError=$maxCostError
    CommonConvergenceCheckpoints=$trace.Count
    MaxCommonConvergenceEndpointError=$finalError
    VerifiedLocalDocumentLinks=$linkCount
    ProtectedHashesUnchanged=$true
    ScientificMATLABSourcesUnchanged=$true
    PackagingOnlyMATLABChanges=@('Setup_JRD.m','Shared/JRDProjectManifest.m')
}
$report | ConvertTo-Json -Depth 4 | Out-File -LiteralPath (Join-Path $out 'release_validation.json') -Encoding UTF8
$report | ConvertTo-Json -Depth 4
