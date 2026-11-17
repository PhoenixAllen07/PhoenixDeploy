# PhoenixDeploy

A one-launch Windows 11 application bootstrapper written in Bash and PowerShell.

PhoenixDeploy installs your favorite apps from **one launcher** while keeping per-user installs separate from administrator installs.

## Applications

| Runs as your Windows user | Administrator phase |
|---|---|
| Discord (x64) | Google Chrome |
| Spotify | Wireshark |
| Medal (requires separate official installer) | Steam |
| | Epic Games Launcher |
| | Visual Studio Code |
| | NVIDIA App (NVIDIA GPU + Chocolatey required) |

## Quick start

1. Download or clone this repository on the **Windows 11 PC you want to configure**.
2. Ensure **WinGet/App Installer** is available (and Git Bash if using the Bash entry point).
3. **Medal:** obtain the official installer from https://medal.tv/ and save it as `MedalSetup.exe` beside the scripts. Third-party installer binaries are intentionally not redistributed in Git.
4. Sign in using your normal Windows account.
5. Double-click **`Run-Phoenix.cmd`** normally, **not Run as administrator**. Or run `bash install-phoenix.sh` from Git Bash.
6. Approve the Windows UAC prompt for the separate administrator phase if requested.
7. Read the completion status in the terminal.

## Project files

- `install-phoenix.sh` — Git Bash launcher.
- `Run-Phoenix.cmd` — Windows double-click launcher.
- `Install-PhoenixApps.ps1` — user-level installation and orchestration.
- `Phoenix-Admin.ps1` — machine-wide installation phase.
- `Phoenix-Common.ps1` — package, shortcut, and console helpers.
- `.gitignore` — excludes installers and generated artifacts.

The user and administrator phases are deliberately separated: Spotify's installer can reject administrator elevation. For the same reason, **do not elevate the entire launcher**.

## Behavior

- Checks known executable locations and attempts to skip installed applications.
- Requests silent WinGet installation wherever supported; vendor installers may still prompt.
- Creates missing desktop shortcuts while attempting to avoid duplicates.
- Does not create PhoenixDeploy-specific CSV or text logs. Windows and vendor installers may log separately.
- NVIDIA App is skipped when an NVIDIA GPU is not detected (for example, in VirtualBox).
- Medal uses a locally supplied web installer because its WinGet package previously returned a 404. Its installation may require interaction and may not be fully silent.

## Limitations

This is a personal automation project, **not a Windows OS image**. It configures an already-installed Windows 11 system. Application detection uses known executable paths and is not exhaustive; verify installation results. The scripts have not been independently tested on every Windows configuration.

Do not run against university- or organization-managed devices without authorization.
