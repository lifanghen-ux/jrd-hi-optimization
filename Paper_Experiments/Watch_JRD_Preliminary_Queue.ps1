param(
    [Parameter(Mandatory=$true)][string]$QueueDirectory,
    [int]$PollSeconds=15
)
# Read-only scientific monitoring; writes only this queue's progress artifacts.
$ErrorActionPreference='Stop'
$queueResolved=(Resolve-Path -LiteralPath $QueueDirectory).Path
$statePath=Join-Path $queueResolved 'queue_state.json'
$terminalStates=@('complete','completed_with_failures','blocked_global_error','not_started_insufficient_window','dry_run_validated')
# Keep this unattended queue awake without changing any permanent power plan.
# Windows clears this thread-scoped request when the monitor process exits.
Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class JRDQueuePower { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags); }'
[JRDQueuePower]::SetThreadExecutionState([uint32]2147483649) | Out-Null
while ($true) {
    try {
        if (-not (Test-Path -LiteralPath $statePath)) { Start-Sleep -Seconds $PollSeconds; continue }
        $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $expectedNow=[int]$state.CurrentExpectedTasks
        if (-not $state.CurrentStage) { $expectedNow=0 }
        $completeNow=0; $failedNow=0; $pendingNow=[math]::Max(0,$expectedNow); $taskFile=''
        if ($state.CurrentRoot -and (Test-Path -LiteralPath $state.CurrentRoot)) {
            $statusFiles=Get-ChildItem -LiteralPath $state.CurrentRoot -Filter 'task_status.csv' -Recurse -File | Sort-Object LastWriteTime -Descending
            if ($statusFiles.Count -gt 0) {
                $taskFile=$statusFiles[0].FullName
                $tasks=@(Import-Csv -LiteralPath $taskFile)
                $completeNow=@($tasks | Where-Object {$_.Status -eq 'complete'}).Count
                $failedNow=@($tasks | Where-Object {$_.Status -eq 'failed'}).Count
                $pendingNow=@($tasks | Where-Object {$_.Status -eq 'pending'}).Count
            }
        }
        $started=[datetime]::ParseExact($state.StartedAt,'yyyyMMddTHHmmss',[cultureinfo]::InvariantCulture)
        $elapsed=((Get-Date)-$started).TotalSeconds
        $stageElapsed=0
        if ($state.CurrentStage -and $state.CurrentStageStartedAt) {
            $stageStarted=[datetime]::ParseExact($state.CurrentStageStartedAt,'yyyyMMddTHHmmss',[cultureinfo]::InvariantCulture)
            $stageElapsed=((Get-Date)-$stageStarted).TotalSeconds
        }
        $estimatedSeconds=$null; $etaText='unavailable until actual calibration completes'
        if ([double]$state.EstimatedRemainingSeconds -gt 0) {
            $estimatedSeconds=[math]::Max(0,[double]$state.EstimatedRemainingSeconds-$stageElapsed)
            $etaText="$([math]::Round($estimatedSeconds/60,1)) minutes"
        } elseif (-not $state.CurrentStage) { $estimatedSeconds=0; $etaText='0 minutes' }
        $totalComplete=[int]$state.CommittedUniqueTasks+[math]::Max(0,$completeNow-[int]$state.CurrentReusedTasks)
        if (-not $state.CurrentStage) { $totalComplete=[int]$state.CommittedUniqueTasks }
        $progress=[ordered]@{UpdatedAt=(Get-Date).ToString('o');QueueStatus=$state.Status;CurrentStage=$state.CurrentStage;
            CommittedUniqueCompleted=$totalComplete;CurrentStageCompleted=$completeNow;CurrentStageFailed=$failedNow;
            CurrentStagePending=$pendingNow;CurrentStageExpected=$expectedNow;
            QueueElapsedSeconds=$elapsed;EstimatedStageRemainingSeconds=$estimatedSeconds;TaskStatusFile=$taskFile;
            GitCommit=$state.GitCommit;SoftDeadline=$state.Deadline}
        $progress | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $queueResolved 'live_progress.json') -Encoding UTF8
        # ASCII source is parseable by both Windows PowerShell 5 and pwsh.
        $lines=@('# JRD-HI live queue status','',"Updated: $($progress.UpdatedAt)","Queue status: $($state.Status)",
            "Current stage: $($state.CurrentStage)","Unique completed tasks: $totalComplete",
            "Current stage: $completeNow / $expectedNow complete; $failedNow failed; $pendingNow pending",
            "Queue elapsed: $([math]::Round($elapsed/60,1)) minutes",
            "Estimated stage remaining: $etaText (estimate, not a solver time cap)",'',
            "Task details: $taskFile",'Summary: REPORT.md. MAT/CSV are saved after every completed solver.',
            'This monitor does not modify scientific inputs, solvers, or configuration.')
        $lines | Set-Content -LiteralPath (Join-Path $queueResolved 'live_progress.md') -Encoding UTF8
        if ($terminalStates -contains $state.Status) { break }
    } catch {
        # Atomic-replacement/read races do not stop a scientific queue.
        Add-Content -LiteralPath (Join-Path $queueResolved 'monitor_errors.log') -Value ((Get-Date).ToString('o')+' '+$_.Exception.Message) -Encoding UTF8
    }
    Start-Sleep -Seconds $PollSeconds
}
[JRDQueuePower]::SetThreadExecutionState([uint32]2147483648) | Out-Null
