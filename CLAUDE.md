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
5. **After editing TMDL/PBIR files**, remind the user to refresh Power BI Desktop (close/reopen or use automation scripts in `scripts/`)
6. **Report visuals** reference semantic model objects by exact name — Entity must match table name, Property must match column/measure name
7. **When adding pages**, also update `pages.json` pageOrder array
8. **When adding measures**, always include `lineageTag` and `formatString` properties
9. **Prefer existing patterns** — look at existing .tmdl and .json files in the project for style consistency
10. **Visual schema URL** must use `visualContainer/` (NOT `visual/`) — see SKILL.md for all correct schema paths
11. **Numeric columns in value roles** (card Values, chart Y-axis) must use Aggregation wrapper — see SKILL.md for details

## File Locations

- Semantic model tables: `*.SemanticModel/definition/tables/*.tmdl`
- Relationships: `*.SemanticModel/definition/relationships.tmdl`
- Expressions/parameters: `*.SemanticModel/definition/expressions.tmdl`
- Report pages: `*.Report/definition/pages/*/page.json`
- Page visuals: `*.Report/definition/pages/*/visuals/*/visual.json`
- Report config: `*.Report/definition/report.json`
- Page ordering: `*.Report/definition/pages/pages.json`

## Automation Scripts

PowerShell scripts are in `scripts/`:
- `Find-PBIDesktopPort.ps1` — discovers the local Analysis Services port PBI Desktop is using
- `Invoke-SemanticModelRefresh.ps1` — pushes semantic model changes to running PBI Desktop via TOM
- `Restart-PBIDesktop.ps1` — automates close and reopen of the PBIP file
- `Validate-PBIP.ps1` — checks TMDL and PBIR files for common errors
- `Get-PBIRSchemaVersions.ps1` — reports schema versions used in PBIR files

## Validation

Always run validation after making changes:
```bash
powershell ./scripts/Validate-PBIP.ps1 -Path .
```

## Working Example

`examples/power-bi-example-data/` contains a complete working PBIP project with Financial Sample data, correct schemas, working visuals, and a parameterized data path in `expressions.tmdl`.
