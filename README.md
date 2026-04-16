# PowerBI-Harness

**AI-powered conversational interface for Power BI development via PBIP/TMDL/PBIR in VS Code.**

Turn Power BI Desktop projects into a fully AI-editable workflow. This harness gives GitHub Copilot, Claude Code, and other AI coding assistants the built-in knowledge and automation scripts to read, modify, and manage Power BI project files — without reading the docs every time.

## The Problem

Power BI Desktop's PBIP format saves semantic models (TMDL) and reports (PBIR) as human-readable text files. This is a breakthrough for version control and collaboration, but the AI workflow has gaps:

1. **AI models don't know PBIP/TMDL/PBIR syntax** — every session starts from scratch
2. **Refresh requires close/reopen** — PBI Desktop doesn't detect external file changes
3. **No automation bridge** — there's nothing connecting VS Code AI tools to PBI Desktop's local Analysis Services instance

## What This Harness Provides

| Component | Purpose |
|---|---|
| `.github/copilot-instructions.md` | Workspace-level instructions for GitHub Copilot — always loaded |
| `skills/powerbi-pbip/SKILL.md` | Copilot skill with complete TMDL, PBIR, and PBIP reference |
| `agents/powerbi.agent.md` | Agent mode for conversational Power BI development |
| `scripts/` | PowerShell automation for port discovery, refresh, and validation |
| `examples/` | Real TMDL and PBIR examples for AI to learn from |
| `docs/` | Quick-reference guides for TMDL syntax and PBIR structure |

## Quick Start

### 1. Clone/Copy into your PBIP project root

```
your-project/
├── .github/copilot-instructions.md    ← copy from this harness
├── skills/powerbi-pbip/SKILL.md       ← copy from this harness
├── agents/powerbi.agent.md            ← copy from this harness  
├── scripts/                           ← copy from this harness
├── MyReport.Report/
├── MyReport.SemanticModel/
└── MyReport.pbip
```

Or add the harness as a second workspace folder in VS Code.

### 2. Enable PBIP + TMDL + PBIR in Power BI Desktop

In Power BI Desktop: **File → Options → Preview features**, enable:
- ✅ Power BI Project (.pbip) save option
- ✅ Store semantic model using TMDL format
- ✅ Store reports using enhanced metadata format (PBIR)

Save your file as `.pbip`.

### 3. Start talking to your AI

With the skill and instructions loaded, your AI assistant now understands:
- TMDL syntax for measures, columns, tables, relationships
- PBIR JSON structure for pages, visuals, bookmarks
- DAX patterns for common business logic
- How to add, modify, or remove model objects
- How to create and configure report visuals

**Example prompts:**
```
"Add a YTD sales measure to the Sales table"
"Create a new report page with a bar chart showing sales by region"
"Add a relationship between Sales.ProductKey and Product.ProductKey"
"Show me all measures in the model"
"Add a date slicer to the overview page"
```

### 4. Refresh Power BI Desktop

After AI makes changes to your TMDL/PBIR files:

**Option A — Automated (semantic model changes via TOM):**
```powershell
.\scripts\Find-PBIDesktopPort.ps1
.\scripts\Invoke-SemanticModelRefresh.ps1 -PbipPath ".\MyReport.SemanticModel"
```

**Option B — Restart cycle:**
```powershell
.\scripts\Restart-PBIDesktop.ps1 -PbipPath ".\MyReport.pbip"
```

**Option C — Manual:**
Close Power BI Desktop → Reopen the `.pbip` file.

## Prerequisites

- [Power BI Desktop](https://powerbi.microsoft.com/desktop/) (latest version)
- [VS Code](https://code.visualstudio.com/) with GitHub Copilot or another AI coding assistant
- [TMDL VS Code Extension](https://marketplace.visualstudio.com/items?itemName=analysis-services.TMDL) (recommended)
- PowerShell 5.1+ (comes with Windows)

## How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  AI Assistant    │────▶│  PBIP Files       │────▶│  Power BI Desktop   │
│  (Copilot/Claude)│     │  (.tmdl, .json)   │     │  (reads on open)    │
│                  │     │                   │     │                     │
│  Has: SKILL.md   │     │  Edited directly  │     │  Local AS instance  │
│  Has: instructions│     │  by AI or user    │     │  on localhost:PORT  │
│  Has: examples   │     │                   │     │                     │
└─────────────────┘     └──────────────────┘     └─────────────────────┘
                                                          │
                              ┌────────────────────────────┘
                              ▼
                    ┌─────────────────────┐
                    │  scripts/           │
                    │  • Port discovery   │
                    │  • TOM push changes │  
                    │  • Auto restart     │
                    │  • Validation       │
                    └─────────────────────┘
```

**Key insight:** PBI Desktop runs a local Analysis Services engine on a random port. The harness scripts discover this port and can push semantic model changes through TOM (Tabular Object Model) without a full restart. For report layout changes, an automated restart cycle handles the close/reopen.

## File Encoding

PBIP files must be saved as **UTF-8 without BOM**. Configure your editor accordingly. The included `.vscode/settings.json` handles this.

## License

MIT
