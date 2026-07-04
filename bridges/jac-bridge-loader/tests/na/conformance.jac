# M3 conformance: prove the na and CPython runtimes are observationally
# identical against the SAME libjac_bridge_regex.so.
#
# CPython side: the real loader (jaclang.compiler.rust_bridge.load_bridge -> ctypes module).
# na side:      synthesize Jac source from the same .so's metadata, nacompile it
#               with an appended probe that prints one line per assertion outcome,
#               run the binary, and compare the outputs.
import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


glob REPO = Path(__file__).resolve().parents[4],
     JAC = REPO / "jac",
     SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_regex.so",
     SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so";

glob CASES = [
         ("foo\\d+", "foo42", True),
         ("foo\\d+", "bar", False),
         ("^[a-z]+$", "hello", True),
         ("^[a-z]+$", "Hello", False),
         ("\\bcat\\b", "the cat sat", True),
         ("\\bcat\\b", "category", False)
     ];
glob BAD_PATTERNS = ["(unclosed", "a{", "[z-a]"];


def cpython_side -> list {
    regex = load_bridge(str(SO));
    lines = [];
    for (pat, text, _flag) in CASES {
        re = regex.Regex(pat);
        lines.append(f"match {repr(pat)} {repr(text)} = {int(re.is_match(text))}");
        re.close();
    }
    for pat in BAD_PATTERNS {
        try {
            regex.Regex(pat);
            lines.append(f"bad {repr(pat)} = NOERROR");
        } except Exception as e {
            # Compare the REAL error text, not just "RAISED": the message is the
            # Rust regex crate's own (multi-line) parse error, decoded from the
            # error handle's JacBuf -- the exact path the na JacBuf->str read must
            # reproduce byte-for-byte against the same .so.
            lines.append(f"bad {repr(pat)} = {e}");
        }
    }
    # Normalize multi-line messages the same way the na side does (below), so the
    # two line-lists are structurally comparable.
    return [
        ln
        for ln in "\n".join(lines).splitlines()
        if ln.strip()
    ];
}


def _jac_str(s: str) -> str {
    # embed a Python string as a Jac double-quoted literal
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
}


def na_side -> list {
    meta = parse(read_jac_bridge_section(str(SO)));
    src = render_na_source(meta, SO.name).source;

    probe = ["\nwith entry {"];
    for (pat, text, _flag) in CASES {
        label = f"match {repr(pat)} {repr(text)} = ";
        probe.append(f"    re = Regex({_jac_str(pat)});");
        probe.append(f"    if re.is_match({_jac_str(text)}) {{");
        probe.append(f"        print({_jac_str(label + '1')});");
        probe.append("    } else {");
        probe.append(f"        print({_jac_str(label + '0')});");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for pat in BAD_PATTERNS {
        label = f"bad {repr(pat)} = ";
        # Print the decoded error text (prefix identical to the CPython side), so
        # conformance checks the JacBuf->str message bytes, not merely that it
        # raised.  str(e) on na yields the same Rust message as CPython's {e}.
        probe.append(
            f"    try {{ bad = Regex({_jac_str(pat)}); " + f"print({_jac_str(
                label + 'NOERROR'
            )}); }} " + f"except Exception as e {{ print({_jac_str(
                label
            )} + str(e)); }}"
        );
    }
    probe.append("}");
    src = src + "\n".join(probe);

    with tempfile.TemporaryDirectory() as td {
        jac_file = Path(td) / "conf.jac";
        jac_file.write_text(src);
        binp = Path(td) / "conf";
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
        run_env = dict(os.environ);
        run_env["LD_LIBRARY_PATH"] = str(SO.parent);
        run = subprocess.run(
            [str(binp)], capture_output=True, text=True, timeout=60, env=run_env
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
    }
}


test "na cpython conformance" {
    # pytest entry: skips unless the bridge .so and LLVM shim are both present.
    if not SO.is_file() {
        return;
    }
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")) {
        return;
    }
    assert cpython_side() == na_side();
}
