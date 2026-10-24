# Jac Studio

`jac studio` is a terminal workspace for working on a Jac codebase with coding agents. It is built into the `jac` binary and backed by the compiler: the project is loaded into a graph of packages, modules, archetypes, abilities and impls joined by the wiring in `archwire.jac`, and every view and every piece of context an agent receives comes from that graph.

There is no text editor. You point at compiler-level things (a module, an archetype, an ability, a wire), put them in the context tray, and tell an agent what to do with them. Agents make the edits, and the compiler checks each edit before it reaches disk.

```bash
jac studio                      # open the workspace on the project around the current directory
jac studio -d path/to/project   # open another project
jac studio -a claude            # choose the agent for this session
jac studio -s 20261023-0012     # resume a saved session (a unique prefix is enough)
```

## The workspace

| Pane | What it shows |
|------|---------------|
| Navigator | Packages, modules, archetypes, abilities and fields. A `●` marks symbols changed in this session. |
| Code | The selected file, read-only, with semantic highlighting, hover, diagnostics and inferred types inline. |
| Wiring | For the focused module: the modules that feed it, the module itself with the rules that govern it, and the modules it feeds, with the names each wire carries. A wire that breaks a rule is marked `⚠` with the reason. |
| Map | The architecture map: the wiring between packages, one level of the package hierarchy at a time. See [The architecture map](#the-architecture-map). |
| Agent | The transcript: messages, collapsible tool calls, the agent's plan and command output. |
| Context | The tray: everything you selected for the next request. |
| Prompt | Your instruction. Slash verbs act on the tray. |

The centre pane switches between code and wiring with `Ctrl+T` (or `w` in the navigator or code view), and to the architecture map with `m`.

## Keys

| Key | Action |
|-----|--------|
| `Tab` / `Shift+Tab` | Move focus between panes |
| `Ctrl+P` | Go to any module or symbol (`Tab` in the list adds it to the context) |
| `m` | Architecture map of the package around the selection |
| `Ctrl+X` | Command palette |
| `Ctrl+L` | Jump to the prompt |
| `F1` | All keys |
| `Ctrl+C` | Cancel the agent's turn; press twice to quit |
| `Ctrl+Q` | Quit |
| `Alt+←` / `Alt+→` | Move the edge of the focused pane |

In the navigator and code view, `Space` (or `a`) adds the item under the cursor to the context. In the code view, `Enter` or `d` goes to the definition, `r` lists references, `i` jumps between a declaration and its impl, `e` moves to the next diagnostic, and `t` shows or hides inferred types. In the wiring view, `←` and `→` move between the columns, `Enter` follows a wire, `Space` adds a wire or symbol to the context, and `A` adds a whole column.

In the transcript, `↑` and `↓` select an entry. `Enter` expands a tool call, or on the plan opens the code its steps are linked to. `o` opens the files a tool call touched.

## The architecture map

`m` in the navigator or code view opens the map on the package that holds the selected item, with the item selected. Each level groups the modules under one package by their next name segment, so a level shows sub-packages and modules side by side, and adds up the wires between them. Groups are ordered providers first: a group comes before the groups it feeds wherever the wiring allows it.

The map has seven views of the same level; `v` cycles them and `1` to `7` pick one.

| View | Shows |
|------|-------|
| Matrix | Every pair of groups. The row feeds the column, and each number is a count of wires. Numbers right of the diagonal follow the provider order; a number left of it is a backward wire, where a later group feeds an earlier one. Backward counts are yellow and counts that include a rule violation are red. `↻` marks groups that sit in a cycle. |
| Layers | Groups stacked by depth: layer 0 is fed by nothing at this level, and every forward wire goes to a higher layer. Selecting a group lights up what feeds it, what it feeds, and the rest of its cycle. |
| Issues | What keeps the level from being cleanly layered: wires that break a rule, backward wires (largest first), and cycles. |
| Roles | Every module under the level by role (see [Reading the architecture](#reading-the-architecture)), foundations first. |
| Iface | The interface of the selected group: the names that leave it, each with its outside users, what enters it, and hints. `←` and `→` move to the next group. |
| Rules | Each archwire rule against the wires it admits, the permissions only one wire uses, unused rules and permissions, and violations. |
| Clusters | The clusters the wiring forms under the level, compared with the declared packages: packages it splits, clusters that span packages, and modules that look misplaced. Enter on a cluster maps just its modules. |

Under each view, the selected group shows its module count, layer, cycle, governing rules, and the groups it feeds and is fed by with wire counts (`↺` marks a backward one). A selected matrix cell shows the dependency: its wire count, a sample wire, and whether the two groups depend on each other.

| Key | Action |
|-----|--------|
| Arrows | Move. In the matrix, `d` jumps to the diagonal and `t` swaps the row and column |
| `Enter` | Open a package (its level), show a module in the wiring view, or list the wires behind a number |
| `Backspace` / `u` | Up one level |
| `Space` | Add the selection to the context: a module, a package's map, or the wires behind a dependency |
| `A` | Add the whole level to the context |
| `w` | Show the selected module in the wiring view |
| `s` / `b` | Narrow the map to the slice (what the selection rests on) or the blast radius (what depends on it), as loaded at import time; press again for everything reachable through any wire |
| `x` | Clear the slice, blast radius or cluster filter |

A package's map in the context reaches the agent as the level in text: its groups by layer, the matrix, the backward wires and the cycles. A dependency reaches it as the list of wires with the names each carries. The map follows `archwire.jac`: change a wire and the level is recomputed.

## Reading the architecture

Because every dependency is a declared wire that names what it carries, the studio can answer higher-level questions about how a codebase is organized. Each answer is a map view, a command, and part of the `studio_insight` tool, so you and an agent see the same thing.

| Question | Where | What it tells you |
|----------|-------|-------------------|
| What is each module for? | Roles view, `jac studio roles [package]` | Sorts modules by how they are wired. *Foundations* feed many modules and depend on few: read these first. *Hubs* feed many and depend on many: central and risky to change. *Integrators* pull from many and feed few. *Entry points* are wired to by nothing (commands, tests, code loaded by name). *Many* means the top tenth of the project. |
| What does a package expose? | Iface view, `jac studio interface <package>` | The names that cross its boundary with their users: its real API. A name with a single outside user could live next to that user; a name used by many is a core abstraction; a package whose exports mostly go to one place may belong there. |
| Do the rules match the code? | Rules view, `jac studio rules` | How many wires cross packages and how many a rule admits, which rules and permissions nothing uses (they could be removed), which permissions a single wire uses (the easiest to tighten), and every violation. When every permission is used, the rules mirror the wiring rather than limit it. |
| What does this rest on? | `s`, `jac studio slice <module>` | Everything a module depends on, step by step: what importing it loads (wires at module level) and what it can reach once functions that import inside them run. |
| What breaks if this changes? | `b`, `jac studio blast <module or name>` | The modules that use a module or a single name directly (exact, from the wires that carry the name), those that load it at import time, and the upper bound reachable through any wire. |
| Do the packages match the code? | Clusters view, `jac studio clusters [package]` | Groups modules by how tightly they are wired (Louvain communities) and compares the groups with the packages: modularity, how many modules sit in a cluster their own package leads, packages the wiring splits, and modules most of whose consumers live in another package. |
| How should I learn this codebase? | Command palette, `jac studio tour [package]` | A tour in markdown: the foundations and hubs to read first, each layer's groups with what they feed and their most used names, where the layering breaks, and the rules. It is generated from the wiring, so it does not go stale. |
| What did this change do to the architecture? | Command palette, `jac studio diff [revision]` | Compares the wiring now with a git revision, by default the nearest `main`, against its merge base like a code review: wires added and removed, names a wire gained or lost, rules added or changed, and per package level any new backward dependency, a grown cycle, a new violation, or a wider interface. |

## Telling an agent what to do

Select what the request is about, then type it in the prompt. `@` in the prompt adds something to the context without leaving the keyboard. Each item in the tray is sent to the agent as a typed block: the declaration together with its impl body, its signature, what uses it and what it uses, the wires that carry it, and the rules that govern its module.

Slash verbs turn the tray into a request:

| Verb | Asks the agent to |
|------|-------------------|
| `/explain` | Explain the selected code and how it is wired |
| `/tests` | Write tests that follow the project's conventions |
| `/refactor` | Refactor without changing behaviour, keeping the wiring valid |
| `/review` | Report bugs and risky assumptions without editing |
| `/doc` | Add or improve docstrings and `sem` strings |
| `/fix` | Fix the problems in the selected code |
| `/move` | Move the selected code to another module and rewire `archwire.jac` |

Add your own verbs under `[studio.verbs]` in `jac.toml`.

## Compiler-checked edits

When an agent writes a file, the write is held while the compiler checks the new text in an overlay. The approval sheet shows:

- whether the edit compiles, and how long the check took;
- each symbol it adds, changes or removes;
- new errors and warnings, and existing diagnostics it fixes;
- architecture changes (wires or rules added, removed or changed);
- the diff.

| Key | Action |
|-----|--------|
| `a` | Accept the edit |
| `1`-`9` | Toggle one symbol change; changes that share a line toggle together |
| `A` | Approve an architecture change and accept the edit |
| `r` | Reject |
| `f` | Reject and send the compiler's findings back to the agent |

An edit cannot be accepted while the compiler is still checking it, and an edit that changes the architecture cannot be accepted with `a`; it always needs `A`. To accept part of an edit, toggle the changes to drop and press `a`: the studio first compiles just the kept changes and shows that verdict, and a second `a` writes them and tells the agent which changes were dropped. When an agent proposes several files at once, rejecting one rechecks the others that were checked against it.

A resumed or forked session gives the agent its earlier conversation: an agent that can reload its own session does, and otherwise the saved transcript goes with the first new request.

Reads, searches, the jac and studio MCP tools, and edits are allowed without asking, because every write is reviewed here. Other tool calls, such as shell commands, ask first. `[studio] auto_allow` adds tool kinds or title fragments to the allowed set.

## Agents

```bash
jac studio agents
```

The studio drives any agent that speaks the [Agent Client Protocol](https://agentclientprotocol.com): Claude Code and Codex through their ACP adapters, Gemini CLI, or any command you configure. Every agent is started with two MCP servers: `jac mcp` for the compiler tools, and the studio's own server, which gives the agent these tools:

| Tool | Returns or does |
|------|-----------------|
| `studio_selection` | The context tray, the file and symbol under the cursor, and the module in the wiring view |
| `studio_focus` | Shows a module, symbol or file location to the user, with an optional note |
| `studio_wiring` | A module's providers, consumers and governing rules |
| `studio_rules` | Every rule and the modules it covers |
| `studio_graph` | One level of the architecture map: groups by layer, wire counts between them, backward wires and cycles |
| `studio_insight` | Roles, an interface, rule use, a slice, a blast radius, clusters, a tour or the architecture diff (see [Reading the architecture](#reading-the-architecture)) |
| `studio_symbol` | A declaration with its impl, users, uses and the walkers that visit it |
| `studio_search` | Fuzzy search over modules and symbols |
| `studio_link_plan` | Links each step of the agent's plan to the code it touches |

The built-in agent, `jac`, runs on byLLM inside the studio. It needs byLLM's model client: add `[byllm]` to `jac.toml` and run `jac install`. Choose its model with `[studio] model`, or byLLM's `default_model`.

## Headless use

```bash
jac studio model                       # summary of the project model
jac studio model geo.shape --json      # one module, as JSON
jac studio model geo.shape.Circle      # a symbol: members, impls, users, uses, walkers
jac studio graph                       # the architecture map of the project, as text
jac studio graph core --json           # one package's level, as JSON
jac studio roles                       # foundations, hubs, integrators and entry points
jac studio interface core              # the names that cross a package's boundary
jac studio rules                       # the rules against the wires they admit
jac studio slice app.main              # what a module rests on
jac studio blast core.jobs.Runner      # what depends on a module or a name
jac studio clusters core               # natural clusters against the declared packages
jac studio tour > TOUR.md              # an onboarding tour, in markdown
jac studio diff main                   # how the architecture changed since a revision
jac studio ask geo.shape.Circle "add a perimeter method" -a claude --yes
jac studio sessions                    # saved sessions
jac studio sessions fork <id>          # copy a session to take it in another direction
```

`jac studio ask` hands a symbol or module and an instruction to an agent without the UI. With `--yes` it approves permission requests and writes, so use it only where that is safe.

## Sessions

The transcript, the context tray and every decision you made are saved on a root graph in the project's `.jac/studio` store when you quit. `jac studio -s <id>` reopens a session in the same state, and `jac studio sessions fork <id>` copies one so you can try a different direction.

## Configuration

```toml
[studio]
default_agent = "claude"           # agent used when -a is not given
model = "anthropic/claude-sonnet-5-5"   # model for the built-in agent
gate = "ask"                       # ask | auto | strict | off
auto_allow = ["execute"]           # more tool kinds or title fragments to allow

[studio.verbs]
perf = "Find the hot paths in the selected code and make them faster."

[studio.agents.mine]
command = "my-agent"
args = ["--acp"]
env = { MY_AGENT_MODE = "acp" }
```

| `gate` | Behaviour |
|--------|-----------|
| `ask` | Every edit waits for you, with the compiler's verdict (default) |
| `auto` | Clean edits are accepted and broken ones are sent back with the compiler's findings; architecture changes still wait for you |
| `strict` | Broken edits are sent back; clean ones wait for you |
| `off` | Edits wait for you without a compiler check |

Settings in `~/.jac/studio.toml` (or the file named by `JAC_STUDIO_CONFIG`) apply to every project; the project's `jac.toml` takes precedence.

## Performance

The workspace opens before the project is indexed: the navigator shows the module tree at once, and symbols fill in from a background index. On the jaclang compiler itself (about 5,800 modules), the first frame appears in under 7 seconds. Code intelligence is per file, so hover, definitions and diagnostics for the open file do not wait for the full index.
