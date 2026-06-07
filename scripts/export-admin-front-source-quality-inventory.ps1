param(
    [string]$OutputDate = (Get-Date).ToString('yyyy-MM-dd'),
    [string]$OutputDir = 'docs/knowledge'
)

$ErrorActionPreference = 'Stop'

function Normalize-PathText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return ($Path -replace '\\','/')
}

function RelPath {
    param(
        [string]$Base,
        [string]$Path
    )
    return Normalize-PathText ([System.IO.Path]::GetRelativePath((Resolve-Path -LiteralPath $Base), (Resolve-Path -LiteralPath $Path)))
}

function Escape-Cell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return (($Value -replace '\|','\|') -replace '\r?\n', '<br>')
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

function Get-AdminFrontSourceFiles {
    $root = 'admin_front_ts/src'
    if (-not (Test-Path -LiteralPath $root)) { throw "source root missing: $root" }

    foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName)) {
        $relative = RelPath -Base '.' -Path $file.FullName
        if ($file.Extension -notin @('.ts', '.vue')) { continue }
        if ($file.Name -like '*.d.ts') { continue }
        if ($file.Name -match '\.(test|spec)\.ts$') { continue }
        if ($relative -match '(^|/)(__tests__|tests|generated|__generated__)(/|$)') { continue }
        $file.FullName
    }
}

function Remove-SourceComments {
    param([string]$Text)

    $builder = [System.Text.StringBuilder]::new()
    $quote = [char]0
    $escape = $false
    $lineComment = $false
    $blockComment = $false

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }

        if ($lineComment) {
            if ($ch -eq "`r" -or $ch -eq "`n") {
                [void]$builder.Append($ch)
                $lineComment = $false
            }
            continue
        }

        if ($blockComment) {
            if ($ch -eq '*' -and $next -eq '/') {
                $i++
                $blockComment = $false
                continue
            }
            if ($ch -eq "`r" -or $ch -eq "`n") {
                [void]$builder.Append($ch)
            }
            continue
        }

        if ($quote -ne [char]0) {
            [void]$builder.Append($ch)
            if ($escape) {
                $escape = $false
                continue
            }
            if ($ch -eq '\') {
                $escape = $true
                continue
            }
            if ($ch -eq $quote) {
                $quote = [char]0
            }
            continue
        }

        if ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') {
            $quote = $ch
            [void]$builder.Append($ch)
            continue
        }

        if ($ch -eq '/' -and $next -eq '/') {
            $lineComment = $true
            $i++
            continue
        }

        if ($ch -eq '/' -and $next -eq '*') {
            $blockComment = $true
            $i++
            continue
        }

        [void]$builder.Append($ch)
    }

    return $builder.ToString()
}

function Add-Finding {
    param(
        [System.Collections.ArrayList]$Findings,
        [string]$Kind,
        [string]$File,
        [int]$Line,
        [string]$Snippet
    )
    [void]$Findings.Add([pscustomobject]@{
        Kind = $Kind
        File = $File
        Line = $Line
        Snippet = $Snippet.Trim()
    })
}

function Test-DirectExternalHttpCall {
    param(
        [string[]]$Lines,
        [int]$Index
    )
    $line = $Lines[$Index]
    return $line -match '\baxios\.(get|post|put|patch|delete|request)\s*\(' -and $line -match 'https?://'
}

