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

.PARAMETER Refresh
    After applying TMDL changes, trigger a full data refresh (re-loads data from sources).
    Without this switch, only schema changes are pushed.

.EXAMPLE
    $port = .\Find-PBIDesktopPort.ps1
    .\Invoke-SemanticModelRefresh.ps1 -Port $port -TmdlPath ".\MyReport.SemanticModel\definition"

.EXAMPLE
    .\Invoke-SemanticModelRefresh.ps1 -PbipPath ".\MyReport.pbip" -Refresh
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Port,

    [Parameter(Mandatory = $false)]
    [string]$TmdlPath,

    [Parameter(Mandatory = $false)]
    [string]$PbipPath,

    [Parameter(Mandatory = $false)]
    [switch]$Refresh
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

# Determine which TOM package works for this PowerShell version
$isPSCore = $PSVersionTable.PSEdition -eq 'Core'
if ($isPSCore) {
    $preferredPackage = "microsoft.analysisservices.netcore.retail.amd64"
    $fallbackPackage  = "microsoft.analysisservices.retail.amd64"
} else {
    # PS 5.1 (.NET Framework) - must use the net45 package
    $preferredPackage = "microsoft.analysisservices.retail.amd64"
    $fallbackPackage  = "microsoft.analysisservices.netcore.retail.amd64"
}

# Option 1: Check if already loaded
try {
    [Microsoft.AnalysisServices.Tabular.TmdlSerializer] | Out-Null
    $tomLoaded = $true
    Write-Host "  TOM assemblies already loaded" -ForegroundColor DarkGray
} catch {}

# Option 2: Look for NuGet package in local cache
if (-not $tomLoaded) {
    $nugetPaths = @(
        "$env:USERPROFILE\.nuget\packages\$preferredPackage",
        "$env:USERPROFILE\.nuget\packages\$fallbackPackage"
    )
    foreach ($nugetBase in $nugetPaths) {
        if (Test-Path $nugetBase) {
            $latestVersion = Get-ChildItem $nugetBase -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latestVersion) {
                $dllPath = Get-ChildItem $latestVersion.FullName -Filter "Microsoft.AnalysisServices.Tabular.dll" -Recurse | Select-Object -First 1
                if ($dllPath) {
                    try {
                        Add-Type -Path $dllPath.FullName -ErrorAction Stop
                        $tomLoaded = $true
                        Write-Host "  Loaded TOM from: $($dllPath.FullName)" -ForegroundColor DarkGray
                        break
                    } catch {
                        Write-Verbose "Could not load $($dllPath.FullName): $_"
                    }
                }
            }
        }
    }
}

# Option 3: Look alongside PBI Desktop installation
if (-not $tomLoaded) {
    $pbiPaths = @(
        "${env:ProgramFiles}\Microsoft Power BI Desktop\bin",
        "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop\bin"
    )
    # Store version: find via running process path
    $pbiProc = Get-Process -Name "PBIDesktop" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pbiProc -and $pbiProc.Path) {
        $pbiPaths = @(Split-Path $pbiProc.Path -Parent) + $pbiPaths
    }
    foreach ($pbiPath in $pbiPaths) {
        $dll = Join-Path $pbiPath "Microsoft.AnalysisServices.Tabular.dll"
        if (Test-Path $dll) {
            try {
                Add-Type -Path $dll -ErrorAction Stop
                $tomLoaded = $true
                Write-Host "  Loaded TOM from PBI Desktop: $dll" -ForegroundColor DarkGray
                break
            } catch {
                Write-Verbose "Could not load $dll : $_"
            }
        }
    }
}

