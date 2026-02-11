# Shire — Project Proposal

## Overview

Shire is a native macOS application that turns any folder on your machine into an AI-powered workspace. You point it at a directory, and it gives you a chat interface backed by **Claude Code** — the Anthropic CLI tool already installed on your system. Shire does not bundle its own AI agent or tools; it is a native UI layer over Claude Code, which already provides file reading, writing, search, shell execution, and everything else needed for a local coding assistant.

### Why Claude Code?

Apps like Conductor, Craft Agent, and One Code all work with Claude Code. Most bundle their own binary. Shire takes a different approach: it uses the Claude Code installation already on your machine. This means:

- **No duplicate binaries** — no 100MB+ bundled CLI
- **Always up to date** — you update Claude Code once, Shire benefits
- **Your existing auth works** — no re-authentication needed
- **All tools included** — Read, Write, Edit, Bash, Glob, Grep, WebSearch, and 20+ more tools are built into Claude Code
- **No agent to maintain** — we don't build tool definitions, sandboxing, or orchestration; Claude Code handles all of it

### Why Native macOS?

Shire v0 was an Electron app. The rewrite uses **AppKit** (not SwiftUI) for a truly native macOS experience:

- Native window chrome, vibrancy, and traffic lights
- NSOutlineView sidebar, NSTableView message list
- Real macOS context menus and keyboard shortcuts
- Small binary size, fast launch, low memory usage
- No web renderer overhead

---

## Core Concepts

### Workspace
A workspace is a reference to a local directory. It stores metadata (name, path, created date) and serves as the working directory for Claude Code. All AI operations are scoped to this directory.

### Chat Session
Each workspace can have multiple independent chat sessions. A session maps 1:1 to a Claude Code session (via `--resume`). Sessions are persisted — messages, tool calls, tool results, and generated artifacts.

### Artifact
When Claude Code writes or creates a file, the app tracks it as an artifact — a database record linking the chat session to that file path, capturing metadata like creation time and the originating message.

---

## Features

### v0.1 — MVP

- **Workspace management** — Create, open, rename, delete workspaces (each backed by a local folder).
- **Sidebar navigation** — Persistent sidebar listing workspaces with nested chat sessions (5 most recent shown per workspace, "Show more" expands the rest).
- **Chat interface** — Multi-turn conversation with Claude Code. Streaming responses rendered in real-time.
- **All Claude Code tools** — The model can read files, write files, search with glob/ripgrep, run shell commands, edit files — everything Claude Code supports, with no custom tool definitions.
- **Session persistence** — All messages, tool calls, and results stored in SQLite.
- **Multi-turn via `--resume`** — Each Shire session maps to a Claude Code session ID. Subsequent messages resume the conversation seamlessly.
- **Artifact tracking** — Files written by Claude Code are tracked as artifacts linked to the originating session and message.
- **Tool call display** — Collapsible blocks showing tool name, summary, and expandable input/output.
- **Auto-generated session titles** — Claude Code generates a short title after the first exchange.
- **Claude Code auto-detection** — Discovers the `claude` binary via PATH, Homebrew paths, or user config. Offers one-click Homebrew install if not found.
- **Token usage tracking** — Per-message token counts from Claude Code's result events, running total shown per session.
- **Model selection** — Switch between sonnet, opus, haiku via settings.
- **Cost control** — Per-message budget limit via `--max-budget-usd`.

### Future (out of scope for v0.1)

- File diff view for AI-generated changes.
- Git integration (commit, diff, branch awareness).
- Workspace-level context/system prompt customization.
- MCP server integration (extend Claude Code with custom tools).
- Multi-window support (one window per workspace).
- Auto-updates via Sparkle.
- Conversation export.

---

## Architecture

