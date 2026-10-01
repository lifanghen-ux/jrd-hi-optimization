param(
    [Parameter(Mandatory=$true)][string]$ProfileDirectory,
    [string]$Deadline='',
    [string]$ResumeDirectory=''
)
# Launch only an authorized preliminary queue; each invocation gets new logs.
# The MATLAB queue decides complete stages from remaining time, never stops
# an active solver because of a wall-clock deadline.
$ErrorActionPreference='Stop'
$projectDirectory=(Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$profileResolved=(Resolve-Path -LiteralPath $ProfileDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $profileResolved 'profile.mat') -PathType Leaf)) {
    throw 'ProfileDirectory must contain the completed profiling profile.mat.'
}
$matlabExecutable='D:\MATLAB\R2024a\bin\matlab.exe'
if (-not (Test-Path -LiteralPath $matlabExecutable -PathType Leaf)) {
    throw "MATLAB executable not found: $matlabExecutable"
}
$watchScript=Join-Path $PSScriptRoot 'Watch_JRD_Preliminary_Queue.ps1'
if (-not (Test-Path -LiteralPath $watchScript -PathType Leaf)) {
    throw "Queue monitor script not found: $watchScript"
}
$chinaNow=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow,'China Standard Time')
if ([string]::IsNullOrWhiteSpace($Deadline)) {
    $Deadline=$chinaNow.ToString('yyyy-MM-dd')+' 16:50:00'
}
$null=[DateTime]::ParseExact($Deadline,'yyyy-MM-dd HH:mm:ss',[cultureinfo]::InvariantCulture)
$resumeResolved=''
if (-not [string]::IsNullOrWhiteSpace($ResumeDirectory)) {
    $resumeResolved=(Resolve-Path -LiteralPath $ResumeDirectory).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resumeResolved 'queue.mat') -PathType Leaf)) {
        throw 'ResumeDirectory must contain this queue''s queue.mat.'
    }
}

$launchId='Launch_'+$chinaNow.ToString('yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$launchParent=Join-Path $projectDirectory 'Results_Unattended'
if (-not (Test-Path -LiteralPath $launchParent -PathType Container)) {
    $null=New-Item -ItemType Directory -Path $launchParent
}
$launchDirectory=Join-Path $launchParent $launchId
$null=New-Item -ItemType Directory -Path $launchDirectory
$queueOutputRoot=Join-Path $launchDirectory 'queue'
$stdoutPath=Join-Path $launchDirectory 'stdout.log'
$stderrPath=Join-Path $launchDirectory 'stderr.log'
$metadataPath=Join-Path $launchDirectory 'launch.json'

function ConvertTo-MatlabLiteral([string]$Value) {
    return "'"+$Value.Replace("'","''")+"'"
}
$expression=('cd('+ (ConvertTo-MatlabLiteral $projectDirectory)+'); Setup_JRD(); Run_Unattended_Preliminary_Queue('+ 
    "'ProfileDir',"+(ConvertTo-MatlabLiteral $profileResolved)+",'Deadline',"+(ConvertTo-MatlabLiteral $Deadline))
if ($resumeResolved) {
    $expression+=",'ResumeDir',"+(ConvertTo-MatlabLiteral $resumeResolved)+');'
} else {
    $expression+=",'OutputRoot',"+(ConvertTo-MatlabLiteral $queueOutputRoot)+');'
}
# Start-Process joins ArgumentList; quote the whole batch expression once.
$matlabArguments=@('-batch',('"'+$expression+'"'))
$launch=[ordered]@{
    LaunchId=$launchId; LaunchStatus='starting'; StartedAtAsiaShanghai=$chinaNow.ToString('o');
    ProjectDirectory=$projectDirectory; MatlabExecutable=$matlabExecutable;
    ProfileDirectory=$profileResolved; Deadline=$Deadline; ResumeDirectory=$resumeResolved;
    LaunchDirectory=$launchDirectory; QueueOutputRoot=$queueOutputRoot;
    StdoutLog=$stdoutPath; StderrLog=$stderrPath; BatchExpression=$expression;
    MatlabPID=$null; MonitorPID=$null; MonitorExecutable=''; MonitorScript=$watchScript;
    QueueDirectory=''; QueueStatePath=''; QueueStateWaitSeconds=60; WaitOutcome='not_started';
    Error=''
}
function Save-LaunchMetadata {
    $temporary=Join-Path $launchDirectory ('launch_'+[guid]::NewGuid().ToString('N')+'.json')
    $launch | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $metadataPath -Force
}
Save-LaunchMetadata
try {
    $matlabStartOptions=@{
        FilePath=$matlabExecutable; ArgumentList=$matlabArguments;
        WorkingDirectory=$projectDirectory; WindowStyle='Hidden';
        RedirectStandardOutput=$stdoutPath; RedirectStandardError=$stderrPath; PassThru=$true
    }
    $matlabProcess=Start-Process @matlabStartOptions
    $launch.MatlabPID=$matlabProcess.Id
    $launch.LaunchStatus='matlab_started'
    $launch.WaitOutcome='waiting_for_queue_state'
    Save-LaunchMetadata

    $watchTimer=[Diagnostics.Stopwatch]::StartNew()
    $queueState=''
    while ($watchTimer.Elapsed.TotalSeconds -lt 60 -and -not $queueState) {
        if ($resumeResolved) {
            $candidate=Join-Path $resumeResolved 'queue_state.json'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $queueState=$candidate }
        } elseif (Test-Path -LiteralPath $queueOutputRoot -PathType Container) {
            $candidates=@(Get-ChildItem -LiteralPath $queueOutputRoot -Filter 'queue_state.json' -Recurse -File | Sort-Object LastWriteTime -Descending)
            if ($candidates.Count -gt 0) { $queueState=$candidates[0].FullName }
        }
        if (-not $queueState) { Start-Sleep -Milliseconds 1000 }
    }
    $watchTimer.Stop()
    if ($queueState) {
        $queueResolved=(Resolve-Path -LiteralPath (Split-Path -Parent $queueState)).Path
        $launch.QueueDirectory=$queueResolved; $launch.QueueStatePath=$queueState
        $launch.WaitOutcome='queue_state_found'
        $pwshCommand=Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pwshCommand) { $monitorExecutable=$pwshCommand.Source }
        else { $monitorExecutable=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe' }
        $monitorArguments=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',
            ('"'+$watchScript+'"'),'-QueueDirectory',('"'+$queueResolved+'"'))
        $monitorStartOptions=@{
            FilePath=$monitorExecutable; ArgumentList=$monitorArguments;
            WorkingDirectory=$projectDirectory; WindowStyle='Hidden';
            RedirectStandardOutput=(Join-Path $launchDirectory 'monitor.stdout.log');
            RedirectStandardError=(Join-Path $launchDirectory 'monitor.stderr.log'); PassThru=$true
        }
        $monitorProcess=Start-Process @monitorStartOptions
        $launch.MonitorPID=$monitorProcess.Id; $launch.MonitorExecutable=$monitorExecutable
        $launch.LaunchStatus='matlab_and_monitor_started'
    } else {
        $launch.WaitOutcome='no_queue_state_within_60_seconds'
        $launch.LaunchStatus='matlab_started_monitor_not_started'
    }
    Save-LaunchMetadata
    [pscustomobject]$launch
} catch {
    $launch.LaunchStatus='launch_or_monitor_error'; $launch.Error=$_.Exception.Message
    Save-LaunchMetadata
    throw
}
