$ErrorActionPreference = 'Stop'

function Normalize-PathText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return ($Path.Trim() -replace '\\','/')
}

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    throw 'Cannot locate installer script path.'
}

$scriptDir = Split-Path -Parent $scriptPath
$repoRootRaw = & git -C $scriptDir rev-parse --show-toplevel 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($repoRootRaw | Select-Object -First 1))) {
    throw "Cannot locate repo root from '$scriptDir': $repoRootRaw"
}

$repoRoot = Normalize-PathText (($repoRootRaw | Select-Object -First 1).ToString())
Set-Location $repoRoot

& git config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to set git config core.hooksPath .githooks.'
}

$finalHooksPathRaw = & git config --get core.hooksPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read git config core.hooksPath after install: $finalHooksPathRaw"
}

$finalHooksPath = (($finalHooksPathRaw | Select-Object -First 1).ToString()).Trim()
if ($finalHooksPath -ne '.githooks') {
    throw "Unexpected core.hooksPath '$finalHooksPath'; expected '.githooks'."
}

Write-Host "repo root: $repoRoot"
Write-Host "core.hooksPath: $finalHooksPath"
