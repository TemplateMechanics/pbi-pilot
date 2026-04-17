# Power BI PBIP / TMDL / PBIR Skill

You are an expert Power BI developer working with Power BI Project (PBIP) files. You can directly read and edit semantic model files (TMDL) and report definition files (PBIR JSON). You understand DAX, M/Power Query, the Tabular Object Model, and Power BI report visuals.

## When to Use This Skill

Use this skill when the user wants to:
- Add, edit, or remove measures, columns, tables, or relationships in a semantic model
- Create or modify report pages, visuals, filters, or bookmarks
- Write DAX expressions or M/Power Query code
- Understand or navigate PBIP file structure
- Validate or troubleshoot PBIP files
- Automate Power BI development tasks

---

## PBIP Project Structure

A Power BI Project (.pbip) saves as a folder structure:

```
Project/
├── MyReport.Report/                    # Report definition
│   ├── definition/                     # PBIR format (enhanced)
│   │   ├── report.json                 # Report-level config, themes, filters
│   │   ├── version.json                # PBIR version
│   │   ├── reportExtensions.json       # Report-level measures
│   │   ├── pages/
│   │   │   ├── pages.json              # Page order and active page
│   │   │   └── [pageName]/
│   │   │       ├── page.json           # Page config, filters, formatting
│   │   │       └── visuals/
│   │   │           └── [visualName]/
│   │   │               ├── visual.json # Visual config, query, formatting
│   │   │               └── mobile.json # Mobile layout (optional)
│   │   └── bookmarks/
│   │       ├── bookmarks.json          # Bookmark order and groups
│   │       └── [name].bookmark.json    # Individual bookmark state
│   ├── definition.pbir                 # Report pointer to semantic model
│   ├── StaticResources/
│   │   └── RegisteredResources/        # Images, custom themes, pbiviz files
│   └── .pbi/localSettings.json         # Local-only settings (git-ignored)
│
├── MyReport.SemanticModel/             # Semantic model definition
│   ├── definition/                     # TMDL format
│   │   ├── database.tmdl              # Database compatibility level
│   │   ├── model.tmdl                 # Model config, culture, ref ordering
│   │   ├── relationships.tmdl         # All relationships
│   │   ├── expressions.tmdl           # Shared M expressions / parameters
│   │   ├── roles/                     # RLS role definitions
│   │   │   └── [roleName].tmdl
│   │   ├── cultures/                  # Translations
│   │   │   └── [locale].tmdl
│   │   ├── perspectives/              # Perspectives
│   │   │   └── [perspectiveName].tmdl
│   │   └── tables/                    # One file per table
│   │       ├── Sales.tmdl
│   │       ├── Product.tmdl
│   │       ├── Date.tmdl
│   │       └── ...
│   ├── definition.pbism               # Semantic model pointer
│   └── .pbi/
│       ├── localSettings.json         # Local-only (git-ignored)
│       ├── editorSettings.json        # Editor settings
│       └── cache.abf                  # Data cache (git-ignored)
│
├── .gitignore
└── MyReport.pbip                       # Entry point file
```

### Key Files

| File | Purpose | Editable? |
|------|---------|-----------|
| `*.tmdl` | Semantic model definitions | YES — primary editing target |
| `definition/report.json` | Report-level config (PBIR) | YES — with JSON schema |
| `definition/pages/*/page.json` | Page config | YES — with JSON schema |
| `definition/pages/*/visuals/*/visual.json` | Visual config | YES — with JSON schema |
| `definition.pbir` | Report → model pointer | YES |
| `definition.pbism` | Model definition pointer | YES |
| `report.json` (root) | PBIR-Legacy format | NO — use definition/ folder instead |

---

## TMDL Syntax Reference

TMDL (Tabular Model Definition Language) is indentation-based, similar to YAML. It defines the semantic model structure.

### Core Rules

1. **Indentation**: Use single TAB characters. Three levels: object → properties → expressions
2. **Object declaration**: `objectType objectName` or `objectType 'Name With Spaces'`
3. **Properties**: `propertyName: value` (colon delimiter)
4. **Expressions/defaults**: `objectType Name = expression` (equals delimiter)
5. **Single quotes** around names containing: `.` `=` `:` `'` or spaces
6. **Escape single quotes** by doubling: `'Name''s Thing'`
7. **Booleans**: shortcut `isHidden` means `isHidden: true`
8. **Descriptions**: `///` triple-slash above object declaration
9. **Refs**: `ref table TableName` for ordering and references
10. **Case**: camelCase for types/keywords/enums. Parsing is case-insensitive.
11. **Partial declarations**: same object can be defined across multiple files
12. **Multi-line expressions**: indented one level deeper than parent properties

