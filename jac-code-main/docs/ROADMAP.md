# JacCoder Roadmap: From Coding Chatbot to Autonomous Coding Agent

> **Vision**: Make jac-coder the unbeatable AI coding agent for the Jaseci stack — an agent that understands OSP, graph persistence, walker semantics, and `.cl.jac` frontends better than any general-purpose tool ever could.

> **Philosophy**: Niche-first. Own Jac/Jaseci development completely. Then generalize.

---

## Current State Assessment

### What's Solid (Phases 1-6 Complete)
- 19 tools (filesystem, search, shell, web, jac-specific, AST analysis)
- Self-correcting code writes (jac_check errors auto-fed back into ReAct loop)
- Real-time tool output with timing and turn summaries
- Smart context management (tiered compaction, active files, pending errors)
- Project memory (AST-based scan, cross-turn knowledge, project summary injection)
- Compiler-level Jac intelligence (jac_project_analysis, jac_find_symbol via AST API)
- Public API for external integration (JacBuilder, future IDE extensions)
- Permission engine (allow/deny/ask with pattern matching)
- Output safety (truncation, sandboxing, command blocking)
- Graph structure (Router → BuildHandler → Client/Server/Integration + Plan + Explore)
- Config system (global → project → env var cascade)
- CLI + JacBuilder web IDE integration via API
- Clean code separation (.jac interfaces + .impl.jac implementations)

### What's Missing (Post Phase 6)
- **Architecture bottleneck** — Router + BuildHandler burn 2 LLM calls classifying intent before any real work starts. Every other coding agent (OpenCode, Hermes, OpenClaw) uses one agent with all tools — the LLM naturally picks the right tools without classification
- **Tool fragmentation** — ExploreHandler has 7 tools, PlanHandler 12, BuildHandler sub-agents 13-16 each. Misrouting means the agent literally doesn't have the tools it needs
- **Rigid build pipeline** — `build_phase` state machine (init → client → server → integration) assumes linear app building. Breaks for bug fixes, refactors, test writing, single-file edits
- **Git tools** — developers need first-class git operations, not `bash_exec("git ...")`
- **No doom loop detection** — agent can spin endlessly on unfixable errors
- **No retry/fallback** — single API failure kills the entire turn
- **Stale ProjectMemory** — initialized once per session, becomes outdated as agent modifies files
- **No streaming** — user sees nothing until entire response complete (byllm constraint)
- **Session lost on exit** — `jac run` starts fresh each time, no persistence across CLI sessions

---

## Architecture Principle: One Agent, All Tools, byllm's ReAct Loop

Two principles guide JacCoder's architecture:

### 1. byllm Owns the Execution Loop

byllm's `by llm(tools=[...])` with native tool calling IS the correct execution engine. Our value-add is the layers AROUND and INSIDE it:

```
Phase 1:   Smart tools INSIDE the loop (self-correcting writes)
Phase 2:   Real-time events emitted BY tools during the loop
Phase 3:   Context compaction BEFORE the loop call
Phase 4:   Project memory injected BEFORE the loop call
Phase 5:   Jac Intelligence tools available INSIDE the loop
Phase 6:   Public API wrapping the loop
Phase 7:   Orchestrator-Worker — MainAgent node spawns SubAgent walkers dynamically
Phase 8:   Resilience — retry, fallback, doom loop detection, session persistence
Phase 9:   Production polish (streaming, hooks, IDE)
```

We explored replacing byllm's ReAct with a walker-owned loop using structured output. This degraded code quality and added parse failures. byllm's native ReAct remains the execution engine.

### 2. Dynamic Orchestration Over Pre-Defined Routing

**Lesson from OpenCode, Hermes, and OpenClaw**: None of them classify intent before acting. They give one agent tools and let it decide what to do, spawning sub-agents when specialization is needed.

JacCoder takes this further with the **Orchestrator-Worker pattern**:

- **MainAgent (node)** understands the task, has read/search/analysis tools, and orchestrates
- **SubAgent (walkers)** are spawned dynamically with exact tools, prompts, and domain context
- **Nothing is pre-defined** — MainAgent composes sub-agents at runtime based on what the task actually needs
- **Simple tasks** are handled directly by MainAgent (no sub-agent overhead)
- **Complex tasks** get focused sub-agents with sharp, concentrated prompts

This is idiomatic OSP: nodes hold state and orchestrate, walkers do focused work and return. The Client/Server/Integration knowledge remains valuable — but as context the MainAgent provides to sub-agents, not as a rigid pipeline.

---

## Phase 1: Self-Correcting Tools ✅ Complete

**Goal**: Every code write automatically runs `jac_check`. Errors feed back into the LLM's next ReAct iteration without any loop changes.

**The Trick**: Wrap tools so the tool RESULT contains jac_check feedback. byllm's ReAct loop naturally sees the error and fixes it. Zero changes to byllm.

```
LLM calls write_file_checked("app.jac", code)
  → writes file → runs jac_check
  → returns "File written. jac_check found 2 errors:
     line 15: unknown type 'String' (did you mean 'str'?)
     ⚠ ACTION REQUIRED: Fix these errors before moving on."
  → LLM sees errors → calls edit_file to fix → jac_check again → clean
```

### Success Criteria
- Agent writes code → gets jac_check error → fixes it → clean. All within ONE user prompt.
- No changes to byllm. Only changes: tool wrappers, handler tool lists, chat_history metadata.

---

## Phase 2: Enhanced Real-Time Output ✅ Complete

**Goal**: User sees polished, real-time progress — tool calls with timing, results with status, step counts.