function Scan-SourceFile {
    param([string]$Path)

    $relative = RelPath -Base '.' -Path $Path
    $text = Get-Content -Raw -LiteralPath $Path
    $stripped = Remove-SourceComments $text
    $lines = [regex]::Split($stripped, '\r?\n')
    $findings = New-Object System.Collections.ArrayList

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $lineNumber = $index + 1
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        foreach ($match in @([regex]::Matches($line, '\bany\b'))) {
            Add-Finding $findings 'any' $relative $lineNumber $line
        }
        foreach ($match in @([regex]::Matches($line, '\bas\s+any\b'))) {
            Add-Finding $findings 'as-any' $relative $lineNumber $line
        }
        foreach ($match in @([regex]::Matches($line, '\bRecord\s*<\s*string\s*,\s*any\s*>'))) {
            Add-Finding $findings 'record-string-any' $relative $lineNumber $line
        }
        foreach ($match in @([regex]::Matches($line, '\bcatch\s*\(\s*[^)]*:\s*any\s*\)'))) {
            Add-Finding $findings 'catch-any' $relative $lineNumber $line
        }
        if ($line -match '\|\|') {
            Add-Finding $findings 'logical-or-fallback' $relative $lineNumber $line
        }
        if ($line -match '\?\?') {
            Add-Finding $findings 'nullish-fallback' $relative $lineNumber $line
        }
        if ($line -match '\?\.' -and $line -match '(\|\||\?\?)') {
            Add-Finding $findings 'optional-chain-fallback' $relative $lineNumber $line
        }
        if (Test-DirectExternalHttpCall -Lines $lines -Index $index) {
            Add-Finding $findings 'direct-external-http' $relative $lineNumber $line
        }
    }

    return @($findings)
}

function Count-Kind {
    param(
        [object[]]$Findings,
        [string]$Kind
    )
    return @($Findings | Where-Object { $_.Kind -eq $Kind }).Count
}

