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

function Normalize-PathText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return ($Path -replace '\\','/')
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

function Get-LatestBackendRouteInventoryArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'backend-route-inventory-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^backend-route-inventory-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) { throw 'no generated backend route inventory artifact found under docs/knowledge' }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Unwrap-CodeCell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^``(?<value>.*)``$') { return $Matches.value }
    if ($trimmed -match '^`(?<value>.*)`$') { return $Matches.value }
    return $trimmed
}

function Get-RoutesFromInventory {
    param([string]$Path)
    $rows = @()
    $inRouteTable = $false
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ($line -eq '## Route inventory') {
            $inRouteTable = $true
            continue
        }
        if ($inRouteTable -and $line.StartsWith('## ')) { break }
        if (-not $inRouteTable) { continue }
        if (-not $line.StartsWith('|')) { continue }
        if ($line -match '^\|\s*---') { continue }
        if ($line -match '^\|\s*Capability\s*\|') { continue }

        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 13) { continue }
        $rows += [pscustomobject]@{
            Capability = Unwrap-CodeCell $cells[0]
            Surface = Unwrap-CodeCell $cells[1]
            File = Unwrap-CodeCell $cells[2]
            Line = [int](Unwrap-CodeCell $cells[3])
            Method = Unwrap-CodeCell $cells[4]
            InferredFullPath = Unwrap-CodeCell $cells[8]
            PathKind = Unwrap-CodeCell $cells[9]
            CallbackException = Unwrap-CodeCell $cells[10]
            PermissionCode = Unwrap-CodeCell $cells[11]
            Operation = Unwrap-CodeCell $cells[12]
        }
    }
    return @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.InferredFullPath) })
}

function Get-DocsText {
    param([string[]]$Paths)
    $parts = New-Object System.Collections.ArrayList
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $item = Get-Item -LiteralPath $path
        if ($item.PSIsContainer) {
            foreach ($file in @(Get-ChildItem -LiteralPath $path -Filter '*.md' -File | Sort-Object Name)) {
                [void]$parts.Add((Read-Text $file.FullName))
            }
        } else {
            [void]$parts.Add((Read-Text $path))
        }
    }
    return ($parts -join "`n")
}

function Get-ResourcePrefixes {
    param([string]$Path)
    $segments = @($Path.Trim('/') -split '/')
    $prefixes = @()
    if ($segments.Count -lt 4) { return $prefixes }
    for ($i = $segments.Count; $i -ge 4; $i--) {
        $candidateSegments = @($segments[0..($i - 1)] | Where-Object { $_ -notmatch '^:' -and $_ -ne '*path' })
        if ($candidateSegments.Count -lt 4) { continue }
        $candidate = '/' + ($candidateSegments -join '/')
        if ($candidate -ne $Path -and $candidate.Length -ge 14) {
            $prefixes += $candidate
        }
    }
    return @($prefixes | Select-Object -Unique)
}

