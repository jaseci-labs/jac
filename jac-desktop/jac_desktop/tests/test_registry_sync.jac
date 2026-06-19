"""Sync tests for the dual plugin registry.

jac-desktop keeps TWO parallel plugin lists that cannot be unified:

  - `BUILTIN_PLUGINS` in plugin/registry.jac — the ordered list of plugin
    manifests (which plugins to construct + register, gated by config).
  - `_plugin_mods` in targets/impl/native_desktop_target.impl.jac — the module
    load order for the embedded CPython importlib bootstrap, which runs
    *before* registry is importable.

The embedded bootstrap loads infra modules (manifest, desktop_plugin,
webview_lib, plugin_host), every `built_in.*` plugin module, then `registry`
last. Every `built_in.*` entry here MUST match the `module` field of a
BUILTIN_PLUGINS entry, or the bootstrap either (a) crashes at runtime with
ModuleNotFoundError when registry imports a plugin that was never loaded, or
(b) loads a module that is never registered.

These tests pin that invariant so adding plugin #8 fails loudly if only one
side is updated. See the long comments in registry.jac and
native_desktop_target.impl.jac for why the two lists exist separately.
"""
import ast;
import os;
import from pathlib { Path }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
"""Locate the jac_desktop package root from this test file.

Mirrors the helper in test_integration.jac: walks up from this file until it
finds plugin/plugin_host.jac."""
def _pkg_root -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(6) {
        if (probe / "plugin" / "plugin_host.jac").exists() {
            return probe;
        }
        probe = probe.parent;
    }
    raise RuntimeError("Could not find jac_desktop package root from " + str(here));
}

"""Path to native_desktop_target.impl.jac — the file that owns _plugin_mods."""
def _impl_path -> Path {
    return _pkg_root() / "targets" / "impl" / "native_desktop_target.impl.jac";
}

"""Path to the plugin source directory (where each module's .jac file lives)."""
def _plugin_src_dir -> Path {
    return _pkg_root() / "plugin";
}

"""Extract the `_plugin_mods` literal list from the impl source.

`_plugin_mods` is a local variable inside `_generate_host_source`, so it cannot
be imported — we parse the source instead. `ast.literal_eval` is safe because
the list contains only string literals. Returns the list of module names in
load order."""
def _extract_plugin_mods -> list[str] {
    src = _impl_path().read_text();
    marker = "_plugin_mods = [";
    start = src.find(marker);
    assert start != -1 , "_plugin_mods list not found in native_desktop_target.impl.jac";
    bracket = src.find("[", start);
    # The list is the first ']'-terminated block after the opening bracket.
    end_sep = "];";
    close = src.find(end_sep, bracket);
    assert close != -1 , "_plugin_mods list is not terminated by the list-close marker";
    # ast.literal_eval returns any; cast to list[str] so callers get typed
    # module names (the list holds only string literals, so this is safe).
    return ast.literal_eval(src[bracket:close + 1]) as list[str];
}

"""Run a function with the plugin source directory on sys.path, restoring after.

Needed so `import from registry` resolves the live BUILTIN_PLUGINS (registry
imports every built_in.* plugin at module scope)."""
def _with_plugins(fn: callable) {
    import sys;
    saved = sys.path[:];
    sys.path.insert(0, str(_plugin_src_dir()));
    try {
        fn();
    } finally {
        sys.path[:] = saved;
    }
}


