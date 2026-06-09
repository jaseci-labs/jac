"""Tests for the ink_compile module (bundle_patch.py and compile.py)."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import pytest
from jac_super.ink_compile.bundle_patch import (
    _count_braces,
    _extract_brace_block,
    consolidate_bundle_imports,
    fix_broken_nullish_or,
    fix_double_escaped_unicode,
    fix_missing_loop_close,
    hoist_jac_runtime,
)
from jac_super.ink_compile.compile import (
    _FETCH_TRANSPORT_HELPER,
    _apply_ai_tui_module_patches,
    _finalize_esm_exports,
    _inject_runtime_imports,
    _remove_register_client_module,
    _replace_python_os_import,
    _strip_inlined_jac_runtime,
    _strip_shimmed_react_imports,
)

# ---------------------------------------------------------------------------
# _extract_brace_block
#
# Signature: _extract_brace_block(code, start) -> (body, end)
#   - `start` is the index AFTER the opening `{` (code[start-1] must be `{`)
#   - Returns `body` = code[start:i] (between braces, exclusive of both)
#   - Returns `end` = i + 1 (position after the closing `}`)
# ---------------------------------------------------------------------------


class TestExtractBraceBlock:
    def test_simple_block(self):
        code = "{ return 42; }"
        body, end = _extract_brace_block(code, 1)
        # Body is between the braces: " return 42; "
        assert "return 42;" in body
        assert "{" not in body
        assert "}" not in body
        assert end == len(code)

    def test_nested_braces(self):
        code = "{ { a: 1 } { b: 2 } }"
        body, end = _extract_brace_block(code, 1)
        assert "{ a: 1 }" in body
        assert "{ b: 2 }" in body
        assert end == len(code)

    def test_empty_block(self):
        code = "{}"
        body, end = _extract_brace_block(code, 1)
        assert body == ""
        assert end == 2

    def test_string_with_braces(self):
        code = '{ foo("{hello}") } extra'
        body, end = _extract_brace_block(code, 1)
        assert "{hello}" in body
        assert "extra" not in body
        assert end > len(body)

    def test_string_with_escaped_quote(self):
        code = '{ foo("he\\"llo") } extra'
        body, end = _extract_brace_block(code, 1)
        assert '\\"llo' in body

    def test_single_quoted_string_with_braces(self):
        code = "{ foo('{hello}') } extra"
        body, end = _extract_brace_block(code, 1)
        assert "'{hello}'" in body

    # -- Comment handling (uncommitted change) --

    def test_line_comment_skipped(self):
        code = "{ // this is a { comment\n  return 42;\n} extra"
        body, end = _extract_brace_block(code, 1)
        assert "return 42;" in body
        # The { in the comment should NOT have incremented depth
        # so the block is extracted completely
        assert "extra" not in body

    def test_line_comment_at_end_of_file(self):
        code = "{ // comment with no newline"
        body, end = _extract_brace_block(code, 1)
        # Unterminated — returns all remaining code
        assert "comment" in body

    def test_block_comment_skipped(self):
        code = "{ /* { nested brace } */ return 42; } extra"
        body, end = _extract_brace_block(code, 1)
        assert "return 42;" in body

    def test_block_comment_unterminated(self):
        code = "{ /* unterminated comment"
        body, end = _extract_brace_block(code, 1)
        assert "/*" in body

    # -- Template literal handling (uncommitted change) --

    def test_template_literal_skipped(self):
        code = "{ foo(`hello {world}`) } extra"
        body, end = _extract_brace_block(code, 1)
        assert "`hello {world}`" in body
        assert "extra" not in body

    def test_template_literal_with_backslash(self):
        code = "{ foo(`he\\`llo`) } extra"
        body, end = _extract_brace_block(code, 1)
        assert "`he\\`llo`" in body

    def test_template_literal_at_start(self):
        code = "{`{nested}`}"
        body, end = _extract_brace_block(code, 1)
        assert "`{nested}`" in body
        assert end == len(code)

    def test_template_literal_with_dollar_brace(self):
        """Simplified handling — ${} braces NOT tracked (known limitation)."""
        code = "{ `hello ${x + (y * z)} world` }"
        body, end = _extract_brace_block(code, 1)
        # With no ${} tracking, inner braces may affect depth.
        # This test documents the known limitation — it should not crash.
        assert "`" in body

    # -- Realistic JS blocks --

    def test_js_object_literal(self):
        code = '{\n  key: "value",\n  nested: { a: 1 }\n}'
        body, end = _extract_brace_block(code, 1)
        assert "key:" in body
        assert "nested:" in body
        assert end == len(code)

    def test_js_condition_block(self):
        code = "{\n  if ((x instanceof Error)) {}\n} extra"
        body, end = _extract_brace_block(code, 1)
        assert "instanceof Error" in body
        assert "extra" not in body


# ---------------------------------------------------------------------------
# fix_broken_nullish_or
#
# Regex: (\w+(?:\[\w+\])?\s*\?\?\s*""\s*)\|\|\s*""
# Replaces:  X ?? "" || ""  →  X ?? ""
# Capture group includes trailing \s* whitespace.
# Bracket access pattern is [\w+] (no quotes), i.e. foo[key] not foo["key"].
# ---------------------------------------------------------------------------


class TestFixBrokenNullishOr:
    def test_basic(self):
        code = 'let x = foo ?? "" || "";'
        result = fix_broken_nullish_or(code)
        # Capture group \1 includes trailing space before ||
        assert 'let x = foo ?? "" ;' in result or 'let x = foo ?? "";' in result
        assert '|| ""' not in result

    def test_with_bracket_access(self):
        # Bracket access pattern: [\w+] (no quotes around key)
        code = 'let x = data[key] ?? "" || "";'
        result = fix_broken_nullish_or(code)
        assert '|| ""' not in result
        assert "data[key]" in result

    def test_quoted_bracket_access_not_matched(self):
        """data[\"key\"] uses quoted keys — not matched by [\\w+] pattern."""
        code = 'let x = data["key"] ?? "" || "";'
        result = fix_broken_nullish_or(code)
        # Regex doesn't match quoted keys — code is unchanged
        assert result == code

    def test_no_match(self):
        code = 'let x = foo ?? "";'
        result = fix_broken_nullish_or(code)
        assert result == code

    def test_multiple_occurrences(self):
        code = 'a ?? "" || ""; b ?? "" || "";'
        result = fix_broken_nullish_or(code)
        assert '|| ""' not in result

    def test_realistic_jac_output(self):
        code = 'let v = ev ?? "" || "";'
        result = fix_broken_nullish_or(code)
        assert '|| ""' not in result


# ---------------------------------------------------------------------------
# fix_double_escaped_unicode
# ---------------------------------------------------------------------------


class TestFixDoubleEscapedUnicode:
    def test_basic_unicode(self):
        code = '"hello \\\\u0041 world"'
        result = fix_double_escaped_unicode(code)
        assert "\\\\u0041" not in result
        assert "\\u0041" in result

    def test_single_quoted_string(self):
        code = "'hello \\\\u0041 world'"
        result = fix_double_escaped_unicode(code)
        assert "\\\\u0041" not in result

    def test_no_double_unicode(self):
        code = '"hello \\u0041 world"'
        result = fix_double_escaped_unicode(code)
        assert result == code

    def test_multiple_in_one_string(self):
        code = '"\\\\u0041 \\\\u0042"'
        result = fix_double_escaped_unicode(code)
        assert result.count("\\\\u") == 0
        assert result.count("\\u") == 2

    def test_ignores_outside_strings(self):
        code = "const x = \\\\u0041;"
        result = fix_double_escaped_unicode(code)
        assert "\\\\u0041" in result  # Outside strings, no fix


# ---------------------------------------------------------------------------
# fix_missing_loop_close
# ---------------------------------------------------------------------------


class TestFixMissingLoopClose:
    def test_normal_for_loop_unchanged(self):
        code = "for (let i = 0; i < n; i++) {\n  console.log(i);\n}"
        result = fix_missing_loop_close(code)
        assert result.strip() == code.strip()

    def test_early_return_inserts_close(self):
        # Input missing its closing brace (the bug this fixes)
        code = "for (let e of events) {\n    if (e.id === 0) continue;\n    return e;\n"
        result = fix_missing_loop_close(code)
        # Should insert a } before the return
        assert result.count("{") == result.count("}")
        # The return is still in the output
        assert "return" in result

    def test_no_changes_when_no_early_return(self):
        code = "for (let e of events) {\n  process(e);\n}"
        result = fix_missing_loop_close(code)
        assert "{" in result
        assert "}" in result


# ---------------------------------------------------------------------------
# _count_braces
# ---------------------------------------------------------------------------


class TestCountBraces:
    def test_no_braces(self):
        assert _count_braces("hello world") == 0

    def test_open_brace(self):
        assert _count_braces("{") == 1

    def test_close_brace(self):
        assert _count_braces("}") == -1

    def test_braces_in_string_ignored(self):
        assert _count_braces('"{"') == 0

    def test_braces_in_single_quotes_ignored(self):
        assert _count_braces("'{'") == 0


# ---------------------------------------------------------------------------
# consolidate_bundle_imports
# ---------------------------------------------------------------------------


class TestConsolidateBundleImports:
    def test_merges_duplicate_imports(self):
        code = (
            'import { Box } from "ink";\nimport { Text } from "ink";\nconsole.log(1);\n'
        )
        result = consolidate_bundle_imports(code)
        assert result.count('from "ink"') == 1
        assert "Box" in result
        assert "Text" in result

    def test_preserves_non_import_lines(self):
        code = 'import { Box } from "ink";\nconsole.log(1);\n'
        result = consolidate_bundle_imports(code)
        assert "console.log(1)" in result


# ---------------------------------------------------------------------------
# hoist_jac_runtime
# ---------------------------------------------------------------------------


class TestHoistJacRuntime:
    def test_no_runtime_unchanged(self):
        code = "console.log(1);"
        result, runtime = hoist_jac_runtime(code)
        assert result == code
        assert runtime is None

    def test_hoists_runtime_block(self):
        code = (
            "const _jac = {\n"
            "  exc: { Exception: class {} },\n"
            "  builtin: {}\n"
            "};\n"
            "console.log(1);\n"
        )
        result, runtime = hoist_jac_runtime(code)
        assert runtime is not None
        assert "exc" in runtime
        assert "export { _jac }" in runtime
        assert "const _jac" not in result


# ---------------------------------------------------------------------------
# _strip_inlined_jac_runtime
# ---------------------------------------------------------------------------


class TestStripInlinedJacRuntime:
    def test_strips_runtime_section(self):
        code = (
            "// Imported .jac module: @jac/runtime\n"
            "// runtime code here\n"
            "// Imported .jac module: other\n"
            "real code\n"
        )
        result = _strip_inlined_jac_runtime(code)
        assert "@jac/runtime" not in result
        assert "real code" in result

    def test_no_runtime_unchanged(self):
        code = "real code\n"
        result = _strip_inlined_jac_runtime(code)
        assert result.strip() == code.strip()


# ---------------------------------------------------------------------------
# _remove_register_client_module
# ---------------------------------------------------------------------------


class TestRemoveRegisterClientModule:
    def test_removes_register_call(self):
        code = "__jacRegisterClientModule(something);\nreal code\n"
        result = _remove_register_client_module(code)
        assert "__jacRegisterClientModule" not in result
        assert "real code" in result


# ---------------------------------------------------------------------------
# _replace_python_os_import
# ---------------------------------------------------------------------------


class TestReplacePythonOsImport:
    def test_replaces_os_environ_import(self):
        code = "import { environ } from \"os\";\nconsole.log(environ.get('KEY'));\n"
        result = _replace_python_os_import(code)
        assert "const environ = { ...process.env };" in result
        assert 'from "os"' not in result

    def test_no_os_import_unchanged(self):
        code = "console.log(1);"
        result = _replace_python_os_import(code)
        assert result == code


# ---------------------------------------------------------------------------
# _strip_shimmed_react_imports
# ---------------------------------------------------------------------------


class TestStripShimmedReactImports:
    def test_removes_shimmed_imports(self):
        code = 'import { useState, useEffect } from "react";\nconsole.log(1);\n'
        result = _strip_shimmed_react_imports(code)
        assert "useState" not in result
        assert "useEffect" not in result

    def test_keeps_non_shimmed_react_imports(self):
        code = 'import { createPortal } from "react";\nconsole.log(1);\n'
        result = _strip_shimmed_react_imports(code)
        assert "createPortal" in result

    def test_default_plus_named_import(self):
        code = (
            'import React, { useState, createPortal } from "react";\nconsole.log(1);\n'
        )
        result = _strip_shimmed_react_imports(code)
        assert "React" in result
        assert "createPortal" in result
        assert "useState" not in result


# ---------------------------------------------------------------------------
# _finalize_esm_exports
# ---------------------------------------------------------------------------


class TestFinalizeEsmExports:
    def test_adds_export_statement(self):
        code = "function app() {}\n"
        result = _finalize_esm_exports(code, ["app"])
        assert "export { app }" in result

    def test_no_duplicate_export(self):
        code = "function app() {}\nexport { app };\n"
        result = _finalize_esm_exports(code, ["app"])
        assert result.count("export { app }") == 1


# ---------------------------------------------------------------------------
# _inject_runtime_imports
# ---------------------------------------------------------------------------


class TestInjectRuntimeImports:
    def test_injects_header(self):
        code = "function app() {}"
        result = _inject_runtime_imports(code, with_jac_builtin=True)
        assert "./runtime_shim.mjs" in result
        assert "./jac_runtime_shim.mjs" in result
        assert "./jac_builtin_runtime.mjs" in result

    def test_replaces_at_jac_runtime(self):
        code = 'import { useState } from "@jac/runtime";'
        result = _inject_runtime_imports(code)
        assert '@jac/runtime"' not in result
        assert "./jac_runtime_shim.mjs" in result

    def test_no_double_injection(self):
        code = 'import { useState } from "./jac_runtime_shim.mjs";\nfunction app() {}'
        result = _inject_runtime_imports(code, with_jac_builtin=False)
        assert result.count("./runtime_shim.mjs") == 1


# ---------------------------------------------------------------------------
# _apply_ai_tui_module_patches  (the key uncommitted change)
# ---------------------------------------------------------------------------


class TestApplyAiTuiModulePatches:
    def _make_temp_module(self, content: str) -> Path:
        """Write content to a temp file and return its Path."""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".mjs", delete=False, encoding="utf-8"
        ) as tmp:
            tmp.write(content)
            return Path(tmp.name)

    def test_injects_fetch_transport_helper(self):
        content = "let TUI_COMMANDS = [];\nfunction app() {}\n"
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            assert "function isFetchTransportError" in result
            assert "AbortError" in result
            assert "TimeoutError" in result
        finally:
            path.unlink()

    def test_does_not_double_inject_helper(self):
        content = _FETCH_TRANSPORT_HELPER + "let TUI_COMMANDS = [];\n"
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            # Should appear exactly once
            assert result.count("function isFetchTransportError") == 1
        finally:
            path.unlink()

    def test_widens_catch_guard_basic(self):
        content = (
            "function agent_fetch() {\n"
            "  try {\n"
            "    return fetch();\n"
            "  } catch (__jac_e) {\n"
            "    if ((__jac_e instanceof _jac.exc.Exception)) {} else {\n"
            "      throw __jac_e;\n"
            "    }\n"
            "  }\n"
            "}\n"
        )
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            assert "isFetchTransportError(__jac_e)" in result
            assert (
                "(__jac_e instanceof _jac.exc.Exception) || isFetchTransportError(__jac_e)"
            ) in result
        finally:
            path.unlink()

    def test_does_not_double_widen(self):
        content = (
            "function agent_fetch() {\n"
            "  try {\n"
            "    return fetch();\n"
            "  } catch (__jac_e) {\n"
            "    if ((__jac_e instanceof _jac.exc.Exception) || isFetchTransportError(__jac_e)) {} else {\n"
            "      throw __jac_e;\n"
            "    }\n"
            "  }\n"
            "}\n"
        )
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            # isFetchTransportError should still appear exactly once per guard
            double_patched = (
                "|| isFetchTransportError(__jac_e)) || isFetchTransportError(__jac_e))"
            )
            assert double_patched not in result
        finally:
            path.unlink()

    def test_widens_multiple_catch_blocks(self):
        content = (
            "let TUI_COMMANDS = [];\n"
            "function agent_fetch() {\n"
            "  try {\n"
            "    return fetch();\n"
            "  } catch (__jac_e) {\n"
            "    if ((__jac_e instanceof _jac.exc.Exception)) {} else {\n"
            "      throw __jac_e;\n"
            "    }\n"
            "  }\n"
            "}\n"
            "function streamLoop() {\n"
            "  try {\n"
            "    return fetch();\n"
            "  } catch (__jac_e) {\n"
            "    if ((__jac_e instanceof _jac.exc.Exception)) {} else {\n"
            "      throw __jac_e;\n"
            "    }\n"
            "  }\n"
            "}\n"
        )
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            # Both catch blocks should be widened (2 occurrences of the
            # isFetchTransportError in catch guards, plus 1 in the injected
            # helper function body — the helper body uses the name in checks
            # like `if (msg.includes(...))` but not as `isFetchTransportError(__jac_e)`).
            # The helper function definition counts as 1 occurrence, and each
            # widened catch guard adds 1.
            assert result.count("isFetchTransportError(__jac_e))") >= 2
        finally:
            path.unlink()

    def test_stream_loop_unmount_tolerance(self):
        content = (
            "let TUI_COMMANDS = [];\n"
            "    } catch (__jac_e) {\n"
            "      if ((__jac_e instanceof _jac.exc.Exception) || isFetchTransportError(__jac_e)) {} else {\n"
            "        throw __jac_e;\n"
            "      }\n"
            "    }\n"
            "    if (_unmounted) {\n"
        )
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            # Should now include _unmounted in the guard
            assert "|| _unmounted || isFetchTransportError(__jac_e)" in result
        finally:
            path.unlink()

    def test_no_helper_without_tui_commands_marker(self):
        content = (
            "function app() {\n"
            "  try {\n"
            "    return fetch();\n"
            "  } catch (__jac_e) {\n"
            "    if ((__jac_e instanceof _jac.exc.Exception)) {} else {\n"
            "      throw __jac_e;\n"
            "    }\n"
            "  }\n"
            "}\n"
        )
        path = self._make_temp_module(content)
        try:
            _apply_ai_tui_module_patches(path)
            result = path.read_text(encoding="utf-8")
            # Helper not injected (no TUI_COMMANDS marker), but catch guards still widened
            assert "function isFetchTransportError" not in result
            assert "isFetchTransportError(__jac_e)" in result
        finally:
            path.unlink()

    def test_helper_fragment_validates_structure(self):
        """Verify the injected helper string contains expected checks (it's JS,
        not Python — the helper runs in Node.js at runtime)."""
        helper = _FETCH_TRANSPORT_HELPER

        # Must be a function declaration
        assert helper.startswith("function isFetchTransportError")

        # Must check for falsy err
        assert "if (!err) return false" in helper

        # Must check known error names
        assert '"AbortError"' in helper
        assert '"TimeoutError"' in helper
        assert '"TypeError"' in helper

        # Must check message substrings
        assert '"fetch failed"' in helper
        assert '"econnreset"' in helper
        assert '"network"' in helper

        # Must return false at the end (default: not a transport error)
        assert "return false" in helper


