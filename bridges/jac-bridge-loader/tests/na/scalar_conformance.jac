# Scalar-integer conformance: prove the na and CPython runtimes are
# observationally identical for the integer boundary tags (TAG_INT / TAG_UINT),
# against the SAME libjac_bridge_scalar.so.
#
# na side: synthesize Jac source from the .so's metadata, nacompile it with an
# appended probe that prints one line per observation, run the binary, diff the
# output against the CPython loader.  Gated on the LLVM shim; skips without it.
#
# Width note: the na runtime's `int` is 64-bit SIGNED, so a `u64` >= 2**63
# cannot be a positive Jac int -- na carries it as its two's-complement signed
# image (u64::MAX -> -1).  The conformance claim is that the SAME 64 bits cross
# on both runtimes, so the CPython side is normalized to that signed image
# (`_norm`) before comparison.  Values within i64 range compare directly.
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
     SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_scalar.so",
     SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so",
     I64_MIN = -9223372036854775807 - 1,
     # (seed, method, arg) -> arg is None for a no-arg method. Covers signed
     # round-trips (pos/neg, full width), narrow unsigned (low_byte), unsigned
     # high-bit decode (max_u64, magnitude of i64::MIN), and a fallible return.
     CASES = [
         (5, "seed", None),
         (-7, "seed", None),
         (9223372036854775807, "seed", None),
         (I64_MIN, "seed", None),
         (10, "add", 3),
         (10, "add", -25),
         (0x1234, "low_byte", None),
         (-1, "low_byte", None),
         (-7, "magnitude", None),
         (I64_MIN, "magnitude", None),
         (0, "max_u64", None),
         (0, "echo_u64", 42),
         (0, "echo_u64", 9223372036854775807),
         (20, "checked_div", 4),
         (20, "checked_div", 0)
     ];


def _norm(v: int) -> int {
    # Reduce an unsigned result to its signed 64-bit image (na's representation).
    return v - 0x10000000000000000 if v >= 0x8000000000000000 else v;
}


def _label(seed: int, method: str, arg: object) -> str {
    a = "" if arg is None else str(arg);
    return f"{seed} {method}({a}) = ";
}


def cpython_side -> list {
    mod = load_bridge(str(SO));
    calc = mod.Calc;
    err_cls = mod.ScalarError;
    lines = [];
    for case in CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        label = _label(seed, method, arg);
        c = calc(seed);
        fn = getattr(c, method);
        try {
            r = fn() if arg is None else fn(arg);
            lines.append(label + str(_norm(r)));
        } except err_cls {
            lines.append(label + "ERR");
        }
        c.close();
    }
    return [
        ln
        for ln in lines
        if ln.strip()
    ];
}


def _na_int(v: int) -> str {
    # Emit `v` as a Jac int literal; i64::MIN can't be written as a negated
    # positive literal (2**63 overflows i64), so build it by subtraction.
    if v == I64_MIN {
        return "(-9223372036854775807 - 1)";
    }
    return str(v);
}


def na_side -> list {
    meta = parse(read_jac_bridge_section(str(SO)));
    src = render_na_source(meta, SO.name).source;

    probe = ["\nwith entry {"];
    for case in CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        label = _label(seed, method, arg);
        call = f"c.{method}()" if arg is None else f"c.{method}({_na_int(arg)})";
        probe.append("    c = Calc(" + _na_int(seed) + ");");
        probe.append("    try {");
        probe.append("        r = " + call + ";");
        probe.append("        print(" + _jac_str(label) + " + str(r));");
        probe.append("    } except Exception {");
        probe.append("        print(" + _jac_str(label + "ERR") + ");");
        probe.append("    }");
        probe.append("    c.close();");
    }
    probe.append("}");
    src = src + "\n".join(probe);

    td = tempfile.mkdtemp();
    try {
        jac_file = Path(td) / "scalar_conf.na.jac";
        jac_file.write_text(src);
        binp = Path(td) / "scalar_conf";
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
        return [
            ln
            for ln in run.stdout.splitlines()
            if ln.strip()
        ];
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


def _jac_str(s: str) -> str {
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
}


test "scalar na cpython conformance" {
    if not SO.is_file() {
        return;
    }
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")) {
        return;
    }
    assert cpython_side() == na_side();
}
