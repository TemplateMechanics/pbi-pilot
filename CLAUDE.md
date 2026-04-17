# Power BI PBIP Workspace — Claude Code Instructions

This workspace contains Power BI Project (PBIP) files. You are working with:

- **TMDL** (Tabular Model Definition Language) files for the semantic model — indentation-based syntax using TABs
- **PBIR** (Power BI Enhanced Report Format) JSON files for the report definition
- **DAX** expressions for measures and calculated columns
- **M / Power Query** expressions for data source queries

## Before Making Any Edits

Read `skills/powerbi-pbip/SKILL.md` — it contains the complete reference for TMDL syntax, PBIR JSON structure, DAX patterns, visual type mappings, and aggregation rules. This is the single source of truth for this project.

## Key Rules

1. **TMDL uses TAB indentation** — never use spaces in .tmdl files
2. **Generate unique GUIDs** for every new `lineageTag` — format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
3. **Save as UTF-8 without BOM**, CRLF line endings
4. **Don't edit** `LocalDateTable_*` auto-generated tables
5. **After editing TMDL/PBIR files**, apply changes using the automation scripts in `scripts/` (see Automation Scripts section below)
6. **Report visuals** reference semantic model objects by exact name — Entity must match table name, Property must match column/measure name
7. **When adding pages**, also update `pages.json` pageOrder array
8. **When adding measures**, always include `lineageTag` and `formatString` properties
9. **Prefer existing patterns** — look at existing .tmdl and .json files in the project for style consistency
10. **Visual schema URL** must use `visualContainer/` (NOT `visual/`) — see SKILL.md for all correct schema paths
11. **Numeric columns in value roles** (card Values, chart Y-axis) must use Aggregation wrapper — see SKILL.md for details
12. **If visuals/filters do not appear after edits**, treat it as a refresh-state issue: verify visual folders exist on disk for missing visuals, and for missing filters also confirm the relevant `*.Report/definition/pages/*/page.json` contains the expected filters in the page's existing format (`filters` or `filterConfig`). Then run `Validate-PBIP.ps1` and restart PBI Desktop. For demo/sample projects, set `.pbip` `settings.enableAutoRecovery` to `false` to avoid stale auto-recovery sessions masking PBIR changes.
13. **When adding filters**, prefer page-level filters in `page.json` over canvas slicer visuals, using the page's existing schema representation (`filters` or `filterConfig`) as documented in SKILL.md. Canvas slicers created externally may not render reliably. Page-level filters always appear in the Filter Pane (right sidebar). Use both approaches together for maximum reliability — see SKILL.md for the correct JSON format for the schema/version in use.

## File Locations

- Semantic model tables: `*.SemanticModel/definition/tables/*.tmdl`
- Relationships: `*.SemanticModel/definition/relationships.tmdl`
- Expressions/parameters: `*.SemanticModel/definition/expressions.tmdl`
- Report pages: `*.Report/definition/pages/*/page.json`
- Page visuals: `*.Report/definition/pages/*/visuals/*/visual.json`
- Report config: `*.Report/definition/report.json`
- Page ordering: `*.Report/definition/pages/pages.json`

## Automation Scripts — USE THESE, DON'T REINVENT THEM

PowerShell scripts in `scripts/` are **required tools** for operational tasks. Always use the project scripts instead of writing manual commands, shell one-liners, or `Invoke-Item`/`Start-Process` workarounds.

| Task | Script | Example |
|------|--------|---------|
| **Open a PBIP file** in PBI Desktop | `Open-PBIPFile.ps1` | `./scripts/Open-PBIPFile.ps1 -PbipPath "./MyReport.pbip" -Wait` |
| **Validate** TMDL/PBIR files | `Validate-PBIP.ps1` | `./scripts/Validate-PBIP.ps1 -Path .` |
| **Refresh** the semantic model (requires PBI Desktop running with the PBIP open) | `Invoke-SemanticModelRefresh.ps1` | `./scripts/Invoke-SemanticModelRefresh.ps1 -PbipPath "./MyReport.pbip"` |
| **Restart** PBI Desktop | `Restart-PBIDesktop.ps1` | `./scripts/Restart-PBIDesktop.ps1 -PbipPath "./MyReport.pbip" -Force` |
| **Find** the Analysis Services port | `Find-PBIDesktopPort.ps1` | `./scripts/Find-PBIDesktopPort.ps1` |
| **Check** PBIR schema versions | `Get-PBIRSchemaVersions.ps1` | `./scripts/Get-PBIRSchemaVersions.ps1` |

### When to use which script:
- **Opening files**: Always use `Open-PBIPFile.ps1`. Never use `start`, `Invoke-Item`, or manual process launching.
- **After editing TMDL files**: Ensure PBI Desktop is running with the PBIP open (use `Open-PBIPFile.ps1 -Wait` first if needed), then run `Invoke-SemanticModelRefresh.ps1 -PbipPath "./MyReport.pbip"` to push changes without restarting.
- **After editing PBIR files**: Run `Restart-PBIDesktop.ps1 -PbipPath "./MyReport.pbip" -Force` (PBIR changes require a restart).
- **After any edit**: Run `Validate-PBIP.ps1` to catch errors before refreshing.
- **Troubleshooting**: Run `Find-PBIDesktopPort.ps1` to confirm PBI Desktop is running and get the port. Requires PBI Desktop to already have a PBIP open.

## Validation

Always run validation after making changes:
```bash
powershell ./scripts/Validate-PBIP.ps1 -Path .
```

## Working Example

`examples/power-bi-example-data/` contains a complete working PBIP project with Financial Sample data, correct schemas, working visuals, and a parameterized data path in `expressions.tmdl`.
