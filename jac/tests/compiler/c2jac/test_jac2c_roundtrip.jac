"""Round-trip conformance for the Emit leg (jac2c) of #7145.

Proves the C-codegen backend end to end: lift the `minilib` C fixture to Jac
(`c2jac`), re-emit it as C (`jac2c`), then compile *both* the original C and the
emitted C against a shared driver with the system C compiler and require the two
binaries to agree behaviorally. When no C compiler is present the structural
half still runs so the test stays meaningful in minimal environments.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob MINILIB: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures", "minilib"
     ),
     DRIVER: str = "#include <stdio.h>\n"
     "#include \"vec2.h\"\n"
     "int main(void) {\n"
     "    struct Vec2 a = {3, 4}, b = {1, 2};\n"
     "    struct Vec2 s = vec2_add(a, b);\n"
     "    printf(\"%d %d %d %d %d\\n\","
     " s.x, s.y, vec2_dot(a, b), vec2_len_sq(a), vec2_sum_to(5));\n"
     "    return 0;\n"
     "}\n";

def _emit_c(c_path: str) -> str {
    # c2jac then jac2c: lift the C to Jac, then re-emit that Jac as C source.
    lift_prog = JacProgram();
    lifted = lift_prog.compile(file_path=c_path);
    assert not lift_prog.errors_had , f"lift errors: {[
        str(e) for e in lift_prog.errors_had
    ]}";
    jac_src = lifted.unparse();

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
    return emitted.gen.c_src;
}

def _run(driver: str, lib_c: str, work: str, tag: str) -> str {
    # Compile `driver` + `lib_c` (each its own translation unit) and run.
    lib_path = os.path.join(work, f"{tag}.c");
    with open(lib_path, "w") as f {
        f.write(lib_c);
    }
    drv_path = os.path.join(work, f"driver_{tag}.c");
    with open(drv_path, "w") as f {
        f.write(driver);
    }
    binp = os.path.join(work, f"bin_{tag}");
    cc = shutil.which("cc") or shutil.which("gcc") or shutil.which("clang");
    subprocess.run([cc, drv_path, lib_path, "-I", work, "-o", binp], check=True);
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return proc.stdout.strip();
}

test "jac2c emits structurally faithful C for the minilib" {
    c_src = _emit_c(os.path.join(MINILIB, "vec2.c"));
    for needle in [
        "struct Vec2 {",
        "struct Vec2 vec2_add(struct Vec2 a, struct Vec2 b)",
        "int vec2_dot(struct Vec2 a, struct Vec2 b)",
        "int vec2_sum_to(int n)",
        "for (int i = 0; (i < n); i += 1)"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "c2jac -> jac2c round-trips to behaviorally-equivalent C" {
    if shutil.which("cc") is None
    and shutil.which("gcc") is None
    and shutil.which("clang") is None {
        return;
    }
    work = tempfile.mkdtemp();
    shutil.copy(os.path.join(MINILIB, "vec2.h"), os.path.join(work, "vec2.h"));

    with open(os.path.join(MINILIB, "vec2.c")) as f {
        orig_c = f.read();
    }
    emitted_c = _emit_c(os.path.join(MINILIB, "vec2.c"));

    ref = _run(DRIVER, orig_c, work, "orig");
    got = _run(DRIVER, emitted_c, work, "gen");
    assert ref == "4 6 11 25 10" , f"reference C changed: {ref!r}";
    assert got == ref , f"emitted C diverged: {got!r} != {ref!r}";
}
