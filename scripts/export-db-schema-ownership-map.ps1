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

function Get-LatestSchemaArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/db' -Filter 'mysql-live-schema-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^mysql-live-schema-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $date = $Matches[1]
        $sqlPath = Join-Path 'docs/db' "mysql-live-schema-$date.sql"
        if (-not (Test-Path -LiteralPath $sqlPath)) {
            throw "schema SQL artifact missing for $($file.Name): $sqlPath"
        }
        $items += [pscustomobject]@{
            Date = $date
            MdPath = "docs/db/$($file.Name)"
            SqlPath = ($sqlPath -replace '\\','/')
        }
    }
    if ($items.Count -eq 0) { throw 'no tracked MySQL live schema artifact found under docs/db' }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LiveTables {
    param([string]$SchemaPath)
    $tables = @()
    $inTable = $false
    foreach ($line in @(Get-Content -LiteralPath $SchemaPath)) {
        if ($line -eq '## Table inventory') {
            $inTable = $true
            continue
        }
        if ($inTable -and $line.StartsWith('## ')) { break }
        if (-not $inTable) { continue }
        if (-not $line.StartsWith('|')) { continue }
        if ($line -match '^\|\s*---') { continue }
        if ($line -match '^\|\s*Table\s*\|') { continue }
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 5) { continue }
        $tables += [pscustomobject]@{
            Table = Unwrap-CodeCell $cells[0]
            Rows = [int](Unwrap-CodeCell $cells[1])
            Engine = $cells[2]
            Collation = $cells[3]
            Comment = Unwrap-CodeCell $cells[4]
        }
    }
    return $tables
}

function Get-RelativeUnixPath {
    param([string]$Path)
    return ([System.IO.Path]::GetRelativePath((Resolve-Path -LiteralPath '.'), (Resolve-Path -LiteralPath $Path)) -replace '\\','/')
}

function Get-SourceOwner {
    param([string]$RelativePath)
    $parts = @($RelativePath -split '/')
    $moduleIndex = [Array]::IndexOf($parts, 'module')
    if ($moduleIndex -ge 0 -and $parts.Count -gt ($moduleIndex + 2)) {
        $after = @($parts[($moduleIndex + 1)..($parts.Count - 2)])
        $transportIndex = [Array]::IndexOf($after, 'transport')
        if ($transportIndex -gt 0) { $after = @($after[0..($transportIndex - 1)]) }
        return $after -join '/'
    }
    $sharedIndex = [Array]::IndexOf($parts, 'shared')
    if ($sharedIndex -ge 0 -and $parts.Count -gt ($sharedIndex + 1)) {
        return 'shared/' + $parts[$sharedIndex + 1]
    }
    $infraIndex = [Array]::IndexOf($parts, 'infra')
    if ($infraIndex -ge 0 -and $parts.Count -gt ($infraIndex + 1)) {
        return 'infra/' + $parts[$infraIndex + 1]
    }
    return ''
}

function Get-GoSourceFiles {
    $roots = @(
        'admin_back_go/internal/module',
        'admin_back_go/internal/shared',
        'admin_back_go/internal/infra'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.go' | Sort-Object FullName)) {
            if ($file.Name -like '*_test.go') { continue }
            $relative = Get-RelativeUnixPath $file.FullName
            if ($relative -match '/transport/') { continue }
            [pscustomobject]@{
                Path = $relative
                FullName = $file.FullName
                Owner = Get-SourceOwner $relative
                Text = Read-Text $file.FullName
            }
        }
    }
}

