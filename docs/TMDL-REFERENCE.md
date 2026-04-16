# TMDL Quick Reference

## Syntax At a Glance

```
objectType objectName                    ← Object declaration
    propertyName: value                  ← Property (colon)
    childType childName = expression     ← Child with default (equals)
        nestedProperty: value            ← Child property
            multiLineExpression          ← Expression (deepest level)
```

**Indentation:** TAB characters only. Three levels: object → property → expression.

## Object Types

| Type | Parent | Has Default Property? | Default Property |
|------|--------|-----------------------|------------------|
| `database` | (root) | No | — |
| `model` | (root) | No | — |
| `table` | model | No | — |
| `column` | table | Yes (calculated) | Expression (DAX) |
| `measure` | table | Yes | Expression (DAX) |
| `partition` | table | Yes | SourceType enum |
| `hierarchy` | table | No | — |
| `level` | hierarchy | No | — |
| `relationship` | model | No | — |
| `role` | model | No | — |
| `tablePermission` | role | Yes | FilterExpression (DAX) |
| `expression` | model | Yes | Expression (M) |
| `calculationItem` | table | Yes | Expression (DAX) |
| `perspective` | model | No | — |
| `culture` | model | No | — |

## Property Delimiters

| Delimiter | Used For | Example |
|-----------|----------|---------|
| `:` (colon) | All non-expression properties | `dataType: int64` |
| `=` (equals) | Default properties and expressions | `measure X = SUM(...)` |

## Common Column Properties

```tmdl
column ColumnName
    dataType: string|int64|decimal|double|boolean|dateTime
    formatString: "format"
    lineageTag: guid
    summarizeBy: none|sum|count|min|max|average
    sourceColumn: SourceColumnName
    isHidden
    isKey
    sortByColumn: OtherColumn
    dataCategory: category
    isDefaultLabel
    isDefaultImage
```

## Common Measure Properties

```tmdl
measure 'Measure Name' = DAX_EXPRESSION
    formatString: "format"
    lineageTag: guid
    displayFolder: "Folder Name"
    isHidden
    description: "text"
```

## Format Strings

| Pattern | Example Output |
|---------|---------------|
| `$ #,##0.00` | $ 1,234.56 |
| `$ #,##0` | $ 1,235 |
| `#,##0` | 1,235 |
| `#,##0.00` | 1,234.56 |
| `0.0 %` | 12.3 % |
| `0.00%` | 12.34% |
| `0` | 1235 |
| `Short Date` | 1/15/2024 |
| `Long Date` | Monday, January 15, 2024 |

## Data Types

| TMDL Value | Description |
|------------|-------------|
| `string` | Text |
| `int64` | Whole number (64-bit integer) |
| `decimal` | Fixed decimal (currency-precise) |
| `double` | Floating point |
| `boolean` | True/False |
| `dateTime` | Date and time |
| `binary` | Binary data |

## Partition Types

```tmdl
partition PartName = m              ← M/Power Query (import)
    mode: import
    source = let ... in ...

partition PartName = m              ← M/Power Query (DirectQuery)
    mode: directQuery
    source = let ... in ...

partition PartName = entity         ← Entity partition
    entityName: TableName
    schemaName: dbo

partition PartName = calculated     ← Calculated table
    source = DAX_EXPRESSION
```

## Relationship Properties

```tmdl
relationship name
    fromColumn: FromTable.FromColumn
    toColumn: ToTable.ToColumn
    crossFilteringBehavior: oneDirection|bothDirections|automatic
    isActive
    securityFilteringBehavior: oneDirection|bothDirections
    joinOnDateBehavior: datePartOnly|dateAndTime
```

## Naming Rules

- Enclose in single quotes if name contains: `.` `=` `:` `'` or spaces
- Escape single quotes by doubling: `'Name''s Value'`
- Fully qualified: `'Table Name'.'Column Name'`

## Descriptions (///  triple-slash)

```tmdl
/// This is a table description
/// spanning multiple lines
table Sales

    /// This measure calculates total revenue
    measure 'Total Sales' = SUM(Sales[Amount])
```

## Ref Keyword (ordering & references)

```tmdl
model Model
    ref table Date        ← Controls table ordering
    ref table Sales
    ref table Product

ref table Sales           ← Reference from another file
    column Amount
```
