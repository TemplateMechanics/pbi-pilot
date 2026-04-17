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
11. **Visual schema URL** must use `visualContainer/` (NOT `visual/`) — see SKILL.md for all correct schema paths
12. **Numeric columns in value roles** (card Values, chart Y-axis) must use Aggregation wrapper — see SKILL.md for details
13. **If visuals/filters do not appear after edits**, treat it as a refresh-state issue: verify visual folders exist on disk, run `Validate-PBIP.ps1`, and restart PBI Desktop. For demo/sample projects, set `.pbip` `settings.enableAutoRecovery` to `false` to avoid stale auto-recovery sessions masking PBIR changes.
14. **When adding filters**, prefer page-level `filterConfig` in `page.json` over canvas slicer visuals. Canvas slicers created externally may not render reliably. Page-level filters always appear in the Filter Pane (right sidebar). Use both approaches together for maximum reliability — see SKILL.md for `filterConfig` JSON format.

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
