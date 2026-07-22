"""Region benchmark driver for the osp_regions experiments.

Usage: jac run harness/rbench.jac [--invocations N] [--quick]
       [--out results/regions_results.json]

Covers the four region kernels:
  reg_graph     build-traverse-discard: {region, bare} x {rc, cycles} x
             {acyclic, cyclic}; digest identity across every cell of a
             config; medians plus tail-latency and drop-count metrics.
             The bare variant is generated with rerase.jac (the
             mechanical open-lines-only diff) and reports m:drops=0 on
             native: managed nodes are runtime-pinned immortal, which is
             the measured baseline, not an error.
  reg_wspawn    walker-spawn reclamation under rc and cycles.
  reg_transfer  move vs copy vs serial across subgraph sizes; digest
             identity across strategies per size; per-transfer ns.
  reg_overhead  region_of allocation micro (managed vs region anchored).

Digest = stdout minus lines starting with "ns=" or "m:"; metric lines
are parsed and reported per cell.
"""

import hashlib;
import json;
import statistics;
import subprocess;
import sys;
import from pathlib { Path }

glob BENCH = Path(str(__file__)).resolve().parent.parent,
     MODES = ["rc", "cycles"],
     TRANSFER_SIZES = ["100", "1000", "10000", "100000"],
     TRANSFER_SIZES_QUICK = ["100", "1000"];

"""Compile `src` under a gc mode; exit loudly on failure."""
def compile_src(src: Path, mode: str, out: Path) -> Path {
    out.parent.mkdir(exist_ok=True);
    cmd = ["jac", "nacompile", str(src), "--gc", mode, "-o", str(out)];
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600);
    if r.returncode != 0 or not out.exists() {
        sys.exit(f"compile failed: {' '.join(cmd)}\n{r.stdout}\n{r.stderr}");
    }
    return out;
}

"""One invocation: digest, internal ns, parsed m: metrics, max RSS."""
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
    metrics: dict = {};
    digest_lines: list[str] = [];
    for line in r.stdout.splitlines() {
        if line.startswith("ns=") {
            ns = int(line[3:]);
        } elif line.startswith("m:") {
            (key, _, val) = line[2:].partition("=");
            metrics[key] = int(val);
        } else {
            digest_lines.append(line);
        }
    }
    digest = hashlib.sha256("\n".join(digest_lines).encode()).hexdigest()[:16];
    return {"ns": ns, "rss_kb": rss_kb, "digest": digest, "metrics": metrics};
}

"""Run `invocations` times; aggregate medians, keep last metrics."""
def measure(binary: Path, args: list[str], invocations: int) -> dict {
    runs = [run_once(binary, args) for _ in range(invocations)];
    digests = {r["digest"] for r in runs};
    if len(digests) != 1 {
        sys.exit(f"nondeterministic output: {binary} {' '.join(args)}");
    }
    times = [
        r["ns"]
        for r in runs
        if r["ns"] is not None
    ];
    med: dict = {};
    first_metrics: dict = runs[0]["metrics"];
    for key in first_metrics.keys() {
        med[key] = int(statistics.median([r["metrics"][key] for r in runs]));
    }
    return {
        "args": args,
        "median_ns": int(statistics.median(times)) if times else None,
        "stdev_ns": int(statistics.stdev(times)) if len(times) > 1 else 0,
        "max_rss_kb": max([r["rss_kb"] for r in runs]),
        "digest": digests.pop(),
        "metrics": med,

    };
}

"""Parse CLI options."""
def parse_opts(argv: list[str]) -> dict {
    opts: dict = {
        "invocations": 10,
        "quick": False,
        "out": str(BENCH / "results" / "regions_results.json"),

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag == "--quick" {
            opts["quick"] = True;
            i += 1;
        } elif flag in ("--invocations", "--out") and i + 1 < len(argv) {
            key = flag[2:];
            opts[key] = int(argv[i + 1]) if flag == "--invocations" else argv[i + 1];
            i += 2;
        } else {
            sys.exit(f"unknown option: {flag}\n{__doc__}");
        }
    }
    return opts;
}

"""Generate the bare reg_graph variant with rerase.jac."""
def make_bare(src: Path, dst: Path) -> Path {
    r = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "run",
            str(BENCH / "harness" / "rerase.jac"),
            str(src)
        ],
        capture_output=True,
        text=True,
        timeout=300,
    );
    if r.returncode != 0 {
        sys.exit(f"rerase failed: {r.stderr}");
    }
    dst.parent.mkdir(exist_ok=True);
    dst.write_text(r.stdout);
    return dst;
}