```
shire/
├── apps/
│   ├── macos/                              # Native macOS app (Xcode)
│   │   ├── Shire.xcodeproj/
│   │   ├── Shire/
│   │   │   ├── App/
│   │   │   │   ├── AppDelegate.swift              # NSApplication lifecycle
│   │   │   │   └── MainMenu.swift                 # Programmatic NSMenu
│   │   │   ├── Windows/
│   │   │   │   └── MainWindowController.swift     # Frameless window, vibrancy
│   │   │   ├── ViewControllers/
│   │   │   │   ├── SplitViewController.swift      # NSSplitViewController
│   │   │   │   ├── SidebarViewController.swift    # NSOutlineView sidebar
│   │   │   │   ├── ContentViewController.swift    # Child VC swapping
│   │   │   │   ├── ChatViewController.swift       # Message list + composer
│   │   │   │   ├── WorkspaceViewController.swift  # Workspace overview
│   │   │   │   └── SettingsViewController.swift   # Preferences panel
│   │   │   ├── Views/
│   │   │   │   ├── MessageCellView.swift          # Chat message row
│   │   │   │   ├── ToolCallCellView.swift         # Collapsible tool call
│   │   │   │   ├── StreamingTextView.swift        # Append-only streaming
│   │   │   │   ├── ComposerView.swift             # Auto-growing input
│   │   │   │   ├── SidebarRowView.swift           # Sidebar row
│   │   │   │   └── MarkdownRenderer.swift         # Markdown → NSAttributedString
│   │   │   ├── Models/
│   │   │   │   ├── Workspace.swift
│   │   │   │   ├── Session.swift
│   │   │   │   ├── Message.swift
│   │   │   │   ├── Artifact.swift
│   │   │   │   └── Settings.swift
│   │   │   ├── Database/
│   │   │   │   ├── DatabaseManager.swift          # GRDB connection + migrations
│   │   │   │   ├── Schema.swift                   # Migration SQL
│   │   │   │   ├── WorkspaceRepository.swift
│   │   │   │   ├── SessionRepository.swift
│   │   │   │   ├── MessageRepository.swift
│   │   │   │   ├── ArtifactRepository.swift
│   │   │   │   └── SettingsRepository.swift
│   │   │   ├── ClaudeCode/
│   │   │   │   ├── ClaudeCodeRunner.swift         # Binary discovery
│   │   │   │   ├── ClaudeCodeSession.swift        # Process lifecycle
│   │   │   │   ├── StreamParser.swift             # NDJSON parser
│   │   │   │   └── StreamEvent.swift              # Codable stream types
│   │   │   ├── Services/
│   │   │   │   ├── ChatService.swift              # Orchestration
│   │   │   │   ├── WorkspaceService.swift         # Workspace CRUD
│   │   │   │   └── SettingsService.swift          # Settings management
│   │   │   └── Utilities/
│   │   │       ├── UUIDv7.swift
│   │   │       └── NSColor+Theme.swift
│   │   ├── Resources/
│   │   │   └── Assets.xcassets/
│   │   └── Package.swift                          # SPM dependencies
│   │
│   └── landing/                             # Marketing page (Vite + React)
│
├── PROPOSAL.md
├── README.md
├── package.json                             # Landing page workspace only
└── .gitignore
```

---

## Decisions

