param(
    [switch]$LiveSchema
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Name)
    Write-Host ''
    Write-Host $Name
    Write-Host ('-' * $Name.Length)
}

function Add-Failure {
    param(
        [System.Collections.ArrayList]$Failures,
        [string]$Message
    )
    [void]$Failures.Add($Message)
}

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "required file missing: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path
}

function Assert-Contains {
    param(
        [System.Collections.ArrayList]$Failures,
        [string]$Path,
        [string]$Needle,
        [string]$Reason
    )
    $text = Read-Text $Path
    if (-not $text.Contains($Needle)) {
        Add-Failure $Failures "$Reason`: $Path does not contain [$Needle]"
    }
}

function Assert-NotContains {
    param(
        [System.Collections.ArrayList]$Failures,
        [string]$Path,
        [string]$Needle,
        [string]$Reason
    )
    $text = Read-Text $Path
    if ($text.Contains($Needle)) {
        Add-Failure $Failures "$Reason`: $Path still contains [$Needle]"
    }
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

function Get-GoVersion {
    param([string]$Path)
    $match = Select-String -LiteralPath $Path -Pattern '^go\s+(.+)$' | Select-Object -First 1
    if ($null -eq $match) { throw "go version line missing: $Path" }
    return $match.Matches[0].Groups[1].Value.Trim()
}

function Get-SchemaBaseTableCount {
    param([string]$Path)
    $text = Read-Text $Path
    $match = [regex]::Match($text, '\|\s*Base tables\s*\|\s*(\d+)\s*\|')
    if (-not $match.Success) { throw "Base tables row missing: $Path" }
    return [int]$match.Groups[1].Value
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
            SqlPath = $sqlPath -replace '\\','/'
        }
    }
    if ($items.Count -eq 0) {
        throw 'no tracked MySQL live schema artifact found under docs/db'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestRuntimeInventoryArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'runtime-inventory-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^runtime-inventory-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated runtime inventory artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
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
    if ($items.Count -eq 0) {
        throw 'no generated backend route inventory artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestBackendRouteContractDriftArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'backend-route-contract-drift-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^backend-route-contract-drift-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated backend route contract drift artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestFrontendApiInventoryArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'frontend-api-inventory-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^frontend-api-inventory-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated frontend API inventory artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
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

function Get-LatestApiSourceOnlyRouteReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'api-source-only-route-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^api-source-only-route-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated API source-only route review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestDbSchemaOwnershipMapArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'db-schema-ownership-map-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^db-schema-ownership-map-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated DB schema ownership map artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestFullStackModuleMapArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'full-stack-module-map-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^full-stack-module-map-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated full-stack module map artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestBackendCapabilityManifestArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'backend-capability-manifest-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^backend-capability-manifest-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated backend capability manifest artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontSourceQualityInventoryArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-source-quality-inventory-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-source-quality-inventory-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front source quality inventory artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestCanvasAIRequestContractReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'canvas-ai-request-contract-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^canvas-ai-request-contract-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Canvas AI request contract review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestCanvasRBACPermissionContractReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'canvas-rbac-permission-contract-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^canvas-rbac-permission-contract-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Canvas RBAC permission contract review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestCanvasAssetRouteContractReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'canvas-asset-route-contract-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^canvas-asset-route-contract-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Canvas asset route contract review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestCanvasAuthLogoutContractReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'canvas-auth-logout-contract-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^canvas-auth-logout-contract-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Canvas auth logout contract review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminUserStatusContractReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-user-status-contract-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-user-status-contract-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin user status contract review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminAIAgentTestContractReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-ai-agent-test-contract-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-ai-agent-test-contract-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin AI agent test contract review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontDirectExternalHelperReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-direct-external-helper-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-direct-external-helper-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front direct external helper review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontHeaderBreadcrumbReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-header-breadcrumb-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-header-breadcrumb-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front Header breadcrumb source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontForgotPasswordErrorReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-forgot-password-error-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-forgot-password-error-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front forgot-password error source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontJsonEditorReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-json-editor-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-json-editor-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front JsonEditor source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontDIconReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-dicon-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-dicon-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front DIcon source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontEditorReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-editor-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-editor-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front Editor source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontDownloadManagerReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-download-manager-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-download-manager-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front DownloadManager source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontDevTestDownloadReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-dev-test-download-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-dev-test-download-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front dev test download source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontValidatorReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-validator-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-validator-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front validator source-quality review artifact found under docs/knowledge'
    }
    return ($items | Sort-Object Date -Descending | Select-Object -First 1)
}

function Get-LatestAdminFrontUploadDemoReviewArtifact {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath 'docs/knowledge' -Filter 'admin-front-upload-demo-source-quality-review-*.md' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -notmatch '^admin-front-upload-demo-source-quality-review-(\d{4}-\d{2}-\d{2})\.md$') { continue }
        $items += [pscustomobject]@{
            Date = $Matches[1]
            Path = "docs/knowledge/$($file.Name)"
        }
    }
    if ($items.Count -eq 0) {
        throw 'no generated Admin front upload demo source-quality review artifact found under docs/knowledge'
    }
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

function Get-BackendRouteRegistrationCount {
    $routeFiles = @(
        Get-ChildItem -LiteralPath 'admin_back_go/internal/module' -Recurse -File |
            Where-Object { $_.Name -eq 'route.go' -or $_.Name -eq 'routes.go' -or $_.Name -like '*_route.go' } |
            Sort-Object FullName
    )
    $count = 0
    foreach ($file in $routeFiles) {
        $count += @(Select-String -LiteralPath $file.FullName -Pattern '\.(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD|Any)\(').Count
    }
    return $count
}

