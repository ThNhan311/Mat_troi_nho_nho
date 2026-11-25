[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Provision','Run','Cleanup','Stop')][string]$Action,
 [Parameter(Mandatory=$true)][string]$PrivateDirectory,
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [string]$Python='python.exe'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'portable-resources.ps1')
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$private=Assert-PrivateRehearsalDirectory $PrivateDirectory
$java=Join-Path $JavaHome 'bin/java.exe'
$ErrorActionPreference='Continue';$version=(& $java -version 2>&1|Out-String);$code=$LASTEXITCODE;$ErrorActionPreference='Stop'
if($code -or $version -notmatch 'version "21\.'){throw 'JDK21 required'}
& node (Join-Path $PSScriptRoot 'enrollment-migration-inventory.mjs');if($LASTEXITCODE){throw 'Published migrations/ref changed; review before rehearsal'}
$m=Get-Content -Raw -LiteralPath (Join-Path $repo 'docs/backend-handover/proposals/db01/candidate-manifest.json')|ConvertFrom-Json
$sqlFiles=@(Get-ChildItem -LiteralPath (Join-Path $repo 'docs/backend-handover/proposals/db01') -Filter '*.sql' -Recurse -File)
if($sqlFiles.Count -ne 2 -or $m.entries.Count -ne 2 -or $m.releaseReady -ne $false){throw 'Unexpected DB01 SQL candidate'}
foreach($e in $m.entries){if((Get-FileHash -LiteralPath (Join-Path $repo $e.path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $e.sha256){throw 'Candidate SQL differs from reviewed manifest'}}
if($Action -eq 'Provision'){if($ExpectedContainerId){throw 'Provision requires a new authority'};New-PortablePostgresResource $private 'Account';return}
if(!$ExpectedContainerId){throw 'Full private resource ID required'}
$r=Get-VerifiedPortableResource $private $ExpectedContainerId 'Account'
if($Action -eq 'Stop'){$i=@(docker --context desktop-linux inspect $r.containerId|ConvertFrom-Json)[0];if($i.State.Running){$null=docker --context desktop-linux stop --timeout 10 $r.containerId;if($LASTEXITCODE){throw 'Stop failed'}};Write-Host 'Stopped DB01 owned resource; volume retained';return}
$i=@(docker --context desktop-linux inspect $r.containerId|ConvertFrom-Json)[0];if(!$i.State.Running){throw 'Owned test DB must be running'}
$saved=@{};foreach($n in @('JAVA_HOME','PATH','JAVA_TOOL_OPTIONS','DB_PASSWORD','PGPASSWORD')){$saved[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
try{
 $env:JAVA_HOME=$JavaHome;$env:PATH="$JavaHome/bin;$env:PATH";$env:JAVA_TOOL_OPTIONS='-Duser.timezone=UTC'
 $env:DB_PASSWORD=[Net.NetworkCredential]::new('',(Get-Content -Raw -LiteralPath (Join-Path $private 'app.dpapi')|ConvertTo-SecureString)).Password
 if($Action -eq 'Cleanup'){$env:PGPASSWORD=$env:DB_PASSWORD;& node (Join-Path $PSScriptRoot 'cleanup-db01-rehearsal.mjs') $private $ExpectedContainerId;if($LASTEXITCODE){throw 'Exact DB01 cleanup failed'};return}
 Push-Location (Join-Path $repo 'backend')
 try{
  $ErrorActionPreference='Continue'; & .\mvnw.cmd -B -ntp -DskipTests package *> (Join-Path $private 'db01-package.private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Package failed; inspect private output'}
  $ErrorActionPreference='Continue'; & .\mvnw.cmd -B -ntp dependency:build-classpath "-Dmdep.outputFile=$private/classpath.txt" *> (Join-Path $private 'db01-classpath.private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Classpath failed'}
 }finally{Pop-Location}
 $nonce=(New-RehearsalSecret).Substring(0,12);$attempt=Join-Path $private ('attempt-'+$nonce);New-Item -ItemType Directory -Path (Join-Path $attempt 'source-v7')|Out-Null
 # Exact original V7 bytes from pinned Git object, not a rewritten migration.
 $v7=Join-Path $attempt 'source-v7/V7__membership_periods.sql'
 & $Python -c "import pathlib,subprocess,sys;pathlib.Path(sys.argv[1]).open('xb').write(subprocess.check_output(['git','-C',sys.argv[2],'show',sys.argv[3]+':'+sys.argv[4]]))" $v7 $repo $m.v7Commit $m.v7Path
 if($LASTEXITCODE -or (Get-FileHash -LiteralPath $v7 -Algorithm SHA256).Hash.ToLowerInvariant() -ne $m.v7GitSha256){throw 'V7 pin/hash mismatch'}
 $databases=@();foreach($scenario in @('fresh','v6_history','v7_history','existing_core','existing_legacy_core','conflicting_evidence','m03_before_v11','duplicate_receipt','missing_coverage','missing_provenance','refunded','wrong_binding','overlap_rollback')){
  $db='fitcenter_db01_'+(New-RehearsalSecret).Substring(0,12)+'_test';if($db -notmatch '^fitcenter_db01_[a-f0-9]{12}_test$'){throw 'Unexpected database namespace'}
  $databases+=@([ordered]@{scenario=$scenario;database=$db})
 }
 $run=[ordered]@{format=1;containerId=$r.containerId;attempt=$nonce;databases=$databases;createdAt=[DateTime]::UtcNow.ToString('o')}
 Save-NewPrivateJson (Join-Path $attempt 'db01-run.json') $run
 foreach($entry in $databases){"CREATE DATABASE $($entry.database) OWNER fitcenter_account_app;"|docker --context desktop-linux exec -i $r.containerId psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres|Out-Null;if($LASTEXITCODE){throw 'Fresh database create failed; retain authority for exact recovery'}}
 $cp=(Join-Path $repo 'backend/target/classes')+';'+[IO.File]::ReadAllText((Join-Path $private 'classpath.txt')).Trim()
 $ErrorActionPreference='Continue'; & $java '-Duser.timezone=UTC' -cp $cp (Join-Path $PSScriptRoot 'Db01MigrationRehearsal.java') $repo $attempt *> (Join-Path $attempt 'db01-harness.private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop'
 if($code){throw "DB01 rehearsal failed; inspect private attempt $nonce without printing secrets"}
 $result=Get-Content -Raw -LiteralPath (Join-Path $attempt 'db01-results.json')|ConvertFrom-Json
 if($result.failed -or $result.skipped){throw 'DB01 candidate did not fully pass'}
 Write-Host "DB01 migration/service checks: passed=$($result.passed) failed=0 skipped=0; attempt=$nonce"
}finally{foreach($n in $saved.Keys){[Environment]::SetEnvironmentVariable($n,$saved[$n],'Process')}}