function Test-TextContainsPath {
    param(
        [string]$Text,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return $Text.Contains($Path)
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $inventory = Get-LatestBackendRouteInventoryArtifact
    $routes = @(Get-RoutesFromInventory $inventory.Path)
    $contractText = Get-DocsText @('docs/contracts')
    $sourceDocsText = Get-DocsText @('docs/status', 'docs/knowledge')

    $classified = @()
    foreach ($route in $routes) {
        $path = $route.InferredFullPath
        $contractExact = Test-TextContainsPath $contractText $path
        $sourceExact = Test-TextContainsPath $sourceDocsText $path
        $prefixHit = ''
        if (-not $contractExact) {
            foreach ($prefix in Get-ResourcePrefixes $path) {
                if (Test-TextContainsPath $contractText $prefix) {
                    $prefixHit = $prefix
                    break
                }
            }
        }

        $class = 'undocumented-exact'
        if ($contractExact) {
            $class = 'contract-exact'
        } elseif (-not [string]::IsNullOrWhiteSpace($prefixHit)) {
            $class = 'contract-prefix-only'
        } elseif ($sourceExact) {
            $class = 'source-docs-only'
        }

        $classified += [pscustomobject]@{
            Classification = $class
            Capability = $route.Capability
            Surface = $route.Surface
            Method = $route.Method
            Path = $path
            RouteFile = $route.File
            Line = $route.Line
            PrefixHit = $prefixHit
            CallbackException = $route.CallbackException
            PermissionCode = $route.PermissionCode
            Operation = $route.Operation
        }
    }

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Backend Route Contract Drift Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines "Route source inventory: ``$($inventory.Path)``"
    Add-Line $lines ''
    Add-Line $lines 'This artifact compares current Go backend route source inventory with current Markdown contracts/status/knowledge docs. It is a drift report, not served endpoint proof and not an automatic compatibility verdict.'
    Add-Line $lines ''
    Add-Line $lines 'Classification rules: `contract-exact` means a docs/contracts file contains the full route path; `contract-prefix-only` means only a resource prefix is mentioned; `source-docs-only` means status/knowledge mentions the exact path but contracts do not; `undocumented-exact` means no exact Markdown contract hit was found.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Route inventory artifact | ``$($inventory.Path)`` |"
    Add-Line $lines "| Route registrations compared | ``$($classified.Count)`` |"
    foreach ($name in @('contract-exact','contract-prefix-only','source-docs-only','undocumented-exact')) {
        Add-Line $lines "| $name | ``$(@($classified | Where-Object { $_.Classification -eq $name }).Count)`` |"
    }
    Add-Line $lines "| Callback exception registrations | ``$(@($classified | Where-Object { $_.CallbackException -eq 'yes' }).Count)`` |"

    Add-Line $lines ''
    Add-Line $lines '## Surface classification summary'
    Add-Line $lines ''
    Add-Line $lines '| Surface | contract-exact | contract-prefix-only | source-docs-only | undocumented-exact |'
    Add-Line $lines '| --- | ---: | ---: | ---: | ---: |'
    foreach ($surfaceGroup in @($classified | Group-Object Surface | Sort-Object Name)) {
        $items = @($surfaceGroup.Group)
        Add-Line $lines "| $(Code-Cell $surfaceGroup.Name) | ``$(@($items | Where-Object { $_.Classification -eq 'contract-exact' }).Count)`` | ``$(@($items | Where-Object { $_.Classification -eq 'contract-prefix-only' }).Count)`` | ``$(@($items | Where-Object { $_.Classification -eq 'source-docs-only' }).Count)`` | ``$(@($items | Where-Object { $_.Classification -eq 'undocumented-exact' }).Count)`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Routes without exact contract hit'
    Add-Line $lines ''
    Add-Line $lines 'These rows need human review before editing contract docs. Prefix-only is not exact contract coverage.'
    Add-Line $lines ''
    Add-Line $lines '| Class | Capability | Surface | Method | Path | Route source | Prefix hit | Permission code | Operation metadata |'
    Add-Line $lines '| --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    foreach ($route in @($classified | Where-Object { $_.Classification -ne 'contract-exact' } | Sort-Object Classification, Surface, Capability, Path, Method)) {
        $source = "$($route.RouteFile):$($route.Line)"
        Add-Line $lines "| $(Code-Cell $route.Classification) | $(Code-Cell $route.Capability) | $(Code-Cell $route.Surface) | $(Code-Cell $route.Method) | $(Code-Cell $route.Path) | $(Code-Cell $source) | $(Code-Cell $route.PrefixHit) | $(Code-Cell $route.PermissionCode) | $(Code-Cell $route.Operation) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "backend-route-contract-drift-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
    Write-Host "routes=$($classified.Count)"
    foreach ($name in @('contract-exact','contract-prefix-only','source-docs-only','undocumented-exact')) {
        Write-Host "$name=$(@($classified | Where-Object { $_.Classification -eq $name }).Count)"
    }
}
finally {
    Pop-Location
}
