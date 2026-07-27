"""Every service spawn site must emit argv the real `jac` CLI accepts.

The runtime spawns sibling services by shelling out to `jac start ...
--no-client`. That argv is a cross-component contract with the CLI's argparse
layer, but it is assembled far from the parser: when #7512 renamed
`--no_client` to the documented `--no-client`, every auto-spawned service died
at argparse ("unrecognized arguments") and surfaced only as "did not become
healthy". These tests capture the argv each spawn site actually builds (Popen
is mocked - nothing runs) and feed it to the parser the `jac` binary really
uses, so a flag rename fails here instead of in production."""

import os;
import unittest.mock;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import jaclang.cli.commands.execution;
import from jaclang.cli.registry { get_registry }
import from jaclang.runtimelib { sv_client }


"""Assert the parser the `jac` entrypoint builds accepts `argv` headless."""
def _parse_with_real_cli(argv: list) {
    parser = get_registry().finalize();
    try {
        ns = parser.parse_args(argv);
    } except SystemExit {
        assert False , f"the real `jac` CLI rejected spawn argv: {argv}";
    }
    assert getattr(ns, "no_client", False) is True , (
        f"service spawn must run headless (no_client): {argv}"
    );
}


"""A subprocess.Popen stand-in that records argv and spawns nothing."""
def _capture_popen(captured: list) -> any {
    fake = unittest.mock.MagicMock();
    fake.poll.return_value = None;
    fake.pid = 4242;
    def _spawn(cmd: any, *args: any, **kwargs: any) -> any {
        captured.append([str(c) for c in cmd]);
        return fake;
    }
    return _spawn;
}


test "sv-to-sv sibling spawn (scale plugin) argv is accepted by the real CLI" {
    import from jaclang.scale.plugin { JacScalePlugin }
    with TemporaryDirectory() as tmpdir {
        (Path(tmpdir) / "argv_probe_plugin.jac").write_text(
            "def:pub ping() -> int { return 1; }"
        );
        captured: list = [];
        with unittest.mock.patch("subprocess.Popen", _capture_popen(captured)) {
            with unittest.mock.patch(
                "jaclang.scale.runtime.context.util.wait_for_health", return_value=True
            ) {
                JacScalePlugin.ensure_sv_service("argv_probe_plugin", tmpdir);
            }
        }
        sv_client.unregister("argv_probe_plugin");
        assert len(captured) == 1 , f"expected one spawn, got {captured}";
        # captured[0][0] is the jac executable; the rest is the CLI invocation.
        _parse_with_real_cli(captured[0][1:]);
    }
}

test "orchestrator start_service argv is accepted by the real CLI" {
    import from jaclang.scale.runtime.gateway.service_registry {
        ServiceRegistry,
        ServiceEntry
    }
    import from jaclang.scale.runtime.orchestrator.process_manager {
        ServiceProcessManager
    }
    with TemporaryDirectory() as tmpdir {
        # start_service writes .jac/logs + pid/port files relative to cwd.
        old_cwd = os.getcwd();
        os.chdir(tmpdir);
        try {
            reg = ServiceRegistry();
            reg.register(
                ServiceEntry(
                    name="argv_probe_orch", file="svc.jac", prefix="/svc", port=18497
                )
            );
            mgr = ServiceProcessManager(registry=reg);
            captured: list = [];
            with unittest.mock.patch("subprocess.Popen", _capture_popen(captured)) {
                ok = mgr.start_service("argv_probe_orch");
            }
            assert ok , "start_service should report success with Popen mocked";
            sv_client.unregister("argv_probe_orch");
            assert len(captured) == 1 , f"expected one spawn, got {captured}";
            _parse_with_real_cli(captured[0][1:]);
        } finally {
            os.chdir(old_cwd);
        }
    }
}

test "client dev backend spawn argv is accepted by the real CLI" {
    import from jaclang.runtimelib.client.targets.client_dev_common {
        start_backend_server_common
    }
    captured: list = [];
    with unittest.mock.patch("subprocess.Popen", _capture_popen(captured)) {
        start_backend_server_common(Path("app.jac"), Path("."), 8321);
    }
    assert len(captured) == 1 , f"expected one spawn, got {captured}";
    # argv is [sys.executable, "-m", "jaclang", <cli invocation...>].
    _parse_with_real_cli(captured[0][3:]);
}