```
[1] Read: components/App.cl.jac → 45 lines (0.1s)
[2] Write: components/Login.cl.jac → 28 lines (0.2s)
[3] Check: components/Login.cl.jac → ok (1.3s)

── 3 tools, 1 file modified, 1.6s ──
```

### Success Criteria
- Tool calls show result previews and timing in real-time
- Turn summary line after each agent response
- Event infrastructure works through both CLI and JacBuilder adapter

---

## Phase 3: Context Window Management ✅ Complete

**Goal**: Agent handles 30+ step tasks without hitting token limits or forgetting earlier decisions.

Smart context compaction BEFORE passing to `respond()`:
- Tiered priority: active_files + pending_errors → project_summary → important turns → recent verbatim
- Deterministic compaction (no LLM call needed)
- 20K token budget with 80% threshold

### Success Criteria
- Agent completes 25-step tasks without losing context
- Active files and errors ALWAYS in context

---

## Phase 4: Project Memory ✅ Complete

**Goal**: Agent remembers codebase facts. Session 2 starts smart, not blank.

```
Root
  ├── Sessions (existing)
  ├── Router (existing)
  └── ProjectMemory (persists)
        ├── architecture: "Full-stack Jac app..."
        ├── file_map: {"main.jac": "entry point", ...}
        ├── conventions: ["snake_case", ...]
        └── known_issues, past_decisions
```

### Success Criteria
- Session 2 skips the "let me explore your codebase" phase
- Memory stays compact (<500 tokens when summarized)

---

## Phase 5: Jac Intelligence ✅ Complete

**Goal**: Give the agent compiler-level understanding of Jac code. Instead of reading files as raw text, the agent understands the structural relationships between nodes, walkers, edges, and imports across the entire project.

**Why This Matters**: This is jac-coder's unfair advantage. No other coding agent has compiler-level understanding of any language. Claude Code reads files as text. Cursor reads files as text. jac-coder will understand the AST.

### The Difference

```
BEFORE (current):
  Agent: "I need to create a walker that visits User nodes"
  → reads 5 files to find User definition
  → guesses the import path
  → gets it wrong, jac_check fails, fixes, tries again
  → 8 tool calls, 30 seconds

AFTER (Phase 5):
  Agent: calls jac_project_analysis() (or reads from ProjectMemory)
  → already knows: User is in models.jac, "import from models {User}"
  → knows: User has fields name:str, email:str
  → writes correct code on first try
  → 3 tool calls, 10 seconds
```

### How It Works: jaclang's Compiler API

jaclang exposes a full AST API. The SAME parser handles all file types:

```python
from jaclang.jac0core.program import JacProgram

prog = JacProgram()
module = prog.compile("myfile.jac", type_check=True, no_cgen=True)

# Works for ALL file types:
# .jac    → default context (server + client)
# .cl.jac → code_context = CLIENT (unfolds cl{} blocks, removes sv{})
# .sv.jac → code_context = SERVER

# Extract everything:
for archetype in module.get_all_sub_nodes(Archetype):
    archetype.name              → "User"
    archetype.arch_type.name    → KW_NODE / KW_WALKER / KW_EDGE
    archetype.get_has_vars()    → [name:str, email:str]
    archetype.get_methods()     → [create(), update()]
    ability.is_genai_ability    → True if "by llm()"

for imp in module.get_all_sub_nodes(Import):
    imp.from_loc                → "models"
    imp.items                   → [User, Post]
```

### What to Build

| # | File | Action | Description |
|---|------|--------|-------------|
| 5.1 | `jac_coder/tool/jac_analyzer.jac` | CREATE | Interface for `jac_project_analysis` and `jac_find_symbol` tools |
| 5.2 | `jac_coder/tool/impl/jac_analyzer.impl.jac` | CREATE | Implementation using `JacProgram` AST API — parses all .jac/.cl.jac files, extracts nodes/walkers/edges/imports/fields/abilities |
| 5.3 | `jac_coder/tool/__init__.jac` | MODIFY | Export new analysis tools |
| 5.4 | `jac_coder/nodes.jac` | MODIFY | Add `jac_project_analysis` and `jac_find_symbol` to ALL handler tool lists |
| 5.5 | `jac_coder/impl/memory.impl.jac` | MODIFY | Enhance `_init_memory` to use AST analysis instead of raw file reading for project scan |
| 5.6 | `jac_coder/nodes.jac` | MODIFY | Add `graph_topology: str` field to ProjectMemory — stores node→edge→node relationships |
| 5.7 | `tests/test_jac_analyzer.py` | CREATE | Test AST extraction on sample .jac and .cl.jac files |
| 5.8 | Regression | RUN | All existing tests still pass |

### Tool 1: `jac_project_analysis(directory)`

Scans ALL `.jac` and `.cl.jac` files in the project, returns structured analysis:

```
Nodes:
  - User (models.jac:5) — fields: name:str, email:str | abilities: validate()
  - Post (models.jac:20) — fields: title:str, body:str | abilities: summarize() [by llm]

Walkers:
  - create_user (walkers.jac:3) — visits: Root → User
  - get_posts (walkers.jac:18) — visits: User → Post

Edges:
  - follows (models.jac:35) — User → User
  - authored (models.jac:40) — User → Post

Client Components (.cl.jac):
  - Calculator (components/calculator.cl.jac:47) — state: display:str, prevValue:float
  - LoginForm (components/login.cl.jac:12) — state: email:str, password:str

Import Map:
  models.jac: exports [User, Post, follows, authored]
  walkers.jac: imports [User, Post] from models
  main.jac: imports [create_user] from walkers, [User] from models
```

