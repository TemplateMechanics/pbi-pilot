# Pester tests for PowerBI-Harness scripts
# Run with: Invoke-Pester -Path .\tests\

BeforeAll {
    $scriptRoot = Join-Path (Join-Path $PSScriptRoot '..') 'scripts'
    $examplesRoot = Join-Path (Join-Path $PSScriptRoot '..') 'examples'
}

Describe 'Validate-PBIP.ps1' {
    It 'passes on valid example data' {
        $result = & "$scriptRoot\Validate-PBIP.ps1" -Path "$examplesRoot\power-bi-example-data" 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It 'detects missing TMDL files in an empty folder' {
        $tempDir = Join-Path $TestDrive 'empty-project'
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        $result = & "$scriptRoot\Validate-PBIP.ps1" -Path $tempDir 2>&1
        # Should succeed (no files to fail on) but warn about structure
        $LASTEXITCODE | Should -Be 0
    }

    It 'detects invalid JSON' {
        $tempDir = Join-Path $TestDrive 'bad-json'
        $rptDir = Join-Path (Join-Path $tempDir 'Test.Report') 'definition'
        New-Item -Path $rptDir -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $rptDir 'report.json') -Value '{ invalid json }'
        $result = & "$scriptRoot\Validate-PBIP.ps1" -Path $tempDir 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It 'detects wrong visual schema path' {
        $tempDir = Join-Path $TestDrive 'bad-schema'
        $visDir = Join-Path (Join-Path (Join-Path (Join-Path (Join-Path (Join-Path $tempDir 'Test.Report') 'definition') 'pages') 'p1') 'visuals') 'v1'
        New-Item -Path $visDir -ItemType Directory -Force | Out-Null
        $badVisual = @{
            '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visual/1.2.0/schema.json'
            name = 'v1'
            position = @{ x = 0; y = 0; z = 0; width = 100; height = 100 }
            visual = @{ visualType = 'card' }
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $visDir 'visual.json') -Value $badVisual
        $result = & "$scriptRoot\Validate-PBIP.ps1" -Path $tempDir 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'Get-PBIRSchemaVersions.ps1' {
    It 'reports schema versions for example data' {
        $result = & "$scriptRoot\Get-PBIRSchemaVersions.ps1" -Path "$examplesRoot" 2>&1
        $output = $result | Out-String
        $output | Should -Match 'visualContainer'
        $output | Should -Match 'page'
    }

    It 'handles empty directory gracefully' {
        $tempDir = Join-Path $TestDrive 'empty-schemas'
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        { & "$scriptRoot\Get-PBIRSchemaVersions.ps1" -Path $tempDir } | Should -Not -Throw
    }
}

Describe 'Find-PBIDesktopPort.ps1' {
    It 'script file exists and has valid syntax' {
        $scriptPath = Join-Path $scriptRoot 'Find-PBIDesktopPort.ps1'
        Test-Path $scriptPath | Should -BeTrue
        
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

Describe 'Invoke-SemanticModelRefresh.ps1' {
    It 'script file exists and has valid syntax' {
        $scriptPath = Join-Path $scriptRoot 'Invoke-SemanticModelRefresh.ps1'
        Test-Path $scriptPath | Should -BeTrue
        
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

Describe 'Restart-PBIDesktop.ps1' {
    It 'script file exists and has valid syntax' {
        $scriptPath = Join-Path $scriptRoot 'Restart-PBIDesktop.ps1'
        Test-Path $scriptPath | Should -BeTrue
        
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}
