"""P4 phase-exit: pcpp preprocessing + CLI flag surface + real-small-lib round-trip.

Exercises `transpile_c_file` (the path the `jac c2jac` CLI drives) and
`preprocess_c` (§8.1) against a self-contained C "mini lib" under
fixtures/minilib/ that uses an include guard, local `#include`, object- and
function-like macros, and `#ifdef` conditional compilation.
"""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.support { parse_errors as _parses }
import from jaclang.compiler.c2jac.driver { transpile_c_file, transpile_c_str }
import from jaclang.compiler.c2jac.preprocess { preprocess_c }

glob MINILIB = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures", "minilib"
     ),
     VEC2_C = os.path.join(MINILIB, "vec2.c");

# ---------------------------------------------------------------------------- #
# preprocess_c (§8.1) — the pcpp front-end in isolation                         #
# ---------------------------------------------------------------------------- #
test "preprocess_c expands an object-like macro" {
    out = preprocess_c("#define N 3\nint a[N];\n", "m.c");
    assert "int a[3];" in out , f"macro not expanded:\n{out}";
    assert "#define" not in out , f"directive survived:\n{out}";
}

test "preprocess_c honors -D NAME=VALUE from the caller" {
    out = preprocess_c("int x = SCALE;\n", "m.c", defines=["SCALE=42"]);
    assert "int x = 42;" in out , f"-D substitution missing:\n{out}";
}

test "preprocess_c -U cancels an earlier -D" {
    src = "#ifdef DBG\nint dbg;\n#endif\nint y;\n";
    out = preprocess_c(src, "m.c", defines=["DBG"], undefines=["DBG"]);
    assert "int dbg;" not in out , f"-U did not cancel -D:\n{out}";
    assert "int y;" in out;
}

test "preprocess_c emits no #line markers (coords stay aligned)" {
    # #line directives would remap pycparser coords out of the text we transpile;
    # the front-end suppresses them (see preprocess.jac docstring).
    out = preprocess_c("#define Z 1\nint q = Z;\n", "m.c");
    assert "#line" not in out , f"unexpected #line marker:\n{out}";
}

test "preprocess_c hard-fails on an unresolved #include (§8.2)" {
    failed = False;
    try {
        preprocess_c("#include <does_not_exist.h>\nint x;\n", "m.c", nostdinc=True);
    } except ValueError as e {
        failed = True;
        assert "not found" in str(e);
    }
    assert failed , "Unresolved #include must raise (preprocessing is a hard failure)";
}

# ---------------------------------------------------------------------------- #
# transpile_c_file — real small lib round-trip (the CLI's path)                 #
# ---------------------------------------------------------------------------- #
test "minilib vec2.c transpiles end-to-end (include guard + local include)" {
    (jac_str, tags) = transpile_c_file(VEC2_C);
    # All four public functions survive the local `#include "vec2.h"`.
    for fn in ["vec2_add", "vec2_dot", "vec2_len_sq", "vec2_sum_to"] {
        assert f"def {fn}" in jac_str , f"missing {fn}:\n{jac_str}";
    }
    # The struct lowers to an obj; no preprocessor directive leaks through.
    assert "class Vec2" in jac_str or "obj Vec2" in jac_str , f"struct not lowered:\n{jac_str}";
    assert "#include" not in jac_str , f"directive leaked:\n{jac_str}";
}

test "minilib: function-like macro SQR is expanded, not emitted" {
    (jac_str, tags) = transpile_c_file(VEC2_C);
    # SQR(v.x) → (v.x * v.x); the macro name must not survive.
    assert "SQR" not in jac_str , f"macro name leaked:\n{jac_str}";
    assert "v.x * v.x" in jac_str , f"SQR not expanded:\n{jac_str}";
}

test "minilib emitted Jac recompiles cleanly (round-trip)" {
    (jac_str, tags) = transpile_c_file(VEC2_C);
    errs = _parses(jac_str);
    assert len(errs) == 0 , f"emitted Jac must recompile, got: {errs}\n{jac_str}";
}

test "minilib: #ifdef block is excluded by default" {
    (jac_str, tags) = transpile_c_file(VEC2_C);
    assert "vec2_version" not in jac_str , f"VEC2_EXTRA block leaked without -D:\n{jac_str}";
}

test "minilib: -DVEC2_EXTRA includes the conditional function" {
    (jac_str, tags) = transpile_c_file(VEC2_C, defines=["VEC2_EXTRA"]);
    assert "def vec2_version" in jac_str , f"-D did not enable the #ifdef block:\n{jac_str}";
    assert len(_parses(jac_str)) == 0 , f"conditional build must recompile:\n{jac_str}";
}

test "minilib is fully Tier-A (no best-effort sites, no header)" {
    (jac_str, tags) = transpile_c_file(VEC2_C);
    assert tags.tier_b_entries() == [] , f"unexpected Tier-B: {[
        t.reason for t in tags.tier_b_entries()
    ]}";
    assert not jac_str.startswith("#") , f"unexpected header on Tier-A lib:\n{jac_str[:120]}";
}
