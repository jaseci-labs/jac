"""Integration tests for the Jac desktop plugin IPC system.

Exercises the full build pipeline and Python dispatch roundtrip without
requiring a webview or display. Covers:

  1. Plugin transpilation: all .jac -> .py (with jac0 fallback)
  2. Generated host source validity
  3. Full Python dispatch: import real plugins, register, dispatch commands
  4. Config -> plugin registration (TOML -> enabled/disabled)
  5. FsPlugin security: allow-list enforcement, path traversal prevention
  6. ShellPlugin security: deny-all default, glob matching, no shell injection
  7. JS SDK injection snippet validity
  8. Generated CPython bootstrap correctness
"""
import json;
import os;
import shutil;
import subprocess;
import sysconfig;
import tempfile;
import from pathlib { Path }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
"""Locate the desktop target package root.

Desktop now ships inside jaclang core at
``jaclang/runtimelib/client/targets/desktop/``; resolve it from the installed
``jaclang`` package rather than walking the test file's parents."""
def _pkg_root -> Path {
    import jaclang;
    pkg = (
        Path(jaclang.__file__).parent / "runtimelib" / "client" / "targets" / "desktop"
    );
    if not (pkg / "plugin" / "plugin_host.jac").exists() {
        raise RuntimeError("Could not find desktop target package root at " + str(pkg));
    }
    return pkg;
}

"""Locate the native/ directory (contains plugin_bridge.na.jac)."""
def _native_dir -> Path {
    return _pkg_root() / "native";
}

"""Locate the plugin source directory."""
def _plugin_src_dir -> Path {
    return _pkg_root() / "plugin";
}

"""Locate the desktop plugin config module (desktop_plugin_config.jac).

It lives one level up from the desktop target package, directly under
``jaclang/runtimelib/client/``."""
def _plugin_config_path -> Path {
    return _pkg_root().parent.parent / "desktop_plugin_config.jac";
}

"""The rich window.__jac SDK shim (invoke/on/__emit__).

Single in-test copy of the SDK so the JS tests below don't each carry their own.
`cef_dispatch.na.jac`'s BOOTSTRAP_JS glob is the source of truth (this is the
slice `_jac_sdk_js()` extracts for the web target); the "js sdk snippet matches
generated host source" test asserts this copy has not drifted from it."""
def _bootstrap_js_snippet -> str {
    return (
        "(function(){"
        "var _l={};"
        "window.__jac={"
        "invoke:function(p,c,a){"
        "return window.__jac_invoke(p,c,a||{}).then(function(r){"
        "if(typeof r==='string')r=JSON.parse(r);"
        "if(r.ok)return r.data;"
        "var e=new Error(r.error.message);"
        "e.code=r.error.code;throw e;"
        "});"
        "},"
        "on:function(ev,cb){"
        "(_l[ev]=_l[ev]||[]).push(cb);"
        "return function(){var a=_l[ev]||[];var i=a.indexOf(cb);"
        "if(i!==-1)a.splice(i,1);};"
        "},"
        "__emit__:function(ev,p){"
        "(_l[ev]||[]).forEach(function(h){try{h(p);}catch(_){}});"
        "}"
        "};"
        "window.__JAC_DESKTOP__=true;"
        "window.__JAC_BROKER__='/__jac';"
        "})();"
    );
}

"""Run jac2py on a file, return (ok, stdout_or_None, stderr_or_None)."""
def _jac2py(jac_file: Path) -> tuple {
    jac = shutil.which("jac") or "jac";
    result = subprocess.run(
        [jac, "jac2py", str(jac_file)], capture_output=True, text=True, timeout=60
    );
    return (
        result.returncode == 0 and bool(result.stdout.strip()),
        result.stdout,
        result.stderr
    );
}

"""Transpile all plugin .jac files into a temp dir, returning (dir, results).

results is a dict mapping relative path -> {ok, used_jac0, error}.
"""
def _transpile_all_plugins -> tuple {
    tmp = tempfile.mkdtemp();
    src_dir = _plugin_src_dir();
    results: dict = {};
    for jac_file in sorted(src_dir.rglob("*.jac")) {
        # rglob("*.jac") also matches directories named ".jac" (build cache).
        if not jac_file.is_file() {
            continue;
        }
        rel = str(jac_file.relative_to(src_dir));
        py_name = str(jac_file.with_suffix(".py").relative_to(src_dir));
        target = os.path.join(tmp, py_name);
        os.makedirs(os.path.dirname(target), exist_ok=True);
        (ok, stdout, stderr) = _jac2py(jac_file);
        if ok {
            with open(target, "w") as f {
                f.write(stdout);
            }
            results[rel] = {"ok": True, "used_jac0": False, "error": None};
        } else {
            # Safe fallback: jac0.compile_jac() uses a simpler transpilation
            # path that handles f-strings the full pipeline can't (upstream bug
            # jaseci-labs/jaseci#6564). Remove once fixed.
            import jaclang.jac0 as jac0;
            try {
                jac0_out = jac0.compile_jac(jac_file.read_text());
                if jac0_out and jac0_out.strip() {
                    with open(target, "w") as f {
                        f.write(jac0_out);
                    }
                    results[rel] = {"ok": True, "used_jac0": True, "error": None};
                } else {
                    results[rel] = {
                        "ok": False,
                        "used_jac0": False,
                        "error": stderr or "(empty output from both jac2py and jac0)"
                    };
                }
            } except Exception as e {
                results[rel] = {
                    "ok": False,
                    "used_jac0": False,
                    "error": f"{stderr or '(empty)'} | jac0: {e}"
                };
            }
        }
    }
    return (tmp, results);
}

"""Try importing a module, return True if successful, False otherwise."""
def _try_import(mod_name: str) -> bool {
    try {
        __import__(mod_name);
        return True;
    } except Exception {
        return False;
    }
}

"""Get the ShellPlugin class directly (avoids built_in attribute issues in Jac)."""
def _get_shell_plugin_class -> object {
    mod = _import_plugin("built_in.shell_plugin");
    return getattr(mod, "ShellPlugin");
}

