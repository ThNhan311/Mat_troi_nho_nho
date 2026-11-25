[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Verify','Seed','LifecycleSeed','LifecycleAudit','LifecycleSnapshot','Policy','Rotate','Capture','Audit','Cleanup','ServeBackend')][string]$Action,
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [ValidateRange(1024,65535)][int]$BackendPort=18081,
 [switch]$IncludeAdminWeb,
 [switch]$StartDatabase
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$container='fitcenter-baseline-20261120-db'
$context='desktop-linux'
$names=@('JAVA_HOME','PATH','DB_URL','DB_USERNAME','DB_PASSWORD','JWT_SECRET','PGPASSWORD','SERVER_PORT','SERVER_ADDRESS','CORS_ALLOWED_ORIGINS','SPRING_PROFILES_ACTIVE')
$saved=@{}
foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
 $overrides=Get-ChildItem Env: | Where-Object {$_.Name -match '^(SPRING_|FLYWAY_)' -or $_.Name -in @('MAVEN_ARGS','MAVEN_OPTS','JAVA_TOOL_OPTIONS','JDK_JAVA_OPTIONS','_JAVA_OPTIONS')}
 if($overrides){throw 'Remove inherited Spring/Flyway/JVM/Maven overrides before using demo tooling.'}
 $java=Join-Path $JavaHome 'bin\java.exe'
 $ErrorActionPreference='Continue'; $version=(& $java -version 2>&1 | Out-String); $code=$LASTEXITCODE; $ErrorActionPreference='Stop'
 if($code -ne 0 -or $version -notmatch 'version "21\.'){throw 'JDK21 is required.'}
 $endpoint=@(docker --context $context context inspect $context | ConvertFrom-Json)[0]
 if($LASTEXITCODE -or $endpoint.Endpoints.docker.Host -ne 'npipe:////./pipe/dockerDesktopLinuxEngine'){throw 'Unexpected Docker endpoint.'}
 $instance=@(docker --context $context inspect $container | ConvertFrom-Json)[0]
 $mounts=@($instance.Mounts|Where-Object Destination -eq '/var/lib/postgresql/data')
 $bindings=@($instance.HostConfig.PortBindings.'5432/tcp')
 if($instance.Id -ne $ExpectedContainerId -or $instance.Config.Labels.'fitcenter.task' -ne 'baseline-20261120' -or
    $mounts.Count -ne 1 -or $mounts[0].Name -ne 'fitcenter_baseline_20261120_data' -or $mounts[0].Type -ne 'volume' -or
    $bindings.Count -ne 1 -or $bindings[0].HostIp -ne '127.0.0.1' -or $bindings[0].HostPort -ne '15437'){throw 'Container/label/volume/loopback port mismatch.'}
 $manifest=[IO.Path]::GetFullPath($ManifestPath)
 $tempRoot=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp'))+[IO.Path]::DirectorySeparatorChar
 if(!$manifest.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or $manifest.StartsWith($repo,[StringComparison]::OrdinalIgnoreCase) -or
    !(Test-Path -LiteralPath (Split-Path -Parent $manifest))){throw 'Manifest must be in an existing private Temp folder outside repository.'}
 if(!$instance.State.Running){
  if(!$StartDatabase){throw 'Test DB is stopped; verify identity and explicitly pass -StartDatabase.'}
  $null=docker --context $context start $container
  if($LASTEXITCODE){throw 'Cannot start verified DB.'}
  Write-Host 'Started the verified demo/test container. Stop this exact container after cleanup; keep volume.'
 }
 $ready=$false
 for($attempt=0;$attempt -lt 30;$attempt++){
  docker --context $context exec $container pg_isready -q -h 127.0.0.1 -U fitcenter_baseline_app -d fitcenter_baseline_20261120_test
  if($LASTEXITCODE -eq 0){$ready=$true;break};Start-Sleep -Milliseconds 300
 }
 if(!$ready){throw 'DB not ready.'}
 if([string]::IsNullOrWhiteSpace($env:DB_PASSWORD)){
  $secure=Read-Host 'Password for the isolated application DB role' -AsSecureString
  $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try{$env:DB_PASSWORD=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)}
 }
 $env:JAVA_HOME=$JavaHome; $env:PATH="$JavaHome\bin;$env:PATH"
 $env:DB_URL='jdbc:postgresql://127.0.0.1:15437/fitcenter_baseline_20261120_test'
 $env:DB_USERNAME='fitcenter_baseline_app'
 $env:PGPASSWORD=$env:DB_PASSWORD
 $verify=@'
SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||
 (SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE version IS NOT NULL)||'|'||
 (SELECT bool_and(success)::text FROM flyway_schema_history) FROM pg_roles WHERE rolname=current_user;
'@
 $identity=docker --context $context exec -e PGPASSWORD $container psql -X -A -t -v ON_ERROR_STOP=1 -h 127.0.0.1 -U fitcenter_baseline_app -d fitcenter_baseline_20261120_test -c $verify
 if($LASTEXITCODE -or $identity.Trim() -ne 'fitcenter_baseline_20261120_test|fitcenter_baseline_app|false|1,2,3,4,5,6|true'){throw 'Datasource identity/privileges/V1-V6 mismatch.'}
 Remove-Item Env:PGPASSWORD
 $actual=@(Get-ChildItem -LiteralPath (Join-Path $repo 'database\migrations') -File -Filter 'V*__*.sql'|Select-Object -ExpandProperty Name)
 # Refuse any migration beyond the existing canonical set. Names are compared with the tracked set below.
 $tracked=@(git -C $repo ls-tree --name-only HEAD database/migrations/)
 $tracked=@($tracked|ForEach-Object {Split-Path -Leaf $_})
 if($tracked.Count -ne 6 -or @(Compare-Object ($tracked|Sort-Object) ($actual|Sort-Object)).Count -ne 0 -or ($actual|Where-Object {$_ -notmatch '^V[1-6]__'})){throw 'Canonical migrations must remain exactly tracked V1-V6.'}
 git -C $repo diff --quiet HEAD -- database/migrations
 if($LASTEXITCODE){throw 'Do not run with changes to applied migrations.'}
 $classpathFile=Join-Path (Split-Path -Parent $manifest) 'classpath.txt'
 if(!(Test-Path -LiteralPath $classpathFile)){throw 'Prepare cached dependency classpath using Maven dependency:build-classpath as documented.'}
 $classpath=(Get-Content -Raw -LiteralPath $classpathFile).Trim()
 if($Action -eq 'ServeBackend'){
  $listener=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,$BackendPort)
  try{$listener.Start()}finally{$listener.Stop()}
  $env:SERVER_PORT=[string]$BackendPort; $env:SERVER_ADDRESS='127.0.0.1'
  $env:CORS_ALLOWED_ORIGINS='http://localhost:3000,http://localhost:3001'
  if($IncludeAdminWeb){$env:CORS_ALLOWED_ORIGINS+=',http://localhost:3002'}
  $env:SPRING_PROFILES_ACTIVE='default'
  $random=New-Object byte[] 48;$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
  try{$rng.GetBytes($random)}finally{$rng.Dispose()}
  $env:JWT_SECRET=[Convert]::ToBase64String($random)
  $jar=Get-ChildItem -LiteralPath (Join-Path $repo 'backend\target') -Filter '*.jar'|Where-Object Name -notlike '*.original'|Select-Object -First 1
  if(!$jar){throw 'Build the Backend jar with JDK21 and -DskipTests package first.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($jar.FullName)
  try {
   $migrations=@($archive.Entries|Where-Object FullName -like 'BOOT-INF/classes/db/migration/V*__*.sql')
   if($migrations.Count -ne 6 -or @(Compare-Object ($tracked|Sort-Object) (@($migrations.Name)|Sort-Object)).Count){throw 'Packaged jar must contain exactly canonical V1-V6, with no V7/stale migration.'}
   foreach($entry in $migrations){
    $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
    try{$packagedHash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
    if($packagedHash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo ('database/migrations/'+$entry.Name))).Hash){throw 'Packaged migration differs from canonical source.'}
   }
  }finally{$archive.Dispose()}
  Write-Host 'Starting loopback Backend with verified test datasource, default V1-V6, explicit fixed web origins (3000/3001; 3002 only with -IncludeAdminWeb) and an in-memory JWT key.'
  & $java '-Duser.timezone=UTC' -jar $jar.FullName
  if($LASTEXITCODE){throw 'Backend exited with error; inspect local log without sharing secrets.'}
 }elseif($Action -eq 'Verify'){
  Write-Host 'JDK21, container/volume/port, DB role and V1-V6 verified; no seed/update requested.'
 }else{
  & $java '-Duser.timezone=UTC' -cp $classpath (Join-Path $PSScriptRoot 'BookingDemo.java') $Action.ToLowerInvariant() $manifest ("http://127.0.0.1:$BackendPort/api/v1")
  if($LASTEXITCODE){throw 'Demo action failed. Inspect local state without printing credentials or SQL.'}
 }
}finally{
 foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
}
