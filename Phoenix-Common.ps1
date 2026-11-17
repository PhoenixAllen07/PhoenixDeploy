$ErrorActionPreference='Stop'
# Console-only status reporting. This project writes no CSV or text logs.
$script:Results = [System.Collections.Generic.List[object]]::new()
function Write-Log([string]$Text,[string]$Color='Gray') {
  Write-Host $Text -ForegroundColor $Color
}
function Save-Result([string]$App,[string]$Status,[string]$Detail,[string]$Phase) {
  $script:Results.Add([pscustomobject]@{Application=$App;Phase=$Phase;Status=$Status;Details=$Detail})
  $color=if($Status -in @('FAILED','REVIEW')){'Yellow'}else{'Green'}
  Write-Log "$App => $Status : $Detail" $color
}
function Find-App([string]$Name) {
  $pf=$env:ProgramFiles; $pf86=${env:ProgramFiles(x86)}; $la=$env:LOCALAPPDATA
  $patterns=switch($Name) {
    'Google Chrome' { @("$pf\Google\Chrome\Application\chrome.exe","$pf86\Google\Chrome\Application\chrome.exe") }
    'Wireshark' { @("$pf\Wireshark\Wireshark.exe","$pf86\Wireshark\Wireshark.exe") }
    'Discord' { @("$la\Discord\app-*\Discord.exe","$la\Programs\Discord\Discord.exe") }
    'Steam' { @("$pf86\Steam\steam.exe","$pf\Steam\steam.exe") }
    'Epic Games Launcher' { @("$pf\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe","$pf86\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe") }
    'Visual Studio Code' { @("$la\Programs\Microsoft VS Code\Code.exe","$pf\Microsoft VS Code\Code.exe","$pf86\Microsoft VS Code\Code.exe") }
    'Spotify' { @("$la\Spotify\Spotify.exe","$la\Programs\Spotify\Spotify.exe") }
    'Medal' { @("$la\Medal\Medal.exe","$la\Medal\app-*\Medal.exe","$la\Programs\Medal\Medal.exe","$la\Programs\Medal\app-*\Medal.exe") }
    'NVIDIA App' { @("$pf\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe","$pf\NVIDIA Corporation\NVIDIA app\NVIDIA app.exe") }
    default { @() }
  }
  foreach($p in $patterns) {
    if(-not $p){continue}
    $a=@(Get-Item -Path $p -ErrorAction SilentlyContinue | Where-Object {-not $_.PSIsContainer} | Sort-Object FullName -Descending)
    if($a.Count){return $a[0].FullName}
  }
  return $null
}
function Get-SpotifyStoreAppId {
  $pkg=Get-AppxPackage -Name 'SpotifyAB.SpotifyMusic' -ErrorAction SilentlyContinue
  if($pkg) {
    $item=Get-StartApps | Where-Object {$_.Name -match '^Spotify'} | Select-Object -First 1
    if($item){return $item.AppID}
  }
  return $null
}
function Ensure-Shortcut([string]$Name,[string]$Exe,[string]$AppId) {
  $folders=@([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('CommonDesktopDirectory')) | Where-Object {$_ -and (Test-Path -LiteralPath $_)} | Select-Object -Unique
  if(-not $folders.Count){return}
  $wsh=New-Object -ComObject WScript.Shell
  $matches=@()
  foreach($folder in $folders) {
    foreach($file in @(Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -File -ErrorAction SilentlyContinue)) {
      try {
        $shortcut=$wsh.CreateShortcut($file.FullName)
        $target=[Environment]::ExpandEnvironmentVariables([string]$shortcut.TargetPath)
        $byExe=$Exe -and $target -and ($target -ieq $Exe)
        $byName=$file.BaseName -ieq $Name
        if($byExe -or $byName) {$matches+=,$file}
      }catch{}
    }
  }
  if($matches.Count) {
    # Preserve an existing app shortcut; only eliminate duplicates with the same actual executable.
    $primary=@($matches | Sort-Object CreationTime,FullName)[0]
    foreach($other in @($matches | Where-Object {$_.FullName -ne $primary.FullName})) {
      try {
        $a=$wsh.CreateShortcut($primary.FullName)
        $b=$wsh.CreateShortcut($other.FullName)
        if($a.TargetPath -and ($a.TargetPath -ieq $b.TargetPath)) {
          Remove-Item -LiteralPath $other.FullName -Force
          Write-Log "Removed confirmed duplicate: $($other.FullName)" 'DarkCyan'
        }
      }catch {Write-Log "Could not inspect/remove duplicate: $_" 'Yellow'}
    }
    Write-Log "Shortcut already present for $Name; not adding another." 'DarkCyan'
    return
  }
  $dest=Join-Path $folders[0] "$Name.lnk"
  if(Test-Path -LiteralPath $dest){return}
  $s=$wsh.CreateShortcut($dest)
  if($Exe){$s.TargetPath=$Exe;$s.WorkingDirectory=Split-Path $Exe -Parent;$s.IconLocation="$Exe,0"}
  elseif($AppId){$s.TargetPath="$env:WINDIR\explorer.exe";$s.Arguments="shell:AppsFolder\$AppId"}
  else {return}
  $s.Save()
  Write-Log "Created shortcut: $dest" 'DarkCyan'
}
function Invoke-Winget([string]$Name,[string]$Id,[string]$Scope='', [switch]$X64) {
  $args=@('install','--id',$Id,'--exact','--source','winget','--silent','--no-upgrade','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
  if($Scope){$args+=@('--scope',$Scope)}
  if($X64){$args+=@('--architecture','x64')}
  Write-Log "WinGet: $Name [$Id] (scope=$Scope)" 'Cyan'
  try {
    & winget.exe @args 2>&1 | ForEach-Object {if($_){Write-Log "  $_"}}
    $code=$LASTEXITCODE
    Write-Log "WinGet exit=$code"
    return $code
  }catch {Write-Log "WinGet threw error: $_" 'Yellow';return -1}
}
function Get-IsAdmin {
  $ident=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=[Security.Principal.WindowsPrincipal]::new($ident)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