### database.tmdl

```tmdl
database MyDatabase
	compatibilityLevel: 1567
```

### model.tmdl

```tmdl
model Model
	culture: en-US
	defaultPowerBIDataSourceVersion: powerBI_V3
	discourageImplicitMeasures: true

ref table Date
ref table Sales
ref table Product
ref table Customer

ref culture en-US
```

### Table Definition (tables/Sales.tmdl)

```tmdl
/// Sales transaction data
table Sales
	lineageTag: a1b2c3d4-e5f6-7890-abcd-ef1234567890

	/// Total revenue from all sales
	measure 'Total Sales' = SUM(Sales[Amount])
		formatString: $ #,##0.00
		lineageTag: 11111111-2222-3333-4444-555555555555

	/// Year-over-year growth rate
	measure 'Sales YoY %' =
			VAR CurrentYear = [Total Sales]
			VAR PriorYear = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Date'[Date]))
			RETURN DIVIDE(CurrentYear - PriorYear, PriorYear)
		formatString: 0.0 %
		lineageTag: 22222222-3333-4444-5555-666666666666

	/// Year-to-date sales
	measure 'Sales YTD' = TOTALYTD([Total Sales], 'Date'[Date])
		formatString: $ #,##0.00
		lineageTag: 33333333-4444-5555-6666-777777777777

	column Amount
		dataType: decimal
		formatString: $ #,##0.00
		lineageTag: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
		summarizeBy: sum
		sourceColumn: Amount

	column 'Product Key'
		dataType: int64
		isHidden
		lineageTag: bbbbbbbb-cccc-dddd-eeee-ffffffffffff
		summarizeBy: none
		sourceColumn: ProductKey

	column Quantity
		dataType: int64
		lineageTag: cccccccc-dddd-eeee-ffff-000000000000
		summarizeBy: sum
		sourceColumn: Quantity

	column 'Order Date'
		dataType: dateTime
		formatString: Short Date
		lineageTag: dddddddd-eeee-ffff-0000-111111111111
		summarizeBy: none
		sourceColumn: OrderDate

	partition Sales = m
		mode: import
		source =
			let
				Source = Sql.Database(Server, Database),
				dbo_Sales = Source{[Schema="dbo",Item="Sales"]}[Data]
			in
				dbo_Sales

	annotation PBI_ResultType = Table
```

### Date/Calendar Table (tables/Date.tmdl)

```tmdl
table Date
	lineageTag: 44444444-5555-6666-7777-888888888888
	dataCategory: Time

	column Date
		dataType: dateTime
		isKey
		formatString: Short Date
		lineageTag: 55555555-6666-7777-8888-999999999999
		summarizeBy: none
		sourceColumn: Date

	column Year
		dataType: int64
		formatString: 0
		lineageTag: 66666666-7777-8888-9999-aaaaaaaaaaaa
		summarizeBy: none
		sourceColumn: Year

	column Month
		dataType: string
		lineageTag: 77777777-8888-9999-aaaa-bbbbbbbbbbbb
		summarizeBy: none
		sourceColumn: Month
		sortByColumn: 'Month Number'

	column 'Month Number'
		dataType: int64
		isHidden
		formatString: 0
		lineageTag: 88888888-9999-aaaa-bbbb-cccccccccccc
		summarizeBy: none
		sourceColumn: MonthNumber

	column Quarter
		dataType: string
		lineageTag: 99999999-aaaa-bbbb-cccc-dddddddddddd
		summarizeBy: none
		sourceColumn: Quarter

	hierarchy 'Date Hierarchy'
		lineageTag: aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee

		level Year
			column: Year

		level Quarter
			column: Quarter

		level Month
			column: Month

	partition Date = m
		mode: import
		source =
			let
				Source = Sql.Database(Server, Database),
				dbo_Date = Source{[Schema="dbo",Item="Date"]}[Data]
			in
				dbo_Date
```

### Relationships (relationships.tmdl)

```tmdl
relationship rel_Sales_Date
	fromColumn: Sales.'Order Date'
	toColumn: 'Date'.Date

relationship rel_Sales_Product
	fromColumn: Sales.'Product Key'
	toColumn: Product.'Product Key'

relationship rel_Sales_Customer
	fromColumn: Sales.'Customer Key'
	toColumn: Customer.'Customer Key'
```

### Shared Expressions / Parameters (expressions.tmdl)

Use parameters to avoid hardcoded paths. This lets the expression auto-detect the PBI Desktop SampleData folder across Store and MSI installs.

