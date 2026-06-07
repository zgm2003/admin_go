param(
    [string]$OutputDate = (Get-Date).ToString('yyyy-MM-dd'),
    [string]$OutputDir = 'docs/knowledge'
)

$ErrorActionPreference = 'Stop'

function Normalize-PathText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return ($Path -replace '\\','/')
}

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "required file missing: $Path" }
    return Get-Content -Raw -LiteralPath $Path
}

function Add-Line {
    param(
        [System.Collections.ArrayList]$Lines,
        [string]$Line = ''
    )
    [void]$Lines.Add($Line)
}

function Escape-Cell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return (($Value -replace '\|','\|') -replace "`r?`n", '<br>')
}

function Code-List {
    param([string[]]$Items)
    $clean = @($Items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($clean.Count -eq 0) { return '' }
    return ($clean | ForEach-Object { "``$(Escape-Cell $_)``" }) -join ', '
}

function Normalize-Cell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    $v = $Value.Trim()
    $v = $v -replace '\\\|','|'
    $v = $v -replace '^`+',''
    $v = $v -replace '`+$',''
    return $v.Trim()
}

function Split-MarkdownRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if (-not ($trimmed.StartsWith('|') -and $trimmed.EndsWith('|'))) { return @() }
    if ($trimmed -match '^\|\s*-+') { return @() }
    $inner = $trimmed.Trim('|')
    return @($inner -split '\s*\|\s*' | ForEach-Object { Normalize-Cell $_ })
}

function Get-SectionRows {
    param(
        [string]$Path,
        [string]$SectionName
    )
    $rows = @()
    $inSection = $false
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ($line -eq "## $SectionName") {
            $inSection = $true
            continue
        }
        if ($inSection -and $line -match '^##\s+') { break }
        if (-not $inSection) { continue }
        $cells = @(Split-MarkdownRow $line)
        if ($cells.Count -eq 0) { continue }
        if (@('Capability', 'Workspace', 'Table', 'Category').Contains([string]$cells[0])) { continue }
        $rows += ,$cells
    }
    return @($rows)
}

function Get-LatestArtifact {
    param(
        [string]$Directory,
        [string]$Filter,
        [string]$Regex,
        [string]$MissingMessage
    )
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Directory -Filter $Filter -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch $Regex) { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "$(Normalize-PathText $Directory)/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) { throw $MissingMessage }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestSchemaArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/db' -Filter 'mysql-live-schema-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^mysql-live-schema-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $date = $Matches[1]
        $sqlPath = Join-Path 'docs/db' "mysql-live-schema-$date.sql"
        if (-not (Test-Path -LiteralPath $sqlPath)) { throw "schema SQL artifact missing for $($file.Name): $sqlPath" }
        $items += [pscustomobject]@{
            Date = $date
            MdPath = "docs/db/$($file.Name)"
            SqlPath = Normalize-PathText $sqlPath
        }
    }
    if ($items.Count -eq 0) { throw 'no tracked schema artifact found under docs/db' }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
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

function Parse-CodeList {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split ',' | ForEach-Object {
        ($_ -replace '`','').Trim()
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Normalize-ApiPath {
    param([string]$Path)
    $p = $Path.Trim()
    $p = $p -replace ':[A-Za-z_][A-Za-z0-9_]*', ':param'
    $p = $p -replace '\*[A-Za-z_][A-Za-z0-9_]*', '*param'
    return $p
}

function Add-Count {
    param(
        [hashtable]$Map,
        [string]$Key,
        [int]$Amount = 1
    )
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = 0 }
    $Map[$Key] += $Amount
}

function Add-SetValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = New-Object System.Collections.ArrayList }
    if (-not $Map[$Key].Contains($Value)) { [void]$Map[$Key].Add($Value) }
}

function Find-BackendRoute {
    param(
        [object[]]$Routes,
        [hashtable]$RouteByKey,
        [string]$Method,
        [string]$Path
    )
    $normalizedPath = Normalize-ApiPath $Path
    $exactKey = "$Method $normalizedPath"
    if ($RouteByKey.ContainsKey($exactKey)) { return $RouteByKey[$exactKey] }

    $anyKey = "ANY $normalizedPath"
    if ($RouteByKey.ContainsKey($anyKey)) { return $RouteByKey[$anyKey] }

    foreach ($route in $Routes) {
        if ($route.Method -ne $Method -and $route.Method -ne 'ANY') { continue }
        $routePath = Normalize-ApiPath $route.Path
        if ($routePath -notlike '*/*param') { continue }
        $prefix = $routePath -replace '/\*param$',''
        if ($normalizedPath -eq $prefix -or $normalizedPath.StartsWith("$prefix/")) {
            return $route
        }
    }

    return $null
}

