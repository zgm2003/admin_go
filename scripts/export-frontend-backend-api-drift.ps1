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

function Get-LatestArtifact {
    param(
        [string]$Directory,
        [string]$Prefix
    )
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Directory -Filter "$Prefix-*.md" -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch "^$([regex]::Escape($Prefix))-(\d{4}-\d{2}-\d{2})\.md$") { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "$Directory/$($file.Name)" -replace '\\','/'
        }
    }
    if ($items.Count -eq 0) {
        throw "no generated $Prefix artifact found under $Directory"
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Normalize-RoutePath {
    param([string]$Path)
    $value = Unwrap-CodeCell $Path
    if ([string]::IsNullOrWhiteSpace($value)) { return '' }
    $value = ($value -split '\?', 2)[0].Trim()
    $segments = @($value.Trim('/') -split '/')
    $normalized = @()
    foreach ($segment in $segments) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        if ($segment.StartsWith(':')) {
            $normalized += ':param'
        } elseif ($segment.StartsWith('*')) {
            $normalized += '*path'
        } else {
            $normalized += $segment
        }
    }
    if ($normalized.Count -eq 0) { return '/' }
    return '/' + ($normalized -join '/')
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

function Get-BackendRoutes {
    param([string]$Path)
    foreach ($cells in @(Get-MarkdownRows $Path '## Route inventory' '^\|\s*Capability\s*\|')) {
        if ($cells.Count -lt 13) { continue }
        $method = Unwrap-CodeCell $cells[4]
        $fullPath = Unwrap-CodeCell $cells[8]
        if ([string]::IsNullOrWhiteSpace($fullPath)) { continue }
        [pscustomobject]@{
            Capability = Unwrap-CodeCell $cells[0]
            Surface = Unwrap-CodeCell $cells[1]
            File = Unwrap-CodeCell $cells[2]
            Line = [int](Unwrap-CodeCell $cells[3])
            Method = $method
            Path = $fullPath
            NormalizedPath = Normalize-RoutePath $fullPath
            RouteKey = "$method $(Normalize-RoutePath $fullPath)"
        }
    }
}

function Get-FrontendBackendCalls {
    param([string]$Path)
    foreach ($cells in @(Get-MarkdownRows $Path '## Backend API calls under known prefixes' '^\|\s*Project\s*\|')) {
        if ($cells.Count -lt 7) { continue }
        $methodPath = Unwrap-CodeCell $cells[4]
        $parts = @($methodPath -split ' ', 2)
        if ($parts.Count -ne 2) { continue }
        $method = $parts[0]
        $pathValue = $parts[1]
        [pscustomobject]@{
            Project = Unwrap-CodeCell $cells[0]
            File = Unwrap-CodeCell $cells[1]
            Line = [int](Unwrap-CodeCell $cells[2])
            Client = Unwrap-CodeCell $cells[3]
            Method = $method
            Path = $pathValue
            NormalizedPath = Normalize-RoutePath $pathValue
            RawUrlExpression = Unwrap-CodeCell $cells[5]
            Kind = Unwrap-CodeCell $cells[6]
        }
    }
}

function Get-FrontendNonBackendRows {
    param([string]$Path)
    foreach ($cells in @(Get-MarkdownRows $Path '## Non-backend and infrastructure calls' '^\|\s*Project\s*\|')) {
        if ($cells.Count -lt 7) { continue }
        [pscustomobject]@{
            Project = Unwrap-CodeCell $cells[0]
            File = Unwrap-CodeCell $cells[1]
            Line = [int](Unwrap-CodeCell $cells[2])
            Client = Unwrap-CodeCell $cells[3]
            MethodPath = Unwrap-CodeCell $cells[4]
            RawUrlExpression = Unwrap-CodeCell $cells[5]
            Classification = Unwrap-CodeCell $cells[6]
        }
    }
}

function Get-MarkdownSummaryCount {
    param(
        [string]$Path,
        [string]$Name
    )
    $text = Read-Text $Path
    $pattern = '\|\s*' + [regex]::Escape($Name) + '\s*\|\s*`+(\d+)`+\s*\|'
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) { throw "summary count [$Name] missing: $Path" }
    return [int]$match.Groups[1].Value
}

function New-RouteIndexes {
    param([object[]]$Routes)
    $exact = @{}
    $path = @{}
    foreach ($route in $Routes) {
        $exact[$route.RouteKey] = $route
        if (-not $path.ContainsKey($route.NormalizedPath)) {
            $path[$route.NormalizedPath] = @()
        }
        $path[$route.NormalizedPath] += $route
        if ($route.Method -eq 'ANY') {
            foreach ($method in @('GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS')) {
                $exact["$method $($route.NormalizedPath)"] = $route
            }
        }
    }
    return [pscustomobject]@{
        Exact = $exact
        Path = $path
    }
}