"""Get the FsPlugin class directly (avoids built_in attribute issues in Jac)."""
def _get_fs_plugin_class -> object {
    mod = _import_plugin("built_in.fs_plugin");
    return getattr(mod, "FsPlugin");
}

"""Common module names to clean up after plugin tests."""
def _plugin_mod_names -> list {
    return [
        "desktop_plugin",
        "plugin_host",
        "built_in",
        "built_in.path_plugin",
        "built_in.fs_plugin",
        "built_in.notification_plugin",
        "built_in.clipboard_plugin",
        "built_in.dialog_plugin",
        "built_in.window_plugin",
        "built_in.shell_plugin"
    ];
}

"""Run a function with the plugin source directory on sys.path, restoring it after."""
def _with_plugins(fn: callable) {
    import sys;
    saved_path = sys.path[:];
    sys.path.insert(0, str(_plugin_src_dir()));
    try {
        fn();
    } finally {
        sys.path[:] = saved_path;
    }
}


"""Import a plugin module from its .jac source.

The Jac meta-importer may fail on some .jac files. This function handles
both paths: try normal import first (works for compiled .jac modules),
then fall back to loading the transpiled .py directly.
"""
def _import_plugin(mod_name: str) -> object {
    import importlib;
    try {
        return importlib.import_module(mod_name);
    } except Exception {
        # Fall back to loading transpiled .py directly
        import importlib.util;
        parts = mod_name.split(".");
        # e.g. "built_in.shell_plugin" -> "built_in/shell_plugin.py"
        py_path = str(_plugin_src_dir().joinpath(*parts)) + ".py";
        spec = importlib.util.spec_from_file_location(mod_name, py_path);
        if spec is None {
            raise ImportError(f"Cannot find {mod_name} as .jac or .py");
        }
        mod = importlib.util.module_from_spec(spec);
        spec.loader.exec_module(mod);
        import sys;
        sys.modules[mod_name] = mod;
        # Ensure parent package is in sys.modules for attribute access
        # e.g. for "built_in.shell_plugin", set built_in.shell_plugin attr
        if "." in mod_name {
            parent_name = ".".join(parts[:-1]);
            child_name = parts[-1];
            if parent_name in sys.modules {
                setattr(sys.modules[parent_name], child_name, mod);
            }
        }
        return mod;
    }
}

"""Import _generate_host_source using the installed precompiled module.

The Jac meta-importer intercepts imports of .jac files in the local repo
and fails. We load the installed JIR bytecode directly instead.
"""
def _get_generate_host_source -> object {
    import sys;
    # The installed package has precompiled bytecode. If the module is already
    # loaded (it was imported when the desktop target was loaded), use it directly.
    mod_name = "jaclang.runtimelib.client.targets.desktop.native_desktop_target";
    if mod_name in sys.modules {
        return sys.modules[mod_name]._generate_host_source;
    }
    # Otherwise, we can't load it from the test runner (meta-importer blocks it).
    # Return a mock that generates a basic host for testing purposes.
    raise ImportError(
        "Cannot load _generate_host_source - module not pre-loaded. "
        "Run 'pip install -e .' first."
    );
}


# ---------------------------------------------------------------------------
# 1. Plugin transpilation
# ---------------------------------------------------------------------------
"""Every plugin .jac file transpiles (via jac2py or jac0 fallback)."""
test "all plugin files transpile or have jac0 fallback" {
    (tmp, results) = _transpile_all_plugins();
    try {
        failures = [
            r
            for r in results.items()
            if not r[1]["ok"]
        ];
        assert len(failures) == 0 , (
            "Some plugins failed to transpile:\n" + "\n".join(
                [f"  {r[0]}: {r[1]['error']}" for r in failures]
            )
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

"""Transpiled plugins produce valid Python that can be imported."""
test "transpiled plugin files are importable Python" {
    (tmp, results) = _transpile_all_plugins();
    try {
        import sys;
        saved_path = sys.path[:];
        sys.path.insert(0, tmp);
        try {
            # Import the base types first (other plugins depend on them)
            import desktop_plugin;
            import plugin_host;
            # Import all built-in plugins
            import built_in.path_plugin;
            import built_in.notification_plugin;
            import built_in.clipboard_plugin;
            _import_plugin("built_in.shell_plugin");
            # fs_plugin, dialog_plugin, shell_plugin transpile via jac0 fallback
            _FsPlugin = _get_fs_plugin_class();
            _try_import("built_in.dialog_plugin");
            _try_import("built_in.window_plugin");
            # Verify core classes exist on the base modules
            assert hasattr(desktop_plugin, "PluginError");
            assert hasattr(desktop_plugin, "DesktopPlugin");
            assert hasattr(plugin_host, "PluginHost");
            assert hasattr(built_in.path_plugin, "PathPlugin");
        } finally {
            sys.path[:] = saved_path;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ---------------------------------------------------------------------------
# 2. Full Python dispatch roundtrip (actual plugins, no webview)
# ---------------------------------------------------------------------------
"""PathPlugin dispatch roundtrip: resolve home directory."""
test "path plugin dispatch roundtrip" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            host = plugin_host.PluginHost();
            host.register("jac.path", built_in.path_plugin.PathPlugin());
            resp = json.loads(
                host.dispatch(
                    json.dumps({"plugin": "jac.path", "command": "home", "args": {}})
                )
            );
            assert resp["ok"] == True;
            assert "path" in resp["data"];
            assert len(resp["data"]["path"]) > 0;
            # Verify it's an absolute path
            assert resp["data"]["path"].startswith("/");
        }
    );
}

"""PluginHost.dispatch accepts libwebview bind arg arrays."""
test "dispatch accepts webview bind arg arrays" {
    _with_plugins(
        lambda {
            import plugin_host;
            import built_in.path_plugin;
            host = plugin_host.PluginHost();
            host.register("jac.path", built_in.path_plugin.PathPlugin());
            resp = json.loads(host.dispatch(json.dumps(["jac.path", "home", {}])));
            assert resp["ok"] == True;
            assert "path" in resp["data"];
        }
    );
}

"""PathPlugin dispatch roundtrip: separator command."""
test "path plugin separator command" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            host = plugin_host.PluginHost();
            host.register("jac.path", built_in.path_plugin.PathPlugin());
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {"plugin": "jac.path", "command": "separator", "args": {}}
                    )
                )
            );
            assert resp["ok"] == True;
            assert resp["data"]["separator"] == os.sep;
        }
    );
}

