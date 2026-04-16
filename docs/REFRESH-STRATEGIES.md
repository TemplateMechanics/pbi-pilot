# Refresh Strategies

Power BI Desktop does **not** detect external file changes while running. After AI or external tools edit TMDL/PBIR files, you need to refresh.

## Strategy Comparison

| Strategy | Speed | Scope | Data Preserved? | When to Use |
|----------|-------|-------|----------------|-------------|
| TOM Push | Fast (~5s) | Semantic model only | Yes | Adding/editing measures, columns, relationships |
| Automated Restart | Medium (~30s) | Everything | No (re-cached) | Report layout changes, major model restructuring |
| Manual Restart | Medium (~30s) | Everything | No (re-cached) | When scripts aren't set up |

## Strategy 1: TOM Push (Semantic Model Changes)

Connects to PBI Desktop's local Analysis Services instance and deploys TMDL changes directly. No restart needed.

**Best for:** measures, calculated columns, relationships, table properties, RLS roles

```powershell
# Step 1: Find the local AS port
$port = .\scripts\Find-PBIDesktopPort.ps1

# Step 2: Push TMDL to the running instance
.\scripts\Invoke-SemanticModelRefresh.ps1 -Port $port -TmdlPath ".\MyReport.SemanticModel\definition"
```

**How it works:**
1. PBI Desktop runs `msmdsrv.exe` (Analysis Services) on a random local port
2. The port is written to a port file in the AnalysisServicesWorkspaces folder:
   - **MSI install:** `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces\...\msmdsrv.port.txt`
   - **Store install:** `%USERPROFILE%\Microsoft\Power BI Desktop Store App\AnalysisServicesWorkspaces\...\msmdsrv.port.txt`
3. We connect via `localhost:<port>` using the TOM (Tabular Object Model) .NET library
4. TMDL files are deserialized into a TOM Database object and applied to the running model
5. PBI Desktop synchronizes the changes to the report canvas

**Requirements:**
- `Microsoft.AnalysisServices.Tabular` .NET library (script tries to auto-install)
- Power BI Desktop must be running with a file open

**Limitations:**
- Does NOT handle report layout changes (PBIR)
- Some complex schema changes may require a restart anyway
- Processing commands (data refresh) are not supported through this path

## Strategy 2: Automated Restart

Closes PBI Desktop and reopens the PBIP file. Works for all change types.

```powershell
.\scripts\Restart-PBIDesktop.ps1 -PbipPath ".\MyReport.pbip"

# Or with force (no confirmation prompt):
.\scripts\Restart-PBIDesktop.ps1 -Force
```

**How it works:**
1. Finds running PBI Desktop process
2. Sends graceful close signal (CloseMainWindow)
3. Waits up to 15 seconds for exit
4. Force kills if still running
5. Opens the PBIP file in PBI Desktop

**Limitations:**
- Unsaved changes in PBI Desktop are lost (script warns)
- Takes ~30 seconds for PBI Desktop to fully load
- Data cache may need to be re-imported

## Strategy 3: Manual Restart

1. Save any work in Power BI Desktop
2. Close Power BI Desktop
3. Double-click the `.pbip` file (or `.pbir` file in the report definition folder)
4. Wait for PBI Desktop to fully load

## Strategy 4: External Tool Integration

Register the harness as an External Tool in PBI Desktop. The tool receives the AS server/port automatically.

```powershell
# One-time setup (requires admin for the shared tools folder)
.\scripts\Register-ExternalTool.ps1
```

After registration, a "VS Code AI Harness" button appears in PBI Desktop's External Tools ribbon. Clicking it opens VS Code with the connection info.

## Decision Tree

```
Change Type?
├── Semantic Model (TMDL)
│   ├── Simple (add measure, edit expression) → TOM Push
│   └── Complex (new tables, restructure) → Automated Restart
├── Report Layout (PBIR)
│   └── Always → Automated Restart
└── Both
    └── Automated Restart
```

## Tips

- **Batch your changes** — make all TMDL edits, then push once via TOM
- **For report development**, make multiple PBIR changes before doing a single restart
- **Use validation first** — run `.\scripts\Validate-PBIP.ps1` before attempting a refresh to catch errors early
- **Keep PBI Desktop open** during semantic model work — TOM push is much faster than restart
