"""Degenerate import targets must degrade to diagnostics, never crash.

Parse-error recovery deliberately keeps an `Import` node whose module path
is empty (e.g. a file containing only the bare token `import`, so the
parser reports `E0002: Missing ';'` but compilation continues). Every
later pass funnels that node's module specifier through `resolve_module`,
so the resolver must be *total* over degenerate specifiers: an empty
module name cannot resolve to any artifact, and reaching it must yield a
clean "unresolved" outcome instead of an `IndexError` that surfaces to the
user as `Error checking 'x.jac': list index out of range`.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.modresolver { resolve_module }
import from jaclang.compiler.driver.program { JacProgram }


test "bare import yields a syntax diagnostic, never an internal error" {
    tmp_dir = tempfile.mkdtemp(prefix="jac_bare_import_");
    try {
        target = Path(tmp_dir) / "repro.jac";
        target.write_text("import");
        prog = JacProgram();
        internal_error: str | None = None;
        try {
            prog.compile(
                file_path=str(target),
                options=CompileOptions(no_cgen=True, force_target_program=True)
            );
        } except Exception as e {
            internal_error = f"{type(e).__name__}: {e}";
        }
        assert internal_error is None , (
            "compiling a bare `import` must degrade to diagnostics, not raise "
            "an internal exception; got: "
            + str(internal_error)
        );
        messages = [str(e) for e in prog.errors_had];
        assert len(messages) > 0 , (
            "a bare `import` must produce at least one diagnostic"
        );
        assert any("Missing ';'" in m for m in messages) , (
            "expected the parser's E0002 Missing ';' diagnostic for a bare "
            "`import`; got: "
            + repr(messages)
        );
        joined = " ".join(messages);
        assert "IndexError" not in joined and "list index out of range" not in joined , (
            "no internal resolver error may leak into diagnostics; got: "
            + repr(messages)
        );
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "resolve_module stays total for an empty module specifier" {
    tmp_dir = tempfile.mkdtemp(prefix="jac_empty_resolve_");
    try {
        base_file = Path(tmp_dir) / "base.jac";
        base_file.write_text("");
        result = resolve_module("", str(base_file));
        resolved_path = result[0];
        if resolved_path {
            assert not os.path.exists(resolved_path) , (
                "an empty module name must never resolve to an existing "
                f"artifact; got: {resolved_path}"
            );
        }
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}