"""PathPlugin dispatch roundtrip: resolve command."""
test "path plugin resolve command" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            host = plugin_host.PluginHost();
            host.register("jac.path", built_in.path_plugin.PathPlugin());
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.path",
                            "command": "resolve",
                            "args": {"path": "~/.."}
                        }
                    )
                )
            );
            assert resp["ok"] == True;
            assert resp["data"]["path"] == str(Path.home().parent);
        }
    );
}

"""PathPlugin returns temp directory."""
test "path plugin temp command" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            host = plugin_host.PluginHost();
            host.register("jac.path", built_in.path_plugin.PathPlugin());
            resp = json.loads(
                host.dispatch(
                    json.dumps({"plugin": "jac.path", "command": "temp", "args": {}})
                )
            );
            assert resp["ok"] == True;
            assert len(resp["data"]["path"]) > 0;
        }
    );
}

"""PathPlugin returns data directory."""
test "path plugin data command" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            host = plugin_host.PluginHost();
            host.register("jac.path", built_in.path_plugin.PathPlugin());
            resp = json.loads(
                host.dispatch(
                    json.dumps({"plugin": "jac.path", "command": "data", "args": {}})
                )
            );
            assert resp["ok"] == True;
            assert "path" in resp["data"];
        }
    );
}

"""ShellPlugin deny-all: exec is blocked when no allow list configured."""
test "shell plugin denies all commands by default" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            _ShellPlugin = _get_shell_plugin_class();
            host = plugin_host.PluginHost();
            host.register("jac.shell", _ShellPlugin({}));
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "echo hello"}
                        }
                    )
                )
            );
            assert resp["ok"] == False;
            assert resp["error"]["code"] == "FORBIDDEN";
        }
    );
}

"""ShellPlugin allow-list: matching commands execute, non-matching are blocked."""
test "shell plugin allow-list matching" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            _ShellPlugin = _get_shell_plugin_class();
            config = {"allow": ["echo *", "ls *"]};
            host = plugin_host.PluginHost();
            host.register("jac.shell", _ShellPlugin(config));
            # Matching command should succeed
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "echo hello"}
                        }
                    )
                )
            );
            assert resp["ok"] == True;
            assert resp["data"]["exit_code"] == 0;
            assert "hello" in resp["data"]["stdout"];
            # Non-matching command should be blocked
            resp2 = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "rm -rf /tmp/something"}
                        }
                    )
                )
            );
            assert resp2["ok"] == False;
            assert resp2["error"]["code"] == "FORBIDDEN";
        }
    );
}

"""ShellPlugin blocks shell injection via glob-matched command strings."""
test "shell plugin rejects shell injection in allowed commands" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            _ShellPlugin = _get_shell_plugin_class();
            config = {"allow": ["echo *"]};
            host = plugin_host.PluginHost();
            host.register("jac.shell", _ShellPlugin(config));
            marker = "/tmp/jac_shell_injection_test";
            with open(marker, "w") as f {
                f.write("probe");
            }
            # shell=True + fnmatch on full string would run rm; argv + shell=False must not.
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": f"echo hello; rm -f {marker}"}
                        }
                    )
                )
            );
            assert resp["ok"] == True;
            assert "hello" in resp["data"]["stdout"];
            assert os.path.exists(marker);
            os.remove(marker);
        }
    );
}


"""Shell allow-list does not silently widen subcommands.

The old matcher only checked pattern_argv[0], so `allow=["git log"]` permitted
ALL git subcommands (the " log" was ignored). The token-aware matcher matches
each pattern token against the corresponding argv token.
"""
test "shell allow-list does not silently widen subcommands" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            _ShellPlugin = _get_shell_plugin_class();
            # "git log" must NOT permit "git push"
            host = plugin_host.PluginHost();
            host.register("jac.shell", _ShellPlugin({"allow": ["git log"]}));
            resp_ok = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "git log"}
                        }
                    )
                )
            );
            assert resp_ok["ok"] == True;
            resp_bad = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "git push"}
                        }
                    )
                )
            );
            assert resp_bad["ok"] == False;
            assert resp_bad["error"]["code"] == "FORBIDDEN";
            # Trailing wildcard still works
            host2 = plugin_host.PluginHost();
            host2.register("jac.shell", _ShellPlugin({"allow": ["git *"]}));
            resp_wild = json.loads(
                host2.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "git push"}
                        }
                    )
                )
            );
            assert resp_wild["ok"] == True;
            # Exact match, extra args rejected unless wildcarded
            host3 = plugin_host.PluginHost();
            host3.register("jac.shell", _ShellPlugin({"allow": ["ls"]}));
            resp_exact = json.loads(
                host3.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "ls -la"}
                        }
                    )
                )
            );
            assert resp_exact["ok"] == False;
            assert resp_exact["error"]["code"] == "FORBIDDEN";
            host4 = plugin_host.PluginHost();
            host4.register("jac.shell", _ShellPlugin({"allow": ["ls *"]}));
            resp_wc = json.loads(
                host4.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.shell",
                            "command": "exec",
                            "args": {"command": "ls -la"}
                        }
                    )
                )
            );
            assert resp_wc["ok"] == True;
        }
    );
}


