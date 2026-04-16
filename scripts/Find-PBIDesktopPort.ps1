<#
.SYNOPSIS
    Discovers the local Analysis Services port that Power BI Desktop is using.

.DESCRIPTION
    Power BI Desktop runs a local Analysis Services (msmdsrv.exe) instance on a
    dynamically assigned port. This script finds that port using a multi-strategy 
    approach that works for both MSI and Microsoft Store installs:

    1. Scans known port-file locations for msmdsrv.port.txt
    2. Falls back to parsing the msmdsrv.exe command-line data directory
    3. Falls back to netstat to find the listening port by PID

    The port can then be used to connect via TOM (Tabular Object Model) to push
    semantic model changes without restarting Power BI Desktop.

.OUTPUTS
    [int] The port number of the local Analysis Services instance.

.EXAMPLE
    $port = .\Find-PBIDesktopPort.ps1
    Write-Host "PBI Desktop AS instance running on localhost:$port"

.EXAMPLE
    # Use with Invoke-SemanticModelRefresh
    $port = .\Find-PBIDesktopPort.ps1
    .\Invoke-SemanticModelRefresh.ps1 -Port $port -TmdlPath ".\MyReport.SemanticModel\definition"
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ── Strategy 1: Scan known port-file locations ───────────────────────
# MSI install, Store install (user profile), Store install (package cache)
$searchPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces",
    "$env:USERPROFILE\Microsoft\Power BI Desktop Store App\AnalysisServicesWorkspaces",
    "$env:LOCALAPPDATA\Packages\Microsoft.MicrosoftPowerBIDesktop_8wekyb3d8bbwe\LocalCache\Local\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces"
)

$portFile = $null
foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {
        Write-Verbose "Checking: $basePath"
        $portFile = Get-ChildItem -Path $basePath -Filter "msmdsrv.port.txt" -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($portFile) { break }
    }
}

if ($portFile) {
    $portRaw = (Get-Content $portFile.FullName -Raw) -replace '[^\d]', ''
    $port = [int]$portRaw
    Write-Host "Found Power BI Desktop Analysis Services instance on localhost:$port" -ForegroundColor Green
    Write-Host "  Method:   port file" -ForegroundColor DarkGray
    Write-Host "  Location: $($portFile.FullName)" -ForegroundColor DarkGray
    Write-Host "  Modified: $($portFile.LastWriteTime)" -ForegroundColor DarkGray
    return $port
}

# ── Strategy 2: Parse msmdsrv.exe command line for data directory ────
Write-Verbose "Port file not found in known locations, checking msmdsrv process..."
$msmdsrvProc = Get-Process -Name "msmdsrv" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "*Power BI*" } |
    Select-Object -First 1

if ($msmdsrvProc) {
    $wmiProc = Get-CimInstance Win32_Process -Filter "ProcessId = $($msmdsrvProc.Id)" -ErrorAction SilentlyContinue
    if ($wmiProc -and $wmiProc.CommandLine -match '-s\s+"?([^"]+)"?') {
        $dataDir = $Matches[1]
        Write-Verbose "msmdsrv data directory: $dataDir"
        $portFilePath = Join-Path $dataDir "msmdsrv.port.txt"
        if (Test-Path $portFilePath) {
            $port = [int]((Get-Content $portFilePath -Raw) -replace '[^\d]', '')
            Write-Host "Found Power BI Desktop Analysis Services instance on localhost:$port" -ForegroundColor Green
            Write-Host "  Method:   msmdsrv command line" -ForegroundColor DarkGray
            Write-Host "  Location: $portFilePath" -ForegroundColor DarkGray
            return $port
        }
    }

    # ── Strategy 3: netstat fallback ─────────────────────────────────
    Write-Verbose "Port file not in data directory, trying netstat for PID $($msmdsrvProc.Id)..."
    $netstatLine = netstat -ano 2>$null |
        Select-String "LISTENING" |
        Select-String "\s$($msmdsrvProc.Id)\s*$" |
        Select-Object -First 1

    if ($netstatLine -and $netstatLine -match ':(\d+)\s+\S+\s+LISTENING') {
        $port = [int]$Matches[1]
        Write-Host "Found Power BI Desktop Analysis Services instance on localhost:$port" -ForegroundColor Green
        Write-Host "  Method:   netstat (PID $($msmdsrvProc.Id))" -ForegroundColor DarkGray
        Write-Warning "Port file was not found - this port was inferred from the running process."
        return $port
    }

    Write-Warning "Found msmdsrv.exe (PID: $($msmdsrvProc.Id)) but could not determine port."
}

throw "Could not find Power BI Desktop's Analysis Services port. Is Power BI Desktop running with a file open?"
