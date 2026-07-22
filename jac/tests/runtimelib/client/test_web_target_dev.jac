"""Regression tests for WebTarget.dev() -- the web/static/PWA HMR dev flow.

Bug (#7660): WebTarget.dev() -- inherited directly by StaticTarget, and
indirectly by PWATarget via `super.dev(...)` -- started the Vite dev server
without ever compiling the .jac client entry into `.jac/client/compiled/`
first. A brand new project's very first `jac start -d` therefore always
failed with "Failed to resolve import /compiled/_entry.js"; it only started
working after a `jac start` (production build) had populated that directory
as a side effect. MobileTarget.dev() and NativeDesktopTarget.dev() already
compiled up front via `prepare_vite_dev_compilation()`; WebTarget.dev() was
the one target that skipped this step.

These tests mock at the same seam MobileTarget/NativeDesktopTarget's own
tests do (client_dev_common's helpers), rather than driving a real compile:
`prepare_vite_dev_compilation()` resolves its output directory through the
process-wide ambient project config, so invoking it for real against an
isolated temp project inside a test runner whose own ambient project is this
monorepo lands compiled output in the *monorepo's* .jac/client/compiled
instead -- a separate, pre-existing global-state quirk, unrelated to this
fix, that isn't worth fighting in a unit test.
"""

import unittest.mock;
import from pathlib { Path }


obj _FakeBundler {
    has calls: list = [];

    def create_vite_config(entry_file: any, **kw: dict) -> any {
        return None;
    }

    def start_dev_server(**kw: dict) -> any {
        self.calls.append("serve");
        return None;
    }
}


def _no_watchdog(label: str) -> bool {
    return False;
}


"""WebTarget.dev() must compile the client entry (prepare_vite_dev_compilation)
before starting the Vite dev server (start_dev_server) -- the exact ordering
the bug violated (server started first; compile step never ran at all)."""
test "web target dev compiles client entry before starting vite" {
    import from jaclang.runtimelib.client.targets.web_target { WebTarget }

    calls: list = [];
    fake_bundler = _FakeBundler(calls=calls);

    def _fake_prepare(project_dir: any, entry_file: any) -> tuple {
        calls.append("compile");
        return (fake_bundler, object());
    }

    with unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.prepare_vite_dev_compilation",
        _fake_prepare
    ), unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.ensure_watchdog_common",
        _no_watchdog
    ) {
        target = WebTarget();
        target.dev(Path("app.jac"), Path("."), port=0, api_port=0);
    }

    assert calls == ["compile", "serve"] , (
        "WebTarget.dev() must call prepare_vite_dev_compilation() before "
        f"start_dev_server(); got call order: {calls}"
    );
}


"""The HMR file watcher cleanup must run even when start_dev_server hands
back a falsy process. Before this fix, cleanup only ran inside
`if process { ... }`, so a falsy/None process would leak the watcher thread;
it must now run unconditionally, in a `finally`."""
test "web target dev stops the hmr watcher even when start_dev_server returns nothing" {
    import from jaclang.runtimelib.client.targets.web_target { WebTarget }

    fake_bundler = _FakeBundler();

    def _fake_prepare(project_dir: any, entry_file: any) -> tuple {
        return (fake_bundler, object());
    }

    stop_calls: list = [];

    def _fake_stop_dev_watcher(watcher: any) {
        stop_calls.append(watcher);
    }

    with unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.prepare_vite_dev_compilation",
        _fake_prepare
    ), unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.ensure_watchdog_common",
        _no_watchdog
    ), unittest.mock.patch(
        "jaclang.runtimelib.client.targets.client_dev_common.stop_dev_watcher",
        _fake_stop_dev_watcher
    ) {
        target = WebTarget();
        target.dev(Path("app.jac"), Path("."), port=0, api_port=0);
    }

    assert len(stop_calls) == 1 , (
        "stop_dev_watcher must run exactly once even though start_dev_server "
        "returned a falsy process -- otherwise the HMR watcher thread leaks"
    );
}


"""StaticTarget does not override dev() -- it must keep inheriting
WebTarget's (fixed) compile-then-serve behavior, since this is exactly the
path `jac start -d` takes for a `kind = "web-static"` project (the bug's
original repro). PWATarget does define its own dev(), but only to print a
PWA-specific notice before delegating to WebTarget's via `super.dev(...)` --
so it inherits the fix too."""
test "static and pwa targets both rely on webtarget's fixed dev flow" {
    import from jaclang.runtimelib.client.targets.static_target { StaticTarget }

    assert "dev" not in StaticTarget.__dict__ , (
        "StaticTarget must not define its own dev() override; it should "
        "keep inheriting WebTarget.dev() so this fix covers web-static "
        "projects too"
    );

    pwa_impl_path = (
        Path(__file__).parent.parent.parent.parent / "jaclang" / "runtimelib" / "client" / "targets" / "impl" / "pwa_target.impl.jac"
    );
    content = pwa_impl_path.read_text();
    dev_start = content.index("impl PWATarget.dev(");
    dev_end = content.index("\nimpl PWATarget.start(");
    dev_body = content[dev_start:dev_end];
    assert "super.dev(" in dev_body , (
        "PWATarget.dev() must delegate to WebTarget.dev() via super.dev() "
        "so it inherits the compile-before-serve fix too"
    );
}
