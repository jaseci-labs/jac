"""R3: renderer dispatch tests.

`__jacJsx` (client_runtime_core) does not call `React.createElement`
directly; it delegates to a renderer object the active platform registers at
bundle init time. React Native is the production consumer of this seam
(core + client_runtime_native), so these tests compile that pairing and
verify:

1. The compiled jac-client runtime exposes the dispatch surface
   (`__jacRegisterRenderer`, `__jacGetRenderer`, `__jacNativeCreate`).
2. `__jacJsx`'s compiled body is a one-line delegation, not DOM-aware logic.
3. Behavior: registering a stub renderer routes JSX calls to that stub
   unchanged (no tag rewrites, no child wrapping).
4. HMR: re-evaluating the runtime module body must not clobber a renderer
   that has already been registered on globalThis.

The substring assertions follow the same pattern as `test_client_bundle.jac`.
The behavioral assertions execute the compiled JS under Node so we catch
regressions the source-level checks miss.
"""

import os;
import shutil;
import subprocess;
import importlib;
import pytest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

"""Locate the core client runtime directory."""
def _jac_client_plugin_dir -> str {
    plugin = importlib.import_module("jaclang.runtimelib.client");
    paths = `list(getattr(plugin, "__path__", []) or []);
    if not paths {
        pytest.fail("jaclang.runtimelib.client has no __path__");
    }
    return paths[0];
}

"""Strip trailing ``export { ... };`` from jac2js output."""
def _strip_esm_export_line(js_code: str) -> str {
    lines = js_code.split("\n");
    filtered: list[str] = [];
    for line in lines {
        trimmed = line.strip();
        if trimmed.startswith("export {") or trimmed.startswith("export{") {
            continue;
        }
        filtered.append(line);
    }
    return "\n".join(filtered);
}

"""Drop inlined core import after D9 bundle stitch."""
def _strip_runtime_core_import(js_code: str) -> str {
    lines = js_code.split("\n");
    filtered: list[str] = [];
    for line in lines {
        if "client_runtime_core" in line and "import " in line {
            continue;
        }
        filtered.append(line);
    }
    return "\n".join(filtered);
}

glob _compiled_runtime_js: (str | None) = None;

"""Compile D9 runtime (core + native platform) the same way ``compile_runtime_utils`` does.

Memoized in a module glob: five tests share this and each ``jac jac2js``
invocation is a full CLI startup, so the cache saves 8 subprocess spawns
per run.
"""
def _compile_runtime_to_js -> str {
    global _compiled_runtime_js;
    if _compiled_runtime_js is not None {
        return _compiled_runtime_js;
    }
    plugin_dir = _jac_client_plugin_dir();
    core_src = os.path.join(plugin_dir, "client_runtime_core.cl.jac");
    native_src = os.path.join(plugin_dir, "client_runtime_native.cl.jac");
    if not os.path.isfile(core_src) or not os.path.isfile(native_src) {
        pytest.skip(
            "client_runtime_core.cl.jac or client_runtime_native.cl.jac not found"
        );
    }
    jac_bin = shutil.which("jac");
    if not jac_bin {
        pytest.skip("`jac` CLI not on PATH");
    }
    core_result = subprocess.run(
        [jac_bin, "jac2js", core_src], capture_output=True, text=True, check=False
    );
    if core_result.returncode != 0 {
        pytest.skip(f"jac2js core failed: {core_result.stderr}");
    }
    native_result = subprocess.run(
        [jac_bin, "jac2js", native_src], capture_output=True, text=True, check=False
    );
    if native_result.returncode != 0 {
        pytest.skip(f"jac2js native failed: {native_result.stderr}");
    }
    _compiled_runtime_js = (
        _strip_esm_export_line(core_result.stdout) + "\n" + _strip_runtime_core_import(
            _strip_esm_export_line(native_result.stdout)
        )
    );
    return _compiled_runtime_js;
}

"""Find the index just past the ``}`` that closes the ``{`` at ``open_pos``.

A raw brace counter is fooled by ``{``/``}`` that appear inside string
literals, template expressions (``${...}``), or comments -- any of which a
future refactor of the renderer functions could introduce. This scanner
tracks those contexts so only structural braces are counted, which keeps
``_slice_renderer_fns`` honest as the compiled output evolves.

Returns -1 if no matching brace is found.
"""
def _find_matching_brace(js: str, open_pos: int) -> int {
    # ``open_pos`` must point at the opening ``{``. Each stack frame is a
    # (mode, depth) pair; ``depth`` is only meaningful for ``"code"`` frames
    # and tracks nested braces within that frame.
    stack: list[tuple[str, int]] = [("code", 1)];
    i = open_pos + 1;
    n = len(js);
    while i < n and len(stack) > 0 {
        mode = stack[-1][0];
        ch = js[i];
        nxt = js[i + 1] if i + 1 < n else "";
        if mode == "code" {
            if ch == "{" {
                (m, d) = stack.pop();
                stack.append((m, d + 1));
                i += 1;
            } elif ch == "}" {
                (m, d) = stack.pop();
                d -= 1;
                if d == 0 {
                    if len(stack) == 0 {
                        return i + 1;
                    }
                    # Closing an interpolation frame -- resume the template
                    # literal that pushed it.
                } else {
                    stack.append((m, d));
                }
                i += 1;
            } elif ch == "'" {
                stack.append(("sq", 0));
                i += 1;
            } elif ch == "\"" {
                stack.append(("dq", 0));
                i += 1;
            } elif ch == "`" {
                stack.append(("tpl", 0));
                i += 1;
            } elif ch == "/" and nxt == "/" {
                stack.append(("line_c", 0));
                i += 2;
            } elif ch == "/" and nxt == "*" {
                stack.append(("block_c", 0));
                i += 2;
            } else {
                i += 1;
            }
        } elif mode == "sq" {
            if ch == "\\" {
                i += 2;
            } elif ch == "'" {
                stack.pop();
                i += 1;
            } else {
                i += 1;
            }
        } elif mode == "dq" {
            if ch == "\\" {
                i += 2;
            } elif ch == "\"" {
                stack.pop();
                i += 1;
            } else {
                i += 1;
            }
        } elif mode == "tpl" {
            if ch == "\\" {
                i += 2;
            } elif ch == "`" {
                stack.pop();
                i += 1;
            } elif ch == "$" and nxt == "{" {
                stack.append(("code", 1));
                i += 2;
            } else {
                i += 1;
            }
        } elif mode == "line_c" {
            if ch == "\n" {
                stack.pop();
            }
            i += 1;
        } elif mode == "block_c" {
            if ch == "*" and nxt == "/" {
                stack.pop();
                i += 2;
            } else {
                i += 1;
            }
        } else {
            i += 1;
        }
    }
    return -1;
}

