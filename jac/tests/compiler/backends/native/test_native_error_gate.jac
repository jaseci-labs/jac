"""Tests for the native error gate (issue #7239).

A native module that accumulates codegen-time errors (E5092 and
friends) must not publish any artifact: no llvm ir, no jit engine, no
python bytecode, and no .jir cache entry. Importing such a module must
fail loudly with the real diagnostics, and the check path must surface
the same errors `jac run` would (check/run parity).

Before the gate landed, the first compile printed the errors but cached
the poisoned artifact anyway, so every later run executed silently with
holes in the code (exit 0, zero diagnostics).
"""
import from jaclang.compiler.driver.ifacecache { artifact_cache_path }

import from tests.support {
    diagnostics_text,
    error_codes,
    kernel_check_file,
    kernel_compile_file,
    native_force_opts
}
import os;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }

def _bytecode(prog: JacProgram, target: str) -> any {
    return prog._get_compiler().get_bytecode(target, prog);
}

# `eval` of a runtime string can never be lowered on the na pathway: it
# would need an embedded interpreter inside the AOT-compiled binary. The
# E5092 is the MIR decision step's refusal and, crucially, is NOT caught
# by the up-front capability blacklist -- that makes it the exact "drift"
# class of error the gate exists for. (An earlier version leaned on
# for-loop tuple destructuring, but #7238 later lowered that construct
# natively -- exactly the kind of drift this test guards against. A
# fundamentally dynamic construct like `eval` is drift-proof.)
glob BAD_NA_SOURCE: str = (
         "def probe() -> None {\n"
         "    eval(\"1 + 1\");\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    probe();\n"
         "}\n"
     ),
     GOOD_NA_SOURCE: str = (
         "def answer() -> int {\n"
         "    return 42;\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    print(answer());\n"
         "}\n"
     );

"""Write a module source into a fresh temp dir; return its path."""
def write_module(name: str, source: str) -> str {
    tmpdir = tempfile.mkdtemp();
    src_path = os.path.join(tmpdir, name);
    with open(src_path, "w") as fh {
        fh.write(source);
    }
    return src_path;
}

"""Options that place a module in the native codespace and require it there,
so a refusal is an E5092 error rather than a demotion."""
def required_opts -> CompileOptions {
    return CompileOptions(force_codespace="native", native_required=True);
}

test "na codegen errors withhold the native artifact" {
    src = write_module("gate_bad.jac", BAD_NA_SOURCE);
    result = kernel_compile_file(src, required_opts(), ["bytecode", "mir"]);
    assert "E5092" in error_codes(result) , (
        f"Expected E5092 from native codegen, got: {diagnostics_text(result)}"
    );
    assert not any(unit.native_ir for unit in result.units) , (
        "a module with native codegen errors must not publish llvm ir"
    );
    assert not any(unit.native_object for unit in result.units) , (
        "a module with native codegen errors must not publish a native object"
    );
}

test "inferred module that cannot lower natively demotes to working bytecode" {
    # With the .na.jac marker retired, an importable module has no way to
    # *mandate* native: preference-driven inference demotes on lowering
    # failure and the server bytecode must be complete, never a poisoned
    # half-native artifact. (The loud error gate lives on the forced path --
    # see "na codegen errors withhold the native artifact".)
    src = write_module("gate_bad.jac", BAD_NA_SOURCE);
    bc = _bytecode(JacProgram(), src);
    assert bc is not None , (
        "an inferred module whose native codegen errors must demote to a "
        "complete server bytecode, not fail"
    );
}

test "import of a natively-unlowerable module demotes and succeeds" {
    # Marker-era pin was "import fails loudly": with placement inferred, the
    # import instead lands on the server fallback and must succeed.
    src = write_module("gate_bad_import.jac", BAD_NA_SOURCE);
    mod: any = JacRuntime.jac_import(
        target="gate_bad_import", base_path=os.path.dirname(src)
    );
    assert mod is not None , "demoted module must import cleanly";
}

test "check-path compile surfaces native codegen errors (check/run parity)" {
    src = write_module("gate_bad_check.jac", BAD_NA_SOURCE);
    opts = required_opts();
    opts.native_parity = True;
    result = kernel_check_file(src, opts);
    assert "E5092" in error_codes(result) , (
        f"`jac check` path must report the same native errors `jac run` "
        f"does, got: {diagnostics_text(result)}"
    );
    seen: set = set();
    for diag in result.errors {
        key = (diag.code, diag.span.line, diag.span.col, diag.message);
        assert key not in seen , f"duplicate diagnostic reported: {key}";
        seen.add(key);
    }
}

test "clean na module still publishes artifacts and caches" {
    src = write_module("gate_good.jac", GOOD_NA_SOURCE);
    result = kernel_compile_file(src, native_force_opts());
    assert result.ok() , f"unexpected errors: {diagnostics_text(result)}";
    assert result.unit(src).native_ir , "clean na module must still publish llvm ir";
    bc = _bytecode(JacProgram(), src);
    assert bc is not None , "clean na module must still produce bytecode";
    assert os.path.exists(artifact_cache_path(src, JacProgram())) , (
        "clean na module must still be written to the jir cache"
    );
}
