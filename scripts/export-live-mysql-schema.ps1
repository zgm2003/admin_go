param(
    [string]$EnvPath = "admin_back_go/.env",
    [string]$OutputDate = (Get-Date).ToString("yyyy-MM-dd"),
    [string]$OutputDir = "docs/db"
)

$ErrorActionPreference = "Stop"

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

function Invoke-MySQL {
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

function Invoke-MySQLDumpNoData {
    param(
        [object]$Config,
        [string]$Path,
        [string]$VerifiedAt
    )

    $tmpPath = "$Path.tmp"
    $args = @(
        "-h", $Config.Host,
        "-P", $Config.Port,
        "-u", $Config.User,
        "--default-character-set=utf8mb4",
        "--no-data",
        "--routines",
        "--events",
        "--triggers",
        "--skip-comments",
        "--set-gtid-purged=OFF",
        $Config.Database
    )

    $previousPassword = $env:MYSQL_PWD
    $env:MYSQL_PWD = $Config.Password
    try {
        & mysqldump @args > $tmpPath
        if ($LASTEXITCODE -ne 0) {
            throw "mysqldump failed"
        }
    }
    finally {
        $env:MYSQL_PWD = $previousPassword
    }

    $header = @(
        "-- MySQL live schema snapshot",
        "-- Verified at: $VerifiedAt",
        "-- Truth source: live MySQL DATABASE() = $($Config.Database) on $($Config.Host):$($Config.Port)",
        "-- Generated via mysqldump --no-data. Secrets are not included.",
        ""
    ) -join "`r`n"

    $dump = Get-Content -LiteralPath $tmpPath -Raw
    Set-Content -LiteralPath $Path -Value ($header + "`r`n" + $dump) -Encoding UTF8
    Remove-Item -LiteralPath $tmpPath -Force
}

function Escape-MarkdownCell {
    param([string]$Value)
    if ($null -eq $Value -or $Value -eq "") { return "" }
    return ($Value -replace "\\", "\\" -replace "\|", "\|" -replace "`r?`n", "<br>")
}

$config = Parse-MySQLDsn (Read-DotEnvValue -Path $EnvPath -Key "MYSQL_DSN")
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$mdPath = Join-Path $OutputDir "mysql-live-schema-$OutputDate.md"
$sqlPath = Join-Path $OutputDir "mysql-live-schema-$OutputDate.sql"
$verifiedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$databaseName = Invoke-MySQL -Config $config -Sql "SELECT DATABASE();" | Select-Object -First 1
$tables = @(Invoke-MySQL -Config $config -Sql "SELECT table_name FROM information_schema.tables WHERE table_schema='$($config.Database)' AND table_type='BASE TABLE' ORDER BY table_name;")

$tableMeta = @{}
$tableMetaSql = "SELECT table_name, engine, table_collation, IFNULL(table_comment, '') FROM information_schema.tables WHERE table_schema='$($config.Database)' AND table_type='BASE TABLE' ORDER BY table_name;"
foreach ($line in Invoke-MySQL -Config $config -Sql $tableMetaSql) {
    $parts = $line -split "`t", 4
    $tableMeta[$parts[0]] = [pscustomobject]@{
        Engine = $parts[1]
        Collation = $parts[2]
        Comment = $parts[3]
    }
}

$rowCounts = @{}
foreach ($table in $tables) {
    $safeTable = $table -replace '`', '``'
    $rowCounts[$table] = Invoke-MySQL -Config $config -Sql "SELECT COUNT(*) FROM ``$safeTable``;" | Select-Object -First 1
}

$columnsByTable = @{}
$columnSql = @"
SELECT table_name, ordinal_position, column_name, column_type, is_nullable, IFNULL(column_default, '<NULL>'), column_key, extra, IFNULL(column_comment, '')
FROM information_schema.columns
WHERE table_schema='$($config.Database)'
ORDER BY table_name, ordinal_position;
"@
foreach ($line in Invoke-MySQL -Config $config -Sql $columnSql) {
    $parts = $line -split "`t", 9
    $table = $parts[0]
    if (-not $columnsByTable.ContainsKey($table)) {
        $columnsByTable[$table] = New-Object System.Collections.Generic.List[object]
    }
    $columnsByTable[$table].Add([pscustomobject]@{
        Ordinal = $parts[1]
        Name = $parts[2]
        Type = $parts[3]
        Nullable = $parts[4]
        Default = $parts[5]
        Key = $parts[6]
        Extra = $parts[7]
        Comment = $parts[8]
    })
}

$indexesByTable = @{}
$indexSql = @"
SELECT table_name, index_name, non_unique, seq_in_index, column_name, IFNULL(index_type, ''), IFNULL(index_comment, '')
FROM information_schema.statistics
WHERE table_schema='$($config.Database)'
ORDER BY table_name, index_name, seq_in_index;
"@
foreach ($line in Invoke-MySQL -Config $config -Sql $indexSql) {
    $parts = $line -split "`t", 7
    $table = $parts[0]
    if (-not $indexesByTable.ContainsKey($table)) {
        $indexesByTable[$table] = New-Object System.Collections.Generic.List[object]
    }
    $indexesByTable[$table].Add([pscustomobject]@{
        Name = $parts[1]
        NonUnique = $parts[2]
        Seq = $parts[3]
        Column = $parts[4]
        Type = $parts[5]
        Comment = $parts[6]
    })
}

$foreignKeys = @(Invoke-MySQL -Config $config -Sql "SELECT table_name, constraint_name, column_name, referenced_table_name, referenced_column_name FROM information_schema.key_column_usage WHERE table_schema='$($config.Database)' AND referenced_table_name IS NOT NULL ORDER BY table_name, constraint_name, ordinal_position;")

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# MySQL Live Schema Snapshot")
$lines.Add("")
$lines.Add("Verified at: $verifiedAt")
$lines.Add("")
$lines.Add("Truth source: live MySQL ``DATABASE() = $databaseName`` on ``$($config.Host):$($config.Port)``. Passwords and secrets are intentionally not recorded here.")
$lines.Add("")
$lines.Add("This snapshot is generated from ``information_schema``, per-table ``COUNT(*)``, and ``mysqldump --no-data``. Do not replace it with migration-file inference.")
$lines.Add("")
$lines.Add("## Summary")
$lines.Add("")
$lines.Add("| Item | Value |")
$lines.Add("| --- | --- |")
$lines.Add("| Database | ``$databaseName`` |")
$lines.Add("| Base tables | $($tables.Count) |")
$lines.Add("| Full DDL artifact | ``docs/db/mysql-live-schema-$OutputDate.sql`` |")
$lines.Add("")
$lines.Add("## Table inventory")
$lines.Add("")
$lines.Add("| Table | Rows checked by COUNT(*) | Engine | Collation | Comment |")
$lines.Add("| --- | ---: | --- | --- | --- |")
foreach ($table in $tables) {
    $meta = $tableMeta[$table]
    $lines.Add(("| ``{0}`` | {1} | {2} | {3} | {4} |" -f $table, $rowCounts[$table], $meta.Engine, $meta.Collation, (Escape-MarkdownCell $meta.Comment)))
}

$lines.Add("")
$lines.Add("## Foreign keys observed")
$lines.Add("")
if ($foreignKeys.Count -eq 0) {
    $lines.Add("No foreign keys are declared in live MySQL. Relationships are enforced by service/repository code and must not be invented in docs.")
} else {
    $lines.Add("| Table | Constraint | Column | References |")
    $lines.Add("| --- | --- | --- | --- |")
    foreach ($line in $foreignKeys) {
        $parts = $line -split "`t", 5
        $lines.Add(("| ``{0}`` | ``{1}`` | ``{2}`` | ``{3}.{4}`` |" -f $parts[0], $parts[1], $parts[2], $parts[3], $parts[4]))
    }
}

$lines.Add("")
$lines.Add("## Columns by table")
foreach ($table in $tables) {
    $lines.Add("")
    $lines.Add(("### ``{0}``" -f $table))
    $lines.Add("")
    $lines.Add("| # | Column | Type | Null | Key | Default | Extra | Comment |")
    $lines.Add("| ---: | --- | --- | --- | --- | --- | --- | --- |")

    foreach ($column in $columnsByTable[$table]) {
        $default = if ($column.Default -eq "<NULL>") { "NULL" } else { Escape-MarkdownCell $column.Default }
        $lines.Add(("| {0} | ``{1}`` | ``{2}`` | {3} | {4} | {5} | {6} | {7} |" -f $column.Ordinal, $column.Name, $column.Type, $column.Nullable, $column.Key, $default, (Escape-MarkdownCell $column.Extra), (Escape-MarkdownCell $column.Comment)))
    }

    if ($indexesByTable.ContainsKey($table)) {
        $lines.Add("")
        $lines.Add("Indexes:")
        foreach ($index in ($indexesByTable[$table] | Group-Object Name)) {
            $first = $index.Group | Select-Object -First 1
            $unique = if ($first.NonUnique -eq "0") { "unique" } else { "non-unique" }
            $columns = ($index.Group | Sort-Object { [int]$_.Seq } | ForEach-Object { "``$($_.Column)``" }) -join ", "
            $lines.Add(("- ``{0}`` ({1}, {2}): {3}" -f $index.Name, $unique, $first.Type, $columns))
        }
    }
}

Set-Content -LiteralPath $mdPath -Value ($lines -join "`r`n") -Encoding UTF8
Invoke-MySQLDumpNoData -Config $config -Path $sqlPath -VerifiedAt $verifiedAt

Write-Host "Wrote $mdPath"
Write-Host "Wrote $sqlPath"
Write-Host "tables=$($tables.Count)"


