# PBIR Quick Reference

## Folder Structure

```
definition/
├── report.json              # Report-level config, theme, filters
├── version.json             # PBIR format version
├── reportExtensions.json    # Report-level measures
├── pages/
│   ├── pages.json           # Page order and active page
│   └── [pageName]/
│       ├── page.json        # Page settings
│       └── visuals/
│           └── [visualName]/
│               ├── visual.json  # Visual definition
│               └── mobile.json  # Mobile layout (optional)
└── bookmarks/
    ├── bookmarks.json       # Bookmark order/groups
    └── [name].bookmark.json # Individual bookmark
```

## Common Operations

### Add a New Page

1. Create folder: `definition/pages/my_new_page/`
2. Create `page.json` inside it
3. Add `"my_new_page"` to `pages.json` → `pageOrder` array

### Add a Visual to a Page

1. Create folder: `definition/pages/my_page/visuals/my_visual/`
2. Create `visual.json` inside it

### Remove a Page

1. Delete the page folder
2. Remove from `pages.json` → `pageOrder` array

## Visual Types

| visualType | Description |
|---|---|
| `card` | Single value card |
| `multiRowCard` | Multi-row card |
| `clusteredBarChart` | Horizontal bars |
| `clusteredColumnChart` | Vertical columns |
| `stackedBarChart` | Stacked horizontal bars |
| `stackedColumnChart` | Stacked vertical columns |
| `hundredPercentStackedBarChart` | 100% stacked bars |
| `hundredPercentStackedColumnChart` | 100% stacked columns |
| `lineChart` | Line chart |
| `areaChart` | Area chart |
| `stackedAreaChart` | Stacked area |
| `lineClusteredColumnComboChart` | Line + column combo |
| `lineStackedColumnComboChart` | Line + stacked column combo |
| `pieChart` | Pie chart |
| `donutChart` | Donut chart |
| `treemap` | Treemap |
| `waterfallChart` | Waterfall chart |
| `funnel` | Funnel chart |
| `scatterChart` | Scatter/bubble chart |
| `map` | Bing map |
| `filledMap` | Choropleth map |
| `shapeMap` | Shape map |
| `gauge` | Gauge |
| `kpi` | KPI visual |
| `tableEx` | Table |
| `pivotTable` | Matrix |
| `slicer` | Slicer |
| `textbox` | Rich text box |
| `image` | Image |
| `shape` | Shape |
| `actionButton` | Button |
| `bookmarkNavigator` | Bookmark navigator |
| `pageNavigator` | Page navigator |
| `decompositionTreeVisual` | Decomposition tree |
| `keyInfluencersVisual` | Key influencers |
| `qnaVisual` | Q&A |
| `smartNarrativeVisual` | Smart narrative |

## Query Field Patterns

### Column
```json
{
  "field": {
    "Column": {
      "Expression": { "SourceRef": { "Entity": "TableName" } },
      "Property": "ColumnName"
    }
  },
  "queryRef": "TableName.ColumnName",
  "active": true
}
```

### Measure
```json
{
  "field": {
    "Measure": {
      "Expression": { "SourceRef": { "Entity": "TableName" } },
      "Property": "MeasureName"
    }
  },
  "queryRef": "TableName.MeasureName",
  "active": true
}
```

### Hierarchy Level
```json
{
  "field": {
    "HierarchyLevel": {
      "Expression": {
        "Hierarchy": {
          "Expression": { "SourceRef": { "Entity": "TableName" } },
          "Hierarchy": "HierarchyName"
        }
      },
      "Level": "LevelName"
    }
  },
  "queryRef": "TableName.HierarchyName.LevelName",
  "active": true
}
```

## Query Buckets by Visual Type

| Visual Type | Buckets |
|---|---|
| Card | `Values` |
| Bar/Column Chart | `Category`, `Y` (values), `Series` (legend) |
| Line Chart | `Category` (axis), `Y` (values), `Series` (legend) |
| Pie/Donut | `Category` (legend), `Y` (values) |
| Table | `Values` (all columns/measures) |
| Matrix | `Rows`, `Columns`, `Values` |
| Slicer | `Values` |
| Scatter | `Category` (details), `X`, `Y`, `Size` |
| Map | `Category` (location), `Size`, `Color` |
| Gauge | `Y` (value), `TargetValue`, `MinValue`, `MaxValue` |
| KPI | `Goal`, `Indicator`, `TrendAxis` |

## Position Properties

```json
{
  "position": {
    "x": 40,       // Pixels from left
    "y": 20,       // Pixels from top
    "z": 1000,     // Z-order (higher = on top)
    "width": 300,  // Width in pixels
    "height": 200, // Height in pixels
    "tabOrder": 0  // Tab navigation order
  }
}
```

Default page size: **1280 x 720** pixels.

## Slicer Modes

```json
"objects": {
  "data": [{
    "properties": {
      "mode": { "expr": { "Literal": { "Value": "'Dropdown'" } } }
    }
  }]
}
```

Modes: `'Dropdown'`, `'List'`, `'Between'` (range), `'Before'`, `'After'`

## Visual Title

```json
"visualContainerObjects": {
  "title": [{
    "properties": {
      "text": { "expr": { "Literal": { "Value": "'My Title'" } } },
      "show": { "expr": { "Literal": { "Value": "true" } } }
    }
  }]
}
```

## Naming Convention

- Folder/file names must match the `name` property in the JSON
- Names: word characters and hyphens only `[\w-]+`
- Use descriptive names: `sales_by_category`, `date_slicer`, `overview_page`
