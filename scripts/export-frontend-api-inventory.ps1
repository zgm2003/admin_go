param(
    [string]$OutputDate = (Get-Date).ToString('yyyy-MM-dd'),
    [string]$OutputDir = 'docs/knowledge'
)

$ErrorActionPreference = 'Stop'

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

function Get-SourceFiles {
    $roots = @(
        'admin_front_ts/src/api',
        'admin_front_ts/src/lib',
        'admin_front_ts/src/hooks',
        'admin_front_ts/src/views',
        'admin_front_ts/src/components',
        'canvas_front_next/src/services',
        'canvas_front_next/src/app',
        'canvas_front_next/src/features',
        'canvas_front_next/src/stores',
        'canvas_front_next/src/hooks'
    )

    $seen = @{}
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName)) {
            if ($file.Extension -notin @('.ts', '.tsx', '.vue')) { continue }
            if ($file.Name -match '\.test\.') { continue }
            if ($file.Name -like '*.d.ts') { continue }
            if (-not $seen.ContainsKey($file.FullName)) {
                $seen[$file.FullName] = $true
                $file.FullName
            }
        }
    }
}

function Get-TypeScriptModulePath {
    foreach ($candidate in @(
        'admin_front_ts/node_modules/typescript/lib/typescript.js',
        'canvas_front_next/node_modules/typescript/lib/typescript.js'
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'typescript module not found under admin_front_ts or canvas_front_next node_modules'
}

$nodeParser = @'
const fs = require("fs");
const path = require("path");

const input = JSON.parse(fs.readFileSync(0, "utf8"));
const ts = require(input.tsModulePath);
const repoRoot = input.repoRoot;

function toUnixPath(value) {
  return value.split(path.sep).join("/");
}

function relPath(file) {
  return toUnixPath(path.relative(repoRoot, file));
}

function sourceForParse(file) {
  const text = fs.readFileSync(file, "utf8");
  if (!file.endsWith(".vue")) return text;
  const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let output = "";
  let cursor = 0;
  let matched = false;
  for (const match of text.matchAll(scriptRegex)) {
    matched = true;
    const before = text.slice(cursor, match.index);
    const newlines = before.match(/\r\n|\r|\n/g);
    output += "\n".repeat(newlines ? newlines.length : 0);
    output += match[1];
    cursor = match.index + match[0].length;
  }
  return matched ? output : "";
}

function scriptKindFor(file) {
  if (file.endsWith(".tsx")) return ts.ScriptKind.TSX;
  return ts.ScriptKind.TS;
}

function propertyNameText(name) {
  if (!name) return "";
  if (ts.isIdentifier(name) || ts.isStringLiteral(name) || ts.isNumericLiteral(name)) return name.text;
  return "";
}

function objectPropertyExpression(objectNode, name) {
  if (!objectNode || !ts.isObjectLiteralExpression(objectNode)) return null;
  for (const prop of objectNode.properties) {
    if (!ts.isPropertyAssignment(prop)) continue;
    if (propertyNameText(prop.name) === name) return prop.initializer;
  }
  return null;
}

function evaluateExpression(node, constants, dynamicToken = false) {
  if (!node) return null;
  if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
  if (ts.isIdentifier(node)) return constants.get(node.text) ?? null;
  if (ts.isParenthesizedExpression(node)) return evaluateExpression(node.expression, constants, dynamicToken);
  if (ts.isAsExpression(node) || ts.isTypeAssertionExpression(node) || (ts.isSatisfiesExpression && ts.isSatisfiesExpression(node))) {
    return evaluateExpression(node.expression, constants, dynamicToken);
  }
  if (ts.isTemplateExpression(node)) {
    let value = node.head.text;
    for (const span of node.templateSpans) {
      const exprValue = evaluateExpression(span.expression, constants, dynamicToken);
      if (exprValue === null && !dynamicToken) return null;
      value += exprValue ?? ":param";
      value += span.literal.text;
    }
    return value;
  }
  if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const left = evaluateExpression(node.left, constants, dynamicToken);
    const right = evaluateExpression(node.right, constants, dynamicToken);
    if (left === null || right === null) return null;
    return left + right;
  }
  return null;
}

function normalizeKnownApiPath(value) {
  if (!value) return "";
  for (const prefix of ["/api/admin/v1", "/api/canvas/v1", "/api/app/v1"]) {
    const index = value.indexOf(prefix);
    if (index >= 0) return value.slice(index);
  }
  return value;
}

function collectConstants(sourceFile) {
  const constants = new Map([
    ["ADMIN_API_PREFIX", "/api/admin/v1"],
    ["ADMIN_AUTH_REFRESH_PATH", "/api/admin/v1/auth/refresh"],
    ["ADMIN_QUEUE_MONITOR_UI_PATH", "/api/admin/v1/queue-monitor-ui"],
  ]);
  const declarations = [];

  function visit(node) {
    if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && node.initializer) {
      declarations.push({ name: node.name.text, initializer: node.initializer });
    }
    ts.forEachChild(node, visit);
  }

  visit(sourceFile);
  for (let pass = 0; pass < 6; pass += 1) {
    let changed = false;
    for (const declaration of declarations) {
      const value = evaluateExpression(declaration.initializer, constants, true);
      if (value !== null && constants.get(declaration.name) !== value) {
        constants.set(declaration.name, value);
        changed = true;
      }
    }
    if (!changed) break;
  }
  return constants;
}