This gets stored in ProjectMemory AND returned as a tool result.

### Tool 2: `jac_find_symbol(name)`

Quick lookup for a specific symbol:

```
jac_find_symbol("User")
→ Defined: models.jac:5 (node)
  Fields: name:str, email:str
  Abilities: validate()
  Used by: walkers.jac:3 (import), walkers.jac:22 (with User entry), main.jac:8 (import)
  Correct import: "import from models {User}"
```

### Enhanced ProjectMemory

Phase 4's project scan used raw file reading + LLM-based extraction. Phase 5 upgrades it to use AST analysis:

```
BEFORE (Phase 4 — LLM guesses structure from raw text):
  file_map: {"models.jac": "data models", "walkers.jac": "API endpoints"}

AFTER (Phase 5 — compiler-accurate structure):
  file_map: {"models.jac": "nodes: User, Post; edges: follows, authored", ...}
  graph_topology: "User --[follows]--> User, User --[authored]--> Post"
  import_graph: {"walkers.jac": ["models.User", "models.Post"]}
```

### Testing Strategy

1. **Unit**: Parse a sample .jac file → verify correct node/walker/edge extraction
2. **Unit**: Parse a sample .cl.jac file → verify component/state extraction
3. **Unit**: `jac_find_symbol("User")` → verify definition location, usages, import suggestion
4. **Unit**: `jac_project_analysis(dir)` on a real project → verify complete output
5. **Integration**: Agent uses analysis to write code with correct imports on first try
6. **Regression**: All Phase 1-4 tests still pass

### Success Criteria
- Agent writes correct imports without trial-and-error
- Agent knows graph topology (which nodes connect via which edges)
- Agent understands .cl.jac components (state, props, hooks)
- ProjectMemory includes compiler-accurate structural data
- Zero extra latency for agents that don't call the tools (opt-in)

---

## Phase 6: Public API ✅ Complete

**Goal**: Expose a clean, stable public API so external applications (JacBuilder, future IDE extensions, etc.) can integrate with jac-coder without importing internal modules. Internal changes should never break external integrations.

### The Problem

The current JacBuilder adapter imports **13 internal modules** and manually orchestrates routing, handler resolution, graph traversal, memory init, session management — 470 lines of tightly-coupled code. Any internal change to jac-coder breaks the adapter.

```
BEFORE (current — tight coupling):
  import from jac_coder.walkers {new_session, ensure_router, routing_instruction}
  import from jac_coder.nodes {Session, Router, BuildHandler, ClientBuilder, ...}
  import from jac_coder.permission {permission_engine}
  import from jac_coder.events {register_event_callback, clear_event_callbacks}
  import from jac_coder.config {get_config}
  import from jac_coder.util.sandbox {set_sandbox_root}
  import from jac_coder.memory {find_or_create_memory, _init_memory}
  → 470 lines of manual orchestration

AFTER (public API — zero internal imports):
  import from jac_coder.api {init, create_session, chat, list_sessions, close_session}
  → ~30 lines
```

### What to Build

```jac
# jac_coder/api.jac — the ONLY module external apps import

def init(mode: str = "web") -> None;
def create_session(directory: str, title: str = "", agent: str = "build") -> dict;
def chat(session_id: str, message: str, directory: str = "", on_event: Any = None) -> dict;
def list_sessions() -> list;
def get_session(session_id: str) -> dict;
def close_session(session_id: str) -> dict;
```

`chat()` handles everything internally:
1. Initializes memory (AST scan if first turn)
2. Sets sandbox root
3. Registers event callback (if `on_event` provided)
4. Builds context (compaction, active_files, pending_errors, project_summary)
5. Routes the message (Router.classify)
6. Orchestrates build phase (BuildHandler.orchestrate)
7. Calls the right handler (Client/Server/Integration/Plan/Explore)
8. Persists response + updates memory
9. Returns plain dict result

### Success Criteria
- JacBuilder adapter reduced from ~470 lines to ~30 lines
- Zero internal imports in external apps — only `jac_coder.api`
- All existing functionality preserved (sessions, routing, building, memory, events)
- Internal refactoring never breaks the API contract

---

## Phase 7: Orchestrator-Worker Architecture ← NEXT

**Goal**: Replace the rigid Router → Handler → Sub-handler pipeline with a dynamic **Orchestrator-Worker** pattern. MainAgent (node) handles simple tasks directly and spawns SubAgent walkers for complex work. MainAgent **thinks** (explicit reasoning step), then **composes a detailed instruction string** for each SubAgent. SubAgents are scoped by **capability** (worker: read+write, explorer: read-only), not by domain. The instruction string is what provides domain specialization.

### Why This Change

**Evidence from other coding agents:**

| Agent | Architecture | Routing Strategy |
|-------|-------------|-----------------|
| **OpenCode** | 2 modes + `task()` tool for subagents | No intent classification. Subagents spawned on demand. |
| **Hermes** | ONE agent + `delegate_task()` with shared budget | Same agent, delegates when needed |
| **OpenClaw** | Task-agnostic pipeline + subagent spawning | All tasks through same path, specialization via delegation |
| **JacCoder (current)** | Router → 3 handlers → 3 sub-handlers | 2 LLM classification calls before work starts |

Every production coding agent converges on: **one orchestrator that delegates dynamically, not a pre-defined routing pipeline.**

### Current Flow (3 LLM calls per turn, rigid)

```
User message
  → Router.classify() .................. [LLM call #1 — classify BUILD/PLAN/EXPLORE]
    → BuildHandler.orchestrate() ....... [LLM call #2 — classify CLIENT/SERVER/INTEGRATION]
      → ClientBuilder.respond() ........ [LLM call #3 — actual work starts here]
```

