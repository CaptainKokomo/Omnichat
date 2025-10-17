param()

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
  throw 'Omnichat installer must be run on Windows PowerShell.'
}

$scriptPath = if ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } elseif ($PSCommandPath) { $PSCommandPath } else { $null }
$scriptRoot = if ($scriptPath) { Split-Path -Parent $scriptPath } else { Get-Location }
$appPayload = Join-Path $scriptRoot 'app'

if (-not (Test-Path $appPayload)) {
  throw 'Missing "app" folder next to Omnichat.install.ps1. Download the full Omnichat package and run the setup again.'
}

$installRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Omnichat'
$desktop = [Environment]::GetFolderPath('Desktop')
$electronVersion = '28.2.0'
$electronZip = Join-Path ([IO.Path]::GetTempPath()) "electron-$electronVersion.zip"
$electronUrl = "https://github.com/electron/electron/releases/download/v$electronVersion/electron-v$electronVersion-win32-x64.zip"

Write-Host "Installing Omnichat to $installRoot"

$running = Get-Process -Name 'Omnichat' -ErrorAction SilentlyContinue
if ($running) {
  Write-Host 'Closing running Omnichat instances...'
  $running | Stop-Process -Force
  Start-Sleep -Seconds 1
}

if (Test-Path $installRoot) {
  Write-Host 'Removing previous installation...'
  Remove-Item -Path $installRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null

Write-Host "Downloading Electron runtime $electronVersion..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $electronUrl -OutFile $electronZip

Write-Host 'Extracting runtime...'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($electronZip, $installRoot)
Remove-Item $electronZip -Force

Rename-Item -Path (Join-Path $installRoot 'electron.exe') -NewName 'Omnichat.exe'

Write-Host 'Cleaning default Electron resources...'
$defaultApp = Join-Path $installRoot 'resources/default_app.asar'
if (Test-Path $defaultApp) {
  Remove-Item $defaultApp -Force
}

Write-Host 'Copying Omnichat application files...'
$appDestination = Join-Path $installRoot 'resources/app'
if (Test-Path $appDestination) {
  Remove-Item -Path $appDestination -Recurse -Force
}
New-Item -ItemType Directory -Path $appDestination -Force | Out-Null
Copy-Item -Path (Join-Path $appPayload '*') -Destination $appDestination -Recurse -Force

Write-Host 'Creating desktop shortcut...'
$shortcutPath = Join-Path $desktop 'Omnichat.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $installRoot 'Omnichat.exe'
$shortcut.WorkingDirectory = $installRoot
$shortcut.IconLocation = Join-Path $installRoot 'Omnichat.exe'
$shortcut.Save()

Write-Host 'Launching Omnichat...'
Start-Process -FilePath (Join-Path $installRoot 'Omnichat.exe')

Write-Host 'Installation complete. Omnichat is ready to use.'