"""Extract just the renderer-dispatch functions from compiled JS.

The full runtime imports `react`, `react-native`, etc., which Node can't
resolve in a bare TemporaryDirectory. The dispatch layer doesn't depend on
any of those at definition time (the platform create function only touches
its imports when actually invoked, and these harnesses always install a
stub renderer first), so slicing the function bodies out is enough to
exercise the contract.
"""
def _slice_renderer_fns(js: str) -> str {
    parts = "";
    for marker in [
        "function __jacJsx",
        "function __jacRegisterRenderer",
        "function __jacGetRenderer"
    ] {
        start = js.find(marker);
        assert start >= 0 , f"compiled runtime missing {marker}";
        # Walk parens first so default-arg literals like `{}` inside the
        # parameter list don't trip the brace counter; the function body
        # begins at the first `{` *after* the closing `)` of the params.
        paren_depth = 0;
        j = js.find("(", start);
        assert j >= 0;
        while j < len(js) {
            if js[j] == "(" {
                paren_depth += 1;
            } elif js[j] == ")" {
                paren_depth -= 1;
                if paren_depth == 0 {
                    break;
                }
            }
            j += 1;
        }
        brace_open = js.find("{", j);
        assert brace_open >= 0 , f"no body brace for {marker}";
        end = _find_matching_brace(js, brace_open);
        assert end > 0 , f"unterminated function body for {marker}";
        parts += js[start:end] + "\n\n";
    }
    return parts;
}