# ---------------------------------------------------------------------------
# 1. Core parity: _plugin_mods built_in.*  ==  BUILTIN_PLUGINS .module
# ---------------------------------------------------------------------------
"""Every built_in.* module in the bootstrap is a registered plugin and vice
versa. This is THE test that catches 'added a plugin, forgot the bootstrap'
(and the reverse) when plugin #8 lands."""
test "_plugin_mods built_in.* entries match BUILTIN_PLUGINS modules" {
    _with_plugins(
        lambda {
            import from registry { BUILTIN_PLUGINS }
            mods = _extract_plugin_mods();
            bootstrap_builtin = sorted(
                [
                    m
                    for m in mods
                    if m.startswith("built_in.")
                ]
            );
            registry_mods = sorted([m.module for m in BUILTIN_PLUGINS]);
            missing_in_bootstrap = [
                m
                for m in registry_mods
                if m not in bootstrap_builtin
            ];
            missing_in_registry = [
                m
                for m in bootstrap_builtin
                if m not in registry_mods
            ];
            assert missing_in_bootstrap == [] , (
                "registry.jac BUILTIN_PLUGINS has plugin modules with no matching "
                "entry in _plugin_mods (native_desktop_target.impl.jac). The "
                "embedded CPython bootstrap will NOT load them, so "
                "bootstrap_plugins() crashes with ModuleNotFoundError. Add each "
                "to _plugin_mods (before 'registry'): " + ", ".join(
                    missing_in_bootstrap
                )
            );
            assert missing_in_registry == [] , (
                "_plugin_mods (native_desktop_target.impl.jac) loads built_in.* "
                "modules that are NOT in BUILTIN_PLUGINS (registry.jac). They get "
                "imported but never registered. Remove them from _plugin_mods or "
                "add them to BUILTIN_PLUGINS: " + ", ".join(missing_in_registry)
            );
        }
    );
}


# ---------------------------------------------------------------------------
# 2. Required infra modules are present
# ---------------------------------------------------------------------------
"""_plugin_mods must load the non-plugin infra modules registry/plugins import.

These are intentionally absent from BUILTIN_PLUGINS (they are not plugins),
which is exactly why the bootstrap list cannot be derived from the registry.
If one is dropped, the bootstrap crashes on the first bare import."""
test "_plugin_mods includes all required infra modules" {
    mods = _extract_plugin_mods();
    for infra in ["manifest", "desktop_plugin", "webview_lib", "plugin_host"] {
        assert infra in mods , (
            "infra module '" + infra + "' missing from _plugin_mods; " + "registry/plugins import it, so the bootstrap will crash without it"
        );
    }
}


# ---------------------------------------------------------------------------
# 3. registry must be loaded last (load-order invariant)
# ---------------------------------------------------------------------------
"""registry is loaded last. registry.jac imports every built_in.* plugin at
module scope; in the embedded CPython `built_in` is a bare ModuleType, so
`from built_in.x import Y` only resolves once built_in.x is already in
sys.modules. Loading registry before the built_in modules raises
ModuleNotFoundError and silently kills dispatch for the whole app."""
test "registry is the last entry in _plugin_mods" {
    mods = _extract_plugin_mods();
    assert len(mods) > 0 , "_plugin_mods is empty";
    assert mods[-1] == "registry" , (
        "'registry' must be loaded LAST in _plugin_mods (it imports every " + "built_in.* plugin at module scope); got last entry: " + str(
            mods[-1]
        )
    );
}


# ---------------------------------------------------------------------------
# 4. Every module string maps to a real .jac source file
# ---------------------------------------------------------------------------
"""Catches a typo'd module string in _plugin_mods before it crashes the
embedded bootstrap with FileNotFoundError at runtime. Every entry (infra,
built_in.*, registry) must resolve to a .jac file under plugin/."""
test "every _plugin_mods entry maps to a .jac source file" {
    mods = _extract_plugin_mods();
    src_dir = _plugin_src_dir();
    for m in mods {
        jac_path = src_dir / (m.replace(".", os.sep) + ".jac");
        assert jac_path.exists() , (
            "_plugin_mods lists '" + m + "' but no source file exists at " + str(
                jac_path
            ) + " — the bootstrap will crash with FileNotFoundError"
        );
    }
}


# ---------------------------------------------------------------------------
# 5. No duplicate entries
# ---------------------------------------------------------------------------
"""Duplicate module loads silently waste work and, for built_in.*, can shadow
the setattr() that attaches the child to the bare built_in ModuleType."""
test "_plugin_mods has no duplicate entries" {
    # Jac comprehensions don't support tuple unpacking (no `for k, v in ...`),
    # so detect duplicates with an explicit two-list sweep.
    mods = _extract_plugin_mods();
    seen: list[str] = [];
    dups: list[str] = [];
    for m in mods {
        if m in seen {
            if m not in dups {
                dups.append(m);
            }
        } else {
            seen.append(m);
        }
    }
    assert dups == [] , "duplicate entries in _plugin_mods: " + ", ".join(dups);
}
