# Power BI PBIP Workspace Instructions

This workspace contains Power BI Project (PBIP) files. You are working with:

- **TMDL** (Tabular Model Definition Language) files for the semantic model — indentation-based syntax using TABs
- **PBIR** (Power BI Enhanced Report Format) JSON files for the report definition
- **DAX** expressions for measures and calculated columns
- **M / Power Query** expressions for data source queries

## Key Rules

1. **Use the `powerbi-pbip` skill** — read `skills/powerbi-pbip/SKILL.md` for complete TMDL syntax, PBIR JSON structure, DAX patterns, and visual type references before making any edits
2. **TMDL uses TAB indentation** — never use spaces in .tmdl files
3. **Generate unique GUIDs** for every new `lineageTag` — use format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
4. **Save as UTF-8 without BOM**, CRLF line endings
5. **Don't edit** `LocalDateTable_*` auto-generated tables
6. **After editing TMDL/PBIR files**, remind the user to refresh Power BI Desktop (close/reopen or use automation scripts in `scripts/`)
7. **Report visuals** reference semantic model objects by exact name — Entity must match table name, Property must match column/measure name
8. **When adding pages**, also update `pages.json` pageOrder array
9. **When adding measures**, add `lineageTag` and `formatString` properties
10. **Prefer existing patterns** — look at existing .tmdl and .json files in the project for style consistency

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