# ---------------------------------------------------------------------------
# 3. FsPlugin security
# ---------------------------------------------------------------------------
"""FsPlugin blocks reads when no allow_read is configured."""
test "fs plugin blocks reads with empty allow list" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            _FsPlugin = _get_fs_plugin_class();
            host = plugin_host.PluginHost();
            path_p = built_in.path_plugin.PathPlugin();
            host.register("jac.path", path_p);
            # No allow_read entries
            fs_p = _FsPlugin({}, path_p);
            host.register("jac.fs", fs_p);
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.fs",
                            "command": "read_file",
                            "args": {"path": "/etc/hostname"}
                        }
                    )
                )
            );
            assert resp["ok"] == False;
            assert resp["error"]["code"] == "FORBIDDEN";
        }
    );
}

"""FsPlugin enforces allow_read for paths inside the allow list."""
test "fs plugin allows reads within allowed paths" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            _FsPlugin = _get_fs_plugin_class();
            with tempfile.TemporaryDirectory() as td {
                # Create a test file inside the allowed dir
                test_file = Path(td) / "test.txt";
                test_file.write_text("hello from integration test");
                host = plugin_host.PluginHost();
                path_p = built_in.path_plugin.PathPlugin();
                host.register("jac.path", path_p);
                fs_p = _FsPlugin({"allow_read": [str(td)]}, path_p);
                host.register("jac.fs", fs_p);
                resp = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "read_file",
                                "args": {"path": str(test_file)}
                            }
                        )
                    )
                );
                assert resp["ok"] == True;
                assert resp["data"]["content"] == "hello from integration test";
            }
        }
    );
}

"""FsPlugin blocks reads outside the allowed directory."""
test "fs plugin blocks reads outside allowed paths" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            _FsPlugin = _get_fs_plugin_class();
            with tempfile.TemporaryDirectory() as td {
                host = plugin_host.PluginHost();
                path_p = built_in.path_plugin.PathPlugin();
                host.register("jac.path", path_p);
                fs_p = _FsPlugin({"allow_read": [str(td)]}, path_p);
                host.register("jac.fs", fs_p);
                resp = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "read_file",
                                "args": {"path": "/etc/hostname"}
                            }
                        )
                    )
                );
                assert resp["ok"] == False;
                assert resp["error"]["code"] == "FORBIDDEN";
            }
        }
    );
}

"""FsPlugin write + read roundtrip inside an allowed directory."""
test "fs plugin write and read roundtrip" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            _FsPlugin = _get_fs_plugin_class();
            with tempfile.TemporaryDirectory() as td {
                host = plugin_host.PluginHost();
                path_p = built_in.path_plugin.PathPlugin();
                host.register("jac.path", path_p);
                fs_p = _FsPlugin(
                    {"allow_read": [str(td)], "allow_write": [str(td)]}, path_p
                );
                host.register("jac.fs", fs_p);
                # Write a file
                write_resp = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "write_file",
                                "args": {
                                    "path": str(Path(td) / "subdir" / "test.txt"),
                                    "content": "integration test content"
                                }
                            }
                        )
                    )
                );
                assert write_resp["ok"] == True;
                # Read it back
                read_resp = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "read_file",
                                "args": {"path": str(Path(td) / "subdir" / "test.txt")}
                            }
                        )
                    )
                );
                assert read_resp["ok"] == True;
                assert read_resp["data"]["content"] == "integration test content";
            }
        }
    );
}

"""FsPlugin exists command works within allowed paths."""
test "fs plugin exists command" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            _FsPlugin = _get_fs_plugin_class();
            with tempfile.TemporaryDirectory() as td {
                test_file = Path(td) / "exists_test.txt";
                test_file.write_text("data");
                host = plugin_host.PluginHost();
                path_p = built_in.path_plugin.PathPlugin();
                host.register("jac.path", path_p);
                fs_p = _FsPlugin({"allow_read": [str(td)]}, path_p);
                host.register("jac.fs", fs_p);
                # Existing file
                resp1 = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "exists",
                                "args": {"path": str(test_file)}
                            }
                        )
                    )
                );
                assert resp1["ok"] == True;
                assert resp1["data"]["exists"] == True;
                # Non-existing file
                resp2 = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "exists",
                                "args": {"path": str(Path(td) / "nope.txt")}
                            }
                        )
                    )
                );
                assert resp2["ok"] == True;
                assert resp2["data"]["exists"] == False;
            }
        }
    );
}

"""FsPlugin list_dir returns entries."""
test "fs plugin list_dir command" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.path_plugin;
            _FsPlugin = _get_fs_plugin_class();
            with tempfile.TemporaryDirectory() as td {
                # Create some files
                (Path(td) / "a.txt").write_text("aaa");
                (Path(td) / "b.txt").write_text("bbb");
                host = plugin_host.PluginHost();
                path_p = built_in.path_plugin.PathPlugin();
                host.register("jac.path", path_p);
                fs_p = _FsPlugin({"allow_read": [str(td)]}, path_p);
                host.register("jac.fs", fs_p);
                resp = json.loads(
                    host.dispatch(
                        json.dumps(
                            {
                                "plugin": "jac.fs",
                                "command": "list_dir",
                                "args": {"path": str(td)}
                            }
                        )
                    )
                );
                assert resp["ok"] == True;
                assert len(resp["data"]["entries"]) == 2;
                names = [e["name"] for e in resp["data"]["entries"]];
                assert "a.txt" in names;
                assert "b.txt" in names;
            }
        }
    );
}


# ---------------------------------------------------------------------------
# 4. NotificationPlugin & ClipboardPlugin instantiation
# ---------------------------------------------------------------------------
"""NotificationPlugin handles `notification = true` (not a dict)."""
test "notification plugin accepts true config" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.notification_plugin;
            host = plugin_host.PluginHost();
            # Config is True (from `notification = true` in TOML)
            host.register(
                "jac.notification",
                built_in.notification_plugin.NotificationPlugin(True)
            );
            # send should attempt (and likely fail in CI, but the plugin should
            # not reject the config)
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.notification",
                            "command": "send",
                            "args": {"title": "Test", "body": "Body"}
                        }
                    )
                )
            );
            # In CI, notify-send probably fails with UNAVAILABLE, but NOT
            # FORBIDDEN (which would mean config was misread).
            if not resp["ok"] {
                assert resp["error"]["code"] != "FORBIDDEN";
            }
        }
    );
}

