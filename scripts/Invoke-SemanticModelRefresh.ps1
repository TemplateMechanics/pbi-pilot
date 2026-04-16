<#
.SYNOPSIS
    Pushes semantic model (TMDL) changes to a running Power BI Desktop instance via TOM.

.DESCRIPTION
    Connects to Power BI Desktop's local Analysis Services instance and deploys
    the TMDL definition from disk. This avoids needing to close and reopen 
    Power BI Desktop for semantic model changes (measures, columns, relationships, etc.).

    NOTE: This does NOT work for report layout changes (PBIR). For those,
    use Restart-PBIDesktop.ps1.

    Requires the Microsoft.AnalysisServices.NetCore.retail.amd64 NuGet package 
    or the AMO/TOM client libraries. The script will attempt to auto-download if not found.

.PARAMETER Port
    The local Analysis Services port. Use Find-PBIDesktopPort.ps1 to discover it.

.PARAMETER TmdlPath
    Path to the TMDL definition folder (e.g., ".\MyReport.SemanticModel\definition").

.PARAMETER PbipPath
    Alternative: path to the .SemanticModel folder. The script will append \definition.

.EXAMPLE
    $port = .\Find-PBIDesktopPort.ps1
    .\Invoke-SemanticModelRefresh.ps1 -Port $port -TmdlPath ".\MyReport.SemanticModel\definition"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Port,

    [Parameter(Mandatory = $false)]
    [string]$TmdlPath,

    [Parameter(Mandatory = $false)]
    [string]$PbipPath
)

$ErrorActionPreference = 'Stop'

# Resolve the TMDL path
if ($PbipPath -and -not $TmdlPath) {
    if ($PbipPath -match '\.SemanticModel[/\\]?$') {
        $TmdlPath = Join-Path $PbipPath "definition"
    } elseif ($PbipPath -match '\.pbip$') {
        $smFolder = Get-ChildItem -Path (Split-Path $PbipPath -Parent) -Directory -Filter "*.SemanticModel" | Select-Object -First 1
        if ($smFolder) {
            $TmdlPath = Join-Path $smFolder.FullName "definition"
        }
    }
}

if (-not $TmdlPath -or -not (Test-Path $TmdlPath)) {
    # Auto-discover from current directory
    $smFolder = Get-ChildItem -Path "." -Directory -Filter "*.SemanticModel" | Select-Object -First 1
    if ($smFolder) {
        $defPath = Join-Path $smFolder.FullName "definition"
        $bimPath = Join-Path $smFolder.FullName "model.bim"
        if (Test-Path $defPath) {
            $TmdlPath = $defPath
        } elseif (Test-Path $bimPath) {
            throw "This semantic model uses TMSL (model.bim), not TMDL. Convert to TMDL in Power BI Desktop first."
        }
    }
    if (-not $TmdlPath -or -not (Test-Path $TmdlPath)) {
        throw "Could not find TMDL definition folder. Specify -TmdlPath or -PbipPath, or run from the PBIP root directory."
    }
}

$TmdlPath = Resolve-Path $TmdlPath

# Auto-discover port if not provided
if (-not $Port) {
    Write-Host "No port specified, auto-discovering..." -ForegroundColor Yellow
    $Port = & (Join-Path $PSScriptRoot "Find-PBIDesktopPort.ps1")
}

Write-Host "`nSemantic Model Refresh via TOM" -ForegroundColor Cyan
Write-Host "  Target: localhost:$Port" -ForegroundColor White
Write-Host "  TMDL:   $TmdlPath" -ForegroundColor White

# Try to load TOM assemblies
$tomLoaded = $false

# Option 1: Check if already loaded
try {
    [Microsoft.AnalysisServices.Tabular.TmdlSerializer] | Out-Null
    $tomLoaded = $true
    Write-Host "  TOM assemblies already loaded" -ForegroundColor DarkGray
} catch {}

