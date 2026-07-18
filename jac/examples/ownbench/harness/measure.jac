"""Compile and measure ownbench kernels across GC modes.

Usage:
  jac run harness/measure.jac [--kernels k1,k2] [--modes none,rc,cycles]
      [--invocations N] [--sizes default|small] [--out results.json]
      [--skip-compile]

Per (kernel, mode): compiles with jac nacompile, runs N process
invocations, reports median wall-time (from the kernel's internal ns=
line), max RSS (via /usr/bin/time -v), and a digest (stdout minus the ns=
line). Fails loudly if digests differ across modes for the same
kernel/size (the differential-identity oracle).
"""

import hashlib;
import json;
import statistics;
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
     MODES = ["none", "rc", "cycles"],
     SIZES: dict[str, dict[str, list[str]]] = {
         "default": {
             "own_binarytrees": ["16"],
             "own_vecdot": ["20000", "400"],
             "own_histogram": ["200000", "40"],
             "own_vm": ["5000", "4000"],
             "own_rbtree": ["100000", "8"],
             "own_deriv": ["120", "400"],

         },
         "small": {
             "own_binarytrees": ["10"],
             "own_vecdot": ["2000", "20"],
             "own_histogram": ["20000", "5"],
             "own_vm": ["500", "200"],
             "own_rbtree": ["5000", "3"],
             "own_deriv": ["40", "10"],

         },

     };

"""nacompile flags for a memory mode."""
def mode_flags(mode: str) -> list[str] {
    if mode == "none" {
        return ["--enforce-nogc", "--gc", "none", "--assert-no-rc"];
    }
    return ["--gc", mode];
}

"""Compile one kernel under one mode; exit loudly on failure."""
def compile_kernel(kernel: str, mode: str) -> Path {
    src = BENCH / "kernels" / f"{kernel}.na.jac";
    out = BENCH / "bin" / f"{kernel}_{mode}";
    out.parent.mkdir(exist_ok=True);
    cmd = ["jac", "nacompile", str(src)] + mode_flags(mode) + ["-o", str(out)];
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600);
    if r.returncode != 0 or not out.exists() {
        sys.exit(f"compile failed: {' '.join(cmd)}\n{r.stdout}\n{r.stderr}");
    }
    return out;
}

"""One measured invocation: internal ns, max RSS (KB), and output digest."""
def run_once(binary: Path, args: list[str]) -> dict {
    r = subprocess.run(
        ["/usr/bin/time", "-v", str(binary)] + args,
        capture_output=True,
        text=True,
        timeout=600,
    );
    if r.returncode != 0 {
        sys.exit(f"run failed rc={r.returncode}: {binary} {' '.join(args)}");
    }
    rss_kb = 0;
    for line in r.stderr.splitlines() {
        if "Maximum resident set size" in line {
            rss_kb = int(line.rsplit(" ", 1)[-1]);
        }
    }
    ns: int | None = None;
    digest_lines: list[str] = [];
    for line in r.stdout.splitlines() {
        if line.startswith("ns=") {
            ns = int(line[3:]);
        } else {
            digest_lines.append(line);
        }
    }
    digest = hashlib.sha256("\n".join(digest_lines).encode()).hexdigest()[:16];
    return {"ns": ns, "max_rss_kb": rss_kb, "digest": digest};
}

"""Parse --flag value / --flag CLI options into a dict, with defaults."""
def parse_opts(argv: list[str]) -> dict {
    opts: dict = {
        "kernels": ",".join(KERNELS),
        "modes": ",".join(MODES),
        "invocations": 10,
        "sizes": "default",
        "out": str(BENCH / "results" / "results.json"),
        "skip_compile": False,

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag == "--skip-compile" {
            opts["skip_compile"] = True;
            i += 1;
        } elif flag in ("--kernels", "--modes", "--sizes", "--out", "--invocations")
        and i + 1 < len(argv) {
            key = flag[2:].replace("-", "_");
            opts[key] = int(argv[i + 1]) if flag == "--invocations" else argv[i + 1];
            i += 2;
        } else {
            sys.exit(f"unknown option: {flag}\n{__doc__}");
        }
    }
    if opts["sizes"] not in SIZES {
        sys.exit(f"--sizes must be one of {sorted(SIZES.keys())}");
    }
    return opts;
}

"""Measure every requested (kernel, mode) cell and write results JSON."""
def main(opts: dict) {
    kernels = [
        k
        for k in opts["kernels"].split(",")
        if k
    ];
    modes = [
        m
        for m in opts["modes"].split(",")
        if m
    ];
    results: dict = {};
    identity_fail = False;

    for kernel in kernels {
        args = SIZES[opts["sizes"]][kernel];
        per_mode: dict = {};
        for mode in modes {
            binary = BENCH / "bin" / f"{kernel}_{mode}";
            if not opts["skip_compile"] or not binary.exists() {
                binary = compile_kernel(kernel, mode);
            }
            runs = [run_once(binary, args) for _ in range(opts["invocations"])];
            times = [
                r["ns"]
                for r in runs
                if r["ns"] is not None
            ];
            digests = {r["digest"] for r in runs};
            if len(digests) != 1 {
                sys.exit(f"{kernel}/{mode}: nondeterministic output across runs");
            }
            per_mode[mode] = {
                "args": args,
                "invocations": opts["invocations"],
                "median_ns": int(statistics.median(times)) if times else None,
                "min_ns": min(times) if times else None,
                "max_ns": max(times) if times else None,
                "stdev_ns": int(statistics.stdev(times)) if len(times) > 1 else 0,
                "max_rss_kb": max([r["max_rss_kb"] for r in runs]),
                "digest": digests.pop(),

            };
            cell = per_mode[mode];
            print(
                f"{kernel:12s} {mode:6s} median={cell['median_ns']}ns "
                f"rss={cell['max_rss_kb']}KB digest={cell['digest']}"
            );
        }
        cross = {m["digest"] for m in per_mode.values()};
        if len(cross) != 1 {
            print(f"{kernel}: DIGEST MISMATCH ACROSS MODES {cross}", file=sys.stderr);
            identity_fail = True;
        } else {
            print(f"{kernel:12s} identity: OK");
        }
        results[kernel] = per_mode;
    }

    out = Path(opts["out"]);
    out.parent.mkdir(exist_ok=True);
    out.write_text(json.dumps(results, indent=2) + "\n");
    print(f"wrote {out}");
    if identity_fail {
        sys.exit("differential identity FAILED");
    }
}

with entry {
    main(parse_opts(sys.argv));
}
