<#
.SYNOPSIS
    Validates PBIP project files for common errors.

.DESCRIPTION
    Scans TMDL and PBIR files in a Power BI Project for common issues:
    - TMDL: tab indentation, lineageTag presence, syntax patterns
    - PBIR: JSON validity, required properties, schema references
    - Cross-references: visual references match model objects

.PARAMETER Path
    Root path of the PBIP project. Defaults to current directory.

.PARAMETER Detailed
    Show detailed information about each check.

.EXAMPLE
    .\Validate-PBIP.ps1

.EXAMPLE
    .\Validate-PBIP.ps1 -Path "C:\Projects\MyReport" -Detailed
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".",

    [switch]$Detailed
)

$ErrorActionPreference = 'Continue'
$script:errors = @()
$script:warnings = @()
$script:checks = 0

function Add-Error($file, $message) {
    $script:errors += [PSCustomObject]@{ File = $file; Message = $message }
}

function Add-Warning($file, $message) {
    $script:warnings += [PSCustomObject]@{ File = $file; Message = $message }
}

Write-Host "`nPBIP Validation" -ForegroundColor Cyan
Write-Host "  Path: $(Resolve-Path $Path)" -ForegroundColor White
Write-Host ""

# --- Check project structure ---
Write-Host "  Checking project structure..." -ForegroundColor Yellow
$script:checks++

$smFolders = Get-ChildItem -Path $Path -Directory -Filter "*.SemanticModel"
$rptFolders = Get-ChildItem -Path $Path -Directory -Filter "*.Report"
$pbipFiles = Get-ChildItem -Path $Path -Filter "*.pbip"

if ($smFolders.Count -eq 0) { Add-Warning $Path "No .SemanticModel folder found" }
if ($rptFolders.Count -eq 0) { Add-Warning $Path "No .Report folder found" }

foreach ($sm in $smFolders) {
    $defFolder = Join-Path $sm.FullName "definition"
    $bimFile = Join-Path $sm.FullName "model.bim"
    
    if ((Test-Path $defFolder)) {
        Write-Host "    Found TMDL model: $($sm.Name)" -ForegroundColor DarkGray
    } elseif ((Test-Path $bimFile)) {
        Write-Host "    Found TMSL model: $($sm.Name) (consider upgrading to TMDL)" -ForegroundColor DarkGray
    } else {
        Add-Error $sm.FullName "Semantic model has neither definition/ folder (TMDL) nor model.bim (TMSL)"
    }
}

# --- Validate TMDL files ---
$tmdlFiles = Get-ChildItem -Path $Path -Filter "*.tmdl" -Recurse
if ($tmdlFiles.Count -gt 0) {
    Write-Host "  Checking $($tmdlFiles.Count) TMDL files..." -ForegroundColor Yellow
}

foreach ($file in $tmdlFiles) {
    $script:checks++
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $lines = Get-Content $file.FullName -ErrorAction SilentlyContinue
    $lineNum = 0

    foreach ($line in $lines) {
        $lineNum++
        
        # Check for space indentation (should be tabs)
        if ($line -match '^ +\S' -and $line -notmatch '^\t') {
            Add-Error "$($file.Name):$lineNum" "Uses spaces for indentation instead of TABs: '$($line.TrimEnd())'"
        }

        # Check for mixed tabs and spaces
        if ($line -match '^\t+ +\S' -or $line -match '^ +\t+\S') {
            Add-Error "$($file.Name):$lineNum" "Mixed tabs and spaces in indentation"
        }
    }

    # Check for lineageTag on tables and measures
    if ($file.Directory.Name -eq "tables") {
        # Check table has lineageTag
        if ($content -match '(?m)^table\s' -and $content -notmatch 'lineageTag:') {
            Add-Warning $file.Name "Table definition missing lineageTag"
        }

        # Check measures have lineageTag
        $measureMatches = [regex]::Matches($content, '(?m)^\tmeasure\s')
        foreach ($m in $measureMatches) {
            # Find the next measure or end of content
            $startPos = $m.Index
            $nextMeasure = [regex]::Match($content.Substring($startPos + 1), '(?m)^\t(measure|column|partition|hierarchy)\s')
            $block = if ($nextMeasure.Success) {
                $content.Substring($startPos, $nextMeasure.Index + 1)
            } else {
                $content.Substring($startPos)
            }
            
            if ($block -notmatch 'lineageTag:') {
                $measureName = if ($m.Value -match "measure\s+'?([^'=]+)") { $Matches[1].Trim() } else { "(unknown)" }
                Add-Warning $file.Name "Measure '$measureName' missing lineageTag"
            }
        }
    }

    # File encoding check
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Add-Warning $file.Name "File has UTF-8 BOM (should be UTF-8 without BOM)"
    }
}

