[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Provision','Build','Verify','Test','PrepareDemo','ServeBackend','Cleanup','Stop')][string]$Action,
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [Parameter(Mandatory=$true)][string]$PrivateDirectory,
 [ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [string]$Python,
 [ValidateSet('Core','Renewal')][string]$Scenario='Core',
 [switch]$FullSuite
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'portable-resources.ps1')
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$private=Assert-PrivateRehearsalDirectory $PrivateDirectory
$baseline=Join-Path $private 'baseline'
# Current manifest is exact V1-V6,V8-V13; unknown SQL is always a failure.
& node (Join-Path $PSScriptRoot 'core-demo-inventory.mjs');if($LASTEXITCODE){throw 'Current frozen candidate failed verification'}
$java=Join-Path $JavaHome 'bin/java.exe';$ErrorActionPreference='Continue';$version=(& $java -version 2>&1|Out-String);$versionCode=$LASTEXITCODE;$ErrorActionPreference='Stop'
if($versionCode -or $version -notmatch 'version "21\.'){throw 'JDK21 required'}
$runner=Join-Path $PSScriptRoot 'enrollment-integration-rehearsal.ps1'
if($Action -eq 'Provision'){
 if($ExpectedContainerId){throw 'Provision creates new authority; do not supply an existing ID'}
 New-PortablePostgresResource $baseline 'Baseline'
 New-PortablePostgresResource $private 'Account'
 return
}
if(!$ExpectedContainerId){throw 'Full account container ID from the newly generated manifest required'}
$resource=Get-VerifiedPortableResource $private $ExpectedContainerId 'Account'
$br=Get-Content -Raw -LiteralPath (Join-Path $baseline 'baseline-resource.json')|ConvertFrom-Json
$null=Get-VerifiedPortableResource $baseline $br.containerId 'Baseline'
if($Action -eq 'Stop'){
 foreach($pair in @(@($private,'Account',$ExpectedContainerId),@($baseline,'Baseline',$br.containerId))){
  $owned=Get-VerifiedPortableResource $pair[0] $pair[2] $pair[1]
  $state=@(docker --context desktop-linux inspect $owned.containerId|ConvertFrom-Json)[0]
  if($state.State.Running){$null=docker --context desktop-linux stop --timeout 10 $owned.containerId;if($LASTEXITCODE){throw 'Owned container stop failed'}}
 }
 Write-Host 'Stopped exact portable resources; all volumes/schema/history retained';return
}
$demo=Join-Path $private ('demo-'+$Scenario.ToLowerInvariant())
if($Action -eq 'Verify'){
 $runFile=Join-Path $private 'current-run.json'
 if(Test-Path -LiteralPath $runFile){& $runner -Action Verify -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $ExpectedContainerId}
 Write-Host 'Portable image/container/context/volume/loopback authority verified';return
}
$saved=@{};foreach($name in @('JAVA_HOME','PATH','JAVA_TOOL_OPTIONS','DB_PASSWORD','PGPASSWORD')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try{
 $env:JAVA_HOME=$JavaHome;$env:PATH="$JavaHome/bin;$env:PATH";$env:JAVA_TOOL_OPTIONS='-Duser.timezone=UTC'
 if($Action -eq 'Build'){
  Push-Location (Join-Path $repo 'backend')
  try{$ErrorActionPreference='Continue'; & .\mvnw.cmd -B -ntp -DskipTests package *> (Join-Path $private 'package-private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Package failed; inspect private log'}
   $ErrorActionPreference='Continue'; & .\mvnw.cmd -B -ntp dependency:build-classpath "-Dmdep.outputFile=$private/classpath.txt" *> (Join-Path $private 'classpath-private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Dependency classpath build failed'}
  }finally{Pop-Location}
  $candidate=Get-Content -Raw -LiteralPath (Join-Path $repo 'database/enrollment-integration-candidate.json')|ConvertFrom-Json
  $compiledRoot=Join-Path $repo 'backend/target/classes/db'
  $compiled=@(Get-ChildItem -LiteralPath $compiledRoot -Recurse -File -Filter 'V*__*.sql')
  if($compiled.Count -ne $candidate.entries.Count){throw 'Unexpected compiled SQL; inspect stale build artifacts before Flyway'}
  foreach($item in $candidate.entries){
   $relative=$item.path.Substring('database/'.Length);if($relative.StartsWith('migrations/')){$relative='migration/'+$relative.Substring('migrations/'.Length)}
   $file=Join-Path $compiledRoot $relative
   if(!(Test-Path -LiteralPath $file) -or (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant() -ne $item.sha256){throw 'Compiled SQL differs from the frozen candidate'}
  }
  $cp=(Join-Path $repo 'backend/target/classes')+';'+[IO.File]::ReadAllText((Join-Path $private 'classpath.txt')).Trim()
  $env:DB_PASSWORD=[Net.NetworkCredential]::new('',(Get-Content -LiteralPath (Join-Path $baseline 'app.dpapi')|ConvertTo-SecureString)).Password
  $ErrorActionPreference='Continue'; & $java '-Duser.timezone=UTC' -cp $cp (Join-Path $PSScriptRoot 'PreparePortableBaseline.java') *> (Join-Path $private 'baseline-prepare-private.log');$code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Fresh baseline prepare failed; never reset or migrate another database'}
  Write-Host 'Packaged backend and prepared new guarded V1-V6 baseline';return
 }
 if($Action -eq 'Test'){
  if(!$Python){throw 'Supply isolated Face Python runtime for selected F03A regression; never silently skip it'}
  & (Join-Path $PSScriptRoot 'face-service-rehearsal.ps1') -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $ExpectedContainerId -Python $Python -BaselinePrivateDirectory $baseline -FullSuite:$FullSuite
  return
 }
 if($Action -eq 'PrepareDemo'){
  if(Test-Path -LiteralPath $demo){throw 'Demo scope exists; reconcile/cleanup instead of overwriting'}
  & $runner -Action NewRun -JavaHome $JavaHome -PrivateDirectory $private -ExpectedContainerId $ExpectedContainerId
  $run=Get-Content -Raw -LiteralPath (Join-Path $private 'current-run.json')|ConvertFrom-Json
  New-Item -ItemType Directory -Path $demo|Out-Null
  # New scoped authority only for this run; credentials were generated by this task on this machine.
  $scoped=Get-Content -Raw -LiteralPath (Join-Path $private 'account-resource.json')|ConvertFrom-Json;$scoped.runs=@($run)
  Save-NewPrivateJson (Join-Path $demo 'account-resource.json') $scoped;Save-NewPrivateJson (Join-Path $demo 'current-run.json') $run
  $encrypted=Get-Content -Raw -LiteralPath (Join-Path $private 'app.dpapi');[IO.File]::WriteAllText((Join-Path $demo 'app.dpapi'),$encrypted,[Text.UTF8Encoding]::new($false))
  $env:DB_PASSWORD=[Net.NetworkCredential]::new('',($encrypted|ConvertTo-SecureString)).Password
  $cp=(Join-Path $repo 'backend/target/classes')+';'+[IO.File]::ReadAllText((Join-Path $private 'classpath.txt')).Trim()
  $ErrorActionPreference='Continue'; & $java '-Duser.timezone=UTC' -cp $cp (Join-Path $PSScriptRoot 'CoreIntegrationDemo.java') $demo $run.nonce --fresh-core *> (Join-Path $private ('demo-'+$Scenario+'-prepare-private.log'));$code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Demo preparation failed; reconcile exact run, do not reseed/reset'}
  Write-Host "Prepared $Scenario Admin-only scope under private authority; all business objects must use API/UI";return
 }
 if($Action -eq 'ServeBackend'){
  $null=Get-VerifiedPortableResource $demo $ExpectedContainerId 'Account'
  & $runner -Action ServeBackend -JavaHome $JavaHome -PrivateDirectory $demo -ExpectedContainerId $ExpectedContainerId -CoreDemo
  return
 }
 if($Action -eq 'Cleanup'){
  $env:PGPASSWORD=[Net.NetworkCredential]::new('',(Get-Content -LiteralPath (Join-Path $private 'app.dpapi')|ConvertTo-SecureString)).Password
  # Scope demos separately: only UUIDs registered to each run are eligible for deletion.
  foreach($scope in @('demo-core','demo-renewal')){if(Test-Path -LiteralPath (Join-Path $private $scope)){& node (Join-Path $PSScriptRoot 'cleanup-enrollment-integration.mjs') (Join-Path $private $scope);if($LASTEXITCODE){throw 'Demo exact cleanup failed'}}}
  & node (Join-Path $PSScriptRoot 'cleanup-enrollment-integration.mjs') $private;if($LASTEXITCODE){throw 'Test exact cleanup failed'}
  return
 }
}finally{foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
