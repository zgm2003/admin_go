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

function Convert-HttpMethodName {
    param([string]$Name)
    $upper = $Name.ToUpperInvariant()
    switch ($upper) {
        'GET' { return 'GET' }
        'POST' { return 'POST' }
        'PUT' { return 'PUT' }
        'PATCH' { return 'PATCH' }
        'DELETE' { return 'DELETE' }
        'OPTIONS' { return 'OPTIONS' }
        'HEAD' { return 'HEAD' }
        'ANY' { return 'ANY' }
        default { throw "unsupported HTTP method token: $Name" }
    }
}

function Join-RoutePath {
    param(
        [string]$Prefix,
        [string]$Path
    )
    if ($null -eq $Path) { return $null }
    if ([string]::IsNullOrEmpty($Prefix)) { return $Path }
    if ([string]::IsNullOrEmpty($Path)) { return $Prefix }
    if ($Prefix.EndsWith('/') -and $Path.StartsWith('/')) {
        return $Prefix.TrimEnd('/') + $Path
    }
    if ((-not $Prefix.EndsWith('/')) -and (-not $Path.StartsWith('/'))) {
        return $Prefix + '/' + $Path
    }
    return $Prefix + $Path
}

function Get-GoStringField {
    param(
        [string]$Body,
        [string]$Name
    )
    $match = [regex]::Match($Body, "(?m)\b$Name\s*:\s*""([^""]*)""")
    if ($match.Success) { return $match.Groups[1].Value }
    return ''
}

function Get-StringConstants {
    param([string[]]$Lines)
    $constants = @{}
    foreach ($line in $Lines) {
        if ($line -match '^\s*const\s+(?<name>[A-Za-z_]\w*)\s*=\s*"(?<value>[^"]*)"') {
            $constants[$Matches.name] = $Matches.value
            continue
        }
        if ($line -match '^\s*(?<name>[A-Za-z_]\w*)\s*=\s*"(?<value>[^"]*)"') {
            $constants[$Matches.name] = $Matches.value
        }
    }
    return $constants
}

function Resolve-RouteExpression {
    param(
        [string]$Expression,
        [hashtable]$Constants
    )
    $expr = $Expression.Trim()
    if ($expr -match '^"(?<value>[^"]*)"$') {
        return [pscustomobject]@{ Value = $Matches.value; Kind = 'literal'; Raw = $expr }
    }
    if ($expr -match '^(?<name>[A-Za-z_]\w*)$') {
        $name = $Matches.name
        if ($Constants.ContainsKey($name)) {
            return [pscustomobject]@{ Value = $Constants[$name]; Kind = "const:$name"; Raw = $expr }
        }
        return [pscustomobject]@{ Value = $null; Kind = 'unresolved'; Raw = $expr }
    }
    if ($expr -match '^(?<name>[A-Za-z_]\w*)\s*\+\s*"(?<suffix>[^"]*)"$') {
        $name = $Matches.name
        if ($Constants.ContainsKey($name)) {
            return [pscustomobject]@{ Value = $Constants[$name] + $Matches.suffix; Kind = "const-concat:$name"; Raw = $expr }
        }
        return [pscustomobject]@{ Value = $null; Kind = 'unresolved'; Raw = $expr }
    }
    return [pscustomobject]@{ Value = $null; Kind = 'unresolved'; Raw = $expr }
}

function Get-CapabilitySurface {
    param([string]$FilePath)
    $relative = RelPath -Base 'admin_back_go/internal/module' -Path $FilePath
    $parts = @($relative -split '/')
    $transportIndex = [Array]::IndexOf($parts, 'transport')
    if ($transportIndex -lt 1 -or $parts.Count -le ($transportIndex + 1)) {
        return [pscustomobject]@{
            Capability = ''
            Surface = ''
        }
    }
    return [pscustomobject]@{
        Capability = ($parts[0..($transportIndex - 1)] -join '/')
        Surface = $parts[$transportIndex + 1]
    }
}

