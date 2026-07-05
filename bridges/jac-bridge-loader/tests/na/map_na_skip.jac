# na-gate proof for the map return tag (M6.2): the native backend cannot yet
# build or return a dict, so the synthesizer SKIPS every HashMap<String, V>
# method (asserted at the source level in ../test_na_codegen_map.jac). This test
# proves the stronger runtime property: the ctor-only source that remains after
# those skips actually nacompiles and runs — no dangling reference to a skipped
# shim, no ICE — against the real libjac_bridge_map.so. Gated on the LLVM shim;
# skips without it.
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


glob REPO = Path(__file__).resolve().parents[4],
     JAC = REPO / "jac",
     SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_map.so",
     SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so";


test "na skips every map method yet the ctor-only module compiles + runs" {
    if not SO.is_file() {
        return;
    }
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")) {
        return;
    }

    meta = parse(read_jac_bridge_section(str(SO)));
    res = render_na_source(meta, SO.name);

    # Every HashMap<String, V> method is skipped with the na dict-return reason.
    skipped = {s.item for s in res.skips};
    for name in [
        "Store.counts",
        "Store.big",
        "Store.labels",
        "Store.flags",
        "Store.none",
        "Store.checked"
    ] {
        assert name in skipped , f"{name} not skipped: {skipped}";
    }

    # The ctor survives, so the module is non-empty and must nacompile cleanly.
    src = res.source + "\nwith entry {\n    s = Store(3);\n    s.close();\n    print(\"ok\");\n}\n";

    td = tempfile.mkdtemp();
    try {
        jac_file = Path(td) / "map_skip.na.jac";
        jac_file.write_text(src);
        binp = Path(td) / "map_skip";
        env = dict(os.environ);
        env["JAC_LLVM_SHIM"] = str(SHIM);
        env["PYTHONPATH"] = str(JAC);
        r = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                str(jac_file),
                "-o",
                str(binp)
            ],
            cwd=str(JAC),
            env=env,
            capture_output=True,
            text=True,
            timeout=600
        );
        assert binp.exists() , "nacompile failed:\n" + r.stdout[-2000:] + r.stderr[-2000:];
        runenv = dict(os.environ);
        runenv["LD_LIBRARY_PATH"] = str(SO.parent);
        run = subprocess.run(
            [str(binp)], capture_output=True, text=True, timeout=60, env=runenv
        );
        assert run.returncode == 0 , f"binary exited {run.returncode}:\n{run.stdout}\n{run.stderr}";
        assert "ok" in run.stdout;
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}