function Find-RouteMatch {
    param(
        [object]$Call,
        [object]$Indexes
    )
    $key = "$($Call.Method) $($Call.NormalizedPath)"
    if ($Indexes.Exact.ContainsKey($key)) {
        return [pscustomobject]@{
            Classification = 'route-match'
            Route = $Indexes.Exact[$key]
            MethodCandidates = ''
        }
    }
    if ($Indexes.Path.ContainsKey($Call.NormalizedPath)) {
        $candidates = @($Indexes.Path[$Call.NormalizedPath] | ForEach-Object { $_.Method } | Sort-Object -Unique)
        return [pscustomobject]@{
            Classification = 'method-mismatch'
            Route = $null
            MethodCandidates = ($candidates -join ',')
        }
    }
    return [pscustomobject]@{
        Classification = 'no-backend-route'
        Route = $null
        MethodCandidates = ''
    }
}

function Get-BackendSourceOnlyNote {
    param([object]$Route)
    if ($Route.Path -in @('/health','/ready','/api/admin/v1/ping','/api/admin/v1/realtime/ws')) {
        return 'runtime/system endpoint'
    }
    if ($Route.Path.StartsWith('/api/admin/v1/queue-monitor')) {
        return 'queue monitor runtime/admin UI endpoint'
    }
    if ($Route.Path.StartsWith('/api/canvas/v1/payment/') -or $Route.Path.StartsWith('/api/canvas/v1/wallet/')) {
        return 'retained Canvas payment/wallet base domain, not active free-generation UI dependency'
    }
    if ($Route.Path.StartsWith('/api/admin/v1/upload-') -and $Route.Method -eq 'DELETE') {
        return 'covered by Admin uploadConfig parametric delete helper in source inventory'
    }
    return 'backend source route not referenced by exact frontend API inventory'
}

