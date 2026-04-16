<#
.SYNOPSIS
    Detects PBIR schema versions used in a Power BI Project.

.DESCRIPTION
    Scans all PBIR JSON files in a PBIP project and reports the $schema URLs
    and their versions. Useful for checking version consistency and identifying
    what schema versions Power BI Desktop is currently generating.

.PARAMETER Path
    Root path of the PBIP project. Defaults to current directory.

.EXAMPLE
    .\Get-PBIRSchemaVersions.ps1

.EXAMPLE
    .\Get-PBIRSchemaVersions.ps1 -Path "C:\Projects\MyReport"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = "."
)

$ErrorActionPreference = 'Continue'

$resolvedPath = Resolve-Path $Path -ErrorAction Stop
Write-Host "`nPBIR Schema Version Report" -ForegroundColor Cyan
Write-Host "  Path: $resolvedPath" -ForegroundColor White
Write-Host ""

# Known schema path-to-name mapping
$schemaNames = @{
    'report'          = 'Report'
    'page'            = 'Page'
    'visualContainer' = 'Visual'
    'pagesMetadata'   = 'Pages Metadata'
    'versionMetadata' = 'Version Metadata'
}

# Deprecated schema paths that should be updated
$deprecatedPaths = @{
    'visual'  = 'visualContainer'
    'pages'   = 'pagesMetadata'
    'version' = 'versionMetadata'
}

$jsonFiles = Get-ChildItem -Path $Path -Filter "*.json" -Recurse |
    Where-Object { $_.Name -in @('report.json', 'page.json', 'visual.json', 'pages.json', 'version.json') }

if ($jsonFiles.Count -eq 0) {
    Write-Host "  No PBIR JSON files found." -ForegroundColor Yellow
    exit 0
}

$versions = @{}
$issues = @()

foreach ($file in $jsonFiles) {
    try {
        $json = Get-Content $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "  [SKIP] $($file.FullName): invalid JSON" -ForegroundColor DarkGray
        continue
    }

    $schema = $json.'$schema'
    if (-not $schema) { continue }

    # Parse schema URL: .../definition/{type}/{version}/schema.json
    if ($schema -match '/definition/([^/]+)/([^/]+)/schema\.json') {
        $schemaType = $Matches[1]
        $schemaVersion = $Matches[2]
        $relativePath = $file.FullName.Substring($resolvedPath.Path.Length + 1)

        # Check for deprecated paths
        if ($deprecatedPaths.ContainsKey($schemaType)) {
            $correctType = $deprecatedPaths[$schemaType]
            $issues += [PSCustomObject]@{
                File    = $relativePath
                Issue   = "Uses deprecated '$schemaType/' - should be '$correctType/'"
            }
        }

        $key = "$schemaType/$schemaVersion"
        if (-not $versions.ContainsKey($key)) {
            $versions[$key] = @{ Count = 0; Files = @() }
        }
        $versions[$key].Count++
        $versions[$key].Files += $relativePath
    }
}

# Display version summary
Write-Host "  Schema Versions Found:" -ForegroundColor Yellow
Write-Host ""
Write-Host ("  {0,-30} {1,-10} {2}" -f "Schema Path", "Version", "Count") -ForegroundColor White
Write-Host ("  {0,-30} {1,-10} {2}" -f ('-' * 30), ('-' * 10), ('-' * 5)) -ForegroundColor DarkGray

foreach ($entry in $versions.GetEnumerator() | Sort-Object Name) {
    $parts = $entry.Key -split '/'
    $type = $parts[0]
    $ver = $parts[1]
    $isDeprecated = $deprecatedPaths.ContainsKey($type)
    $color = if ($isDeprecated) { 'Red' } else { 'Green' }
    $suffix = if ($isDeprecated) { " (DEPRECATED)" } else { "" }
    Write-Host ("  {0,-30} {1,-10} {2}{3}" -f $type, $ver, $entry.Value.Count, $suffix) -ForegroundColor $color
}

# Display issues
if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Host "  Issues:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "    $($issue.File): $($issue.Issue)" -ForegroundColor Red
    }
}

Write-Host ""

# Return structured output for scripting
$versions