function Get-RelativeUnixPath {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )
    $baseResolved = (Resolve-Path -LiteralPath $BasePath).ProviderPath
    $childResolved = (Resolve-Path -LiteralPath $ChildPath).ProviderPath
    $getRelativePath = [System.IO.Path].GetMethods() |
        Where-Object { $_.Name -eq 'GetRelativePath' -and $_.GetParameters().Count -eq 2 } |
        Select-Object -First 1
    if ($null -ne $getRelativePath) {
        return ([string]$getRelativePath.Invoke($null, @($baseResolved, $childResolved)) -replace '\\','/')
    }

    $baseFull = [System.IO.Path]::GetFullPath($baseResolved).TrimEnd('\', '/')
    $childFull = [System.IO.Path]::GetFullPath($childResolved).TrimEnd('\', '/')
    $baseRoot = [System.IO.Path]::GetPathRoot($baseFull)
    $childRoot = [System.IO.Path]::GetPathRoot($childFull)
    if (-not [string]::Equals($baseRoot, $childRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($childFull -replace '\\','/')
    }

    $baseParts = @($baseFull.Substring($baseRoot.Length).Trim('\', '/') -split '[\\/]' | Where-Object { $_ -ne '' })
    $childParts = @($childFull.Substring($childRoot.Length).Trim('\', '/') -split '[\\/]' | Where-Object { $_ -ne '' })
    $commonLength = 0
    while (
        $commonLength -lt $baseParts.Count -and
        $commonLength -lt $childParts.Count -and
        [string]::Equals($baseParts[$commonLength], $childParts[$commonLength], [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        $commonLength++
    }

    $relativeParts = @()
    for ($i = $commonLength; $i -lt $baseParts.Count; $i++) { $relativeParts += '..' }
    for ($i = $commonLength; $i -lt $childParts.Count; $i++) { $relativeParts += $childParts[$i] }
    if ($relativeParts.Count -eq 0) { return '.' }
    return ($relativeParts -join '/')
}

function Read-DotEnvValue {
    param(
        [string]$Path,
        [string]$Key
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "env file not found: $Path"
    }
    $line = Get-Content -LiteralPath $Path |
        Where-Object { $_ -match "^\s*$([regex]::Escape($Key))=" } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "env key not found in ${Path}: $Key"
    }
    return ($line -replace "^\s*$([regex]::Escape($Key))=", "").Trim()
}

function Parse-MySQLDsn {
    param([string]$Dsn)
    $match = [regex]::Match($Dsn, "^(?<user>[^:]+):(?<password>[^@]*)@tcp\((?<host>[^:()]+):(?<port>\d+)\)/(?<database>[^?]+)")
    if (-not $match.Success) {
        throw "unsupported MYSQL_DSN format; expected user:password@tcp(host:port)/database"
    }
    return [pscustomobject]@{
        User = $match.Groups["user"].Value
        Password = $match.Groups["password"].Value
        Host = $match.Groups["host"].Value
        Port = $match.Groups["port"].Value
        Database = $match.Groups["database"].Value
    }
}

function Invoke-LiveMySQLQuery {
    param(
        [object]$Config,
        [string]$Sql
    )
    $args = @(
        "-h", $Config.Host,
        "-P", $Config.Port,
        "-u", $Config.User,
        "--default-character-set=utf8mb4",
        "--batch",
        "--raw",
        "--skip-column-names",
        $Config.Database,
        "-e", $Sql
    )
    $previousPassword = $env:MYSQL_PWD
    $env:MYSQL_PWD = $Config.Password
    try {
        $result = & mysql @args
        if ($LASTEXITCODE -ne 0) {
            throw "mysql query failed: $Sql"
        }
        return $result
    }
    finally {
        $env:MYSQL_PWD = $previousPassword
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot

try {
    $failures = New-Object System.Collections.ArrayList
    $evidence = New-Object System.Collections.ArrayList
    $verification = New-Object System.Collections.ArrayList

    $knowledgePath = 'docs/knowledge/current-runtime-knowledge.md'
    $sourceMapPath = 'docs/knowledge/runtime-source-map.md'
    $statusPath = 'docs/status/current-status.md'
    $qualityRunwayPath = 'docs/architecture/09-codex-first-quality-runway.md'
    $agentFrameworkPath = 'docs/architecture/02-agent-framework.md'
    $agentsApiContractPath = 'agents/api-contract.md'
    $schemaArtifact = Get-LatestSchemaArtifact
    $schemaMdPath = $schemaArtifact.MdPath
    $schemaSqlPath = $schemaArtifact.SqlPath
    $schemaDate = $schemaArtifact.Date
    $inventoryArtifact = Get-LatestRuntimeInventoryArtifact
    $inventoryPath = $inventoryArtifact.Path
    $inventoryDate = $inventoryArtifact.Date
    $backendRouteArtifact = Get-LatestBackendRouteInventoryArtifact
    $backendRouteInventoryPath = $backendRouteArtifact.Path
    $backendRouteInventoryDate = $backendRouteArtifact.Date
    $backendRouteContractDriftArtifact = Get-LatestBackendRouteContractDriftArtifact
    $backendRouteContractDriftPath = $backendRouteContractDriftArtifact.Path
    $backendRouteContractDriftDate = $backendRouteContractDriftArtifact.Date
    $frontendApiArtifact = Get-LatestFrontendApiInventoryArtifact
    $frontendApiInventoryPath = $frontendApiArtifact.Path
    $frontendApiInventoryDate = $frontendApiArtifact.Date
    $frontendBackendApiDriftArtifact = Get-LatestFrontendBackendApiDriftArtifact
    $frontendBackendApiDriftPath = $frontendBackendApiDriftArtifact.Path
    $frontendBackendApiDriftDate = $frontendBackendApiDriftArtifact.Date
    $apiSourceOnlyReviewArtifact = Get-LatestApiSourceOnlyRouteReviewArtifact
    $apiSourceOnlyReviewPath = $apiSourceOnlyReviewArtifact.Path
    $apiSourceOnlyReviewDate = $apiSourceOnlyReviewArtifact.Date
    $dbSchemaOwnershipArtifact = Get-LatestDbSchemaOwnershipMapArtifact
    $dbSchemaOwnershipMapPath = $dbSchemaOwnershipArtifact.Path
    $dbSchemaOwnershipMapDate = $dbSchemaOwnershipArtifact.Date
    $fullStackModuleMapArtifact = Get-LatestFullStackModuleMapArtifact
    $fullStackModuleMapPath = $fullStackModuleMapArtifact.Path
    $fullStackModuleMapDate = $fullStackModuleMapArtifact.Date
    $backendCapabilityManifestArtifact = Get-LatestBackendCapabilityManifestArtifact
    $backendCapabilityManifestPath = $backendCapabilityManifestArtifact.Path
    $backendCapabilityManifestDate = $backendCapabilityManifestArtifact.Date
    $adminFrontSourceQualityArtifact = Get-LatestAdminFrontSourceQualityInventoryArtifact
    $adminFrontSourceQualityPath = $adminFrontSourceQualityArtifact.Path
    $adminFrontSourceQualityDate = $adminFrontSourceQualityArtifact.Date
    $canvasAIRequestContractReviewArtifact = Get-LatestCanvasAIRequestContractReviewArtifact
    $canvasAIRequestContractReviewPath = $canvasAIRequestContractReviewArtifact.Path
    $canvasAIRequestContractReviewDate = $canvasAIRequestContractReviewArtifact.Date
    $canvasRBACPermissionContractReviewArtifact = Get-LatestCanvasRBACPermissionContractReviewArtifact
    $canvasRBACPermissionContractReviewPath = $canvasRBACPermissionContractReviewArtifact.Path
    $canvasRBACPermissionContractReviewDate = $canvasRBACPermissionContractReviewArtifact.Date
    $canvasAssetRouteContractReviewArtifact = Get-LatestCanvasAssetRouteContractReviewArtifact
    $canvasAssetRouteContractReviewPath = $canvasAssetRouteContractReviewArtifact.Path
    $canvasAssetRouteContractReviewDate = $canvasAssetRouteContractReviewArtifact.Date
    $canvasAuthLogoutContractReviewArtifact = Get-LatestCanvasAuthLogoutContractReviewArtifact
    $canvasAuthLogoutContractReviewPath = $canvasAuthLogoutContractReviewArtifact.Path
    $canvasAuthLogoutContractReviewDate = $canvasAuthLogoutContractReviewArtifact.Date
    $adminUserStatusContractReviewArtifact = Get-LatestAdminUserStatusContractReviewArtifact
    $adminUserStatusContractReviewPath = $adminUserStatusContractReviewArtifact.Path
    $adminUserStatusContractReviewDate = $adminUserStatusContractReviewArtifact.Date
    $adminAIAgentTestContractReviewArtifact = Get-LatestAdminAIAgentTestContractReviewArtifact
    $adminAIAgentTestContractReviewPath = $adminAIAgentTestContractReviewArtifact.Path
    $adminAIAgentTestContractReviewDate = $adminAIAgentTestContractReviewArtifact.Date
    $adminFrontDirectExternalHelperReviewArtifact = Get-LatestAdminFrontDirectExternalHelperReviewArtifact
    $adminFrontDirectExternalHelperReviewPath = $adminFrontDirectExternalHelperReviewArtifact.Path
    $adminFrontDirectExternalHelperReviewDate = $adminFrontDirectExternalHelperReviewArtifact.Date
    $adminFrontHeaderBreadcrumbReviewArtifact = Get-LatestAdminFrontHeaderBreadcrumbReviewArtifact
    $adminFrontHeaderBreadcrumbReviewPath = $adminFrontHeaderBreadcrumbReviewArtifact.Path
    $adminFrontHeaderBreadcrumbReviewDate = $adminFrontHeaderBreadcrumbReviewArtifact.Date
    $adminFrontForgotPasswordErrorReviewArtifact = Get-LatestAdminFrontForgotPasswordErrorReviewArtifact
    $adminFrontForgotPasswordErrorReviewPath = $adminFrontForgotPasswordErrorReviewArtifact.Path
    $adminFrontForgotPasswordErrorReviewDate = $adminFrontForgotPasswordErrorReviewArtifact.Date
    $adminFrontJsonEditorReviewArtifact = Get-LatestAdminFrontJsonEditorReviewArtifact
    $adminFrontJsonEditorReviewPath = $adminFrontJsonEditorReviewArtifact.Path
    $adminFrontJsonEditorReviewDate = $adminFrontJsonEditorReviewArtifact.Date
    $adminFrontDIconReviewArtifact = Get-LatestAdminFrontDIconReviewArtifact
    $adminFrontDIconReviewPath = $adminFrontDIconReviewArtifact.Path
    $adminFrontDIconReviewDate = $adminFrontDIconReviewArtifact.Date
    $adminFrontEditorReviewArtifact = Get-LatestAdminFrontEditorReviewArtifact
    $adminFrontEditorReviewPath = $adminFrontEditorReviewArtifact.Path
    $adminFrontEditorReviewDate = $adminFrontEditorReviewArtifact.Date
    $adminFrontDownloadManagerReviewArtifact = Get-LatestAdminFrontDownloadManagerReviewArtifact
    $adminFrontDownloadManagerReviewPath = $adminFrontDownloadManagerReviewArtifact.Path
    $adminFrontDownloadManagerReviewDate = $adminFrontDownloadManagerReviewArtifact.Date
    $adminFrontDevTestDownloadReviewArtifact = Get-LatestAdminFrontDevTestDownloadReviewArtifact
    $adminFrontDevTestDownloadReviewPath = $adminFrontDevTestDownloadReviewArtifact.Path
    $adminFrontDevTestDownloadReviewDate = $adminFrontDevTestDownloadReviewArtifact.Date
    $adminFrontValidatorReviewArtifact = Get-LatestAdminFrontValidatorReviewArtifact
    $adminFrontValidatorReviewPath = $adminFrontValidatorReviewArtifact.Path
    $adminFrontValidatorReviewDate = $adminFrontValidatorReviewArtifact.Date
    $adminFrontUploadDemoReviewArtifact = Get-LatestAdminFrontUploadDemoReviewArtifact
    $adminFrontUploadDemoReviewPath = $adminFrontUploadDemoReviewArtifact.Path
    $adminFrontUploadDemoReviewDate = $adminFrontUploadDemoReviewArtifact.Date

    foreach ($path in @(
        'AGENTS.md',
        'docs/README.md',
        $knowledgePath,
        $sourceMapPath,
        $qualityRunwayPath,
        'docs/knowledge/README.md',
        'docs/knowledge/codex-first-agent-operating-model.md',
        $statusPath,
        $agentFrameworkPath,
        $agentsApiContractPath,
        'admin_back_go/go.mod',
        'admin_front_ts/package.json',
        'admin_front_ts/tests/layout/search-dialog-source-quality.test.ts',
        'admin_front_ts/tests/shared/user/forgot-password-source-quality.test.ts',
        'admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts',
        'admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts',
        'admin_front_ts/tests/shared/editor/editor-source-quality.test.ts',
        'admin_front_ts/tests/shared/download-manager/download-manager-source-quality.test.ts',
        'admin_front_ts/tests/shared/download-manager/download-demo-source-quality.test.ts',
        'admin_front_ts/tests/shared/download-manager/dev-test-download-source-quality.test.ts',
        'admin_front_ts/tests/shared/validator/use-validator-source-quality.test.ts',
        'admin_front_ts/tests/shared/upload/upload-demo-source-quality.test.ts',
        'admin_front_ts/src/components/JsonEditor/src/json.ts',
        'admin_front_ts/src/components/DownloadManager/src/errors.ts',
        'admin_front_ts/src/views/Main/component/display/components/Editor.vue',
        'admin_front_ts/src/views/Main/component/upload/components/media.ts',
        'canvas_front_next/package.json',
        $schemaMdPath,
        $schemaSqlPath,
        $inventoryPath,
        $backendRouteInventoryPath,
        $backendRouteContractDriftPath,
        $frontendApiInventoryPath,
        $frontendBackendApiDriftPath,
        $apiSourceOnlyReviewPath,
        $dbSchemaOwnershipMapPath,
        $fullStackModuleMapPath,
        $backendCapabilityManifestPath,
        $adminFrontSourceQualityPath,
        $canvasAIRequestContractReviewPath,
        $canvasRBACPermissionContractReviewPath,
        $canvasAssetRouteContractReviewPath,
        $canvasAuthLogoutContractReviewPath,
        $adminUserStatusContractReviewPath,
        $adminAIAgentTestContractReviewPath,
        $adminFrontDirectExternalHelperReviewPath,
        $adminFrontHeaderBreadcrumbReviewPath,
        $adminFrontForgotPasswordErrorReviewPath,
        $adminFrontJsonEditorReviewPath,
        $adminFrontDIconReviewPath,
        $adminFrontEditorReviewPath,
        $adminFrontDownloadManagerReviewPath,
        $adminFrontDevTestDownloadReviewPath,
        $adminFrontValidatorReviewPath,
        $adminFrontUploadDemoReviewPath,
        'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md'
    )) {
        if (-not (Test-Path -LiteralPath $path)) {
            Add-Failure $failures "required runtime/doc fact file missing: $path"
        }
    }

    if ($failures.Count -eq 0) {
        $goVersion = Get-GoVersion 'admin_back_go/go.mod'
        Assert-Contains $failures $knowledgePath "Go $goVersion" 'knowledge backend Go version drift'
        Assert-Contains $failures $knowledgePath "| ``admin_back_go`` | Go | ``$goVersion`` |" 'knowledge backend exact Go version table drift'
        [void]$evidence.Add("go=$goVersion")
        [void]$evidence.Add("latest_schema_date=$schemaDate")
        [void]$evidence.Add("latest_runtime_inventory_date=$inventoryDate")
        [void]$evidence.Add("latest_backend_route_inventory_date=$backendRouteInventoryDate")
        [void]$evidence.Add("latest_backend_route_contract_drift_date=$backendRouteContractDriftDate")
        [void]$evidence.Add("latest_frontend_api_inventory_date=$frontendApiInventoryDate")
        [void]$evidence.Add("latest_frontend_backend_api_drift_date=$frontendBackendApiDriftDate")
        [void]$evidence.Add("latest_api_source_only_route_review_date=$apiSourceOnlyReviewDate")
        [void]$evidence.Add("latest_db_schema_ownership_map_date=$dbSchemaOwnershipMapDate")
        [void]$evidence.Add("latest_full_stack_module_map_date=$fullStackModuleMapDate")
        [void]$evidence.Add("latest_backend_capability_manifest_date=$backendCapabilityManifestDate")
        [void]$evidence.Add("latest_admin_front_source_quality_inventory_date=$adminFrontSourceQualityDate")
        [void]$evidence.Add("latest_canvas_ai_request_contract_review_date=$canvasAIRequestContractReviewDate")
        [void]$evidence.Add("latest_canvas_rbac_permission_contract_review_date=$canvasRBACPermissionContractReviewDate")
        [void]$evidence.Add("latest_canvas_asset_route_contract_review_date=$canvasAssetRouteContractReviewDate")
        [void]$evidence.Add("latest_canvas_auth_logout_contract_review_date=$canvasAuthLogoutContractReviewDate")
        [void]$evidence.Add("latest_admin_user_status_contract_review_date=$adminUserStatusContractReviewDate")
        [void]$evidence.Add("latest_admin_ai_agent_test_contract_review_date=$adminAIAgentTestContractReviewDate")
        [void]$evidence.Add("latest_admin_front_direct_external_helper_review_date=$adminFrontDirectExternalHelperReviewDate")
        [void]$evidence.Add("latest_admin_front_header_breadcrumb_review_date=$adminFrontHeaderBreadcrumbReviewDate")
        [void]$evidence.Add("latest_admin_front_forgot_password_error_review_date=$adminFrontForgotPasswordErrorReviewDate")
        [void]$evidence.Add("latest_admin_front_json_editor_review_date=$adminFrontJsonEditorReviewDate")
        [void]$evidence.Add("latest_admin_front_dicon_review_date=$adminFrontDIconReviewDate")
        [void]$evidence.Add("latest_admin_front_editor_review_date=$adminFrontEditorReviewDate")
        [void]$evidence.Add("latest_admin_front_download_manager_review_date=$adminFrontDownloadManagerReviewDate")
        [void]$evidence.Add("latest_admin_front_dev_test_download_review_date=$adminFrontDevTestDownloadReviewDate")
        [void]$evidence.Add("latest_admin_front_validator_review_date=$adminFrontValidatorReviewDate")
        [void]$evidence.Add("latest_admin_front_upload_demo_review_date=$adminFrontUploadDemoReviewDate")
        if ($inventoryDate -lt $schemaDate) {
            Add-Failure $failures "latest runtime inventory date $inventoryDate is older than latest schema date $schemaDate"
        }
        if ($backendRouteInventoryDate -lt $inventoryDate) {
            Add-Failure $failures "latest backend route inventory date $backendRouteInventoryDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($backendRouteContractDriftDate -lt $backendRouteInventoryDate) {
            Add-Failure $failures "latest backend route contract drift date $backendRouteContractDriftDate is older than latest backend route inventory date $backendRouteInventoryDate"
        }
        if ($frontendApiInventoryDate -lt $inventoryDate) {
            Add-Failure $failures "latest frontend API inventory date $frontendApiInventoryDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($frontendBackendApiDriftDate -lt $frontendApiInventoryDate) {
            Add-Failure $failures "latest frontend/backend API drift date $frontendBackendApiDriftDate is older than latest frontend API inventory date $frontendApiInventoryDate"
        }
        if ($frontendBackendApiDriftDate -lt $backendRouteInventoryDate) {
            Add-Failure $failures "latest frontend/backend API drift date $frontendBackendApiDriftDate is older than latest backend route inventory date $backendRouteInventoryDate"
        }
        if ($apiSourceOnlyReviewDate -lt $frontendBackendApiDriftDate) {
            Add-Failure $failures "latest API source-only route review date $apiSourceOnlyReviewDate is older than latest frontend/backend API drift date $frontendBackendApiDriftDate"
        }
        if ($dbSchemaOwnershipMapDate -lt $schemaDate) {
            Add-Failure $failures "latest DB schema ownership map date $dbSchemaOwnershipMapDate is older than latest schema date $schemaDate"
        }
        if ($fullStackModuleMapDate -lt $dbSchemaOwnershipMapDate) {
            Add-Failure $failures "latest full-stack module map date $fullStackModuleMapDate is older than latest DB schema ownership map date $dbSchemaOwnershipMapDate"
        }
        if ($fullStackModuleMapDate -lt $backendRouteInventoryDate) {
            Add-Failure $failures "latest full-stack module map date $fullStackModuleMapDate is older than latest backend route inventory date $backendRouteInventoryDate"
        }
        if ($fullStackModuleMapDate -lt $frontendApiInventoryDate) {
            Add-Failure $failures "latest full-stack module map date $fullStackModuleMapDate is older than latest frontend API inventory date $frontendApiInventoryDate"
        }
        if ($fullStackModuleMapDate -lt $apiSourceOnlyReviewDate) {
            Add-Failure $failures "latest full-stack module map date $fullStackModuleMapDate is older than latest API source-only review date $apiSourceOnlyReviewDate"
        }
        if ($backendCapabilityManifestDate -lt $backendRouteInventoryDate) {
            Add-Failure $failures "latest backend capability manifest date $backendCapabilityManifestDate is older than latest backend route inventory date $backendRouteInventoryDate"
        }
        if ($backendCapabilityManifestDate -lt $dbSchemaOwnershipMapDate) {
            Add-Failure $failures "latest backend capability manifest date $backendCapabilityManifestDate is older than latest DB schema ownership map date $dbSchemaOwnershipMapDate"
        }
        if ($adminFrontSourceQualityDate -lt $inventoryDate) {
            Add-Failure $failures "latest Admin front source quality inventory date $adminFrontSourceQualityDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($canvasAIRequestContractReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Canvas AI request contract review date $canvasAIRequestContractReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($canvasRBACPermissionContractReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Canvas RBAC permission contract review date $canvasRBACPermissionContractReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($canvasAssetRouteContractReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Canvas asset route contract review date $canvasAssetRouteContractReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($canvasAuthLogoutContractReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Canvas auth logout contract review date $canvasAuthLogoutContractReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($adminUserStatusContractReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Admin user status contract review date $adminUserStatusContractReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($adminAIAgentTestContractReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Admin AI agent test contract review date $adminAIAgentTestContractReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($adminFrontDirectExternalHelperReviewDate -lt $frontendApiInventoryDate) {
            Add-Failure $failures "latest Admin front direct external helper review date $adminFrontDirectExternalHelperReviewDate is older than latest frontend API inventory date $frontendApiInventoryDate"
        }
        if ($adminFrontHeaderBreadcrumbReviewDate -lt $inventoryDate) {
            Add-Failure $failures "latest Admin front Header breadcrumb review date $adminFrontHeaderBreadcrumbReviewDate is older than latest runtime inventory date $inventoryDate"
        }
        if ($adminFrontForgotPasswordErrorReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front forgot-password error review date $adminFrontForgotPasswordErrorReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontJsonEditorReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front JsonEditor review date $adminFrontJsonEditorReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontDIconReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front DIcon review date $adminFrontDIconReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontEditorReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front Editor review date $adminFrontEditorReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontDownloadManagerReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front DownloadManager review date $adminFrontDownloadManagerReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontDevTestDownloadReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front dev test download review date $adminFrontDevTestDownloadReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontValidatorReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front validator review date $adminFrontValidatorReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }
        if ($adminFrontUploadDemoReviewDate -lt $adminFrontSourceQualityDate) {
            Add-Failure $failures "latest Admin front upload demo review date $adminFrontUploadDemoReviewDate is older than latest Admin front source quality inventory date $adminFrontSourceQualityDate"
        }

        $adminPkg = Read-PackageJson 'admin_front_ts/package.json'
        foreach ($dep in @('vue', 'vite', 'typescript', 'element-plus', 'pinia', 'vue-i18n', 'axios')) {
            $version = Get-PackageVersion $adminPkg $dep
            if ([string]::IsNullOrWhiteSpace($version)) {
                Add-Failure $failures "admin_front_ts/package.json dependency missing: $dep"
            } else {
                Assert-Contains $failures $knowledgePath "``$version``" "knowledge admin_front_ts dependency drift: $dep"
                [void]$evidence.Add("admin_front_ts:$dep=$version")
            }
        }

        $canvasPkg = Read-PackageJson 'canvas_front_next/package.json'
        foreach ($dep in @('next', 'react', 'typescript', 'antd', 'zustand', '@tanstack/react-query', 'axios')) {
            $version = Get-PackageVersion $canvasPkg $dep
            if ([string]::IsNullOrWhiteSpace($version)) {
                Add-Failure $failures "canvas_front_next/package.json dependency missing: $dep"
            } else {
                Assert-Contains $failures $knowledgePath "``$version``" "knowledge canvas_front_next dependency drift: $dep"
                [void]$evidence.Add("canvas_front_next:$dep=$version")
            }
        }

        Assert-Contains $failures 'AGENTS.md' 'admin / app / canvas / openapi / merchant' 'AGENTS platform list drift'
        Assert-Contains $failures 'docs/architecture/00-platform-and-module-rules.md' 'admin / app / canvas / openapi / merchant / miniapp' 'architecture platform list drift'
        Assert-Contains $failures 'docs/README.md' '/api/canvas/v1' 'docs README API scope drift'
        Assert-Contains $failures 'docs/README.md' $qualityRunwayPath 'docs README quality runway cold-start entry drift'
        Assert-Contains $failures $knowledgePath $qualityRunwayPath 'current runtime knowledge quality runway reference drift'
        Assert-Contains $failures $sourceMapPath $qualityRunwayPath 'runtime source map quality runway reference drift'
        Assert-Contains $failures $statusPath $qualityRunwayPath 'status quality runway reference drift'
        Assert-Contains $failures $qualityRunwayPath 'Admin Vue source quality | `280` source files，`0` any，`0` as-any，`0` catch-any，`542` fallback，`0` direct external HTTP' 'quality runway Admin Vue baseline drift'
        Assert-Contains $failures $qualityRunwayPath 'Go backend routes | `298` route registrations' 'quality runway Go route baseline drift'
        Assert-Contains $failures $qualityRunwayPath 'Live MySQL | live base tables = `57`' 'quality runway live schema baseline drift'
        Assert-Contains $failures $qualityRunwayPath 'Admin Vue fallback = 542 尚未逐条审查' 'quality runway must not claim fallback completion'
        Assert-Contains $failures $agentFrameworkPath 'docs/knowledge/current-runtime-knowledge.md' 'agent framework knowledge entry drift'
        Assert-Contains $failures $agentFrameworkPath 'docs/knowledge/runtime-source-map.md' 'agent framework source-map entry drift'
        Assert-Contains $failures $agentFrameworkPath 'docs/db/mysql-live-schema-YYYY-MM-DD.md' 'agent framework schema snapshot rule drift'
        Assert-Contains $failures 'docs/knowledge/README.md' 'docs/knowledge/runtime-source-map.md' 'knowledge README source-map entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $inventoryPath 'knowledge README runtime inventory entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $backendRouteInventoryPath 'knowledge README backend route inventory entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $backendRouteContractDriftPath 'knowledge README backend route contract drift entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $frontendApiInventoryPath 'knowledge README frontend API inventory entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $frontendBackendApiDriftPath 'knowledge README frontend/backend API drift entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $apiSourceOnlyReviewPath 'knowledge README API source-only route review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $dbSchemaOwnershipMapPath 'knowledge README DB schema ownership map entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $fullStackModuleMapPath 'knowledge README full-stack module map entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $backendCapabilityManifestPath 'knowledge README backend capability manifest entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontSourceQualityPath 'knowledge README Admin front source quality inventory entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $canvasRBACPermissionContractReviewPath 'knowledge README Canvas RBAC permission contract review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $canvasAssetRouteContractReviewPath 'knowledge README Canvas asset route contract review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $canvasAuthLogoutContractReviewPath 'knowledge README Canvas auth logout contract review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminUserStatusContractReviewPath 'knowledge README Admin user status contract review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminAIAgentTestContractReviewPath 'knowledge README Admin AI agent test contract review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDirectExternalHelperReviewPath 'knowledge README Admin front direct external helper review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontHeaderBreadcrumbReviewPath 'knowledge README Admin front Header breadcrumb review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontForgotPasswordErrorReviewPath 'knowledge README Admin front forgot-password error review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontJsonEditorReviewPath 'knowledge README Admin front JsonEditor review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDIconReviewPath 'knowledge README Admin front DIcon review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontEditorReviewPath 'knowledge README Admin front Editor review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDownloadManagerReviewPath 'knowledge README Admin front DownloadManager review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDevTestDownloadReviewPath 'knowledge README Admin front dev test download review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontValidatorReviewPath 'knowledge README Admin front validator review entry drift'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontUploadDemoReviewPath 'knowledge README Admin front upload demo review entry drift'
        Assert-Contains $failures $knowledgePath $inventoryPath 'current runtime knowledge inventory reference drift'
        Assert-Contains $failures $knowledgePath $backendRouteInventoryPath 'current runtime knowledge backend route inventory reference drift'
        Assert-Contains $failures $knowledgePath $backendRouteContractDriftPath 'current runtime knowledge backend route contract drift reference drift'
        Assert-Contains $failures $knowledgePath $frontendApiInventoryPath 'current runtime knowledge frontend API inventory reference drift'
        Assert-Contains $failures $knowledgePath $frontendBackendApiDriftPath 'current runtime knowledge frontend/backend API drift reference drift'
        Assert-Contains $failures $knowledgePath $apiSourceOnlyReviewPath 'current runtime knowledge API source-only route review reference drift'
        Assert-Contains $failures $knowledgePath $dbSchemaOwnershipMapPath 'current runtime knowledge DB schema ownership map reference drift'
        Assert-Contains $failures $knowledgePath $fullStackModuleMapPath 'current runtime knowledge full-stack module map reference drift'
        Assert-Contains $failures $knowledgePath $backendCapabilityManifestPath 'current runtime knowledge backend capability manifest reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontSourceQualityPath 'current runtime knowledge Admin front source quality inventory reference drift'
        Assert-Contains $failures $knowledgePath $canvasRBACPermissionContractReviewPath 'current runtime knowledge Canvas RBAC permission contract review reference drift'
        Assert-Contains $failures $knowledgePath $canvasAssetRouteContractReviewPath 'current runtime knowledge Canvas asset route contract review reference drift'
        Assert-Contains $failures $knowledgePath $canvasAuthLogoutContractReviewPath 'current runtime knowledge Canvas auth logout contract review reference drift'
        Assert-Contains $failures $knowledgePath $adminUserStatusContractReviewPath 'current runtime knowledge Admin user status contract review reference drift'
        Assert-Contains $failures $knowledgePath $adminAIAgentTestContractReviewPath 'current runtime knowledge Admin AI agent test contract review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontDirectExternalHelperReviewPath 'current runtime knowledge Admin front direct external helper review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontHeaderBreadcrumbReviewPath 'current runtime knowledge Admin front Header breadcrumb review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontForgotPasswordErrorReviewPath 'current runtime knowledge Admin front forgot-password error review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontJsonEditorReviewPath 'current runtime knowledge Admin front JsonEditor review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontDIconReviewPath 'current runtime knowledge Admin front DIcon review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontEditorReviewPath 'current runtime knowledge Admin front Editor review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontDownloadManagerReviewPath 'current runtime knowledge Admin front DownloadManager review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontDevTestDownloadReviewPath 'current runtime knowledge Admin front dev test download review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontValidatorReviewPath 'current runtime knowledge Admin front validator review reference drift'
        Assert-Contains $failures $knowledgePath $adminFrontUploadDemoReviewPath 'current runtime knowledge Admin front upload demo review reference drift'
        Assert-Contains $failures $sourceMapPath $inventoryPath 'source map inventory reference drift'
        Assert-Contains $failures $sourceMapPath $backendRouteInventoryPath 'source map backend route inventory reference drift'
        Assert-Contains $failures $sourceMapPath $backendRouteContractDriftPath 'source map backend route contract drift reference drift'
        Assert-Contains $failures $sourceMapPath $frontendApiInventoryPath 'source map frontend API inventory reference drift'
        Assert-Contains $failures $sourceMapPath $frontendBackendApiDriftPath 'source map frontend/backend API drift reference drift'
        Assert-Contains $failures $sourceMapPath $apiSourceOnlyReviewPath 'source map API source-only route review reference drift'
        Assert-Contains $failures $sourceMapPath $dbSchemaOwnershipMapPath 'source map DB schema ownership map reference drift'
        Assert-Contains $failures $sourceMapPath $fullStackModuleMapPath 'source map full-stack module map reference drift'
        Assert-Contains $failures $sourceMapPath $backendCapabilityManifestPath 'source map backend capability manifest reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontSourceQualityPath 'source map Admin front source quality inventory reference drift'
        Assert-Contains $failures $sourceMapPath $canvasRBACPermissionContractReviewPath 'source map Canvas RBAC permission contract review reference drift'
        Assert-Contains $failures $sourceMapPath $canvasAssetRouteContractReviewPath 'source map Canvas asset route contract review reference drift'
        Assert-Contains $failures $sourceMapPath $canvasAuthLogoutContractReviewPath 'source map Canvas auth logout contract review reference drift'
        Assert-Contains $failures $sourceMapPath $adminUserStatusContractReviewPath 'source map Admin user status contract review reference drift'
        Assert-Contains $failures $sourceMapPath $adminAIAgentTestContractReviewPath 'source map Admin AI agent test contract review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDirectExternalHelperReviewPath 'source map Admin front direct external helper review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontHeaderBreadcrumbReviewPath 'source map Admin front Header breadcrumb review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontForgotPasswordErrorReviewPath 'source map Admin front forgot-password error review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontJsonEditorReviewPath 'source map Admin front JsonEditor review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDIconReviewPath 'source map Admin front DIcon review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontEditorReviewPath 'source map Admin front Editor review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDownloadManagerReviewPath 'source map Admin front DownloadManager review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDevTestDownloadReviewPath 'source map Admin front dev test download review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontValidatorReviewPath 'source map Admin front validator review reference drift'
        Assert-Contains $failures $sourceMapPath $adminFrontUploadDemoReviewPath 'source map Admin front upload demo review reference drift'
        Assert-Contains $failures $statusPath $adminFrontSourceQualityPath 'status Admin front source quality inventory reference drift'
        Assert-Contains $failures $statusPath $adminAIAgentTestContractReviewPath 'status Admin AI agent test contract review drift'
        Assert-Contains $failures $statusPath $adminFrontDirectExternalHelperReviewPath 'status Admin front direct external helper review drift'
        Assert-Contains $failures $statusPath $adminFrontHeaderBreadcrumbReviewPath 'status Admin front Header breadcrumb review drift'
        Assert-Contains $failures $statusPath $adminFrontForgotPasswordErrorReviewPath 'status Admin front forgot-password error review drift'
        Assert-Contains $failures $statusPath $adminFrontJsonEditorReviewPath 'status Admin front JsonEditor review drift'
        Assert-Contains $failures $statusPath $adminFrontDIconReviewPath 'status Admin front DIcon review drift'
        Assert-Contains $failures $statusPath $adminFrontEditorReviewPath 'status Admin front Editor review drift'
        Assert-Contains $failures $statusPath $adminFrontDownloadManagerReviewPath 'status Admin front DownloadManager review drift'
        Assert-Contains $failures $statusPath $adminFrontDevTestDownloadReviewPath 'status Admin front dev test download review drift'
        Assert-Contains $failures $statusPath $adminFrontValidatorReviewPath 'status Admin front validator review drift'
        Assert-Contains $failures $statusPath $adminFrontUploadDemoReviewPath 'status Admin front upload demo review drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-backend-route-inventory.ps1' 'agent framework backend route inventory exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-backend-route-contract-drift.ps1' 'agent framework backend route contract drift exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-frontend-api-inventory.ps1' 'agent framework frontend API inventory exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-frontend-backend-api-drift.ps1' 'agent framework frontend/backend API drift exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-api-source-only-route-review.ps1' 'agent framework API source-only route review exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-db-schema-ownership-map.ps1' 'agent framework DB schema ownership exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'docs/knowledge/db-schema-ownership-map-YYYY-MM-DD.md' 'agent framework DB schema ownership artifact rule drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-full-stack-module-map.ps1' 'agent framework full-stack module map exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'docs/knowledge/full-stack-module-map-YYYY-MM-DD.md' 'agent framework full-stack module map artifact rule drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-backend-capability-manifest.ps1' 'agent framework backend capability manifest exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'docs/knowledge/backend-capability-manifest-YYYY-MM-DD.md' 'agent framework backend capability manifest artifact rule drift'
        Assert-Contains $failures $agentFrameworkPath 'scripts/export-admin-front-source-quality-inventory.ps1' 'agent framework Admin front source quality exporter drift'
        Assert-Contains $failures $agentFrameworkPath 'docs/knowledge/admin-front-source-quality-inventory-YYYY-MM-DD.md' 'agent framework Admin front source quality artifact rule drift'
        foreach ($path in @('docs/knowledge/README.md', $knowledgePath, $sourceMapPath, $statusPath)) {
            Assert-Contains $failures $path $schemaMdPath "latest schema markdown reference drift"
            Assert-Contains $failures $path $schemaSqlPath "latest schema SQL reference drift"
        }
        Assert-Contains $failures $inventoryPath $schemaMdPath 'runtime inventory latest schema markdown drift'
        Assert-Contains $failures $inventoryPath $schemaSqlPath 'runtime inventory latest schema SQL drift'
        Assert-Contains $failures $dbSchemaOwnershipMapPath $schemaMdPath 'DB schema ownership latest schema markdown drift'
        Assert-Contains $failures $dbSchemaOwnershipMapPath $schemaSqlPath 'DB schema ownership latest schema SQL drift'
        Assert-Contains $failures $fullStackModuleMapPath $schemaMdPath 'full-stack module map latest schema markdown drift'
        Assert-Contains $failures $fullStackModuleMapPath $schemaSqlPath 'full-stack module map latest schema SQL drift'
        Assert-Contains $failures $fullStackModuleMapPath $backendRouteInventoryPath 'full-stack module map backend route artifact reference drift'
        Assert-Contains $failures $fullStackModuleMapPath $frontendApiInventoryPath 'full-stack module map frontend API artifact reference drift'
        Assert-Contains $failures $fullStackModuleMapPath $dbSchemaOwnershipMapPath 'full-stack module map DB ownership artifact reference drift'
        Assert-Contains $failures $fullStackModuleMapPath $apiSourceOnlyReviewPath 'full-stack module map source-only review artifact reference drift'
        Assert-Contains $failures $backendCapabilityManifestPath $backendRouteInventoryPath 'backend capability manifest route artifact reference drift'
        Assert-Contains $failures $backendCapabilityManifestPath $dbSchemaOwnershipMapPath 'backend capability manifest DB ownership artifact reference drift'

        $backendRouteRegistrationCount = Get-BackendRouteRegistrationCount
        $backendRouteArtifactCount = Get-MarkdownSummaryCount $backendRouteInventoryPath 'Route registrations found'
        if ($backendRouteArtifactCount -ne $backendRouteRegistrationCount) {
            Add-Failure $failures "backend route inventory count $backendRouteArtifactCount does not match current route source count $backendRouteRegistrationCount"
        }
        [void]$evidence.Add("backend_route_registrations=$backendRouteRegistrationCount")
        if ((Get-MarkdownSummaryCount $backendRouteInventoryPath 'Unresolved registrations') -ne 0) {
            Add-Failure $failures 'backend route inventory contains unresolved route registrations'
        }
        if ((Get-MarkdownSummaryCount $backendRouteInventoryPath 'Unmatched permission route_meta keys') -ne 0) {
            Add-Failure $failures 'backend route inventory contains unmatched permission route_meta keys'
        }
        if ((Get-MarkdownSummaryCount $backendRouteInventoryPath 'Unmatched operation route_meta keys') -ne 0) {
            Add-Failure $failures 'backend route inventory contains unmatched operation route_meta keys'
        }
        Assert-Contains $failures $backendRouteInventoryPath 'Route registrations found' 'backend route inventory summary drift'
        Assert-Contains $failures $backendRouteInventoryPath 'transport/callback/route.go' 'backend route inventory callback route drift'
        Assert-Contains $failures $backendRouteInventoryPath '/api/admin/v1/users/me' 'backend route inventory admin users/me route drift'
        Assert-Contains $failures $backendRouteInventoryPath '/api/canvas/v1/users/me' 'backend route inventory canvas users/me route drift'

        $backendRouteContractDriftCount = Get-MarkdownSummaryCount $backendRouteContractDriftPath 'Route registrations compared'
        if ($backendRouteContractDriftCount -ne $backendRouteArtifactCount) {
            Add-Failure $failures "backend route contract drift count $backendRouteContractDriftCount does not match backend route inventory count $backendRouteArtifactCount"
        }
        [void]$evidence.Add("backend_route_contract_drift_compared=$backendRouteContractDriftCount")
        if ((Get-MarkdownSummaryCount $backendRouteContractDriftPath 'undocumented-exact') -ne 0) {
            Add-Failure $failures 'backend route contract drift contains undocumented-exact rows'
        }
        if ((Get-MarkdownSummaryCount $backendRouteContractDriftPath 'contract-prefix-only') -ne 0) {
            Add-Failure $failures 'backend route contract drift contains contract-prefix-only rows'
        }
        if ((Get-MarkdownSummaryCount $backendRouteContractDriftPath 'source-docs-only') -ne 0) {
            Add-Failure $failures 'backend route contract drift contains source-docs-only rows'
        }
        Assert-Contains $failures $backendRouteContractDriftPath $backendRouteInventoryPath 'backend route contract drift inventory reference drift'
        Assert-Contains $failures $backendRouteContractDriftPath 'contract-prefix-only' 'backend route contract drift classification drift'

        [void]$evidence.Add("frontend_api_calls=$(Get-MarkdownSummaryCount $frontendApiInventoryPath 'Frontend API calls found')")
        [void]$evidence.Add("frontend_admin_backend_calls=$(Get-MarkdownSummaryCount $frontendApiInventoryPath 'Admin frontend backend API calls')")
        [void]$evidence.Add("frontend_canvas_backend_calls=$(Get-MarkdownSummaryCount $frontendApiInventoryPath 'Canvas frontend backend API calls')")
        if ((Get-MarkdownSummaryCount $frontendApiInventoryPath 'Backend /api calls outside known prefixes') -ne 0) {
            Add-Failure $failures 'frontend API inventory contains backend /api calls outside known prefixes'
        }
        if ((Get-MarkdownSummaryCount $frontendApiInventoryPath 'Unresolved frontend API expressions') -ne 0) {
            Add-Failure $failures 'frontend API inventory contains unresolved frontend API expressions'
        }
        Assert-Contains $failures $frontendApiInventoryPath 'GET /api/admin/v1/users/me' 'frontend API inventory admin users/me call drift'
        Assert-Contains $failures $frontendApiInventoryPath 'GET /api/canvas/v1/users/me' 'frontend API inventory canvas users/me call drift'
        Assert-Contains $failures $frontendApiInventoryPath 'POST /api/canvas/v1/auth/logout' 'frontend API inventory canvas auth logout call drift'
        Assert-Contains $failures $frontendApiInventoryPath 'PATCH /api/admin/v1/users/:param/status' 'frontend API inventory admin user status call drift'
        Assert-Contains $failures $frontendApiInventoryPath 'POST /api/admin/v1/ai-agents/:param/test' 'frontend API inventory admin AI agent test call drift'
        Assert-NotContains $failures $frontendApiInventoryPath 'https://api.btstu.cn/sjbz/api.php' 'frontend API inventory reintroduced retired random-image external helper'
        Assert-Contains $failures $frontendApiInventoryPath 'backend-admin-parametric' 'frontend API inventory parametric helper classification drift'

        $frontendExactCalls = Get-MarkdownSummaryCount $frontendBackendApiDriftPath 'Frontend exact backend API calls compared'
        $frontendRouteMatches = Get-MarkdownSummaryCount $frontendBackendApiDriftPath 'frontend-route-match'
        [void]$evidence.Add("frontend_backend_exact_calls_compared=$frontendExactCalls")
        [void]$evidence.Add("frontend_backend_route_matches=$frontendRouteMatches")
        if ($frontendRouteMatches -ne $frontendExactCalls) {
            Add-Failure $failures "frontend/backend API drift route matches $frontendRouteMatches do not equal exact calls $frontendExactCalls"
        }
        if ((Get-MarkdownSummaryCount $frontendBackendApiDriftPath 'frontend-method-mismatch') -ne 0) {
            Add-Failure $failures 'frontend/backend API drift contains method mismatches'
        }
        if ((Get-MarkdownSummaryCount $frontendBackendApiDriftPath 'frontend-no-backend-route') -ne 0) {
            Add-Failure $failures 'frontend/backend API drift contains frontend calls without backend route'
        }
        if ((Get-MarkdownSummaryCount $frontendBackendApiDriftPath 'Frontend inventory unresolved expressions') -ne 0) {
            Add-Failure $failures 'frontend/backend API drift was generated from unresolved frontend API expressions'
        }
        Assert-Contains $failures $frontendBackendApiDriftPath $backendRouteInventoryPath 'frontend/backend API drift backend inventory reference drift'
        Assert-Contains $failures $frontendBackendApiDriftPath $frontendApiInventoryPath 'frontend/backend API drift frontend inventory reference drift'
        Assert-Contains $failures $frontendBackendApiDriftPath 'Backend admin/canvas routes not referenced by exact frontend calls' 'frontend/backend API drift source-only review table drift'
        Assert-Contains $failures $frontendBackendApiDriftPath 'backend-admin-parametric' 'frontend/backend API drift parametric helper classification drift'

        $sourceOnlyRoutesReviewed = Get-MarkdownSummaryCount $apiSourceOnlyReviewPath 'Source-only routes reviewed'
        $sourceOnlyRowsFromDrift = Get-MarkdownSummaryCount $frontendBackendApiDriftPath 'Backend admin/canvas routes not referenced by exact frontend calls'
        [void]$evidence.Add("api_source_only_routes_reviewed=$sourceOnlyRoutesReviewed")
        [void]$evidence.Add("api_source_only_owner_decision_required=$(Get-MarkdownSummaryCount $apiSourceOnlyReviewPath 'Owner-decision-required routes')")
        if ($sourceOnlyRoutesReviewed -ne $sourceOnlyRowsFromDrift) {
            Add-Failure $failures "API source-only review count $sourceOnlyRoutesReviewed does not match drift source-only count $sourceOnlyRowsFromDrift"
        }
        if ((Get-MarkdownSummaryCount $apiSourceOnlyReviewPath 'Owner-decision-required routes') -ne 0) {
            Add-Failure $failures 'API source-only route review owner decision count changed from expected 0'
        }
        Assert-Contains $failures $apiSourceOnlyReviewPath $frontendBackendApiDriftPath 'API source-only route review drift artifact reference drift'
        Assert-NotContains $failures $apiSourceOnlyReviewPath '/api/admin/v1/ai-agents/:id/test' 'API source-only review still lists resolved ai agent test owner decision'
        Assert-NotContains $failures $frontendBackendApiDriftPath '/api/admin/v1/ai-agents/:id/test' 'frontend/backend API drift still lists resolved ai agent test source-only row'
        Assert-NotContains $failures $apiSourceOnlyReviewPath '/api/admin/v1/users/:id/status' 'API source-only review still lists resolved user status owner decision'
        Assert-NotContains $failures $frontendBackendApiDriftPath '/api/admin/v1/users/:id/status' 'frontend/backend API drift still lists resolved user status source-only row'
        Assert-NotContains $failures $apiSourceOnlyReviewPath '/api/canvas/v1/auth/logout' 'API source-only review still lists resolved canvas logout owner decision'
        Assert-Contains $failures $apiSourceOnlyReviewPath 'frontend-parametric-helper-covered' 'API source-only review parametric helper classification drift'

        $adminPrefixText = Read-Text 'admin_front_ts/src/lib/http/api-prefix.ts'
        if (-not $adminPrefixText.Contains("ADMIN_API_PREFIX = '/api/admin/v1'")) {
            Add-Failure $failures 'admin_front_ts API prefix is not /api/admin/v1'
        }
        $usersApiText = Read-Text 'admin_front_ts/src/api/user/users.ts'
        if (-not $usersApiText.Contains('/users/me')) {
            Add-Failure $failures 'admin_front_ts UsersApi no longer calls /users/me'
        }
        if ($usersApiText.Contains('/users/init')) {
            Add-Failure $failures 'admin_front_ts UsersApi still references /users/init'
        }
        Assert-Contains $failures $knowledgePath 'GET /api/admin/v1/users/me' 'knowledge admin users/me contract drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts' 'src/components/Table/src/components/TableActions.vue' 'Admin Vue TableActions i18n guard coverage drift'
        Assert-Contains $failures 'admin_front_ts/src/components/Table/src/components/TableActions.vue' "t('common.actions.refresh')" 'Admin Vue TableActions refresh i18n key drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a shared-component i18n guard fix.' 'ADMIN-FRONT-HARDENING-001 resolved status drift'
        $tableActionsText = Read-Text 'admin_front_ts/src/components/Table/src/components/TableActions.vue'
        if ($tableActionsText.Contains('刷新')) {
            Add-Failure $failures 'admin_front_ts TableActions still contains raw visible Chinese refresh text'
        }
        [void]$evidence.Add('admin_front_table_actions_i18n_guard=covered')

        Assert-Contains $failures 'admin_front_ts/tests/layout/search-dialog-source-quality.test.ts' 'src/views/Layout/components/Header/components/SearchDialog.vue' 'Admin Vue SearchDialog source-quality guard coverage drift'
        $searchDialogText = Read-Text 'admin_front_ts/src/views/Layout/components/Header/components/SearchDialog.vue'
        if ([regex]::IsMatch($searchDialogText, '\bany\b|\bas\s+any\b')) {
            Add-Failure $failures 'admin_front_ts SearchDialog still contains any/as any route-walk debt'
        }
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a typed route-search guard fix.' 'ADMIN-FRONT-HARDENING-002 resolved status drift'
        [void]$evidence.Add('admin_front_search_dialog_source_quality_guard=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $canvasAIRequestContractReviewPath 'Canvas AI request contract review knowledge index drift'
        Assert-Contains $failures $knowledgePath $canvasAIRequestContractReviewPath 'current runtime knowledge Canvas AI request contract review drift'
        Assert-Contains $failures $sourceMapPath $canvasAIRequestContractReviewPath 'runtime source map Canvas AI request contract review drift'
        Assert-Contains $failures 'docs/contracts/admin-api-v1.md' 'CanvasChatCompletionBody' 'Canvas AI chat request contract missing typed body'
        Assert-Contains $failures 'docs/contracts/admin-api-v1.md' 'CanvasVideoGenerationBody' 'Canvas AI video request contract missing typed body'
        Assert-Contains $failures 'docs/contracts/admin-api-v1.md' 'forbidden request fields: `model`, `provider`, `api_key`, `base_url`' 'Canvas AI forbidden request field contract drift'
        Assert-Contains $failures $canvasAIRequestContractReviewPath 'forbidden request fields: `model`, `provider`, `api_key`, `base_url`' 'Canvas AI request review forbidden field drift'
        Assert-Contains $failures $canvasAIRequestContractReviewPath 'chat: JSON `agent_id` + `message`' 'Canvas AI request review chat body drift'
        Assert-Contains $failures $canvasAIRequestContractReviewPath 'video: JSON or FormData `agent_id` + `prompt` + video params' 'Canvas AI request review video body drift'
        Assert-Contains $failures 'admin_back_go/internal/module/ai/internal/canvasrequest/json.go' 'agentOwnedConfigFields = [...]string{"model", "provider", "api_key", "base_url"}' 'Canvas AI forbidden field guard drift'
        Assert-NotContains $failures 'admin_back_go/internal/module/ai/chat/transport/canvas/request.go' 'json:"model"' 'Canvas AI chat request model field drift'
        Assert-NotContains $failures 'admin_back_go/internal/module/ai/video/transport/canvas/request.go' 'json:"model"' 'Canvas AI video request model field drift'
        Assert-NotContains $failures 'admin_back_go/internal/module/ai/chat/transport/canvas/handler.go' 'ModelID: req.ModelID' 'Canvas AI chat handler still forwards client model'
        Assert-NotContains $failures 'admin_back_go/internal/module/ai/video/transport/canvas/handler.go' 'ModelID: req.ModelID' 'Canvas AI video handler still forwards client model'
        Assert-Contains $failures 'admin_back_go/internal/module/ai/video/transport/canvas/handler_test.go' 'TestCanvasVideoRoutesAcceptActiveClientMultipartRequest' 'Canvas AI video multipart active-client guard missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as an agent_id-only request contract guard fix.' 'CANVAS-DOC-003 resolved status drift'
        [void]$evidence.Add('canvas_ai_request_contract_agent_id_only=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $canvasRBACPermissionContractReviewPath 'Canvas RBAC permission contract review knowledge index drift'
        Assert-Contains $failures $knowledgePath $canvasRBACPermissionContractReviewPath 'current runtime knowledge Canvas RBAC permission contract review drift'
        Assert-Contains $failures $sourceMapPath $canvasRBACPermissionContractReviewPath 'runtime source map Canvas RBAC permission contract review drift'
        Assert-Contains $failures 'docs/contracts/admin-api-v1.md' 'BUTTON: canvas_access, canvas_prompt_read, canvas_asset_read, canvas_ai_image_generate, canvas_ai_video_generate' 'Canvas active BUTTON contract drift'
        Assert-NotContains $failures 'docs/contracts/admin-api-v1.md' 'canvas_ai_text_generate' 'Canvas contract must not reintroduce dead text-generation BUTTON code'
        Assert-Contains $failures $canvasRBACPermissionContractReviewPath 'not an active Canvas BUTTON permission' 'Canvas RBAC permission review active/dead decision drift'
        Assert-Contains $failures $canvasRBACPermissionContractReviewPath 'soft-deleted orphan' 'Canvas RBAC permission review live DB evidence drift'
        Assert-Contains $failures 'canvas_front_next/tests/shared/canvas-rbac-shell.test.ts' 'expect(registry).not.toContain("canvas_ai_text_generate")' 'Canvas RBAC negative guard missing'
        Assert-NotContains $failures 'canvas_front_next/src/features/rbac/canvas-permissions.ts' 'canvas_ai_text_generate' 'Canvas frontend canonical permission type reintroduced dead text code'
        $canvasTextPermissionSourceReferences = @(
            Get-ChildItem -LiteralPath 'canvas_front_next/src' -Recurse -File |
                Where-Object { $_.Extension -in @('.ts', '.tsx') } |
                Select-String -Pattern 'canvas_ai_text_generate' -SimpleMatch -ErrorAction SilentlyContinue
        )
        if ($canvasTextPermissionSourceReferences.Count -gt 0) {
            $first = $canvasTextPermissionSourceReferences | Select-Object -First 1
            Add-Failure $failures "Canvas frontend src still references dead canvas_ai_text_generate permission at $($first.Path):$($first.LineNumber)"
        }
        Assert-NotContains $failures 'admin_back_go/database/migrations/20260531_canvas_front_next_integration.sql' 'canvas_ai_text_generate' 'Canvas integration migration reintroduced dead text-generation BUTTON code'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a dead frontend permission type drift cleanup.' 'CANVAS-DOC-001 resolved status drift'
        [void]$evidence.Add('canvas_rbac_text_permission_dead_code=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $canvasAssetRouteContractReviewPath 'Canvas asset route contract review knowledge index drift'
        Assert-Contains $failures $knowledgePath $canvasAssetRouteContractReviewPath 'current runtime knowledge Canvas asset route contract review drift'
        Assert-Contains $failures $sourceMapPath $canvasAssetRouteContractReviewPath 'runtime source map Canvas asset route contract review drift'
        Assert-Contains $failures 'canvas_front_next/src/features/rbac/canvas-permissions.ts' 'path: "/assets"' 'Canvas frontend canonical assets route missing'
        Assert-NotContains $failures 'canvas_front_next/src/features/rbac/canvas-permissions.ts' '/asset-library' 'Canvas frontend route registry reintroduced dead asset-library path'
        if (Test-Path -LiteralPath 'canvas_front_next/src/app/(user)/asset-library/page.tsx') {
            Add-Failure $failures 'Canvas frontend still contains dead asset-library page'
        }
        Assert-Contains $failures 'canvas_front_next/tests/shared/canvas-rbac-shell.test.ts' 'asset-library' 'Canvas asset-library negative guard missing'
        Assert-Contains $failures 'canvas_front_next/tests/shared/canvas-rbac-shell.test.ts' 'asset-picker-modal.tsx' 'Canvas asset API active caller guard missing'
        Assert-Contains $failures $canvasAssetRouteContractReviewPath '`/asset-library` was a dead Canvas Next page' 'Canvas asset route review decision drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a dead Canvas Next page cleanup.' 'CANVAS-DOC-002 resolved status drift'
        Assert-NotContains $failures $sourceMapPath '(user)/asset-library' 'source map reintroduced dead Canvas asset-library page'
        Assert-NotContains $failures $inventoryPath '(user)/asset-library' 'runtime inventory reintroduced dead Canvas asset-library page'
        Assert-NotContains $failures $frontendApiInventoryPath 'asset-library/page.tsx' 'frontend API inventory reintroduced dead Canvas asset-library page'
        [void]$evidence.Add('canvas_asset_route_contract_dead_page=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $canvasAuthLogoutContractReviewPath 'Canvas auth logout contract review knowledge index drift'
        Assert-Contains $failures $knowledgePath $canvasAuthLogoutContractReviewPath 'current runtime knowledge Canvas auth logout contract review drift'
        Assert-Contains $failures $sourceMapPath $canvasAuthLogoutContractReviewPath 'runtime source map Canvas auth logout contract review drift'
        Assert-Contains $failures $canvasAuthLogoutContractReviewPath 'active Canvas frontend gap' 'Canvas auth logout review decision drift'
        Assert-Contains $failures $canvasAuthLogoutContractReviewPath 'backend failure preserves the browser session' 'Canvas auth logout review fail-closed drift'
        Assert-Contains $failures 'canvas_front_next/src/services/api/auth.ts' 'apiPost<null>("/api/canvas/v1/auth/logout", null, token)' 'Canvas auth logout API wrapper drift'
        Assert-Contains $failures 'canvas_front_next/src/stores/use-user-store.ts' 'await logoutSession(token)' 'Canvas user store logout must call backend revoke'
        Assert-Contains $failures 'canvas_front_next/src/stores/use-user-store.ts' 'throw error' 'Canvas user store logout must rethrow backend revoke failure'
        Assert-Contains $failures 'canvas_front_next/src/components/layout/user-status-actions.tsx' 'state.logout' 'Canvas user status menu must use async logout action'
        Assert-NotContains $failures 'canvas_front_next/src/components/layout/user-status-actions.tsx' 'state.clearSession' 'Canvas user status menu still uses local-only logout'
        Assert-Contains $failures 'canvas_front_next/tests/shared/canvas-auth-boundary.test.ts' 'logout revokes the canvas backend session before local cleanup' 'Canvas auth logout boundary guard missing'
        Assert-Contains $failures 'canvas_front_next/src/stores/use-user-store.test.ts' 'keeps the browser session when backend logout fails' 'Canvas auth logout fail-closed store test missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as an active Canvas frontend contract call.' 'Canvas auth logout resolved status drift'
        [void]$evidence.Add('canvas_auth_logout_contract=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminUserStatusContractReviewPath 'Admin user status contract review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminUserStatusContractReviewPath 'current runtime knowledge Admin user status contract review drift'
        Assert-Contains $failures $sourceMapPath $adminUserStatusContractReviewPath 'runtime source map Admin user status contract review drift'
        Assert-Contains $failures $statusPath $adminUserStatusContractReviewPath 'status Admin user status contract review drift'
        Assert-Contains $failures $adminUserStatusContractReviewPath 'active Admin Vue frontend gap that has been closed' 'Admin user status review decision drift'
        Assert-Contains $failures $adminUserStatusContractReviewPath '`API-DRIFT-001` has no remaining owner-decision-required route' 'Admin user status review zero owner decision drift'
        Assert-Contains $failures 'admin_front_ts/src/api/user/users.ts' 'type UserStatusBody = { status: number }' 'Admin user status API body type drift'
        Assert-Contains $failures 'admin_front_ts/src/api/user/users.ts' 'request.patch<void, UserStatusBody>(`${ADMIN_API_PREFIX}/users/${ids[0]}/status`, body)' 'Admin user status API wrapper drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue' 'toggleStatus(row, CommonEnum.YES)' 'Admin user status enable action drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/user/userManager/components/UserList/index.vue' 'toggleStatus(row, CommonEnum.NO)' 'Admin user status disable action drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/user/user-list.test.ts' 'uses the dedicated Go REST status route for user enable and disable' 'Admin user status source guard missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as an active Admin Vue frontend contract call.' 'Admin user status resolved status drift'
        [void]$evidence.Add('admin_user_status_contract=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminAIAgentTestContractReviewPath 'Admin AI agent test contract review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminAIAgentTestContractReviewPath 'current runtime knowledge Admin AI agent test contract review drift'
        Assert-Contains $failures $sourceMapPath $adminAIAgentTestContractReviewPath 'runtime source map Admin AI agent test contract review drift'
        Assert-Contains $failures $statusPath $adminAIAgentTestContractReviewPath 'status Admin AI agent test contract review drift'
        Assert-Contains $failures $adminAIAgentTestContractReviewPath 'active Admin Vue frontend gap that has been closed' 'Admin AI agent test review decision drift'
        Assert-Contains $failures $adminAIAgentTestContractReviewPath 'owner-decision-required routes = 0' 'Admin AI agent test review owner decision count drift'
        Assert-Contains $failures 'admin_front_ts/src/api/ai/agents.ts' 'export interface AiAgentTestResult' 'Admin AI agent test result type drift'
        Assert-Contains $failures 'admin_front_ts/src/api/ai/agents.ts' 'request.post<AiAgentTestResult>(`${ADMIN_API_PREFIX}/ai-agents/${positiveID(params.id, ''AI agent id'')}/test`)' 'Admin AI agent test API wrapper drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/ai/agents/index.vue' 'async function testConnection(row: AiAgentItem)' 'Admin AI agent test page action handler drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/ai/agents/index.vue' "userStore.can('ai_agent_test') && row.status === CommonEnum.YES" 'Admin AI agent test permission/status guard drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/ai/ai-agent-api.test.ts' 'request.post<AiAgentTestResult>' 'Admin AI agent test source guard missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 after the Admin AI agent test frontend contract call.' 'API-DRIFT-001 resolved aggregate status drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'docs/knowledge/api-source-only-route-review-2026-06-07.md now reports 0 owner-decision-required rows and no ai-agents/:id/test row.' 'Admin AI agent test source-only resolved evidence drift'
        [void]$evidence.Add('admin_ai_agent_test_contract=covered')

        $canvasProxyText = Read-Text 'canvas_front_next/src/app/api/[...path]/route.ts'
        if (-not $canvasProxyText.Contains('process.env.API_BASE_URL || "http://127.0.0.1:8080"')) {
            Add-Failure $failures 'canvas proxy default API_BASE_URL drift'
        }
        Assert-Contains $failures $knowledgePath 'API_BASE_URL' 'knowledge canvas proxy rule drift'
        Assert-Contains $failures $knowledgePath '/api/canvas/v1/users/me' 'knowledge canvas users/me contract drift'
        Assert-Contains $failures $sourceMapPath 'transport/callback' 'source map callback transport exception drift'
        Assert-Contains $failures $sourceMapPath '(user)/assets' 'source map canvas assets route inventory drift'
        Assert-Contains $failures $sourceMapPath 'admin_back_go/internal/jobs/noop.go' 'source map jobs register drift'
        Assert-Contains $failures $inventoryPath 'transport/callback' 'runtime inventory callback transport exception drift'

        foreach ($module in @(Get-ChildItem -LiteralPath 'admin_back_go/internal/module' -Directory | Sort-Object Name)) {
            Assert-Contains $failures $sourceMapPath "| ``$($module.Name)`` |" "source map missing backend module $($module.Name)"
            Assert-Contains $failures $inventoryPath "| ``$($module.Name)`` |" "runtime inventory missing backend module $($module.Name)"
            foreach ($transportDir in @(Get-ChildItem -LiteralPath $module.FullName -Recurse -Directory -Filter 'transport')) {
                foreach ($surface in @(Get-ChildItem -LiteralPath $transportDir.FullName -Directory | Sort-Object Name)) {
                    $relativeSurface = Get-RelativeUnixPath -BasePath $module.FullName -ChildPath $surface.FullName
                    Assert-Contains $failures $sourceMapPath $relativeSurface "source map missing backend transport $($module.Name)/$relativeSurface"
                    Assert-Contains $failures $inventoryPath $relativeSurface "runtime inventory missing backend transport $($module.Name)/$relativeSurface"
                }
            }
        }

        foreach ($page in @(Get-ChildItem -LiteralPath 'canvas_front_next/src/app' -Recurse -Filter 'page.tsx' | Sort-Object FullName)) {
            $relativePage = Get-RelativeUnixPath -BasePath 'canvas_front_next/src/app' -ChildPath $page.DirectoryName
            Assert-Contains $failures $sourceMapPath $relativePage "source map missing Canvas page $relativePage"
            Assert-Contains $failures $inventoryPath $relativePage "runtime inventory missing Canvas page $relativePage"
        }

        foreach ($bad in @(
            'login -> AuthToken -> users/me -> users/init',
            'users/init returns temporary router',
            '`init` 只允许作为明确 bootstrap contract，例如 `users/init`',
            '当前 Phase 2 架构级重构的 code/docs/frontend gates 已通过，final admin smoke 仍 pending',
            'page-init 一律通过 `dict.PageInit(ctx, names...)` 组装',
            '模块 HTTP request struct 放在 `internal/module/<name>/request.go`'
        )) {
            foreach ($path in @('AGENTS.md', 'agents/api-contract.md', 'docs/architecture/00-platform-and-module-rules.md', 'docs/architecture/04-go-backend-framework.md', 'docs/architecture/05-development-quality-rules.md', $statusPath, 'docs/status/module-matrix.md', 'docs/testing/test-strategy.md')) {
                Assert-NotContains $failures $path $bad 'stale docs phrase drift'
            }
        }

        $schemaCount = Get-SchemaBaseTableCount $schemaMdPath
        if ($schemaCount -ne 57) {
            Add-Failure $failures "schema snapshot expected 57 base tables, got $schemaCount"
        }
        [void]$evidence.Add("schema_snapshot_base_tables=$schemaCount")
        foreach ($table in @('users', 'permissions', 'ai_agents', 'ai_image_tasks', 'ai_image_files', 'ai_prompts', 'ai_assets', 'canvas_prompts', 'canvas_assets', 'canvas_video_tasks', 'payment_recharges')) {
            Assert-Contains $failures $schemaSqlPath "CREATE TABLE ``$table``" "schema DDL missing table $table"
        }

        $dbSchemaOwnershipReviewed = Get-MarkdownSummaryCount $dbSchemaOwnershipMapPath 'Live tables reviewed'
        $dbSchemaOwnershipText = Read-Text $dbSchemaOwnershipMapPath
        $dbSchemaOwnershipLiveOnly = 0
        if ($dbSchemaOwnershipText.Contains('| live-schema-only |')) {
            $dbSchemaOwnershipLiveOnly = Get-MarkdownSummaryCount $dbSchemaOwnershipMapPath 'live-schema-only'
        }
        [void]$evidence.Add("db_schema_ownership_live_tables_reviewed=$dbSchemaOwnershipReviewed")
        [void]$evidence.Add("db_schema_ownership_live_schema_only=$dbSchemaOwnershipLiveOnly")
        if ($dbSchemaOwnershipReviewed -ne $schemaCount) {
            Add-Failure $failures "DB schema ownership reviewed $dbSchemaOwnershipReviewed tables, but schema snapshot has $schemaCount base tables"
        }
        if ($dbSchemaOwnershipLiveOnly -ne 2) {
            Add-Failure $failures "DB schema ownership live-schema-only count changed from expected 2 legacy AI prompt/asset migration-window tables to $dbSchemaOwnershipLiveOnly"
        }
        Assert-Contains $failures $dbSchemaOwnershipMapPath 'not a migration history' 'DB schema ownership scope disclaimer drift'
        foreach ($table in @('users', 'permissions', 'ai_agents', 'ai_image_tasks', 'ai_image_files', 'canvas_prompts', 'payment_recharges')) {
            Assert-Contains $failures $dbSchemaOwnershipMapPath "``$table``" "DB schema ownership missing table $table"
        }
        foreach ($table in @('canvas_prompts', 'canvas_assets')) {
            Assert-Contains $failures $dbSchemaOwnershipMapPath "| ``$table``" "DB schema ownership missing retained legacy migration-window table $table"
            Assert-Contains $failures $dbSchemaOwnershipMapPath "``$table`` |" "DB schema ownership missing retained legacy migration-window table $table"
        }

        $fullStackBackendRoutes = Get-MarkdownSummaryCount $fullStackModuleMapPath 'Backend route registrations joined'
        $fullStackFrontendAssigned = Get-MarkdownSummaryCount $fullStackModuleMapPath 'Frontend exact backend API calls assigned'
        $fullStackFrontendUnassigned = Get-MarkdownSummaryCount $fullStackModuleMapPath 'Unassigned frontend exact backend API calls'
        $fullStackLiveTables = Get-MarkdownSummaryCount $fullStackModuleMapPath 'Live DB tables mapped'
        $fullStackSourceOnlyReviewed = Get-MarkdownSummaryCount $fullStackModuleMapPath 'Source-only routes reviewed'
        $fullStackOwnerDecision = Get-MarkdownSummaryCount $fullStackModuleMapPath 'Owner-decision-required routes'
        [void]$evidence.Add("full_stack_backend_routes=$fullStackBackendRoutes")
        [void]$evidence.Add("full_stack_frontend_exact_assigned=$fullStackFrontendAssigned")
        [void]$evidence.Add("full_stack_frontend_exact_unassigned=$fullStackFrontendUnassigned")
        [void]$evidence.Add("full_stack_live_db_tables=$fullStackLiveTables")
        [void]$evidence.Add("full_stack_owner_decision_required=$fullStackOwnerDecision")
        if ($fullStackBackendRoutes -ne $backendRouteArtifactCount) {
            Add-Failure $failures "full-stack module map backend routes $fullStackBackendRoutes do not match backend route inventory $backendRouteArtifactCount"
        }
        if ($fullStackFrontendAssigned -ne $frontendExactCalls) {
            Add-Failure $failures "full-stack module map frontend assigned calls $fullStackFrontendAssigned do not match frontend/backend exact calls $frontendExactCalls"
        }
        if ($fullStackFrontendUnassigned -ne 0) {
            Add-Failure $failures "full-stack module map contains $fullStackFrontendUnassigned unassigned frontend exact backend calls"
        }
        if ($fullStackLiveTables -ne $dbSchemaOwnershipReviewed) {
            Add-Failure $failures "full-stack module map live tables $fullStackLiveTables do not match DB ownership reviewed tables $dbSchemaOwnershipReviewed"
        }
        if ($fullStackSourceOnlyReviewed -ne $sourceOnlyRoutesReviewed) {
            Add-Failure $failures "full-stack module map source-only routes $fullStackSourceOnlyReviewed do not match source-only review $sourceOnlyRoutesReviewed"
        }
        if ($fullStackOwnerDecision -ne 0) {
            Add-Failure $failures 'full-stack module map owner decision count changed from expected 0'
        }
        Assert-Contains $failures $fullStackModuleMapPath 'If a frontend exact backend API call cannot be joined to backend route inventory, this exporter fails' 'full-stack module map no-fallback invariant drift'
        foreach ($capability in @('auth', 'user', 'permission', 'ai/agent', 'canvas', 'payment', 'payment/wallet')) {
            Assert-Contains $failures $fullStackModuleMapPath "| ``$capability`` |" "full-stack module map missing capability $capability"
        }

        $backendCapabilityCount = Get-MarkdownSummaryCount $backendCapabilityManifestPath 'Backend capabilities found'
        $backendCapabilityRoutes = Get-MarkdownSummaryCount $backendCapabilityManifestPath 'Backend route registrations covered'
        $backendCapabilityHelpers = Get-MarkdownSummaryCount $backendCapabilityManifestPath 'Helper packages not promoted'
        [void]$evidence.Add("backend_capability_manifest_capabilities=$backendCapabilityCount")
        [void]$evidence.Add("backend_capability_manifest_routes=$backendCapabilityRoutes")
        [void]$evidence.Add("backend_capability_manifest_helper_packages=$backendCapabilityHelpers")
        if ($backendCapabilityRoutes -ne $backendRouteArtifactCount) {
            Add-Failure $failures "backend capability manifest routes $backendCapabilityRoutes do not match backend route inventory $backendRouteArtifactCount"
        }
        if ($backendCapabilityCount -lt 30) {
            Add-Failure $failures "backend capability manifest capability count unexpectedly low: $backendCapabilityCount"
        }
        if ($backendCapabilityHelpers -ne 4) {
            Add-Failure $failures "backend capability manifest helper package count changed from expected 4 to $backendCapabilityHelpers"
        }
        Assert-Contains $failures $backendCapabilityManifestPath 'instead of being promoted by fallback' 'backend capability manifest no-fallback helper rule drift'
        foreach ($capability in @('ai/agent', 'payment/wallet', 'notification/task', 'auth', 'user')) {
            Assert-Contains $failures $backendCapabilityManifestPath "| ``$capability`` |" "backend capability manifest missing capability $capability"
        }
        foreach ($helper in @('auth/verifycode', 'payment/serialno', 'queuemonitor/asynqmonui')) {
            Assert-Contains $failures $backendCapabilityManifestPath "| ``$helper`` |" "backend capability manifest missing helper package $helper"
        }

        $adminFrontFilesScanned = Get-MarkdownSummaryCount $adminFrontSourceQualityPath 'Source files scanned'
        $adminFrontAnyCandidates = Get-MarkdownSummaryCount $adminFrontSourceQualityPath 'any candidates'
        $adminFrontAsAnyCandidates = Get-MarkdownSummaryCount $adminFrontSourceQualityPath 'as any candidates'
        $adminFrontCatchAnyCandidates = Get-MarkdownSummaryCount $adminFrontSourceQualityPath 'catch(error: any) candidates'
        $adminFrontFallbackCandidates = Get-MarkdownSummaryCount $adminFrontSourceQualityPath 'fallback candidates'
        $adminFrontDirectExternalCandidates = Get-MarkdownSummaryCount $adminFrontSourceQualityPath 'direct external HTTP candidates'
        [void]$evidence.Add("admin_front_source_quality_files_scanned=$adminFrontFilesScanned")
        [void]$evidence.Add("admin_front_source_quality_any_candidates=$adminFrontAnyCandidates")
        [void]$evidence.Add("admin_front_source_quality_as_any_candidates=$adminFrontAsAnyCandidates")
        [void]$evidence.Add("admin_front_source_quality_catch_any_candidates=$adminFrontCatchAnyCandidates")
        [void]$evidence.Add("admin_front_source_quality_fallback_candidates=$adminFrontFallbackCandidates")
        [void]$evidence.Add("admin_front_source_quality_direct_external_candidates=$adminFrontDirectExternalCandidates")
        if ($adminFrontFilesScanned -le 0) {
            Add-Failure $failures 'Admin front source quality inventory scanned no files'
        }
        if ($adminFrontAnyCandidates -ne 0) {
            Add-Failure $failures "Admin front source quality inventory any count changed from expected 0 to $adminFrontAnyCandidates"
        }
        if ($adminFrontAsAnyCandidates -ne 0) {
            Add-Failure $failures "Admin front source quality inventory as-any count changed from expected 0 to $adminFrontAsAnyCandidates"
        }
        if ($adminFrontCatchAnyCandidates -ne 0) {
            Add-Failure $failures "Admin front source quality inventory catch-any count changed from expected 0 to $adminFrontCatchAnyCandidates"
        }
        if ($adminFrontFallbackCandidates -le 0) {
            Add-Failure $failures 'Admin front source quality inventory unexpectedly has zero fallback candidates'
        }
        if ($adminFrontDirectExternalCandidates -ne 0) {
            Add-Failure $failures "Admin front source quality inventory direct external HTTP count changed from expected 0 to $adminFrontDirectExternalCandidates"
        }
        Assert-Contains $failures $knowledgePath 'Current counts are `280` source files scanned, `0` `any` candidates, `0` `as any` candidates, `0` `catch(error: any)` candidates, `542` fallback candidates, and `0` direct external HTTP candidates.' 'current runtime knowledge Admin front source-quality count drift'
        Assert-Contains $failures $sourceMapPath 'Current inventory facts: `280` Admin Vue source files scanned, `0` `any` candidates, `0` `as any` candidates, `0` `catch(error: any)` candidates, `542` fallback candidates, and `0` direct external HTTP candidates.' 'runtime source map Admin front source-quality count drift'
        Assert-Contains $failures $statusPath 'current inventory records 0 `any` candidates, 0 `as any` candidates, 0 `Record<string, any>` candidates, 0 `catch(...: any)` candidates, 542 fallback candidates, and 0 direct external HTTP candidates' 'status Admin front source-quality count drift'
        Assert-Contains $failures $adminFrontSourceQualityPath 'This is a regex source inventory, not type-aware semantic proof.' 'Admin front source quality inventory scope disclaimer drift'
        foreach ($priorityPath in @(
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
            'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue'
        )) {
            Assert-Contains $failures $adminFrontSourceQualityPath $priorityPath "Admin front source quality inventory missing priority file $priorityPath"
        }
        Assert-NotContains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/api/tools.ts' 'Admin front source quality inventory reintroduced retired random-image helper path'
        Assert-NotContains $failures $adminFrontSourceQualityPath 'api.btstu.cn' 'Admin front source quality inventory reintroduced retired external image host'
        if (Test-Path -LiteralPath 'admin_front_ts/src/api/tools.ts') {
            Add-Failure $failures 'Admin Vue still contains retired unused direct external helper src/api/tools.ts'
        }
        Assert-Contains $failures 'admin_front_ts/tests/shared/api/no-direct-external-helper.test.ts' 'api.btstu.cn' 'Admin direct external helper guard missing retired host check'
        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDirectExternalHelperReviewPath 'Admin direct external helper review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontDirectExternalHelperReviewPath 'current runtime knowledge Admin direct external helper review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDirectExternalHelperReviewPath 'runtime source map Admin direct external helper review drift'
        Assert-Contains $failures $statusPath $adminFrontDirectExternalHelperReviewPath 'status Admin direct external helper review drift'
        Assert-Contains $failures $adminFrontDirectExternalHelperReviewPath 'unused Admin Vue helper and has been deleted' 'Admin direct external helper review decision drift'
        Assert-Contains $failures $adminFrontDirectExternalHelperReviewPath 'direct external HTTP candidates = 0' 'Admin direct external helper review source-quality count drift'
        Assert-Contains $failures $adminFrontDirectExternalHelperReviewPath 'frontend API calls found = 274' 'Admin direct external helper review frontend inventory count drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as an unused dead helper deletion.' 'ADMIN-FRONT-HARDENING-003 resolved status drift'
        [void]$evidence.Add('admin_front_direct_external_helper=deleted')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontHeaderBreadcrumbReviewPath 'Admin Header breadcrumb review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontHeaderBreadcrumbReviewPath 'current runtime knowledge Admin Header breadcrumb review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontHeaderBreadcrumbReviewPath 'runtime source map Admin Header breadcrumb review drift'
        Assert-Contains $failures $statusPath $adminFrontHeaderBreadcrumbReviewPath 'status Admin Header breadcrumb review drift'
        Assert-Contains $failures $adminFrontHeaderBreadcrumbReviewPath 'breadcrumb route-walk debt has been closed' 'Admin Header breadcrumb review decision drift'
        Assert-Contains $failures $adminFrontHeaderBreadcrumbReviewPath 'Header/index.vue priority evidence = no regex finding in configured categories' 'Admin Header breadcrumb review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Layout/components/Header/index.vue' 'function findBreadcrumbPath(items: PermissionMenuItem[], target: string): PermissionMenuItem[] | null' 'Admin Header breadcrumb typed route walk missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Layout/components/Header/index.vue' 'if (matchedPath !== null) return matchedPath' 'Admin Header breadcrumb explicit missing-path branch drift'
        Assert-NotContains $failures 'admin_front_ts/src/views/Layout/components/Header/index.vue' 'any[]' 'Admin Header breadcrumb reintroduced any[]'
        Assert-NotContains $failures 'admin_front_ts/src/views/Layout/components/Header/index.vue' 'item: any' 'Admin Header breadcrumb label reintroduced item any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Layout/components/Header/index.vue' 'getPath(userStore.permissions, selectedIndex) || []' 'Admin Header breadcrumb reintroduced logical-or path fallback'
        Assert-Contains $failures 'admin_front_ts/tests/layout/header-source-quality.test.ts' 'does not hide breadcrumb path lookup failures behind logical-or fallback' 'Admin Header breadcrumb source guard missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a typed breadcrumb route-walk cleanup.' 'ADMIN-FRONT-HARDENING-004 resolved status drift'
        [void]$evidence.Add('admin_front_header_breadcrumb_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontForgotPasswordErrorReviewPath 'Admin forgot-password error review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontForgotPasswordErrorReviewPath 'current runtime knowledge Admin forgot-password error review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontForgotPasswordErrorReviewPath 'runtime source map Admin forgot-password error review drift'
        Assert-Contains $failures $statusPath $adminFrontForgotPasswordErrorReviewPath 'status Admin forgot-password error review drift'
        Assert-Contains $failures $adminFrontForgotPasswordErrorReviewPath 'request-error fallback debt has been closed' 'Admin forgot-password error review decision drift'
        Assert-Contains $failures $adminFrontForgotPasswordErrorReviewPath 'any candidates = 7' 'Admin forgot-password error review any count drift'
        Assert-Contains $failures $adminFrontForgotPasswordErrorReviewPath 'as any candidates = 0' 'Admin forgot-password error review as-any count drift'
        Assert-Contains $failures $adminFrontForgotPasswordErrorReviewPath 'fallback candidates = 562' 'Admin forgot-password error review fallback count drift'
        Assert-Contains $failures $adminFrontForgotPasswordErrorReviewPath 'useForgotPassword.ts no longer has catch-any or optional-chain error fallback rows' 'Admin forgot-password error review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Login/composables/useForgotPassword.ts' "function requireRequestErrorMessage(error: unknown, operation: 'send code' | 'reset'): string" 'Admin forgot-password request error helper missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Login/composables/useForgotPassword.ts' 'catch (error: unknown)' 'Admin forgot-password catch unknown missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Login/composables/useForgotPassword.ts' "requireRequestErrorMessage(error, 'send code')" 'Admin forgot-password send-code error helper call missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Login/composables/useForgotPassword.ts' "requireRequestErrorMessage(error, 'reset')" 'Admin forgot-password reset error helper call missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Login/composables/useForgotPassword.ts' 'catch (error: any)' 'Admin forgot-password reintroduced catch any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Login/composables/useForgotPassword.ts' 'error?.message ||' 'Admin forgot-password reintroduced optional-chain fallback message'
        Assert-Contains $failures 'admin_front_ts/tests/shared/user/forgot-password-source-quality.test.ts' 'does not replace an empty send-code request error with the generic send fallback' 'Admin forgot-password send-code source guard missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/user/forgot-password-source-quality.test.ts' 'does not replace an empty reset-password request error with the generic reset fallback' 'Admin forgot-password reset source guard missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a forgot-password request-error fail-closed cleanup.' 'ADMIN-FRONT-HARDENING-005 resolved status drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'now reports any candidates = 7, fallback candidates = 562 after the later upload demo cleanup' 'ADMIN-FRONT-HARDENING-005 known-issues inventory count drift'
        [void]$evidence.Add('admin_front_forgot_password_request_error_fail_closed=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontJsonEditorReviewPath 'Admin JsonEditor review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontJsonEditorReviewPath 'current runtime knowledge Admin JsonEditor review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontJsonEditorReviewPath 'runtime source map Admin JsonEditor review drift'
        Assert-Contains $failures $statusPath $adminFrontJsonEditorReviewPath 'status Admin JsonEditor review drift'
        Assert-Contains $failures $adminFrontJsonEditorReviewPath 'JsonEditor parse-error fallback debt has been closed' 'Admin JsonEditor review decision drift'
        Assert-Contains $failures $adminFrontJsonEditorReviewPath 'any candidates = 7' 'Admin JsonEditor review any count drift'
        Assert-Contains $failures $adminFrontJsonEditorReviewPath 'as any candidates = 0' 'Admin JsonEditor review as-any count drift'
        Assert-Contains $failures $adminFrontJsonEditorReviewPath 'catch(error: any) candidates = 0' 'Admin JsonEditor review catch-any count drift'
        Assert-Contains $failures $adminFrontJsonEditorReviewPath 'fallback candidates = 562' 'Admin JsonEditor review fallback count drift'
        Assert-Contains $failures $adminFrontJsonEditorReviewPath 'JsonEditor/src/index.vue priority evidence = no regex finding in configured categories' 'Admin JsonEditor review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/json.ts' 'export function parseJsonEditorValue(value: string): unknown' 'Admin JsonEditor parse helper missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/json.ts' 'export function formatJsonEditorValue(value: string): string' 'Admin JsonEditor format helper missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/json.ts' 'export function requireJsonParseErrorMessage(error: unknown): string' 'Admin JsonEditor error helper missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'catch (error: unknown)' 'Admin JsonEditor catch unknown missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'requireJsonParseErrorMessage(error)' 'Admin JsonEditor error helper call missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'parseJsonEditorValue(modelValue.value)' 'Admin JsonEditor parse helper call missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'formatJsonEditorValue(modelValue.value)' 'Admin JsonEditor format helper call missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' "t('jsonEditor.invalidJson'" 'Admin JsonEditor invalidJson i18n key missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' "t('jsonEditor.formatted')" 'Admin JsonEditor formatted i18n key missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' "t('jsonEditor.format')" 'Admin JsonEditor format button i18n key missing'
        Assert-Contains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' "t('jsonEditor.validate')" 'Admin JsonEditor validate button i18n key missing'
        Assert-NotContains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'catch (e: any)' 'Admin JsonEditor reintroduced catch any'
        Assert-NotContains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'e?.message ||' 'Admin JsonEditor reintroduced optional-chain fallback message'
        Assert-NotContains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' "modelValue.value || '{}'" 'Admin JsonEditor reintroduced implicit empty-object fallback'
        Assert-NotContains $failures 'admin_front_ts/src/components/JsonEditor/src/index.vue' 'JSON 格式错误' 'Admin JsonEditor reintroduced raw Chinese error text'
        Assert-Contains $failures 'admin_front_ts/src/i18n/locales/zh-CN.ts' 'jsonEditor:' 'Admin zh-CN JsonEditor i18n keys missing'
        Assert-Contains $failures 'admin_front_ts/src/i18n/locales/en-US.ts' 'jsonEditor:' 'Admin en-US JsonEditor i18n keys missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts' 'preserves the empty editor compatibility rule as an explicit empty object parse' 'Admin JsonEditor empty compatibility guard missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts' 'rejects malformed parse error reasons instead of hiding them behind empty text' 'Admin JsonEditor error message guard missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts' 'src/components/JsonEditor/src/index.vue' 'Admin JsonEditor visible Chinese guard coverage missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a JsonEditor parse-error and touched-i18n cleanup.' 'ADMIN-FRONT-HARDENING-006 resolved status drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'now reports any candidates = 7, as any candidates = 0, catch(error: any) candidates = 0, fallback candidates = 562 after the later upload demo cleanup' 'ADMIN-FRONT-HARDENING-006 known-issues inventory count drift'
        [void]$evidence.Add('admin_front_json_editor_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDIconReviewPath 'Admin DIcon review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontDIconReviewPath 'current runtime knowledge Admin DIcon review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDIconReviewPath 'runtime source map Admin DIcon review drift'
        Assert-Contains $failures $statusPath $adminFrontDIconReviewPath 'status Admin DIcon review drift'
        Assert-Contains $failures $adminFrontDIconReviewPath 'DIcon Element Plus dynamic-module as-any debt has been closed' 'Admin DIcon review decision drift'
        Assert-Contains $failures $adminFrontDIconReviewPath 'any candidates = 7' 'Admin DIcon review any count drift'
        Assert-Contains $failures $adminFrontDIconReviewPath 'as any candidates = 0' 'Admin DIcon review as-any count drift'
        Assert-Contains $failures $adminFrontDIconReviewPath 'DIcon/src/index.vue priority evidence = explicit missing-icon/null-state fallback rows only; no any/as-any row remains' 'Admin DIcon review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' "type ElementPlusIconsModule = typeof import('@element-plus/icons-vue')" 'Admin DIcon typed Element Plus module missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' 'type ElementPlusIconName = keyof ElementPlusIconsModule' 'Admin DIcon Element Plus icon name type missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' 'function hasElementPlusIcon(' 'Admin DIcon key guard missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' 'name is ElementPlusIconName' 'Admin DIcon key guard predicate missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' 'hasElementPlusIcon(mod, name) ? mod[name] : undefined' 'Admin DIcon guarded module lookup missing'
        Assert-NotContains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' '(mod as any)' 'Admin DIcon reintroduced module as any'
        Assert-NotContains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' 'as unknown as Promise<Record<string, Component>>' 'Admin DIcon reintroduced unknown Record module cast'
        Assert-NotContains $failures 'admin_front_ts/src/components/DIcon/src/index.vue' 'Record<string, Component>' 'Admin DIcon reintroduced broad Record module type'
        Assert-Contains $failures 'admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts' 'does not index the Element Plus icon module through any' 'Admin DIcon source guard missing any rejection'
        Assert-Contains $failures 'admin_front_ts/tests/shared/icon/dicon-source-quality.test.ts' 'narrows runtime icon names through an explicit module key guard' 'Admin DIcon source guard missing key guard assertion'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a DIcon Element Plus dynamic-module typing cleanup.' 'ADMIN-FRONT-HARDENING-007 resolved status drift'
        [void]$evidence.Add('admin_front_dicon_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontEditorReviewPath 'Admin Editor review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontEditorReviewPath 'current runtime knowledge Admin Editor review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontEditorReviewPath 'runtime source map Admin Editor review drift'
        Assert-Contains $failures $statusPath $adminFrontEditorReviewPath 'status Admin Editor review drift'
        Assert-Contains $failures $adminFrontEditorReviewPath 'wangEditor wrapper `any/as any` and upload URL fallback debt' 'Admin Editor review decision drift'
        Assert-Contains $failures $adminFrontEditorReviewPath 'any candidates = 7' 'Admin Editor review any count drift'
        Assert-Contains $failures $adminFrontEditorReviewPath 'as any candidates = 0' 'Admin Editor review as-any count drift'
        Assert-Contains $failures $adminFrontEditorReviewPath 'fallback candidates = 562' 'Admin Editor review fallback count drift'
        Assert-Contains $failures $adminFrontEditorReviewPath 'Editor.vue priority evidence = no regex finding in configured categories' 'Admin Editor review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' "import { Boot, type IDomEditor, type IEditorConfig, type IModuleConf } from '@wangeditor/editor'" 'Admin Editor wangEditor typed import missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'const editorRef = shallowRef<IDomEditor | null>(null)' 'Admin Editor typed editorRef missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'const cfg = computed<AdminEditorConfig>' 'Admin Editor typed config computed missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'type ImageInsertFn = (src: string, alt: string, href: string) => void' 'Admin Editor image insert type missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'type VideoInsertFn = (src: string, poster: string) => void' 'Admin Editor video insert type missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'Boot.registerModule(markdownModule.default)' 'Admin Editor typed markdown module registration missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'requireUploadURL(result.url)' 'Admin Editor upload URL requirement missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' '(editorModule as any)' 'Admin Editor reintroduced module as any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/display/components/Editor.vue' 'result.url ||' 'Admin Editor reintroduced upload URL fallback'
        Assert-Contains $failures 'admin_front_ts/tests/shared/editor/editor-source-quality.test.ts' 'does not use any/as-any at the editor boundary' 'Admin Editor source guard missing any/as-any rejection'
        Assert-Contains $failures 'admin_front_ts/tests/shared/editor/editor-source-quality.test.ts' 'types custom upload insert functions and rejects empty uploaded URLs' 'Admin Editor source guard missing upload URL assertion'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a wangEditor wrapper typing and upload URL fail-closed cleanup.' 'ADMIN-FRONT-HARDENING-008 resolved status drift'
        [void]$evidence.Add('admin_front_editor_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDownloadManagerReviewPath 'Admin DownloadManager review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontDownloadManagerReviewPath 'current runtime knowledge Admin DownloadManager review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDownloadManagerReviewPath 'runtime source map Admin DownloadManager review drift'
        Assert-Contains $failures $statusPath $adminFrontDownloadManagerReviewPath 'status Admin DownloadManager review drift'
        Assert-Contains $failures $adminFrontDownloadManagerReviewPath 'DownloadManager `download.ts` catch-any, failed-download silent direct-open fallback, and same-file filename logical-or fallback debt' 'Admin DownloadManager review decision drift'
        Assert-Contains $failures $adminFrontDownloadManagerReviewPath 'any candidates = 7' 'Admin DownloadManager review any count drift'
        Assert-Contains $failures $adminFrontDownloadManagerReviewPath 'catch(error: any) candidates = 0' 'Admin DownloadManager review catch-any count drift'
        Assert-Contains $failures $adminFrontDownloadManagerReviewPath 'DownloadManager/download.ts priority evidence = no regex finding in configured categories' 'Admin DownloadManager review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' "import { isDownloadUserCancelled, requireDownloadError } from './errors'" 'Admin DownloadManager error helper import missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' "isDownloadUserCancelled(error, t('download.userCancelled'))" 'Admin DownloadManager user-cancel guard missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' "requireDownloadError(error, 'download')" 'Admin DownloadManager tauri error requirement missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' "requireDownloadError(error, 'web download')" 'Admin DownloadManager web error requirement missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'const DEFAULT_DOWNLOAD_FILENAME = ' 'Admin DownloadManager default filename constant missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'function resolveSuggestedDownloadFilename(url: string, filename?: string): string' 'Admin DownloadManager suggested filename helper missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'function resolveSavePathFilename(savePath: string, suggestedFilename: string): string' 'Admin DownloadManager save path filename helper missing'
        Assert-NotContains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' "options.url.split('/').pop()?.split('?')[0] || 'download'" 'Admin DownloadManager reintroduced URL filename fallback chain'
        Assert-NotContains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'options.filename || urlFilename' 'Admin DownloadManager reintroduced suggested filename fallback chain'
        Assert-NotContains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'savePath.split(/[/\\]/).pop() || suggestedFilename' 'Admin DownloadManager reintroduced save path filename fallback chain'
        Assert-NotContains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' "filename || url.split('/').pop()?.split('?')[0] || 'download'" 'Admin DownloadManager reintroduced web filename fallback chain'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/errors.ts' 'export function isDownloadUserCancelled(error: unknown, cancelMessage: string): boolean' 'Admin DownloadManager user-cancel helper missing'
        Assert-Contains $failures 'admin_front_ts/src/components/DownloadManager/src/errors.ts' 'export function requireDownloadError(error: unknown, operation: string): Error' 'Admin DownloadManager require error helper missing'
        Assert-NotContains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'catch (error: any)' 'Admin DownloadManager reintroduced catch error any'
        Assert-NotContains $failures 'admin_front_ts/src/components/DownloadManager/src/download.ts' 'catch (err: any)' 'Admin DownloadManager reintroduced catch err any'
        Assert-Contains $failures 'admin_front_ts/tests/shared/download-manager/download-manager-source-quality.test.ts' 'throws Web fetch failures instead of hiding them behind direct-open fallback' 'Admin DownloadManager source guard missing web fallback assertion'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a DownloadManager catch-any and failed-download fallback cleanup.' 'ADMIN-FRONT-HARDENING-009 resolved status drift'
        [void]$evidence.Add('admin_front_download_manager_source_quality=covered')

        Assert-Contains $failures 'admin_front_ts/tests/shared/download-manager/download-demo-source-quality.test.ts' 'does not teach or use catch-any download error handling' 'Admin download demo source guard missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/download/index.vue' 'function requireDownloadDemoErrorMessage(error: unknown): string' 'Admin download demo error helper missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/download/index.vue' 'function optionalDownloadFilename(filename: string): string | undefined' 'Admin download demo filename helper missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/download/index.vue' 'catch (error: unknown)' 'Admin download demo catch unknown missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/download/index.vue' 'ElMessage.error(requireDownloadDemoErrorMessage(error))' 'Admin download demo error message requirement missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/download/index.vue' 'catch (error: any)' 'Admin download demo reintroduced catch any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/download/index.vue' "error.message || '下载失败'" 'Admin download demo reintroduced fallback error message'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/views/Main/component/download/index.vue` | no regex finding in configured categories' 'Admin download demo inventory evidence drift'
        [void]$evidence.Add('admin_front_download_demo_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontDevTestDownloadReviewPath 'Admin dev test download review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontDevTestDownloadReviewPath 'current runtime knowledge Admin dev test download review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontDevTestDownloadReviewPath 'runtime source map Admin dev test download review drift'
        Assert-Contains $failures $statusPath $adminFrontDevTestDownloadReviewPath 'status Admin dev test download review drift'
        Assert-Contains $failures $adminFrontDevTestDownloadReviewPath 'Dev test download priority evidence = no catch-any/error fallback/filename || undefined rows remain' 'Admin dev test download review inventory evidence drift'
        Assert-Contains $failures $adminFrontDevTestDownloadReviewPath 'catch(error: any) candidates = 0' 'Admin dev test download review catch-any count drift'
        Assert-Contains $failures $adminFrontDevTestDownloadReviewPath 'fallback candidates = 562' 'Admin dev test download review fallback count drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/download-manager/dev-test-download-source-quality.test.ts' 'does not hide download errors behind any or fallback messages' 'Admin dev test download source guard missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/test/index.vue' 'function requireDevTestDownloadErrorMessage(error: unknown): string' 'Admin dev test download error helper missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/test/index.vue' 'function optionalDownloadFilename(filename: string): string | undefined' 'Admin dev test download filename helper missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/test/index.vue' 'catch (error: unknown)' 'Admin dev test download catch unknown missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/test/index.vue' 'requireDevTestDownloadErrorMessage(error)' 'Admin dev test download error helper call missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/test/index.vue' 'catch (error: any)' 'Admin dev test download reintroduced catch any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/test/index.vue' "error.message || t('devTest.downloadFailed'" 'Admin dev test download reintroduced fallback error message'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/test/index.vue' 'testFilename.value || undefined' 'Admin dev test download reintroduced filename fallback'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/views/Main/test/index.vue` | no regex finding in configured categories' 'Admin dev test download inventory evidence drift'
        [void]$evidence.Add('admin_front_dev_test_download_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontValidatorReviewPath 'Admin validator review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontValidatorReviewPath 'current runtime knowledge Admin validator review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontValidatorReviewPath 'runtime source map Admin validator review drift'
        Assert-Contains $failures $statusPath $adminFrontValidatorReviewPath 'status Admin validator review drift'
        Assert-Contains $failures $adminFrontValidatorReviewPath 'Admin `useValidator` validator input typing and message fallback debt is closed.' 'Admin validator review decision drift'
        Assert-Contains $failures $adminFrontValidatorReviewPath 'any candidates = 7' 'Admin validator review any count drift'
        Assert-Contains $failures $adminFrontValidatorReviewPath 'fallback candidates = 562' 'Admin validator review fallback count drift'
        Assert-Contains $failures $adminFrontValidatorReviewPath 'useValidator.ts priority evidence = no any/message fallback rows; only validation predicate logical-or remains' 'Admin validator review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/hooks/web/useValidator.ts' 'type ValidatorValue = string' 'Admin validator value type missing'
        Assert-Contains $failures 'admin_front_ts/src/hooks/web/useValidator.ts' 'function resolveValidatorMessage(message: string | undefined, fallback: string): string' 'Admin validator message resolver missing'
        Assert-Contains $failures 'admin_front_ts/src/hooks/web/useValidator.ts' 'const lengthRange = (val: ValidatorValue, callback: Callback, options: LengthRange) => {' 'Admin validator lengthRange typed input missing'
        Assert-Contains $failures 'admin_front_ts/src/hooks/web/useValidator.ts' 'resolveValidatorMessage(message, t(' 'Admin validator resolver call missing'
        Assert-NotContains $failures 'admin_front_ts/src/hooks/web/useValidator.ts' 'val: any' 'Admin validator reintroduced val any'
        Assert-NotContains $failures 'admin_front_ts/src/hooks/web/useValidator.ts' 'message ||' 'Admin validator reintroduced message fallback'
        Assert-Contains $failures 'admin_front_ts/tests/shared/validator/use-validator-source-quality.test.ts' 'does not hide validator types or messages behind any and logical-or fallbacks' 'Admin validator source guard missing'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a validator input typing and message fallback cleanup.' 'ADMIN-FRONT-HARDENING-011 resolved status drift'
        [void]$evidence.Add('admin_front_validator_source_quality=covered')

        Assert-Contains $failures 'docs/knowledge/README.md' $adminFrontUploadDemoReviewPath 'Admin upload demo review knowledge index drift'
        Assert-Contains $failures $knowledgePath $adminFrontUploadDemoReviewPath 'current runtime knowledge Admin upload demo review drift'
        Assert-Contains $failures $sourceMapPath $adminFrontUploadDemoReviewPath 'runtime source map Admin upload demo review drift'
        Assert-Contains $failures $statusPath $adminFrontUploadDemoReviewPath 'status Admin upload demo review drift'
        Assert-Contains $failures $adminFrontUploadDemoReviewPath 'Admin upload demo `imgList` typing debt is closed.' 'Admin upload demo review decision drift'
        Assert-Contains $failures $adminFrontUploadDemoReviewPath 'source files scanned = 280' 'Admin upload demo review file count drift'
        Assert-Contains $failures $adminFrontUploadDemoReviewPath 'any candidates = 7' 'Admin upload demo review any count drift'
        Assert-Contains $failures $adminFrontUploadDemoReviewPath 'fallback candidates = 562' 'Admin upload demo review fallback count drift'
        Assert-Contains $failures $adminFrontUploadDemoReviewPath 'Upload demo priority evidence = upload/index.vue has no configured source-quality finding; UpMediaList fallback rows remain outside this slice' 'Admin upload demo review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/upload/index.vue' "import type { UploadMediaItem } from './components/media'" 'Admin upload demo media item type import missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/upload/index.vue' 'const imgList = ref<UploadMediaItem[]>([])' 'Admin upload demo typed media list missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/upload/index.vue' 'ref<any[]>' 'Admin upload demo reintroduced any array ref'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue' "import type { UploadMediaItem } from './media'" 'Admin UpMediaList media item type import missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue' 'modelValue?: UploadMediaItem[]' 'Admin UpMediaList typed modelValue missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue' "'update:modelValue': [value: UploadMediaItem[]]" 'Admin UpMediaList typed emit missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/upload/components/UpMediaList.vue' 'interface MediaItem' 'Admin UpMediaList reintroduced local duplicate MediaItem'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/upload/components/media.ts' 'export interface UploadMediaItem' 'Admin upload media item type missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/upload/upload-demo-source-quality.test.ts' 'does not hide UpMediaList model shape behind any array refs' 'Admin upload demo source guard missing'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/views/Main/component/upload/index.vue` | no regex finding in configured categories' 'Admin upload demo inventory evidence drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as an upload demo media-list typing cleanup.' 'ADMIN-FRONT-HARDENING-012 resolved status drift'
        [void]$evidence.Add('admin_front_upload_demo_source_quality=covered')



        Assert-Contains $failures 'docs/knowledge/README.md' 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'Admin demo any review knowledge index drift'
        Assert-Contains $failures $knowledgePath 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'current runtime knowledge Admin demo any review drift'
        Assert-Contains $failures $sourceMapPath 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'runtime source map Admin demo any review drift'
        Assert-Contains $failures $statusPath 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'status Admin demo any review drift'
        Assert-Contains $failures 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'any candidates = 0' 'Admin demo any review any count drift'
        Assert-Contains $failures 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'fallback candidates = 555' 'Admin demo any review fallback count drift'
        Assert-Contains $failures 'docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md' 'Demo any priority evidence = form/index.vue and display/index.vue have no configured source-quality finding; ParticleBackground has only the pointer null-state logical-or guard' 'Admin demo any review inventory evidence drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/form/form-demo-source-quality.test.ts' 'does not hide demo form, icon ref, or remote params behind any' 'Admin form demo source guard missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/display/display-demo-source-quality.test.ts' 'does not document passthrough table column props as any' 'Admin display demo source guard missing'
        Assert-Contains $failures 'admin_front_ts/tests/shared/effect/particle-background-source-quality.test.ts' 'does not hide particle and pointer state behind any or logical-or fallbacks' 'Admin ParticleBackground source guard missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' "import type { SearchFormModel } from '@/components/Search/types'" 'Admin form demo SearchFormModel import missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' 'const iconSelectRef = ref<IconSelectExpose | null>(null)' 'Admin form demo typed icon ref missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' 'const mockFetch: RemoteListFetchMethod<MockRemoteSelectOption, MockRemoteSelectParams> = async (params) => {' 'Admin form demo typed mock fetch missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' '(form: any)' 'Admin form demo reintroduced form any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' 'ref<any>' 'Admin form demo reintroduced ref any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' '(params: any)' 'Admin form demo reintroduced params any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/form/index.vue' "type: 'any'" 'Admin form demo reintroduced documented any'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/display/index.vue' "type: 'Record<string, unknown>'" 'Admin display demo passthrough type drift'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/display/index.vue' "type: 'any'" 'Admin display demo reintroduced documented any'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'interface Particle {' 'Admin ParticleBackground Particle type missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'interface PointerPosition {' 'Admin ParticleBackground PointerPosition type missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'let particles: Particle[] = []' 'Admin ParticleBackground particles type drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'let mouse: PointerPosition = { x: null, y: null }' 'Admin ParticleBackground pointer type drift'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'function requireParticleContext(): CanvasRenderingContext2D' 'Admin ParticleBackground context invariant missing'
        Assert-Contains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'function positiveDistance(distance: number): number' 'Admin ParticleBackground distance invariant missing'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'particles: any[]' 'Admin ParticleBackground reintroduced particles any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'mouse: any' 'Admin ParticleBackground reintroduced mouse any'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'window.devicePixelRatio || 1' 'Admin ParticleBackground reintroduced DPR fallback'
        Assert-NotContains $failures 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue' 'Math.sqrt(dx*dx + dy*dy) || 1' 'Admin ParticleBackground reintroduced distance fallback'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/views/Main/component/form/index.vue` | no regex finding in configured categories' 'Admin form demo inventory evidence drift'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/views/Main/component/display/index.vue` | no regex finding in configured categories' 'Admin display demo inventory evidence drift'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/views/Main/component/effect/components/ParticleBackground.vue` | L102 `logical-or-fallback`' 'Admin ParticleBackground inventory evidence drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as a form/display/ParticleBackground demo any cleanup.' 'ADMIN-FRONT-HARDENING-013 resolved status drift'
        [void]$evidence.Add('admin_front_demo_any_source_quality=covered')


        Assert-Contains $failures 'docs/knowledge/README.md' 'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md' 'Admin AI image payload review knowledge index drift'
        Assert-Contains $failures $knowledgePath 'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md' 'current runtime knowledge Admin AI image payload review drift'
        Assert-Contains $failures $sourceMapPath 'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md' 'runtime source map Admin AI image payload review drift'
        Assert-Contains $failures $statusPath 'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md' 'status Admin AI image payload review drift'
        Assert-Contains $failures 'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md' 'fallback candidates = 542' 'Admin AI image payload review fallback count drift'
        Assert-Contains $failures 'docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md' 'optionalImageEnum(...) treats only `undefined` and explicit empty string' 'Admin AI image payload review enum decision drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/ai/ai-image-api.test.ts' 'normalizes optional create-task payload fields without logical-or fallbacks' 'Admin AI image payload source guard missing'
        Assert-Contains $failures 'admin_front_ts/src/api/ai/images.ts' 'function optionalImageEnum<T extends string>(value: T |' 'Admin AI image optional enum helper missing'
        Assert-Contains $failures 'admin_front_ts/src/api/ai/images.ts' 'size: optionalImageEnum(payload.size),' 'Admin AI image size normalization drift'
        Assert-Contains $failures 'admin_front_ts/src/api/ai/images.ts' 'input_files: payload.input_files,' 'Admin AI image input file payload drift'
        Assert-Contains $failures 'admin_front_ts/src/api/ai/images.ts' 'mask_file: payload.mask_file,' 'Admin AI image mask file payload drift'
        Assert-Contains $failures 'admin_front_ts/tests/shared/ai/ai-image-complete-split.test.ts' 'does not revive the old global ai_images asset contract' 'Admin AI image complete split source guard missing'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' '/ai-images/assets' 'Admin AI image asset registration route reintroduced'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'input_asset_ids' 'Admin AI image input asset IDs reintroduced'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'mask_asset_id' 'Admin AI image mask asset ID reintroduced'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'mask_target_asset_id' 'Admin AI image mask target asset ID reintroduced'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'payload.size || undefined' 'Admin AI image reintroduced size fallback'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'payload.quality || undefined' 'Admin AI image reintroduced quality fallback'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'payload.output_format || undefined' 'Admin AI image reintroduced output format fallback'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'payload.moderation || undefined' 'Admin AI image reintroduced moderation fallback'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'if (payload.mask_asset_id)' 'Admin AI image reintroduced truthy mask ID guard'
        Assert-NotContains $failures 'admin_front_ts/src/api/ai/images.ts' 'if (payload.mask_target_asset_id)' 'Admin AI image reintroduced truthy mask target ID guard'
        Assert-Contains $failures $adminFrontSourceQualityPath 'admin_front_ts/src/api/ai/images.ts` | L130 `logical-or-fallback`' 'Admin AI image inventory evidence drift'
        Assert-Contains $failures 'docs/status/known-issues.md' 'Status: resolved on 2026-06-07 as an AI image create-task optional payload fallback cleanup.' 'ADMIN-FRONT-HARDENING-014 resolved status drift'
        [void]$evidence.Add('admin_front_ai_image_payload_source_quality=covered')

        if ($LiveSchema) {
            $checkDir = '.tmp/runtime-doc-facts'
            & powershell -ExecutionPolicy Bypass -File '.\scripts\export-live-mysql-schema.ps1' -OutputDate 'runtime-doc-facts' -OutputDir $checkDir | ForEach-Object {
                [void]$evidence.Add("live-schema-export: $_")
            }
            if ($LASTEXITCODE -ne 0) {
                Add-Failure $failures 'live schema export failed'
            } else {
                $liveCount = Get-SchemaBaseTableCount (Join-Path $checkDir 'mysql-live-schema-runtime-doc-facts.md')
                if ($liveCount -ne $schemaCount) {
                    Add-Failure $failures "live schema table count $liveCount does not match tracked snapshot $schemaCount"
                }
                [void]$evidence.Add("live_schema_base_tables=$liveCount")
            }
            $mysqlConfig = Parse-MySQLDsn (Read-DotEnvValue -Path 'admin_back_go/.env' -Key 'MYSQL_DSN')
            $canvasTextRows = @(
                Invoke-LiveMySQLQuery -Config $mysqlConfig -Sql "SELECT parent_id, type, status, is_del FROM permissions WHERE platform='canvas' AND code='canvas_ai_text_generate' ORDER BY id DESC LIMIT 1;"
            )
            if ($canvasTextRows.Count -eq 0) {
                [void]$evidence.Add('live_canvas_ai_text_generate=absent')
            } else {
                $parts = [string]$canvasTextRows[0] -split "`t"
                if ($parts.Count -lt 4) {
                    Add-Failure $failures "live canvas_ai_text_generate permission row has unexpected shape: $($canvasTextRows[0])"
                } else {
                    [void]$evidence.Add("live_canvas_ai_text_generate=parent_id:$($parts[0]),type:$($parts[1]),status:$($parts[2]),is_del:$($parts[3])")
                    if ($parts[0] -ne '0' -or $parts[1] -ne '3' -or $parts[2] -ne '2' -or $parts[3] -ne '1') {
                        Add-Failure $failures "live canvas_ai_text_generate must be a soft-deleted orphan BUTTON row, got parent_id=$($parts[0]) type=$($parts[1]) status=$($parts[2]) is_del=$($parts[3])"
                    }
                }
            }
            $canvasAssetRows = @(
                Invoke-LiveMySQLQuery -Config $mysqlConfig -Sql "SELECT code, path, component, type, status, is_del, show_menu FROM permissions WHERE platform='canvas' AND (path IN ('/assets','/asset-library') OR code='canvas_assets_page') ORDER BY code, path;"
            )
            $activeAssetsPage = $false
            foreach ($row in $canvasAssetRows) {
                $parts = [string]$row -split "`t"
                if ($parts.Count -lt 7) {
                    Add-Failure $failures "live Canvas asset route row has unexpected shape: $row"
                    continue
                }
                [void]$evidence.Add("live_canvas_asset_route=code:$($parts[0]),path:$($parts[1]),component:$($parts[2]),type:$($parts[3]),status:$($parts[4]),is_del:$($parts[5]),show_menu:$($parts[6])")
                if ($parts[1] -eq '/asset-library' -and $parts[4] -eq '1' -and $parts[5] -eq '2') {
                    Add-Failure $failures 'live MySQL must not contain an active Canvas /asset-library PAGE row'
                }
                if ($parts[0] -eq 'canvas_assets_page' -and $parts[1] -eq '/assets' -and $parts[2] -eq 'assets' -and $parts[3] -eq '2' -and $parts[4] -eq '1' -and $parts[5] -eq '2') {
                    $activeAssetsPage = $true
                }
            }
            if (-not $activeAssetsPage) {
                Add-Failure $failures 'live MySQL missing active Canvas canvas_assets_page at /assets'
            }
        }
    }

    if ($failures.Count -eq 0) {
        [void]$verification.Add('runtime documentation facts match current manifests, source routes, and tracked schema snapshot')

        if ($LiveSchema) {
            [void]$verification.Add('live MySQL schema table count matches tracked schema snapshot')
            [void]$verification.Add('live MySQL canvas_ai_text_generate permission row is absent or soft-deleted orphan')
            [void]$verification.Add('live MySQL Canvas asset route is /assets and not active /asset-library')
        }
    }

    Write-Section 'Outcome'
    if ($failures.Count -gt 0) {
        Write-Host "BLOCKED: $($failures.Count) runtime doc fact drift issue(s) found."
    } else {
        Write-Host 'PASS: runtime doc facts are in sync.'
    }

    Write-Section 'Key evidence'
    foreach ($item in $evidence) { Write-Host "- $item" }

    Write-Section 'Verification'
    foreach ($item in $verification) { Write-Host "- $item" }

    Write-Section 'Known risks'
    Write-Host '- non-live mode checks tracked schema artifacts, not DB connectivity'
    Write-Host '- package version checks prove manifest/doc sync, not build success'
    if (-not $LiveSchema) { Write-Host '- rerun with -LiveSchema to compare against the current MySQL instance' }

    if ($failures.Count -gt 0) {
        Write-Section 'Failures'
        foreach ($item in $failures) { Write-Host "- $item" }
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
