[CmdletBinding()]
param(
    [switch]$UseAlignmentContainer,
    [string]$DatabaseContainer = 'fitcenter-alignment-db',
    [ValidateSet('alignment', 'default')][string]$Profile = 'alignment',
    [string]$DatabaseUrl,
    [ValidateRange(1, 65535)][int]$Port = 8082
)
$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$names = @('DB_USERNAME', 'DB_PASSWORD', 'JWT_SECRET', 'DB_URL', 'ALIGNMENT_DB_URL', 'SERVER_PORT')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    if ($UseAlignmentContainer) {
        $raw = & docker inspect --format '{{json .Config.Env}}' $DatabaseContainer
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read the selected local database container.' }
        $settings = @{}
        foreach ($entry in ($raw | ConvertFrom-Json)) {
            $pair = $entry -split '=', 2
            if ($pair.Length -eq 2) { $settings[$pair[0]] = $pair[1] }
        }
        if (-not $settings['POSTGRES_USER'] -or -not $settings['POSTGRES_PASSWORD']) {
            throw 'The selected container has no PostgreSQL username/password configuration.'
        }
        $env:DB_USERNAME = $settings['POSTGRES_USER']
        $env:DB_PASSWORD = $settings['POSTGRES_PASSWORD']
        $databaseName = $settings['POSTGRES_DB']
        if (-not $databaseName) { $databaseName = $env:DB_USERNAME }
        if (-not $DatabaseUrl) {
            $mapping = & docker port $DatabaseContainer 5432/tcp
            if ($LASTEXITCODE -ne 0 -or -not $mapping) { throw 'No published PostgreSQL port found.' }
            $hostPort = (($mapping | Select-Object -First 1) -split ':')[-1]
            $DatabaseUrl = "jdbc:postgresql://127.0.0.1:$hostPort/$databaseName"
        }
    }
    if ([string]::IsNullOrWhiteSpace($env:DB_USERNAME) -or [string]::IsNullOrWhiteSpace($env:DB_PASSWORD)) {
        throw 'Set DB_USERNAME and DB_PASSWORD, or use -UseAlignmentContainer for the selected local Docker database.'
    }
    if ([string]::IsNullOrWhiteSpace($env:JWT_SECRET)) {
        $bytes = New-Object byte[] 48
        $random = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $random.GetBytes($bytes) } finally { $random.Dispose() }
        $env:JWT_SECRET = [Convert]::ToBase64String($bytes)
        Write-Host 'Generated an in-memory development JWT key; tokens expire on the next script restart.'
    }
    if ([Text.Encoding]::UTF8.GetByteCount($env:JWT_SECRET) -lt 32) {
        throw 'JWT_SECRET must contain at least 32 UTF-8 bytes.'
    }
    if ($DatabaseUrl) {
        if ($DatabaseUrl -notmatch '^jdbc:postgresql://') { throw 'DatabaseUrl must be a PostgreSQL JDBC URL.' }
        $env:DB_URL = $DatabaseUrl
        $env:ALIGNMENT_DB_URL = $DatabaseUrl
    }
    $env:SERVER_PORT = [string]$Port
    Push-Location $backendRoot
    try {
        $mavenArgs = @('spring-boot:run', '-Dspring-boot.run.jvmArguments=-Duser.timezone=UTC')
        if ($Profile -ne 'default') { $mavenArgs += "-Dspring-boot.run.profiles=$Profile" }
        & '.\mvnw.cmd' @mavenArgs
        if ($LASTEXITCODE -ne 0) { throw "Backend exited with code $LASTEXITCODE." }
    } finally { Pop-Location }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
