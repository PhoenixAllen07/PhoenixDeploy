# Machine installation phase; elevated via UAC from the normal-user launcher.
param()
. (Join-Path $PSScriptRoot 'Phoenix-Common.ps1')
if(-not (Get-IsAdmin)){throw 'Machine phase requires administrator privileges.'}
Write-Log '=== ELEVATED MACHINE PHASE ===' 'Cyan'
$apps=@(
  @{Name='Google Chrome';Id='Google.Chrome';Scope='machine'},
  @{Name='Wireshark';Id='WiresharkFoundation.Wireshark';Scope='machine'},
  @{Name='Steam';Id='Valve.Steam';Scope=''},
  @{Name='Epic Games Launcher';Id='EpicGames.EpicGamesLauncher';Scope=''},
  @{Name='Visual Studio Code';Id='Microsoft.VisualStudioCode';Scope='machine'}
)
foreach($app in $apps) {
  $name=$app.Name
  try {
    $before=Find-App $name
    if($before){Save-Result $name 'SKIPPED' "Executable already exists: $before" 'Machine';continue}
    $rc=Invoke-Winget $name $app.Id $app.Scope
    Start-Sleep -Seconds 2
    $after=Find-App $name
    if($after){Save-Result $name 'INSTALLED' "Executable: $after; winget exit=$rc" 'Machine'}
    elseif($rc -eq 0){Save-Result $name 'REVIEW' 'WinGet returned success but executable was not found' 'Machine'}
    else {Save-Result $name 'FAILED' "WinGet exit=$rc" 'Machine'}
  }catch {Save-Result $name 'FAILED' "Unexpected error: $_" 'Machine'}
}
# NVIDIA App is not compatible with normal VirtualBox virtual graphics; attempt only on an actual NVIDIA machine.
try {
  $existing=Find-App 'NVIDIA App'
  $gpu=@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object {$_.Name -match 'NVIDIA'}).Count -gt 0
  if($existing){Save-Result 'NVIDIA App' 'SKIPPED' "Already exists: $existing" 'Machine'}
  elseif(-not $gpu){Save-Result 'NVIDIA App' 'SKIPPED' 'No NVIDIA GPU detected (expected inside VirtualBox)' 'Machine'}
  elseif(Get-Command choco.exe -ErrorAction SilentlyContinue) {
    Write-Log 'NVIDIA GPU detected; attempting Chocolatey nvidia-app package' 'Cyan'
    & choco.exe install nvidia-app -y --no-progress --limit-output 2>&1 | ForEach-Object {Write-Log "  $_"}
    $rc=$LASTEXITCODE
    if(Find-App 'NVIDIA App'){Save-Result 'NVIDIA App' 'INSTALLED' 'Executable verified' 'Machine'}
    else{Save-Result 'NVIDIA App' 'REVIEW' "Installer exit=$rc; verify GPU drivers and application" 'Machine'}
  } else {
    Save-Result 'NVIDIA App' 'REVIEW' 'NVIDIA GPU detected; Chocolatey not available. Install NVIDIA App from official NVIDIA website.' 'Machine'
  }
}catch{Save-Result 'NVIDIA App' 'FAILED' "Unexpected error: $_" 'Machine'}

Write-Log '=== MACHINE APP RESULTS ===' 'Cyan'
if($script:Results.Count -gt 0) {
  $script:Results | Format-Table Application,Phase,Status,Details -AutoSize | Out-Host
}
