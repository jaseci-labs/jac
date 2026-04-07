# JacCoder Architecture

An AI coding agent built with the **Jaseci stack** — Jac language, `byllm` for LLM integration, and `jac-scale` for API serving. JacCoder uses Object-Spatial Programming (OSP) where walkers traverse a persistent node graph to process messages, and a MainAgent orchestrator delegates complex tasks to ephemeral SubAgent walkers.

---

## Graph Architecture

```
Root
  ├──> Session          (per-chat state, history, tracking)
  ├──> MainAgent        (orchestrator — handles or delegates)
  └──> ProjectMemory    (AST-derived codebase knowledge)
```

| Node | Purpose | Key Fields |
|------|---------|------------|
| `Session` | Chat state | chat_history, active_files, pending_errors, project_summary |
| `MainAgent` | Orchestrator | `respond() by llm(tools=[...])` — 20+ tools |
| `ProjectMemory` | Codebase knowledge | architecture, node_details, walker_details, import_map |

---

## Walker Traversal

The `interact` walker processes each user message in 2 steps:

```
Public API / CLI / REST
         │
         ▼
       Root ──step 1──> Session ──step 2──> MainAgent
                          │                     │
                     load memory           respond() by llm()
                     append message         ├─ handle directly (simple)
                     build context          └─ spawn_agent() (complex)
                                                  │
                                            SubAgent (worker/explorer)
                                                  │
                                            result → MainAgent
```

**Step 1 — `init_session` (Root)**: Find/create Session, ensure MainAgent exists.

**Step 2 — `enter_session` (Session)**: Load ProjectMemory, append user message, compact context, visit MainAgent.

**Step 3 — `respond` (MainAgent)**: LLM decides to handle directly or delegate via `spawn_agent()`.

---

## Orchestrator-Worker Pattern

MainAgent decides how to handle each task:

**Simple tasks** (bug fix, read file, small edit) → MainAgent handles directly with its own tools.

**Complex tasks** (build feature, multi-file refactor) → MainAgent calls `think()` to plan, then `spawn_agent()` to delegate.

### SubAgent Modes

| Mode | Tools | Purpose |
|------|-------|---------|
| `worker` | write, edit, check, run, git, scaffold + read tools | Can modify files |
| `explorer` | read, search, analyze, docs | Read-only investigation |

SubAgents are **ephemeral** — spawned as subprocess, tools attached by code (not LLM), return result to MainAgent.

---

## Tool System

22 tools organized into modules:

```
tool/
├── filesystem.jac ── read_file, write_file, edit_file, list_files
├── search.jac ────── grep_search, find_files
├── shell.jac ─────── bash_exec
├── checked.jac ───── write_code, edit_code (auto jac_check)
├── guarded.jac ───── run_command (permission-wrapped bash)
├── jac_tools.jac ─── jac_check, jac_run
├── jac_analyzer.jac─ analyze_project, find_symbol (AST-based)
├── jac_docs.jac ──── jac_docs (language reference)
├── web.jac ───────── web_fetch, web_search
├── git.jac ───────── git_status, git_diff, git_log, git_commit
├── think.jac ─────── think (chain-of-thought reasoning)
├── delegation.jac ── spawn_agent (SubAgent spawning)
├── question.jac ──── ask_question
├── todo.jac ──────── update_todos
├── task.jac ──────── spawn_task (legacy, delegates to spawn_agent)
└── scaffold.jac ──── scaffold_project
```

### Self-Correcting Tools

Every `.jac` file write auto-runs `jac_check`. Errors feed back into the ReAct loop:

```
write_code("app.jac", code) → write to disk → jac_check
  ├─ clean → "File written. jac_check passed."
  └─ errors → "File written. 2 errors: ... ⚠ Fix these before moving on."
              → LLM sees error → edit_code → jac_check → clean
```

---

## Jac Intelligence

Compiler-level understanding via jaclang's `JacProgram` AST API:

- `analyze_project(directory)` → all nodes, walkers, edges, imports, client components
- `find_symbol(name)` → definition location, fields, abilities, usages, correct import

AST data auto-injected into ProjectMemory at session start — agent knows codebase structure from turn 1.

---

## Context Management

`build_context()` compacts chat history before each LLM call (deterministic, no LLM cost):

```
[1] project_summary (from ProjectMemory)     ~500 tokens
[2] summary of old turns (condensed)          ~200 tokens
[3] important old turns (file writes, errors) variable
[4] recent turns verbatim (last 8 exchanges)  ~10K tokens
[5] active_files, pending_errors              ~300 tokens
```

Token budget: 20K. Compaction triggers at 80%.

---

## Public API

External apps import only from `jac_coder.api`:

```jac
import from jac_coder.api { initialize, create_session, chat, close_session }
```

| Function | Purpose |
|----------|---------|
| `initialize(mode)` | Setup permissions ("web" or "cli") |
| `create_session(dir, title)` | Create session + init memory |
| `chat(session_id, message)` | Full agent execution → response dict |
| `close_session(session_id)` | Archive session |

Internal changes never break external integrations.

---

## Permission System

```
Always allowed: read_file, list_files, grep_search, find_files, web_*, jac_*, analyze_*, think
Ask per resource: write_file, edit_file, bash_exec
Web mode (JacBuilder): all tools auto-allowed
```

---

## Configuration

Precedence (lowest → highest): code defaults → `~/.jaccoder/config.json` → `./jaccoder.json` → environment variables (`MODEL`, `TEMPERATURE`, `MAX_TOKENS`, `MAX_REACT_ITERATIONS`).

---

## Testing

61 tests across 7 suites:

| Suite | Tests | Covers |
|-------|-------|--------|
| Graph | 7 | Session, MainAgent, edges |
| Tools | 8 | read, write, edit, search, bash |
| Walker | 6 | Session creation, traversal |
| Self-Correction | 13 | checked tools, error detection |
| Events | 6 | tool events, timing, summaries |
| Context | 9 | compaction, priority ordering |
| Memory | 9 | AST scan, dedup, summarize |
