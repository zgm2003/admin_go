param(
    [ValidateSet('working', 'range')]
    [string]$Mode = 'working',
    [string]$Base,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Name)
    Write-Host ""
    Write-Host $Name
    Write-Host ('-' * $Name.Length)
}

function Normalize-PathText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return ($Path.Trim() -replace '\\','/')
}

function Add-Unique {
    param(
        [System.Collections.ArrayList]$List,
        [string]$Value
    )
    $v = Normalize-PathText $Value
    if ($v -and -not $v.EndsWith('/') -and -not $List.Contains($v)) { [void]$List.Add($v) }
}

function Test-IncludedPath {
    param([string]$Path)
    $p = Normalize-PathText $Path
    if (-not $p) { return $false }
    return ($p -notmatch '(^|/)node_modules(/|$)')
}

function Filter-ChangedPaths {
    param([object[]]$Paths)
    $filtered = New-Object System.Collections.ArrayList
    foreach ($path in $Paths) {
        if (Test-IncludedPath $path) { Add-Unique $filtered $path }
    }
    return @($filtered)
}

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw 'Not inside a git repository.'
    }
    return (Normalize-PathText $root)
}

function Git-Ref-Exists {
    param([string]$Ref)
    if ([string]::IsNullOrWhiteSpace($Ref)) { return $false }
    & git rev-parse --verify --quiet $Ref *> $null
    return ($LASTEXITCODE -eq 0)
}

function Git-Ref-ExistsInRepo {
    param(
        [string]$Path,
        [string]$Ref
    )
    if ([string]::IsNullOrWhiteSpace($Ref)) { return $false }
    & git -C $Path rev-parse --verify --quiet $Ref *> $null
    return ($LASTEXITCODE -eq 0)
}

function Get-CurrentBranch {
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    $branch = ($branch | Select-Object -First 1)
    if ($branch -eq 'HEAD') { return $null }
    return $branch
}

function Parse-PorcelainPath {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 4) { return $null }
    $path = $Line.Substring(3)
    if ($path -match ' -> ') {
        $parts = $path -split ' -> '
        $path = $parts[$parts.Length - 1]
    }
    return (Normalize-PathText ($path.Trim('"')))
}

function Get-WorkingChangedPaths {
    $paths = New-Object System.Collections.ArrayList

    $statusLines = & git status --porcelain 2>$null
    foreach ($line in $statusLines) {
        Add-Unique $paths (Parse-PorcelainPath $line)
    }

    $diffNames = & git diff --name-only 2>$null
    foreach ($name in $diffNames) { Add-Unique $paths $name }

    $cachedNames = & git diff --cached --name-only 2>$null
    foreach ($name in $cachedNames) { Add-Unique $paths $name }

    $otherNames = & git ls-files --others --exclude-standard 2>$null
    foreach ($name in $otherNames) { Add-Unique $paths $name }

    return @(Filter-ChangedPaths $paths)
}

function Get-RangeBase {
    param([string]$RequestedBase)
    if (-not [string]::IsNullOrWhiteSpace($RequestedBase)) {
        if (-not (Git-Ref-Exists $RequestedBase)) {
            return [pscustomobject]@{
                Ref = $RequestedBase
                Source = 'explicit -Base'
                Warning = $null
                Error = "requested base ref does not exist: $RequestedBase"
            }
        }
        return [pscustomobject]@{
            Ref = $RequestedBase
            Source = 'explicit -Base'
            Warning = $null
            Error = $null
        }
    }

    $candidates = @(
        [pscustomobject]@{ Ref = '@{upstream}'; Source = 'upstream (@{upstream})' },
        [pscustomobject]@{ Ref = 'origin/master'; Source = 'origin/master fallback' },
        [pscustomobject]@{ Ref = 'origin/main'; Source = 'origin/main fallback' },
        [pscustomobject]@{ Ref = 'master'; Source = 'local master fallback' },
        [pscustomobject]@{ Ref = 'main'; Source = 'local main fallback' }
    )

    foreach ($candidate in $candidates) {
        if (Git-Ref-Exists $candidate.Ref) {
            return [pscustomobject]@{
                Ref = $candidate.Ref
                Source = $candidate.Source
                Warning = $null
                Error = $null
            }
        }
    }

    return [pscustomobject]@{
        Ref = 'HEAD'
        Source = 'HEAD fallback'
        Warning = 'no explicit -Base, upstream, origin/master, origin/main, local master, or local main was available; range is HEAD-only'
        Error = $null
    }
}