### New Flow (dynamic, OSP-native)

```
User message
  → interact walker: Root → Session → MainAgent
  → MainAgent.respond() [1 LLM call — orchestrator with tools]
      → Calls think() → reasons about the task, plans approach
      → Simple task? Handle directly (read, edit, check, git)
      → Complex task?
          → Reads relevant rules/docs/code
          → Calls think() → composes detailed instruction string
          → Calls spawn_agent(task=instruction, mode="worker")
              → SubAgent walker spawned with capability-scoped tools
              → SubAgent.execute() [focused LLM call with sharp instruction]
              → Result returned (files_modified, errors, content)
              → Session state updated automatically
          → MainAgent reviews, spawns more if needed, responds to user
```

### The OSP Design: Node + Walkers

This maps naturally to Jac's Object-Spatial Programming model:

- **MainAgent = Node** (persistent, orchestrates, has all tools including `think` for explicit reasoning)
- **SubAgent = Walker** (ephemeral, spawned on MainAgent, capability-scoped tools, specialized by instruction string)

```jac
node MainAgent {
    can respond(
        message: str,
        chat_history: list
    ) -> AgentResponse by llm(
        tools=[
            # Think (explicit reasoning before acting or delegating)
            think,
            # Understand
            read_file, grep_search, glob_files, list_files,
            jac_project_analysis, jac_find_symbol, jac_docs,
            # Act (simple tasks)
            edit_file_checked, write_file_checked, bash_exec,
            # Git
            git_status, git_diff, git_log, git_commit,
            # Delegate (complex tasks)
            spawn_agent,
            # Interact
            ask_question, todo_write
        ]
    );
}

walker SubAgent {
    has task: str;              # detailed instruction string from MainAgent
    has max_iterations: int = 30;
    # tools set by spawn_agent based on mode (worker/explorer)
    # files_modified and tools_used tracked programmatically, not by LLM

    can execute() -> SubAgentResult by llm();
}

obj SubAgentResult {
    has content: str;              # LLM's final response
    has files_modified: list[str]; # tracked programmatically by write/edit tools (not LLM-reported)
    has errors: list[str];         # tracked programmatically by jac_check results
    has tools_used: list[str];     # tracked programmatically by tool execution hooks
}
```

### The `think` Tool

Explicit reasoning step — MainAgent uses this to plan its approach before acting or to compose a detailed instruction string before delegating. The think output is visible in the agent's reasoning trace but not sent to the user.

```jac
can think(
    thought: str    # MainAgent's internal reasoning
) -> str;
# Returns the thought back — used for chain-of-thought reasoning
# within the ReAct loop. The LLM sees its own reasoning in the
# tool result, which improves subsequent decisions.
```

**Why a tool, not native model thinking**: byllm's ReAct loop processes tool calls sequentially. By making `think` a tool, MainAgent can reason at any point in the loop — before deciding to delegate, while composing an instruction, or after reviewing a SubAgent result. It works with any model, not just models that support extended thinking natively.

**Pattern from Claude Code**: Claude Code uses a similar pattern where the agent reasons explicitly before complex decisions. The think step is what produces high-quality delegation instructions.

### The `spawn_agent` Tool

MainAgent thinks, reads relevant context, composes a detailed instruction string, then calls `spawn_agent` with a **capability mode** (worker or explorer). The mode controls tool access. The instruction string provides domain specialization.

```jac
can spawn_agent(
    task: str,              # detailed instruction string MainAgent composed
    mode: str = "worker"    # "worker" (read+write) or "explorer" (read-only)
) -> str;
```

**Capability modes** (following OpenCode, Claude Code pattern):

| Mode | Tools | Purpose |
|------|-------|---------|
| **worker** | write_file_checked, edit_file_checked, read_file, bash_exec, jac_check, jac_run, jac_docs, jac_find_symbol, jac_project_analysis, grep_search, glob_files, scaffold_project, web_fetch, web_search | Can modify files — for building, fixing, refactoring |
| **explorer** | read_file, grep_search, glob_files, list_files, jac_project_analysis, jac_find_symbol, jac_docs, web_search, web_fetch | Read-only — for investigating, analyzing, researching |

This is **capability scoping, not domain routing**. Whether the SubAgent works on client code, server code, or integration is determined by the instruction string — not by the tool set.

Implementation:

```jac
can spawn_agent(task: str, mode: str = "worker") -> str {
    # Shared iteration budget — prevents runaway across multiple SubAgents
    let remaining_budget = get_shared_budget().remaining;
    if remaining_budget <= 0 {
        return "Iteration budget exhausted. Cannot spawn more SubAgents.";
    }
    let iterations = min(30, remaining_budget);

    # Capability-scoped tool sets (2 modes, not domain categories)
    let tools = match mode {
        "worker" => worker_tools,
        "explorer" => explorer_tools,
        _ => worker_tools
    };

    # Enrich task with session context
    let enriched_task = f"{task}\n\nProject context:\n{get_project_summary()}"
        + f"\n\nRecent work:\n{summarize_recent_subagent_results()}";

    # Track files/tools programmatically (not LLM-reported)
    let tracker = FileTracker();

    # Create walker, spawn on MainAgent node
    let agent = SubAgent(task=enriched_task, max_iterations=iterations);
    let result: SubAgentResult = spawn agent(tools=tools, tracker=tracker) on here;

    # Deduct iterations used from shared budget
    get_shared_budget().consume(result.iterations_used);

    # Update Session state automatically (using programmatic tracking)
    update_active_files(tracker.files_modified);
    track_errors(tracker.errors);

    return format_result(result);
}
```