"""Run a JS snippet under Node and return (rc, stdout, stderr)."""
def _run_node(snippet: str) -> tuple[int, str, str] {
    node_bin = shutil.which("node");
    if not node_bin {
        pytest.skip("node not on PATH");
    }
    with TemporaryDirectory() as tmp_name {
        tmp = str(tmp_name);
        harness_path = Path(tmp) / "harness.mjs";
        harness_path.write_text(snippet);
        result = subprocess.run(
            [node_bin, str(harness_path)], capture_output=True, text=True, check=False
        );
        return (result.returncode, result.stdout, result.stderr);
    }
}

test "_find_matching_brace ignores braces inside strings and comments" {
    # Braces inside single-quoted, double-quoted, and template literals, as
    # well as line and block comments, must not affect the depth counter.
    cases: list[tuple[str, int, int]] = [
        # Plain body -- no strings involved.
        ("{ return 1; }", 0, len("{ return 1; }")),
        # Single-quoted string containing a close brace.
        ("{ x = '}'; }", 0, len("{ x = '}'; }")),
        # Double-quoted string containing open and close braces.
        ("{ x = \"{}\"; }", 0, len("{ x = \"{}\"; }")),
        # Template literal containing a literal close brace.
        ("{ x = `}`; }", 0, len("{ x = `}`; }")),
        # Template expression whose interpolation contains nested braces.
        ("{ x = `${ { a: 1 } }`; }", 0, len("{ x = `${ { a: 1 } }`; }")),
        # Line comment containing a close brace.
        (
            "{ // } not a real brace\n return 1; }",
            0,
            len("{ // } not a real brace\n return 1; }")
        ),
        # Block comment containing braces.
        ("{ /* { } */ return 1; }", 0, len("{ /* { } */ return 1; }")),
        # Escaped quote inside a string does not terminate the string early.
        ("{ x = '\\'}'; }", 0, len("{ x = '\\'}'; }")),
        # Nested structural braces with a brace inside a string at the inner level.
        (
            "{ if (x) { y = '{'; } return y; }",
            0,
            len("{ if (x) { y = '{'; } return y; }")
        ),

    ];
    for (src, open_pos, expected) in cases {
        got = _find_matching_brace(src, open_pos);
        assert got == expected , (f"expected {expected} for {repr(src)}, got {got}");
    }
    # Unbalanced input returns -1.
    assert _find_matching_brace("{ { ", 0) == -1;
}

test "compiled runtime exposes renderer dispatch surface" {
    js = _compile_runtime_to_js();
    assert "function __jacJsx" in js , "__jacJsx must still be emitted";
    assert "function __jacRegisterRenderer" in js , (
        "R3: __jacRegisterRenderer missing from compiled runtime"
    );
    assert "function __jacGetRenderer" in js , (
        "R3: __jacGetRenderer missing from compiled runtime"
    );
    assert "function __jacNativeCreate" in js , (
        "R3: native renderer body should live in __jacNativeCreate"
    );
    assert "globalThis.__jacRenderer__" in js , (
        "R3: renderer must be stored on globalThis to survive HMR reload"
    );
}

test "__jacJsx body is a thin dispatcher" {
    js = _compile_runtime_to_js();
    start = js.find("function __jacJsx");
    assert start >= 0;
    brace = js.find("{", start);
    end = js.find("\n}", brace);
    body = js[brace + 1:end];
    assert "__jacGetRenderer__" in body or "__jacGetRenderer" in body , (
        "R3: __jacJsx must delegate via the platform renderer hook"
    );
    assert "React.createElement" not in body , (
        "R3 regression: __jacJsx must not call React.createElement directly. "
        "DOM-specific logic belongs in __jacWebCreate."
    );
    assert "Fragment" not in body , (
        "R3 regression: Fragment fallback must live in the web renderer, "
        "not in __jacJsx itself."
    );
}