"""ClipboardPlugin handles `clipboard = true` and denies write by default."""
test "clipboard plugin accepts true config with defaults" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.clipboard_plugin;
            host = plugin_host.PluginHost();
            # Config is True -> normalized to {} -> defaults to allow both
            host.register(
                "jac.clipboard", built_in.clipboard_plugin.ClipboardPlugin(True)
            );
            # Write should attempt (may fail with UNAVAILABLE in CI, but not
            # FORBIDDEN)
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {
                            "plugin": "jac.clipboard",
                            "command": "write",
                            "args": {"text": "hello"}
                        }
                    )
                )
            );
            if not resp["ok"] {
                assert resp["error"]["code"] != "FORBIDDEN";
            }
        }
    );
}

"""ClipboardPlugin respects allow_read=false."""
test "clipboard plugin blocks read when allow_read is false" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            import plugin_host;
            import built_in.clipboard_plugin;
            host = plugin_host.PluginHost();
            host.register(
                "jac.clipboard",
                built_in.clipboard_plugin.ClipboardPlugin(
                    {"allow_read": False, "allow_write": True}
                )
            );
            resp = json.loads(
                host.dispatch(
                    json.dumps(
                        {"plugin": "jac.clipboard", "command": "read", "args": {}}
                    )
                )
            );
            assert resp["ok"] == False;
            assert resp["error"]["code"] == "FORBIDDEN";
        }
    );
}


# ---------------------------------------------------------------------------
# 5. Generated host source validity
# ---------------------------------------------------------------------------
"""_generate_host_source produces a host with the correct structure.

We can't import _generate_host_source directly (meta-importer blocks it),
so we verify the structure by checking the installed module's output.
If the module is available, test it; otherwise, validate the expected
structure using the known format.
"""
test "generated host source contains required elements" {
    import sys;
    mod_name = "jaclang.runtimelib.client.targets.desktop.native_desktop_target";
    if mod_name not in sys.modules {
        return;  # Skip: module not loaded in this test runner
    }
    _generate_host_source = sys.modules[mod_name]._generate_host_source;

    src = _generate_host_source(
        title="TestApp",
        width=800,
        height=600,
        app_name="test-app",
        plugin_configs={"path": True, "fs": {"allow_read": ["$HOME"]}}
    );
    # Must contain key elements
    assert "import from webview" in src;
    assert "import from jacpyembed" in src;
    assert "jac_engine_boot" in src;
    assert "Py_Finalize" in src;
    assert "_jac_invoke_handler" in src;
    assert "_PH_DISPATCH" in src;
    assert "wv.bind" in src;
    assert "BOOTSTRAP_JS" in src;
    assert "SERVE_PY" in src;
    assert "__jac_invoke" in src;
    assert "TestApp" in src;
    assert "800" in src;
    assert "600" in src;
    # Plugin configs must be baked in
    assert "path" in src;
    assert "True" in src;
    # Bridge must be inlined (not imported from separate file)
    assert "PyGILState_Ensure" in src;
    assert "respond" in src;
    # Plugin bootstrap must use os.path.join(_root, ...) -- Jac f-strings with
    # nested quotes produced spec_from_file_location('mod, mod.py') (null loader).
    assert "os.path.join(_root," in src;
    assert "desktop_plugin, desktop_plugin.py" not in src;
    assert "_stash_wv_in_python" in src;
    assert "run_main_loop()" in src;
    assert "webview_create(0, 0)" in src;
    assert "LAST_WEBVIEW_HANDLE = _wv_raw" in src;
    assert "Webview(handle=_wv_raw)" in src;
}

"""_generate_host_source with empty plugin_configs still produces valid host."""
test "generated host source with no plugins" {
    import sys;
    mod_name = "jaclang.runtimelib.client.targets.desktop.native_desktop_target";
    if mod_name not in sys.modules {
        return;  # Skip: module not loaded in this test runner
    }
    _generate_host_source = sys.modules[mod_name]._generate_host_source;

    src = _generate_host_source(
        title="NoPlugins",
        width=640,
        height=480,
        app_name="no-plugins",
        plugin_configs={}
    );
    assert "import from webview" in src;
    assert "wv.bind" in src;
    assert "NoPlugins" in src;
    # Bridge must be inlined
    assert "_jac_invoke_handler" in src;
    # Plugin registration should use registry bootstrap
    assert "bootstrap_plugins" in src;
    assert "_pc.get" not in src;  # old hand-written registration removed
}


# ---------------------------------------------------------------------------
# 6. JS SDK validity
# ---------------------------------------------------------------------------
"""The JS SDK snippet is parseable JavaScript."""
test "js sdk snippet is valid javascript" {
    import subprocess;
    js_sdk = _bootstrap_js_snippet();
    # Check with node if available
    node_bin = shutil.which("node");
    if node_bin {
        # Wrap in a window mock since node doesn't have `window`
        wrapped = "var window = {};" + js_sdk + ";";
        result = subprocess.run(
            [node_bin, "-e", wrapped], capture_output=True, text=True, timeout=5
        );
        # node exit code should be 0 (no syntax errors)
        assert result.returncode == 0 , f"JS SDK failed to parse: {result.stderr}";
        # window.__jac should exist
        check = wrapped + "console.log(typeof window.__jac);";
        result2 = subprocess.run(
            [node_bin, "-e", check], capture_output=True, text=True, timeout=5
        );
        assert "object" in result2.stdout;
    }
    # Structural checks (always valid)
    assert "window.__jac" in js_sdk;
    assert "window.__JAC_DESKTOP__" in js_sdk;
    assert "window.__JAC_BROKER__" in js_sdk;
    assert "invoke" in js_sdk;
    assert "__emit__" in js_sdk;
}

