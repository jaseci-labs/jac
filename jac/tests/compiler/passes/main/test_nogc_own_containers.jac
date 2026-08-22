"""Owned containers of archetype elements (#7857 Phase B).

Fresh archetype instantiations move into container grow methods and list
literals under nogc enforcement; the container owns its elements, stamps
the element-drop slot with the element type's drop, and frees each element
exactly once at container drop -- at the same points in every gc mode.
Named archetype bindings stay fenced (E1406): there is no copy-in idiom
for archetypes, so only fresh values may enter.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob OWNFIELD_DIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "main", "fixtures", "nogc_ownfield"
     ),
     CONTAINER_DIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "main", "fixtures", "nogc_containers"
     ),
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

def _enforced_codes(path: str) -> list[str] {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        prog.compile(
            path,
            options=CompileOptions(
                aot_mode=True, type_check=True, na_gc_mode="none", nogc_enforce_all=True
            )
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
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
}

test "fresh archetype elements pass the container fence" {
    codes = _enforced_codes(os.path.join(OWNFIELD_DIR, "own_list_elems.jac"));
    assert codes == [] , codes;
}

test "named archetype bindings stay fenced (E1406)" {
    codes = _enforced_codes(os.path.join(CONTAINER_DIR, "append_obj_named.jac"));
    assert "E1406" in codes , codes;
}

test "element drops fire exactly once at identical points in all gc modes" {
    fixture = os.path.join(OWNFIELD_DIR, "own_list_elems.jac");
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"olc_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "nacompile", fixture]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
        }
        for k in range(3) {
            assert outs["none"].count(f"drop {k}") == 1 , outs["none"];
        }
        assert "1\n3\n" in outs["none"] , outs["none"];
        assert outs["none"].endswith("end\n") , outs["none"];
        assert outs["rc"] == outs["none"] , f"rc diverged:\n{outs['rc']}";
        assert outs["cycles"] == outs["none"] , f"cycles diverged:\n{outs['cycles']}";
    }
}
