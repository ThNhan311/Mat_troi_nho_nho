[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Provision','NewRun','Verify','Test','ServeBackend','Stop')][string]$Action,
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [Parameter(Mandatory=$true)][string]$PrivateDirectory,
 [ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [switch]$FullSuite
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& node (Join-Path $PSScriptRoot 'enrollment-migration-inventory.mjs')
if($LASTEXITCODE){throw 'Checkin migration inventory mismatch'}
$private=[IO.Path]::GetFullPath($PrivateDirectory)
$temp=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp'))+[IO.Path]::DirectorySeparatorChar
if(!$private.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or $private.StartsWith($repo,[StringComparison]::OrdinalIgnoreCase)){throw 'Use a dedicated private Temp directory outside Git'}
$container='fitcenter-account-20261123-db';$volume='fitcenter_account_20261123_data';$context='desktop-linux'
$manifest=Join-Path $private 'account-resource.json'
$canonical=@(Get-ChildItem -LiteralPath (Join-Path $repo 'database/migrations') -File -Filter 'V*__*.sql'|Select-Object -ExpandProperty Name)
$expected=@('V1__core_users_members.sql','V2__membership_payment.sql','V3__checkin.sql','V4__pt_booking.sql','V5__workout_notification.sql','V6__audit_log.sql')
if($canonical.Count -ne 6 -or @(Compare-Object ($expected|Sort-Object) ($canonical|Sort-Object)).Count){throw 'Canonical migration set changed; do not apply V7 through rehearsal'}
git -C $repo diff --quiet 66a70311517ccd0bf287eff45b476f1ce5138a16 -- database/migrations
if($LASTEXITCODE){throw 'Applied canonical migrations differ from the approved V1-V6 baseline'}
$java=Join-Path $JavaHome 'bin/java.exe'
$ErrorActionPreference='Continue';$version=(& $java -version 2>&1|Out-String);$javaExit=$LASTEXITCODE;$ErrorActionPreference='Stop'
if($javaExit -or $version -notmatch 'version "21\.'){throw 'JDK21 required'}
$endpoint=@(docker --context $context context inspect $context|ConvertFrom-Json)[0]
if($endpoint.Endpoints.docker.Host -ne 'npipe:////./pipe/dockerDesktopLinuxEngine'){throw 'Local Docker engine required'}
function Secret(){ $b=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($b)}finally{$rng.Dispose()};[BitConverter]::ToString($b).Replace('-','').ToLowerInvariant() }
function Save-PrivateJson($path,$value){[IO.File]::WriteAllText($path,($value|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))}
if($Action -eq 'Provision'){
 if(Test-Path -LiteralPath $manifest){throw 'Manifest exists; verify its resource ID instead of overwriting'}
 if(@(docker --context $context ps -a --filter "name=^/$container$" --format '{{.ID}}').Count -or @(docker --context $context volume ls --filter "name=^$volume$" --format '{{.Name}}').Count){throw 'Resource collision; refuse reuse without ownership manifest'}
 $listener=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,15441);try{$listener.Start()}finally{$listener.Stop()}
 if(!(Test-Path -LiteralPath $private)){New-Item -ItemType Directory -Path $private|Out-Null}
 $admin=Secret;$app=Secret
 ConvertTo-SecureString $admin -AsPlainText -Force|ConvertFrom-SecureString|Set-Content -LiteralPath (Join-Path $private 'postgres.dpapi')
 ConvertTo-SecureString $app -AsPlainText -Force|ConvertFrom-SecureString|Set-Content -LiteralPath (Join-Path $private 'app.dpapi')
 $envFile=Join-Path $private 'postgres.env';[IO.File]::WriteAllText($envFile,"POSTGRES_PASSWORD=$admin`n",[Text.UTF8Encoding]::new($false))
 $image=docker --context $context inspect fitcenter-baseline-20261120-db --format '{{.Image}}';if($LASTEXITCODE -or $image -notmatch '^sha256:[a-f0-9]{64}$'){throw 'Expected cached baseline PostgreSQL image'}
 $null=docker --context $context volume create --label fitcenter.task=account-20261123 $volume;if($LASTEXITCODE){throw 'Volume create failed'}
 try{$id=docker --context $context create --name $container --label fitcenter.task=account-20261123 --env-file $envFile -p 127.0.0.1:15441:5432 -v "${volume}:/var/lib/postgresql/data" $image;if($LASTEXITCODE){throw 'Container create failed'}}finally{Remove-Item -LiteralPath $envFile}
 $resource=[ordered]@{container=$container;containerId=$id.Trim();volume=$volume;port=15441;image=$image;runs=@();createdAtUtc=[DateTime]::UtcNow.ToString('o')};Save-PrivateJson $manifest $resource
 $null=docker --context $context start $container;if($LASTEXITCODE){throw 'Container start failed'}
 for($i=0;$i -lt 50;$i++){docker --context $context exec $container pg_isready -q -h 127.0.0.1 -U postgres;if(!$LASTEXITCODE){break};Start-Sleep -Milliseconds 200}
 $statement="CREATE ROLE fitcenter_account_app LOGIN PASSWORD '$app' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;"
 $statement|docker --context $context exec -i $container psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres|Out-Null;if($LASTEXITCODE){throw 'Application role provisioning failed'}
 Write-Host "Provisioned dedicated rehearsal container $($resource.containerId), loopback15441; private credential files outside Git."
 return
}
if(!(Test-Path -LiteralPath $manifest) -or !$ExpectedContainerId){throw 'Private resource manifest and full ExpectedContainerId required'}
$r=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
$i=@(docker --context $context inspect $container|ConvertFrom-Json)[0];$mount=@($i.Mounts|Where-Object Destination -eq '/var/lib/postgresql/data');$binding=@($i.HostConfig.PortBindings.'5432/tcp')
if($i.Id -ne $ExpectedContainerId -or $i.Id -ne $r.containerId -or $i.Config.Labels.'fitcenter.task' -ne 'account-20261123' -or $i.Image -ne $r.image -or $mount.Count -ne 1 -or $mount[0].Name -ne $volume -or $mount[0].Type -ne 'volume' -or $binding.Count -ne 1 -or $binding[0].HostIp -ne '127.0.0.1' -or $binding[0].HostPort -ne '15441'){throw 'Rehearsal resource identity mismatch'}
if($Action -eq 'Stop'){if($i.State.Running){$null=docker --context $context stop --timeout 10 $i.Id};Write-Host 'Stopped exact rehearsal container; volume retained';return}
if(!$i.State.Running){throw 'Verified rehearsal DB must be started explicitly before running'}
$app=[Net.NetworkCredential]::new('',(Get-Content -LiteralPath (Join-Path $private 'app.dpapi')|ConvertTo-SecureString)).Password
if($Action -in @('NewRun','Test')){
 $nonce=(Secret).Substring(0,12);$run=[ordered]@{nonce=$nonce;empty="fitcenter_account_${nonce}_empty_test";history="fitcenter_account_${nonce}_history_test";atUtc=[DateTime]::UtcNow.ToString('o')}
 foreach($db in @($run.empty,$run.history)){if($db -notmatch '^fitcenter_account_[a-f0-9]{12}_(empty|history)_test$'){throw 'Bad database name'};"CREATE DATABASE $db OWNER fitcenter_account_app;"|docker --context $context exec -i $container psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres|Out-Null;if($LASTEXITCODE){throw 'Fresh rehearsal database create failed'}}
 $r.runs=@($r.runs)+@($run);Save-PrivateJson $manifest $r;Save-PrivateJson (Join-Path $private 'current-run.json') $run
 if($Action -eq 'NewRun'){Write-Host 'Created two empty databases for this isolated rehearsal run';return}
}
$run=Get-Content -LiteralPath (Join-Path $private 'current-run.json') -Raw|ConvertFrom-Json
$accountRun=$run;$renewalRun=$run;$coreRun=$run
if($Action -eq 'Test'){
 & (Join-Path $PSScriptRoot 'account-integration-rehearsal.ps1') -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $ExpectedContainerId
 $accountRun=Get-Content -LiteralPath (Join-Path $private 'current-run.json') -Raw|ConvertFrom-Json
 & (Join-Path $PSScriptRoot 'account-integration-rehearsal.ps1') -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $ExpectedContainerId
 $renewalRun=Get-Content -LiteralPath (Join-Path $private 'current-run.json') -Raw|ConvertFrom-Json
 & (Join-Path $PSScriptRoot 'account-integration-rehearsal.ps1') -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $ExpectedContainerId
 $coreRun=Get-Content -LiteralPath (Join-Path $private 'current-run.json') -Raw|ConvertFrom-Json
 Save-PrivateJson (Join-Path $private 'current-run.json') $run
}
$envNames=@('JAVA_HOME','PATH','JAVA_TOOL_OPTIONS','ACCOUNT_EMPTY_DB_URL','ACCOUNT_HISTORY_DB_URL','ACCOUNT_DB_PASSWORD','ACCOUNT_PRIVATE_DIRECTORY','ACCOUNT_INTEGRATION_GUARD_VERIFIED','RUN_ACCOUNT_POSTGRES_TESTS','DB_URL','DB_USERNAME','DB_PASSWORD','SPRING_PROFILES_ACTIVE','JWT_SECRET','SERVER_ADDRESS','SERVER_PORT','CORS_ALLOWED_ORIGINS','ACCOUNT_TEST_SMTP_PORT','RENEWAL_EMPTY_DB_URL','RENEWAL_HISTORY_DB_URL','RENEWAL_GUARD_VERIFIED','RUN_RENEWAL_POSTGRES_TESTS','CHECKIN_EMPTY_DB_URL','CHECKIN_HISTORY_DB_URL','RUN_CHECKIN_POSTGRES_TESTS','CHECKIN_GUARD_VERIFIED','CHECKIN_TEST_CONFIG','ENROLLMENT_EMPTY_DB_URL','ENROLLMENT_HISTORY_DB_URL','RUN_ENROLLMENT_POSTGRES_TESTS','ENROLLMENT_GUARD_VERIFIED','ENROLLMENT_TEST_CONFIG')
$saved=@{};foreach($n in $envNames){$saved[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
try{
 $env:JAVA_HOME=$JavaHome;$env:PATH="$JavaHome/bin;$env:PATH";$env:JAVA_TOOL_OPTIONS='-Duser.timezone=UTC'
 $env:ACCOUNT_EMPTY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($accountRun.empty)";$env:ACCOUNT_HISTORY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($accountRun.history)";$env:ACCOUNT_DB_PASSWORD=$app;$env:ACCOUNT_PRIVATE_DIRECTORY=$private;$env:ACCOUNT_INTEGRATION_GUARD_VERIFIED='true';$env:RUN_ACCOUNT_POSTGRES_TESTS='true';$env:RUN_RENEWAL_POSTGRES_TESTS='true';$env:RENEWAL_GUARD_VERIFIED='true';$env:RENEWAL_EMPTY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($renewalRun.empty)";$env:RENEWAL_HISTORY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($renewalRun.history)";$env:ENROLLMENT_EMPTY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($run.empty)";$env:ENROLLMENT_HISTORY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($run.history)";$env:ENROLLMENT_GUARD_VERIFIED='true';$env:RUN_ENROLLMENT_POSTGRES_TESTS='true';$env:CHECKIN_EMPTY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($coreRun.empty)";$env:CHECKIN_HISTORY_DB_URL="jdbc:postgresql://127.0.0.1:15441/$($coreRun.history)";$env:CHECKIN_GUARD_VERIFIED='true';$env:RUN_CHECKIN_POSTGRES_TESTS='true'
 $oldPg=$env:PGPASSWORD;$env:PGPASSWORD=$app
 try{$q="SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text FROM pg_roles WHERE rolname=current_user";$identity=docker --context $context exec -e PGPASSWORD $container psql -X -A -t -v ON_ERROR_STOP=1 -h 127.0.0.1 -U fitcenter_account_app -d $run.history -c $q;if($LASTEXITCODE -or $identity.Trim() -ne "$($run.history)|fitcenter_account_app|false"){throw 'Datasource/role verification failed'}}finally{$env:PGPASSWORD=$oldPg}
 if($Action -eq 'Verify'){Write-Host 'JDK21/container/volume/loopback/database/app-role verified; no migration requested';return}
 if($Action -eq 'ServeBackend'){
  # Check the packaged locations before a JVM/Flyway can start.
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $jarPath=Join-Path $repo 'backend/target/fitcenter-0.0.1-SNAPSHOT.jar'
  $archive=[IO.Compression.ZipFile]::OpenRead($jarPath)
  try{
   $base=@($archive.Entries|Where-Object FullName -like 'BOOT-INF/classes/db/migration/V*__*.sql')
   if($base.Count -ne 6 -or @(Compare-Object ($expected|Sort-Object) (@($base.Name)|Sort-Object)).Count){throw 'Jar must package only V1-V6 in default location'}
   $extra=@($archive.Entries|Where-Object { $_.FullName -like 'BOOT-INF/classes/db/activation-rehearsal/V8__*.sql' -or $_.FullName -like 'BOOT-INF/classes/db/membership-rehearsal/V9__*.sql' -or $_.FullName -like 'BOOT-INF/classes/db/member-activation-rehearsal/V10__*.sql' -or $_.FullName -like 'BOOT-INF/classes/db/renewal-rehearsal/V11__*.sql' -or $_.FullName -like 'BOOT-INF/classes/db/checkin-rehearsal/V12__*.sql' -or $_.FullName -like 'BOOT-INF/classes/db/enrollment-rehearsal/V13__*.sql' })
   if($extra.Count -ne 6){throw 'Jar must package exact separate V8,V9,V10,V11,V12,V13 rehearsal migrations'}
   foreach($entry in @($base)+@($extra)){
    $relative=$entry.FullName.Substring('BOOT-INF/classes/db/'.Length)
    $source=if($relative.StartsWith('migration/')){Join-Path $repo ('database/migrations/'+$entry.Name)}else{Join-Path $repo ('database/'+$relative)}
    $stream=$entry.Open();$digest=[Security.Cryptography.SHA256]::Create()
    try{$actual=[BitConverter]::ToString($digest.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$digest.Dispose()}
    if($actual -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash){throw 'Packaged SQL/source mismatch'}
   }
  }finally{$archive.Dispose()}
  $env:DB_URL=$env:ENROLLMENT_HISTORY_DB_URL;$env:ENROLLMENT_TEST_CONFIG=Join-Path $private 'enrollment-demo-config.json';$env:CHECKIN_TEST_CONFIG=Join-Path $private 'checkin-demo-config.json';$env:DB_USERNAME='fitcenter_account_app';$env:DB_PASSWORD=$app;$env:SPRING_PROFILES_ACTIVE='face-enrollment-rehearsal';$env:ACCOUNT_TEST_SMTP_PORT='11035';$env:JWT_SECRET=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Secret)));$env:SERVER_ADDRESS='127.0.0.1';$env:SERVER_PORT='18086';$env:CORS_ALLOWED_ORIGINS='http://localhost:3000,http://localhost:3001,http://localhost:3002'
  & $java '-Duser.timezone=UTC' -jar (Join-Path $repo 'backend/target/fitcenter-0.0.1-SNAPSHOT.jar');if($LASTEXITCODE){throw 'Rehearsal Backend failed'};return
 }
 if($Action -eq 'Test'){
  $reviewDir=Join-Path $private 'v7-reference'
  if(!(Test-Path -LiteralPath $reviewDir)){New-Item -ItemType Directory -Path $reviewDir|Out-Null}
  $reviewSql=@(git -C $repo show origin/feature/database-schema:database/database/migrations/V7__membership_periods.sql)
  if($LASTEXITCODE){throw 'Cannot resolve Duy V7 for validate-only ordering test'}
  [IO.File]::WriteAllText((Join-Path $reviewDir 'V7__membership_periods.sql'),($reviewSql -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
  $started=[DateTime]::UtcNow
  if($FullSuite){
   if([string]::IsNullOrWhiteSpace($saved.DB_PASSWORD)){throw 'Provide the previously verified baseline DB password in process only for full regression'}
   $env:DB_PASSWORD=$saved.DB_PASSWORD
   & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test-http-baseline.ps1') -JavaHome $JavaHome -ExpectedContainerId e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0 -StartDatabase -FullSuite -IntegratedAccountSuite
   $code=$LASTEXITCODE
  }else{
   Push-Location (Join-Path $repo 'backend')
   try{ $ErrorActionPreference='Continue'; & .\mvnw.cmd -B -ntp test '-Dtest=EnrollmentPostgresTest,EnrollmentUnitTest' *> (Join-Path $private 'focused-maven-private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop' }finally{Pop-Location}
  }
  $sum=@{tests=0;failures=0;errors=0;skipped=0};$reports=@(Get-ChildItem (Join-Path $repo 'backend/target/surefire-reports/TEST-*.xml')|Where-Object LastWriteTimeUtc -ge $started)
  foreach($file in $reports){[xml]$x=Get-Content -LiteralPath $file.FullName;foreach($key in @('tests','failures','errors','skipped')){$sum[$key]+=[int]$x.testsuite.$key}}
  $sum.full=[bool]$FullSuite;$sum.runNonce=$run.nonce;Save-PrivateJson (Join-Path $private 'latest-tests.json') $sum
  Write-Host "Fresh rehearsal results: passed=$($sum.tests-$sum.failures-$sum.errors-$sum.skipped),failed=$($sum.failures),errors=$($sum.errors),skipped=$($sum.skipped)"
  if($code -or !$reports.Count -or $sum.failures -or $sum.errors -or $sum.skipped){throw 'Rehearsal failed; inspect sanitized reports privately'}
 }
}finally{foreach($n in $envNames){[Environment]::SetEnvironmentVariable($n,$saved[$n],'Process')}}