function Get-RangeChangedPaths {
    param([string]$ResolvedBase)
    $paths = New-Object System.Collections.ArrayList

    $result = Invoke-RangeNameOnly $ResolvedBase
    foreach ($name in $result.Paths) { Add-Unique $paths $name }
    return @(Filter-ChangedPaths $paths)
}

function Get-SubrepoRangeChangedPaths {
    param(
        [string]$Path,
        [string]$Prefix,
        [string]$ResolvedBase
    )

    $paths = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Paths = @()
            Range = $null
            Fallback = $null
            Warning = $null
        }
    }

    $inside = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or ($inside | Select-Object -First 1) -ne 'true') {
        return [pscustomobject]@{
            Paths = @()
            Range = $null
            Fallback = $null
            Warning = "$Prefix is present but is not a git worktree; subrepo range paths skipped"
        }
    }

    if (-not (Git-Ref-ExistsInRepo -Path $Path -Ref $ResolvedBase)) {
        return [pscustomobject]@{
            Paths = @()
            Range = $null
            Fallback = $null
            Warning = "$Prefix range base does not exist: $ResolvedBase"
        }
    }

    $triple = @(& git -C $Path diff --name-only "$ResolvedBase...HEAD" -- . ':(exclude)**/node_modules/**' 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($name in $triple) { Add-Unique $paths "$Prefix/$name" }
        return [pscustomobject]@{
            Paths = @(Filter-ChangedPaths $paths)
            Range = "${Prefix}:$ResolvedBase...HEAD"
            Fallback = $null
            Warning = $null
        }
    }

    $double = @(& git -C $Path diff --name-only "$ResolvedBase..HEAD" -- . ':(exclude)**/node_modules/**' 2>$null)
    foreach ($name in $double) { Add-Unique $paths "$Prefix/$name" }
    return [pscustomobject]@{
        Paths = @(Filter-ChangedPaths $paths)
        Range = "${Prefix}:$ResolvedBase..HEAD"
        Fallback = "${Prefix}:$ResolvedBase...HEAD"
        Warning = $null
    }
}

function Invoke-GitDiffCheck {
    param([string[]]$Arguments)
    $output = @(& git @Arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output
    }
}

function Invoke-SubrepoRangeDiffCheck {
    param(
        [string]$Path,
        [string]$Prefix,
        [string]$ResolvedBase
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Prefix = $Prefix
            Skipped = $true
            Warning = $null
            Label = $null
            ExitCode = 0
            Output = @()
        }
    }

    $inside = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or ($inside | Select-Object -First 1) -ne 'true') {
        return [pscustomobject]@{
            Prefix = $Prefix
            Skipped = $true
            Warning = "$Prefix is present but is not a git worktree; subrepo range diff check skipped"
            Label = $null
            ExitCode = 0
            Output = @()
        }
    }

    if (-not (Git-Ref-ExistsInRepo -Path $Path -Ref $ResolvedBase)) {
        return [pscustomobject]@{
            Prefix = $Prefix
            Skipped = $true
            Warning = "$Prefix range base does not exist: $ResolvedBase"
            Label = $null
            ExitCode = 0
            Output = @()
        }
    }

    $output = @(& git -C $Path diff --check "$ResolvedBase...HEAD" -- . ':(exclude)**/node_modules/**' 2>&1)
    $label = "subrepo range diff check: git -C $Prefix diff --check $ResolvedBase...HEAD -- . ':(exclude)**/node_modules/**'"
    if ($LASTEXITCODE -eq 0) {
        return [pscustomobject]@{
            Prefix = $Prefix
            Skipped = $false
            Warning = $null
            Label = $label
            ExitCode = 0
            Output = $output
        }
    }

    $fallbackOutput = @(& git -C $Path diff --check "$ResolvedBase..HEAD" -- . ':(exclude)**/node_modules/**' 2>&1)
    return [pscustomobject]@{
        Prefix = $Prefix
        Skipped = $false
        Warning = "$label failed; falling back to git -C $Prefix diff --check $ResolvedBase..HEAD -- . ':(exclude)**/node_modules/**'"
        Label = "subrepo range diff check: git -C $Prefix diff --check $ResolvedBase..HEAD -- . ':(exclude)**/node_modules/**'"
        ExitCode = $LASTEXITCODE
        Output = $fallbackOutput
    }
}