**Key design**: Two concerns are cleanly separated:
1. **Capability scope** (worker/explorer) — controlled by code, determines WHAT the SubAgent CAN do
2. **Domain specialization** (instruction string) — composed by MainAgent's thinking, determines WHAT the SubAgent SHOULD do

MainAgent reads relevant files (rules, existing code, docs), uses `think` to reason about the approach, and bakes everything into the instruction string — like a senior developer writing a detailed brief for a teammate.

### How It Works In Practice

**Complex task — "Build me a todo app with auth":**

```
MainAgent.respond() [LLM call #1 — thinks, reads context, delegates]
  1. Calls think("User wants a todo app with auth. I need to:
       1) Understand the current project structure
       2) Build a login component (client)
       3) Build User node + auth walker (server)
       4) Wire them together (integration)
       Let me check the project and load the relevant patterns.")

  2. Calls jac_project_analysis() → understands current project structure
  3. Calls read_file("data/client_rules.md") → loads Jac client patterns

  4. Calls think("Now I'll compose a detailed brief for the client SubAgent.
       I need to include the cl.jac patterns from the rules file and
       specify the exact component structure needed.")

  5. Calls spawn_agent(
       task="Create Login.cl.jac with email and password fields.
             Include form validation and a submit handler.

             Follow these Jac client component patterns:
             - Use 'has' for state variables inside the node
             - Wrap client-side code in cl{} blocks
             - Event handlers use 'can' keyword with event parameter
             - Import components with 'import from components {...}'
             [... relevant patterns from client_rules.md ...]

             The server will have a User node and auth walker (not built yet).",
       mode="worker"
     )
     → SubAgent spawns with worker tools (can write/edit/check)
     → SubAgent.execute() [LLM call #2 — focused by instruction string]
     → Writes Login.cl.jac, self-corrects via jac_check
     → Returns SubAgentResult(files_modified=["Login.cl.jac"], ...)
     → Session.active_files updated automatically

  6. Calls read_file("data/server_rules.md") → loads Jac server patterns
  7. Calls spawn_agent(
       task="Create a User node with email:str, password_hash:str fields
             and an auth walker that validates credentials.

             Follow these Jac server patterns:
             - Define nodes with 'node Name { has field: type; }'
             - Walkers use 'walker Name { can visit_ability with Node entry {...} }'
             [... relevant patterns from server_rules.md ...]

             The Login.cl.jac component (already built) will call this auth walker.",
       mode="worker"
     )
     → SubAgent gets enriched task with previous SubAgent results as context
     → SubAgent.execute() [LLM call #3 — focused server work]
     → Returns SubAgentResult(files_modified=["models.jac", "auth.jac"], ...)

  8. Calls spawn_agent(
       task="Wire Login.cl.jac submit handler to the auth walker.
             Login.cl.jac is in components/Login.cl.jac (just created).
             The auth walker is in auth.jac (just created).
             Update the import in Login.cl.jac and connect the submit handler
             to spawn the auth walker with the form data.",
       mode="worker"
     )
     → SubAgent knows what was built (via enriched task with recent work summary)
     → SubAgent.execute() [LLM call #4 — focused integration work]

  9. Reviews all results, responds to user with summary

Total: 4 LLM calls, each doing real work. Zero wasted classification calls.
       think() steps ensured MainAgent composed sharp, detailed instructions.
```

**Simple task — "Fix the type error in walkers.jac":**

```
MainAgent.respond() [1 LLM call — handles directly, no delegation]
  1. Calls jac_check("walkers.jac") → sees the error
  2. Calls read_file("walkers.jac") → understands the code
  3. Calls edit_file_checked("walkers.jac", old, new) → fixes the error
  4. Responds to user: "Fixed the type error on line 15..."

Total: 1 LLM call. No think() needed for simple tasks. No SubAgent needed.
```

**Deep investigation — "Analyze how the graph topology affects walker traversal performance":**

```
MainAgent.respond() [LLM call #1]
  1. Calls think("This is a complex analysis task. I should spawn an explorer
       to do deep research without modifying anything.")
  2. Calls spawn_agent(
       task="Analyze the graph topology of this project.
             1) Use jac_project_analysis to get all nodes, edges, and walkers
             2) Map which walkers visit which nodes via which edges
             3) Identify any deep traversal chains (3+ hops)
             4) Report how graph structure affects walker performance",
       mode="explorer"
     )
     → SubAgent spawns with read-only tools (cannot modify files)
     → SubAgent.execute() [LLM call #2 — reads, analyzes, reports]
  3. Reviews SubAgent's analysis, responds to user

Total: 2 LLM calls.
```

**Refactoring — "Rename User to Account everywhere":**

```
MainAgent.respond() [LLM call #1]
  1. Calls jac_find_symbol("User") → finds all files that reference it
  2. Calls think("User is in 3 files. I need a worker SubAgent to do the
       rename across all of them and validate with jac_check.")
  3. Calls spawn_agent(
       task="Rename the User node to Account across the entire project.
             Files to update: models.jac (definition), walkers.jac (imports + entry types),
             main.jac (imports).
             Update: node definition name, all 'import from models {User}' → {Account},
             all walker entry types 'with User entry' → 'with Account entry',
             all edge declarations referencing User.",
       mode="worker"
     )
     → SubAgent.execute() [LLM call #2]
  3. Reviews result, responds to user

Total: 2 LLM calls.
```

**Git workflow — "Commit my changes with a good message":**