function Get-ClassCount {
    param(
        [hashtable]$Counts,
        [string]$Name
    )
    if ($Counts.ContainsKey($Name)) { return [int]$Counts[$Name] }
    return 0
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $backendArtifact = Get-LatestArtifact 'docs/knowledge' 'backend-route-inventory'
    $frontendArtifact = Get-LatestArtifact 'docs/knowledge' 'frontend-api-inventory'
    $backendRoutes = @(Get-BackendRoutes $backendArtifact.Path)
    $frontendBackendCalls = @(Get-FrontendBackendCalls $frontendArtifact.Path)
    $frontendNonBackendRows = @(Get-FrontendNonBackendRows $frontendArtifact.Path)
    $indexes = New-RouteIndexes $backendRoutes

    $classifiedCalls = @()
    $matchedRouteKeys = @{}
    foreach ($call in $frontendBackendCalls) {
        $match = Find-RouteMatch $call $indexes
        if ($null -ne $match.Route) {
            $matchedRouteKeys[$match.Route.RouteKey] = $true
        }
        $classifiedCalls += [pscustomobject]@{
            Classification = $match.Classification
            Project = $call.Project
            File = $call.File
            Line = $call.Line
            Client = $call.Client
            Method = $call.Method
            Path = $call.Path
            NormalizedPath = $call.NormalizedPath
            RawUrlExpression = $call.RawUrlExpression
            Kind = $call.Kind
            BackendCapability = if ($null -ne $match.Route) { $match.Route.Capability } else { '' }
            BackendSurface = if ($null -ne $match.Route) { $match.Route.Surface } else { '' }
            BackendSource = if ($null -ne $match.Route) { "$($match.Route.File):$($match.Route.Line)" } else { '' }
            MethodCandidates = $match.MethodCandidates
        }
    }

    $activeBackendRoutes = @($backendRoutes | Where-Object { $_.Surface -in @('admin','canvas') })
    $backendSourceOnly = @()
    foreach ($route in $activeBackendRoutes) {
        if (-not $matchedRouteKeys.ContainsKey($route.RouteKey)) {
            $backendSourceOnly += [pscustomobject]@{
                Surface = $route.Surface
                Capability = $route.Capability
                Method = $route.Method
                Path = $route.Path
                RouteSource = "$($route.File):$($route.Line)"
                Note = Get-BackendSourceOnlyNote $route
            }
        }
    }

    $nonBackendByClass = @{}
    foreach ($row in $frontendNonBackendRows) {
        if (-not $nonBackendByClass.ContainsKey($row.Classification)) {
            $nonBackendByClass[$row.Classification] = 0
        }
        $nonBackendByClass[$row.Classification] += 1
    }

    $routeMatchCount = @($classifiedCalls | Where-Object { $_.Classification -eq 'route-match' }).Count
    $methodMismatchCount = @($classifiedCalls | Where-Object { $_.Classification -eq 'method-mismatch' }).Count
    $noBackendRouteCount = @($classifiedCalls | Where-Object { $_.Classification -eq 'no-backend-route' }).Count
    $distinctFrontendKeys = @($classifiedCalls | ForEach-Object { "$($_.Method) $($_.NormalizedPath)" } | Sort-Object -Unique).Count
    $parametricCount = Get-ClassCount $nonBackendByClass 'backend-admin-parametric'
    $externalCount = Get-ClassCount $nonBackendByClass 'external'
    $blobDownloadCount = Get-ClassCount $nonBackendByClass 'blob/download'
    $wrapperProxyCount = (Get-ClassCount $nonBackendByClass 'wrapper-internal') + (Get-ClassCount $nonBackendByClass 'next-proxy')

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Frontend Backend API Drift Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines "Backend route inventory: ``$($backendArtifact.Path)``"
    Add-Line $lines "Frontend API inventory: ``$($frontendArtifact.Path)``"
    Add-Line $lines ''
    Add-Line $lines 'This artifact compares frontend source API calls with backend route source inventory. It is not served-route smoke, not browser runtime proof, and not an OpenAPI schema. Dynamic route segments are normalized to `:param`; backend `ANY` routes can satisfy exact frontend methods. Parametric helpers, wrapper internals, blob/download calls, external HTTP calls, and Next proxy calls stay outside exact route matching.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Backend route inventory artifact | ``$($backendArtifact.Path)`` |"
    Add-Line $lines "| Frontend API inventory artifact | ``$($frontendArtifact.Path)`` |"
    Add-Line $lines "| Backend route registrations available | ``$($backendRoutes.Count)`` |"
    Add-Line $lines "| Active backend admin/canvas routes | ``$($activeBackendRoutes.Count)`` |"
    Add-Line $lines "| Frontend exact backend API calls compared | ``$($frontendBackendCalls.Count)`` |"
    Add-Line $lines "| Distinct frontend exact method/path keys | ``$distinctFrontendKeys`` |"
    Add-Line $lines "| frontend-route-match | ``$routeMatchCount`` |"
    Add-Line $lines "| frontend-method-mismatch | ``$methodMismatchCount`` |"
    Add-Line $lines "| frontend-no-backend-route | ``$noBackendRouteCount`` |"
    Add-Line $lines "| Backend admin/canvas routes not referenced by exact frontend calls | ``$($backendSourceOnly.Count)`` |"
    Add-Line $lines "| Frontend parametric backend helper calls excluded from exact matching | ``$parametricCount`` |"
    Add-Line $lines "| Frontend external HTTP calls excluded from exact matching | ``$externalCount`` |"
    Add-Line $lines "| Frontend blob/download calls excluded from exact matching | ``$blobDownloadCount`` |"
    Add-Line $lines "| Frontend wrapper/proxy calls excluded from exact matching | ``$wrapperProxyCount`` |"
    Add-Line $lines "| Frontend inventory unresolved expressions | ``$(Get-MarkdownSummaryCount $frontendArtifact.Path 'Unresolved frontend API expressions')`` |"

    Add-Line $lines ''
    Add-Line $lines '## Frontend exact calls without backend route match'
    Add-Line $lines ''
    Add-Line $lines 'This table must stay empty for current exact frontend backend calls. If it gains rows, fix source or contract evidence instead of hiding it behind defaults.'
    Add-Line $lines ''
    Add-Line $lines '| Class | Project | Source | Client | Method | Path | Method candidates | Raw URL expression |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- | --- | --- |'
    foreach ($call in @($classifiedCalls | Where-Object { $_.Classification -ne 'route-match' } | Sort-Object Classification,Project,File,Line)) {
        $source = "$($call.File):$($call.Line)"
        Add-Line $lines "| $(Code-Cell $call.Classification) | $(Code-Cell $call.Project) | $(Code-Cell $source) | $(Code-Cell $call.Client) | $(Code-Cell $call.Method) | $(Code-Cell $call.Path) | $(Code-Cell $call.MethodCandidates) | $(Code-Cell $call.RawUrlExpression) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Backend admin/canvas routes not referenced by exact frontend calls'
    Add-Line $lines ''
    Add-Line $lines 'These are backend source routes with no exact frontend method/path call in the current source inventory. This is not automatically a bug: runtime endpoints, retained backend domains, websocket paths, queue monitor routes, and parametric frontend helpers are deliberately separated.'
    Add-Line $lines ''
    Add-Line $lines '| Surface | Capability | Method | Path | Route source | Note |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- |'
    foreach ($route in @($backendSourceOnly | Sort-Object Surface,Capability,Path,Method)) {
        Add-Line $lines "| $(Code-Cell $route.Surface) | $(Code-Cell $route.Capability) | $(Code-Cell $route.Method) | $(Code-Cell $route.Path) | $(Code-Cell $route.RouteSource) | $(Code-Cell $route.Note) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Frontend non-exact API rows excluded from route matching'
    Add-Line $lines ''
    Add-Line $lines '| Classification | Count |'
    Add-Line $lines '| --- | ---: |'
    foreach ($className in @($nonBackendByClass.Keys | Sort-Object)) {
        Add-Line $lines "| $(Code-Cell $className) | ``$($nonBackendByClass[$className])`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "frontend-backend-api-drift-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
    Write-Host "frontend_exact_calls=$($frontendBackendCalls.Count)"
    Write-Host "frontend_route_match=$routeMatchCount"
    Write-Host "frontend_method_mismatch=$methodMismatchCount"
    Write-Host "frontend_no_backend_route=$noBackendRouteCount"
    Write-Host "backend_source_only=$($backendSourceOnly.Count)"
}
finally {
    Pop-Location
}
