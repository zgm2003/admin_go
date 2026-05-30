param()

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [string]$Path,
        [string[]]$GitArgs
    )
    & git -C $Path @GitArgs *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "git -C $Path $($GitArgs -join ' ') failed"
    }
}

function Write-File {
    param(
        [string]$Path,
        [string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
}

function New-TestRepo {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Invoke-Git -Path $Path -GitArgs @('init', '-b', 'master')
    Invoke-Git -Path $Path -GitArgs @('config', 'user.email', 'agent-governance-test@example.test')
    Invoke-Git -Path $Path -GitArgs @('config', 'user.name', 'Agent Governance Test')
}

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("admin-go-governance-test-" + [System.Guid]::NewGuid().ToString('N'))

try {
    New-TestRepo $tempRoot
    New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot 'scripts') | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'scripts/check-agent-governance.ps1') -Destination (Join-Path $tempRoot 'scripts/check-agent-governance.ps1')
    Write-File (Join-Path $tempRoot 'README.md') '# fixture'
    Invoke-Git -Path $tempRoot -GitArgs @('add', '.')
    Invoke-Git -Path $tempRoot -GitArgs @('commit', '-m', 'initial root')
    Invoke-Git -Path $tempRoot -GitArgs @('update-ref', 'refs/remotes/origin/master', 'HEAD')

    $backend = Join-Path $tempRoot 'admin_back_go'
    New-TestRepo $backend
    Write-File (Join-Path $backend 'README.md') '# backend fixture'
    Invoke-Git -Path $backend -GitArgs @('add', '.')
    Invoke-Git -Path $backend -GitArgs @('commit', '-m', 'initial backend')
    Invoke-Git -Path $backend -GitArgs @('update-ref', 'refs/remotes/origin/master', 'HEAD')

    Write-File (Join-Path $backend 'internal/module/demo/foo.go') @'
package demo

func Foo() string { return "bar" }
'@
    Invoke-Git -Path $backend -GitArgs @('add', '.')
    Invoke-Git -Path $backend -GitArgs @('commit', '-m', 'touch backend runtime')

    Push-Location $tempRoot
    try {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File '.\scripts\check-agent-governance.ps1' -Mode range -Base origin/master -Strict 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    $text = ($output -join "`n")
    if ($exitCode -eq 0) {
        throw "expected range governance to fail for subrepo runtime-only commit, but it passed.`n$text"
    }
    if ($text -notmatch 'admin_back_go/internal/module/demo/foo\.go') {
        throw "expected range changed files to include subrepo runtime path.`n$text"
    }
    if ($text -notmatch 'Strict: backend runtime touched without backend contract/status/smoke/backend-architecture doc sync') {
        throw "expected strict backend docs-sync blocker for subrepo runtime path.`n$text"
    }

    Write-Output 'agent governance subrepo range assertions passed'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