```tmdl
/// Auto-detects the PBI Desktop SampleData folder (Store or MSI install)
expression SampleDataPath =
		let
			MsiPath = "C:\Program Files\Microsoft Power BI Desktop\bin\SampleData",
			StoreBase = "C:\Program Files\WindowsApps",
			StoreContents = try Folder.Contents(StoreBase) otherwise #table({"Name", "Folder Path"}, {}),
			StoreMatches = Table.Sort(
				Table.AddColumn(
					Table.SelectRows(
						StoreContents,
						each Text.StartsWith([Name], "Microsoft.MicrosoftPowerBIDesktop_")
							and Text.Contains([Name], "_x64_")
					),
					"SortKey",
					each try Text.Combine(List.Transform(
						Text.Split(Text.BetweenDelimiters([Name], "Microsoft.MicrosoftPowerBIDesktop_", "_x64_"), "."),
						each Text.PadStart(_, 10, "0")
					), ".") otherwise ""
				),
				{{"SortKey", Order.Descending}}
			),
			PathExists = (path) => not (try Folder.Contents(path))[HasError],
			StoreCandidates = List.Transform(
				Table.ToRecords(StoreMatches),
				each [Folder Path] & [Name] & "\bin\SampleData"
			),
			StoreMatch = List.First(List.Select(StoreCandidates, each PathExists(_)), null),
			Source =
				if StoreMatch <> null then StoreMatch
				else if PathExists(MsiPath) then MsiPath
				else error Error.Record(
					"SampleDataPath",
					"Cannot find Power BI Desktop SampleData folder. Install PBI Desktop (Store or MSI) or update this expression.",
					[StoreBase = StoreBase, StoreCandidates = StoreCandidates, MsiPath = MsiPath]
				)
		in
			Source
	lineageTag: c4e8f2a6-3b5d-7e9f-1a2c-4d6e8f0a2b4c

	annotation PBI_NavigationStepName = Navigation

	annotation PBI_ResultType = Text
```

Then reference the parameter in table partition M queries:
```m
Source = Excel.Workbook(File.Contents(#"SampleDataPath" & "\Financial Sample.xlsx"), null, true)
```

Server/database connection parameters:
```tmdl
expression Server = "localhost" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

expression Database = "AdventureWorks" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]
```

Shared date table query:
```tmdl
/// Shared date table query
expression DateQuery =
		let
			StartDate = #date(2020, 1, 1),
			EndDate = Date.From(DateTime.LocalNow()),
			DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1,0,0,0)),
			DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error)
		in
			DateTable
	lineageTag: ee111111-ff22-0033-1144-225533664477
```

### Roles (roles/Reader.tmdl)

```tmdl
role Reader
	modelPermission: read

	tablePermission Store = 'Store'[Region] = "West"
```

### Calculated Column Example

```tmdl
table Sales

	column 'Profit Margin' = DIVIDE(Sales[Profit], Sales[Revenue])
		dataType: decimal
		formatString: 0.0 %
		lineageTag: ff000000-1111-2222-3333-444444444444
		summarizeBy: none
```

### Calculation Group Example

```tmdl
table 'Time Intelligence'
	calculationGroup

	column 'Time Calc'
		dataType: string
		isDefaultLabel
		sourceColumn: Name

	column Ordinal
		dataType: int64
		isDefaultOrder
		sourceColumn: Ordinal

	calculationItem 'Current' = SELECTEDMEASURE()

	calculationItem 'YTD' = TOTALYTD(SELECTEDMEASURE(), 'Date'[Date])
		ordinal: 1

	calculationItem 'PY' = CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Date'[Date]))
		ordinal: 2
```

---

## Common DAX Patterns (for Measures)

### Aggregations
```dax
measure 'Total Sales' = SUM(Sales[Amount])
measure 'Avg Order Value' = AVERAGE(Sales[Amount])
measure 'Order Count' = COUNTROWS(Sales)
measure 'Distinct Customers' = DISTINCTCOUNT(Sales[CustomerID])
```

### Time Intelligence
```dax
measure 'Sales YTD' = TOTALYTD([Total Sales], 'Date'[Date])
measure 'Sales MTD' = TOTALMTD([Total Sales], 'Date'[Date])
measure 'Sales QTD' = TOTALQTD([Total Sales], 'Date'[Date])
measure 'Sales PY' = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Date'[Date]))
measure 'Sales YoY %' =
    VAR CY = [Total Sales]
    VAR PY = [Sales PY]
    RETURN DIVIDE(CY - PY, PY)
measure 'Sales Rolling 12M' = CALCULATE([Total Sales], DATESINPERIOD('Date'[Date], MAX('Date'[Date]), -12, MONTH))
```