test "registered renderer receives (tag, props, children) verbatim" {
    js = _compile_runtime_to_js();
    snippet = _slice_renderer_fns(js);
    harness = (
        "globalThis.React = { createElement: () => ({}), Fragment: 'F' };\n" + snippet + "globalThis.__jacGetRenderer__ = () => globalThis.__jacRenderer__;\n" + "const calls = [];\n" + "__jacRegisterRenderer({ create: (tag, props, children) => {\n" + "  calls.push({tag, props, children}); return 'stub-element';\n" + "}});\n" + "const out = __jacJsx('button', {id: 'x'}, ['hi']);\n" + "if (out !== 'stub-element') {\n" + "  console.error('expected stub return, got', out); process.exit(1);\n" + "}\n" + "if (calls.length !== 1) {\n" + "  console.error('expected 1 call, got', calls.length); process.exit(1);\n" + "}\n" + "const c = calls[0];\n" + "if (c.tag !== 'button') { console.error('tag', c); process.exit(1); }\n" + "if (c.props.id !== 'x') { console.error('props', c); process.exit(1); }\n" + "if (!Array.isArray(c.children) || c.children[0] !== 'hi') {\n" + "  console.error('children mismatch', c); process.exit(1);\n" + "}\n" + "console.log('OK');\n"
    );
    (rc, out, err) = _run_node(harness);
    assert rc == 0 , f"dispatch harness failed: stdout={out} stderr={err}";
    assert "OK" in out;
}

test "native renderer auto-installs when nothing is registered" {
    # The native platform's __jacGetRenderer lazily installs its own create
    # function; invoking it needs the full RN module graph, so this checks
    # the wiring under Node with the create fn stubbed at install time.
    js = _compile_runtime_to_js();
    snippet = _slice_renderer_fns(js);
    harness = (
        "const __jacNativeCreate = (tag, props, children) => ['native', tag];\n" + snippet + "globalThis.__jacGetRenderer__ = __jacGetRenderer;\n" + "const out = __jacJsx('div', {className: 'x'}, []);\n" + "if (!globalThis.__jacRenderer__) {\n" + "  console.error('native renderer did not auto-install'); process.exit(1);\n" + "}\n" + "if (!Array.isArray(out) || out[1] !== 'div') {\n" + "  console.error('tag not forwarded to installed create', out);\n" + "  process.exit(1);\n" + "}\n" + "console.log('OK');\n"
    );
    (rc, out, err) = _run_node(harness);
    assert rc == 0 , f"auto-install harness failed: stdout={out} stderr={err}";
    assert "OK" in out;
}

test "registration survives runtime re-evaluation (HMR sim)" {
    js = _compile_runtime_to_js();
    snippet = _slice_renderer_fns(js);
    module_iife = "(() => {\n" + snippet + "return __jacJsx;\n})()";
    harness = (
        "globalThis.React = { createElement: () => ({}), Fragment: 'F' };\n" + "globalThis.__jacGetRenderer__ = () => globalThis.__jacRenderer__;\n" + "const firstJsx = " + module_iife + ";\n" + "firstJsx;\n" + "globalThis.__jacRenderer__ = { create: (t,p,c) => 'native:' + t };\n" + "const reloadedJsx = " + module_iife + ";\n" + "const out = reloadedJsx('div', {}, []);\n" + "if (out !== 'native:div') {\n" + "  console.error('HMR clobbered renderer, got', out); process.exit(1);\n" + "}\n" + "console.log('OK');\n"
    );
    (rc, out, err) = _run_node(harness);
    assert rc == 0 , f"HMR harness failed: stdout={out} stderr={err}";
    assert "OK" in out;
}
