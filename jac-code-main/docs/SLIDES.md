# JacCoder — Slide Deck

> Each section = one slide. Minimal text. Diagrams do the talking.

---

## Slide 1: Title

**JacCoder: AI Coding Agent on the Jaseci Stack**

Built with Jac · byllm · OSP

---

## Slide 2: The Problem

**Generic agents don't understand Jac**

| Generic Agent | JacCoder |
|---|---|
| Reads files as text | Understands AST |
| Guesses imports | Knows exact paths |
| Trial and error | Correct first try |

---

## Slide 3: Architecture

**[DIAGRAM: graph.png]**

- 3 persistent nodes: Session, MainAgent, ProjectMemory
- Walker: `Root → Session → MainAgent`
- SubAgents spawned on demand (worker / explorer)

---

## Slide 4: How It Works

**Simple task** (fix a bug, read a file) → MainAgent uses its own tools directly

**Complex task** (build a feature) → MainAgent spawns SubAgent walkers on itself:

```
MainAgent thinks: "I need backend endpoints + frontend component"
  → spawns WorkerRunner → writes main.jac (backend)
  → spawns WorkerRunner → writes App.cl.jac (frontend)
  → reads both results → responds to user
```

Each SubAgent runs its own ReAct loop with focused tools and Jac rules

---

## Slide 5: 22 Tools

| Category | Tools |
|----------|-------|
| Read & Search | read_file, grep_search, find_files, list_files |
| Write & Validate | write_code, edit_code, validate_project |
| Jac Intelligence | analyze_project, find_symbol, jac_check, jac_docs |
| Git | git_status, git_diff, git_commit, git_log |
| Reasoning | think, spawn_agent |
| Interact | ask_question, update_todos, run_command |

LLM selects tools via byllm ReAct loop: think → pick tool → execute → observe → repeat

---

## Slide 6: Self-Correction

**Per-file**: quick syntax check (instant)
**End of task**: `validate_project()` — batch type check + auto-fix

Auto-fixes: `root→root()`, `def: pub→def:pub`, slash→dot imports

Errors direct agent to call `jac_docs()` before fixing

---

## Slide 7: Jac Intelligence

**Compiler-level understanding via jaclang AST**

```
JacProgram().compile(file) → extract:
  • Nodes + fields + types
  • Walkers + entry points
  • Edges + imports/exports
```

Stored in ProjectMemory → agent knows the codebase from turn 1

---

## Slide 8: Context Management

30 messages (~60K tokens) → compacted to <20K tokens

Priority order:

1. Project summary (AST)
2. Jac rules (build + client + server)
3. Last 8 turns verbatim
4. Important old turns
5. Active files + errors

---

## Slide 9: Integration

**Public API — 4 functions, zero internals**

```
initialize("web")
create_session(directory)
chat(session_id, message)
close_session(session_id)
```

JacBuilder, IDE extensions, custom apps — all use the same API

---

## Slide 10: Summary

| Layer | How |
|-------|-----|
| Graph | OSP: Root → Session → MainAgent |
| Reasoning | byllm `by llm(tools=[...])` ReAct loop |
| Delegation | In-process SubAgents (worker / explorer) |
| Intelligence | jaclang AST analysis |
| Validation | Syntax per-file + batch type check |
| Context | Deterministic compaction <20K tokens |
| API | 4 functions, fully decoupled |