### Ratios & Percentages
```dax
measure '% of Total' = DIVIDE([Total Sales], CALCULATE([Total Sales], REMOVEFILTERS()))
measure 'Margin %' = DIVIDE([Total Profit], [Total Sales])
measure 'Cumulative Sales' = CALCULATE([Total Sales], FILTER(ALL('Date'[Date]), 'Date'[Date] <= MAX('Date'[Date])))
```

### Conditional / Status
```dax
measure 'Sales Status' =
    SWITCH(
        TRUE(),
        [Sales YoY %] > 0.1, "Strong Growth",
        [Sales YoY %] > 0, "Growth",
        [Sales YoY %] > -0.1, "Decline",
        "Significant Decline"
    )
```

### Rankings
```dax
measure 'Product Rank' =
    RANKX(
        ALL(Product[Product Name]),
        [Total Sales],,
        DESC,
        Dense
    )
```

---

## PBIR Report Definition Reference

PBIR (Power BI Enhanced Report Format) stores report definitions as individual JSON files with published schemas.

### Schema URLs

All schemas are at: `https://developer.microsoft.com/json-schemas/fabric/item/report/definition/`

| File | Schema Path |
|------|------------|
| report.json | `report/{version}/schema.json` |
| version.json | `versionMetadata/{version}/schema.json` |
| page.json | `page/{version}/schema.json` |
| visual.json | `visualContainer/{version}/schema.json` |
| pages.json | `pagesMetadata/{version}/schema.json` |
| bookmark.json | `bookmark/{version}/schema.json` |
| reportExtensions.json | `reportExtension/{version}/schema.json` |

> **IMPORTANT — Schema Version Detection**: Schema versions change with each PBI Desktop release.
> Do NOT hardcode versions. Instead, check existing `$schema` URLs in the project's JSON files
> (especially `report.json` and `page.json`) to determine what versions the current PBI Desktop uses.
> All schema versions for a report are published at:
> https://github.com/microsoft/json-schemas/tree/main/fabric/item/report/definition

### version.json

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/version/1.0.0/schema.json",
  "version": "4.0"
}
```

### report.json (Report Level)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/1.0.0/schema.json",
  "themeCollection": {
    "baseTheme": {
      "name": "CY24SU06",
      "reportVersionAtImport": "5.55",
      "type": "SharedResources"
    }
  },
  "dataColors": [
    "#118DFF", "#12239E", "#E66C37", "#6B007B", "#E044A7", "#744EC2"
  ],
  "filters": [],
  "annotations": []
}
```

### pages.json

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pages/1.0.0/schema.json",
  "pageOrder": [
    "overview_page",
    "sales_detail_page",
    "product_analysis_page"
  ],
  "activePageName": "overview_page"
}
```

### page.json (Individual Page)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/1.0.0/schema.json",
  "name": "overview_page",
  "displayName": "Sales Overview",
  "displayOption": "FitToPage",
  "height": 720,
  "width": 1280,
  "filters": [],
  "background": {
    "color": { "solid": { "color": "#FFFFFF" } },
    "transparency": 0
  },
  "wallpaper": {
    "color": { "solid": { "color": "#FFFFFF" } },
    "transparency": 0
  },
  "annotations": []
}
```

### visual.json (Individual Visual)

