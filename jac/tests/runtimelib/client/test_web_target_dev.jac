"""Regression tests for WebTarget.dev() -- the web/static/PWA dev flow.

Bug (#7660): WebTarget.dev() started Vite without compiling the .jac
client entry first, so a fresh project's first `jac start -d` failed
with "Failed to resolve import /compiled/_entry.js". StaticTarget and
PWATarget inherit this method, so both were affected too.

Tests mock prepare_vite_dev_compilation() rather than calling it for
real, since it resolves output paths via ambient project config that
won't match an isolated temp project in this test runner.
"""

import unittest.mock;
import from pathlib { Path }


obj _FakeBundler {
    has calls: list;

    def create_vite_config(entry_file: any, **kw: dict) -> any {
        return None;
    }

    def start_dev_server(**kw: dict) -> any {
        self.calls.append("serve");
        return None;
    }
}


obj _FakeWatcher {
    has events: list;

    def add_callback(cb: any) {
        self.events.append("callback");
    }

    def start {
        self.events.append("start");
    }

    def stop {
        self.events.append("stop");
    }
}


"""Runs target.dev() with the compile step and the watchdog probe stubbed out,
and returns the steps the flow actually took, in order. Passing a watcher makes
ensure_watchdog_common() report watchdog as available, so the HMR path runs."""
def _record_dev_calls(target: any, watcher: any = None) -> list {
    calls: list = [];
    fake_bundler = _FakeBundler(calls=calls);

    def _fake_prepare(project_dir: any, entry_file: any) -> tuple {
        calls.append("compile");
        return (fake_bundler, object());
    }

    def _fake_ensure_watchdog(label: str) -> bool {
        return watcher is not None;
    }

    def _fake_watcher_cls(**kw: dict) -> any {
        return watcher;
    }

    with unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.prepare_vite_dev_compilation",
        _fake_prepare
    ), unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.ensure_watchdog_common",
        _fake_ensure_watchdog
    ), unittest.mock.patch(
        "jaclang.runtimelib.watcher.JacFileWatcher", _fake_watcher_cls
    ) {
        target.dev(Path("app.jac"), Path("."), port=0, api_port=0);
    }
    return calls;
}


"""WebTarget.dev() must compile the client entry (prepare_vite_dev_compilation)
before starting the Vite dev server (start_dev_server) -- the exact ordering
the bug violated (server started first; compile step never ran at all)."""
test "web target dev compiles client entry before starting vite" {
    import from jaclang.runtimelib.client.targets.web_target { WebTarget }

    calls = _record_dev_calls(WebTarget());

    assert calls == ["compile", "serve"] , (
        "WebTarget.dev() must call prepare_vite_dev_compilation() before "
        f"start_dev_server(); got call order: {calls}"
    );
}


"""The HMR watcher must be wired to the recompile callback, started, and then
stopped on the way out -- including when start_dev_server hands back a falsy
process, which skips the wait/interrupt block entirely and would otherwise
leak the watcher thread."""
test "web target dev wires up the hmr watcher and always stops it" {
    import from jaclang.runtimelib.client.targets.web_target { WebTarget }

    watcher = _FakeWatcher(events=[]);
    _record_dev_calls(WebTarget(), watcher=watcher);

    assert watcher.events == ["callback", "start", "stop"] , (
        "the HMR watcher must be given its recompile callback, started, and "
        f"stopped even when no dev server process comes back; got: {watcher.events}"
    );
}


"""`jac start -d` on a `kind = "web-static"` project (the bug's original repro)
runs StaticTarget.dev(), which is WebTarget's inherited one; PWATarget defines
its own only to print a notice before delegating via super.dev(). Both must end
up on the fixed compile-then-serve path."""
test "static and pwa dev flows inherit the compile-before-serve fix" {
    import from jaclang.runtimelib.client.targets.pwa_target { PWATarget }
    import from jaclang.runtimelib.client.targets.static_target { StaticTarget }

    assert _record_dev_calls(StaticTarget()) == ["compile", "serve"] , (
        "StaticTarget must inherit WebTarget.dev(), so web-static projects "
        "compile before Vite starts"
    );
    assert _record_dev_calls(PWATarget()) == ["compile", "serve"] , (
        "PWATarget.dev() must delegate to WebTarget.dev() via super.dev(), so "
        "PWA projects compile before Vite starts"
    );
}