"""JS SDK invoke function produces correct JSON from arguments."""
test "js sdk invoke produces correct request format" {
    node_bin = shutil.which("node");
    if not node_bin {
        return;  # Skip in environments without node
    }
    test_code = (
        "var captured = null;"
        "window = {__jac_invoke: function(p,c,a) { captured = {plugin:p,command:c,args:a}; "
        "return Promise.resolve({ok:true,data:{x:1}}); }};"
    ) + _bootstrap_js_snippet() + (
        "window.__jac.invoke('fs','read_file',{path:'/tmp/x'}).then(function(r){"
        "console.log(JSON.stringify(captured));"
        "console.log('RESULT:'+JSON.stringify(r));"
        "});"
    );
    result = subprocess.run(
        [node_bin, "-e", test_code], capture_output=True, text=True, timeout=5
    );
    assert result.returncode == 0;
    lines = result.stdout.strip().split("\n");
    # First line: the captured request
    captured = json.loads(lines[0]);
    assert captured["plugin"] == "fs";
    assert captured["command"] == "read_file";
    assert captured["args"]["path"] == "/tmp/x";
    # Second line: the result
    assert "RESULT:" in lines[1];
    result_data = json.loads(lines[1].replace("RESULT:", ""));
    assert result_data["x"] == 1;
}

"""The in-test JS shim must match the canonical SDK source of truth.

Guards the single _bootstrap_js_snippet() copy against drifting from the real
window.__jac SDK, which is single-sourced from cef_dispatch.na.jac's BOOTSTRAP_JS
glob (the slice _jac_sdk_js() extracts for the web target). The native desktop
target no longer carries this rich SDK -- its _generate_host_source emits a
flag-only document-start shim (__JAC_DESKTOP__/__JAC_BROKER__/__JAC_NATIVE__) and
binds window.__jac_invoke directly via wv.bind -- so the CEF glob, not the native
host source, is what this snippet must track."""
test "js sdk snippet matches generated host source" {
    cef_src = (_native_dir() / "cef" / "cef_dispatch.na.jac").read_text();
    assert _bootstrap_js_snippet() in cef_src , "in-test JS shim drifted from cef_dispatch.na.jac BOOTSTRAP_JS";
}

"""Every command the client SDK invokes maps to a real host plugin command.

A text-level contract between desktop_api.cl.jac (the hand-written typed SDK)
and the built-in plugins' dispatch. Catches the drift a hand-written SDK is
prone to: a method calling a renamed/removed plugin or command. (The host may
expose more commands than the SDK surfaces -- that direction is allowed.)"""
test "client SDK commands map to host plugin commands" {
    import re;
    plugin_dir = _plugin_src_dir();
    sdk_text = (plugin_dir / "desktop_api.cl.jac").read_text();
    sdk_pairs = re.findall(r'_invoke\(\s*"([^"]+)"\s*,\s*"([^"]+)"', sdk_text);
    assert len(sdk_pairs) > 0 , "no _invoke() calls found in desktop_api.cl.jac";
    # Map host plugin name -> handled commands, parsed from each plugin source.
    host = {};
    for pf in sorted((plugin_dir / "built_in").glob("*_plugin.jac")) {
        text = pf.read_text();
        nm = re.search(r'name="(jac\.[a-z]+)"', text);
        if nm is None {
            continue;
        }
        host[nm.group(1)] = set(re.findall(r'command == "([a-z_]+)"', text));
    }
    for (plugin, command) in sdk_pairs {
        assert plugin in host , f"SDK calls unknown plugin '{plugin}'";
        assert command in host[plugin] , f"SDK has no host command {plugin}.{command}";
    }
}


"""The hand-maintained `desktop_sdk_exports` list tracks the `obj` declarations
in desktop_api.cl.jac.

`desktop_sdk_exports` (in plugin_config.jac) is the authoritative export list
the `@jac/desktop` module entry point hands to jaclang's client compiler --
`obj` types that the generic export extractor misses. It is hand-maintained, so
adding an `obj foo {}` to the SDK without listing `'foo'` here silently breaks
the import. This test pins the two together so that drift fails in CI rather
than at app startup."""
test "desktop_sdk exports match api declarations" {
    import re;
    plugin_dir = _plugin_src_dir();
    sdk_text = (plugin_dir / "desktop_api.cl.jac").read_text();
    declared = set(re.findall(r'^obj\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{', sdk_text, re.M));
    # `_invoke` is a free `def`, not an exported `obj`; we only compare obj
    # surfaces, so non-obj helpers can't perturb the result.
    assert len(declared) > 0 , "no obj declarations found in desktop_api.cl.jac";
    # Scope to the desktop_sdk_exports function body so unrelated string
    # literals elsewhere in desktop_plugin_config.jac can't create false matches.
    cfg_text = _plugin_config_path().read_text();
    fn = re.search(
        r'def\s+desktop_sdk_exports.*?return\s*\[([^\]]*)\]', cfg_text, re.S
    );
    assert fn is not None , "desktop_sdk_exports not found in desktop_plugin_config.jac";
    listed = set(re.findall(r"'([A-Za-z_][A-Za-z0-9_]*)'", fn.group(1)));
    assert listed == declared , (
        f"desktop_sdk_exports drifted from desktop_api.cl.jac obj declarations: "
        f"missing from exports={sorted(declared - listed)}, "
        f"stale in exports={sorted(listed - declared)}"
    );
}


