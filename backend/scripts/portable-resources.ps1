# Small shared guard/bootstrap helpers for existing Windows rehearsal runners.
Set-StrictMode -Version 2
function Save-NewPrivateJson([string]$Path,$Value) {
 $bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 12)+"`n")
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}
function New-RehearsalSecret {
 $bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
 try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
 [BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant()
}
function Assert-PrivateRehearsalDirectory([string]$Path) {
 $full=[IO.Path]::GetFullPath($Path);$temp=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp'))+[IO.Path]::DirectorySeparatorChar
 if(!$full.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'Private rehearsal directory must be outside Git under LOCALAPPDATA/Temp'}
 $repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
 if($full.StartsWith($repo+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Never put private authority in Git'}
 $ancestor=New-Object IO.DirectoryInfo($full)
 while($null -ne $ancestor){
  if(Test-Path -LiteralPath (Join-Path $ancestor.FullName '.git')){throw 'Private authority cannot be inside any Git repository'}
  if($ancestor.Exists -and ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Private authority cannot use a redirected directory'}
  $ancestor=$ancestor.Parent
 }
 $full
}
function Assert-PortableResource($Resource,$Instance,[string]$ExpectedId,[string]$Kind='Account') {
 $baseline=$Kind -eq 'Baseline';$port=if($baseline){15437}else{15441};$label=if($baseline){'baseline-20261120'}else{'account-20261123'}
 if($ExpectedId -notmatch '^[a-f0-9]{64}$' -or $Resource.containerId -ne $ExpectedId -or $Instance.Id -ne $ExpectedId){throw 'Full container identity mismatch'}
 if($Resource.image -notmatch '^sha256:[a-f0-9]{64}$' -or $Instance.Image -ne $Resource.image){throw 'Container image mismatch'}
 $mount=@($Instance.Mounts|Where-Object Destination -eq '/var/lib/postgresql/data');$binding=@($Instance.HostConfig.PortBindings.'5432/tcp')
 if($Resource.port -ne $port -or $Instance.Config.Labels.'fitcenter.task' -ne $label -or $mount.Count -ne 1 -or $mount[0].Type -ne 'volume' -or $mount[0].Name -ne $Resource.volume -or $binding.Count -ne 1 -or $binding[0].HostIp -ne '127.0.0.1' -or $binding[0].HostPort -ne [string]$port){throw 'Task/volume/loopback port identity mismatch'}
 $prefix=if($baseline){'baseline'}else{'core'}
 $legacy=(!$baseline -and $Resource.container -eq 'fitcenter-account-20261123-db' -and $Resource.volume -eq 'fitcenter_account_20261123_data')
 if(!$legacy){
  if($Resource.scope -notmatch '^[a-f0-9]{12}$' -or $Resource.container -ne "fitcenter-$prefix-$($Resource.scope)-db" -or $Resource.volume -ne "fitcenter_${prefix}_$($Resource.scope)_data" -or $Instance.Config.Labels.'fitcenter.scope' -ne $Resource.scope){throw 'Portable resource namespace mismatch'}
 }
}
function Assert-LocalDocker {
 $raw=docker --context desktop-linux context inspect desktop-linux;if($LASTEXITCODE){throw 'Docker Desktop Linux context is unavailable'}
 if(@($raw|ConvertFrom-Json)[0].Endpoints.docker.Host -ne 'npipe:////./pipe/dockerDesktopLinuxEngine'){throw 'Local Docker Desktop Linux engine required'}
}
function Get-ApprovedPostgresImage {
 $lock=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'postgres-rehearsal-image.json')|ConvertFrom-Json
 $raw=docker --context desktop-linux image inspect $lock.reference 2>$null
 if($LASTEXITCODE){docker --context desktop-linux pull $lock.reference|Out-Null;if($LASTEXITCODE){throw 'Pull of pinned PostgreSQL image failed'};$raw=docker --context desktop-linux image inspect $lock.reference}
 $image=@($raw|ConvertFrom-Json)[0]
 $digest=$lock.reference.Split('@')[1]
 if($image.Os -ne $lock.os -or $image.Architecture -ne $lock.architecture -or !@($image.RepoDigests|Where-Object { $_.EndsWith('@'+$digest) }).Count){throw 'Pinned PostgreSQL image provenance/platform mismatch'}
 $version=docker --context desktop-linux run --rm --network none --entrypoint postgres $lock.reference --version
 if($LASTEXITCODE -or !$version.StartsWith($lock.versionPrefix)){throw 'Pinned PostgreSQL version mismatch'}
 $image.Id
}
function New-PortablePostgresResource([string]$PrivateDirectory,[string]$Kind='Account') {
 $private=Assert-PrivateRehearsalDirectory $PrivateDirectory;Assert-LocalDocker
 $baseline=$Kind -eq 'Baseline';$file=if($baseline){'baseline-resource.json'}else{'account-resource.json'}
 if(Test-Path -LiteralPath (Join-Path $private $file)){throw 'Authority already exists; verify instead of provisioning over it'}
 foreach($name in @('postgres.dpapi','app.dpapi','provision-intent.json','postgres.env')){if(Test-Path -LiteralPath (Join-Path $private $name)){throw 'Private authority/credential collision; never overwrite'}}
 $image=Get-ApprovedPostgresImage;$scope=(New-RehearsalSecret).Substring(0,12);$prefix=if($baseline){'baseline'}else{'core'}
 $container="fitcenter-$prefix-$scope-db";$volume="fitcenter_${prefix}_${scope}_data";$port=if($baseline){15437}else{15441};$label=if($baseline){'baseline-20261120'}else{'account-20261123'};$role=if($baseline){'fitcenter_baseline_app'}else{'fitcenter_account_app'}
 if(@(docker --context desktop-linux ps -a --filter "name=^/$container$" --format '{{.ID}}').Count -or @(docker --context desktop-linux volume ls --filter "name=^$volume$" --format '{{.Name}}').Count){throw 'Resource collision; refusing overwrite'}
 $listener=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,$port);try{$listener.Start()}finally{$listener.Stop()}
 if(!(Test-Path -LiteralPath $private)){New-Item -ItemType Directory -Path $private|Out-Null}
 Save-NewPrivateJson (Join-Path $private 'provision-intent.json') ([ordered]@{scope=$scope;container=$container;volume=$volume;image=$image;port=$port;kind=$Kind})
 $admin=New-RehearsalSecret;$app=New-RehearsalSecret
 foreach($pair in @(@('postgres.dpapi',$admin),@('app.dpapi',$app))){$encrypted=ConvertTo-SecureString $pair[1] -AsPlainText -Force|ConvertFrom-SecureString;[IO.File]::WriteAllText((Join-Path $private $pair[0]),$encrypted,[Text.UTF8Encoding]::new($false))}
 $envFile=Join-Path $private 'postgres.env';[IO.File]::WriteAllText($envFile,"POSTGRES_PASSWORD=$admin`n",[Text.UTF8Encoding]::new($false))
 $null=docker --context desktop-linux volume create --label "fitcenter.task=$label" --label "fitcenter.scope=$scope" $volume;if($LASTEXITCODE){throw 'Volume creation failed'}
 try{$id=docker --context desktop-linux create --name $container --label "fitcenter.task=$label" --label "fitcenter.scope=$scope" --env-file $envFile -p "127.0.0.1:${port}:5432" -v "${volume}:/var/lib/postgresql/data" $image;if($LASTEXITCODE){throw 'Container creation failed'}}finally{Remove-Item -LiteralPath $envFile}
 $resource=[ordered]@{format=1;scope=$scope;container=$container;containerId=$id.Trim();volume=$volume;port=$port;image=$image;runs=@();createdAtUtc=[DateTime]::UtcNow.ToString('o')}
 Save-NewPrivateJson (Join-Path $private $file) $resource
 $null=docker --context desktop-linux start $resource.containerId;if($LASTEXITCODE){throw 'Container start failed'}
 $ready=$false;for($attempt=0;$attempt -lt 60;$attempt++){docker --context desktop-linux exec $resource.containerId pg_isready -q -h 127.0.0.1 -U postgres;if(!$LASTEXITCODE){$ready=$true;break};Start-Sleep -Milliseconds 250};if(!$ready){throw 'New PostgreSQL instance not ready'}
 "CREATE ROLE $role LOGIN PASSWORD '$app' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;"|docker --context desktop-linux exec -i $resource.containerId psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres|Out-Null;if($LASTEXITCODE){throw 'Application role creation failed'}
 if($baseline){"CREATE DATABASE fitcenter_baseline_20261120_test OWNER $role;"|docker --context desktop-linux exec -i $resource.containerId psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres|Out-Null;if($LASTEXITCODE){throw 'Baseline database creation failed'}}
 Write-Host "Provisioned new $Kind resource $($resource.containerId); private keys generated locally; volume retained."
}
function Get-VerifiedPortableResource([string]$PrivateDirectory,[string]$ExpectedId,[string]$Kind='Account') {
 $private=Assert-PrivateRehearsalDirectory $PrivateDirectory;Assert-LocalDocker
 $name=if($Kind -eq 'Baseline'){'baseline-resource.json'}else{'account-resource.json'}
 $resource=Get-Content -Raw -LiteralPath (Join-Path $private $name)|ConvertFrom-Json
 $raw=docker --context desktop-linux inspect $resource.container;if($LASTEXITCODE){throw 'Cannot inspect selected resource'}
 $instance=@($raw|ConvertFrom-Json)[0];Assert-PortableResource $resource $instance $ExpectedId $Kind
 $mount=docker --context desktop-linux volume inspect $resource.volume;if($LASTEXITCODE){throw 'Volume inspection failed'}
 $vol=@($mount|ConvertFrom-Json)[0];$label=if($Kind -eq 'Baseline'){'baseline-20261120'}else{'account-20261123'}
 if($vol.Labels.'fitcenter.task' -ne $label){throw 'Volume label mismatch'}
 if($resource.PSObject.Properties.Name -contains 'scope'){if($vol.Labels.'fitcenter.scope' -ne $resource.scope){throw 'Volume scope mismatch'}}
 $resource
}
function Invoke-PortableBaseline([string]$PrivateDirectory,[string]$JavaHome) {
 $resource=Get-Content -Raw -LiteralPath (Join-Path $PrivateDirectory 'baseline-resource.json')|ConvertFrom-Json
 $r=Get-VerifiedPortableResource $PrivateDirectory $resource.containerId 'Baseline'
 $saved=$env:DB_PASSWORD
 try{
  $env:DB_PASSWORD=[Net.NetworkCredential]::new('',(Get-Content -LiteralPath (Join-Path $PrivateDirectory 'app.dpapi')|ConvertTo-SecureString)).Password
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test-http-baseline.ps1') -JavaHome $JavaHome -ExpectedContainerId $r.containerId -ExpectedImage $r.image -ContainerName $r.container -VolumeName $r.volume -StartDatabase -FullSuite -IntegratedAccountSuite
  if($LASTEXITCODE){throw 'Portable baseline regression failed'}
 }finally{$env:DB_PASSWORD=$saved}
}