The visual.json file defines a single visual's position, type, data bindings, and formatting.

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "sales_bar_chart",
  "position": {
    "x": 40,
    "y": 60,
    "z": 1000,
    "width": 560,
    "height": 380,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "clusteredBarChart",
    "query": {
      "queryState": {
        "Category": {
          "projections": [
            {
              "field": {
                "Column": {
                  "Expression": { "SourceRef": { "Entity": "Product" } },
                  "Property": "Category"
                }
              },
              "queryRef": "Product.Category",
              "active": true
            }
          ]
        },
        "Y": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": { "SourceRef": { "Entity": "Sales" } },
                  "Property": "Total Sales"
                }
              },
              "queryRef": "Sales.Total Sales",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {},
    "visualContainerObjects": {
      "title": [{ "properties": { "text": { "expr": { "Literal": { "Value": "'Sales by Category'" } } } } }]
    }
  }
}
```

### Common Visual Types

| visualType Value | Description |
|---|---|
| `clusteredBarChart` | Horizontal bar chart |
| `clusteredColumnChart` | Vertical column chart |
| `lineChart` | Line chart |
| `areaChart` | Area chart |
| `lineClusteredColumnComboChart` | Combo chart (line + column) |
| `pieChart` | Pie chart |
| `donutChart` | Donut chart |
| `card` | Single value card |
| `multiRowCard` | Multi-row card |
| `tableEx` | Table |
| `pivotTable` | Matrix / Pivot table |
| `slicer` | Slicer (dropdown, list, range) |
| `map` | Map visual |
| `filledMap` | Filled/choropleth map |
| `treemap` | Treemap |
| `waterfallChart` | Waterfall chart |
| `funnel` | Funnel chart |
| `gauge` | Gauge |
| `kpi` | KPI indicator |
| `scatterChart` | Scatter plot |
| `textbox` | Text box / Rich text |
| `image` | Image |
| `shape` | Shape |
| `actionButton` | Button |
| `bookmarkNavigator` | Bookmark navigator |
| `pageNavigator` | Page navigator |

### CRITICAL — Common Visual Mistakes to Avoid

> **NEVER invent queryState structures.** Always copy patterns from the examples below or from existing working visuals in the project.

| Mistake | Correct |
|---|---|
| `barChart` | `clusteredBarChart` |
| `columnChart` | `clusteredColumnChart` |
| `table` | `tableEx` |
| `matrix` | `pivotTable` |
| `Categorical` with `categories`/`values` sub-objects | Named-role keys (`Category`, `Y`, `Values`, `Rows`, `Columns`) with `projections` arrays |
| `Relational` with `Primary`/`Groupings`/`Values` | Named-role keys with `projections` arrays |
| `filters: []` in page.json (schema 2.1.0) | Use `filterConfig` or omit entirely — check existing pages for the correct format |

**queryState role mapping by visual type:**

| Visual Type | queryState Roles |
|---|---|
| `clusteredBarChart`, `clusteredColumnChart`, `lineChart`, `areaChart` | `Category` + `Y` |
| `card`, `slicer` | `Values` |
| `tableEx` | `Values` (all columns in one projections array) |
| `pivotTable` | `Rows` + `Columns` + `Values` |
| `treemap` | `Group` + `Values` |
| `pieChart`, `donutChart` | `Category` + `Y` |
| `scatterChart` | `X` + `Y` + `Size` (optional) |
| `lineClusteredColumnComboChart` | `Category` + `Y` + `Y2` |

### Mandatory Post-Edit Visibility Checklist (PBIR)

After adding or editing pages, visuals, slicers, or page/report filters, you MUST perform these checks before concluding work:

1. **Verify page registration:** Ensure each page folder exists and is listed in `definition/pages/pages.json` `pageOrder`.
2. **Verify visual folders exist on disk:** For every expected visual, confirm `definition/pages/<page>/visuals/<visual>/visual.json` exists.
3. **Verify filters are physically present in PBIR:** If filters were requested, confirm the applicable implemented mechanism exists:
   - report-level filters exist in `definition/report.json` (for report filters),
   - page-level filters exist in `definition/pages/<page>/page.json` using the page filter structure already present for that PBIR schema/version in the project (commonly top-level `filters`, or `filterConfig` in newer patterns), and/or
   - slicer visual folders/files exist under `definition/pages/<page>/visuals/<visual>/visual.json`.
   Treat `filters` and `filterConfig` as schema/version-specific representations of page-level filtering in `page.json`; do not switch formats unless the target project/schema requires it.
   Do not claim filters were added if they exist only in plan text.
4. **Verify field bindings:** Confirm each implemented filter references valid model fields (`Entity` + `Property`):
   - for report-level filters, validate the bindings in `definition/report.json`
   - for page-level filters, validate the bindings in whichever `page.json` structure is actually used by that page/schema (`filters` or `filterConfig`)
   - for slicers, validate `queryState.Values.projections`
5. **Run validation:** Execute `powershell ./scripts/Validate-PBIP.ps1 -Path <pbip-root-or-project-folder>` and require `Errors: 0`.
6. **Refresh Power BI Desktop:**
   - If PBIR/report layout changed: use `scripts/Restart-PBIDesktop.ps1`.
   - If only semantic model TMDL changed: use `scripts/Invoke-SemanticModelRefresh.ps1`.
7. **Post-refresh verification:** Re-check visual folder presence and, if filters were requested, report explicit file path(s) showing the implemented filter mechanism: `definition/report.json` for report-level filters, `definition/pages/<page>/page.json` for page-level filters (identify whether the page uses `filters` or `filterConfig`), and/or `definition/pages/<page>/visuals/<visual>/visual.json` for slicer filters.

If any of these checks fail, fix the issue first and re-run the checklist.

### Troubleshooting: Visuals or Slicers Not Appearing After Restart

If users report that newly added visuals/filters are missing from all pages:

1. Verify the visual folders still exist on disk under `definition/pages/<page>/visuals/<visual>/visual.json`.
2. Re-run `powershell ./scripts/Validate-PBIP.ps1 -Path <project-folder>` and require zero errors.
3. Confirm the correct PBIP file is being opened (`*.pbip` points to the expected `.Report` folder).
4. For sample/demo projects, if you are troubleshooting stale state, temporarily set `.pbip` `settings.enableAutoRecovery` to `false` (for example in `examples/power-bi-example-data/pbi-test-data.pbip`) to rule out auto-recovery masking PBIR file changes; restore the original value after troubleshooting if appropriate.
5. Restart PBI Desktop using `scripts/Restart-PBIDesktop.ps1` and wait for full load before checking visuals.

### Adding Filters to Reports — Preferred Approaches

This section covers **two common ways to expose user-facing interactive filtering controls in PBIR**:
Filter Pane filters and on-canvas slicers. Note that the **Filter Pane** can surface report-level,
page-level, or visual-level filters; the examples below focus on page-level filters in `page.json`.

**Important:** Page-level filters have two schema representations. Always match the format already
used by the target project's `page.json` files:
- **`filters` (top-level array)** — used with page schema `1.0.0` and some older versions
- **`filterConfig` (nested object)** — used with page schema `2.1.0` and newer

Do not mix formats within a project unless the schema requires it.

#### 1. Filter Pane Filters (page-level — RECOMMENDED for externally-created reports)

Add page-level filters to `page.json` to define filters visible in the **Filter Pane** (right sidebar).
This is the most reliable approach for externally-authored PBIR because PBI Desktop always renders
the filter pane from `page.json`, unlike canvas slicers which may not render if created externally.

**Schema `2.1.0`+ — `filterConfig` format:**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "my_page_id",
  "displayName": "My Page",
  "displayOption": "FitToPage",
  "height": 720,
  "width": 1280,
  "filterConfig": {
    "filters": [
      {
        "name": "unique_filter_name_across_report",
        "field": {
          "Column": {
            "Expression": { "SourceRef": { "Entity": "TableName" } },
            "Property": "ColumnName"
          }
        },
        "type": "Categorical"
      }
    ]
  }
}
```