function Get-TableNameModels {
    param([object[]]$Files)
    $models = @{}
    $regex = [regex]::new('func\s*\((?<receiver>[^)]*)\)\s*TableName\(\)\s*string\s*\{\s*return\s+"(?<table>[^"]+)"', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($file in $Files) {
        foreach ($match in $regex.Matches($file.Text)) {
            $table = $match.Groups['table'].Value
            if (-not $models.ContainsKey($table)) { $models[$table] = @() }
            $models[$table] += [pscustomobject]@{
                Owner = $file.Owner
                File = $file.Path
            }
        }
    }
    return $models
}

function Get-ExplicitTableCalls {
    param([object[]]$Files)
    $calls = @{}
    $regex = [regex]'\.Table\(\s*"(?<table>[^"]+)"'
    foreach ($file in $Files) {
        foreach ($match in $regex.Matches($file.Text)) {
            $table = $match.Groups['table'].Value
            if (-not $calls.ContainsKey($table)) { $calls[$table] = @() }
            $calls[$table] += [pscustomobject]@{
                Owner = $file.Owner
                File = $file.Path
            }
        }
    }
    return $calls
}

function Find-TableReferences {
    param(
        [object[]]$Files,
        [string]$Table
    )
    $refs = @()
    $pattern = "(?<![A-Za-z0-9_])$([regex]::Escape($Table))(?![A-Za-z0-9_])"
    foreach ($file in $Files) {
        if ($file.Text -notmatch $pattern) { continue }
        $refs += [pscustomobject]@{
            Owner = $file.Owner
            File = $file.Path
        }
    }
    return $refs
}

function Format-CodeList {
    param([string[]]$Items)
    $values = @($Items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($values.Count -eq 0) { return '' }
    return ($values | ForEach-Object { "``$(Escape-Cell $_)``" }) -join ', '
}

function Format-SourceList {
    param([object[]]$Items)
    $values = @($Items | ForEach-Object { "$($_.Owner):$($_.File)" } | Sort-Object -Unique)
    if ($values.Count -eq 0) { return '' }
    return ($values | Select-Object -First 6 | ForEach-Object { "``$(Escape-Cell $_)``" }) -join '<br>'
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $schema = Get-LatestSchemaArtifact
    $tables = @(Get-LiveTables $schema.MdPath)
    $files = @(Get-GoSourceFiles)
    $modelsByTable = Get-TableNameModels $files
    $explicitCallsByTable = Get-ExplicitTableCalls $files

    $rows = @()
    foreach ($table in $tables) {
        $modelRefs = if ($modelsByTable.ContainsKey($table.Table)) { @($modelsByTable[$table.Table]) } else { @() }
        $explicitCalls = if ($explicitCallsByTable.ContainsKey($table.Table)) { @($explicitCallsByTable[$table.Table]) } else { @() }
        $allRefs = @(Find-TableReferences $files $table.Table)
        $ownerCandidates = @($modelRefs | ForEach-Object { $_.Owner } | Sort-Object -Unique)
        $referenceOwners = @($allRefs | ForEach-Object { $_.Owner } | Sort-Object -Unique)

        $coverage = 'live-schema-only'
        if ($modelRefs.Count -gt 0) {
            $coverage = 'go-model'
        } elseif ($explicitCalls.Count -gt 0) {
            $coverage = 'explicit-table-call'
        } elseif ($allRefs.Count -gt 0) {
            $coverage = 'go-reference-only'
        }

        $rows += [pscustomobject]@{
            Table = $table.Table
            Rows = $table.Rows
            Comment = $table.Comment
            Coverage = $coverage
            ModelOwners = @($ownerCandidates)
            ReferenceOwners = @($referenceOwners)
            ModelSources = @($modelRefs)
            ExplicitTableCalls = @($explicitCalls)
            ReferenceSources = @($allRefs)
        }
    }

    $coverageGroups = @($rows | Group-Object Coverage | Sort-Object Name)
    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# DB Schema Ownership Map Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines "Live schema artifact: ``$($schema.MdPath)`` / ``$($schema.SqlPath)``"
    Add-Line $lines ''
    Add-Line $lines 'This artifact starts from the live MySQL schema snapshot and maps each table to current Go source model/table references. It is a source ownership map, not a migration history and not proof that every code path is exercised at runtime.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Live schema artifact | ``$($schema.MdPath)`` |"
    Add-Line $lines "| Live schema SQL artifact | ``$($schema.SqlPath)`` |"
    Add-Line $lines "| Live tables reviewed | ``$($rows.Count)`` |"
    Add-Line $lines "| Go source files scanned | ``$($files.Count)`` |"
    foreach ($group in $coverageGroups) {
        Add-Line $lines "| $($group.Name) | ``$($group.Count)`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Tables without Go model ownership'
    Add-Line $lines ''
    Add-Line $lines '| Table | Rows | Coverage | Reference owners | Comment |'
    Add-Line $lines '| --- | ---: | --- | --- | --- |'
    foreach ($row in @($rows | Where-Object { $_.Coverage -ne 'go-model' } | Sort-Object Coverage, Table)) {
        Add-Line $lines "| $(Code-Cell $row.Table) | ``$($row.Rows)`` | $(Code-Cell $row.Coverage) | $(Format-CodeList $row.ReferenceOwners) | $(Escape-Cell $row.Comment) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Table ownership map'
    Add-Line $lines ''
    Add-Line $lines '| Table | Rows | Coverage | Model owner candidates | Reference owners | Model sources | Comment |'
    Add-Line $lines '| --- | ---: | --- | --- | --- | --- | --- |'
    foreach ($row in @($rows | Sort-Object Table)) {
        Add-Line $lines "| $(Code-Cell $row.Table) | ``$($row.Rows)`` | $(Code-Cell $row.Coverage) | $(Format-CodeList $row.ModelOwners) | $(Format-CodeList $row.ReferenceOwners) | $(Format-SourceList $row.ModelSources) | $(Escape-Cell $row.Comment) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "db-schema-ownership-map-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
    Write-Host "live_tables=$($rows.Count)"
    foreach ($group in $coverageGroups) {
        Write-Host "$($group.Name)=$($group.Count)"
    }
}
finally {
    Pop-Location
}