```
MainAgent.respond() [1 LLM call — handles directly]
  1. Calls git_status() → sees modified files
  2. Calls git_diff() → reads the changes
  3. Calls git_commit(message="Add auth system with User node and login component",
                      files=["models.jac", "auth.jac", "Login.cl.jac"])
  4. Responds: "Committed 3 files..."

Total: 1 LLM call.
```

### Why Walkers as Sub-Agents Is Idiomatic OSP

In traditional agent frameworks, sub-agents are function calls or child processes. In Jac's OSP model:

1. **Walkers are mobile agents** — designed to be spawned, act, and return. This IS what sub-agents do.
2. **Walkers are ephemeral** — exist for one task, result consumed. No stale handler nodes.
3. **Walkers carry their own context** — each SubAgent has its own tools, prompt, and iteration budget.
4. **The node is the workspace** — MainAgent holds persistent state. Walkers do work on it and leave.

```
Graph at rest:
  Root ──▶ MainAgent
       ──▶ Session
       ──▶ ProjectMemory

During complex task (SubAgent walkers spawned on MainAgent):
  Root ──▶ MainAgent ◀── SubAgent_1 (worker walker, running)
       ──▶ Session
       ──▶ ProjectMemory

After task (walkers consumed, results in session):
  Root ──▶ MainAgent
       ──▶ Session (updated: active_files, chat_history)
       ──▶ ProjectMemory
```

### How Limitations Are Solved

| Problem | Solution |
|---------|----------|
| **Capability scoping** | Two modes: worker (read+write) and explorer (read-only). Capability-based, not domain-based. |
| **Quality of delegation** | `think` tool lets MainAgent reason explicitly before composing instructions — produces sharp, detailed briefs |
| **SubAgent lacks session context** | `spawn_agent` auto-injects project summary + recent SubAgent results into the task |
| **State tracking gap** | `spawn_agent` updates Session.active_files and Session.pending_errors after each SubAgent return |
| **SubAgent coordination** | Sequential spawning — each SubAgent's enriched task includes previous SubAgent results |
| **Overhead for simple tasks** | MainAgent has all tools — handles simple tasks directly, no delegation |
| **Domain knowledge injection** | MainAgent reads rules files (client_rules.md, etc.) and includes relevant patterns in the instruction string |
| **Runaway SubAgents** | Shared iteration budget across MainAgent + all SubAgents (pattern from Hermes). Global cap prevents 5 × 30 = 150 unchecked iterations. |
| **Inaccurate file tracking** | `files_modified`, `errors`, `tools_used` tracked programmatically by tool execution hooks — not LLM-reported. write/edit tools register modifications automatically. |
| **Doom loops** | Tracked in both MainAgent and SubAgent ReAct loops (3+ identical tool calls → warning) |

### Git Tools (First-Class)

| Tool | Description |
|------|-------------|
| `git_status()` | Working tree status — staged, unstaged, untracked |
| `git_diff(ref)` | Diff against HEAD, branch, or specific commit |
| `git_commit(message, files)` | Stage files and commit with message |
| `git_log(count)` | Recent commit history |

### Doom Loop Detection

Track tool calls within the ReAct loop. If the same tool is called with identical arguments 3+ times consecutively:

```
jac_check("app.jac") → errors → edit_file("app.jac", ...) → jac_check("app.jac") → same errors × 3
→ DOOM LOOP DETECTED: inject warning into context, try alternative approach, or ask user
```

Applies to both MainAgent and SubAgent walkers.

### API Enhancement for JacBuilder

Two integration modes:

```jac
# Mode 1: Let MainAgent orchestrate (recommended for CLI and JacBuilder)
chat(session_id, "Build a todo app with auth")
# MainAgent decides the full workflow — spawns SubAgents as needed

# Mode 2: Direct context injection (fine-grained JacBuilder control)
chat(session_id, "Build Login component", agent_context=client_rules)
# Injects domain rules directly into MainAgent's context
```

```jac
def chat(
    session_id: str,
    message: str,
    directory: str = "",
    on_event: Any = None,
    mode: str = "full",           # "full" or "read-only"
    agent_context: str = "",      # domain rules to inject into MainAgent's context
) -> dict;
```

### Walker Traversal (Simplified)

```
BEFORE (5-step walker traversal):
  init_session @ Root → enter_session @ Session → route @ Router
    → orchestrate @ BuildHandler → handle_client @ ClientBuilder

AFTER (3-step walker traversal):
  init_session @ Root → enter_session @ Session → respond @ MainAgent
    → (MainAgent may spawn SubAgent walkers via spawn_agent tool)
```

### What to Build

| # | File | Action | Description |
|---|------|--------|-------------|
| 7.1 | `jac_coder/nodes.jac` | REWRITE | Replace 7 handler nodes with `MainAgent` node. Define `SubAgent` walker + `SubAgentResult`. Keep Session, ProjectMemory. |
| 7.2 | `jac_coder/impl/nodes.impl.jac` | REWRITE | MainAgent orchestrator prompt (sem annotation). SubAgent focused execution prompt. |
| 7.3 | `jac_coder/walkers.jac` | SIMPLIFY | 3-step traversal: Root → Session → MainAgent. Remove route/orchestrate steps. |
| 7.4 | `jac_coder/impl/walkers.impl.jac` | SIMPLIFY | Remove routing logic and build_phase state machine. Direct MainAgent invocation. |
| 7.5 | `jac_coder/tool/think.jac` | CREATE | `think(thought)` interface — explicit reasoning tool |
| 7.6 | `jac_coder/tool/impl/think.impl.jac` | CREATE | `think` implementation — returns thought for chain-of-thought reasoning |
| 7.7 | `jac_coder/tool/spawn.jac` | CREATE | `spawn_agent(task, mode)` interface |
| 7.8 | `jac_coder/tool/impl/spawn.impl.jac` | CREATE | `spawn_agent` implementation — capability-scoped tool resolution, SubAgent walker creation, session context enrichment, shared iteration budget, programmatic file/error tracking |
| 7.9 | `jac_coder/tool/git.jac` | CREATE | `git_status`, `git_diff`, `git_commit`, `git_log` interfaces |
| 7.10 | `jac_coder/tool/impl/git.impl.jac` | CREATE | Git tool implementations |
| 7.11 | `jac_coder/tool/__init__.jac` | MODIFY | Export think, spawn, and git tools |
| 7.12 | `jac_coder/api.jac` | MODIFY | Add `mode`, `agent_context` parameters to `chat()` |
| 7.13 | `jac_coder/impl/api.impl.jac` | MODIFY | Wire new parameters, remove internal routing logic |
| 7.14 | `tests/` | UPDATE | Update all tests for new architecture |