**Schema `1.0.0` — top-level `filters` format:**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/1.0.0/schema.json",
  "name": "my_page_id",
  "displayName": "My Page",
  "displayOption": "FitToPage",
  "height": 720,
  "width": 1280,
  "filters": [
    {
      "name": "unique_filter_name_across_report",
      "field": {
        "Column": {
          "Expression": { "SourceRef": { "Entity": "TableName" } },
          "Property": "ColumnName"
        }
      },
      "type": "Categorical"
    }
  ]
}
```

**Key rules for page-level filters:**
- Each filter `name` must be **unique across the entire report** (not just the page).
- `type` options: `Categorical` (checkboxes), `Range` (numeric/date range), `Advanced` (complex conditions).
- The `field` format is the same `QueryExpressionContainer` used in visual queries.
- Filters appear in the Filter Pane (right sidebar) which users can expand by clicking the filter icon.

#### 2. Canvas Slicer Visuals (on-canvas interactive controls)

Add a slicer `visual.json` as a visual folder. Canvas slicers are interactive controls rendered on
the page canvas. See the "Slicer Visual Example" section below for the JSON format.

**Important:** Canvas slicers created externally (outside PBI Desktop) may not always render
reliably. If slicers are not visible after restart, **always add page-level filters as a
fallback** using the appropriate format (`filters` or `filterConfig`) for the page's schema version.

### Query Field Reference Patterns

> **CRITICAL — Aggregation Required for Numeric Columns in Value Roles:**
> When placing a numeric column in a value role (card `Values`, chart `Y` axis, etc.),
> you MUST wrap it in an `Aggregation` expression. Bare `Column` references only work
> for categorical/grouping roles (chart `Category` axis, slicer `Values`, etc.).
> Without the `Aggregation` wrapper, the visual will render empty or be invisible.

**Column reference (for category/grouping roles only):**
```json
{
  "field": {
    "Column": {
      "Expression": { "SourceRef": { "Entity": "TableName" } },
      "Property": "ColumnName"
    }
  }
}
```

**Aggregated column reference (for value roles — Sum, Avg, Count, etc.):**
```json
{
  "field": {
    "Aggregation": {
      "Expression": {
        "Column": {
          "Expression": { "SourceRef": { "Entity": "TableName" } },
          "Property": "ColumnName"
        }
      },
      "Function": 0
    }
  }
}
```

Aggregation Function values: 0=Sum, 1=Average, 2=DistinctCount, 3=Min, 4=Max, 5=Count, 6=Median, 7=StdDev, 8=Variance

When using Aggregation, the `queryRef` should reflect it, e.g. `"Sum(TableName.ColumnName)"`.

**Measure reference (no aggregation needed — measures are pre-aggregated):**
```json
{
  "field": {
    "Measure": {
      "Expression": { "SourceRef": { "Entity": "TableName" } },
      "Property": "MeasureName"
    }
  }
}
```

**Hierarchy reference:**
```json
{
  "field": {
    "HierarchyLevel": {
      "Expression": {
        "Hierarchy": {
          "Expression": { "SourceRef": { "Entity": "Date" } },
          "Hierarchy": "Date Hierarchy"
        }
      },
      "Level": "Year"
    }
  }
}
```

---

## Slicer Visual Example

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "date_slicer",
  "position": { "x": 40, "y": 20, "z": 500, "width": 200, "height": 60, "tabOrder": 0 },
  "visual": {
    "visualType": "slicer",
    "query": {
      "queryState": {
        "Values": {
          "projections": [
            {
              "field": {
                "Column": {
                  "Expression": { "SourceRef": { "Entity": "Date" } },
                  "Property": "Year"
                }
              },
              "queryRef": "Date.Year",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {
      "data": [{ "properties": { "mode": { "expr": { "Literal": { "Value": "'Dropdown'" } } } } }]
    }
  }
}
```