# ---------------------------------------------------------------------------
# Integration / smoke test
# ---------------------------------------------------------------------------


class TestCompileIntegration:
    def test_compile_runtime_cl_jac_succeeds(self):
        """Verify the full compile pipeline works on the actual runtime.cl.jac."""
        from jac_super.ink_compile.compile import compile_ink_app

        repo_root = Path(__file__).resolve().parent.parent
        entry = repo_root / "jac_super" / "ai_tui_ink" / "runtime.cl.jac"
        if not entry.is_file():
            pytest.skip("runtime.cl.jac not found at expected path")

        with tempfile.TemporaryDirectory() as tmpdir:
            out = Path(tmpdir) / "tui"
            entry_name = compile_ink_app(entry, out, ai_tui_patches=True)

            # Basic output validation
            assert entry_name in ("app",)
            assert (out / "module.mjs").is_file()
            assert (out / "runner.mjs").is_file()
            assert (out / "runtime_shim.mjs").is_file()
            assert (out / "jac_runtime_shim.mjs").is_file()
            assert (out / "package.json").is_file()

            # Verify module.mjs content
            module = (out / "module.mjs").read_text(encoding="utf-8")
            assert len(module) > 1000  # should be substantial
            assert "isFetchTransportError" in module
            assert "streamLoop" in module or "agent_fetch" in module

            # Verify package.json is valid
            pkg = json.loads((out / "package.json").read_text(encoding="utf-8"))
            assert pkg["type"] == "module"
            assert "ink" in pkg["dependencies"]
            assert "react" in pkg["dependencies"]

    def test_compile_without_ai_tui_patches(self):
        """Verify compilation works without AI TUI patches."""
        from jac_super.ink_compile.compile import compile_ink_app

        repo_root = Path(__file__).resolve().parent.parent
        entry = repo_root / "jac_super" / "ai_tui_ink" / "runtime.cl.jac"
        if not entry.is_file():
            pytest.skip("runtime.cl.jac not found at expected path")

        with tempfile.TemporaryDirectory() as tmpdir:
            out = Path(tmpdir) / "tui"
            compile_ink_app(entry, out, ai_tui_patches=False)

            module = (out / "module.mjs").read_text(encoding="utf-8")
            # isFetchTransportError should NOT be injected without patches
            assert "function isFetchTransportError" not in module