function calleeInfo(node, sourceFile) {
  const expression = node.expression;
  if (ts.isIdentifier(expression)) {
    const name = expression.text;
    const methodByHelper = new Map([
      ["apiGet", "GET"],
      ["apiPost", "POST"],
      ["apiPut", "PUT"],
      ["apiDelete", "DELETE"],
      ["fetch", "GET"],
    ]);
    if (methodByHelper.has(name)) {
      return { client: name, method: methodByHelper.get(name) };
    }
    return null;
  }

  if (!ts.isPropertyAccessExpression(expression)) return null;
  const methodName = expression.name.text;
  const receiver = expression.expression.getText(sourceFile);
  const directMethods = new Set(["get", "post", "put", "patch", "delete", "head", "request"]);
  if (!directMethods.has(methodName)) return null;
  if (!["request", "service", "axios"].includes(receiver)) return null;

  const method = methodName === "request" ? "ANY" : methodName.toUpperCase();
  return { client: `${receiver}.${methodName}`, method };
}

function methodFromFetchOptions(node, constants) {
  if (node.arguments.length < 2) return null;
  const methodNode = objectPropertyExpression(node.arguments[1], "method");
  const value = evaluateExpression(methodNode, constants, false);
  return value ? value.toUpperCase() : null;
}

function methodFromAxiosRequest(node, constants) {
  const config = node.arguments[0];
  const methodNode = objectPropertyExpression(config, "method");
  const value = evaluateExpression(methodNode, constants, false);
  return value ? value.toUpperCase() : "ANY";
}

function urlExpressionFromCall(node, info) {
  if (info.client === "axios.request") {
    return objectPropertyExpression(node.arguments[0], "url") ?? node.arguments[0] ?? null;
  }
  return node.arguments[0] ?? null;
}