---

## Card Visual Example

Card with a **measure** (pre-aggregated, no Aggregation wrapper needed):

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "total_sales_card",
  "position": { "x": 40, "y": 20, "z": 1000, "width": 200, "height": 120, "tabOrder": 0 },
  "visual": {
    "visualType": "card",
    "query": {
      "queryState": {
        "Values": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": { "SourceRef": { "Entity": "Sales" } },
                  "Property": "Total Sales"
                }
              },
              "queryRef": "Sales.Total Sales",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {},
    "visualContainerObjects": {
      "title": [{ "properties": { "text": { "expr": { "Literal": { "Value": "'Total Revenue'" } } } } }]
    }
  }
}
```

Card with a **column** (must use Aggregation wrapper):

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "sum_of_sales_card",
  "position": { "x": 260, "y": 20, "z": 1001, "width": 200, "height": 120, "tabOrder": 1 },
  "visual": {
    "visualType": "card",
    "query": {
      "queryState": {
        "Values": {
          "projections": [
            {
              "field": {
                "Aggregation": {
                  "Expression": {
                    "Column": {
                      "Expression": { "SourceRef": { "Entity": "Sales" } },
                      "Property": "Amount"
                    }
                  },
                  "Function": 0
                }
              },
              "queryRef": "Sum(Sales.Amount)",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {},
    "visualContainerObjects": {
      "title": [{ "properties": { "text": { "expr": { "Literal": { "Value": "'Total Sales Amount'" } } } } }]
    }
  }
}
```

---

## Table Visual Example (tableEx)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "sales_table",
  "position": { "x": 40, "y": 20, "z": 1000, "width": 560, "height": 380, "tabOrder": 0 },
  "visual": {
    "visualType": "tableEx",
    "query": {
      "queryState": {
        "Values": {
          "projections": [
            {
              "field": {
                "Column": {
                  "Expression": { "SourceRef": { "Entity": "Sales" } },
                  "Property": "Country"
                }
              },
              "queryRef": "Sales.Country",
              "active": true
            },
            {
              "field": {
                "Aggregation": {
                  "Expression": {
                    "Column": {
                      "Expression": { "SourceRef": { "Entity": "Sales" } },
                      "Property": "Amount"
                    }
                  },
                  "Function": 0
                }
              },
              "queryRef": "Sum(Sales.Amount)",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {}
  }
}
```

---

## Matrix Visual Example (pivotTable)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "sales_matrix",
  "position": { "x": 40, "y": 20, "z": 1000, "width": 560, "height": 380, "tabOrder": 0 },
  "visual": {
    "visualType": "pivotTable",
    "query": {
      "queryState": {
        "Rows": {
          "projections": [
            {
              "field": {
                "Column": {
                  "Expression": { "SourceRef": { "Entity": "Sales" } },
                  "Property": "Country"
                }
              },
              "queryRef": "Sales.Country",
              "active": true
            }
          ]
        },
        "Columns": {
          "projections": [
            {
              "field": {
                "Column": {
                  "Expression": { "SourceRef": { "Entity": "Product" } },
                  "Property": "Category"
                }
              },
              "queryRef": "Product.Category",
              "active": true
            }
          ]
        },
        "Values": {
          "projections": [
            {
              "field": {
                "Aggregation": {
                  "Expression": {
                    "Column": {
                      "Expression": { "SourceRef": { "Entity": "Sales" } },
                      "Property": "Amount"
                    }
                  },
                  "Function": 0
                }
              },
              "queryRef": "Sum(Sales.Amount)",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {}
  }
}
```

---

## Line Chart Visual Example

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json",
  "name": "sales_trend",
  "position": { "x": 40, "y": 20, "z": 1000, "width": 560, "height": 380, "tabOrder": 0 },
  "visual": {
    "visualType": "lineChart",
    "query": {
      "queryState": {
        "Category": {
          "projections": [
            {
              "field": {
                "Column": {
                  "Expression": { "SourceRef": { "Entity": "Date" } },
                  "Property": "Month"
                }
              },
              "queryRef": "Date.Month",
              "active": true
            }
          ]
        },
        "Y": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": { "SourceRef": { "Entity": "Sales" } },
                  "Property": "Total Sales"
                }
              },
              "queryRef": "Sales.Total Sales",
              "active": true
            }
          ]
        }
      }
    },
    "objects": {}
  }
}
```

---

## definition.pbir

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
  "version": "4.0",
  "datasetReference": {
    "byPath": {
      "path": "../MyReport.SemanticModel"
    }
  }
}
```

