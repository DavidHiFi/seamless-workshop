<#
Installs Seamless Workshop, a Windhawk mod, from the latest GitHub release.

    iwr 'https://raw.githubusercontent.com/DavidHiFi/seamless-workshop/main/Install-SeamlessWorkshop.ps1' -OutFile "$env:TEMP\Install-SeamlessWorkshop.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\Install-SeamlessWorkshop.ps1"

What it does:
  1. Finds Windhawk and its command-line tool, and checks the version (2.0 alpha or newer).
  2. Downloads seamless-workshop.wh.cpp and its .sha256 file from the latest release.
  3. Refuses to go on if the file does not match its checksum.
  4. Installs the mod with "windhawk-cli mod install --file", asking for admin rights if needed.
#>
[CmdletBinding()]
param(
    [string]$Repo = 'DavidHiFi/seamless-workshop',
    [string]$WindhawkDir
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$updater = 'https://github.com/DavidHiFi/windhawk-alpha-updater'

function Stop-Install([string]$Message) {
    Write-Host ''
    Write-Host "Seamless Workshop was not installed." -ForegroundColor Red
    Write-Host $Message
    exit 1
}

# 1. Windhawk and its command-line tool
$dirs = @()
if ($WindhawkDir) { $dirs += $WindhawkDir }
$dirs += (Join-Path $env:ProgramFiles 'Windhawk')
if (${env:ProgramFiles(x86)}) { $dirs += (Join-Path ${env:ProgramFiles(x86)} 'Windhawk') }
$running = Get-Process windhawk -ErrorAction SilentlyContinue | Select-Object -First 1
if ($running -and $running.Path) { $dirs += (Split-Path $running.Path -Parent) }
$dir = $dirs | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'windhawk.exe') } | Select-Object -First 1
if (-not $dir) {
    Stop-Install "Windhawk is not installed. Get it from https://windhawk.net, then update it to the latest alpha with $updater"
}
$cli = Join-Path $dir 'windhawk-cli.exe'
if (-not (Test-Path -LiteralPath $cli)) {
    Stop-Install "This Windhawk is too old: it has no command-line tool (windhawk-cli.exe). Update to the latest alpha with $updater, then run this again."
}
$verText = (& $cli --version 2>$null | Out-String).Trim()
$m = [regex]::Match($verText, '(\d+)\.(\d+)\.(\d+)')
if (-not $m.Success) {
    Stop-Install "Could not read the Windhawk version ('$verText'). Update to the latest alpha with $updater"
}
if ([int]$m.Groups[1].Value -lt 2) {
    Stop-Install "Windhawk $($m.Value) is too old. Seamless Workshop needs the 2.0 alpha or newer. Update with $updater"
}
Write-Host "Found Windhawk $($m.Value) in $dir"

# 2. Download the mod and its checksum
$base = "https://github.com/$Repo/releases/latest/download"
$work = Join-Path $env:TEMP ("seamless-workshop-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$file = Join-Path $work 'seamless-workshop.wh.cpp'
$sumFile = Join-Path $work 'seamless-workshop.wh.cpp.sha256'
try {
    Invoke-WebRequest -UseBasicParsing "$base/seamless-workshop.wh.cpp" -OutFile $file
    Invoke-WebRequest -UseBasicParsing "$base/seamless-workshop.wh.cpp.sha256" -OutFile $sumFile
} catch {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Install "Could not download the latest release from https://github.com/$Repo/releases ($($_.Exception.Message))"
}

# 3. Check the checksum
$want = ([regex]::Match((Get-Content -LiteralPath $sumFile -Raw), '[0-9a-fA-F]{64}')).Value
$have = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
if (-not $want -or $want -ne $have) {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Install 'The downloaded file does not match its checksum, so it was thrown away. Try again later, or install it by hand from the release page.'
}
Write-Host 'Download checked: the checksum matches.'

# 4. Install through the Windhawk command-line tool
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$cliArgs = "mod install --file `"$file`""
try {
    if ($isAdmin) {
        $p = Start-Process -FilePath $cli -ArgumentList $cliArgs -WindowStyle Hidden -PassThru -Wait
    } else {
        Write-Host 'Windows will ask for admin rights so Windhawk can install the mod.'
        $p = Start-Process -FilePath $cli -ArgumentList $cliArgs -Verb RunAs -WindowStyle Hidden -PassThru -Wait
    }
} catch {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Install "The install did not start: $($_.Exception.Message)"
}
Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
if ($p.ExitCode -ne 0) {
    Stop-Install "Windhawk could not install the mod (exit code $($p.ExitCode)). Open Windhawk and check that it is running, then try again."
}
Write-Host ''
Write-Host 'Seamless Workshop is installed. You will find it in Windhawk under Installed mods.' -ForegroundColor Green
