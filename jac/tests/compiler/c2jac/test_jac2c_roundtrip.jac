"""Behavioral jac2c round-trip for C-shaped lift output (minilib).

Lift behavioral proof for the full breadth suite lives in
`test_c2jac_lift_oracle.jac` (cc of original C vs jac run of lifted Jac),
because idiomatic lifts (`list[...]`, comprehensions, …) sit outside jac2c's
emittable subset. This file covers the complementary POD half: c2jac stamps
`@__jac_value__` on lifted structs, jac2c re-emits them as by-value C structs,
and the linked binary must agree with the original `.c` under `cc`.
"""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.c.c_gen_pass { emit_translation_units }
import from tests.compiler.c2jac.lift_oracle { run_c }
import from tests.compiler.c2jac.emit_support { cc, link_and_run }

glob MINILIB: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures", "minilib"
     ),
     _MINILIB_DRIVER: str = "#include <stdio.h>\n"
     "#include \"vec2.h\"\n"
     "int main(void) {\n"
     "    struct Vec2 a = {3, 4}, b = {1, 2};\n"
     "    printf(\"%d\\n\", vec2_dot(a, b) + vec2_len_sq(a) + vec2_sum_to(5));\n"
     "    return 0;\n"
     "}\n",
     _MINILIB_RUN: str = "\n\ndef run_minilib -> int {\n"
     "    a: Vec2 = Vec2(x=3, y=4);\n"
     "    b: Vec2 = Vec2(x=1, y=2);\n"
     "    return vec2_dot(a, b) + vec2_len_sq(a) + vec2_sum_to(5);\n"
     "}\n";


def _lift_emit_units(c_path: str, include_dirs: list[str], run_src: str) -> list {
    # c2jac then jac2c: lift the C to Jac, append a `run_*` entry, emit TUs.
    lift_prog = JacProgram();
    lifted = lift_prog.compile(file_path=c_path);
    assert not lift_prog.errors_had , f"lift errors: {[
        str(e) for e in lift_prog.errors_had
    ]}";
    jac_src = lifted.unparse() + run_src;

    out_dir = tempfile.mkdtemp();
    jac_path = os.path.join(out_dir, "vec2.jac");
    with open(jac_path, "w") as f {
        f.write(jac_src);
    }
    emit_prog = JacProgram();
    emitted = emit_prog.compile(file_path=jac_path);
    assert not emit_prog.errors_had , f"emit errors: {[
        str(e) for e in emit_prog.errors_had
    ]}";
    return emit_translation_units(jac_path, emitted, emit_prog);
}


def _main_tu_src(units: list, stem: str = "vec2.jac") -> str {
    for (path, src) in units {
        if path.endswith(stem) {
            return src;
        }
    }
    return "";
}


test "jac2c emits structurally faithful C for the minilib" {
    units = _lift_emit_units(
        os.path.join(MINILIB, "vec2.c"), [MINILIB], _MINILIB_RUN
    );
    c_src = _main_tu_src(units);
    for needle in [
        "struct Vec2 {",
        "struct Vec2 vec2_add(struct Vec2 a, struct Vec2 b)",
        "int vec2_dot(struct Vec2 a, struct Vec2 b)",
        "int vec2_sum_to(int n)",
        "for (int i = 0; (i < n); i += 1)",
        "(struct Vec2){"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
    assert "Vec2()" not in c_src , f"value ctor still emits free call:\n{c_src}";
    assert "Vec2__new" not in c_src , f"value arch leaked into RC ctor:\n{c_src}";
}


test "jac2c linked minilib agrees with original C under cc" {
    if cc() is None {
        return;
    }
    c_path = os.path.join(MINILIB, "vec2.c");
    c_out = run_c([c_path], [MINILIB], _MINILIB_DRIVER);
    units = _lift_emit_units(c_path, [MINILIB], _MINILIB_RUN);
    j_out = link_and_run(units, ["run_minilib"]);
    assert j_out is not None , "jac2c binary produced no int line";
    assert c_out == j_out , f"oracle mismatch: cc={c_out!r} jac2c={j_out!r}";
}
