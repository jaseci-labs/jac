"""Own-typed fields extend the owned world into the heap (#7857 Phase B).

Storing an owned value into an `own`-typed field is a move within the owned
world, not a seal into managed storage: no E1402 under enforcement, the
source binding is consumed (E1301 on later reads), the parent frees the
field at its own drop, and an overwrite drops the old value first -- at the
same program points under every gc mode.

The fixture-plus-expected-codes cases for this rule live in the shared
`test_ownership_codes.jac` table; what stays here asserts something that
table cannot express.
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXDIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "fixtures", "nogc_ownfield"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _enforced_codes(name: str) -> list[str] {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        prog.compile(
            os.path.join(FIXDIR, name),
            options=CompileOptions(aot_mode=True, memory_profile="nogc")
        );
        codes = [
            a.code.code
            for a in (list(prog.errors_had) + list(prog.warnings_had))
            if a.code is not None
                and (a.code.code.startswith("E14") or a.code.code.startswith("E13"))
        ];
        codes.sort();
        return codes;
    } finally {
        pop_native_target(prev);
    }
}

def _run_mode(tmp: str, mode: str) -> str {
    out_bin = os.path.join(tmp, f"ofd_{mode}");
    res = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "build",
            "--native",
            os.path.join(FIXDIR, "own_field_drop_count.jac")
        ]
            + MODE_FLAGS[mode]
            + ["-o", out_bin],
        capture_output=True,
        text=True
    );
    assert res.returncode == 0 , f"{mode}: {res.stderr}";
    ran = subprocess.run([out_bin], capture_output=True, text=True);
    assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
    return ran.stdout;
}

test "own-field store is not a seal under enforcement" {
    codes = _enforced_codes("own_field_store_ok.jac");
    assert codes == [] , codes;
}

test "unannotated-field store still seals under enforcement (E1402)" {
    codes = _enforced_codes("managed_field_store_seals.jac");
    assert "E1402" in codes , codes;
}

test "own-field drops fire exactly once at identical points in all gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs = {m: _run_mode(tmp, m) for m in ("none", "rc", "cycles")};
        expected = "drop 0\nmid\n2\ndrop 2\nend\n";
        assert outs["none"] == expected , outs["none"];
        assert outs["rc"] == outs["none"] , f"rc diverged:\n{outs['rc']}";
        assert outs["cycles"] == outs["none"] , f"cycles diverged:\n{outs['cycles']}";
    }
}
