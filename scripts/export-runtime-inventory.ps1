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

function Escape-Cell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return (($Value -replace '\|','\|') -replace "`r?`n", '<br>')
}

function Add-Line {
    param(
        [System.Collections.ArrayList]$Lines,
        [string]$Line = ''
    )
    [void]$Lines.Add($Line)
}

function Get-GoVersion {
    $match = Select-String -LiteralPath 'admin_back_go/go.mod' -Pattern '^go\s+(.+)$' | Select-Object -First 1
    if ($null -eq $match) { throw 'go version line missing: admin_back_go/go.mod' }
    return $match.Matches[0].Groups[1].Value.Trim()
}

function Read-PackageJson {
    param([string]$Path)
    return (Read-Text $Path | ConvertFrom-Json)
}

function Get-PackageVersion {
    param(
        [object]$PackageJson,
        [string]$Name
    )
    foreach ($sectionName in @('dependencies', 'devDependencies')) {
        $section = $PackageJson.$sectionName
        if ($null -eq $section) { continue }
        $property = $section.PSObject.Properties[$Name]
        if ($null -ne $property) { return [string]$property.Value }
    }
    return $null
}

function Get-LatestSchemaArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/db' -Filter 'mysql-live-schema-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^mysql-live-schema-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $date = $Matches[1]
        $sqlPath = Join-Path 'docs/db' "mysql-live-schema-$date.sql"
        if (-not (Test-Path -LiteralPath $sqlPath)) { throw "schema SQL artifact missing for $($file.Name): $sqlPath" }
        $items += [pscustomobject]@{ Date = $date; MdPath = "docs/db/$($file.Name)"; SqlPath = (Normalize-PathText $sqlPath) }
    }
    if ($items.Count -eq 0) { throw 'no tracked schema artifact found under docs/db' }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-SchemaBaseTableCount {
    param([string]$Path)
    $text = Read-Text $Path
    $match = [regex]::Match($text, '\|\s*Base tables\s*\|\s*(\d+)\s*\|')
    if (-not $match.Success) { throw "Base tables row missing: $Path" }
    return [int]$match.Groups[1].Value
}

function Get-BackendModuleInventory {
    $moduleRoot = Resolve-Path -LiteralPath 'admin_back_go/internal/module'
    foreach ($module in @(Get-ChildItem -LiteralPath $moduleRoot -Directory | Sort-Object Name)) {
        $surfaces = @()
        foreach ($transportDir in @(Get-ChildItem -LiteralPath $module.FullName -Recurse -Directory -Filter 'transport')) {
            foreach ($surface in @(Get-ChildItem -LiteralPath $transportDir.FullName -Directory | Sort-Object Name)) {
                $surfaces += (RelPath -Base $module.FullName -Path $surface.FullName)
            }
        }
        [pscustomobject]@{
            Module = $module.Name
            Surfaces = @($surfaces | Sort-Object -Unique)
        }
    }
}

function Get-RouteFragments {
    $routeFiles = @(Get-ChildItem -LiteralPath 'admin_back_go/internal/module' -Recurse -File -Include 'route.go','routes.go','*_route.go') | Sort-Object FullName
    $regex = [regex]'\.(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD)\(\s*"([^"]*)"'
    foreach ($file in $routeFiles) {
        $text = Read-Text $file.FullName
        $matches = @($regex.Matches($text))
        if ($matches.Count -eq 0) { continue }
        $fragments = @()
        foreach ($match in $matches) {
            $fragmentPath = $match.Groups[2].Value
            if ([string]::IsNullOrEmpty($fragmentPath)) { $fragmentPath = '/' }
            $fragments += "$($match.Groups[1].Value) $fragmentPath"
        }
        [pscustomobject]@{
            File = RelPath -Base '.' -Path $file.FullName
            Fragments = @($fragments | Sort-Object -Unique)
        }
    }
}

function Get-CanvasPages {
    foreach ($page in @(Get-ChildItem -LiteralPath 'canvas_front_next/src/app' -Recurse -Filter 'page.tsx' | Sort-Object FullName)) {
        RelPath -Base 'canvas_front_next/src/app' -Path $page.DirectoryName
    }
}

function Get-DirNames {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -Directory | Sort-Object Name | ForEach-Object { $_.Name })
}

function Get-FileNames {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -File | Sort-Object Name | ForEach-Object { $_.Name })
}