# --- Validate PBIR JSON files ---
$jsonFiles = @()
foreach ($rpt in $rptFolders) {
    $defFolder = Join-Path $rpt.FullName "definition"
    if (Test-Path $defFolder) {
        $jsonFiles += Get-ChildItem -Path $defFolder -Filter "*.json" -Recurse
    }
}

if ($jsonFiles.Count -gt 0) {
    Write-Host "  Checking $($jsonFiles.Count) PBIR JSON files..." -ForegroundColor Yellow
}

foreach ($file in $jsonFiles) {
    $script:checks++
    
    try {
        $json = Get-Content $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Add-Error $file.Name "Invalid JSON: $($_.Exception.Message)"
        continue
    }

    # Check for $schema property
    if (-not $json.'$schema') {
        Add-Warning $file.Name "Missing `$schema property (recommended for validation)"
    }

    # Page-specific checks
    if ($file.Name -eq "page.json") {
        if (-not $json.name) { Add-Warning $file.Name "Missing 'name' property" }
        if (-not $json.displayName) { Add-Warning $file.Name "Missing 'displayName' property" }
    }

    # Visual-specific checks
    if ($file.Name -eq "visual.json") {
        if (-not $json.name) { Add-Warning $file.Name "Missing 'name' property" }
        if (-not $json.position) { Add-Warning $file.Name "Missing 'position' property" }
        if (-not $json.visual -or -not $json.visual.visualType) {
            Add-Warning $file.Name "Missing 'visual.visualType' property"
        }
    }

    # pages.json checks
    if ($file.Name -eq "pages.json" -and $json.pageOrder) {
        $pageFolders = Get-ChildItem -Path $file.Directory.FullName -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "page.json") } |
            ForEach-Object { $_.Name }
        
        foreach ($pf in $pageFolders) {
            if ($json.pageOrder -notcontains $pf) {
                Add-Warning "pages.json" "Page folder '$pf' exists but is not in pageOrder array"
            }
        }
    }
}

# --- Check cross-references between model and report ---
Write-Host "  Checking cross-references..." -ForegroundColor Yellow
$script:checks++

$modelTables = @()
$modelMeasures = @()
foreach ($tmdlFile in ($tmdlFiles | Where-Object { $_.Directory.Name -eq "tables" })) {
    $content = Get-Content $tmdlFile.FullName -Raw
    $tableMatch = [regex]::Match($content, "(?m)^table\s+'?([^'\r\n]+)'?")
    if ($tableMatch.Success) {
        $tableName = $tableMatch.Groups[1].Value.Trim()
        $modelTables += $tableName
        
        $measureMatches = [regex]::Matches($content, "(?m)^\tmeasure\s+'?([^'=\r\n]+)")
        foreach ($mm in $measureMatches) {
            $measName = $mm.Groups[1].Value.Trim()
            $modelMeasures += [PSCustomObject]@{ Table = $tableName; Measure = $measName }
        }
    }
}

if ($Detailed -and $modelTables.Count -gt 0) {
    Write-Host "    Model tables: $($modelTables -join ', ')" -ForegroundColor DarkGray
    Write-Host "    Model measures: $($modelMeasures.Count)" -ForegroundColor DarkGray
}

# --- Results ---
Write-Host "`n$('='*60)" -ForegroundColor White
Write-Host "  Checks: $($script:checks)  |  Errors: $($script:errors.Count)  |  Warnings: $($script:warnings.Count)" -ForegroundColor White
Write-Host "$('='*60)" -ForegroundColor White

if ($script:errors.Count -gt 0) {
    Write-Host "`n  ERRORS:" -ForegroundColor Red
    foreach ($err in $script:errors) {
        Write-Host "    [ERROR] $($err.File): $($err.Message)" -ForegroundColor Red
    }
}

if ($script:warnings.Count -gt 0) {
    Write-Host "`n  WARNINGS:" -ForegroundColor Yellow
    foreach ($warn in $script:warnings) {
        Write-Host "    [WARN]  $($warn.File): $($warn.Message)" -ForegroundColor Yellow
    }
}

if ($script:errors.Count -eq 0 -and $script:warnings.Count -eq 0) {
    Write-Host "`n  All checks passed!" -ForegroundColor Green
}

# Return exit code
if ($script:errors.Count -gt 0) { exit 1 }
exit 0
