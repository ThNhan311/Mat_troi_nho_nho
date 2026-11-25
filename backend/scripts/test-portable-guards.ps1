param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'portable-resources.ps1')
$script:passed=0
function Fixture {
 $r=[pscustomobject]@{scope='0123456789ab';container='fitcenter-core-0123456789ab-db';containerId=('a'*64);volume='fitcenter_core_0123456789ab_data';port=15441;image=('sha256:'+('b'*64))}
 $i=[pscustomobject]@{Id=$r.containerId;Image=$r.image;Mounts=@([pscustomobject]@{Destination='/var/lib/postgresql/data';Type='volume';Name=$r.volume});Config=[pscustomobject]@{Labels=[pscustomobject]@{'fitcenter.task'='account-20261123';'fitcenter.scope'=$r.scope}};HostConfig=[pscustomobject]@{PortBindings=[pscustomobject]@{'5432/tcp'=@([pscustomobject]@{HostIp='127.0.0.1';HostPort='15441'})}}}
 @($r,$i)
}
function Reject([string]$Name,[scriptblock]$Change) {
 $f=Fixture;$r=$f[0];$i=$f[1];& $Change $r $i
 $rejected=$false;try{Assert-PortableResource $r $i ('a'*64)}catch{$rejected=$true}
 if(!$rejected){throw "Guard accepted invalid $Name"};$script:passed++
}
$f=Fixture;Assert-PortableResource $f[0] $f[1] ('a'*64);$script:passed++
Reject 'short ID' {param($r,$i)$r.containerId='aaaa'}
Reject 'unexpected ID' {param($r,$i)$i.Id='c'*64}
Reject 'image' {param($r,$i)$i.Image='sha256:'+('c'*64)}
Reject 'task label' {param($r,$i)$i.Config.Labels.'fitcenter.task'='other'}
Reject 'volume name' {param($r,$i)$i.Mounts[0].Name='other'}
Reject 'bind mount' {param($r,$i)$i.Mounts[0].Type='bind'}
Reject 'two data mounts' {param($r,$i)$i.Mounts=@($i.Mounts[0],$i.Mounts[0])}
Reject 'LAN binding' {param($r,$i)$i.HostConfig.PortBindings.'5432/tcp'[0].HostIp='0.0.0.0'}
Reject 'wrong port' {param($r,$i)$i.HostConfig.PortBindings.'5432/tcp'[0].HostPort='5432'}
Reject 'two ports' {param($r,$i)$i.HostConfig.PortBindings.'5432/tcp'=@($i.HostConfig.PortBindings.'5432/tcp'[0],$i.HostConfig.PortBindings.'5432/tcp'[0])}
Reject 'manifest port' {param($r,$i)$r.port=5432}
Reject 'container namespace' {param($r,$i)$r.container='another-db'}
Reject 'volume namespace' {param($r,$i)$r.volume='another_volume';$i.Mounts[0].Name='another_volume'}
Reject 'scope label' {param($r,$i)$i.Config.Labels.'fitcenter.scope'='wrong'}
$f=Fixture;$f[0].container='fitcenter-account-20261123-db';$f[0].volume='fitcenter_account_20261123_data';$f[1].Mounts[0].Name=$f[0].volume;Assert-PortableResource $f[0] $f[1] ('a'*64);$script:passed++
$f=Fixture;$f[0].container='fitcenter-baseline-0123456789ab-db';$f[0].volume='fitcenter_baseline_0123456789ab_data';$f[0].port=15437;$f[1].Mounts[0].Name=$f[0].volume;$f[1].Config.Labels.'fitcenter.task'='baseline-20261120';$f[1].HostConfig.PortBindings.'5432/tcp'[0].HostPort='15437';Assert-PortableResource $f[0] $f[1] ('a'*64) 'Baseline';$script:passed++
$rejected=$false;try{Assert-PrivateRehearsalDirectory (Split-Path -Parent $PSScriptRoot)|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'Git path accepted for private authority'};$script:passed++
$temporary=Join-Path (Split-Path -Parent $OutputPath) ('guard-git-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary|Out-Null
try{
 [IO.File]::WriteAllText((Join-Path $temporary '.git'),'unit marker')
 $rejected=$false;try{Assert-PrivateRehearsalDirectory (Join-Path $temporary 'private')|Out-Null}catch{$rejected=$true}
 if(!$rejected){throw 'Private authority inside another Git repo accepted'};$script:passed++
}finally{Remove-Item -LiteralPath (Join-Path $temporary '.git');Remove-Item -LiteralPath $temporary}
$null=Assert-PrivateRehearsalDirectory (Join-Path (Split-Path -Parent $OutputPath) 'new-private-scope');$script:passed++

# Parse every changed entrypoint/helper without invoking Docker, SQL, or external processes.
foreach($name in @('portable-resources.ps1','core-readiness.ps1','account-integration-rehearsal.ps1','enrollment-integration-rehearsal.ps1','face-service-rehearsal.ps1','test-http-baseline.ps1')){
 $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name),[ref]$tokens,[ref]$errors);if($errors.Count){throw "PowerShell parse error: $name"}
}
$script:passed++
[IO.File]::WriteAllText($OutputPath,(@{passed=$script:passed;failed=0;skipped=0;kind='guard/unit/parser; no actual Docker or DB'}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Host "Portable guard checks: passed=$script:passed failed=0 skipped=0"