| # | Decision | Choice | Notes |
|---|---|---|---|
| 1 | Build system | **Xcode + Swift Package Manager** | Native toolchain, no JS build step |
| 2 | UI framework | **AppKit** | NSWindow, NSSplitViewController, NSOutlineView, NSTableView, NSTextView |
| 3 | State management | **Delegate pattern + NotificationCenter** | Standard AppKit; no reactive framework needed |
| 4 | AI backend | **Claude Code CLI subprocess** | `claude -p --output-format stream-json`, user's system install |
| 5 | Multi-turn | **`--resume <session_id>`** | Claude Code's built-in session management |
| 6 | Binary discovery | **PATH + Homebrew paths + user override** | Offer Homebrew install if not found |
| 7 | Database | **SQLite via GRDB.swift** | DatabasePool, WAL mode, migration system |
| 8 | Database location | **`~/Library/Application Support/Shire/shire.db`** | Standard macOS app data path |
| 9 | Migrations | **GRDB DatabaseMigrator on app startup** | Auto-runs pending migrations at launch |
| 10 | Session titles | **Auto-generated after first exchange** | Brief Claude Code call produces 4-6 word title |
| 11 | Tool call display | **Collapsible NSDisclosureButton blocks** | Summary line + expandable JSON I/O |
| 12 | Markdown rendering | **`AttributedString(markdown:)` + `swift-markdown`** | Built into macOS 13+; swift-markdown for code blocks |
| 13 | Token tracking | **From Claude Code `result` event** | `usage.inputTokens` + `outputTokens`, stored per message |
| 14 | Window management | **Single window** | NSSplitViewController with sidebar for navigation |
| 15 | Concurrency | **GCD (DispatchQueue)** | Background queue for subprocess I/O, main queue for UI |
| 16 | Authentication | **Delegated to Claude Code** | No API key management in Shire; Claude Code handles its own auth |
| 17 | Security | **Delegated to Claude Code** | Path sandboxing, tool permissions, file size limits — all handled by CC |
| 18 | Minimum target | **macOS 13.0 (Ventura)** | Required for `AttributedString(markdown:)` |
| 19 | Distribution | **Direct download (GitHub Releases)** | Mac App Store deferred |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | **Swift 5.9+** |
| UI framework | **AppKit** (NSWindow, NSSplitViewController, NSOutlineView, NSTableView, NSTextView) |
| Database | **SQLite via GRDB.swift** |
| AI backend | **Claude Code CLI** (subprocess, user's system install) |
| Markdown | **`AttributedString(markdown:)` + `swift-markdown`** for code blocks |
| Package manager | **Swift Package Manager** |
| Build system | **Xcode 15+** |
| Deployment target | **macOS 13.0+ (Ventura)** |

---

## Claude Code Integration

Shire communicates with Claude Code exclusively via subprocess. No SDK, no API calls, no custom tools.

### Binary Discovery

```swift
// ClaudeCodeRunner.swift
// Search order:
// 1. UserDefaults override (Settings > Advanced > Claude Code path)
// 2. /opt/homebrew/bin/claude (Apple Silicon Homebrew)
// 3. /usr/local/bin/claude (Intel Homebrew)
// 4. `which claude` via Process (general PATH lookup)
// 5. Not found → onboarding screen with Homebrew install button
```

### Subprocess Invocation

```bash
# First message in a session
claude --print \
  --output-format stream-json \
  --verbose \
  --include-partial-messages \
  --model sonnet \
  --append-system-prompt "You are Shire, a local coding assistant." \
  "user message here"

# Subsequent messages (multi-turn)
claude --print \
  --output-format stream-json \
  --verbose \
  --include-partial-messages \
  --model sonnet \
  --resume <claude_session_id> \
  "follow-up message"
```

### Stream JSON Format

Claude Code's `stream-json` output is newline-delimited JSON. Each line is one of:

| Type | Purpose | Key Fields |
|---|---|---|
| `system` | Session initialization | `sessionId`, `model`, `tools` |
| `stream_event` | Real-time content deltas | `event` (content_block_delta, etc.), `delta.text` |
| `assistant` | Complete assistant message | `content[]` (text + tool_use blocks) |
| `result` | Final result | `session_id`, `cost_usd`, `duration_ms`, `usage` |

### Process Management

- **Working directory**: set to `workspace.path` via `Process.currentDirectoryURL`
- **Environment**: inherited from `ProcessInfo.processInfo.environment` (picks up API keys, PATH)
- **Cancellation**: `process.terminate()` (SIGTERM), then SIGKILL after 2s
- **One subprocess per send**: each user message spawns a new Process; in-progress sends are cancelled first

---

## Native Desktop Feel

### Window Chrome
- Frameless window: `titlebarAppearsTransparent = true`, `titleVisibility = .hidden`, `.fullSizeContentView` style mask
- Traffic light offset: (16, 16) via button superview frame adjustment
- Sidebar vibrancy: `NSVisualEffectView` with `.sidebar` material
- Window state persistence: `setFrameAutosaveName("MainWindow")`
- Size: default 1200x800, min 800x600

### Interactions
- **Native context menus** — `NSMenu` on right-click workspace/session rows
- **Keyboard-first** — Cmd+N new session, Cmd+Shift+N new workspace, Cmd+, settings
- **Drag and drop** — Drop a folder onto the window to create a workspace
- **Enter to send** — Enter sends message, Shift+Enter inserts newline

### UI View Hierarchy

```
NSWindow (frameless, vibrancy)
└── NSSplitViewController
    ├── Sidebar (NSSplitViewItem, min:200, max:400, default:260)
    │   └── SidebarViewController
    │       ├── NSVisualEffectView (.sidebar material)
    │       ├── NSScrollView → NSOutlineView
    │       │   ├── Workspace rows (expandable)
    │       │   │   └── Session rows (children)
    │       │   └── "Show more..." virtual rows
    │       └── Bottom bar: [+ New Workspace] [⚙ Settings]
    │
    └── Content (NSSplitViewItem)
        └── ContentViewController (swaps child VCs)
            ├── WorkspaceViewController (overview, new chat button)
            └── ChatViewController
                ├── Header (session title, model badge, tokens)
                ├── NSScrollView → NSTableView (messages)
                │   ├── MessageCellView (user — right, colored)
                │   ├── MessageCellView (assistant — left, markdown)
                │   ├── ToolCallCellView (collapsible disclosure)
                │   └── Streaming indicator row
                └── ComposerView (auto-growing NSTextView + send button)
```

### Sidebar Behavior

```
┌──────────────────────────┐
│  Shire                   │  ← app name, drag region
├──────────────────────────┤
│                          │
│  ▼ my-project            │  ← workspace (expanded)
│     Session title 1    * │  ← active session
│     Session title 2      │
│     Session title 3      │
│     Session title 4      │
│     Session title 5      │
│     Show more...         │
│                          │
│  ► another-project       │  ← collapsed
│                          │
├──────────────────────────┤
│  [+ New workspace]  [⚙]  │  ← footer
└──────────────────────────┘
```

- Clicking a workspace name expands/collapses and navigates to workspace view
- Clicking a session navigates to that chat
- Right-click workspace → rename, reveal in Finder, delete
- Right-click session → rename, delete
- `+` icon on workspace row hover creates new session
- New workspace button → NSOpenPanel folder picker

---

## Database Schema

```sql
-- All IDs are UUIDv7 (sortable by creation time)
-- Timestamps are unix milliseconds

CREATE TABLE workspaces (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  path        TEXT NOT NULL UNIQUE,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE TABLE sessions (
  id                  TEXT PRIMARY KEY,
  workspace_id        TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  claude_session_id   TEXT,              -- Claude Code session ID for --resume
  title               TEXT,              -- null until auto-generated
  created_at          INTEGER NOT NULL,
  updated_at          INTEGER NOT NULL
);
CREATE INDEX idx_sessions_workspace ON sessions(workspace_id, updated_at DESC);

CREATE TABLE messages (
  id            TEXT PRIMARY KEY,
  session_id    TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  role          TEXT NOT NULL,           -- 'user' | 'assistant' | 'tool'
  content       TEXT,                    -- nullable for pure tool-call messages
  tool_calls    TEXT,                    -- JSON: [{ id, name, arguments }]
  tool_call_id  TEXT,                    -- for role='tool', references which call
  token_count   INTEGER,                -- from Claude Code result event
  cost_usd      REAL,                   -- from Claude Code result event
  created_at    INTEGER NOT NULL,
  "order"       INTEGER NOT NULL        -- sequence within session
);
CREATE INDEX idx_messages_session ON messages(session_id, "order");

CREATE TABLE artifacts (
  id          TEXT PRIMARY KEY,
  session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  message_id  TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  file_path   TEXT NOT NULL,            -- relative to workspace root
  operation   TEXT NOT NULL,            -- 'create' | 'write' | 'edit'
  created_at  INTEGER NOT NULL
);
CREATE INDEX idx_artifacts_session ON artifacts(session_id);

CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT                            -- JSON-encoded value
);
```

---

## Data Flow — Chat Send

```
User types message in ComposerView
       │
       ▼
ChatViewController calls ChatService.send(sessionId, content)
       │
       ▼
ChatService:
  1. Load session + workspace from DB
  2. Persist user message to messages table
  3. Check session.claude_session_id:
     - nil → first message, no --resume flag
     - exists → add --resume <id> flag
  4. Spawn Process:
     claude -p "content" --output-format stream-json --verbose
       --include-partial-messages --model <settings.model>
       [--resume <claude_session_id>]
     cwd = workspace.path
  5. StreamParser reads stdout pipe, emits StreamEvents
  6. Events dispatched to main thread → ChatViewController:
     - text deltas → StreamingTextView appends text
     - tool_use blocks → ToolCallCellView appears (running state)
     - tool_result → ToolCallCellView updates (done state)
  7. On "result" event:
     - Store session_id from result → session.claude_session_id (if first msg)
     - Persist assistant message to DB (content + tool_calls JSON)
     - Store cost_usd + token counts from result
     - Extract write/edit tool calls → create artifact records
     - Update session.updatedAt
     - Auto-generate title if first exchange
     - Notify UI: streaming done
       │
       ▼
ChatViewController: table reloads, streaming indicator removed
```

---

## Settings

Claude Code manages its own authentication. Shire exposes these settings:

| Setting | Storage | Passed as |
|---|---|---|
| Model (sonnet/opus/haiku) | DB settings table | `--model` flag |
| Allowed tools | DB settings table | `--allowedTools` flag |
| Max budget (USD) | DB settings table | `--max-budget-usd` flag |
| Custom system prompt | DB settings table | `--append-system-prompt` flag |
| Claude Code binary path | UserDefaults | Used by ClaudeCodeRunner |

No API key management. No provider selection. Claude Code handles all of that.

---

## Build & Development

```bash
# Prerequisites
# 1. Xcode 15+ (from Mac App Store)
# 2. Claude Code (brew install claude-code, or npm install -g @anthropic-ai/claude-code)

# Open in Xcode
open apps/macos/Shire.xcodeproj

# Build from command line
xcodebuild -project apps/macos/Shire.xcodeproj -scheme Shire -configuration Debug build

# Run
xcodebuild -project apps/macos/Shire.xcodeproj -scheme Shire -configuration Debug build
open apps/macos/build/Debug/Shire.app

# Landing page (separate, unchanged)
cd apps/landing && bun install && bun dev
```

---

## Package Dependencies (SPM)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    .package(url: "https://github.com/apple/swift-markdown", from: "0.5.0"),
]
```

| Package | Purpose |
|---|---|
| **GRDB.swift** | SQLite — DatabasePool, migrations, Record protocol |
| **swift-markdown** | Markdown AST parsing for code block rendering |

Everything else is built into AppKit/Foundation.

---

## Implementation Order

1. **Scaffold** — Xcode project, AppDelegate, frameless window, split view
2. **Database** — GRDB setup, schema migration, all repositories
3. **Sidebar** — NSOutlineView, workspace/session CRUD, context menus
4. **Claude Code** — Binary discovery, subprocess management, stream parsing
5. **Chat UI** — Message table, markdown rendering, streaming text, composer
6. **Settings** — Preferences panel, model/tools/budget configuration
7. **Polish** — Menu bar, keyboard shortcuts, drag-and-drop, animations, empty states