# Option 4: Auto-install from NuGet
if (-not $tomLoaded) {
    Write-Host "`n  TOM assemblies not found. Installing $preferredPackage..." -ForegroundColor Yellow

    $installed = $false
    $nugetSource = "https://api.nuget.org/v3/index.json"

    # Strategy A: dotnet CLI
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) {
        Write-Host "  Using dotnet CLI..." -ForegroundColor DarkGray
        $tmpDir = Join-Path $env:TEMP "tom-install-$(Get-Random)"
        try {
            New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
            Push-Location $tmpDir
            & dotnet new classlib --no-restore 2>$null | Out-Null
            $addOutput = & dotnet add package $preferredPackage --source $nugetSource 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
                Write-Host "  Package installed via dotnet CLI" -ForegroundColor Green
            } else {
                Write-Verbose "dotnet add failed: $addOutput"
            }
            Pop-Location
        } catch {
            Write-Verbose "dotnet install failed: $_"
            if ((Get-Location).Path -eq $tmpDir) { Pop-Location }
        } finally {
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Strategy B: Direct NuGet download (no dotnet SDK required)
    if (-not $installed) {
        Write-Host "  Downloading package directly from NuGet..." -ForegroundColor DarkGray
        $nugetApiUrl = "https://api.nuget.org/v3-flatcontainer/$preferredPackage/index.json"
        try {
            $versions = (Invoke-RestMethod -Uri $nugetApiUrl -ErrorAction Stop).versions
            $pkgVersion = $versions[-1]
            $nupkgUrl = "https://api.nuget.org/v3-flatcontainer/$preferredPackage/$pkgVersion/$preferredPackage.$pkgVersion.nupkg"
            $destDir = Join-Path "$env:USERPROFILE\.nuget\packages" "$preferredPackage\$pkgVersion"
            $nupkgPath = Join-Path $env:TEMP "$preferredPackage.$pkgVersion.nupkg"

            Write-Host "  Downloading $preferredPackage v$pkgVersion..." -ForegroundColor DarkGray
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -UseBasicParsing -ErrorAction Stop

            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            Expand-Archive -Path $nupkgPath -DestinationPath $destDir -Force
            Remove-Item $nupkgPath -ErrorAction SilentlyContinue
            $installed = $true
            Write-Host "  Package downloaded and extracted" -ForegroundColor Green
        } catch {
            Write-Warning "Direct download failed: $_"
        }
    }

    # Try loading from cache after install
    if ($installed) {
        foreach ($nugetBase in $nugetPaths) {
            if (Test-Path $nugetBase) {
                $latestVersion = Get-ChildItem $nugetBase -Directory | Sort-Object Name -Descending | Select-Object -First 1
                if ($latestVersion) {
                    $dllPath = Get-ChildItem $latestVersion.FullName -Filter "Microsoft.AnalysisServices.Tabular.dll" -Recurse | Select-Object -First 1
                    if ($dllPath) {
                        try {
                            Add-Type -Path $dllPath.FullName -ErrorAction Stop
                            $tomLoaded = $true
                            Write-Host "  Loaded TOM from: $($dllPath.FullName)" -ForegroundColor DarkGray
                            break
                        } catch {
                            Write-Verbose "Could not load $($dllPath.FullName): $_"
                        }
                    }
                }
            }
        }
    }

    if (-not $tomLoaded) {
        throw "TOM client libraries could not be loaded. Try installing manually:`n  dotnet add package $preferredPackage --source $nugetSource"
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
    $newDb = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeDatabaseFromFolder($TmdlPath)

    Write-Host "  Applying changes to running model..." -ForegroundColor Cyan
    
    $targetDb = $server.Databases[0]
    
    # Copy measures, columns, tables, relationships from the TMDL definition
    # Using the model's CopyTo approach for a full sync
    $newDb.Model.CopyTo($targetDb.Model)
    $targetDb.Model.SaveChanges()

    Write-Host "`n  SUCCESS: Semantic model updated in Power BI Desktop!" -ForegroundColor Green

    if ($Refresh) {
        Write-Host "`n  Triggering data refresh (loading data from sources)..." -ForegroundColor Cyan
        $targetDb.Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Full)
        $targetDb.Model.SaveChanges()
        Write-Host "  SUCCESS: Data refresh completed!" -ForegroundColor Green
    }

    Write-Host "  Changes should now be visible in the report." -ForegroundColor Green
} catch {
    Write-Host "`n  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  If this fails, try Restart-PBIDesktop.ps1 instead." -ForegroundColor Yellow
    throw
} finally {
    $server.Disconnect()
}