function Get-RouteMetadata {
    $text = Read-Text 'admin_back_go/internal/bootstrap/route_meta.go'
    $permissions = @{}
    $operations = @{}

    $permissionRegex = [regex]'middleware\.NewRouteKey\(http\.Method(?<method>[A-Za-z]+),\s*"(?<path>[^"]+)"\):\s*"(?<code>[^"]+)"'
    foreach ($match in $permissionRegex.Matches($text)) {
        $method = Convert-HttpMethodName $match.Groups['method'].Value
        $path = $match.Groups['path'].Value
        $permissions["$method $path"] = $match.Groups['code'].Value
    }

    $operationRegex = [regex]::new(
        'middleware\.NewRouteKey\(http\.Method(?<method>[A-Za-z]+),\s*"(?<path>[^"]+)"\):\s*\{(?<body>.*?)\},',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    foreach ($match in $operationRegex.Matches($text)) {
        $method = Convert-HttpMethodName $match.Groups['method'].Value
        $path = $match.Groups['path'].Value
        $body = $match.Groups['body'].Value
        $operations["$method $path"] = [pscustomobject]@{
            Module = Get-GoStringField $body 'Module'
            Action = Get-GoStringField $body 'Action'
            Title = Get-GoStringField $body 'Title'
        }
    }

    return [pscustomobject]@{
        Permissions = $permissions
        Operations = $operations
    }
}

function Get-RouteInventory {
    param(
        [hashtable]$Permissions,
        [hashtable]$Operations
    )

    $routeFiles = @(Get-ChildItem -LiteralPath 'admin_back_go/internal/module' -Recurse -File -Include 'route.go','routes.go','*_route.go' | Sort-Object FullName)
    foreach ($file in $routeFiles) {
        $lines = @(Get-Content -LiteralPath $file.FullName)
        $constants = Get-StringConstants $lines
        $groups = @{ router = '' }
        $location = Get-CapabilitySurface $file.FullName
        $relativeFile = RelPath -Base '.' -Path $file.FullName

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $line = $lines[$index]
            $lineNumber = $index + 1

            if ($line -match '^\s*(?<var>[A-Za-z_]\w*)\s*:=\s*(?<base>[A-Za-z_]\w*)\.Group\(\s*(?<expr>[^)]*)\s*\)') {
                $receiver = $Matches.base
                $expr = Resolve-RouteExpression $Matches.expr $constants
                if ($groups.ContainsKey($receiver) -and $null -ne $expr.Value) {
                    $groups[$Matches.var] = Join-RoutePath $groups[$receiver] $expr.Value
                }
                continue
            }

            $routeMatch = [regex]::Match($line, '(?<receiver>[A-Za-z_]\w*)\.(?<method>GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD|Any)\(\s*(?<expr>[^,]+)\s*,')
            if (-not $routeMatch.Success) { continue }

            $receiver = $routeMatch.Groups['receiver'].Value
            $method = Convert-HttpMethodName $routeMatch.Groups['method'].Value
            $expr = Resolve-RouteExpression $routeMatch.Groups['expr'].Value $constants
            $groupPrefix = if ($groups.ContainsKey($receiver)) { $groups[$receiver] } else { $null }
            $fullPath = if ($null -ne $groupPrefix -and $null -ne $expr.Value) { Join-RoutePath $groupPrefix $expr.Value } else { $null }
            $pathKind = 'unresolved'

            if ($null -ne $expr.Value) {
                if ($receiver -eq 'router') {
                    if ($expr.Kind -like 'const*' -and $expr.Value.StartsWith('/api/')) {
                        $pathKind = 'const-full'
                    } elseif ($expr.Value.StartsWith('/api/')) {
                        $pathKind = 'full-literal'
                    } else {
                        $pathKind = 'root-full'
                    }
                } elseif ($null -ne $groupPrefix) {
                    $pathKind = 'group-fragment'
                } else {
                    $pathKind = 'unresolved-group'
                }
            }

            $metadataKey = if ($fullPath) { "$method $fullPath" } else { $null }
            $permissionCode = if ($metadataKey -and $Permissions.ContainsKey($metadataKey)) { $Permissions[$metadataKey] } else { '' }
            $operation = if ($metadataKey -and $Operations.ContainsKey($metadataKey)) { $Operations[$metadataKey] } else { $null }
            $operationText = ''
            if ($null -ne $operation) {
                $operationText = "$($operation.Module).$($operation.Action)"
                if (-not [string]::IsNullOrWhiteSpace($operation.Title)) {
                    $operationText += " / $($operation.Title)"
                }
            }
            $isCallbackException = ($location.Surface -eq 'callback') -or ($fullPath -like '/api/payment/callbacks*')

            [pscustomobject]@{
                Capability = $location.Capability
                Surface = $location.Surface
                File = $relativeFile
                Line = $lineNumber
                Method = $method
                Receiver = $receiver
                GroupPrefix = $groupPrefix
                RouteArgument = $expr.Raw
                RouteArgumentPath = $expr.Value
                InferredFullPath = $fullPath
                PathKind = $pathKind
                CallbackException = if ($isCallbackException) { 'yes' } else { '' }
                PermissionCode = $permissionCode
                Operation = $operationText
                MetadataKey = $metadataKey
            }
        }
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $metadata = Get-RouteMetadata
    $routes = @(Get-RouteInventory -Permissions $metadata.Permissions -Operations $metadata.Operations)
    $routeKeys = @{}
    foreach ($route in $routes) {
        if (-not [string]::IsNullOrWhiteSpace($route.MetadataKey)) {
            $routeKeys[$route.MetadataKey] = $true
        }
    }
    $unmatchedPermissionKeys = @($metadata.Permissions.Keys | Where-Object { -not $routeKeys.ContainsKey($_) } | Sort-Object)
    $unmatchedOperationKeys = @($metadata.Operations.Keys | Where-Object { -not $routeKeys.ContainsKey($_) } | Sort-Object)

    $sourceFiles = @($routes | Select-Object -ExpandProperty File -Unique)
    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Backend Route Inventory Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines 'This artifact is generated from current Go route source files and `admin_back_go/internal/bootstrap/route_meta.go`. It is a source inventory for navigation and contract drift checks, not proof that every route is currently served by a running process. Runtime behavior, smoke output, and captured traffic still outrank this file.'
    Add-Line $lines ''
    Add-Line $lines 'Path inference rule: only literal strings, same-file string constants, and simple `const + "suffix"` expressions are resolved. Unresolved expressions stay unresolved; the exporter must not invent fallback paths.'
    Add-Line $lines ''
    Add-Line $lines '## Summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Value |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Route source files with registrations | ``$($sourceFiles.Count)`` |"
    Add-Line $lines "| Route registrations found | ``$($routes.Count)`` |"
    Add-Line $lines "| Inferred full paths | ``$(@($routes | Where-Object { -not [string]::IsNullOrWhiteSpace($_.InferredFullPath) }).Count)`` |"
    Add-Line $lines "| Unresolved registrations | ``$(@($routes | Where-Object { [string]::IsNullOrWhiteSpace($_.InferredFullPath) }).Count)`` |"
    Add-Line $lines "| Callback exception registrations | ``$(@($routes | Where-Object { $_.CallbackException -eq 'yes' }).Count)`` |"
    Add-Line $lines "| Permission route_meta matches | ``$(@($routes | Where-Object { -not [string]::IsNullOrWhiteSpace($_.PermissionCode) }).Count)`` |"
    Add-Line $lines "| Operation route_meta matches | ``$(@($routes | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Operation) }).Count)`` |"
    Add-Line $lines "| Unmatched permission route_meta keys | ``$($unmatchedPermissionKeys.Count)`` |"
    Add-Line $lines "| Unmatched operation route_meta keys | ``$($unmatchedOperationKeys.Count)`` |"
    Add-Line $lines ''
    Add-Line $lines '## Surface summary'
    Add-Line $lines ''
    Add-Line $lines '`callback` is an external HTTP callback surface exception, not a business platform.'
    Add-Line $lines ''
    Add-Line $lines '| Surface | Route registrations |'
    Add-Line $lines '| --- | --- |'
    foreach ($surfaceGroup in @($routes | Group-Object Surface | Sort-Object Name)) {
        Add-Line $lines "| ``$($surfaceGroup.Name)`` | ``$($surfaceGroup.Count)`` |"
    }
    Add-Line $lines ''
    Add-Line $lines '## Route inventory'
    Add-Line $lines ''
    Add-Line $lines '| Capability | Surface | Route file | Line | Method | Group prefix | Route argument | Route argument path | Inferred full path | Path kind | Callback exception | Permission code | Operation metadata |'
    Add-Line $lines '| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    foreach ($route in @($routes | Sort-Object Capability, Surface, File, Line)) {
        Add-Line $lines "| $(Code-Cell $route.Capability) | $(Code-Cell $route.Surface) | $(Code-Cell $route.File) | ``$($route.Line)`` | ``$($route.Method)`` | $(Code-Cell $route.GroupPrefix) | $(Code-Cell $route.RouteArgument) | $(Code-Cell $route.RouteArgumentPath) | $(Code-Cell $route.InferredFullPath) | ``$($route.PathKind)`` | $(Code-Cell $route.CallbackException) | $(Code-Cell $route.PermissionCode) | $(Code-Cell $route.Operation) |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Route metadata keys not matched to source inventory'
    Add-Line $lines ''
    Add-Line $lines 'These entries are generated as drift evidence only. They do not prove a route is dead; they mean this static extractor did not match the key to a current route registration.'
    Add-Line $lines ''
    Add-Line $lines '| Type | Method path | Metadata |'
    Add-Line $lines '| --- | --- | --- |'
    foreach ($key in $unmatchedPermissionKeys) {
        Add-Line $lines "| ``permission`` | $(Code-Cell $key) | $(Code-Cell $metadata.Permissions[$key]) |"
    }
    foreach ($key in $unmatchedOperationKeys) {
        $operation = $metadata.Operations[$key]
        $metadataText = "$($operation.Module).$($operation.Action)"
        if (-not [string]::IsNullOrWhiteSpace($operation.Title)) {
            $metadataText += " / $($operation.Title)"
        }
        Add-Line $lines "| ``operation`` | $(Code-Cell $key) | $(Code-Cell $metadataText) |"
    }
    if ($unmatchedPermissionKeys.Count -eq 0 -and $unmatchedOperationKeys.Count -eq 0) {
        Add-Line $lines '|  |  |  |'
    }

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "backend-route-inventory-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
    Write-Host "routes=$($routes.Count)"
    Write-Host "unresolved=$(@($routes | Where-Object { [string]::IsNullOrWhiteSpace($_.InferredFullPath) }).Count)"
    Write-Host "unmatched_permission_meta=$($unmatchedPermissionKeys.Count)"
    Write-Host "unmatched_operation_meta=$($unmatchedOperationKeys.Count)"
}
finally {
    Pop-Location
}