function Format-CountMap {
    param([hashtable]$Map)
    if ($Map.Count -eq 0) { return '' }
    return (@($Map.Keys | Sort-Object) | ForEach-Object { "``$_=$($Map[$_])``" }) -join ', '
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot

try {
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

    $schemaArtifact = Get-LatestSchemaArtifact
    $backendRouteArtifact = Get-LatestArtifact 'docs/knowledge' 'backend-route-inventory-*.md' '^backend-route-inventory-(\d{4}-\d{2}-\d{2})\.md$' 'no backend route inventory artifact found'
    $frontendApiArtifact = Get-LatestArtifact 'docs/knowledge' 'frontend-api-inventory-*.md' '^frontend-api-inventory-(\d{4}-\d{2}-\d{2})\.md$' 'no frontend API inventory artifact found'
    $dbOwnershipArtifact = Get-LatestArtifact 'docs/knowledge' 'db-schema-ownership-map-*.md' '^db-schema-ownership-map-(\d{4}-\d{2}-\d{2})\.md$' 'no DB schema ownership map artifact found'
    $sourceOnlyArtifact = Get-LatestArtifact 'docs/knowledge' 'api-source-only-route-review-*.md' '^api-source-only-route-review-(\d{4}-\d{2}-\d{2})\.md$' 'no API source-only route review artifact found'

    $routeRows = foreach ($cells in Get-SectionRows $backendRouteArtifact.Path 'Route inventory') {
        if ($cells.Count -lt 12) { throw "unexpected route inventory row shape in $($backendRouteArtifact.Path): $($cells -join ' | ')" }
        if ($cells[3] -eq 'Line') { continue }
        if ($cells[3] -notmatch '^\d+$') { throw "route inventory row has non-numeric line in $($backendRouteArtifact.Path): $($cells -join ' | ')" }
        [pscustomobject]@{
            Capability = $cells[0]
            Surface = $cells[1]
            RouteFile = $cells[2]
            Line = [int]$cells[3]
            Method = $cells[4]
            Path = $cells[8]
        }
    }

    $routeByKey = @{}
    foreach ($route in $routeRows) {
        if ([string]::IsNullOrWhiteSpace($route.Path)) { throw "route inventory row without inferred path: $($route.RouteFile):$($route.Line)" }
        $key = "$($route.Method) $(Normalize-ApiPath $route.Path)"
        if (-not $routeByKey.ContainsKey($key)) {
            $routeByKey[$key] = $route
        }
    }

    $frontendRows = foreach ($cells in Get-SectionRows $frontendApiArtifact.Path 'Backend API calls under known prefixes') {
        if ($cells.Count -lt 7) { throw "unexpected frontend API row shape in $($frontendApiArtifact.Path): $($cells -join ' | ')" }
        if ($cells[2] -eq 'Line') { continue }
        if ($cells[2] -notmatch '^\d+$') { throw "frontend API row has non-numeric line in $($frontendApiArtifact.Path): $($cells -join ' | ')" }
        [pscustomobject]@{
            Workspace = $cells[0]
            File = $cells[1]
            Line = [int]$cells[2]
            Helper = $cells[3]
            Request = $cells[4]
            Classification = $cells[6]
        }
    }

    $exactFrontendCalls = @($frontendRows | Where-Object { $_.Classification -in @('admin-prefix', 'canvas-prefix') })
    $assignedFrontendCalls = @()
    $unassignedFrontendCalls = @()
    foreach ($call in $exactFrontendCalls) {
        if ($call.Request -notmatch '^(?<method>[A-Z]+)\s+(?<path>/api/(admin|canvas)/v1.*)$') {
            $unassignedFrontendCalls += $call
            continue
        }
        $route = Find-BackendRoute -Routes $routeRows -RouteByKey $routeByKey -Method $Matches.method -Path $Matches.path
        if ($null -eq $route) {
            $unassignedFrontendCalls += $call
            continue
        }
        $assignedFrontendCalls += [pscustomobject]@{
            Workspace = $call.Workspace
            File = $call.File
            Line = $call.Line
            Request = $call.Request
            Capability = $route.Capability
            Surface = $route.Surface
        }
    }

    if ($unassignedFrontendCalls.Count -gt 0) {
        $sample = ($unassignedFrontendCalls | Select-Object -First 10 | ForEach-Object { "$($_.File):$($_.Line) $($_.Request)" }) -join '; '
        throw "frontend exact backend API calls not assigned to backend route inventory: $($unassignedFrontendCalls.Count); sample: $sample"
    }

    $tableRows = foreach ($cells in Get-SectionRows $dbOwnershipArtifact.Path 'Table ownership map') {
        if ($cells.Count -lt 7) { throw "unexpected DB ownership row shape in $($dbOwnershipArtifact.Path): $($cells -join ' | ')" }
        [pscustomobject]@{
            Table = $cells[0]
            Rows = $cells[1]
            Coverage = $cells[2]
            ModelOwners = @(Parse-CodeList $cells[3])
            ReferenceOwners = @(Parse-CodeList $cells[4])
        }
    }

    $sourceOnlyRows = foreach ($cells in Get-SectionRows $sourceOnlyArtifact.Path 'Full classification') {
        if ($cells.Count -lt 8) { throw "unexpected source-only review row shape in $($sourceOnlyArtifact.Path): $($cells -join ' | ')" }
        [pscustomobject]@{
            Category = $cells[0]
            Surface = $cells[1]
            Capability = $cells[2]
            Method = $cells[3]
            Path = $cells[4]
        }
    }

    $capabilities = New-Object System.Collections.ArrayList
    foreach ($route in $routeRows) { Add-SetValue @{ '__root' = $capabilities } '__root' $route.Capability }
    foreach ($call in $assignedFrontendCalls) { Add-SetValue @{ '__root' = $capabilities } '__root' $call.Capability }
    foreach ($row in $tableRows) {
        $owners = @($row.ModelOwners)
        if ($owners.Count -eq 0 -and $row.Coverage -eq 'live-schema-only') { $owners = @('live-schema-only') }
        foreach ($owner in $owners) { Add-SetValue @{ '__root' = $capabilities } '__root' $owner }
    }
    foreach ($row in $sourceOnlyRows) { Add-SetValue @{ '__root' = $capabilities } '__root' $row.Capability }
    $capabilityList = @($capabilities | Sort-Object -Unique)

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Full-stack Module Map Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines "Backend route inventory: ``$($backendRouteArtifact.Path)``"
    Add-Line $lines "Frontend API inventory: ``$($frontendApiArtifact.Path)``"
    Add-Line $lines "DB schema ownership map: ``$($dbOwnershipArtifact.Path)``"
    Add-Line $lines "API source-only route review: ``$($sourceOnlyArtifact.Path)``"
    Add-Line $lines "Live schema artifact: ``$($schemaArtifact.MdPath)`` / ``$($schemaArtifact.SqlPath)``"
    Add-Line $lines ''
    Add-Line $lines 'This artifact joins current source inventories into a module-level navigation map. It is not served-route smoke, not browser runtime proof, and not migration history. If a frontend exact backend API call cannot be joined to backend route inventory, this exporter fails instead of assigning a fallback owner.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Backend route inventory artifact | ``$($backendRouteArtifact.Path)`` |"
    Add-Line $lines "| Frontend API inventory artifact | ``$($frontendApiArtifact.Path)`` |"
    Add-Line $lines "| DB schema ownership artifact | ``$($dbOwnershipArtifact.Path)`` |"
    Add-Line $lines "| API source-only review artifact | ``$($sourceOnlyArtifact.Path)`` |"
    Add-Line $lines "| Backend route registrations joined | ``$($routeRows.Count)`` |"
    Add-Line $lines "| Frontend exact backend API calls assigned | ``$($assignedFrontendCalls.Count)`` |"
    Add-Line $lines "| Unassigned frontend exact backend API calls | ``$($unassignedFrontendCalls.Count)`` |"
    Add-Line $lines "| Live DB tables mapped | ``$($tableRows.Count)`` |"
    Add-Line $lines "| Live schema-only tables | ``$(($tableRows | Where-Object { $_.Coverage -eq 'live-schema-only' }).Count)`` |"
    Add-Line $lines "| Source-only routes reviewed | ``$($sourceOnlyRows.Count)`` |"
    Add-Line $lines "| Owner-decision-required routes | ``$(($sourceOnlyRows | Where-Object { $_.Category -eq 'owner-decision-required' }).Count)`` |"
    Add-Line $lines "| Capabilities in joined map | ``$($capabilityList.Count)`` |"

    Add-Line $lines ''
    Add-Line $lines '## Platform route and frontend-call summary'
    Add-Line $lines ''
    Add-Line $lines '| Surface / workspace | Count |'
    Add-Line $lines '| --- | ---: |'
    foreach ($group in @($routeRows | Group-Object Surface | Sort-Object Name)) {
        Add-Line $lines "| backend surface ``$($group.Name)`` routes | ``$($group.Count)`` |"
    }
    foreach ($group in @($assignedFrontendCalls | Group-Object Workspace | Sort-Object Name)) {
        Add-Line $lines "| frontend ``$($group.Name)`` exact backend calls | ``$($group.Count)`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Module map'
    Add-Line $lines ''
    Add-Line $lines '| Capability | Backend surfaces / routes | Frontend exact backend calls | Live DB tables by model owner | Source-only review categories | Notes |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- |'

    foreach ($capability in $capabilityList) {
        $capRoutes = @($routeRows | Where-Object { $_.Capability -eq $capability })
        $surfaceCounts = @{}
        foreach ($route in $capRoutes) { Add-Count $surfaceCounts $route.Surface }

        $capCalls = @($assignedFrontendCalls | Where-Object { $_.Capability -eq $capability })
        $workspaceCounts = @{}
        foreach ($call in $capCalls) { Add-Count $workspaceCounts $call.Workspace }

        $tables = New-Object System.Collections.ArrayList
        foreach ($table in $tableRows) {
            $owners = @($table.ModelOwners)
            if ($owners.Count -eq 0 -and $table.Coverage -eq 'live-schema-only') { $owners = @('live-schema-only') }
            if ($owners -contains $capability) {
                [void]$tables.Add($table.Table)
            }
        }

        $reviewCounts = @{}
        foreach ($row in @($sourceOnlyRows | Where-Object { $_.Capability -eq $capability })) {
            Add-Count $reviewCounts $row.Category
        }

        $notes = @()
        if ($capRoutes.Count -eq 0) { $notes += 'no backend route in current route inventory' }
        if ($capCalls.Count -eq 0) { $notes += 'no exact frontend backend call assigned' }
        if ($tables.Count -eq 0) { $notes += 'no live DB model-owner table' }
        if ($capability -eq 'live-schema-only') { $notes = @('live table without Go model ownership') }

        Add-Line $lines "| ``$(Escape-Cell $capability)`` | $(Format-CountMap $surfaceCounts) | $(Format-CountMap $workspaceCounts) | $(Code-List @($tables)) | $(Format-CountMap $reviewCounts) | $(Escape-Cell (($notes | Sort-Object -Unique) -join '; ')) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Frontend join invariant'
    Add-Line $lines ''
    Add-Line $lines 'Every `admin-prefix` / `canvas-prefix` frontend call from the frontend API inventory must map to a backend route inventory row by method and normalized path parameters. This prevents hidden `unknown capability` fallback.'
    Add-Line $lines ''
    Add-Line $lines '```text'
    Add-Line $lines "exact frontend backend calls = $($exactFrontendCalls.Count)"
    Add-Line $lines "assigned frontend backend calls = $($assignedFrontendCalls.Count)"
    Add-Line $lines "unassigned frontend backend calls = $($unassignedFrontendCalls.Count)"
    Add-Line $lines '```'

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outputPath = Join-Path $OutputDir "full-stack-module-map-$OutputDate.md"
    Set-Content -LiteralPath $outputPath -Value ($lines -join "`r`n") -Encoding utf8
    Write-Host "Wrote $outputPath"
    Write-Host "backend_routes=$($routeRows.Count)"
    Write-Host "frontend_exact_assigned=$($assignedFrontendCalls.Count)"
    Write-Host "live_db_tables=$($tableRows.Count)"
}
finally {
    Pop-Location
}
