# Changelog

All notable changes to PowerBI-Harness will be documented in this file.

## [Unreleased]

### Added
- MIT LICENSE file
- Pester test suite (`tests/Harness.Tests.ps1`) — 9 tests covering validation, schema detection, and script syntax
- GitHub Actions CI workflow (`.github/workflows/validate.yml`) — runs validation and Pester on push/PR
- `Get-PBIRSchemaVersions.ps1` — scans PBIR files and reports schema versions, flags deprecated paths
- `Open-PBIPFile.ps1` — launches a .pbip file in Power BI Desktop with wait-for-ready polling
- CHANGELOG.md

### Fixed
- Legacy sample-report schemas updated: `visual/1.2.0` → `visualContainer/2.7.0`, `pages/1.0.0` → `pagesMetadata/1.0.0`, `report/1.0.0` → `report/3.2.0`, `version/1.0.0` → `versionMetadata/1.0.0`, `page/1.0.0` → `page/2.1.0`
- Removed invalid empty `filters` and `annotations` arrays from sample PBIR JSON files
- Validator no longer flags M/Power Query expression blocks as mixed indentation (false positive)
- Store app Analysis Services path added to `REFRESH-STRATEGIES.md` (was only showing MSI path)

### Changed
- `.gitignore` expanded with NuGet packages, .vs/, build outputs, OS files, logs
- `README.md` prerequisites section now documents PBIR preview feature requirement, Store vs MSI, and .NET dependency for TOM
- Validator skips M expression lines inside TMDL partition source blocks when checking indentation

## [0.1.0] - 2025-07-15

### Added
- Initial harness with copilot-instructions, SKILL.md, and agent definition
- PowerShell scripts: `Find-PBIDesktopPort.ps1`, `Invoke-SemanticModelRefresh.ps1`, `Restart-PBIDesktop.ps1`, `Validate-PBIP.ps1`
- TMDL and PBIR example files
- Documentation: TMDL syntax reference, PBIR structure guide, refresh strategies
- `.vscode/settings.json` with PBIR schema mappings
