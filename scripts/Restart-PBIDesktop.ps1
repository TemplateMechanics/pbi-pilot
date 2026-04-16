<#
.SYNOPSIS
    Automates the close and reopen cycle of Power BI Desktop for a given PBIP file.

.DESCRIPTION
    When external tools edit PBIP/TMDL/PBIR files, Power BI Desktop must be 
    restarted to pick up the changes. This script automates that cycle:
    1. Finds the running PBI Desktop process for the target file
    2. Gracefully closes it
    3. Waits for the process to exit
    4. Reopens the PBIP file in Power BI Desktop

    For semantic model-only changes, consider using Invoke-SemanticModelRefresh.ps1
    instead — it's faster and doesn't require a restart.

.PARAMETER PbipPath
    Path to the .pbip file or .pbir file to reopen. If not specified,
    the script searches the current directory.

.PARAMETER Force
    Skip the confirmation prompt and close PBI Desktop immediately.

.PARAMETER WaitSeconds
    Seconds to wait for PBI Desktop to close gracefully before force-killing. Default: 15.

.EXAMPLE
    .\Restart-PBIDesktop.ps1 -PbipPath ".\MyReport.pbip"

.EXAMPLE
    .\Restart-PBIDesktop.ps1 -Force
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PbipPath,

    [switch]$Force,

    [int]$WaitSeconds = 15
)

$ErrorActionPreference = 'Stop'

# Auto-discover the PBIP file
if (-not $PbipPath) {
    $pbipFile = Get-ChildItem -Path "." -Filter "*.pbip" | Select-Object -First 1
    if (-not $pbipFile) {
        # Try .pbir files as fallback
        $pbirFile = Get-ChildItem -Path "." -Filter "definition.pbir" -Recurse | Select-Object -First 1
        if ($pbirFile) {
            $PbipPath = $pbirFile.FullName
        }
    } else {
        $PbipPath = $pbipFile.FullName
    }
}

if (-not $PbipPath -or -not (Test-Path $PbipPath)) {
    throw "Could not find a .pbip or .pbir file. Specify -PbipPath or run from the PBIP root directory."
}

$PbipPath = Resolve-Path $PbipPath

Write-Host "Power BI Desktop Restart" -ForegroundColor Cyan
Write-Host "  File: $PbipPath" -ForegroundColor White

# Find PBI Desktop process
$pbiProcesses = Get-Process -Name "PBIDesktop" -ErrorAction SilentlyContinue
if (-not $pbiProcesses) {
    $pbiProcesses = Get-Process | Where-Object { $_.ProcessName -match "PBIDesktop|Power BI Desktop" } -ErrorAction SilentlyContinue
}

if ($pbiProcesses) {
    Write-Host "`n  Found $($pbiProcesses.Count) Power BI Desktop process(es)" -ForegroundColor Yellow
    
    if (-not $Force) {
        Write-Host "  WARNING: Unsaved changes in Power BI Desktop will be lost!" -ForegroundColor Red
        $confirm = Read-Host "  Close Power BI Desktop? (Y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "  Cancelled." -ForegroundColor Yellow
            return
        }
    }

    # Attempt graceful close
    foreach ($proc in $pbiProcesses) {
        Write-Host "  Closing PBI Desktop (PID: $($proc.Id))..." -ForegroundColor Yellow
        $proc.CloseMainWindow() | Out-Null
    }

    # Wait for graceful exit
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $WaitSeconds) {
        $remaining = Get-Process -Name "PBIDesktop" -ErrorAction SilentlyContinue
        if (-not $remaining) { break }
        Start-Sleep -Milliseconds 500
    }

    # Force kill if still running
    $remaining = Get-Process -Name "PBIDesktop" -ErrorAction SilentlyContinue
    if ($remaining) {
        Write-Host "  Force stopping PBI Desktop..." -ForegroundColor Red
        $remaining | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    Write-Host "  Power BI Desktop closed." -ForegroundColor Green
} else {
    Write-Host "  No running Power BI Desktop instance found." -ForegroundColor DarkGray
}

# Brief pause to ensure file locks are released
Start-Sleep -Seconds 2

# Find PBI Desktop executable
$pbiExe = $null
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

# Fallback: Microsoft Store version
if (-not $pbiExe) {
    $storeApp = Get-AppxPackage -Name "Microsoft.MicrosoftPowerBIDesktop" -ErrorAction SilentlyContinue
    if ($storeApp) {
        # For Store version, use shell execution
        Write-Host "`n  Reopening with default handler: $PbipPath" -ForegroundColor Cyan
        Start-Process $PbipPath
        Write-Host "  Power BI Desktop is starting..." -ForegroundColor Green
        Write-Host "  Wait for it to fully load before making more changes." -ForegroundColor Yellow
        return
    }
}

if ($pbiExe) {
    Write-Host "`n  Reopening: $PbipPath" -ForegroundColor Cyan
    Start-Process $pbiExe -ArgumentList "`"$PbipPath`""
    Write-Host "  Power BI Desktop is starting..." -ForegroundColor Green
} else {
    # Use default file association
    Write-Host "`n  PBI Desktop executable not found in standard locations." -ForegroundColor Yellow
    Write-Host "  Opening via file association..." -ForegroundColor Yellow
    Start-Process $PbipPath
}

Write-Host "  Wait for it to fully load before making more changes." -ForegroundColor Yellow