function Get-StatusSummary {
    param(
        [string]$Label,
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) { return "${Label}: missing" }

    $inside = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or ($inside | Select-Object -First 1) -ne 'true') {
        return "${Label}: present, not a git worktree"
    }

    $lines = @(& git -C $Path status --short 2>$null)
    if ($LASTEXITCODE -ne 0) { return "${Label}: status unavailable" }
    if ($lines.Count -eq 0) { return "${Label}: clean" }
    return "${Label}: $($lines.Count) changed path(s)"
}

function Has-AnyMatch {
    param(
        [string[]]$Paths,
        [string[]]$Patterns
    )
    foreach ($p in $Paths) {
        foreach ($pattern in $Patterns) {
            if ($p -match $pattern) { return $true }
        }
    }
    return $false
}

function Get-MatchingPaths {
    param(
        [string[]]$Paths,
        [string[]]$Patterns
    )
    $matches = New-Object System.Collections.ArrayList
    foreach ($p in $Paths) {
        foreach ($pattern in $Patterns) {
            if ($p -match $pattern) { Add-Unique $matches $p; break }
        }
    }
    return @($matches)
}

function Get-SubrepoWorkingChangedPaths {
    param(
        [string]$Path,
        [string]$Prefix
    )

    $paths = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    $inside = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or ($inside | Select-Object -First 1) -ne 'true') { return @() }

    $statusLines = & git -C $Path status --porcelain 2>$null
    foreach ($line in $statusLines) {
        $parsed = Parse-PorcelainPath $line
        if ($parsed) { Add-Unique $paths "$Prefix/$parsed" }
    }

    $diffNames = & git -C $Path diff --name-only 2>$null
    foreach ($name in $diffNames) { Add-Unique $paths "$Prefix/$name" }

    $cachedNames = & git -C $Path diff --cached --name-only 2>$null
    foreach ($name in $cachedNames) { Add-Unique $paths "$Prefix/$name" }

    $otherNames = & git -C $Path ls-files --others --exclude-standard 2>$null
    foreach ($name in $otherNames) { Add-Unique $paths "$Prefix/$name" }

    return @(Filter-ChangedPaths $paths)
}

function Merge-UniquePaths {
    param([object[]]$PathSets)

    $paths = New-Object System.Collections.ArrayList
    foreach ($set in $PathSets) {
        foreach ($path in $set) { Add-Unique $paths $path }
    }
    return @($paths)
}

function Test-FrontendDeploymentStub {
    param(
        [string]$RepoRoot,
        [string]$Path
    )

    $relativePath = (Normalize-PathText $Path)
    if (-not $relativePath) { return $false }
    $nativeRelativePath = $relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $fullPath = Join-Path $RepoRoot $nativeRelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { return $false }

    $content = Get-Content -LiteralPath $fullPath -Raw
    $lineCount = (($content -split "`r?`n") | Where-Object { $_ -ne '' }).Count

    return (
        $content -match '(?m)^# Moved\s*$' -and
        $content -match 'Canonical doc:' -and
        $content -match 'docs/deployment/' -and
        $lineCount -le 8
    )
}

function Invoke-RangeNameOnly {
    param([string]$ResolvedBase)

    $triple = @(& git diff --name-only "$ResolvedBase...HEAD" -- . ':(exclude)**/node_modules/**' 2>$null)
    if ($LASTEXITCODE -eq 0) {
        return [pscustomobject]@{
            Paths = $triple
            Range = "$ResolvedBase...HEAD"
            Fallback = $null
        }
    }

    $double = @(& git diff --name-only "$ResolvedBase..HEAD" -- . ':(exclude)**/node_modules/**' 2>$null)
    return [pscustomobject]@{
        Paths = $double
        Range = "$ResolvedBase..HEAD"
        Fallback = "$ResolvedBase...HEAD"
    }
}

if ($env:SKIP_AGENT_GOVERNANCE_CHECK -eq '1') {
    Write-Section 'Outcome'
    Write-Host 'SKIPPED: SKIP_AGENT_GOVERNANCE_CHECK=1 is set; agent governance check was not run.'
    Write-Section 'Changed files'
    Write-Host 'not collected because the check was explicitly skipped'
    Write-Section 'Key evidence'
    Write-Host 'skip environment variable was present'
    Write-Section 'Verification'
    Write-Host 'exit 0 by explicit skip rule'
    Write-Section 'Known risks'
    Write-Host 'governance, docs-sync, and git diff --check were not evaluated'
    Write-Section 'Next step'
    Write-Host 'unset SKIP_AGENT_GOVERNANCE_CHECK and rerun before normal review/push'
    exit 0
}

