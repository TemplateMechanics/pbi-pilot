<#
.SYNOPSIS
    Discovers the local Analysis Services port that Power BI Desktop is using.

.DESCRIPTION
    Power BI Desktop runs a local Analysis Services (msmdsrv.exe) instance on a 
    dynamically assigned port. This script finds that port by scanning the 
    AnalysisServicesWorkspaces folder for the msmdsrv.port.txt file.

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

# Power BI Desktop stores workspace data in the user's local app data
$searchPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces",
    "$env:LOCALAPPDATA\Packages\Microsoft.MicrosoftPowerBIDesktop_8wekyb3d8bbwe\LocalCache\Local\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces"
)

$portFile = $null
foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {
        $portFile = Get-ChildItem -Path $basePath -Filter "msmdsrv.port.txt" -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($portFile) { break }
    }
}

if (-not $portFile) {
    # Fallback: check running msmdsrv.exe processes for the port
    $pbiProcess = Get-Process -Name "msmdsrv" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "*Power BI*" } |
        Select-Object -First 1

    if ($pbiProcess) {
        Write-Warning "Found msmdsrv.exe process (PID: $($pbiProcess.Id)) but could not locate port file."
        Write-Warning "Try using netstat to find the listening port:"
        Write-Warning "  netstat -ano | findstr $($pbiProcess.Id)"
    }

    throw "Could not find Power BI Desktop's Analysis Services port file. Is Power BI Desktop running with a file open?"
}

$port = [int](Get-Content $portFile.FullName -Raw).Trim()

Write-Host "Found Power BI Desktop Analysis Services instance on localhost:$port" -ForegroundColor Green
Write-Host "  Port file: $($portFile.FullName)" -ForegroundColor DarkGray
Write-Host "  Last modified: $($portFile.LastWriteTime)" -ForegroundColor DarkGray

return $port