function Format-CodeList {
    param(
        [string[]]$Items,
        [string]$Separator = ', '
    )
    return (@($Items) | ForEach-Object { "``$_``" }) -join $Separator
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

    $schema = Get-LatestSchemaArtifact
    $schemaCount = Get-SchemaBaseTableCount $schema.MdPath
    $goVersion = Get-GoVersion
    $adminPkg = Read-PackageJson 'admin_front_ts/package.json'
    $canvasPkg = Read-PackageJson 'canvas_front_next/package.json'

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Runtime Inventory Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines 'This artifact is generated from current source manifests and directory structure. It is a navigation inventory, not runtime proof. Served API behavior, smoke/tests, and live MySQL schema still outrank this file.'
    Add-Line $lines ''
    Add-Line $lines '## Source summary'
    Add-Line $lines ''
    Add-Line $lines '| Source | Current fact |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Go version | ``$goVersion`` |"
    foreach ($dep in @('vue','vite','typescript','element-plus','pinia','vue-i18n','axios')) {
        Add-Line $lines "| admin_front_ts ``$dep`` | ``$(Get-PackageVersion $adminPkg $dep)`` |"
    }
    foreach ($dep in @('next','react','typescript','antd','zustand','@tanstack/react-query','axios')) {
        Add-Line $lines "| canvas_front_next ``$dep`` | ``$(Get-PackageVersion $canvasPkg $dep)`` |"
    }
    Add-Line $lines "| Latest MySQL schema artifact | ``$($schema.MdPath)`` / ``$($schema.SqlPath)`` |"
    Add-Line $lines "| Latest MySQL base table count | ``$schemaCount`` |"

    Add-Line $lines ''
    Add-Line $lines '## Backend module transport inventory'
    Add-Line $lines ''
    Add-Line $lines 'Rule: `callback` is an external callback HTTP surface exception, not a business platform.'
    Add-Line $lines ''
    Add-Line $lines '| Capability | HTTP surfaces from source tree |'
    Add-Line $lines '| --- | --- |'
    foreach ($item in Get-BackendModuleInventory) {
        $surfaceText = if ($item.Surfaces.Count -gt 0) { ($item.Surfaces | ForEach-Object { "``$_``" }) -join ', ' } else { '' }
        Add-Line $lines "| ``$($item.Module)`` | $surfaceText |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Backend route fragments from transport source'
    Add-Line $lines ''
    Add-Line $lines 'These are route fragments found in module transport route files. They are useful for code navigation, but full served paths must still be verified through Gin route registration, route metadata, contract docs, or smoke.'
    Add-Line $lines ''
    Add-Line $lines '| Route file | Method fragments |'
    Add-Line $lines '| --- | --- |'
    foreach ($route in Get-RouteFragments) {
        $fragmentText = ($route.Fragments | ForEach-Object { "``$_``" }) -join '<br>'
        Add-Line $lines "| ``$($route.File)`` | $fragmentText |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Admin Vue inventory'
    Add-Line $lines ''
    Add-Line $lines '| Area | Current source items |'
    Add-Line $lines '| --- | --- |'
    $adminApiModules = Format-CodeList (Get-DirNames 'admin_front_ts/src/api')
    $adminComponents = Format-CodeList (Get-DirNames 'admin_front_ts/src/components')
    $adminHooks = Format-CodeList (Get-FileNames 'admin_front_ts/src/hooks')
    $adminRouterFiles = Format-CodeList (Get-FileNames 'admin_front_ts/src/router')
    $adminStoreFiles = Format-CodeList (Get-FileNames 'admin_front_ts/src/store')
    Add-Line $lines "| API modules | $adminApiModules |"
    Add-Line $lines "| Shared components | $adminComponents |"
    Add-Line $lines "| Hooks | $adminHooks |"
    Add-Line $lines "| Router files | $adminRouterFiles |"
    Add-Line $lines "| Store files | $adminStoreFiles |"
    Add-Line $lines "| View files count | ``$(@(Get-ChildItem -LiteralPath 'admin_front_ts/src/views' -Recurse -File).Count)`` |"

    Add-Line $lines ''
    Add-Line $lines '## Canvas Next inventory'
    Add-Line $lines ''
    Add-Line $lines '| Area | Current source items |'
    Add-Line $lines '| --- | --- |'
    $canvasPages = Format-CodeList (Get-CanvasPages) '<br>'
    $canvasApiFiles = Format-CodeList (Get-FileNames 'canvas_front_next/src/services/api')
    $canvasFeatures = Format-CodeList (Get-DirNames 'canvas_front_next/src/features')
    $canvasStores = Format-CodeList (Get-FileNames 'canvas_front_next/src/stores')
    Add-Line $lines "| App pages | $canvasPages |"
    Add-Line $lines "| API service files | $canvasApiFiles |"
    Add-Line $lines "| Feature directories | $canvasFeatures |"
    Add-Line $lines "| Store files | $canvasStores |"

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-07'
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "runtime-inventory-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
}
finally {
    Pop-Location
}
