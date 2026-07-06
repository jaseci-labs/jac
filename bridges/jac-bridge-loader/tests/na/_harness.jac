# Shared harness for na conformance tests: Jac literal helpers, synthesized-source
# compile+run, temp-dir lifecycle, LLVM-shim gating, and bridge .so discovery.
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


glob I64_MIN = -9223372036854775807 - 1;


def workspace -> Path {
    # na/ -> tests/ -> jac-bridge-loader/ -> bridges/ (cargo workspace root)
    return Path(__file__).resolve().parent.parent.parent;
}


def bridge_so(crate: str) -> Path {
    ws = workspace();
    stems = (
        f"libjac_bridge_{crate}.so",
        f"libjac_bridge_{crate}.dylib",
        f"jac_bridge_{crate}.dll"
    );
    for stem in stems {
        p = ws / "target" / "release" / stem;
        if p.exists() {
            return p;
        }
    }
    return ws / "target" / "release" / stems[0];
}


def _find_so(crate: str) -> str {
    p = bridge_so(crate);
    if not p.is_file() {
        raise FileNotFoundError(
            f"libjac_bridge_{crate} not found; run: cargo build --release"
        );
    }
    return str(p);
}


def regex_so -> str {
    return _find_so("regex");
}


def owning_so -> str {
    return _find_so("owning");
}


def scalar_so -> str {
    return _find_so("scalar");
}


def map_so -> str {
    return _find_so("map");
}


def list_so -> str {
    return _find_so("list");
}


def jac_root -> Path {
    return workspace().parent / "jac";
}


def llvm_shim -> Path {
    return jac_root() / "zig-out" / "lib" / "libjacllvm.so";
}


def jac_str(s: str) -> str {
    # Embed a Python string as a Jac double-quoted literal.
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
}


def synthesize_source(so: Path) -> str {
    meta = parse(read_jac_bridge_section(str(so)));
    return render_na_source(meta, so.name).source;
}


def norm_unsigned(v: int) -> int {
    # Reduce an unsigned result to its signed 64-bit image (na's representation).
    return v - 0x10000000000000000 if v >= 0x8000000000000000 else v;
}


def canon_value(v: object, kind: str) -> str {
    if kind == "bool" {
        return "1" if v else "0";
    }
    if kind == "str" {
        return str(v);
    }
    return str(norm_unsigned(v));
}


def na_int_literal(v: int) -> str {
    # Emit `v` as a Jac int literal; i64::MIN can't be written as a negated
    # positive literal (2**63 overflows i64), so build it by subtraction.
    if v == I64_MIN {
        return "(-9223372036854775807 - 1)";
    }
    return str(v);
}


def shim_available(shim: Path) -> bool {
    return shim.is_file() or bool(os.environ.get("JAC_LLVM_SHIM"));
}


def skip_gate(so: Path, shim: Path) -> bool {
    return not so.is_file() or not shim_available(shim);
}


def effective_shim(shim: Path) -> str {
    return os.environ.get("JAC_LLVM_SHIM") or str(shim);
}


def compile_env(shim: Path) -> dict {
    env = dict(os.environ);
    env["JAC_LLVM_SHIM"] = effective_shim(shim);
    env["PYTHONPATH"] = str(jac_root());
    return env;
}


def run_env(so: Path) -> dict {
    env = dict(os.environ);
    env["LD_LIBRARY_PATH"] = str(so.parent);
    return env;
}


def nacompile_in_dir(
    src: str, td: str, jac_name: str, bin_name: str, shim: Path, fail_tag: str = ""
) -> Path {
    jac_file = Path(td) / jac_name;
    jac_file.write_text(src);
    binp = Path(td) / bin_name;
    r = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", str(jac_file), "-o", str(binp)],
        cwd=str(jac_root()),
        env=compile_env(shim),
        capture_output=True,
        text=True,
        timeout=600
    );
    if not binp.exists() {
        tag = fail_tag or "nacompile";
        raise RuntimeError(tag + " failed:\n" + r.stdout[-2000:] + r.stderr[-2000:]);
    }
    return binp;
}


def run_binary(binp: Path, so: Path, timeout: int = 60) -> str {
    run = subprocess.run(
        [str(binp)], capture_output=True, text=True, timeout=timeout, env=run_env(so)
    );
    if run.returncode != 0 {
        raise RuntimeError(
            f"binary exited {run.returncode}:\n{run.stdout}\n{run.stderr}"
        );
    }
    return run.stdout;
}


def nacompile_and_run(
    src: str,
    so: Path,
    jac_name: str,
    bin_name: str,
    shim: Path,
    strip_blank: bool = False,
    sort_lines: bool = False
) -> list {
    td = tempfile.mkdtemp();
    try {
        binp = nacompile_in_dir(src, td, jac_name, bin_name, shim);
        lines = run_binary(binp, so).splitlines();
        if strip_blank {
            lines = [
                ln
                for ln in lines
                if ln.strip()
            ];
        }
        if sort_lines {
            lines = sorted(lines);
        }
        return lines;
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


def run_na_probe(
    so: Path,
    probe_lines: list,
    jac_name: str,
    bin_name: str,
    extra_src: str = "",
    strip_blank: bool = False,
    sort_lines: bool = False
) -> list {
    src = synthesize_source(so) + extra_src + "\n".join(probe_lines);
    return nacompile_and_run(
        src,
        so,
        jac_name,
        bin_name,
        llvm_shim(),
        strip_blank=strip_blank,
        sort_lines=sort_lines
    );
}
