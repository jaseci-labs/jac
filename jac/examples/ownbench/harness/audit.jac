"""IR audit: count RC/collector machinery in emitted LLVM IR per kernel/mode.

Usage: jac run harness/audit.jac [--kernels k1,k2] [--modes none,rc,cycles]
       [--out ir_audit.json]

Compiles each (kernel, mode) with JAC_DUMP_IR set and counts __rc_* symbol
references, trace functions, and collector entry points. The enforced
'none' build must show zero of each (the zero-RC contract).
"""

import json;
import os;
import re;
import subprocess;
import sys;
import from pathlib { Path }

glob BENCH = Path(str(__file__)).resolve().parent.parent,
     KERNELS = [
         "own_binarytrees",
         "own_vecdot",
         "own_histogram",
         "own_vm",
         "own_rbtree",
         "own_deriv"
     ],
     MODES = ["none", "rc", "cycles"];

"""nacompile flags for a memory mode."""
def mode_flags(mode: str) -> list[str] {
    if mode == "none" {
        return ["--enforce-nogc", "--gc", "none", "--assert-no-rc"];
    }
    return ["--gc", mode];
}

"""Compile one cell with IR dumping and count the RC machinery."""
def audit(kernel: str, mode: str) -> dict {
    src = BENCH / "kernels" / f"{kernel}.jac";
    out = BENCH / "bin" / f"audit_{kernel}_{mode}";
    out.parent.mkdir(exist_ok=True);
    ll = BENCH / "results" / f"{kernel}_{mode}.ll";
    ll.parent.mkdir(exist_ok=True);
    env = dict(os.environ, JAC_DUMP_IR=str(ll));
    cmd = ["jac", "nacompile", str(src)] + mode_flags(mode) + ["-o", str(out)];
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600, env=env);
    if r.returncode != 0 {
        sys.exit(f"compile failed: {' '.join(cmd)}\n{r.stdout}\n{r.stderr}");
    }
    text = ll.read_text();
    out.unlink(missing_ok=True);
    return {
        "rc_symbol_refs": len(re.findall(r"@__rc_\w+", text)),
        "rc_symbols": sorted({*re.findall(r"@(__rc_\w+)", text)}),
        "trace_fns": len({*re.findall(r"define[^\n]*@(__trace_\w+)", text)}),
        "collector_refs": len(re.findall(r"@__rc_collect_cycles|@__rc_recycler", text)),

    };
}

"""Parse --flag value CLI options into a dict, with defaults."""
def parse_opts(argv: list[str]) -> dict {
    opts: dict = {
        "kernels": ",".join(KERNELS),
        "modes": ",".join(MODES),
        "out": str(BENCH / "results" / "ir_audit.json"),

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag in ("--kernels", "--modes", "--out") and i + 1 < len(argv) {
            opts[flag[2:]] = argv[i + 1];
            i += 2;
        } else {
            sys.exit(f"unknown option: {flag}\n{__doc__}");
        }
    }
    return opts;
}

"""Audit every requested cell; fail if an enforced build has RC machinery."""
def main(opts: dict) {
    census: dict = {};
    bad = False;
    for kernel in [
        k
        for k in opts["kernels"].split(",")
        if k
    ] {
        census[kernel] = {};
        for mode in [
            m
            for m in opts["modes"].split(",")
            if m
        ] {
            a = audit(kernel, mode);
            census[kernel][mode] = a;
            print(
                f"{kernel:12s} {mode:6s} rc_refs={a['rc_symbol_refs']:4d} "
                f"trace_fns={a['trace_fns']:2d} collector={a['collector_refs']}"
            );
            if mode == "none" and (a["rc_symbol_refs"] or a["trace_fns"]) {
                print(f"{kernel}/none: RC MACHINERY PRESENT", file=sys.stderr);
                bad = True;
            }
        }
    }
    out = Path(opts["out"]);
    out.write_text(json.dumps(census, indent=2) + "\n");
    print(f"wrote {out}");
    if bad {
        sys.exit("zero-RC audit FAILED for an enforced build");
    }
}

with entry {
    main(parse_opts(sys.argv));
}
