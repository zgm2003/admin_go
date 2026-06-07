param(
    [string]$OutputDate = (Get-Date).ToString('yyyy-MM-dd'),
    [string]$OutputDir = 'docs/knowledge'
)

$ErrorActionPreference = 'Stop'

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "required file missing: $Path" }
    return Get-Content -Raw -LiteralPath $Path
}

function Escape-Cell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return (($Value -replace '\|','\|') -replace "`r?`n", '<br>')
}

function Code-Cell {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return "``$(Escape-Cell $Value)``"
}

function Add-Line {
    param(
        [System.Collections.ArrayList]$Lines,
        [string]$Line = ''
    )
    [void]$Lines.Add($Line)
}

function Unwrap-CodeCell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^``(?<value>.*)``$') { return $Matches.value }
    if ($trimmed -match '^`(?<value>.*)`$') { return $Matches.value }
    return $trimmed
}

function Get-LatestFrontendBackendApiDriftArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'frontend-backend-api-drift-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^frontend-backend-api-drift-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated frontend/backend API drift artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-MarkdownRows {
    param(
        [string]$Path,
        [string]$Section,
        [string]$HeaderRegex
    )
    $rows = @()
    $inTable = $false
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ($line -eq $Section) {
            $inTable = $true
            continue
        }
        if ($inTable -and $line.StartsWith('## ')) { break }
        if (-not $inTable) { continue }
        if (-not $line.StartsWith('|')) { continue }
        if ($line -match '^\|\s*---') { continue }
        if ($line -match $HeaderRegex) { continue }
        $rows += ,@($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    }
    return $rows
}

function Get-SourceOnlyRows {
    param([string]$Path)
    foreach ($cells in @(Get-MarkdownRows $Path '## Backend admin/canvas routes not referenced by exact frontend calls' '^\|\s*Surface\s*\|')) {
        if ($cells.Count -lt 6) { continue }
        [pscustomobject]@{
            Surface = Unwrap-CodeCell $cells[0]
            Capability = Unwrap-CodeCell $cells[1]
            Method = Unwrap-CodeCell $cells[2]
            Path = Unwrap-CodeCell $cells[3]
            RouteSource = Unwrap-CodeCell $cells[4]
            DriftNote = Unwrap-CodeCell $cells[5]
        }
    }
}

