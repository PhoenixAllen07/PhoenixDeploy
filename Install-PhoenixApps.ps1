# Main orchestrator: RUN UNELEVATED. It asks for administrator approval once for machine-wide installs.
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'Phoenix-Common.ps1')
if(Get-IsAdmin){
  Write-Host 'Launch Run-Phoenix.cmd normally (not Run as administrator).' -ForegroundColor Yellow
  Write-Host 'The launcher automatically asks for admin privileges ONCE for machine-wide apps; Spotify runs unelevated.'
  exit 2
}
if(-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
  Write-Host 'WinGet not found. Install/update Microsoft App Installer from Microsoft Store.' -ForegroundColor Red
  exit 2
}
Write-Log "PhoenixDeploy started as $([Security.Principal.WindowsIdentity]::GetCurrent().Name)" 'Cyan'
Write-Log 'Phase 1: per-user applications, NOT elevated.' 'Cyan'
$userApps=@(
  @{Name='Discord';Id='Discord.Discord';X64=$true},
  @{Name='Spotify';Id='Spotify.Spotify';X64=$false}
)
foreach($app in $userApps) {
  $name=$app.Name
  try {
    $before=Find-App $name
    $store=if($name -eq 'Spotify'){Get-SpotifyStoreAppId}else{$null}
    if($before -or $store){Save-Result $name 'SKIPPED' 'Already installed for current Windows user' 'User';continue}
    $rc=Invoke-Winget $name $app.Id 'user' -X64:([bool]$app.X64)
    Start-Sleep -Seconds 3
    $after=Find-App $name
    $store=if($name -eq 'Spotify'){Get-SpotifyStoreAppId}else{$null}
    if($after -or $store){Save-Result $name 'INSTALLED' 'Executable or Store registration verified' 'User'}
    elseif($rc -eq 0){Save-Result $name 'REVIEW' 'WinGet returned 0 but application not found in normal user profile' 'User'}
    else{Save-Result $name 'FAILED' "WinGet exit=$rc" 'User'}
  }catch{Save-Result $name 'FAILED' "Unexpected error: $_" 'User'}
}
# Medal WinGet package has used a broken download URL. Use separately downloaded official web installer.
try {
  if(Find-App 'Medal'){Save-Result 'Medal' 'SKIPPED' 'Already installed for current user' 'User'}
  else {
    $medal=Join-Path $PSScriptRoot 'MedalSetup.exe'
    if(-not (Test-Path -LiteralPath $medal)){Save-Result 'Medal' 'REVIEW' 'Download Medal installer from https://medal.tv and save as MedalSetup.exe beside scripts.' 'User'}
    else {
      Write-Log 'Launching locally supplied Medal installer as normal user; may require interaction.' 'Yellow'
      $p=Start-Process -FilePath $medal -PassThru
      if($p.WaitForExit(120000)){Write-Log "Medal installer exited with code $($p.ExitCode)"}
      else{Write-Log 'Medal bootstrapper still running after 120 seconds; not forcing termination.' 'Yellow'}
      Start-Sleep -Seconds 5
      if(Find-App 'Medal'){Save-Result 'Medal' 'INSTALLED' 'Executable detected' 'User'}
      else{Save-Result 'Medal' 'REVIEW' 'Installer launched; app not yet detected (interactive setup may be needed)' 'User'}
    }
  }
}catch{Save-Result 'Medal' 'FAILED' "Error: $_" 'User'}
Write-Log 'Phase 2: request ONE UAC elevation for machine-wide applications.' 'Cyan'
try {
  $adminScript=Join-Path $PSScriptRoot 'Phoenix-Admin.ps1'
  $argsText='-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $adminScript
  $process=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -ArgumentList $argsText -Wait -PassThru
  Write-Log "Admin phase exited with code $($process.ExitCode)" 'Cyan'
}catch {Write-Log "Admin phase was canceled or failed: $_" 'Yellow'}
Write-Log 'Phase 3: Create ONLY missing shortcuts in the signed-in user desktop.' 'Cyan'
foreach($name in @('NVIDIA App','Google Chrome','Wireshark','Discord','Steam','Epic Games Launcher','Visual Studio Code','Spotify','Medal')) {
  try {
    $exe=Find-App $name
    $appId=if($name -eq 'Spotify'){Get-SpotifyStoreAppId}else{$null}
    if($exe -or $appId){Ensure-Shortcut $name $exe $appId}
    else{Write-Log "No desktop shortcut created for $name (executable not detected)" 'Yellow'}
  }catch {Write-Log "Shortcut processing failed for ${name}: $_" 'Yellow'}
}
Write-Log '=== USER APP RESULTS ===' 'Cyan'
if($script:Results.Count -gt 0) {
  $script:Results | Format-Table Application,Phase,Status,Details -AutoSize | Out-Host
}
Write-Log 'Admin-phase results were displayed during the elevated stage above.' 'Cyan'
Write-Log 'No installation reports or application logs were written by PhoenixDeploy.' 'Green'
