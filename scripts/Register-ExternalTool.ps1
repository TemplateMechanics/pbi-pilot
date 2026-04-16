<#
.SYNOPSIS
    Registers the PowerBI-Harness as an External Tool in Power BI Desktop.

.DESCRIPTION
    Creates a .pbitool.json registration file in the Power BI Desktop 
    External Tools folder. Once registered, a button appears in PBI Desktop's
    External Tools ribbon that launches VS Code with the PBIP folder open.

    The external tool integration passes the Analysis Services server name and 
    model database name as arguments, which our scripts can use for TOM connections.

.PARAMETER ToolName
    Display name for the tool in PBI Desktop. Default: "VS Code AI Harness"

.PARAMETER Unregister
    Remove the registration file.

.EXAMPLE
    .\Register-ExternalTool.ps1

.EXAMPLE
    .\Register-ExternalTool.ps1 -ToolName "My AI Editor"

.EXAMPLE
    .\Register-ExternalTool.ps1 -Unregister
#>
[CmdletBinding()]
param(
    [string]$ToolName = "VS Code AI Harness",

    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$toolsFolder = Join-Path $env:CommonProgramFiles "Microsoft Shared\Power BI Desktop\External Tools"
if (-not (Test-Path $toolsFolder)) {
    # Try x86 path
    $toolsFolder = Join-Path ${env:CommonProgramFiles(x86)} "Microsoft Shared\Power BI Desktop\External Tools"
}

if (-not (Test-Path $toolsFolder)) {
    # Create the folder if it doesn't exist
    New-Item -Path $toolsFolder -ItemType Directory -Force | Out-Null
}

$jsonFileName = "vscode-ai-harness.pbitool.json"
$jsonPath = Join-Path $toolsFolder $jsonFileName

if ($Unregister) {
    if (Test-Path $jsonPath) {
        Remove-Item $jsonPath -Force
        Write-Host "Unregistered: $jsonPath" -ForegroundColor Green
    } else {
        Write-Host "Registration file not found at: $jsonPath" -ForegroundColor Yellow
    }
    return
}

# Find VS Code executable
$vscodePath = $null
$searchPaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
)

foreach ($p in $searchPaths) {
    if (Test-Path $p) {
        $vscodePath = $p
        break
    }
}

if (-not $vscodePath) {
    # Try where.exe
    $vscodePath = (Get-Command code -ErrorAction SilentlyContinue)?.Source
    if ($vscodePath -and $vscodePath -like "*.cmd") {
        # Resolve the .cmd to actual .exe
        $content = Get-Content $vscodePath -Raw
        if ($content -match '"([^"]+Code\.exe)"') {
            $vscodePath = $Matches[1]
        }
    }
}

if (-not $vscodePath) {
    Write-Warning "VS Code not found. Using 'code' command as fallback."
    $vscodePath = "code"
}

# Create the .pbitool.json registration
$toolDefinition = @{
    version     = "1.0"
    name        = $ToolName
    description = "Open project in VS Code with AI-powered PBIP editing support"
    path        = $vscodePath
    arguments   = "`"%server%`" `"%database%`""
    iconData    = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKGSURBVFhH7ZY9aBRBFMf/s3t3uXgfJkYTg4WFha2FhYiVYCFYWImdjYVgIdhZWAhWgo2FhWBnYyFYWYiVhYjFIagQ/IgxJl6Sm5u9nf+b3dns5S65mFj4g2Fn3rz3n9m3M7OKf4z+F8C6WCwAqrXf6k+B+fk3yrZzjtqL4zj3SqkfJdGa0opXqVj8QhV/kEY/fMjlgBJ5mC5cIvdpBKuB2ycgb17C3rzFJJWxAu4wfkZF/0TECfP4NPxNdCHr0G/+Rb6+BXoo1fATVB73gT92N+2Gw8SEGVHwU1ege4VyF5+h7J8E3S0gf7jdCKtY9ROQB88DfjsE3LmPjBKiXPk8C9M+ArzkP/cBb07B3YuQ+g6F+2Gw/8C2CuQ2MH/A1VeqDQNzTrAwPQR+7sGdTrewCOuxbeJKBf5iAPyqJ9wU0CTu8bE44dz7h5i6SqOJnY9T0ARs2+bIOyqAI9ew/kwjXghknQ8/ehj16FrjjElyZuBJ9ORvuiGdBv8kA6l2G3mDzjBHDngfP0fEjuiRj9vhcVE5CTtwNu/uuAO48hD5+FfjwJdDTN0DPTIJevAf94jvQ85xoKOiJYPf6ETDMJ2kCeuIu9LFr0DuugHJ3oE9cB73MJ+2BfTEFPLnAOecZJKE8cKC4N4jDu7ATDDN1XG9+AU3BHc6lfdGPATB9aJrw1HK5hJ5+Bxq/C3ruIejlR6BnJqG/OQd9ijMiHThZOyC7OYjBNJC+ZzAecGJX0i9AH7oI2nMJ+sQN0MuPQc+ywq+egu7mEDhBv0Cv8EDrwv2CIZmE+ux90F9z9usLwWNI7Ej2YJTdl/1ZVIGevgu99BD05D3Qi/P/JqB7oNQ/fAt/AMns8M0AAAAASUVORK5CYII="
} | ConvertTo-Json -Depth 3

Set-Content -Path $jsonPath -Value $toolDefinition -Encoding UTF8

Write-Host "External tool registered!" -ForegroundColor Green
Write-Host "  Name: $ToolName" -ForegroundColor White
Write-Host "  File: $jsonPath" -ForegroundColor White
Write-Host "  VS Code: $vscodePath" -ForegroundColor White
Write-Host "`nRestart Power BI Desktop to see the tool in the External Tools ribbon." -ForegroundColor Yellow
Write-Host "When clicked, it will pass the AS server and database name as arguments to VS Code." -ForegroundColor DarkGray
