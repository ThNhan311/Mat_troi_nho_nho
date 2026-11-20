[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$JavaHome,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
    [string]$DockerContext = 'desktop-linux',
    [string]$ContainerName = 'fitcenter-baseline-20261120-db',
    [string]$VolumeName = 'fitcenter_baseline_20261120_data',
    [ValidatePattern('^fitcenter_(baseline|http)_[a-z0-9_]+_test$')]
    [string]$DatabaseName = 'fitcenter_baseline_20261120_test',
    [ValidatePattern('^[a-z][a-z0-9_]+$')][string]$AppUsername = 'fitcenter_baseline_app',
    [ValidateRange(1024,65535)][int]$DatabasePort = 15437,
    [switch]$StartDatabase,
    [switch]$FullSuite
)

# A test runner for an already provisioned, isolated DB. No onboarding/seed SQL scripts are invoked.
$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$variableNames = @('JAVA_HOME','PATH','JAVA_TOOL_OPTIONS','DB_URL','DB_USERNAME','DB_PASSWORD','JWT_SECRET',
    'PGPASSWORD','RUN_DB_TESTS','RUN_HTTP_BASELINE_TESTS','HTTP_BASELINE_EXPECTED_DATABASE',
    'HTTP_BASELINE_GUARD_VERIFIED','SPRING_PROFILES_ACTIVE','LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_BOOT',
    'LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_SECURITY')
