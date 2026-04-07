# JacCoder Progress Tracker

> Track every task across all phases. Check off as completed.

---

## Phase 1: Self-Correcting Tools

**Status**: Complete

- [x] Remove deprecated `method="ReAct"` from all handler `by llm()` calls
- [x] Create `checked.jac` — `write_code`, `edit_code` with auto `jac_check`
- [x] Store tool metadata (tools_used, files_modified) in chat_history
- [x] Tests: 13 self-correction tests passing

---

## Phase 2: Enhanced Real-Time Output

**Status**: Complete

- [x] Event system: `start_turn`, `track_file`, `track_error`, `emit_turn_summary`
- [x] Tool status/end display with timing
- [x] CLI event renderer
- [x] Tests: 6 event tests passing

---

## Phase 3: Context Window Management

**Status**: Complete

- [x] `build_context()` with tiered priority compaction
- [x] Token budget: 20K, recent window: 8 exchanges
- [x] Session tracks `active_files` and `pending_errors`
- [x] Tests: 9 context tests passing

---

## Phase 4: Project Memory

**Status**: Complete

- [x] ProjectMemory node with AST-derived fields
- [x] `find_or_create_memory`, `_init_memory`, `update_memory_from_session`
- [x] Deterministic `summarize()` — no LLM cost
- [x] Tests: 9 memory tests passing

---

## Phase 5: Jac Intelligence

**Status**: Complete

- [x] `analyze_project(directory)` — compiler-level AST analysis via jaclang
- [x] `find_symbol(name)` — definition, fields, usages, correct import
- [x] AST-first memory scan with LLM fallback
- [x] Analysis caching with 60s TTL
- [x] ProjectMemory auto-populated with node_details, walker_details, import_map
- [ ] Automated tests for AST extraction (deferred)

---

## Phase 6: Public API

**Status**: Complete

- [x] `api.jac` — `initialize`, `create_session`, `chat`, `close_session`
- [x] External apps import only from `jac_coder.api`
- [x] JacBuilder adapter simplified (~80 lines, zero internal imports)
- [ ] Automated API tests (deferred)

---

## Phase 7: Orchestrator-Worker Architecture

**Status**: Complete

- [x] **MainAgent node** — single orchestrator replacing 7 handler nodes (Router, BuildHandler, ClientBuilder, ServerBuilder, IntegrationBuilder, PlanHandler, ExploreHandler)
- [x] **WorkerRunner obj** — in-process SubAgent with full read+write tools (18 tools)
- [x] **ExplorerRunner obj** — in-process SubAgent with read-only tools (10 tools)
- [x] **spawn_agent tool** — delegates tasks to WorkerRunner/ExplorerRunner in-process
- [x] **think tool** — explicit chain-of-thought reasoning
- [x] **Git tools** — `git_status`, `git_diff`, `git_log`, `git_commit`
- [x] **Tool renames** — write_code, edit_code, find_files, run_command, update_todos, analyze_project, find_symbol
- [x] **SubAgent event labeling** — `[sub:worker:N]` / `[sub:explorer:N]` prefix
- [x] **Shared Jac rules** — MainAgent and SubAgents share build_rules + client_rules + server_rules
- [x] **Budget system** — shared iteration budget across MainAgent + all SubAgents
- [x] **Walker simplification** — 2-step traversal (Root → Session → MainAgent)
- [x] **Removed deprecated code** — no subprocess, no temp files, no string-based script generation
- [x] **Flattened project structure** — removed redundant `jac-coder/` directory
- [x] **Removed dead code** — `_build_result`, `_load_orchestrator_info`, dead config fields
- [x] **Updated ARCHITECTURE.md**
- [x] Tests: 58 passed, 1 skipped
- [x] Live test: 3 explorer SubAgents, 118 tool calls, correct labeling

---

## Future Work

### Reliability

- [ ] Doom loop detection (repeated identical tool calls)
- [ ] LLM retry with exponential backoff
- [ ] Tool result validation

### UX

- [ ] Text streaming (requires byllm `-> str` return type support)
- [ ] Cost/token tracking
- [ ] Undo/rollback for file changes

### Persistence

- [ ] CLI session persistence (serialize to JSON on exit, reload on start)

### byllm Enhancement

- [ ] Dynamic tool attachment on `by llm()` calls (eliminates need for pre-defined runner objects)

---

## Summary

| Phase | Status | Key Deliverable |
|-------|--------|----------------|
| 1. Self-Correcting Tools | Complete | Auto `jac_check` on writes |
| 2. Real-Time Output | Complete | Tool events with timing |
| 3. Context Management | Complete | Smart compaction under 20K tokens |
| 4. Project Memory | Complete | AST-derived codebase knowledge |
| 5. Jac Intelligence | Complete | Compiler-level AST analysis tools |
| 6. Public API | Complete | Clean interface for external apps |
| 7. Orchestrator-Worker | Complete | MainAgent + in-process SubAgents |

**Tests**: 58 passed, 1 skipped (requires API key)
