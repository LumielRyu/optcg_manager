param(
  [ValidateSet("pokemon", "digimon", "magic", "riftbound", "yugioh")]
  [string[]]$Games = @(
    "pokemon",
    "digimon",
    "magic",
    "riftbound",
    "yugioh"
  ),
  [ValidateRange(0, 3600)]
  [int]$DelaySeconds = 30
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$logRoot = Join-Path $repoRoot ".cache\liga-tcg-backfill"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

$python = (Get-Command python -ErrorAction Stop).Source
$started = @()
$alreadyRunning = @()

foreach ($game in $Games) {
  $pidPath = Join-Path $logRoot "$game.pid"
  if (Test-Path -LiteralPath $pidPath) {
    $savedPid = [int](Get-Content -Raw -LiteralPath $pidPath)
    if (Get-Process -Id $savedPid -ErrorAction SilentlyContinue) {
      $alreadyRunning += $game
      continue
    }
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $stdoutPath = Join-Path $logRoot "$game-$timestamp.out.log"
  $stderrPath = Join-Path $logRoot "$game-$timestamp.err.log"
  $arguments = @(
    "-u",
    "scripts/update_liga_tcg_price_cache.py",
    "--game", $game,
    "--missing-only",
    "--shard-count", "1",
    "--shard-index", "0",
    "--priority-editions", "0",
    "--delay", $DelaySeconds.ToString()
  )
  if ($game -eq "riftbound") {
    $arguments += "--include-future"
  }

  $process = Start-Process `
    -FilePath $python `
    -ArgumentList $arguments `
    -WorkingDirectory $repoRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -PassThru
  Set-Content -LiteralPath $pidPath -Value $process.Id
  $started += [pscustomobject]@{
    Game = $game
    ProcessId = $process.Id
    Output = $stdoutPath
    Error = $stderrPath
  }
}

[pscustomobject]@{
  Started = $started
  AlreadyRunning = $alreadyRunning
  LogDirectory = $logRoot
} | ConvertTo-Json -Depth 4
