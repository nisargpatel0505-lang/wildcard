param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('singles', 'pairs')]
    [string]$Phase,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 1000)]
    [int]$ShardCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 1000000)]
    [int]$Runs,

    [string]$Top12 = '',

    [ValidateSet('medium', 'easy')]
    [string]$Difficulty = 'medium',

    [ValidateRange(1, 32)]
    [int]$MaxParallel = 10
)

$ErrorActionPreference = 'Stop'

$flutterRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $flutterRoot 'build\balance\joker_balance_runner.exe'
$outputDirectory = Join-Path $flutterRoot "build\balance\$Difficulty\$Phase"

if (-not (Test-Path -LiteralPath $runner)) {
    throw "Balance runner not found: $runner"
}
if ($Phase -eq 'pairs' -and [string]::IsNullOrWhiteSpace($Top12)) {
    throw 'Pairs require -Top12 with exactly 12 comma-separated Joker ids.'
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Get-ChildItem -LiteralPath $outputDirectory -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match '^shard-\d{3}\.(err\.)?log$'
    } |
    Remove-Item -Force

$pending = [System.Collections.Generic.Queue[int]]::new()
for ($index = 0; $index -lt $ShardCount; $index++) {
    $pending.Enqueue($index)
}
$running = @{}
$failures = [System.Collections.Generic.List[string]]::new()

while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    while ($pending.Count -gt 0 -and $running.Count -lt $MaxParallel) {
        $index = $pending.Dequeue()
        $stdout = Join-Path $outputDirectory ("shard-{0:D3}.log" -f $index)
        $stderr = Join-Path $outputDirectory ("shard-{0:D3}.err.log" -f $index)
        $arguments = @(
            "--runs=$Runs",
            "--phase=$Phase",
            "--difficulty=$Difficulty",
            "--shard-count=$ShardCount",
            "--shard-index=$index"
        )
        if ($Phase -eq 'pairs') {
            $arguments += "--top12=$Top12"
        }
        $process = Start-Process `
            -FilePath $runner `
            -ArgumentList $arguments `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr `
            -WindowStyle Hidden `
            -PassThru
        $running[$index] = [pscustomobject]@{
            Process = $process
            Stdout = $stdout
            Stderr = $stderr
        }
    }

    Start-Sleep -Seconds 2
    foreach ($index in @($running.Keys)) {
        $item = $running[$index]
        if (-not $item.Process.HasExited) {
            continue
        }
        $item.Process.WaitForExit()
        $item.Process.Refresh()
        $exitCode = $item.Process.ExitCode
        if ($null -eq $exitCode) {
            # Windows PowerShell 5 can expose a blank ExitCode for a completed
            # redirected process. Empty stderr plus non-empty stdout is safe to
            # accept here because the merge step independently validates the
            # exact cohort count and uniqueness.
            $stderrLength = (Get-Item -LiteralPath $item.Stderr).Length
            $stdoutLength = (Get-Item -LiteralPath $item.Stdout).Length
            $exitCode = if ($stderrLength -eq 0 -and $stdoutLength -gt 0) {
                0
            } else {
                -1
            }
        }
        if ($exitCode -ne 0) {
            $failures.Add(
                "Shard $index exited $exitCode; see $($item.Stderr)"
            )
        }
        $running.Remove($index)
    }

    $completed = $ShardCount - $pending.Count - $running.Count
    Write-Progress `
        -Activity "WILDCARD $Phase smart-bot audit" `
        -Status "$completed / $ShardCount shards complete" `
        -PercentComplete (($completed / $ShardCount) * 100)
}

Write-Progress -Activity "WILDCARD $Phase smart-bot audit" -Completed
if ($failures.Count -gt 0) {
    throw ($failures -join [Environment]::NewLine)
}

Write-Output "BALANCE_SHARDS_COMPLETE phase=$Phase difficulty=$Difficulty shards=$ShardCount runs=$Runs"
