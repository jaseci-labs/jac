# Coding Workflow & Validation Discipline

> Follow this workflow EVERY TIME you write Jac code. No shortcuts.
> For fullstack apps: Steps 1-5 are ALL MANDATORY. You are NOT done until browser testing passes.

---

## Before Writing Code

1. **Read `jac.toml`** — check npm deps, project config, entry point.
2. **Call `jac_docs(query)`** — look up syntax for what you're building. Do NOT guess.
3. **If existing project**: call `analyze_project(directory)` to understand structure.
4. **Call `jac_docs` again** before EACH new file type (`.jac` vs `.cl.jac` have different syntax).

---

## Build Order (fullstack apps)

1. Backend services — `services/*.sv.jac` files (nodes + endpoints)
2. Entry point — `main.jac` imports from services/ + `cl { def:pub app() }`
3. Hooks — `hooks/useX.cl.jac` (sv import from services/)
4. Leaf components — `Header.cl.jac`, `ItemCard.cl.jac` (no data logic)
5. Container components — `ItemList.cl.jac` (calls hooks, renders leaf components)
6. Layout — `Layout.cl.jac` LAST (imports child components)

**Endpoints must be imported in TWO places:**
- `main.jac` - `import from services.products { get_products }` (registers with server)
- `hooks/*.cl.jac` — `sv import from ..services.products { get_products }` (calls from frontend)

**Build dependencies bottom-up.** Never import a file that doesn't exist yet.

---

## While Writing Code

- Use `write_code` / `edit_code` — they auto-run `jac_check` per file for syntax errors.
- Do NOT call `jac_check` or `jac check` manually.
- Do NOT use `run_command` for jac check.
- If `write_code`/`edit_code` report errors → call `jac_docs(query)` to look up correct syntax → fix → retry.
- Call `jac_docs` at least once every 3-4 tool calls. If unsure about ANY syntax, look it up immediately.
- Use ABSOLUTE file paths for all operations.

---

## After Writing ALL Files

### Step 1: Cross-file import check

Before validating, manually verify:
- Every `import from "..."` / `sv import from ...` references a file that exists
- sv import function names match actual `def:pub` names in `main.jac`
- Component imports use correct dot-levels (`.` same dir, `..` one up, `...` two up)
- No duplicate component names or endpoint names across files

### Step 2: Validate

Call `validate_project(directory)` ONCE after all files are written.
- It batch type-checks all `.jac` files
- It auto-fixes common patterns (root→root(), (?:)→[?:])
- It returns all type errors with hints

### Step 3: Fix and re-validate

- Read the report from `validate_project`
- Fix all remaining errors
- Call `validate_project()` again to confirm clean

### Step 4: Start the app

Start the application server using `run_command` with `background=True`:
- **Fullstack:** `run_command("jac start --dev main.jac", background=True)`
- **Backend only:** `run_command("jac start main.jac", background=True)`
- **Single script:** `jac run main.jac` — one-off execution (no server)

CRITICAL: `jac start` is a LONG-RUNNING server process — ALWAYS use `background=True`.
It will block forever if run in foreground. ALWAYS use `jac start`, NEVER `jac serve`.

After starting:
1. Check readiness with retry: `run_command("for i in 1 2 3 4 5; do curl -s http://localhost:<port>/ > /dev/null && echo UP && break || sleep 2; done")`
2. If DOWN, read `.jac-server.log` in the project dir for startup errors.
3. Then proceed with browser testing.

The port depends on project config — check `jac.toml` for the actual port.
The frontend is served at the ROOT `/` (e.g. `http://localhost:8001`). Do NOT append `/app` — just use the port directly.
NEVER read `/proc/PID/fd/` — it blocks forever. Use `.jac-server.log` or curl instead.

### Step 5: Browser testing (fullstack apps)

Use agent-browser to interactively test the running app at natural checkpoints:

1. `browser_open(url)` — open the app, get page snapshot with element refs (@e1, @e2, ...)
2. `browser_do('click @e3')` — click elements using refs from snapshot
3. `browser_do('fill @e5 "test data"')` — clear + fill input (ref then text, no flags)
4. `browser_do('get text @e1')` — read element text content
5. `browser_state()` — get updated snapshot to verify page changed correctly
6. `browser_close()` — close when done

IMPORTANT: If browser testing reveals problems (blank page, errors, broken UI) — FIX THEM.
Do NOT stop and report to the user. Investigate, fix the code, restart the server, and re-test.
Only stop after 3+ failed fix attempts on the same issue.

Common runtime issues and how to fix them:
  - Blank page / 0 children in root → check console errors with `browser_do('eval "..."')`, read source files, fix the entry point or imports
  - Buttons that don't respond → event handler or sv import mismatch, fix the handler
  - Missing content → data not loading, wrong endpoint name, fix the API call
  - Broken layout → CSS/component rendering issues, fix the styles
  - Form submission failures → request body schema mismatch (422), fix the request format

---

## When Stuck

1. Call `jac_docs(query)` — look up the correct syntax
2. Call `analyze_project` or `find_symbol` — check existing patterns
3. If same error 2-3 times → `ask_question` to ask the user
4. If editing same file 3+ times → step back, check assumptions

---

## HMR "module not found" Fix

1. File exists but compiled JS is stale
2. Do trivial edit on the TARGET file (not the importing file) — add a blank line
3. HMR recompiles, import resolves