---

## definition.pbism

```json
{
  "version": "4.0",
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json"
}
```

---

## Important Rules When Editing

### TMDL Files
1. **Always use TAB for indentation** — never spaces
2. **Generate new GUIDs** for `lineageTag` on new objects (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
3. **Don't modify auto-generated date tables** — they start with `LocalDateTable_`
4. **Save as UTF-8 without BOM**
5. **Use CRLF line endings** on Windows
6. **Don't change** `lineageTag` of existing objects — it breaks references
7. **Expressions** must be indented one level deeper than properties
8. Measure/partition **default expressions** follow `=` on same line (single-line) or next line (multi-line)
9. **Child objects** don't need to be contiguous — measures and columns can be interleaved
10. **Ref ordering** in model.tmdl controls table display order

### PBIR Files
1. **Include `$schema`** at top of every JSON file for validation
2. **Object name = folder/file name** — if you create a new page folder `my_page/`, the `name` in page.json should be `my_page`
3. **Names must match regex**: one or more word characters or hyphens `[\w-]+`
4. **Update pages.json** `pageOrder` array when adding/removing pages
5. **Visual z-order**: higher z = rendered on top
6. **Position units** are in pixels at the report's design resolution
7. **queryRef** format: `TableName.FieldName` or `TableName.Measure Name`
8. **Entity** in SourceRef must match the table name exactly

### After Making Changes
- Power BI Desktop does NOT detect external file changes while running
- Must close and reopen PBI Desktop, OR use the automation scripts to push changes via TOM
- The `scripts/Find-PBIDesktopPort.ps1` discovers the local AS port
- Semantic model changes can be pushed via TOM without full restart
- Report layout changes ALWAYS require a restart

---

## Refresh Strategies

### Strategy 1: TOM Push (Semantic Model Only, No Restart)
Best for: Adding measures, modifying expressions, changing column properties
```powershell
# Find the local Analysis Services port
$port = .\scripts\Find-PBIDesktopPort.ps1
# Push TMDL changes to running instance
.\scripts\Invoke-SemanticModelRefresh.ps1 -Port $port -TmdlPath ".\MyReport.SemanticModel\definition"
```

### Strategy 2: Automated Restart (Any Changes)
Best for: Report layout changes, or when TOM push isn't sufficient
```powershell
.\scripts\Restart-PBIDesktop.ps1 -PbipPath ".\MyReport.pbip"
```

### Strategy 3: Manual
Close PBI Desktop → Reopen the .pbip file (or .pbir file in report folder).

---

## Naming Conventions

- **Table names**: PascalCase or descriptive (`Sales`, `Product`, `Date`, `Customer Addresses`)
- **Column names**: PascalCase matching source where possible (`ProductKey`, `Order Date`)
- **Measure names**: Descriptive with units (`Total Sales`, `Sales YoY %`, `# Orders`)
- **Relationship names**: `rel_FromTable_ToTable` pattern
- **Page names**: snake_case or descriptive lowercase (`overview_page`, `sales_detail`)
- **Visual names**: descriptive of content (`sales_bar_chart`, `date_slicer`, `total_sales_card`)
- **lineageTag**: Always a GUID — generate new ones for new objects

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| PBI Desktop won't open PBIP | Invalid TMDL syntax | Check indentation (must be tabs), check for unclosed quotes |
| "Values must be unique" error | Duplicate lineageTag or name | Generate new GUIDs for new objects |
| Measure shows error in PBI | Invalid DAX expression | Verify table/column names match exactly, check single quotes around names with spaces |
| Visual doesn't render | Invalid query field reference | Verify Entity matches table name, Property matches column/measure name |
| Page missing from report | Not in pages.json pageOrder | Add page folder name to pageOrder array |
| Relationship error | Column data types don't match | Ensure both columns have same dataType |
| TMDL parse error | Wrong indentation or mixed tabs/spaces | Use only TABs, check three-level nesting |
