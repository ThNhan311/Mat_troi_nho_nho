[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Provision','NewRun','Verify','Test','ServeBackend','Stop')][string]$Action,
 [Parameter(Mandatory=$true)][string]$JavaHome,
 [Parameter(Mandatory=$true)][string]$PrivateDirectory,
 [ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedContainerId,
 [switch]$FullSuite
)
$ErrorActionPreference='Stop'
# Do not silently accept a changed SQL set, database ref or candidate checksum.
& node (Join-Path $PSScriptRoot 'core-migration-inventory.mjs') --verify
if($LASTEXITCODE){throw 'Frozen I-01 candidate verification failed'}
$argsForRunner=@{Action=$Action;JavaHome=$JavaHome;PrivateDirectory=$PrivateDirectory}
if($ExpectedContainerId){$argsForRunner.ExpectedContainerId=$ExpectedContainerId}
if($FullSuite){$argsForRunner.FullSuite=$true}
& (Join-Path $PSScriptRoot 'account-integration-rehearsal.ps1') @argsForRunner