function Classify-Route {
    param([object]$Route)
    $path = $Route.Path
    if ($path -in @('/health', '/ready', '/api/admin/v1/ping', '/api/admin/v1/realtime/ws')) {
        return [pscustomobject]@{
            Category = 'runtime-system-endpoint'
            Evidence = 'health/ready/ping/websocket endpoint; exact frontend HTTP API call is not required'
            NextAction = 'keep documented as runtime/backend-only unless served behavior changes'
        }
    }
    if ($path.StartsWith('/api/admin/v1/queue-monitor')) {
        return [pscustomobject]@{
            Category = 'admin-queue-monitor-endpoint'
            Evidence = 'admin_front_ts uses queue-monitor UI iframe/auth-cookie path; stats/failed and wildcard UI routes are backend runtime/asynqmon surfaces'
            NextAction = 'keep as backend/admin tooling endpoint; do not require exact CRUD wrapper call'
        }
    }
    if ($path.StartsWith('/api/canvas/v1/payment/') -or $path.StartsWith('/api/canvas/v1/wallet/')) {
        return [pscustomobject]@{
            Category = 'retained-canvas-payment-wallet-domain'
            Evidence = 'retained in contract as payment/wallet base domain; current Canvas free-generation UI does not depend on wallet/recharge'
            NextAction = 'keep retained-domain wording; do not reintroduce billing UI without product decision'
        }
    }
    if ($Route.Surface -eq 'admin' -and $Route.Capability -eq 'uploadconfig' -and $Route.Method -eq 'DELETE') {
        return [pscustomobject]@{
            Category = 'frontend-parametric-helper-covered'
            Evidence = 'admin_front_ts/src/api/system/uploadConfig.ts deleteResource(base, ...) selects concrete upload base at call-site'
            NextAction = 'keep excluded from exact matching unless frontend inventory learns interprocedural base resolution'
        }
    }
    if ($path -eq '/api/admin/v1/ai-agents/:id/test') {
        return [pscustomobject]@{
            Category = 'owner-decision-required'
            Evidence = 'backend route/service exists; current Admin frontend inventory has provider/payment/mail/sms test calls but no ai-agent test call'
            NextAction = 'decide whether to expose AI agent test action, document backend-only API, or delete route'
        }
    }
    if ($path -eq '/api/admin/v1/users/:id/status') {
        return [pscustomobject]@{
            Category = 'owner-decision-required'
            Evidence = 'backend ChangeStatus route/service exists; current Admin user API inventory uses batch PATCH /users and does not call dedicated status route'
            NextAction = 'decide whether user status toggle should call dedicated route, stay batch-only, or remove route'
        }
    }
    if ($path -eq '/api/canvas/v1/auth/logout') {
        return [pscustomobject]@{
            Category = 'owner-decision-required'
            Evidence = 'backend Canvas logout route/tests exist; current Canvas store clears local session and has no exact logout API call'
            NextAction = 'decide whether Canvas logout should revoke server session or stay local-only with backend route documented/deleted'
        }
    }
    return [pscustomobject]@{
        Category = 'owner-decision-required'
        Evidence = 'no project-specific source-only classification rule matched'
        NextAction = 'review owner and choose active frontend gap, backend-only endpoint, retained future domain, or dead route'
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $drift = Get-LatestFrontendBackendApiDriftArtifact
    $sourceOnlyRows = @(Get-SourceOnlyRows $drift.Path)
    $classified = @()
    foreach ($route in $sourceOnlyRows) {
        $classification = Classify-Route $route
        $classified += [pscustomobject]@{
            Category = $classification.Category
            Surface = $route.Surface
            Capability = $route.Capability
            Method = $route.Method
            Path = $route.Path
            RouteSource = $route.RouteSource
            Evidence = $classification.Evidence
            NextAction = $classification.NextAction
        }
    }

    $ownerDecisionRows = @($classified | Where-Object { $_.Category -eq 'owner-decision-required' })
    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# API Source-only Route Review Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines "Frontend/backend API drift source: ``$($drift.Path)``"
    Add-Line $lines ''
    Add-Line $lines 'This artifact classifies backend admin/canvas routes that are not referenced by exact frontend API calls. It is a review aid, not runtime proof and not a deletion list.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Frontend/backend API drift artifact | ``$($drift.Path)`` |"
    Add-Line $lines "| Source-only routes reviewed | ``$($classified.Count)`` |"
    foreach ($group in @($classified | Group-Object Category | Sort-Object Name)) {
        Add-Line $lines "| $($group.Name) | ``$($group.Count)`` |"
    }
    Add-Line $lines "| Owner-decision-required routes | ``$($ownerDecisionRows.Count)`` |"

    Add-Line $lines ''
    Add-Line $lines '## Owner-decision-required routes'
    Add-Line $lines ''
    Add-Line $lines '| Surface | Capability | Method | Path | Route source | Evidence | Next action |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- | --- |'
    foreach ($route in @($ownerDecisionRows | Sort-Object Surface, Capability, Path, Method)) {
        Add-Line $lines "| $(Code-Cell $route.Surface) | $(Code-Cell $route.Capability) | $(Code-Cell $route.Method) | $(Code-Cell $route.Path) | $(Code-Cell $route.RouteSource) | $(Code-Cell $route.Evidence) | $(Code-Cell $route.NextAction) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Full classification'
    Add-Line $lines ''
    Add-Line $lines '| Category | Surface | Capability | Method | Path | Route source | Evidence | Next action |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- | --- | --- |'
    foreach ($route in @($classified | Sort-Object Category, Surface, Capability, Path, Method)) {
        Add-Line $lines "| $(Code-Cell $route.Category) | $(Code-Cell $route.Surface) | $(Code-Cell $route.Capability) | $(Code-Cell $route.Method) | $(Code-Cell $route.Path) | $(Code-Cell $route.RouteSource) | $(Code-Cell $route.Evidence) | $(Code-Cell $route.NextAction) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "api-source-only-route-review-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
    Write-Host "source_only_routes=$($classified.Count)"
    Write-Host "owner_decision_required=$($ownerDecisionRows.Count)"
    foreach ($group in @($classified | Group-Object Category | Sort-Object Name)) {
        Write-Host "$($group.Name)=$($group.Count)"
    }
}
finally {
    Pop-Location
}
