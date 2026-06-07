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

function RelPath {
    param(
        [string]$Base,
        [string]$Path
    )
    return Normalize-PathText ([System.IO.Path]::GetRelativePath((Resolve-Path -LiteralPath $Base), (Resolve-Path -LiteralPath $Path)))
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
    return @($trimmed.Trim('|') -split '\s*\|\s*' | ForEach-Object { Normalize-Cell $_ })
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
        if (@('Capability', 'Table').Contains([string]$cells[0])) { continue }
        $rows += ,$cells
    }
    return @($rows)
}

function Get-LatestArtifact {
    param(
        [string]$Filter,
        [string]$Regex,
        [string]$MissingMessage
    )
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter $Filter -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch $Regex) { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) { throw $MissingMessage }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Parse-CodeList {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split ',' | ForEach-Object {
        ($_ -replace '`','').Trim()
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Add-Unique {
    param(
        [System.Collections.ArrayList]$List,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    if (-not $List.Contains($Value)) { [void]$List.Add($Value) }
}

function Code-List {
    param([string[]]$Items)
    $clean = @($Items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($clean.Count -eq 0) { return '' }
    return ($clean | ForEach-Object { "``$(Escape-Cell $_)``" }) -join ', '
}

function Format-CountMap {
    param([hashtable]$Map)
    if ($Map.Count -eq 0) { return '' }
    return (@($Map.Keys | Sort-Object) | ForEach-Object { "``$_=$($Map[$_])``" }) -join ', '
}

function Add-Count {
    param(
        [hashtable]$Map,
        [string]$Key
    )
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = 0 }
    $Map[$Key]++
}

function Get-DirectGoFiles {
    param([string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory)) { return @() }
    return @(Get-ChildItem -LiteralPath $Directory -File -Filter '*.go' |
        Where-Object { $_.Name -notlike '*_test.go' } |
        Sort-Object Name |
        ForEach-Object { RelPath -Base '.' -Path $_.FullName })
}

function Get-DirectTestFiles {
    param([string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory)) { return @() }
    return @(Get-ChildItem -LiteralPath $Directory -File -Filter '*_test.go' |
        Sort-Object Name |
        ForEach-Object { RelPath -Base '.' -Path $_.FullName })
}

function Filter-Files {
    param(
        [string[]]$Files,
        [string]$Pattern
    )
    return @($Files | Where-Object { [System.IO.Path]::GetFileName($_) -like $Pattern })
}

function Get-NonTransportGoPackages {
    $moduleRoot = Resolve-Path -LiteralPath 'admin_back_go/internal/module'
    $packages = @()
    foreach ($dir in @(Get-ChildItem -LiteralPath $moduleRoot -Recurse -Directory | Sort-Object FullName)) {
        $relative = RelPath -Base $moduleRoot -Path $dir.FullName
        if ($relative -match '(^|/)transport($|/)') { continue }
        $files = @(Get-ChildItem -LiteralPath $dir.FullName -File -Filter '*.go' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '*_test.go' })
        if ($files.Count -eq 0) { continue }
        $packages += [pscustomobject]@{
            Capability = $relative
            Dir = "admin_back_go/internal/module/$relative"
            GoFiles = @($files | Sort-Object Name | ForEach-Object { RelPath -Base '.' -Path $_.FullName })
        }
    }
    return @($packages)
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot

try {
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

    $backendRouteArtifact = Get-LatestArtifact 'backend-route-inventory-*.md' '^backend-route-inventory-(\d{4}-\d{2}-\d{2})\.md$' 'no backend route inventory artifact found'
    $dbOwnershipArtifact = Get-LatestArtifact 'db-schema-ownership-map-*.md' '^db-schema-ownership-map-(\d{4}-\d{2}-\d{2})\.md$' 'no DB schema ownership map artifact found'

    $routeRows = foreach ($cells in Get-SectionRows $backendRouteArtifact.Path 'Route inventory') {
        if ($cells.Count -lt 12) { throw "unexpected route inventory row shape in $($backendRouteArtifact.Path): $($cells -join ' | ')" }
        if ($cells[3] -eq 'Line') { continue }
        if ($cells[3] -notmatch '^\d+$') { throw "route inventory row has non-numeric line: $($cells -join ' | ')" }
        [pscustomobject]@{
            Capability = $cells[0]
            Surface = $cells[1]
            RouteFile = $cells[2]
            Line = [int]$cells[3]
        }
    }

    $tableRows = foreach ($cells in Get-SectionRows $dbOwnershipArtifact.Path 'Table ownership map') {
        if ($cells.Count -lt 7) { throw "unexpected DB ownership row shape in $($dbOwnershipArtifact.Path): $($cells -join ' | ')" }
        [pscustomobject]@{
            Table = $cells[0]
            Coverage = $cells[2]
            ModelOwners = @(Parse-CodeList $cells[3])
            ModelSources = @($cells[5] -split '<br>' | ForEach-Object { ($_ -replace '`','').Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
    }

    $sourcePackages = @(Get-NonTransportGoPackages)
    $sourcePackageByCapability = @{}
    foreach ($package in $sourcePackages) { $sourcePackageByCapability[$package.Capability] = $package }

    $capabilities = New-Object System.Collections.ArrayList
    foreach ($route in $routeRows) { Add-Unique $capabilities $route.Capability }
    foreach ($table in $tableRows) {
        foreach ($owner in $table.ModelOwners) {
            if ($owner -eq 'shared/validate') { continue }
            if ($sourcePackageByCapability.ContainsKey($owner)) {
                Add-Unique $capabilities $owner
            }
        }
    }

    $capabilityList = @($capabilities | Sort-Object -Unique)
    $helperPackages = @($sourcePackages | Where-Object { $capabilityList -notcontains $_.Capability })

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Backend Capability Manifest Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines "Backend route inventory: ``$($backendRouteArtifact.Path)``"
    Add-Line $lines "DB schema ownership map: ``$($dbOwnershipArtifact.Path)``"
    Add-Line $lines ''
    Add-Line $lines 'This artifact maps current Go backend capabilities to source packages, platform transports, route counts, direct service/repository/model files, tests, and live MySQL table ownership. It is source navigation evidence, not runtime smoke and not import graph proof.'
    Add-Line $lines ''
    Add-Line $lines 'A package is promoted to capability only when it appears in backend route inventory or live DB model ownership. Helper packages with Go files but no route/table ownership are listed separately instead of being promoted by fallback.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Backend route inventory artifact | ``$($backendRouteArtifact.Path)`` |"
    Add-Line $lines "| DB schema ownership artifact | ``$($dbOwnershipArtifact.Path)`` |"
    Add-Line $lines "| Backend capabilities found | ``$($capabilityList.Count)`` |"
    Add-Line $lines "| Backend route registrations covered | ``$($routeRows.Count)`` |"

    $withRoutes = @($capabilityList | Where-Object { $capability = $_; @($routeRows | Where-Object { $_.Capability -eq $capability }).Count -gt 0 })
    $withTables = @($capabilityList | Where-Object {
        $capability = $_
        @($tableRows | Where-Object { $_.ModelOwners -contains $capability }).Count -gt 0
    })
    Add-Line $lines "| Capabilities with routes | ``$($withRoutes.Count)`` |"
    Add-Line $lines "| Capabilities with live DB model-owned tables | ``$($withTables.Count)`` |"
    Add-Line $lines "| Helper packages not promoted | ``$($helperPackages.Count)`` |"

    Add-Line $lines ''
    Add-Line $lines '## Capability manifest'
    Add-Line $lines ''
    Add-Line $lines '| Capability | Source dir | Route surfaces / counts | Route files | Direct source files | Service files | Repository files | Model files | Direct test files | Live DB model-owned tables | Notes |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |'

    foreach ($capability in $capabilityList) {
        $sourceDir = "admin_back_go/internal/module/$capability"
        $sourceExists = Test-Path -LiteralPath $sourceDir
        if (-not $sourceExists) { throw "capability source dir missing for ${capability}: $sourceDir" }

        $directFiles = @(Get-DirectGoFiles $sourceDir)
        $testFiles = @(Get-DirectTestFiles $sourceDir)
        $serviceFiles = @(Filter-Files $directFiles '*service*.go')
        $repositoryFiles = @(Filter-Files $directFiles '*repository*.go')
        $modelFiles = @(Filter-Files $directFiles '*model*.go')

        $capRoutes = @($routeRows | Where-Object { $_.Capability -eq $capability })
        $surfaceCounts = @{}
        foreach ($route in $capRoutes) { Add-Count $surfaceCounts $route.Surface }
        $routeFiles = @($capRoutes | ForEach-Object { "$($_.RouteFile):$($_.Line)" } | Sort-Object -Unique)
        $tables = @($tableRows | Where-Object { $_.ModelOwners -contains $capability } | ForEach-Object { $_.Table } | Sort-Object -Unique)

        $notes = @()
        if ($capRoutes.Count -eq 0) { $notes += 'no HTTP transport route in current inventory' }
        if ($tables.Count -eq 0) { $notes += 'no live DB model-owned table' }
        if ($serviceFiles.Count -eq 0) { $notes += 'no direct service file' }
        if ($repositoryFiles.Count -eq 0) { $notes += 'no direct repository file' }
        if ($modelFiles.Count -eq 0) { $notes += 'no direct model file' }

        Add-Line $lines "| ``$(Escape-Cell $capability)`` | ``$sourceDir`` | $(Format-CountMap $surfaceCounts) | $(Code-List $routeFiles) | $(Code-List $directFiles) | $(Code-List $serviceFiles) | $(Code-List $repositoryFiles) | $(Code-List $modelFiles) | $(Code-List $testFiles) | $(Code-List $tables) | $(Escape-Cell (($notes | Sort-Object -Unique) -join '; ')) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Helper packages not promoted to capability'
    Add-Line $lines ''
    Add-Line $lines 'These packages contain non-transport Go source but do not appear in backend route inventory or live DB model ownership. They are helpers until route/table ownership says otherwise.'
    Add-Line $lines ''
    Add-Line $lines '| Package | Source dir | Direct source files |'
    Add-Line $lines '| --- | --- | --- |'
    foreach ($package in $helperPackages) {
        Add-Line $lines "| ``$(Escape-Cell $package.Capability)`` | ``$($package.Dir)`` | $(Code-List $package.GoFiles) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outputPath = Join-Path $OutputDir "backend-capability-manifest-$OutputDate.md"
    Set-Content -LiteralPath $outputPath -Value ($lines -join "`r`n") -Encoding utf8
    Write-Host "Wrote $outputPath"
    Write-Host "backend_capabilities=$($capabilityList.Count)"
    Write-Host "backend_routes=$($routeRows.Count)"
    Write-Host "helper_packages=$($helperPackages.Count)"
}
finally {
    Pop-Location
}
