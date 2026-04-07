# Jac Docs Researcher Memory

## Jac Testing Patterns
- Test syntax: `test "name" { ... }` with `assert` statements
- CLI: `jac test file.jac`, `jac test -d tests/`, `-t` (specific), `-f` (filter), `-x` (fail fast), `-v` (verbose), `-m` (maxfail)
- `jac.toml` supports `[test]` section with `directory`, `verbose`, `fail_fast`, `max_failures`
- Walker testing: `result = root spawn Walker(); assert len(result.reports) == N;`
- Graph setup in tests: `counter = root ++> Counter();` — each test gets fresh graph state
- `JacTestClient` at `jaclang.runtimelib.testing` — HTTP test client for walker endpoints (no socket needed)
  - `JacTestClient.from_file("app.jac", base_path=str(tmp_path))`
  - `.register_user()`, `.login()`, `.post()`, `.get()`, `.put()`, `.close()`
  - Response: `.status_code`, `.json()`, `.ok`, `.data`

## Jac IDE Project Structure
- Backend: `main.jac` -> `services/ideServer.jac` (walkers + nodes) -> `services/project_manager.jac`, `services/preview_manager.jac`, `services/community_manager.jac`, `services/ai_service.jac`
- Nodes: `Router`, `UserProfile`, `Project`, `ProjectVersion`
- Key walkers: `me`, `template_ops`, `project_ops`, `version_ops`, `ide_file_ops`, `preview_control`, `ai_chat`, `community_ops` (pub), `community_submit`, `env_ops`, `ide_preview_stream` (pub/ws)
- No existing tests in project as of 2026-02-23

## Jac Docs Location
- Official tutorials: `/home/ahzan/Documents/jaseci/jaseci/docs/docs/tutorials/`
- Testing doc: `/home/ahzan/Documents/jaseci/jaseci/docs/docs/tutorials/language/testing.md`
- Syntax cheatsheet: `/home/ahzan/Documents/jaseci/jaseci/docs/docs/quick-guide/syntax-cheatsheet.md`
- JacTestClient source: `/home/ahzan/Documents/jaseci/jaseci/jac/jaclang/runtimelib/testing.jac`

## Jac Multi-Target / Desktop Build System
- Source: `/home/ahzan/Documents/jaseci/jaseci/jac-client/` (jac-client plugin)
- Architecture doc: `/home/ahzan/Documents/jaseci/jaseci/jac-client/multi-target-architecture.md`
- Multi-target intro doc: `/home/ahzan/Documents/jaseci/jaseci/jac-client/jac_client/docs/multi-targets/intro.md`
- Desktop target doc: `/home/ahzan/Documents/jaseci/jaseci/jac-client/jac_client/docs/multi-targets/desktop-target.md`
- Web target doc: `/home/ahzan/Documents/jaseci/jaseci/jac-client/jac_client/docs/multi-targets/web-target.md`
- jac-client reference: `/home/ahzan/Documents/jaseci/jaseci/docs/docs/reference/plugins/jac-client.md`
- Release notes: `/home/ahzan/Documents/jaseci/jaseci/docs/docs/community/release_notes/jac-client.md`
- Desktop-target example project: `/home/ahzan/Documents/jaseci/Desktop-target/`
- Target source code: `/home/ahzan/Documents/jaseci/jaseci/jac-client/jac_client/plugin/src/targets/`
- Targets: web (default), desktop (Tauri v2), pwa
- CLI: `jac setup desktop`, `jac build --client desktop`, `jac start --client desktop --dev`
- Desktop uses Tauri v2 with Rust sidecar for backend API
