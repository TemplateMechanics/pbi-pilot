<#
.SYNOPSIS
    Opens a PBIP file in Power BI Desktop and optionally waits until it's ready.

.DESCRIPTION
    Locates Power BI Desktop (MSI or Store), opens the specified .pbip file,
    and optionally polls for the Analysis Services port to confirm the model
    is loaded and ready for TOM connections.

    Designed to be called by AI agents so the full open-and-wait cycle is automated.

.PARAMETER PbipPath
    Path to the .pbip file. If omitted, searches the current directory and subdirectories.

.PARAMETER Wait
    If set, polls for the Analysis Services port file until PBI Desktop is ready
    or the timeout is reached.

.PARAMETER TimeoutSeconds
    Maximum seconds to wait for PBI Desktop to load (default: 120).

.PARAMETER PassThru
    If set, returns the AS port number when -Wait is used.

.EXAMPLE
    .\Open-PBIPFile.ps1 -PbipPath ".\MyReport.pbip" -Wait

.EXAMPLE
    $port = .\Open-PBIPFile.ps1 -Wait -PassThru
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PbipPath,

    [switch]$Wait,

    [int]$TimeoutSeconds = 120,

    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

# ── Auto-discover PBIP file ──────────────────────────────────────────
if (-not $PbipPath) {
    $pbipFile = Get-ChildItem -Path "." -Filter "*.pbip" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pbipFile) {
        $pbipFile = Get-ChildItem -Path "." -Filter "*.pbip" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($pbipFile) {
        $PbipPath = $pbipFile.FullName
    }
}

if (-not $PbipPath -or -not (Test-Path $PbipPath)) {
    throw "Could not find a .pbip file. Specify -PbipPath or run from a PBIP project directory."
}

$PbipPath = Resolve-Path $PbipPath

# ── Check if PBI Desktop is already running ──────────────────────────
$alreadyRunning = Get-Process -Name "PBIDesktop" -ErrorAction SilentlyContinue
if ($alreadyRunning) {
    Write-Host "Power BI Desktop is already running (PID: $($alreadyRunning[0].Id))" -ForegroundColor Yellow
    Write-Host "  If you need to open a different file, close the current one first." -ForegroundColor Yellow
    Write-Host "  Use Restart-PBIDesktop.ps1 to close and reopen." -ForegroundColor Yellow

    if ($Wait) {
        # Already running — try to find the port immediately
        $port = & "$PSScriptRoot\Find-PBIDesktopPort.ps1" -ErrorAction SilentlyContinue 2>$null
        if ($port) {
            Write-Host "  Already connected on localhost:$port" -ForegroundColor Green
            if ($PassThru) { return $port }
            return
        }
    }
    return
}

# ── Find Power BI Desktop executable ─────────────────────────────────
$pbiExe = $null
$launchMethod = "exe"

$searchPaths = @(
    "${env:ProgramFiles}\Microsoft Power BI Desktop\bin\PBIDesktop.exe",
    "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop\bin\PBIDesktop.exe"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $pbiExe = $path
        break
    }
}

# Check Microsoft Store version
if (-not $pbiExe) {
    $storeApp = Get-AppxPackage -Name "Microsoft.MicrosoftPowerBIDesktop" -ErrorAction SilentlyContinue
    if ($storeApp) {
        $launchMethod = "store"
    }
}

if (-not $pbiExe -and $launchMethod -ne "store") {
    # Final fallback: try file association
    $launchMethod = "assoc"
}

# ── Launch PBI Desktop ───────────────────────────────────────────────
Write-Host "Opening Power BI Desktop" -ForegroundColor Cyan
Write-Host "  File: $PbipPath" -ForegroundColor White

switch ($launchMethod) {
    "exe" {
        Write-Host "  Executable: $pbiExe" -ForegroundColor DarkGray
        Start-Process $pbiExe -ArgumentList "`"$PbipPath`""
    }
    "store" {
        Write-Host "  Using Microsoft Store version" -ForegroundColor DarkGray
        Start-Process $PbipPath
    }
    "assoc" {
        Write-Host "  Using file association (PBI Desktop not found in standard locations)" -ForegroundColor Yellow
        Start-Process $PbipPath
    }
}

Write-Host "  Power BI Desktop is starting..." -ForegroundColor Green

# ── Wait for AS port (optional) ──────────────────────────────────────
if (-not $Wait) {
    Write-Host "  Use -Wait to poll until the model is loaded." -ForegroundColor DarkGray
    return
}

Write-Host "  Waiting for Analysis Services port (up to ${TimeoutSeconds}s)..." -ForegroundColor Yellow

$portSearchPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces",
    "$env:USERPROFILE\Microsoft\Power BI Desktop Store App\AnalysisServicesWorkspaces",
    "$env:LOCALAPPDATA\Packages\Microsoft.MicrosoftPowerBIDesktop_8wekyb3d8bbwe\LocalCache\Local\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces"
)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$port = $null
$lastDot = 0

while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    foreach ($basePath in $portSearchPaths) {
        if (Test-Path $basePath) {
            $portFile = Get-ChildItem -Path $basePath -Filter "msmdsrv.port.txt" -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($portFile) {
                try {
                    $port = [int]((Get-Content $portFile.FullName -Raw) -replace '[^\d]', '')
                    if ($port -gt 0) { break }
                } catch {
                    $port = $null
                }
            }
        }
    }
    if ($port) { break }

    # Progress dots every 5 seconds
    $elapsed = [int]$sw.Elapsed.TotalSeconds
    if ($elapsed -ge $lastDot + 5) {
        Write-Host "  ... ${elapsed}s" -ForegroundColor DarkGray
        $lastDot = $elapsed
    }

    Start-Sleep -Seconds 2
}

if ($port) {
    Write-Host "  Ready! Analysis Services on localhost:$port (took $([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor Green
    if ($PassThru) { return $port }
} else {
    Write-Warning "Timed out after ${TimeoutSeconds}s waiting for Analysis Services port."
    Write-Warning "Power BI Desktop may still be loading. Try running Find-PBIDesktopPort.ps1 later."
}
