# Vec->list conformance: prove the na and CPython runtimes return observationally
# identical list[V] values for the Vec return tag (TAG_LIST_BIT | value_tag),
# against the SAME libjac_bridge_list.so.
#
# na side: synthesize Jac source from the .so metadata, append a probe that prints
# one canonical line per element (in order -- lists are ordered), nacompile, run,
# and diff against the CPython loader. Gated on the LLVM shim; skips without it.
#
# Width note: na's `int` is 64-bit SIGNED, so a `u64` with the high bit set is
# carried as its two's-complement signed image (u64::MAX -> -1). The CPython side
# is normalized to that image (`_norm`) before comparison, so the SAME 64 bits are
# what cross on both runtimes.
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


glob REPO = Path(__file__).resolve().parents[4],
     JAC = REPO / "jac",
     SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_list.so",
     SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so",
     SEED = 3,
     # (method, element-kind). Order matters: lists are compared in element order.
     METHODS = [
         ("counts", "int"),
         ("big", "uint"),
         ("labels", "str"),
         ("flags", "bool"),
         ("none", "int"),
         ("checked", "uint")
     ];


def _norm(v: int) -> int {
    return v - 0x10000000000000000 if v >= 0x8000000000000000 else v;
}


def _canon(v: object, kind: str) -> str {
    if kind == "bool" {
        return "1" if v else "0";
    }
    if kind == "str" {
        return str(v);
    }
    return str(_norm(v));
}


def cpython_side -> list {
    mod = load_bridge(str(SO));
    store = mod.Store(SEED);
    lines = [];
    for case in METHODS {
        method = case[0];
        kind = case[1];
        lines.append("# " + method);
        fn = getattr(store, method);
        for x in fn() {
            lines.append(_canon(x, kind));
        }
    }
    store.close();
    return lines;
}


def _jac_str(s: str) -> str {
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
}


def na_side -> list {
    meta = parse(read_jac_bridge_section(str(SO)));
    src = render_na_source(meta, SO.name).source;

    probe = ["\nwith entry {", f"    s = Store({SEED});"];
    for case in METHODS {
        method = case[0];
        kind = case[1];
        # A distinct local per method: na types a local by its first assignment,
        # so reusing one name across list[int]/list[str]/list[bool] would clash.
        probe.append("    print(" + _jac_str("# " + method) + ");");
        probe.append(f"    _lst_{method} = s.{method}();");
        probe.append(f"    for x in _lst_{method} {{");
        if kind == "bool" {
            probe.append("        print(\"1\" if x else \"0\");");
        } else {
            probe.append("        print(str(x));");
        }
        probe.append("    }");
    }
    probe.append("    s.close();");
    probe.append("}");
    src = src + "\n".join(probe);

    td = tempfile.mkdtemp();
    try {
        jac_file = Path(td) / "list_conf.na.jac";
        jac_file.write_text(src);
        binp = Path(td) / "list_conf";
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
        if not binp.exists() {
            raise RuntimeError(
                "nacompile failed:\n" + r.stdout[-2000:] + r.stderr[-2000:]
            );
        }
        runenv = dict(os.environ);
        runenv["LD_LIBRARY_PATH"] = str(SO.parent);
        run = subprocess.run(
            [str(binp)], capture_output=True, text=True, timeout=60, env=runenv
        );
        if run.returncode != 0 {
            raise RuntimeError(
                f"binary exited {run.returncode}:\n{run.stdout}\n{run.stderr}"
            );
        }
        return run.stdout.splitlines();
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "list na cpython conformance" {
    if not SO.is_file() {
        return;
    }
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")) {
        return;
    }
    assert cpython_side() == na_side();
}