def main(opts: dict) {
    inv = int(opts["invocations"]);
    results: dict = {};
    fail = False;

    rgraph_args = ["50", "20"] if opts["quick"] else ["200", "500"];
    bare_src = make_bare(
        BENCH / "kernels" / "reg_graph.jac", BENCH / "bin" / "reg_graph_bare.jac"
    );
    results["reg_graph"] = {};
    for cfg in ["acyclic", "cyclic"] {
        back = "0" if cfg == "acyclic" else "10";
        cells: dict = {};
        for (variant, src) in [
            ("region", BENCH / "kernels" / "reg_graph.jac"),
            ("bare", bare_src),

        ] {
            for mode in MODES {
                out = BENCH / "bin" / f"reg_graph_{variant}_{mode}";
                compile_src(src, mode, out);
                cell = measure(out, rgraph_args + [back], inv);
                cells[f"{variant}/{mode}"] = cell;
                print(
                    f"reg_graph {cfg:7s} {variant:6s} {mode:6s} "
                    f"median={cell['median_ns']}ns rss={cell['max_rss_kb']}KB "
                    f"drops={cell['metrics'].get('drops')} "
                    f"p99={cell['metrics'].get('p99')}"
                );
            }
        }
        digs = {c["digest"] for c in cells.values()};
        if len(digs) != 1 {
            print(f"reg_graph/{cfg}: DIGEST MISMATCH {digs}", file=sys.stderr);
            fail = True;
        } else {
            print(f"reg_graph {cfg:7s} identity: OK");
        }
        results["reg_graph"][cfg] = cells;
    }

    wspawn_args = ["20", "200"] if opts["quick"] else ["50", "20000"];
    results["reg_wspawn"] = {};
    wdigs: set = set();
    for mode in MODES {
        out = BENCH / "bin" / f"reg_wspawn_{mode}";
        compile_src(BENCH / "kernels" / "reg_wspawn.jac", mode, out);
        cell = measure(out, wspawn_args, inv);
        results["reg_wspawn"][mode] = cell;
        wdigs.add(cell["digest"]);
        print(
            f"reg_wspawn {mode:6s} median={cell['median_ns']}ns "
            f"rss={cell['max_rss_kb']}KB wdrops={cell['metrics'].get('wdrops')}"
        );
    }
    if len(wdigs) != 1 {
        print("reg_wspawn: DIGEST MISMATCH", file=sys.stderr);
        fail = True;
    } else {
        print("reg_wspawn identity: OK");
    }

    sizes = TRANSFER_SIZES_QUICK if opts["quick"] else TRANSFER_SIZES;
    treps = "5" if opts["quick"] else "20";
    out = BENCH / "bin" / "reg_transfer_cycles";
    compile_src(BENCH / "kernels" / "reg_transfer.jac", "cycles", out);
    results["reg_transfer"] = {};
    for size in sizes {
        row: dict = {};
        for strategy in ["move", "copy", "serial"] {
            cell = measure(out, [strategy, size, treps], inv);
            row[strategy] = cell;
            print(
                f"reg_transfer n={size:>7s} {strategy:6s} "
                f"transfer_ns={cell['metrics'].get('transfer_ns')}"
            );
        }
        digs = {c["digest"] for c in row.values()};
        if len(digs) != 1 {
            print(f"reg_transfer n={size}: DIGEST MISMATCH", file=sys.stderr);
            fail = True;
        } else {
            print(f"reg_transfer n={size:>7s} identity: OK");
        }
        results["reg_transfer"][size] = row;
    }

    out = BENCH / "bin" / "reg_overhead_cycles";
    compile_src(BENCH / "kernels" / "reg_overhead.jac", "cycles", out);
    ok_args = ["200000"] if opts["quick"] else ["2000000"];
    cell = measure(out, ok_args, max(3, inv // 3));
    results["reg_overhead"] = cell;
    print(
        f"reg_overhead managed={cell['metrics'].get('managed_alloc_ns')}ns/alloc "
        f"region={cell['metrics'].get('region_alloc_ns')}ns/alloc"
    );

    outp = Path(opts["out"]);
    outp.parent.mkdir(exist_ok=True);
    outp.write_text(json.dumps(results, indent=2) + "\n");
    print(f"wrote {outp}");
    if fail {
        sys.exit("region differential identity FAILED");
    }
}

with entry {
    main(parse_opts(sys.argv));
}