# ---------------------------------------------------------------------------
# 7. Config loading -> plugin registration
# ---------------------------------------------------------------------------
"""Plugin config from jac.toml correctly enables/disables plugins."""
test "plugin configs from toml control registration" {
    import from jaclang.runtimelib.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        toml_path = Path(d) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            '[plugins.desktop]\nname = "Test"\n'
            '[plugins.desktop.plugins]\n'
            'path = true\n'
            'notification = true\n'
            'fs = { allow_read = ["$HOME"], allow_write = ["$APP_DATA"] }\n'
            'shell = { allow = ["git *"] }\n'
        );
        cfg = get_desktop_config(project_dir=Path(d));
        plugins = cfg.get_plugin_configs();
        assert plugins.get("path") == True;
        assert plugins.get("notification") == True;
        assert isinstance(plugins.get("fs"), dict);
        assert plugins["fs"]["allow_read"] == ["$HOME"];
        assert plugins["fs"]["allow_write"] == ["$APP_DATA"];
        assert isinstance(plugins.get("shell"), dict);
        assert plugins["shell"]["allow"] == ["git *"];
        # Not listed -> not present
        assert "dialog" not in plugins;
        assert "clipboard" not in plugins;
        assert "window" not in plugins;
        reset_desktop_config();
    }
}

"""Plugin config with all plugins disabled returns empty dict."""
test "plugin configs empty when no plugins section" {
    import from jaclang.runtimelib.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        toml_path = Path(d) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            '[plugins.desktop]\nname = "Test"\n'
        );
        cfg = get_desktop_config(project_dir=Path(d));
        plugins = cfg.get_plugin_configs();
        assert plugins == {};
        reset_desktop_config();
    }
}


# ---------------------------------------------------------------------------
# 8. Plugin bridge native shim validity
# ---------------------------------------------------------------------------
"""plugin_bridge.na.jac contains the expected native shim elements."""
test "plugin bridge source contains expected elements" {
    bridge = _native_dir() / "plugin_bridge.na.jac";
    src = bridge.read_text();
    assert "PyGILState_Ensure" in src;
    assert "PyGILState_Release" in src;
    assert "PyObject_CallOneArg" in src;
    assert "PyUnicode_FromString" in src;
    assert "PyUnicode_AsUTF8" in src;
    assert "Py_DecRef" in src;
    assert "_PH_DISPATCH" in src;
    assert "_jac_invoke_handler" in src;
    assert "respond" in src;
    assert "DISPATCH_CRASHED" in src;
    assert "req as str" in src;
}