function Count-Kinds {
    param(
        [object[]]$Findings,
        [string[]]$Kinds
    )
    return @($Findings | Where-Object { $_.Kind -in $Kinds }).Count
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

    $files = @(Get-AdminFrontSourceFiles | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
    if ($files.Count -eq 0) { throw 'no Admin Vue source files found for source-quality inventory' }

    $findings = @()
    foreach ($file in $files) {
        $findings += @(Scan-SourceFile $file)
    }

    $fallbackKinds = @('logical-or-fallback', 'nullish-fallback', 'optional-chain-fallback')
    $priorityFiles = @(
        'admin_front_ts/src/views/Layout/components/Header/index.vue',
        'admin_front_ts/src/views/Layout/components/Header/components/SearchDialog.vue',
        'admin_front_ts/src/views/Login/composables/useForgotPassword.ts',
        'admin_front_ts/src/components/JsonEditor/src/index.vue',
        'admin_front_ts/src/components/DIcon/src/index.vue',
        'admin_front_ts/src/views/Main/component/display/components/Editor.vue',
        'admin_front_ts/src/components/DownloadManager/src/download.ts',
        'admin_front_ts/src/views/Main/component/download/index.vue',
        'admin_front_ts/src/views/Main/test/index.vue',
        'admin_front_ts/src/hooks/web/useValidator.ts',
        'admin_front_ts/src/views/Main/component/upload/index.vue',
        'admin_front_ts/src/views/Main/component/form/index.vue',
        'admin_front_ts/src/views/Main/component/display/index.vue',
        'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue',
        'admin_front_ts/src/api/ai/images.ts'
    )

    $topFiles = @($findings |
        Group-Object File |
        Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        Select-Object -First 20)

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Admin Front Source Quality Inventory Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines 'This is a regex source inventory, not type-aware semantic proof. It is meant to expose current Admin Vue quality debt shape before narrow refactors; it is not a claim that every row is a bug.'
    Add-Line $lines ''
    Add-Line $lines '## Source summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Count |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Source files scanned | ``$($files.Count)`` |"
    Add-Line $lines "| Findings found | ``$($findings.Count)`` |"
    Add-Line $lines "| any candidates | ``$(Count-Kind $findings 'any')`` |"
    Add-Line $lines "| as any candidates | ``$(Count-Kind $findings 'as-any')`` |"
    Add-Line $lines "| Record<string, any> candidates | ``$(Count-Kind $findings 'record-string-any')`` |"
    Add-Line $lines "| catch(error: any) candidates | ``$(Count-Kind $findings 'catch-any')`` |"
    Add-Line $lines "| logical-or fallback candidates | ``$(Count-Kind $findings 'logical-or-fallback')`` |"
    Add-Line $lines "| nullish-coalescing fallback candidates | ``$(Count-Kind $findings 'nullish-fallback')`` |"
    Add-Line $lines "| optional-chain fallback candidates | ``$(Count-Kind $findings 'optional-chain-fallback')`` |"
    Add-Line $lines "| fallback candidates | ``$(Count-Kinds $findings $fallbackKinds)`` |"
    Add-Line $lines "| direct external HTTP candidates | ``$(Count-Kind $findings 'direct-external-http')`` |"

    Add-Line $lines ''
    Add-Line $lines '## Priority evidence'
    Add-Line $lines ''
    Add-Line $lines '| Source | Current evidence |'
    Add-Line $lines '| --- | --- |'
    foreach ($priorityFile in $priorityFiles) {
        $rows = @($findings | Where-Object { $_.File -eq $priorityFile } | Sort-Object Line,Kind)
        if ($rows.Count -eq 0) {
            Add-Line $lines "| ``$priorityFile`` | no regex finding in configured categories; keep only if another generated inventory owns this evidence |"
            continue
        }
        $evidence = (@($rows | Select-Object -First 5) | ForEach-Object { "L$($_.Line) ``$($_.Kind)`` $(Code-Cell $_.Snippet)" }) -join '<br>'
        Add-Line $lines "| ``$priorityFile`` | $evidence |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Top files by finding count'
    Add-Line $lines ''
    Add-Line $lines '| Source | Findings |'
    Add-Line $lines '| --- | ---: |'
    foreach ($group in $topFiles) {
        Add-Line $lines "| ``$(Escape-Cell $group.Name)`` | ``$($group.Count)`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Findings by kind'
    Add-Line $lines ''
    Add-Line $lines '| Kind | Count |'
    Add-Line $lines '| --- | ---: |'
    foreach ($group in @($findings | Group-Object Kind | Sort-Object Name)) {
        Add-Line $lines "| ``$($group.Name)`` | ``$($group.Count)`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Full findings'
    Add-Line $lines ''
    Add-Line $lines '| Kind | Source | Line | Snippet |'
    Add-Line $lines '| --- | --- | ---: | --- |'
    foreach ($finding in @($findings | Sort-Object File,Line,Kind,Snippet)) {
        Add-Line $lines "| ``$($finding.Kind)`` | ``$(Escape-Cell $finding.File)`` | ``$($finding.Line)`` | $(Code-Cell $finding.Snippet) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Scanner boundary'
    Add-Line $lines ''
    Add-Line $lines '```text'
    Add-Line $lines 'Included: admin_front_ts/src/**/*.ts and admin_front_ts/src/**/*.vue.'
    Add-Line $lines 'Excluded: *.d.ts, tests/specs, and generated directories.'
    Add-Line $lines 'Comment handling: line and block comments are stripped before scanning while preserving line numbers.'
    Add-Line $lines 'Detection: any, as any, Record<string, any>, catch(...: any), ||, ??, optional chaining with fallback on the same line, and direct axios external HTTP calls.'
    Add-Line $lines 'Not proof: regex rows require owner review before refactor; existing debt does not fail build by itself.'
    Add-Line $lines '```'

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07'
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "admin-front-source-quality-inventory-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8

    Write-Host "Wrote $outPath"
    Write-Host "source_files_scanned=$($files.Count)"
    Write-Host "any_candidates=$(Count-Kind $findings 'any')"
    Write-Host "as_any_candidates=$(Count-Kind $findings 'as-any')"
    Write-Host "fallback_candidates=$(Count-Kinds $findings $fallbackKinds)"
    Write-Host "direct_external_http_candidates=$(Count-Kind $findings 'direct-external-http')"
}
finally {
    Pop-Location
}