# Option 2: Look for NuGet package in local cache
if (-not $tomLoaded) {
    $nugetPaths = @(
        "$env:USERPROFILE\.nuget\packages\microsoft.analysisservices.netcore.retail.amd64",
        "$env:USERPROFILE\.nuget\packages\microsoft.analysisservices.retail.amd64"
    )
    foreach ($nugetBase in $nugetPaths) {
        if (Test-Path $nugetBase) {
            $latestVersion = Get-ChildItem $nugetBase -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latestVersion) {
                $dllPath = Get-ChildItem $latestVersion.FullName -Filter "Microsoft.AnalysisServices.Tabular.dll" -Recurse | Select-Object -First 1
                if ($dllPath) {
                    Add-Type -Path $dllPath.FullName
                    $tomLoaded = $true
                    Write-Host "  Loaded TOM from: $($dllPath.FullName)" -ForegroundColor DarkGray
                    break
                }
            }
        }
    }
}

# Option 3: Look alongside PBI Desktop installation
if (-not $tomLoaded) {
    $pbiPaths = @(
        "${env:ProgramFiles}\Microsoft Power BI Desktop\bin",
        "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop\bin",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"  
    )
    foreach ($pbiPath in $pbiPaths) {
        $dll = Join-Path $pbiPath "Microsoft.AnalysisServices.Tabular.dll"
        if (Test-Path $dll) {
            Add-Type -Path $dll
            $tomLoaded = $true
            Write-Host "  Loaded TOM from PBI Desktop: $dll" -ForegroundColor DarkGray
            break
        }
    }
}

if (-not $tomLoaded) {
    Write-Host "`n  TOM assemblies not found. Installing via NuGet..." -ForegroundColor Yellow
    
    # Try Install-Package
    try {
        Install-Package Microsoft.AnalysisServices.NetCore.retail.amd64 -Source nuget.org -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
        $pkg = Get-Package Microsoft.AnalysisServices.NetCore.retail.amd64 -ErrorAction Stop
        $dllPath = Get-ChildItem (Split-Path $pkg.Source -Parent) -Filter "Microsoft.AnalysisServices.Tabular.dll" -Recurse | Select-Object -First 1
        if ($dllPath) {
            Add-Type -Path $dllPath.FullName
            $tomLoaded = $true
        }
    } catch {
        Write-Warning "Auto-install failed. Please install manually:"
        Write-Warning "  Install-Package Microsoft.AnalysisServices.NetCore.retail.amd64 -Source nuget.org"
        Write-Warning "  - OR -"
        Write-Warning "  dotnet add package Microsoft.AnalysisServices.NetCore.retail.amd64"
        throw "TOM client libraries not available. See above for installation instructions."
    }
}

# Connect and deploy
Write-Host "`nConnecting to localhost:$Port..." -ForegroundColor Cyan

$connectionString = "Data Source=localhost:$Port"
$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect($connectionString)

try {
    $dbName = $server.Databases[0].Name
    Write-Host "  Connected to database: $dbName" -ForegroundColor Green

    Write-Host "  Deserializing TMDL from disk..." -ForegroundColor Cyan
    $newDb = [Microsoft.AnalysisServices.TmdlSerializer]::DeserializeDatabaseFromFolder($TmdlPath)

    Write-Host "  Applying changes to running model..." -ForegroundColor Cyan
    
    $targetDb = $server.Databases[0]
    
    # Copy measures, columns, tables, relationships from the TMDL definition
    # Using the model's CopyTo approach for a full sync
    $newDb.Model.CopyTo($targetDb.Model)
    $targetDb.Model.SaveChanges()

    Write-Host "`n  SUCCESS: Semantic model updated in Power BI Desktop!" -ForegroundColor Green
    Write-Host "  Changes should now be visible in the report." -ForegroundColor Green
} catch {
    Write-Host "`n  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  If this fails, try Restart-PBIDesktop.ps1 instead." -ForegroundColor Yellow
    throw
} finally {
    $server.Disconnect()
}