### Graph Structure Change

```
BEFORE:
  Root ──▶ Router ──▶ BuildHandler ──▶ ClientBuilder
                                   ──▶ ServerBuilder
                                   ──▶ IntegrationBuilder
                   ──▶ PlanHandler
                   ──▶ ExploreHandler
       ──▶ Session
       ──▶ ProjectMemory

AFTER:
  Root ──▶ MainAgent (orchestrator node — spawns SubAgent walkers dynamically)
       ──▶ Session (chat_history, active_files, pending_errors)
       ──▶ ProjectMemory (AST-derived codebase knowledge)
```

### Success Criteria
- Zero pre-defined routing — MainAgent decides autonomously when to delegate
- Capability-scoped SubAgents (worker/explorer) — not domain-scoped (client/server/integration)
- `think` tool enables explicit reasoning — MainAgent plans approach and composes sharp instructions
- Simple tasks handled directly by MainAgent (1 LLM call, no overhead)
- Complex tasks get focused SubAgent walkers with detailed instructions MainAgent composed after thinking
- MainAgent reads relevant rules/docs and bakes them into each SubAgent's instruction
- SubAgents receive session context (project summary + previous SubAgent results) automatically
- Session state (active_files, pending_errors) updated automatically after each SubAgent
- Sequential SubAgents are coordinated — each gets previous results as context
- Explorer mode enforced in code — `spawn_agent` gives read-only tools when mode="explorer"
- JacBuilder can let MainAgent orchestrate OR inject `agent_context` for direct control
- Git operations work as first-class MainAgent tools
- Doom loop detection in both MainAgent and SubAgent ReAct loops
- All existing tests pass (adapted for new architecture)

---

## Phase 8: Resilience & Persistence ← NEXT AFTER 7

**Goal**: Make JacCoder reliable for real development sessions — handle failures gracefully, persist state across CLI restarts, keep memory fresh.

### 8.1 — Retry & Fallback

When an LLM API call fails:
1. Retry with exponential backoff (3 attempts: 2s, 5s, 10s)
2. If retry exhausts, try fallback model (configurable in `jaccoder.json`)
3. If fallback fails, return error to user with context preserved

Pattern from Hermes: `fallback_model` config + shared retry logic.

### 8.2 — Session Persistence (CLI)

Serialize session state to `.jac-memory/sessions/` on disk:
- On each turn completion: write session JSON (chat_history, active_files, pending_errors)
- On CLI start: offer to resume last session (`jac cli.jac` → "Resume session from 2 hours ago? [y/n]")
- ProjectMemory persisted alongside sessions

Pattern from Hermes (SQLite) and OpenCode (persistent store).

### 8.3 — Live ProjectMemory Updates

After every turn that modifies `.jac` or `.cl.jac` files:
- Re-scan modified files via AST (incremental, not full project)
- Update ProjectMemory fields (file_map, node_details, walker_details)
- Keep memory fresh without full re-scan cost

Pattern from OpenCode: `afterTurn()` hook in context engine.

### 8.4 — Tool Result Guards

Validate tool results before feeding back to LLM:
- Truncate results exceeding token budget (existing, but improve thresholds)
- Detect and flag potential prompt injection in tool outputs (web_fetch, bash_exec)
- Guard against infinite output from bash commands (timeout + kill)

Pattern from OpenClaw: `session-tool-result-guard.ts`.

### Success Criteria
- API failures don't crash the session — retry handles transient errors
- CLI sessions survive process restart
- ProjectMemory stays accurate as files change during the session
- No tool result can blow up the context window or inject prompts

---

## Phase 9: Production Polish

**Goal**: Final polish for production deployment.

- **Streaming**: Work with byllm team to support streaming responses (text deltas + tool call events)
- **Hook system**: Pre/post tool call hooks for custom validation (e.g., lint on write, approve on bash)
- **Trust escalation**: Configurable trust levels (0: ask everything, 1: allow reads, 2: allow writes, 3: allow all)
- **IDE extension**: VSCode integration with streaming events, inline diff preview
- **Parallel sub-agents**: Allow MainAgent to spawn multiple SubAgent walkers concurrently with shared iteration budget (pattern from Hermes)

---

## Phase Dependencies

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5 ──→ Phase 6
(self-fix)  (events)    (context)   (memory)    (jac-intel)  (public-api)
                                                                  │
                                                                  ▼
                                                            Phase 7 ──→ Phase 8 ──→ Phase 9
                                                         (orch-worker) (resilience) (polish)