$savedEnvironment = @{}
foreach ($name in $variableNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$startedHere = $false
$locationPushed = $false
try {
    $overrides = Get-ChildItem Env: | Where-Object {
        $_.Name -match '^(SPRING_|FLYWAY_)' -or $_.Name -in @('MAVEN_ARGS','MAVEN_OPTS','JDK_JAVA_OPTIONS','_JAVA_OPTIONS')
    }
    if ($overrides) { throw 'Remove inherited Spring/Flyway/JVM/Maven overrides before running this isolated harness.' }
    $javaPath = Join-Path $JavaHome 'bin\java.exe'
    if (!(Test-Path -LiteralPath $javaPath)) { throw 'JDK path does not contain java.exe.' }
    $ErrorActionPreference = 'Continue' # Windows PowerShell wraps native stderr (including java -version).
    $javaVersion = (& $javaPath -version 2>&1 | Out-String)
    $javaExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($javaExit -ne 0 -or $javaVersion -notmatch 'version "21\.') { throw 'This runner requires JDK 21.' }

    $contextJson = docker --context $DockerContext context inspect $DockerContext
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Docker context.' }
    $context = @($contextJson | ConvertFrom-Json)[0]
    if ($context.Endpoints.docker.Host -ne 'npipe:////./pipe/dockerDesktopLinuxEngine') {
        throw 'Only the explicitly verified local Docker Desktop Linux engine is supported.'
    }
    # Parse in memory; never print docker inspect because Config.Env can contain bootstrap credentials.
    $instanceJson = docker --context $DockerContext inspect $ContainerName
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the selected test container.' }
    $instance = @($instanceJson | ConvertFrom-Json)[0]
    $postgresMounts = @($instance.Mounts | Where-Object Destination -eq '/var/lib/postgresql/data')
    $bindings = @($instance.HostConfig.PortBindings.'5432/tcp')
    if ($instance.Id -ne $ExpectedContainerId -or $instance.Config.Labels.'fitcenter.task' -ne 'baseline-20261120' -or
        $postgresMounts.Count -ne 1 -or $postgresMounts[0].Type -ne 'volume' -or $postgresMounts[0].Name -ne $VolumeName -or
        $bindings.Count -ne 1 -or $bindings[0].HostIp -ne '127.0.0.1' -or $bindings[0].HostPort -ne [string]$DatabasePort) {
        throw 'Container identity, task label, volume or loopback port does not match the expected isolated resource.'
    }
    if (!$instance.State.Running) {
        if (!$StartDatabase) { throw 'Test container is stopped. Verify it and opt in with -StartDatabase.' }
        if (Get-NetTCPConnection -LocalPort $DatabasePort -State Listen -ErrorAction SilentlyContinue) {
            throw 'Selected database port is already occupied.'
        }
        $null = docker --context $DockerContext start $ContainerName
        if ($LASTEXITCODE -ne 0) { throw 'Cannot start the selected test container.' }
        $startedHere = $true
    }
    $ready = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        docker --context $DockerContext exec $ContainerName pg_isready -q -h 127.0.0.1 -U $AppUsername -d $DatabaseName
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (!$ready) { throw 'Selected PostgreSQL instance is not ready.' }
    if ([string]::IsNullOrWhiteSpace($env:DB_PASSWORD)) {
        $securePassword = Read-Host 'Password for the isolated application role' -AsSecureString
        $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        try { $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    }
    $env:PGPASSWORD = $env:DB_PASSWORD
    $verificationSql = @'
SELECT current_database() || '|' || current_user || '|' ||
 (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text || '|' ||
 has_schema_privilege(current_user,'public','CREATE')::text || '|' ||
 (SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE version IS NOT NULL) || '|' ||
 (SELECT bool_and(success)::text FROM flyway_schema_history)
FROM pg_roles WHERE rolname=current_user;
'@
    $identity = docker --context $DockerContext exec -e PGPASSWORD $ContainerName psql -X -A -t -v ON_ERROR_STOP=1 -h 127.0.0.1 -U $AppUsername -d $DatabaseName -c $verificationSql
    if ($LASTEXITCODE -ne 0 -or $identity.Trim() -ne "$DatabaseName|$AppUsername|false|true|1,2,3,4,5,6|true") {
        throw 'Database identity, application privileges or V1-V6 migration history failed verification.'
    }
    $null = Remove-Item Env:PGPASSWORD
    $migrationRoot = Join-Path (Split-Path -Parent $backendRoot) 'database\migrations'
    $expectedFiles = @('V1__core_users_members.sql','V2__membership_payment.sql','V3__checkin.sql',
        'V4__pt_booking.sql','V5__workout_notification.sql','V6__audit_log.sql')
    $actualFiles = @(Get-ChildItem -LiteralPath $migrationRoot -Filter 'V*__*.sql' | Select-Object -ExpandProperty Name)
    if (@(Compare-Object $expectedFiles $actualFiles).Count -ne 0) { throw 'Canonical migration set is not exactly V1-V6.' }
    $compiledMigrations = Join-Path $backendRoot 'target\classes\db\migration'
    if (Test-Path -LiteralPath $compiledMigrations) {
        if (Get-ChildItem -LiteralPath $compiledMigrations -File | Where-Object Name -notin $expectedFiles) {
            throw 'Unexpected stale migration in target/classes; inspect it before running.'
        }
    }

    $env:JAVA_HOME = $JavaHome
    $env:PATH = "$JavaHome\bin;$env:PATH"
    $env:JAVA_TOOL_OPTIONS = '-Duser.timezone=UTC'
    $env:DB_URL = "jdbc:postgresql://127.0.0.1:$DatabasePort/$DatabaseName"
    $env:DB_USERNAME = $AppUsername
    $randomBytes = New-Object byte[] 48
    $randomSource = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $randomSource.GetBytes($randomBytes) } finally { $randomSource.Dispose() }
    $env:JWT_SECRET = [Convert]::ToBase64String($randomBytes)
    $env:RUN_DB_TESTS = 'true'
    $env:RUN_HTTP_BASELINE_TESTS = 'true'
    $env:HTTP_BASELINE_EXPECTED_DATABASE = $DatabaseName
    $env:HTTP_BASELINE_GUARD_VERIFIED = 'true'
    $env:SPRING_PROFILES_ACTIVE = 'default'
    $env:LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_BOOT = 'ERROR'
    $env:LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_SECURITY = 'ERROR'
    Write-Host "Verified JDK 21, container ID, volume, loopback mapping, DB=$DatabaseName, role=$AppUsername and canonical V1-V6."
    Push-Location $backendRoot
    $locationPushed = $true
    $runStartedUtc = [DateTime]::UtcNow
    $mavenArguments = @('-B','-ntp','test')
    if (!$FullSuite) { $mavenArguments += '-Dtest=HttpBaselineTest' }
    $ErrorActionPreference = 'Continue'
    & '.\mvnw.cmd' @mavenArguments 2>&1 | ForEach-Object {
        $line = $_.ToString()
        # Never echo HTTP request/response dumps, credentials or arbitrary Spring exception logs.
        if ($line -match '^\[(INFO|WARNING)\] (Tests run:|BUILD |Total time:|Finished at:)') { Write-Host $line }
    }
    $mavenExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $reports = @(Get-ChildItem target\surefire-reports\TEST-*.xml | Where-Object LastWriteTimeUtc -ge $runStartedUtc)
    if (!$reports.Count) { throw "Maven exited with code $mavenExit without fresh JUnit reports; inspect compilation/preflight locally without exposing secrets." }
    if (!($reports | Where-Object Name -eq 'TEST-vn.edu.tdtu.fitcenter.http.HttpBaselineTest.xml')) {
        throw 'No fresh HTTP harness report; other passing suites do not establish an HTTP baseline.'
    }
    $totals = @{Tests=0;Failures=0;Errors=0;Skipped=0}
    foreach ($report in $reports) {
        [xml]$suite = Get-Content -LiteralPath $report.FullName
        foreach ($name in @('Tests','Failures','Errors','Skipped')) { $totals[$name] += [int]$suite.testsuite.($name.ToLowerInvariant()) }
    }
    Write-Host "Fresh JUnit results: passed=$($totals.Tests-$totals.Failures-$totals.Errors-$totals.Skipped) failed=$($totals.Failures) errors=$($totals.Errors) skipped=$($totals.Skipped)."
    if ($mavenExit -ne 0 -or $totals.Failures -ne 0 -or $totals.Errors -ne 0 -or $totals.Skipped -ne 0) {
        throw 'Baseline did not fully pass. Review fresh Surefire reports; do not treat skipped as passed.'
    }
} finally {
    if ($locationPushed) { Pop-Location }
    foreach ($name in $variableNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    if ($startedHere) {
        $currentId = docker --context $DockerContext inspect $ContainerName --format '{{.Id}}'
        if ($currentId -eq $ExpectedContainerId) { $null = docker --context $DockerContext stop $ContainerName }
    }
}
