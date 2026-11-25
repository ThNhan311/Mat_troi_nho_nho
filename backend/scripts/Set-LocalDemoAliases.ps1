[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$DemoDirectory,
 [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [Parameter(Mandatory=$true)][string]$BackendDirectory,
 [Parameter(Mandatory=$true)][string]$ClasspathFile,
 [Parameter(Mandatory=$true)][string]$HandoffFile
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'portable-resources.ps1')
$private=Assert-PrivateRehearsalDirectory $DemoDirectory
$handoff=Assert-PrivateRehearsalDirectory $HandoffFile
$resource=Get-VerifiedPortableResource $private $ExpectedContainerId 'Account'
$run=Get-Content -Raw -LiteralPath (Join-Path $private 'current-run.json')|ConvertFrom-Json
if($run.nonce -notmatch '^[a-f0-9]{12}$' -or $run.history -ne "fitcenter_account_$($run.nonce)_history_test" -or !@($resource.runs|Where-Object nonce -eq $run.nonce).Count){throw 'Demo run authority mismatch'}
$java=Join-Path $JavaHome 'bin/java.exe'
$ErrorActionPreference='Continue';$version=(& $java -version 2>&1|Out-String);$code=$LASTEXITCODE;$ErrorActionPreference='Stop'
if($code -or $version -notmatch 'version "21\.'){throw 'JDK21 required'}
$accountsFile=Join-Path $private 'manual-accounts.private.json'
$registryFile=Join-Path $private 'core-ui-registry.json'
$fixtureFile=Join-Path $private 'demo-fixture.properties'
$accounts=Get-Content -Raw -LiteralPath $accountsFile|ConvertFrom-Json
$ledger=Get-Content -Raw -LiteralPath $registryFile|ConvertFrom-Json
$fixture=[IO.File]::ReadAllText($fixtureFile)
$handoffText=[IO.File]::ReadAllText($handoff)
$adminId=[regex]::Match($fixture,'(?m)^admin\.userId=([a-f0-9-]{36})\r?$').Groups[1].Value
$adminEmail=[regex]::Match($fixture,'(?m)^admin\.email=([^\r\n]+)').Groups[1].Value
if(!$adminId -or !$adminEmail -or $accounts.Count -ne 5 -or $ledger.run -ne $run.nonce){throw 'Dedicated five-account manual fixture required'}
$aliases=@{'Admin'='admin@example.test';'Member A'='membera@example.test';'Member B'='memberb@example.test';'PT A'='pta@example.test';'PT B'='ptb@example.test'}
$roles=@{'Admin'='ADMIN';'Member A'='MEMBER';'Member B'='MEMBER';'PT A'='PT';'PT B'='PT'}
$seen=@{};$properties="database=$($run.history)`n"
for($i=0;$i -lt $accounts.Count;$i++){
 $a=$accounts[$i]
 if(!$aliases.ContainsKey($a.label) -or $seen.ContainsKey($a.label) -or $a.role -ne $roles[$a.label]){throw 'Unexpected account label/role'}
 $seen[$a.label]=$true
 if($a.label -eq 'Admin'){$id=$adminId;if($a.email -ne $adminEmail){throw 'Admin seed email mismatch'}}
 else{
  $id=$a.userId
  $registered=@($ledger.created|Where-Object {$_.userId -eq $id -and $_.profileId -eq $a.profileId -and $_.role -eq $a.role -and $_.email -eq $a.email})
  if($registered.Count -ne 1){throw 'Account missing exact UUID/profile authority'}
 }
 if($id -notmatch '^[a-f0-9-]{36}$' -or ($a.email -notmatch '^(core-admin|core-e2e)-[a-f0-9-]{36}@example\.invalid$' -and $a.email -ne $aliases[$a.label])){throw 'Only registered synthetic fixture accounts may be renamed'}
 if(!$handoffText.Contains('Email: '+$a.email)){throw 'Handoff does not match fixture; reconcile instead of overwriting'}
 $properties+="user.$i.id=$id`nuser.$i.email=$($a.email)`nuser.$i.role=$($a.role)`nuser.$i.alias=$($aliases[$a.label])`n"
}
# Private checkpoint is created before SQL. If local file persistence fails after commit,
# recover against this exact journal; never recreate accounts or replay unrelated writes.
$journal=Join-Path $private ('alias-change-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $journal
foreach($file in @($accountsFile,$registryFile,$fixtureFile,$handoff)){Copy-Item -LiteralPath $file -Destination $journal}
$inputFile=Join-Path $journal 'request.properties'
[IO.File]::WriteAllText($inputFile,$properties,[Text.UTF8Encoding]::new($false))
$cp=(Join-Path $BackendDirectory 'target/classes')+';'+[IO.File]::ReadAllText($ClasspathFile).Trim()
$saved=$env:DB_PASSWORD
try{
 $env:DB_PASSWORD=[Net.NetworkCredential]::new('',(Get-Content -Raw -LiteralPath (Join-Path $private 'app.dpapi')|ConvertTo-SecureString)).Password
 $ErrorActionPreference='Continue'
 & $java '-Duser.timezone=UTC' -cp $cp (Join-Path $PSScriptRoot 'SetLocalDemoAliases.java') $inputFile
 $code=$LASTEXITCODE;$ErrorActionPreference='Stop';if($code){throw 'Alias transaction failed; local fixture unchanged'}
 [IO.File]::WriteAllText((Join-Path $journal 'database-committed.txt'),'Committed; reconcile local files from this journal if interrupted.',[Text.UTF8Encoding]::new($false))
 foreach($a in $accounts){
  $old=$a.email;$a.email=$aliases[$a.label]
  $handoffText=$handoffText.Replace('Email: '+$old,'Email: '+$a.email)
  if($a.label -ne 'Admin'){foreach($entry in $ledger.created){if($entry.userId -eq $a.userId){$entry.email=$a.email}}}
 }
 $fixture=[regex]::Replace($fixture,'(?m)^admin\.email=[^\r\n]+','admin.email=admin@example.test')
 [IO.File]::WriteAllText($accountsFile,($accounts|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($registryFile,($ledger|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($fixtureFile,$fixture,[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($handoff,$handoffText,[Text.UTF8Encoding]::new($false))
 # Original synthetic intentEmails remain unchanged: cleanup still owns exact created UUIDs.
 $passed=0
 foreach($a in $accounts){
  $body=@{email=$a.email;password=$a.password}|ConvertTo-Json -Compress
  try{$response=Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18086/api/v1/auth/login' -ContentType 'application/json' -Body $body -TimeoutSec 15}
  catch{throw 'Alias login failed; use private journal to reconcile, do not recreate fixture'}
  if($response.role -ne $a.role){throw 'Alias login role mismatch'}
  $passed++
  $response=$null;$body=$null
 }
 $result=@{at=[DateTime]::UtcNow.ToString('o');loginPassed=$passed;failed=0;businessAndPasswordSnapshotUnchanged=$true;databaseCommitted=$true}
 Save-NewPrivateJson (Join-Path $journal 'results.json') $result
 Write-Host 'Five alias logins passed; private handoff updated. Sign out and sign in again in all apps.'
}finally{$env:DB_PASSWORD=$saved}