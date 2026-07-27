param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('singles', 'pairs')]
    [string]$Phase,

    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputCsv
)

$ErrorActionPreference = 'Stop'

$prefix = if ($Phase -eq 'singles') { 'JOKERCSV' } else { 'PAIRCSV' }
$header = @(
    'prefix',
    'joker',
    'rarity',
    'winDelta',
    'heatDelta',
    'runs',
    'wins',
    'winRate',
    'avgTerminalHeat',
    'avgHeatsCleared',
    'heatsClearedDelta',
    'avgScore',
    'avgJokerTriggersPerHand',
    'jokerActiveHandRate',
    'over70'
)

$stdoutFiles = Get-ChildItem -LiteralPath $InputDirectory -File |
    Where-Object { $_.Name -match '^shard-\d{3}\.log$' }

$rows = foreach ($file in $stdoutFiles) {
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        if (-not $line.StartsWith("$prefix,")) {
            continue
        }
        $row = $line | ConvertFrom-Csv -Header $header
        if ($row.joker -eq 'BASELINE') {
            continue
        }
        $row
    }
}

$expected = if ($Phase -eq 'singles') { 102 } else { 66 }
$unique = @($rows | Group-Object joker)
if ($rows.Count -ne $expected -or $unique.Count -ne $expected) {
    throw "Expected $expected unique $Phase rows, found $($rows.Count) rows / $($unique.Count) unique."
}

$ranked = $rows | Sort-Object `
    @{ Expression = { [double]$_.winDelta }; Descending = $true }, `
    @{ Expression = { [double]$_.heatDelta }; Descending = $true }, `
    @{ Expression = { [double]$_.heatsClearedDelta }; Descending = $true }, `
    @{ Expression = { [double]$_.avgScore }; Descending = $true }, `
    @{ Expression = { $_.joker }; Descending = $false }

$parent = Split-Path -Parent $OutputCsv
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$ranked | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation

if ($Phase -eq 'singles') {
    # copper and presser are already present in the fixed two-starter baseline;
    # their forced arms intentionally deduplicate to baseline and cannot be
    # ranked as independent contributions.
    $top12 = @(
        $ranked |
            Where-Object { $_.joker -notin @('copper', 'presser') } |
            Select-Object -First 12 -ExpandProperty joker
    )
    Write-Output "TOP12=$($top12 -join ',')"
} else {
    $flagged = @($ranked | Where-Object { [double]$_.winRate -gt 0.70 })
    Write-Output "PAIR_OVER_70=$($flagged.Count)"
    foreach ($row in $flagged) {
        Write-Output "PAIRFLAG=$($row.joker),$($row.winRate)"
    }
}
Write-Output "MERGED=$OutputCsv"
