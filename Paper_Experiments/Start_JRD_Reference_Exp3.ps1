param(
    [string]$OutputRoot='',
    [string]$ResumeDir='',
    [string]$MatlabExecutable='D:\MATLAB\R2024a\bin\matlab.exe',
    [switch]$DryRun,
    [switch]$Worker,
    [string]$LaunchDirectory='',
    [ValidateRange(1,60)][int]$PollSeconds=15
)
# Optional reference-budget Exp3 only. No solver deadline or model changes.
# ASCII source supports Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference='Stop'

function Write-AtomicJson([object]$Value,[string]$Path) {
    $temporary=Join-Path (Split-Path -Parent $Path) ('json_'+[guid]::NewGuid().ToString('N')+'.tmp')
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-ScientificManifest([string]$Root) {
    # Match Shared/JRDProjectManifest.m: only active .m and immutable inputs.
    $folders=@('','Shared','Direct_V1','Indirect_V1','Evolutionary_Direct',
        'Paper_Experiments','Tests','Tests/Oracles','Tests_Paper')
    $relative=@()
    foreach ($folder in $folders) {
        $directory=$Root
        if ($folder) { $directory=Join-Path $Root $folder }
        foreach ($file in @(Get-ChildItem -LiteralPath $directory -Filter '*.m' -File)) {
            $path=$file.Name
            if ($folder) { $path=$folder+'/'+$file.Name }
            $relative+=$path.Replace('\','/')
        }
    }
    $relative+=@('Data_N10.mat','Data_N30.mat','Data_N50.mat','Data_N100.mat','testDataN6_Paper.mat')
    $relative=[string[]]$relative
    [Array]::Sort($relative,[StringComparer]::Ordinal)
    foreach ($path in $relative) {
        [pscustomobject]@{RelativePath=$path;SHA256=(Get-FileHash -LiteralPath (Join-Path $Root $path) -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}

function Assert-ScientificManifest([string]$Root,[object[]]$Expected) {
    $current=@(Get-ScientificManifest $Root)
    if ($current.Count -ne $Expected.Count) { throw 'Active MATLAB/data manifest changed before launch.' }
    for ($i=0;$i -lt $current.Count;$i++) {
        if ($current[$i].RelativePath -cne $Expected[$i].RelativePath -or $current[$i].SHA256 -cne $Expected[$i].SHA256) {
            throw ('Active MATLAB/data changed before launch: '+$Expected[$i].RelativePath)
        }
    }
}

function Get-MatlabProcesses {
    # The executable in bin can be only a bootstrap. Monitor real processes,
    # never interpret the bootstrap process object's HasExited as completion.
    return @(Get-Process -Name MATLAB -ErrorAction SilentlyContinue)
}

function Read-TaskProgress([string]$Directory,[string]$Root,[int]$Expected) {
    $taskPath=''
    if ($Directory) { $taskPath=Join-Path $Directory 'task_status.csv' }
    elseif (Test-Path -LiteralPath $Root -PathType Container) {
        $files=@(Get-ChildItem -LiteralPath $Root -Filter 'task_status.csv' -Recurse -File | Sort-Object LastWriteTime -Descending)
        if ($files.Count -gt 0) { $taskPath=$files[0].FullName }
    }
    $answer=[ordered]@{TaskStatusFile=$taskPath;Directory=$Directory;Expected=$Expected;
        Complete=0;Failed=0;Pending=$Expected;StudyStatus='';TasksPresent=$false}
    if ($taskPath -and (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
        $tasks=@(Import-Csv -LiteralPath $taskPath)
        if ($tasks.Count -gt 0) {
            $answer.Directory=Split-Path -Parent $taskPath
            $answer.Expected=$tasks.Count
            $answer.Complete=@($tasks | Where-Object {$_.Status -eq 'complete'}).Count
            $answer.Failed=@($tasks | Where-Object {$_.Status -eq 'failed'}).Count
            $answer.Pending=@($tasks | Where-Object {$_.Status -eq 'pending'}).Count
            $statuses=@($tasks.StudyStatus | Select-Object -Unique)
            if ($statuses.Count -eq 1) { $answer.StudyStatus=$statuses[0] }
            $answer.TasksPresent=$true
        }
    }
    return [pscustomobject]$answer
}

function Invoke-ReferenceWorker([string]$Directory) {
    $metadataPath=Join-Path $Directory 'launch.json'
    $launch=Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $powerRequested=$false
    try {
        Assert-ScientificManifest $launch.ProjectDirectory @(Get-Content -LiteralPath $launch.SourceManifest -Raw -Encoding UTF8 | ConvertFrom-Json)
        if (@(Get-MatlabProcesses).Count -gt 0) {
            throw 'Another MATLAB process is present. Reference Exp3 was not started; wait until it finishes.'
        }
        Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class JRDReferenceExp3Power { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags); }'
        $powerResult=[JRDReferenceExp3Power]::SetThreadExecutionState([uint32]2147483649)
        if ($powerResult -eq 0) { throw 'Windows denied the temporary system keep-awake request.' }
        $powerRequested=$true
        $launch.KeepAwake='thread_scoped_ES_CONTINUOUS_ES_SYSTEM_REQUIRED'
        $launch.WorkerPID=$PID
        $launch.LaunchStatus='worker_ready'
        Write-AtomicJson $launch $metadataPath
        $options=@{FilePath=$launch.MatlabExecutable;ArgumentList=@('-batch',('"'+$launch.BatchExpression+'"'));
            WorkingDirectory=$launch.ProjectDirectory;WindowStyle='Hidden';
            RedirectStandardOutput=$launch.StdoutLog;RedirectStandardError=$launch.StderrLog;PassThru=$true}
        $bootstrap=Start-Process @options
        $launch.MatlabBootstrapPID=$bootstrap.Id
        $launch.LaunchStatus='running'
        $launch.StartedAt=(Get-Date).ToString('o')
        Write-AtomicJson $launch $metadataPath
        $absenceSince=$null
        while ($true) {
            try { $progress=Read-TaskProgress $launch.ResumeDir $launch.ExperimentOutputRoot $launch.ExpectedTasks }
            catch {
                # Atomic replacement can race a Windows reader. Never stop a
                # live solver or release keep-awake for a transient read error.
                Add-Content -LiteralPath (Join-Path $Directory 'monitor_read_errors.log') -Value ((Get-Date).ToString('o')+' '+$_.Exception.Message) -Encoding UTF8
                $progress=[pscustomobject]@{TaskStatusFile='';Directory=$launch.ResumeDir;
                    Expected=$launch.ExpectedTasks;Complete=0;Failed=0;Pending=$launch.ExpectedTasks;
                    StudyStatus='';TasksPresent=$false}
            }
            $progress | Add-Member -NotePropertyName UpdatedAt -NotePropertyValue (Get-Date).ToString('o')
            $progress | Add-Member -NotePropertyName LaunchId -NotePropertyValue $launch.LaunchId
            Write-AtomicJson $progress (Join-Path $Directory 'live_progress.json')
            $log=''
            if (Test-Path -LiteralPath $launch.StdoutLog -PathType Leaf) {
                try { $log=Get-Content -LiteralPath $launch.StdoutLog -Raw -Encoding UTF8 }
                catch { $log='' }
            }
            $sentinel='JRD_REFERENCE_EXP3_TERMINAL:'+ $launch.LaunchId +':'
            $marker=$null
            if (Test-Path -LiteralPath $launch.TerminalMarker -PathType Leaf) {
                try { $marker=Get-Content -LiteralPath $launch.TerminalMarker -Raw -Encoding UTF8 | ConvertFrom-Json }
                catch { $marker=$null }
            }
            if ($marker -and $marker.LaunchId -ceq $launch.LaunchId -and $log -and $log.Contains($sentinel)) {
                $launch.ResultDirectory=$marker.Directory
                $launch.StudyStatus=$marker.Status
                $launch.TerminalEvidence='this_launch_stdout_sentinel_and_terminal_marker'
                if ($marker.Status -eq 'complete' -or $marker.Status -eq 'completed_with_failures') {
                    $finalProgress=Read-TaskProgress $marker.Directory $launch.ExperimentOutputRoot $launch.ExpectedTasks
                    if (-not $finalProgress.TasksPresent -or $finalProgress.StudyStatus -cne $marker.Status -or $finalProgress.Pending -ne 0) {
                        throw 'MATLAB returned, but task_status.csv does not agree with its terminal StudyStatus.'
                    }
                    $launch.TerminalEvidence+='plus_task_status_StudyStatus'
                    $launch.CompletedTasks=$finalProgress.Complete
                    $launch.FailedTasks=$finalProgress.Failed
                }
                $launch.LaunchStatus=$marker.Status
                $launch.Error=$marker.ErrorIdentifier
                $launch.EndedAt=(Get-Date).ToString('o')
                Write-AtomicJson $launch $metadataPath
                break
            }
            $active=@(Get-MatlabProcesses)
            $launch.ObservedMatlabPIDs=@($active | Select-Object -ExpandProperty Id)
            Write-AtomicJson $launch $metadataPath
            if ($active.Count -eq 0) {
                if ($null -eq $absenceSince) { $absenceSince=Get-Date }
                # This is a vanished-process/startup grace, NOT a solver cap.
                if (((Get-Date)-$absenceSince).TotalSeconds -ge 120) {
                    throw 'No MATLAB process for 120 seconds and no terminal sentinel. Inspect stdout/stderr and resume completed solver records.'
                }
            } else { $absenceSince=$null }
            Start-Sleep -Seconds $PollSeconds
        }
    } catch {
        $launch.LaunchStatus='launcher_or_abrupt_process_error'
        $launch.Error=$_.Exception.Message
        $launch.EndedAt=(Get-Date).ToString('o')
        Write-AtomicJson $launch $metadataPath
        throw
    } finally {
        if ($powerRequested) { [JRDReferenceExp3Power]::SetThreadExecutionState([uint32]2147483648) | Out-Null }
    }
}

if ($Worker) {
    if ($DryRun -or -not $LaunchDirectory) { throw 'Worker requires LaunchDirectory and cannot use DryRun.' }
    Invoke-ReferenceWorker (Resolve-Path -LiteralPath $LaunchDirectory).Path
    exit
}
if ($LaunchDirectory) { throw 'LaunchDirectory is an internal worker argument.' }
$projectDirectory=(Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$executable=(Resolve-Path -LiteralPath $MatlabExecutable).Path
$resumeResolved=''
if ($ResumeDir) {
    $resumeResolved=(Resolve-Path -LiteralPath $ResumeDir).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resumeResolved 'study.mat') -PathType Leaf)) {
        throw 'ResumeDir must contain an Exp3 study.mat. MATLAB verifies its exact scientific configuration and source.'
    }
}
$launchParent=Join-Path $projectDirectory 'Results_Unattended'
if (-not (Test-Path -LiteralPath $launchParent -PathType Container)) { $null=New-Item -ItemType Directory -Path $launchParent }
$launchId='ReferenceExp3_'+(Get-Date).ToString('yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$launchPath=Join-Path $launchParent $launchId
$null=New-Item -ItemType Directory -Path $launchPath
$experimentRoot=Join-Path $launchPath 'experiment'
if ($OutputRoot) {
    $experimentRoot=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputRoot)
    # A caller-specified root is required to be new, never a historical folder.
    if (Test-Path -LiteralPath $experimentRoot) { throw 'OutputRoot must be a new directory; use ResumeDir for existing experiment results.' }
}
function ConvertTo-MatlabLiteral([string]$Value) { return "'"+$Value.Replace("'","''")+"'" }
$markerPath=Join-Path $launchPath 'matlab_terminal.json'
$config=[ordered]@{NList=@(10,30,50,100);Runs=3;BaseSeed=20261002;Generations=500;
    PopulationFactor=10;MinimumPopulation=40;GridStep=0.001}
$controls=[ordered]@{ContinueOnTaskError=$true;RetryFailedTasks=$false;
    ResumeGranularity='completed solver call; an interrupted unfinished call restarts';
    Deadline='none';CostDecisionUsesTime=$false;NoConcurrentMatlab=$true;
    ResumeConfigurationValidation='original MATLAB runner, before any new solve'}
$runner="[Study,out]=Run_Paper_Experiment3_StrategyComparison('NList',[10 30 50 100],'Runs',3,'BaseSeed',20261002,'Generations',500,'PopulationFactor',10,'MinimumPopulation',40,'GridStep',0.001,'ContinueOnTaskError',true,'RetryFailedTasks',false"
if ($resumeResolved) { $runner+=",'ResumeDir',"+(ConvertTo-MatlabLiteral $resumeResolved)+');' }
else { $runner+=",'OutputRoot',"+(ConvertTo-MatlabLiteral $experimentRoot)+');' }
$markerLiteral=ConvertTo-MatlabLiteral $markerPath
$idLiteral=ConvertTo-MatlabLiteral $launchId
$sentinelLiteral=ConvertTo-MatlabLiteral ('JRD_REFERENCE_EXP3_TERMINAL:'+ $launchId +':%s\n')
$expression='try;cd('+(ConvertTo-MatlabLiteral $projectDirectory)+');Setup_JRD();'+$runner+
    'terminal=struct(''LaunchId'','+$idLiteral+',''Status'',Study.Status,''Directory'',out,''ErrorIdentifier'','''');'+
    'fid=fopen('+$markerLiteral+',''w'',''n'',''UTF-8'');assert(fid>=0,''JRD:ResultWrite'',''Cannot create terminal marker'');fprintf(fid,''%s'',jsonencode(terminal));fclose(fid);fprintf(1,'+$sentinelLiteral+',Study.Status);'+
    'catch exception;terminal=struct(''LaunchId'','+$idLiteral+',''Status'',''matlab_exception'',''Directory'','''',''ErrorIdentifier'',exception.identifier);'+
    'fid=fopen('+$markerLiteral+',''w'',''n'',''UTF-8'');if fid>=0;fprintf(fid,''%s'',jsonencode(terminal));fclose(fid);end;fprintf(1,'+$sentinelLiteral+',''matlab_exception'');rethrow(exception);end;'
$sourcePath=Join-Path $launchPath 'source_manifest.json'
$manifest=@(Get-ScientificManifest $projectDirectory)
Write-AtomicJson $manifest $sourcePath
Write-AtomicJson $config (Join-Path $launchPath 'scientific_config.json')
Write-AtomicJson $controls (Join-Path $launchPath 'run_controls.json')
$gitCommit=(& git -C $projectDirectory rev-parse HEAD 2>$null | Out-String).Trim()
$scriptPath=$PSCommandPath
$launch=[ordered]@{SchemaVersion=1;LaunchId=$launchId;LaunchDirectory=$launchPath;LaunchStatus='prepared';CreatedAt=(Get-Date).ToString('o');
    ProjectDirectory=$projectDirectory;GitCommit=$gitCommit;MatlabExecutable=$executable;
    ResumeDir=$resumeResolved;ExperimentOutputRoot=$experimentRoot;ExpectedTasks=24;
    ScientificConfig=$config;RunControls=$controls;SourceManifest=$sourcePath;
    LauncherPath=$scriptPath;LauncherSHA256=(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant();
    BatchExpression=$expression;StdoutLog=(Join-Path $launchPath 'stdout.log');StderrLog=(Join-Path $launchPath 'stderr.log');
    TerminalMarker=$markerPath;WorkerPID=$null;MatlabBootstrapPID=$null;ObservedMatlabPIDs=@();
    KeepAwake='not_requested';StartedAt='';EndedAt='';ResultDirectory='';StudyStatus='';TerminalEvidence='';CompletedTasks=0;FailedTasks=0;Error=''}
$metadataPath=Join-Path $launchPath 'launch.json'
Write-AtomicJson $launch $metadataPath
Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $launchPath 'launcher_snapshot.ps1')
if ($DryRun) {
    $launch.LaunchStatus='dry_run_validated'
    Write-AtomicJson $launch $metadataPath
    [pscustomobject]$launch
    exit
}
try {
    if (@(Get-MatlabProcesses).Count -gt 0) { throw 'Another MATLAB process is present; wait until it finishes before launching reference Exp3.' }
    $workerExecutable=(Get-Process -Id $PID).Path
    $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',
        ('"'+$scriptPath+'"'),'-Worker','-LaunchDirectory',('"'+$launchPath+'"'),'-PollSeconds',$PollSeconds)
    $options=@{FilePath=$workerExecutable;ArgumentList=$arguments;WorkingDirectory=$projectDirectory;WindowStyle='Hidden';
        RedirectStandardOutput=(Join-Path $launchPath 'worker.stdout.log');RedirectStandardError=(Join-Path $launchPath 'worker.stderr.log');PassThru=$true}
    $workerProcess=Start-Process @options
    # Only the worker writes launch.json after startup, avoiding a writer race.
    [pscustomobject]@{LaunchId=$launchId;WorkerPID=$workerProcess.Id;LaunchDirectory=$launchPath;
        Metadata=$metadataPath;Status='worker_started';ResumeDir=$resumeResolved;ExperimentOutputRoot=$experimentRoot}
} catch {
    $launch.LaunchStatus='not_started'
    $launch.Error=$_.Exception.Message
    Write-AtomicJson $launch $metadataPath
    throw
}