```

Phase 7 is a **breaking architectural change** — it replaces pre-defined routing with dynamic orchestration via the Orchestrator-Worker pattern (MainAgent node + SubAgent walkers). Phases 8-9 build incrementally on the new architecture.

## What We Never Touch

These stay as-is across all phases (extended, not replaced):
- All tool implementations (filesystem, search, shell, web, jac-specific)
- Permission engine structure
- Config system structure
- Output truncation logic
- Path sandboxing
- byllm's ReAct loop — `by llm(tools=[...])` is the correct execution engine

---

## byllm Integration Strategy

| Phase | How We Use byllm |
|-------|------------------|
| Phase 1 | `by llm(tools=[...])` — smarter tools inside byllm's native ReAct loop |
| Phase 2 | Same — tools emit events during byllm's loop |
| Phase 3 | Same — we pre-compact `chat_history` before passing to `respond()` |
| Phase 4 | Same — project memory summary injected into chat_history |
| Phase 5 | Same — new Jac intelligence tools available inside byllm's loop |
| Phase 6 | Same — public API wraps the loop |
| Phase 7 | Same — MainAgent orchestrates, SubAgent walkers use `by llm(tools=[...])` for focused work |
| Phase 8 | Same — retry/fallback wraps the `by llm()` call |
| Phase 9 | Streaming support needed from byllm (upstream work) |

byllm's `by llm(tools=[...])` with native tool calling remains the execution engine throughout. We enhance what goes INTO and comes OUT OF the loop, never replace it.

---

## Critical Corrections (Post-Review)

### 1. Own-the-Loop Approach Degraded Quality
- Replacing byllm's ReAct with structured output (`NextAction` JSON) reduced code generation quality
- Native tool calling via `by llm(tools=[...])` is superior for code generation
- **Decision**: byllm owns the loop. Our value is the layers around it.

### 2. `jac_check` Does NOT Work on `.cl.jac` Files
- Phase 1 checked tools detect file extension, skip check for `.cl.jac`
- Track as known gap until `jac check` supports `.cl.jac`

### 3. `dict` Fields in `by llm()` Return Types Must Be Typed
- Always use `dict[str, str]` — never bare `dict` — on any obj field returned by `by llm()`

### 4. Router Classification Was Unnecessary (Phase 7 Correction)
- Analyzed OpenCode, Hermes, and OpenClaw — none classify intent before acting
- Router + BuildHandler added 2 LLM calls of latency per turn with misclassification risk
- Tool fragmentation across handlers meant misrouted requests couldn't be completed
- **Decision**: Orchestrator-Worker pattern. MainAgent (node) handles simple tasks directly and spawns SubAgent walkers for complex work. No pre-defined routing.

### 5. Two Kinds of Scoping: Capability vs Domain
- Domain-scoped agents ("client", "server", "integration") with fixed tool sets is just routing hidden behind a match statement — wrong approach
- Capability-scoped agents (worker/explorer) control WHAT the SubAgent CAN do — following OpenCode/Claude Code pattern
- Domain specialization comes from MainAgent's instruction string, composed after explicit `think` reasoning
- MainAgent reads relevant rules/docs/code and bakes domain context into each SubAgent's task description
- Two clean concerns: code controls capability (tools), LLM controls domain (instruction)
- JacBuilder can let MainAgent orchestrate autonomously, OR inject agent_context for direct control

---

## The Competitive Landscape

| Feature | Claude Code | Cursor | OpenCode | Hermes | JacCoder (Final) |
|---------|-------------|--------|----------|--------|-------------------|
| Native tool calling | ✓ | ✓ | ✓ | ✓ | ✓ (byllm ReAct) |
| Self-correction | ✓ | Partial | ✗ | ✗ | ✓ (Phase 1) |
| Real-time output | ✓ | ✓ | ✓ | ✓ | ✓ (Phase 2) |
| Context management | ✓ | ✓ | ✓ | ✓ | ✓ (Phase 3) |
| Project memory | ✓ | Basic | ✗ | ✓ (Honcho) | ✓ (Phase 4) |
| **Compiler-level code understanding** | ✗ | ✗ | ✗ | ✗ | **✓ (Phase 5)** |
| Dynamic sub-agent spawning | ✓ (task tool) | ✗ | ✓ (task tool) | ✓ (delegate) | ✓ (SubAgent walkers, Phase 7) |
| Permission system | ✓ | Basic | ✓ | Basic | ✓ (existing) |
| Git integration | ✓ | ✓ | ✓ | Via bash | ✓ (Phase 7) |
| Doom loop detection | ✓ | ✗ | ✓ | ✗ | ✓ (Phase 7) |
| Retry & fallback | ✓ | ✓ | ✓ | ✓ | ✓ (Phase 8) |
| Session persistence | ✓ | ✓ | ✓ | ✓ (SQLite) | ✓ (Phase 8) |
| OSP/Graph awareness | ✗ | ✗ | ✗ | ✗ | ✓ (Phase 5) |
| Jac-specific tooling | ✗ | ✗ | ✗ | ✗ | ✓ (existing + Phase 5) |

**Our unfair advantages**:
1. **Compiler-level AST understanding** of Jac code — no other agent has this for any language
2. **OSP-native Orchestrator-Worker pattern** — MainAgent (node) spawning SubAgent (walkers) is idiomatic Jac, not bolted-on subprocess delegation like every other agent
3. **Think + instruct delegation** — MainAgent reasons explicitly (`think` tool), then composes sharp instruction strings for capability-scoped SubAgents. Clean separation: code controls capability (worker/explorer tools), LLM controls domain (instruction content). Same capability-scoping pattern as OpenCode/Claude Code, but with the explicit reasoning step that produces higher-quality delegation.
