[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [Parameter(Mandatory=$true)][string]$PrivateDirectory,
 [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [Parameter(Mandatory=$true)][string]$Python,
 [string]$BaselinePrivateDirectory,
 [switch]$FullSuite
)
$ErrorActionPreference='Stop'
# Existing runner verifies JDK21, exact container/image/volume/loopback and DB role before any Flyway.
$runner=Join-Path $PSScriptRoot 'enrollment-integration-rehearsal.ps1'
& $runner -Action NewRun -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ExpectedContainerId
$faceRun=Get-Content -Raw -LiteralPath (Join-Path $PrivateDirectory 'current-run.json')|ConvertFrom-Json
$names=@('FACE_SERVICE_EMPTY_DB_URL','FACE_SERVICE_HISTORY_DB_URL','FACE_SERVICE_PYTHON','RUN_FACE_SERVICE_POSTGRES_TESTS','JAVA_HOME','PATH','JAVA_TOOL_OPTIONS','ACCOUNT_DB_PASSWORD','ACCOUNT_PRIVATE_DIRECTORY','RUN_ENROLLMENT_POSTGRES_TESTS','ENROLLMENT_EMPTY_DB_URL','ENROLLMENT_HISTORY_DB_URL')
$saved=@{};foreach($n in $names){$saved[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
try {
 $env:FACE_SERVICE_EMPTY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($faceRun.empty)"
 $env:FACE_SERVICE_HISTORY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($faceRun.history)"
 $env:FACE_SERVICE_PYTHON=(Get-Item -LiteralPath $Python).FullName
 $env:RUN_FACE_SERVICE_POSTGRES_TESTS='true'
 if($FullSuite){
  & $runner -Action Test -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ExpectedContainerId -BaselinePrivateDirectory $BaselinePrivateDirectory -FullSuite
  return
 }
 & $runner -Action NewRun -JavaHome $JavaHome -PrivateDirectory $PrivateDirectory -ExpectedContainerId $ExpectedContainerId
 $enrollmentRun=Get-Content -Raw -LiteralPath (Join-Path $PrivateDirectory 'current-run.json')|ConvertFrom-Json
 $env:JAVA_HOME=$JavaHome;$env:PATH="$JavaHome/bin;$env:PATH";$env:JAVA_TOOL_OPTIONS='-Duser.timezone=UTC'
 $env:ACCOUNT_DB_PASSWORD=[Net.NetworkCredential]::new('',(Get-Content -LiteralPath (Join-Path $PrivateDirectory 'app.dpapi')|ConvertTo-SecureString)).Password
 $env:ACCOUNT_PRIVATE_DIRECTORY=$PrivateDirectory;$env:RUN_ENROLLMENT_POSTGRES_TESTS='true'
 $env:ENROLLMENT_EMPTY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($enrollmentRun.empty)"
 $env:ENROLLMENT_HISTORY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($enrollmentRun.history)"
 $started=[DateTime]::UtcNow
 Push-Location (Join-Path (Split-Path -Parent $PSScriptRoot) '.')
 try{$ErrorActionPreference='Continue'; & .\mvnw.cmd -B -ntp test '-Dtest=FaceServicePostgresTest,FaceServiceUnitTest,EnrollmentPostgresTest,EnrollmentUnitTest' *> (Join-Path $PrivateDirectory 'face-focused-private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop'}finally{Pop-Location}
 $sum=@{tests=0;failures=0;errors=0;skipped=0}
 $reports=@(Get-ChildItem (Join-Path (Split-Path -Parent $PSScriptRoot) 'target/surefire-reports/TEST-*.xml')|Where-Object LastWriteTimeUtc -ge $started)
 foreach($f in $reports){[xml]$x=Get-Content -LiteralPath $f.FullName;foreach($k in $sum.Keys.Clone()){$sum[$k]+=[int]$x.testsuite.$k}}
 [IO.File]::WriteAllText((Join-Path $PrivateDirectory 'face-focused-results.json'),($sum|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 Write-Host "Fresh focused: tests=$($sum.tests),failures=$($sum.failures),errors=$($sum.errors),skipped=$($sum.skipped)"
 if($code -or $reports.Count -ne 4 -or $sum.failures -or $sum.errors -or $sum.skipped){throw 'Face focused regression failed; inspect private reports'}
}finally{foreach($n in $names){[Environment]::SetEnvironmentVariable($n,$saved[$n],'Process')}}