function classify(row, callText) {
  const file = row.file;
  const resolved = row.resolvedPath || "";
  const raw = row.rawUrlExpression || "";

  if (file === "canvas_front_next/src/app/api/[...path]/route.ts" && row.client === "axios.request") {
    return { classification: "next-proxy", pathKind: "next-proxy" };
  }
  if (file === "admin_front_ts/src/lib/http/client.ts" || file === "canvas_front_next/src/services/api/request.ts") {
    return { classification: "wrapper-internal", pathKind: "wrapper-config" };
  }
  if (resolved.startsWith("/api/admin/v1")) return { classification: "backend-admin", pathKind: "admin-prefix" };
  if (resolved.startsWith("/api/canvas/v1")) return { classification: "backend-canvas", pathKind: "canvas-prefix" };
  if (resolved.startsWith("/api/app/v1")) return { classification: "backend-app", pathKind: "app-prefix" };
  if (resolved.startsWith("/api/")) return { classification: "backend-unknown-prefix", pathKind: "literal-api" };
  if (/^https?:\/\//.test(resolved)) return { classification: "external", pathKind: "external" };
  if (file === "admin_front_ts/src/api/system/uploadConfig.ts" && /\bbase\b/.test(raw)) {
    return { classification: "backend-admin-parametric", pathKind: "admin-parametric" };
  }

  if (/responseType\s*:\s*["']blob["']/.test(callText) || /DownloadManager|image-storage|file-storage|asset-picker|asset-library/.test(file)) {
    return { classification: "blob/download", pathKind: "dynamic-url" };
  }
  if (/latestVersionUrl|latestChangelogUrl|\burl\b/.test(raw)) {
    return { classification: "dynamic-url", pathKind: "dynamic-url" };
  }
  return { classification: "unresolved", pathKind: "unresolved" };
}

function parseFile(file) {
  const sourceText = sourceForParse(file);
  if (sourceText.trim().length === 0) return [];
  const sourceFile = ts.createSourceFile(file, sourceText, ts.ScriptTarget.Latest, true, scriptKindFor(file));
  const constants = collectConstants(sourceFile);
  const rows = [];
  const project = relPath(file).startsWith("admin_front_ts/") ? "admin_front_ts" : "canvas_front_next";
  const relativeFile = relPath(file);

  function visit(node) {
    if (ts.isCallExpression(node)) {
      const info = calleeInfo(node, sourceFile);
      if (info) {
        const urlNode = urlExpressionFromCall(node, info);
        let method = info.method;
        if (info.client === "fetch") method = methodFromFetchOptions(node, constants) ?? method;
        if (info.client === "axios.request") method = methodFromAxiosRequest(node, constants);
        const rawUrlExpression = urlNode ? urlNode.getText(sourceFile) : "";
        const resolvedPath = normalizeKnownApiPath(evaluateExpression(urlNode, constants, true) ?? "");
        const position = sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile));
        const callText = node.getText(sourceFile);
        const baseRow = {
          project,
          file: relativeFile,
          line: position.line + 1,
          method,
          client: info.client,
          rawUrlExpression,
          resolvedPath,
        };
        rows.push({ ...baseRow, ...classify(baseRow, callText) });
      }
    }
    ts.forEachChild(node, visit);
  }

  visit(sourceFile);
  return rows;
}

