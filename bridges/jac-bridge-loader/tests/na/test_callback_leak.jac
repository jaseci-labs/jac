# RC-balance regression for the na callback trampoline.
#
# The replace_all callback vertical lowers a Jac lambda to a ctx-leading C-ABI
# trampoline (na_ir_gen_pass.impl/calls.impl.jac::_codegen_callback_arg). That
# trampoline mints an owned Jac str from the matched bytes and receives an owned
# str back from the lambda; both must be RC-released after make_buf copies the
# replacement out, or every match leaks two strings.
#
# This test proves the balance behaviorally: it nacompiles the SAME probe at a
# small and a large iteration count, then measures each probe binary's own peak
# RSS. A leak grows peak RSS ~linearly with the loop count; a balanced trampoline
# plateaus. Peak is read via a one-shot python wrapper whose only child is the
# probe, so RUSAGE_CHILDREN is the probe's peak alone -- isolated from the
# nacompile toolchain (which loads the ~1.2 GB LLVM shim and would otherwise
# dominate the reading). Gated on the owning .so + the LLVM shim; skips without
# either.
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from _harness {
    bridge_so,
    llvm_shim,
    nacompile_in_dir,
    skip_gate,
    synthesize_source
}


glob SO = bridge_so("owning"),
     SHIM = llvm_shim(),
     SMALL_N = 1000,
     LARGE_N = 300000,
     # Balanced growth is ~0; the leak at this LARGE_N is ~100 MB. 40 MB cleanly
     # separates the two while tolerating allocator/runtime noise.
     THRESHOLD_KB = 40000;


# Append a probe loop to the synthesized bridge source. "a1b22c333" has three
# digit-runs, so each replace_all fires the callback three times.
def _probe_src(n: int, base: str) -> str {
    loop = "\nwith entry {\n" + "    re = Regex(\"\\\\d+\");\n" + "    total = 0;\n" + "    i = 0;\n" + "    while i < " + str(
        n
    ) + " {\n" + "        out = re.replace_all(\"a1b22c333\", lambda (m: str) -> str : m.upper());\n" + "        total = total + strlen(out);\n" + "        i = i + 1;\n" + "    }\n" + "    re.close();\n" + "    print(total);\n" + "}\n";
    return base + loop;
}


# Run the probe binary as the SOLE child of a fresh python, so its own peak RSS
# is exactly RUSAGE_CHILDREN.ru_maxrss -- unpolluted by the compiler process.
def _measure(binp: Path) -> tuple {
    wrapper = "import subprocess,resource,sys;" + "r=subprocess.run([sys.argv[1]],capture_output=True,text=True);" + "sys.stdout.write(r.stdout);" + "sys.stderr.write('RC=%d\\nPEAK_KB=%d\\n'" + "%(r.returncode,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss))";
    runenv = dict(os.environ);
    runenv["LD_LIBRARY_PATH"] = str(SO.parent);
    res = subprocess.run(
        [sys.executable, "-c", wrapper, str(binp)],
        capture_output=True,
        text=True,
        timeout=300,
        env=runenv
    );
    peak = 0;
    rc = -1;
    for ln in res.stderr.splitlines() {
        if ln.startswith("PEAK_KB=") {
            peak = int(ln.split("=", 1)[1]);
        } elif ln.startswith("RC=") {
            rc = int(ln.split("=", 1)[1]);
        }
    }
    if rc != 0 {
        raise RuntimeError(f"probe exited {rc}:\n{res.stdout}\n{res.stderr}");
    }
    return (res.stdout.strip(), peak);
}


def _peak_growth_kb -> int {
    base = synthesize_source(SO);
    td = tempfile.mkdtemp();
    try {
        bin_s = nacompile_in_dir(
            _probe_src(SMALL_N, base),
            td,
            "cb_leak_small.na.jac",
            "cb_leak_small",
            SHIM,
            fail_tag="nacompile(small)"
        );
        bin_l = nacompile_in_dir(
            _probe_src(LARGE_N, base),
            td,
            "cb_leak_large.na.jac",
            "cb_leak_large",
            SHIM,
            fail_tag="nacompile(large)"
        );
        (out_s, peak_s) = _measure(bin_s);
        (out_l, peak_l) = _measure(bin_l);
        return peak_l - peak_s;
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "na callback trampoline does not leak per-match strings" {
    if skip_gate(SO, SHIM) {
        return;
    }
    growth = _peak_growth_kb();
    assert growth < THRESHOLD_KB , f"callback trampoline leaks: probe peak RSS grew {growth} KB " + f"(threshold {THRESHOLD_KB} KB) as the match count rose " + f"{SMALL_N}->{LARGE_N}";
}
