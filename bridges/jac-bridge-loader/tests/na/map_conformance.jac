# HashMap->dict conformance: prove the na and CPython runtimes return
# observationally identical dict[str, V] values for the map return tag
# (TAG_MAP_BIT | value_tag), against the SAME libjac_bridge_map.so.
#
# na side: synthesize Jac source from the .so metadata, append a probe that prints
# one "method|key|value" line per entry, nacompile, run, and diff against the
# CPython loader. Dict iteration order is unspecified on both runtimes, so BOTH
# sides sort their line lists before comparison. Gated on the LLVM shim.
#
# Width note: na's `int` is 64-bit SIGNED; a `u64` with the high bit set crosses as
# its two's-complement signed image (u64::MAX -> -1). The CPython side normalizes to
# that image (`_norm`) before comparison.
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
     SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_map.so",
     SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so",
     SEED = 3,
     # (method, value-kind). Compared as a sorted set of key=value lines.
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
        fn = getattr(store, method);
        d = fn();
        for k in d {
            lines.append(method + "|" + k + "|" + _canon(d[k], kind));
        }
    }
    store.close();
    return sorted(lines);
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
        # so reusing one name across dict[str,int]/dict[str,str]/dict[str,bool]
        # would clash.
        _dv = f"_map_{method}";
        probe.append(f"    {_dv} = s.{method}();");
        probe.append(f"    for k in {_dv} {{");
        if kind == "bool" {
            probe.append(
                "        print(" + _jac_str(method + "|") + " + k + \"|\" + (\"1\" if " + _dv + "[k] else \"0\"));"
            );
        } elif kind == "str" {
            probe.append(
                "        print(" + _jac_str(method + "|") + " + k + \"|\" + " + _dv + "[k]);"
            );
        } else {
            probe.append(
                "        print(" + _jac_str(method + "|") + " + k + \"|\" + str(" + _dv + "[k]));"
            );
        }
        probe.append("    }");
    }
    probe.append("    s.close();");
    probe.append("}");
    src = src + "\n".join(probe);

    td = tempfile.mkdtemp();
    try {
        jac_file = Path(td) / "map_conf.na.jac";
        jac_file.write_text(src);
        binp = Path(td) / "map_conf";
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
        return sorted(run.stdout.splitlines());
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "map na cpython conformance" {
    if not SO.is_file() {
        return;
    }
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")) {
        return;
    }
    assert cpython_side() == na_side();
}
