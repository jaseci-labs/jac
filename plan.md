- It depends on private compiler internals.
 ink_compile/compile.py calls ClientBundleBuilder()._compile_to_js(...). The underscore API is explicitly internal. So even aside from vendoring, this is
 pinned to a private implementation detail of jaclang.
- The vendored compiler is not passive reuse; it adds regex surgery.
 ink_compile/bundle_patch.py is a pile of post-compilation patchers:
  - fix_broken_nullish_or
  - fix_missing_loop_close
  - fix_tuple_unpack_loops
  - consolidate_bundle_imports
  - hoist_jac_runtime
 That’s not “use jac-ink as-is”; it’s a shadow fork with local transforms that will drift.
- The runtime shims openly implement only a subset of behavior.
 compile.py injects shims where unsupported paths throw at runtime:
  - __jacSpawn is not supported in Ink mode yet
  - @jac/runtime export '<name>' is not supported in Ink mode yet
 So the custom compiler path is already knowingly incomplete.
- Build invalidation is fragile.
 run_tui_session.impl.jac recompiles only when:
  - runner.mjs missing
  - runtime.cl.jac newer
  - compile.py newer
  - bundle_patch.py newer
 It does not track any future imported .cl.jac files, shared modules, or jac.toml dependency changes. So as soon as the TUI is split into real components,
 stale bundles become likely.
- The monolith has singleton-process state bugs, not just style issues.
 In runtime.cl.jac, _timer, feedSinceId, toolSeq, displayEvents, etc. are globs. That means:
  - only one polling loop can exist sanely
  - a second app instance shares polluted state
  - “clear/reset” is manual global mutation, not component lifecycle
  - Hot reload/re-mount behavior is inherently brittle
- Polling is hardcoded at 200ms because streaming is broken.
 runtime.cl.jac uses setInterval(tick, 200). So the architecture silently degraded from event-driven SSE to constant polling load, exactly because the bridge
 can’t carry ui_stream() correctly.
- There’s dead/contradictory artifact layering.
  - extras.jac exists for Jac-server reuse
  - extras.py exists for Python bootstrap import
  - main.jac exists for jac start
  - but the launcher uses neither jac start nor extras.jac
 So the codebase currently contains both the intended design and the bypass, with the bypass being the live path.
- The duplicated if not exports block is a symptom, not a one-off.
 The duplicate in ink_compile/compile.py is obvious dead code, but it also signals this subtree hasn’t had even minimal review/tests despite being core
 startup infrastructure.

 So yes: the PR isn’t just “a bit heavy.” It currently ships a parallel architecture:

 1. copied compiler,
 2. copied/duplicated endpoints,
 3. custom transport,
 4. runtime polling fallback,
 5. partial TUI-specific hooks in core.