$repoRoot = Get-RepoRoot
Push-Location $repoRoot
try {
    $blocking = New-Object System.Collections.ArrayList
    $warnings = New-Object System.Collections.ArrayList
    $evidence = New-Object System.Collections.ArrayList
    $verification = New-Object System.Collections.ArrayList
    $reminders = New-Object System.Collections.ArrayList

    $resolvedBase = $null
    $rootWorkingDirtyPaths = @(Get-WorkingChangedPaths)
    $subrepoWorkingDirtyPaths = @(
        Get-SubrepoWorkingChangedPaths -Path 'admin_back_go' -Prefix 'admin_back_go'
        Get-SubrepoWorkingChangedPaths -Path 'admin_front_ts' -Prefix 'admin_front_ts'
    )
    $workingDirtyPaths = @(Merge-UniquePaths @($rootWorkingDirtyPaths, $subrepoWorkingDirtyPaths))
    if ($Mode -eq 'range') {
        $baseInfo = Get-RangeBase $Base
        $resolvedBase = $baseInfo.Ref
        if ($baseInfo.Error) {
            $changedPaths = @()
        } else {
            $rootRangeChangedPaths = @(Get-RangeChangedPaths $resolvedBase)
            $subrepoRangeResults = @(
                Get-SubrepoRangeChangedPaths -Path 'admin_back_go' -Prefix 'admin_back_go' -ResolvedBase $resolvedBase
                Get-SubrepoRangeChangedPaths -Path 'admin_front_ts' -Prefix 'admin_front_ts' -ResolvedBase $resolvedBase
            )
            $subrepoRangeChangedPaths = New-Object System.Collections.ArrayList
            foreach ($result in $subrepoRangeResults) {
                foreach ($path in @($result.Paths)) { Add-Unique $subrepoRangeChangedPaths $path }
                if ($result.Warning) { [void]$warnings.Add("subrepo range: $($result.Warning)") }
                if ($result.Range) { Add-Unique $evidence "subrepo-range=$($result.Range)" }
                if ($result.Fallback) { Add-Unique $evidence "subrepo-range-fallback=$($result.Fallback)" }
            }
            $changedPaths = @(Merge-UniquePaths @($rootRangeChangedPaths, $subrepoRangeChangedPaths))
        }
        Add-Unique $evidence "mode=range base=$resolvedBase"
        Add-Unique $evidence "base-source=$($baseInfo.Source)"
        if ($baseInfo.Error) { [void]$blocking.Add($baseInfo.Error); Add-Unique $evidence "base-error=$($baseInfo.Error)" }
        if ($baseInfo.Warning) { [void]$warnings.Add("range base fallback: $($baseInfo.Warning)") }
        if ($workingDirtyPaths.Count -gt 0) {
            Add-Unique $evidence "working-dirty-paths=$($workingDirtyPaths.Count) (reported separately; range changed files do not include dirty/untracked paths)"
        } else {
            Add-Unique $evidence 'working-dirty-paths=0'
        }
    } else {
        $changedPaths = @($workingDirtyPaths)
        Add-Unique $evidence 'mode=working'
    }
    Add-Unique $evidence "repo=$repoRoot"
    Add-Unique $evidence "strict=$([bool]$Strict)"

    if ($Mode -eq 'range' -and -not $baseInfo.Error) {
        $rangeDiffCheck = Invoke-GitDiffCheck -Arguments @('diff', '--check', "$resolvedBase...HEAD", '--', '.', ':(exclude)**/node_modules/**')
        $rangeDiffLabel = "range diff check: git diff --check $resolvedBase...HEAD -- . ':(exclude)**/node_modules/**'"
        if ($rangeDiffCheck.ExitCode -ne 0) {
            Add-Unique $evidence "$rangeDiffLabel failed; falling back to git diff --check $resolvedBase..HEAD -- . ':(exclude)**/node_modules/**'"
            foreach ($line in $rangeDiffCheck.Output) { Add-Unique $evidence "range-diff-check(...): $line" }
            $rangeDiffCheck = Invoke-GitDiffCheck -Arguments @('diff', '--check', "$resolvedBase..HEAD", '--', '.', ':(exclude)**/node_modules/**')
            $rangeDiffLabel = "range diff check: git diff --check $resolvedBase..HEAD -- . ':(exclude)**/node_modules/**'"
        }
        if ($rangeDiffCheck.ExitCode -ne 0) {
            [void]$blocking.Add("$rangeDiffLabel failed")
            foreach ($line in $rangeDiffCheck.Output) { Add-Unique $evidence "range-diff-check: $line" }
        } else {
            [void]$verification.Add("$rangeDiffLabel passed")
        }

        foreach ($subrepoDiffCheck in @(
            Invoke-SubrepoRangeDiffCheck -Path 'admin_back_go' -Prefix 'admin_back_go' -ResolvedBase $resolvedBase
            Invoke-SubrepoRangeDiffCheck -Path 'admin_front_ts' -Prefix 'admin_front_ts' -ResolvedBase $resolvedBase
        )) {
            if ($subrepoDiffCheck.Warning) { Add-Unique $evidence $subrepoDiffCheck.Warning }
            if ($subrepoDiffCheck.Skipped) { continue }
            if ($subrepoDiffCheck.ExitCode -ne 0) {
                [void]$blocking.Add("$($subrepoDiffCheck.Label) failed")
                foreach ($line in $subrepoDiffCheck.Output) { Add-Unique $evidence "subrepo-range-diff-check($($subrepoDiffCheck.Prefix)): $line" }
            } else {
                [void]$verification.Add("$($subrepoDiffCheck.Label) passed")
            }
        }
    }

    $workingDiffCheck = Invoke-GitDiffCheck -Arguments @('diff', '--check', '--', '.', ':(exclude)**/node_modules/**')
    if ($workingDiffCheck.ExitCode -ne 0) {
        [void]$blocking.Add("working diff check: git diff --check -- . ':(exclude)**/node_modules/**' failed")
        foreach ($line in $workingDiffCheck.Output) { Add-Unique $evidence "working-diff-check: $line" }
    } else {
        [void]$verification.Add("working diff check: git diff --check -- . ':(exclude)**/node_modules/**' passed")
    }

    $cachedDiffCheck = Invoke-GitDiffCheck -Arguments @('diff', '--cached', '--check', '--', '.', ':(exclude)**/node_modules/**')
    if ($cachedDiffCheck.ExitCode -ne 0) {
        [void]$blocking.Add("cached diff check: git diff --cached --check -- . ':(exclude)**/node_modules/**' failed")
        foreach ($line in $cachedDiffCheck.Output) { Add-Unique $evidence "cached-diff-check: $line" }
    } else {
        [void]$verification.Add("cached diff check: git diff --cached --check -- . ':(exclude)**/node_modules/**' passed")
    }

    $runtimeDocFactsScript = Join-Path $repoRoot 'scripts/check-runtime-doc-facts.ps1'
    if (Test-Path -LiteralPath $runtimeDocFactsScript) {
        $runtimeDocFactsOutput = @(& powershell -ExecutionPolicy Bypass -File $runtimeDocFactsScript 2>&1)
        if ($LASTEXITCODE -ne 0) {
            [void]$blocking.Add('runtime documentation fact check failed')
            foreach ($line in $runtimeDocFactsOutput) { Add-Unique $evidence "runtime-doc-facts: $line" }
        } else {
            [void]$verification.Add('runtime documentation fact check passed')
        }
    }

    $pathGovernancePaths = @(Merge-UniquePaths @($changedPaths, $workingDirtyPaths))
    foreach ($path in $pathGovernancePaths) {
        if ($path -match '^docs/superpowers/specs/([^/]+)$') {
            $name = $Matches[1]
            if ($name -notmatch '^\d{4}-\d{2}-\d{2}-[A-Za-z0-9][A-Za-z0-9._-]*-design\.md$') {
                [void]$blocking.Add("bad spec filename: $path")
            }
        }
        if ($path -match '^docs/superpowers/plans/([^/]+)$') {
            $name = $Matches[1]
            if ($name -notmatch '^\d{4}-\d{2}-\d{2}-[A-Za-z0-9][A-Za-z0-9._-]*\.md$') {
                [void]$blocking.Add("bad plan filename: $path")
            }
        }
        if ($path -match '^admin_back_go/docs/superpowers/(specs|plans)/' -and $path -notmatch '^admin_back_go/docs/superpowers/archive/') {
            [void]$blocking.Add("active backend-local superpowers spec/plan is not allowed: $path")
        }
        if ($path -match '^admin_front_ts/docs/deployment/[^/]+\.md$') {
            if (-not (Test-FrontendDeploymentStub -RepoRoot $repoRoot -Path $path)) {
                [void]$blocking.Add("frontend deployment docs must be root-owned with a moved stub only: $path")
            }
        }
    }

    $backendPatterns = @(
        '^admin_back_go/internal/module/',
        '^admin_back_go/internal/server/',
        '^admin_back_go/internal/.*/(route|handler|request|dto|response)\.go$',
        '^admin_back_go/internal/response/'
    )
    $frontendPatterns = @(
        '^admin_front_ts/src/api/',
        '^admin_front_ts/src/views/',
        '^admin_front_ts/src/router/',
        '^admin_front_ts/src/stores/'
    )
    $dbPatterns = @(
        '^admin_back_go/database/migrations/',
        '^admin\.sql$',
        '^admin_back_go/.*model.*\.go$'
    )
    $realtimePatterns = @(
        '^admin_back_go/internal/infra/realtime/',
        '^admin_back_go/internal/module/realtime/',
        '^admin_front_ts/src/(.*/)?realtime(/|$)',
        '^admin_front_ts/src/hooks/useWebSocket\.ts$',
        '^docs/contracts/admin-realtime-v1\.md$'
    )
    $queuePatterns = @(
        '^admin_back_go/internal/jobs/',
        '^admin_back_go/internal/infra/taskqueue/',
        '^admin_back_go/internal/infra/scheduler/',
        '^admin_back_go/internal/module/crontask/',
        '^docs/.*queue.*',
        '^docs/.*scheduler.*',
        '^docs/.*cron.*'
    )

    $docPatterns = @('^AGENTS\.md$', '^agents/', '^docs/status/', '^docs/contracts/', '^docs/testing/', '^docs/architecture/', '^admin_back_go/docs/')
    $backendDocPatterns = @('^docs/contracts/admin-api-v1\.md$', '^docs/status/current-status\.md$', '^docs/testing/smoke-matrix\.md$', '^admin_back_go/docs/architecture\.md$')
    $frontendDocPatterns = @('^docs/contracts/admin-api-v1\.md$', '^docs/status/current-status\.md$', '^docs/testing/smoke-matrix\.md$')
    $dbDocPatterns = @('^docs/status/current-status\.md$', '^docs/testing/smoke-matrix\.md$', '^docs/architecture/', '^admin_back_go/docs/architecture\.md$', '^docs/contracts/')
    $realtimeDocPatterns = @('^docs/contracts/admin-realtime-v1\.md$')
    $queueDocPatterns = @('^docs/.*queue.*', '^docs/.*scheduler.*', '^docs/.*cron.*', '^docs/architecture/', '^admin_back_go/docs/')

    $backendTouched = Has-AnyMatch $changedPaths $backendPatterns
    $frontendTouched = Has-AnyMatch $changedPaths $frontendPatterns
    $dbTouched = Has-AnyMatch $changedPaths $dbPatterns
    $realtimeTouched = Has-AnyMatch $changedPaths $realtimePatterns
    $queueTouched = Has-AnyMatch $changedPaths $queuePatterns

    if ($backendTouched) { Add-Unique $reminders 'backend runtime touched -> sync docs/contracts/admin-api-v1.md, docs/status/current-status.md, docs/testing/smoke-matrix.md, admin_back_go/docs/architecture.md as needed' }
    if ($frontendTouched) { Add-Unique $reminders 'frontend runtime touched -> sync docs/contracts/admin-api-v1.md, docs/status/current-status.md, docs/testing/smoke-matrix.md as needed' }
    if ($dbTouched) { Add-Unique $reminders 'DB/schema touched -> sync schema/current-status/architecture/smoke docs as needed' }
    if ($realtimeTouched) { Add-Unique $reminders 'realtime path/keyword touched -> sync docs/contracts/admin-realtime-v1.md as needed' }
    if ($queueTouched) { Add-Unique $reminders 'queue/cron/job path/keyword touched -> sync queue/scheduler docs as needed' }

    $runtimeTouched = ($backendTouched -or $frontendTouched -or $dbTouched -or $realtimeTouched -or $queueTouched)
    $anyDocsTouched = Has-AnyMatch $changedPaths $docPatterns
    if ($runtimeTouched -and -not $anyDocsTouched) {
        $msg = 'runtime path touched without any docs/status/contracts/testing/architecture/agent-doc path in changed files'
        if ($Strict) { [void]$blocking.Add($msg) } else { [void]$warnings.Add($msg) }
    }

    if ($Strict) {
        if ($backendTouched -and -not (Has-AnyMatch $changedPaths $backendDocPatterns)) { [void]$blocking.Add('Strict: backend runtime touched without backend contract/status/smoke/backend-architecture doc sync') }
        if ($frontendTouched -and -not (Has-AnyMatch $changedPaths $frontendDocPatterns)) { [void]$blocking.Add('Strict: frontend runtime touched without API contract/current-status/smoke doc sync') }
        if ($dbTouched -and -not (Has-AnyMatch $changedPaths $dbDocPatterns)) { [void]$blocking.Add('Strict: DB/schema touched without schema/current-status/architecture/smoke doc sync') }
        if ($realtimeTouched -and -not (Has-AnyMatch $changedPaths $realtimeDocPatterns)) { [void]$blocking.Add('Strict: realtime touched without docs/contracts/admin-realtime-v1.md sync') }
        if ($queueTouched -and -not (Has-AnyMatch $changedPaths $queueDocPatterns)) { [void]$blocking.Add('Strict: queue/cron/job touched without queue/scheduler docs sync') }
    }

    if ($blocking.Count -eq 0) {
        [void]$verification.Add('no blocking governance violations found')
    }

    Write-Section 'Outcome'
    if ($blocking.Count -gt 0) {
        Write-Host "BLOCKED: $($blocking.Count) blocking issue(s) found."
    } elseif ($warnings.Count -gt 0) {
        Write-Host "PASS_WITH_WARNINGS: no blocking issues; $($warnings.Count) warning(s)."
    } else {
        Write-Host 'PASS: no blocking governance violations found.'
    }

    if ($Mode -eq 'range') {
        Write-Section 'Range changed files'
    } else {
        Write-Section 'Working changed files'
    }
    if ($changedPaths.Count -eq 0) {
        Write-Host 'none'
    } else {
        foreach ($path in ($changedPaths | Sort-Object -Unique)) { Write-Host "- $path" }
    }

    if ($Mode -eq 'range') {
        Write-Section 'Working dirty files'
        if ($workingDirtyPaths.Count -eq 0) {
            Write-Host 'none'
        } else {
            foreach ($path in ($workingDirtyPaths | Sort-Object -Unique)) { Write-Host "- $path" }
        }
    }

    Write-Section 'Key evidence'
    foreach ($item in $evidence) { Write-Host "- $item" }
    foreach ($item in @(Get-StatusSummary 'root' $repoRoot; Get-StatusSummary 'admin_back_go' (Join-Path $repoRoot 'admin_back_go'); Get-StatusSummary 'admin_front_ts' (Join-Path $repoRoot 'admin_front_ts'))) {
        Write-Host "- $item"
    }
    foreach ($item in $reminders) { Write-Host "- reminder: $item" }
    foreach ($item in $warnings) { Write-Host "- warning: $item" }
    foreach ($item in $blocking) { Write-Host "- blocking: $item" }

    Write-Section 'Verification'
    foreach ($item in $verification) { Write-Host "- $item" }

    Write-Section 'Known risks'
    Write-Host '- checker is mostly path-based; runtime-doc-facts verifies selected manifests/routes/schema artifacts but does not prove full runtime behavior'
    Write-Host '- no DB/Redis/backend/frontend tests were run'
    Write-Host '- untracked file content is not covered by git diff --check until staged; only untracked path names are included in path governance'
    if ($Mode -eq 'range') { Write-Host '- range governance uses range changed files; dirty/untracked working paths are reported separately and are not part of the range diff' }
    if (-not $Strict) { Write-Host '- non-Strict mode prints docs-sync drift as warnings unless another blocking rule fails' }

    Write-Section 'Next step'
    if ($blocking.Count -gt 0) {
        Write-Host '- fix blocking issues, then rerun this checker'
    } elseif ($reminders.Count -gt 0) {
        Write-Host '- review reminders and run task-specific tests or smoke when the touched slice requires it'
    } else {
        Write-Host '- continue with task-specific verification or review'
    }

    if ($blocking.Count -gt 0) { exit 1 }
    exit 0
}
finally {
    Pop-Location
}
