"""Desktop dev-mode (Vite HMR) wiring.

Pins the three things that, if they regress, silently break desktop --dev:
  1. The Vite reload plugin + /__jac broker proxy are emitted for desktop dev.
  2. The generated native host reads _ctx.dev_port and falls back to _ctx.port.
  3. The .jac change handler recompiles in-tree sources and ignores the rest.
"""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.watcher { ChangeType, FileChangeEvent }


def _write_min_jac_toml(project_dir: str) {
    toml_content = '[project]\nname = "desktop-dev-test"\nversion = "1.0.0"\n';
    with open(os.path.join(project_dir, "jac.toml"), "w") as f {
        f.write(toml_content);
    }
}


def _mock_client_entry(project_dir: str) -> Path {
    entry_file = Path(project_dir) / ".jac" / "client" / "build" / "main.js";
    entry_file.parent.mkdir(parents=True, exist_ok=True);
    entry_file.write_text("// Mock entry");
    return entry_file;
}


# =============================================================================
# Vite config: the reload mechanism
# =============================================================================
"""Desktop dev must emit the compiled-dir reload plugin (the thing mobile relies
on) plus the /__jac broker proxy and a loopback-bound, strictPort server."""
test "vite config emits reload plugin + broker proxy for desktop dev" {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            _write_min_jac_toml(temp_dir);
            entry_file = _mock_client_entry(temp_dir);

            bundler = ViteBundler(Path(temp_dir));
            vite_config_path = bundler.create_vite_config(
                entry_file,
                is_dev=True,
                api_port=8123,
                for_desktop_dev=True,
                desktop_broker_port=8123
            );
            vite_content = vite_config_path.read_text();

            # The reload mechanism: without this plugin, recompiles are inert.
            assert "jacCompiledReload" in vite_content , (
                "desktop dev config must emit the compiled-dir reload plugin"
            );
            # SSO/session broker routed to the pinned loopback port via Vite.
            assert '"/__jac"' in vite_content , "desktop dev must proxy /__jac to the broker";
            assert "http://127.0.0.1:8123" in vite_content , "broker proxy target must use the pinned port";
            # Loopback-only + strict port so the baked env URL is never wrong.
            assert 'host: "127.0.0.1"' in vite_content , "desktop dev server must bind loopback only";
            assert "strictPort: true" in vite_content , "desktop dev server must use strictPort";
        } finally {
            os.chdir(original_cwd);
        }
    }
}


"""Without for_desktop_dev, neither the reload plugin nor the broker proxy is
emitted (so web/mobile builds stay untouched)."""
test "vite config omits reload plugin + broker proxy by default" {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            _write_min_jac_toml(temp_dir);
            entry_file = _mock_client_entry(temp_dir);

            bundler = ViteBundler(Path(temp_dir));
            vite_config_path = bundler.create_vite_config(entry_file, is_dev=True);
            vite_content = vite_config_path.read_text();

            assert "jacCompiledReload" not in vite_content , (
                "reload plugin must not be emitted for non-desktop dev builds"
            );
            assert '"/__jac"' not in vite_content , (
                "broker proxy must not be emitted for non-desktop dev builds"
            );
            assert "strictPort: true" not in vite_content , (
                "strictPort must not be forced for non-desktop dev builds"
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}


# =============================================================================
# Generated native host: dev_port branch
# =============================================================================
"""The host reads _ctx.dev_port and, when > 0, navigates to the Vite dev server;
otherwise it falls back to the loopback port (unchanged prod behaviour)."""
test "generated host source branches on dev_port" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source("T", 800, 600, "test-app");
    assert "_ctx.dev_port" in src , "host must read _ctx.dev_port";
    assert "target_port = dev_port if dev_port > 0 else port" in src , (
        "host must fall back to the loopback port when no dev port is set"
    );
    # No codegen-time URL bake: the env is the control-plane seam, read at boot.
    assert "DEV_URL" not in src , "host must not bake a dev URL glob at codegen time";
}


# =============================================================================
# HMR change handler: recompile on in-tree .jac, ignore the rest
# =============================================================================
# Desktop inherits this behaviour from the shared _ClientHmrHandler base, so
# these tests pin the shared handler that desktop (and mobile) rely on.
obj _FakeJacCompiler {
    has return_mod: any = "MOD",
        calls: list = [];

    def compile_module(entry_file: any) -> tuple {
        self.calls.append(str(entry_file));
        return (None, self.return_mod, None);
    }
}

obj _FakeCompiler {
    has jac_compiler: any,
        compile_calls: list = [];

    def compile(mod: any, entry_file: any) {
        self.compile_calls.append((mod, str(entry_file)));
    }
}

test "hmr handler recompiles on in-tree .jac change" {
    import from jaclang.runtimelib.client.targets.client_dev_common {
        _ClientHmrHandler
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir);
        entry_file = project_dir / "app.jac";
        entry_file.write_text("cl { }");
        jc = _FakeJacCompiler();
        compiler = _FakeCompiler(jac_compiler=jc);
        handler = _ClientHmrHandler(
            compiler=compiler, entry_file=entry_file, project_dir=project_dir
        );
        handler.on_event(
            FileChangeEvent(
                path=str(entry_file), change_type=ChangeType.MODIFIED, timestamp=0.0
            )
        );
        assert len(jc.calls) == 1 , "entry module must be recompiled on .jac save";
        assert len(compiler.compile_calls) == 1 , "compiled client must be rebuilt on .jac save";
    }
}

test "hmr handler ignores non-.jac and out-of-tree files" {
    import from jaclang.runtimelib.client.targets.client_dev_common {
        _ClientHmrHandler
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir);
        entry_file = project_dir / "app.jac";
        entry_file.write_text("cl { }");
        jc = _FakeJacCompiler();
        compiler = _FakeCompiler(jac_compiler=jc);
        handler = _ClientHmrHandler(
            compiler=compiler, entry_file=entry_file, project_dir=project_dir
        );
        # Non-.jac in-tree file -> no recompile.
        css_file = project_dir / "styles.css";
        css_file.write_text("body { }");
        handler.on_event(
            FileChangeEvent(
                path=str(css_file), change_type=ChangeType.MODIFIED, timestamp=0.0
            )
        );
        assert len(jc.calls) == 0 , "non-.jac changes must not trigger a recompile";
        # Out-of-tree .jac file -> no recompile.
        with tempfile.TemporaryDirectory() as other_dir {
            outside = Path(other_dir) / "other.jac";
            outside.write_text("cl { }");
            handler.on_event(
                FileChangeEvent(
                    path=str(outside), change_type=ChangeType.MODIFIED, timestamp=0.0
                )
            );
            assert len(jc.calls) == 0 , "out-of-tree .jac changes must not trigger a recompile";
        }
    }
}