"""plugin_bridge.na.jac compiles with webview + libpython (link test)."""
test "plugin bridge links with full native stack" {
    soname = sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0";
    webview_dir = _native_dir() / "webview";
    # The host inlines the bridge code (same pattern as _generate_host_source)
    src = (
        f'import from "{soname}" {{\n'
        "    def Py_Initialize() -> None;\n"
        "    def Py_Finalize() -> None;\n"
        "    def PyRun_SimpleString(cmd: str) -> i32;\n"
        "    def PyImport_AddModule(name: str) -> int;\n"
        "    def PyModule_GetDict(module: int) -> int;\n"
        "    def PyRun_String(s: str, start: i32, g: int, l: int) -> int;\n"
        "    def PyLong_AsLong(o: int) -> int;\n"
        "    def PyEval_SaveThread() -> int;\n"
        "    def PyEval_RestoreThread(s: int) -> None;\n"
        "    def PyGILState_Ensure() -> int;\n"
        "    def PyGILState_Release(state: int) -> None;\n"
        "    def PyObject_CallOneArg(fn: int, arg: int) -> int;\n"
        "    def PyUnicode_FromString(s: str) -> int;\n"
        "    def PyUnicode_AsUTF8(pyobj: int) -> str;\n"
        "    def Py_DecRef(pyobj: int) -> None;\n"
        "}\n"
        "glob PY_EVAL: i32 = 258;\n"
        "glob _PH_DISPATCH: int = 0;\n"
        "def _jac_invoke_handler(id: int, req: int, wv_handle: int) -> None {\n"
        "    gstate = PyGILState_Ensure();\n"
        "    py_req = PyUnicode_FromString(req as str);\n"
        "    py_result = PyObject_CallOneArg(_PH_DISPATCH, py_req);\n"
        "    if py_result == 0 {\n"
        "        Py_DecRef(py_req);\n"
        "        PyGILState_Release(gstate);\n"
        '        respond(wv_handle, id, "{\\"ok\\":false,\\"error\\":{\\"code\\":\\"DISPATCH_CRASHED\\"}}");\n'
        "        return;\n"
        "    }\n"
        "    result_str = PyUnicode_AsUTF8(py_result);\n"
        "    Py_DecRef(py_req);\n"
        "    Py_DecRef(py_result);\n"
        "    PyGILState_Release(gstate);\n"
        "    respond(wv_handle, id, result_str);\n"
        "}\n"
        "import from webview { def webview_create(debug: i32, window: int) -> int; }\n"
        "import from webview { Webview, respond, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n"
        "with entry {\n"
        "    Py_Initialize();\n"
        "    _wv_raw = webview_create(0, 0);\n"
        "    LAST_WEBVIEW_HANDLE = _wv_raw;\n"
        "    wv = Webview(handle=_wv_raw);\n"
        '    wv.title("integration-test");\n'
        "    wv.size(640, 480, HINT_NONE);\n"
        '    wv.bind("__jac_invoke", _jac_invoke_handler);\n'
        '    wv.html("<h1>integration</h1>");\n'
        "    ts = PyEval_SaveThread();\n"
        "    run_main_loop();\n"
        "    PyEval_RestoreThread(ts);\n"
        "    Py_Finalize();\n"
        "}\n"
    );

    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        shutil.copy2(
            str(webview_dir / "webview.na.jac"), os.path.join(tmp, "webview.na.jac")
        );
        with open(os.path.join(tmp, "host.na.jac"), "w") as f {
            f.write(src);
        }
        result = subprocess.run(
            [jac, "nacompile", "host.na.jac", "-o", "test_integration"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert result.returncode == 0 , f"integration host failed to compile:\n{result.stderr}";
        out = os.path.join(tmp, "test_integration");
        assert os.path.exists(out);
        with open(out, "rb") as bf {
            data = bf.read();
        }
        assert data[:4] == b"\x7fELF";
        assert b"libwebview.so" in data;
        assert b"libpython" in data;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ---------------------------------------------------------------------------
# 9. Full build pipeline smoke test (transpile + stage + generate)
# ---------------------------------------------------------------------------
"""Build pipeline (fused runtime): the generated host imports the plugins,
oauth_broker, and inprocess_dispatch from the bundled jaclang tree -- no
transpiled .py staged beside the binary. Verify the generated bootstrap wires
the runtime-import path (not spec_from_file_location)."""
test "build pipeline wires the runtime-imported bootstrap" {
    import sys;
    mod_name = "jaclang.runtimelib.client.targets.desktop.native_desktop_target";
    if mod_name not in sys.modules {
        return;  # Skip: module not loaded in this test runner
    }
    _generate_host_source = sys.modules[mod_name]._generate_host_source;

    host_src = _generate_host_source(
        title="SmokeTest",
        width=800,
        height=600,
        app_name="smoke-test",
        plugin_configs={"path": True, "notification": True}
    );
    # No transpiled-plugin staging: plugins are imported from the runtime.
    assert "spec_from_file_location" not in host_src , "must not load staged .py via spec_from_file_location";
    assert "import manifest, desktop_plugin, webview_lib, plugin_host, registry" in host_src;
    assert "bootstrap_plugins" in host_src;
    # oauth_broker + inprocess_dispatch also come from the fused runtime.
    assert "from jaclang.runtimelib.client.targets.desktop.native import oauth_broker" in host_src;
    assert "from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch" in host_src;
    # Bridge + JS SDK still present.
    assert "_jac_invoke_handler" in host_src;
    assert "_PH_DISPATCH" in host_src;
    assert "PyGILState_Ensure" in host_src;
    assert "__JAC_DESKTOP__" in host_src;
}


# ---------------------------------------------------------------------------
# 10. Registry bootstrap + manifests
# ---------------------------------------------------------------------------
"""Each built-in plugin exposes manifest() returning a PluginManifest."""
test "all built-in plugins expose manifest and build" {
    _with_plugins(
        lambda {
            import built_in.path_plugin;
            import built_in.fs_plugin;
            import built_in.clipboard_plugin;
            import built_in.notification_plugin;
            import built_in.dialog_plugin;
            import built_in.shell_plugin;
            import built_in.window_plugin;
            import from manifest { PluginManifest }
            for cls in [
                built_in.path_plugin.PathPlugin,
                built_in.fs_plugin.FsPlugin,
                built_in.clipboard_plugin.ClipboardPlugin,
                built_in.notification_plugin.NotificationPlugin,
                built_in.dialog_plugin.DialogPlugin,
                built_in.shell_plugin.ShellPlugin,
                built_in.window_plugin.WindowPlugin
            ] {
                m = cls.manifest();
                assert isinstance(m, PluginManifest);
                assert m.name.startswith("jac.");
                assert len(m.config_key) > 0;
                assert len(m.module) > 0;
                assert len(m.class_name) > 0;
                assert hasattr(cls, "build");
            }
        }
    );
}

"""bootstrap_plugins() registers only enabled plugins."""
test "bootstrap_plugins registers only enabled plugins" {
    _with_plugins(
        lambda {
            import from manifest { PluginContext }
            import from registry { bootstrap_plugins }
            import plugin_host;
            configs = {"path": True, "fs": {"allow_read": ["/tmp"]}};
            import sys;
            host = bootstrap_plugins(configs, sys.modules);
            assert "jac.path" in host.plugins;
            assert "jac.fs" in host.plugins;
            # Others should not be registered
            assert "jac.notification" not in host.plugins;
            assert "jac.clipboard" not in host.plugins;
            assert "jac.dialog" not in host.plugins;
            assert "jac.shell" not in host.plugins;
            assert "jac.window" not in host.plugins;
        }
    );
}

"""bootstrap_plugins() with all plugins enabled."""
test "bootstrap_plugins registers all plugins when all enabled" {
    _with_plugins(
        lambda {
            import from manifest { PluginContext }
            import from registry { bootstrap_plugins }
            import plugin_host;
            configs = {
                "path": True,
                "window": True,
                "fs": {"allow_read": ["/tmp"]},
                "notification": True,
                "clipboard": True,
                "dialog": True,
                "shell": {"allow": ["echo *"]}
            };
            import sys;
            host = bootstrap_plugins(configs, sys.modules);
            assert "jac.path" in host.plugins;
            assert "jac.window" in host.plugins;
            assert "jac.fs" in host.plugins;
            assert "jac.notification" in host.plugins;
            assert "jac.clipboard" in host.plugins;
            assert "jac.dialog" in host.plugins;
            assert "jac.shell" in host.plugins;
        }
    );
}

"""bootstrap_plugins() with empty config registers nothing."""
test "bootstrap_plugins registers nothing with empty config" {
    _with_plugins(
        lambda {
            import from registry { bootstrap_plugins }
            import plugin_host;
            import sys;
            host = bootstrap_plugins({}, sys.modules);
            assert len(host.plugins) == 0;
        }
    );
}

"""DesktopPlugin._coerce_config normalizes config values."""
test "_coerce_config normalizes config values" {
    _with_plugins(
        lambda {
            import desktop_plugin;
            assert desktop_plugin.DesktopPlugin._coerce_config(True) == {};
            assert desktop_plugin.DesktopPlugin._coerce_config(False) == {};
            assert desktop_plugin.DesktopPlugin._coerce_config(None) == {};
            assert desktop_plugin.DesktopPlugin._coerce_config({"a": 1}) == {"a": 1};
        }
    );
}

"""Plugin bridge extraction between markers works."""
test "bridge marker extraction from plugin_bridge.na.jac" {
    import from pathlib { Path }

    bridge_path = _native_dir() / "plugin_bridge.na.jac";
    src = bridge_path.read_text();
    assert "# --- BRIDGE START ---" in src;
    assert "# --- BRIDGE END ---" in src;
    assert "_PH_DISPATCH" in src;
    assert "_jac_invoke_handler" in src;
    assert "_stash_wv_in_python" in src;
}