const allRows = [];
for (const file of input.files) {
  allRows.push(...parseFile(file));
}
allRows.sort((left, right) => left.file.localeCompare(right.file) || left.line - right.line || left.client.localeCompare(right.client));
process.stdout.write(JSON.stringify(allRows));
'@

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

    $files = @(Get-SourceFiles | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
    if ($files.Count -eq 0) { throw 'no frontend source files found for API inventory' }

    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "frontend-api-inventory-parser-$PID.cjs"
    $nodeParser | Set-Content -LiteralPath $tempScript -Encoding UTF8
    try {
        $payload = @{
            repoRoot = (Resolve-Path -LiteralPath '.').Path
            tsModulePath = Get-TypeScriptModulePath
            files = $files
        } | ConvertTo-Json -Depth 5 -Compress
        $nodeOutput = $payload | & node $tempScript
        if ($LASTEXITCODE -ne 0) { throw "node frontend API parser failed with exit code $LASTEXITCODE" }
        $rows = @($nodeOutput -join "`n" | ConvertFrom-Json)
    }
    finally {
        if (Test-Path -LiteralPath $tempScript) { [System.IO.File]::Delete((Resolve-Path -LiteralPath $tempScript).Path) }
    }

    $adminBackendRows = @($rows | Where-Object { $_.classification -eq 'backend-admin' })
    $canvasBackendRows = @($rows | Where-Object { $_.classification -eq 'backend-canvas' })
    $appBackendRows = @($rows | Where-Object { $_.classification -eq 'backend-app' })
    $externalRows = @($rows | Where-Object { $_.classification -eq 'external' })
    $dynamicRows = @($rows | Where-Object { $_.classification -in @('blob/download', 'dynamic-url') })
    $wrapperRows = @($rows | Where-Object { $_.classification -in @('wrapper-internal', 'next-proxy') })
    $parametricBackendRows = @($rows | Where-Object { $_.classification -eq 'backend-admin-parametric' })
    $unknownPrefixRows = @($rows | Where-Object { $_.classification -eq 'backend-unknown-prefix' })
    $unresolvedRows = @($rows | Where-Object { $_.classification -eq 'unresolved' })
    $adminPrefixRows = @($rows | Where-Object { [string]$_.resolvedPath -like '/api/admin/v1*' })
    $canvasPrefixRows = @($rows | Where-Object { [string]$_.resolvedPath -like '/api/canvas/v1*' })
    $knownBackendRows = @($rows | Where-Object { $_.classification -in @('backend-admin', 'backend-canvas', 'backend-app') })
    $outsideKnownRows = @($rows | Where-Object { $_.classification -notin @('backend-admin', 'backend-canvas', 'backend-app') })

    $lines = New-Object System.Collections.ArrayList
    Add-Line $lines '# Frontend API Inventory Snapshot'
    Add-Line $lines ''
    Add-Line $lines "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Line $lines ''
    Add-Line $lines 'This artifact is generated from current frontend source. It is a source inventory, not served-route smoke and not browser runtime proof. It intentionally resolves only literal strings, same-file constants, simple string/template concatenation, and the shared admin API prefix. Computed URLs are classified instead of guessed.'
    Add-Line $lines ''
    Add-Line $lines '## Source summary'
    Add-Line $lines ''
    Add-Line $lines '| Fact | Count |'
    Add-Line $lines '| --- | --- |'
    Add-Line $lines "| Source files scanned | ``$($files.Count)`` |"
    Add-Line $lines "| Frontend API calls found | ``$($rows.Count)`` |"
    Add-Line $lines "| Admin frontend backend API calls | ``$($adminBackendRows.Count)`` |"
    Add-Line $lines "| Canvas frontend backend API calls | ``$($canvasBackendRows.Count)`` |"
    Add-Line $lines "| App backend API calls | ``$($appBackendRows.Count)`` |"
    Add-Line $lines "| External HTTP helper calls | ``$($externalRows.Count)`` |"
    Add-Line $lines "| Dynamic blob/download URL calls | ``$($dynamicRows.Count)`` |"
    Add-Line $lines "| Wrapper/proxy infrastructure calls | ``$($wrapperRows.Count)`` |"
    Add-Line $lines "| Parametric backend admin helper calls | ``$($parametricBackendRows.Count)`` |"
    Add-Line $lines "| Calls under /api/admin/v1 | ``$($adminPrefixRows.Count)`` |"
    Add-Line $lines "| Calls under /api/canvas/v1 | ``$($canvasPrefixRows.Count)`` |"
    Add-Line $lines "| Backend /api calls outside known prefixes | ``$($unknownPrefixRows.Count)`` |"
    Add-Line $lines "| Frontend calls outside known backend prefixes | ``$($outsideKnownRows.Count)`` |"
    Add-Line $lines "| Unresolved frontend API expressions | ``$($unresolvedRows.Count)`` |"

    Add-Line $lines ''
    Add-Line $lines '## Backend API calls under known prefixes'
    Add-Line $lines ''
    Add-Line $lines '| Project | Source | Line | Client | Method path | Raw URL expression | Kind |'
    Add-Line $lines '| --- | --- | ---: | --- | --- | --- | --- |'
    foreach ($row in @($knownBackendRows | Sort-Object project,file,line,method,resolvedPath)) {
        $methodPath = "$($row.method) $($row.resolvedPath)"
        Add-Line $lines "| ``$($row.project)`` | ``$(Escape-Cell $row.file)`` | ``$($row.line)`` | ``$(Escape-Cell $row.client)`` | ``$(Escape-Cell $methodPath)`` | $(Code-Cell $row.rawUrlExpression) | ``$(Escape-Cell $row.pathKind)`` |"
    }

    Add-Line $lines ''
    Add-Line $lines '## Non-backend and infrastructure calls'
    Add-Line $lines ''
    Add-Line $lines 'External/blob/dynamic/proxy/parametric rows are kept separate so they do not become false backend contract drift.'
    Add-Line $lines ''
    Add-Line $lines '| Project | Source | Line | Client | Method path | Raw URL expression | Classification |'
    Add-Line $lines '| --- | --- | ---: | --- | --- | --- | --- |'
    foreach ($row in @($outsideKnownRows | Sort-Object classification,project,file,line)) {
        $pathText = if ([string]::IsNullOrWhiteSpace($row.resolvedPath)) { $row.method } else { "$($row.method) $($row.resolvedPath)" }
        Add-Line $lines "| ``$($row.project)`` | ``$(Escape-Cell $row.file)`` | ``$($row.line)`` | ``$(Escape-Cell $row.client)`` | ``$(Escape-Cell $pathText)`` | $(Code-Cell $row.rawUrlExpression) | ``$(Escape-Cell $row.classification)`` |"
    }

    if ($unresolvedRows.Count -gt 0) {
        Add-Line $lines ''
        Add-Line $lines '## Unresolved expressions requiring investigation'
        Add-Line $lines ''
        Add-Line $lines '| Project | Source | Line | Client | Method | Raw URL expression |'
        Add-Line $lines '| --- | --- | ---: | --- | --- | --- |'
        foreach ($row in $unresolvedRows) {
            Add-Line $lines "| ``$($row.project)`` | ``$(Escape-Cell $row.file)`` | ``$($row.line)`` | ``$(Escape-Cell $row.client)`` | ``$($row.method)`` | $(Code-Cell $row.rawUrlExpression) |"
        }
    }

    Add-Line $lines ''
    Add-Line $lines '## Parser boundary'
    Add-Line $lines ''
    Add-Line $lines '```text'
    Add-Line $lines 'Included: .ts, .tsx, and Vue <script> blocks under active Admin Vue and Canvas Next source roots.'
    Add-Line $lines 'Excluded: *.test.ts, *.test.tsx, and *.d.ts files.'
    Add-Line $lines 'Resolved: literal strings, simple consts, simple binary string concat, template strings with known consts, and dynamic path segments as :param.'
    Add-Line $lines 'Not guessed: arbitrary runtime URL variables, blob download URLs, Next proxy targetUrl, wrapper config.url, and parametric helper base paths.'
    Add-Line $lines '```'

    Add-Line $lines ''
    Add-Line $lines '## Verification command'
    Add-Line $lines ''
    Add-Line $lines '```powershell'
    Add-Line $lines "powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate $OutputDate"
    Add-Line $lines 'powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema'
    Add-Line $lines '```'

    $outPath = Join-Path $OutputDir "frontend-api-inventory-$OutputDate.md"
    $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote $outPath"
    Write-Host "frontend_api_calls=$($rows.Count)"
    Write-Host "backend_admin_calls=$($adminBackendRows.Count)"
    Write-Host "backend_canvas_calls=$($canvasBackendRows.Count)"
    Write-Host "external_calls=$($externalRows.Count)"
    Write-Host "unresolved_calls=$($unresolvedRows.Count)"
}
finally {
    Pop-Location
}
