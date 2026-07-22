"""Differential tests over the ownbench region kernels
(jac/examples/ownbench): the experiment surface for topology-aligned
regions.

What is pinned here:
  - rgraph (build-traverse-discard) produces identical digests for the
    region source and its rerase.jac-generated managed baseline, under
    both rc and cycles, acyclic and cyclic -- while the metric lines
    document the semantic difference: region teardown fires every node
    drop hook (drops == nodes) and the managed-native baseline fires
    none (nodes are runtime-pinned immortal).
  - The Python backend runs the same region source to the same digest
    (one region semantics, two backends).
  - rtransfer's three strategies (region move across flow, deep copy,
    serialize) agree on the transferred subgraph's checksum.
  - wspawn's walker and resource drop hooks fire once per request (the
    managed-walker reclamation).
  - This suite is also the regression net for the scope/loop cleanup
    ordering fix: region handles must drop AFTER ordinary locals are
    released (a per-iteration region whose residents are referenced by
    later-declared locals segfaults under allocation reuse otherwise).
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob OWNBENCH = str(Path(__file__).resolve().parents[4] / "examples" / "ownbench"),
     MODES = ["rc", "cycles"];

"""Compile `src` under a gc mode; assert success."""
def _nacompile(src: str, mode: str, out_bin: str) {
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            src,
            "--gc",
            mode,
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=300,
    );
    assert comp.returncode == 0 , (
        f"nacompile --gc {mode} failed for {os.path.basename(src)}:"
        f" exit={comp.returncode}\n"
        f"stdout: {comp.stdout[-600:] if comp.stdout else '(empty)'}\n"
        f"stderr: {comp.stderr[-600:] if comp.stderr else '(empty)'}"
    );
    assert os.path.exists(out_bin) , f"binary not produced at {out_bin}";
}

"""Run a kernel binary; return (digest, metrics dict)."""
def _run(out_bin: str, args: list[str]) -> tuple[str, dict] {
    proc = subprocess.run(
        [out_bin] + args, capture_output=True, text=True, timeout=120
    );
    assert proc.returncode == 0 , (
        f"{os.path.basename(out_bin)} exited {proc.returncode}"
        f" (a crash here is a region-codegen regression)"
    );
    metrics: dict = {};
    lines: list[str] = [];
    for ln in proc.stdout.splitlines() {
        if ln.startswith("ns=") {
            continue;
        }
        if ln.startswith("m:") {
            (key, _, val) = ln[2:].partition("=");
            metrics[key] = int(val);
            continue;
        }
        lines.append(ln);
    }
    return ("\n".join(lines), metrics);
}

"""Generate the bare rgraph baseline via rerase.jac into `dst`."""
def _rerase(src: str, dst: str) {
    r = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "run",
            os.path.join(OWNBENCH, "harness", "rerase.jac"),
            src
        ],
        capture_output=True,
        text=True,
        timeout=120,
    );
    assert r.returncode == 0 , f"rerase.jac failed: {r.stderr}";
    assert "Region" not in r.stdout , "rerase.jac left region annotations behind";
    with open(dst, "w") as f {
        f.write(r.stdout);
    }
}

test "rgraph: region and bare baselines agree; drops witness the leak" {
    src = os.path.join(OWNBENCH, "kernels", "reg_graph.jac");
    args = ["30", "10", "5"];
    with tempfile.TemporaryDirectory() as tmp {
        bare_src = os.path.join(tmp, "reg_graph_bare.jac");
        _rerase(src, bare_src);
        digests: set = set();
        for mode in MODES {
            rb = os.path.join(tmp, f"region_{mode}");
            _nacompile(src, mode, rb);
            (d, m) = _run(rb, args);
            digests.add(d);
            assert m["drops"] == 300 , (
                f"region/{mode}: expected 300 node drops, got {m['drops']}"
            );
            bb = os.path.join(tmp, f"bare_{mode}");
            _nacompile(bare_src, mode, bb);
            (d2, m2) = _run(bb, args);
            digests.add(d2);
            assert m2["drops"] == 0 , (
                f"bare/{mode}: managed nodes are pinned immortal on native;"
                f" expected 0 drops, got {m2['drops']}"
            );
        }
        assert len(digests) == 1 , f"digest mismatch across cells: {digests}";
    }
}

test "rgraph: python backend matches native digest" {
    src = os.path.join(OWNBENCH, "kernels", "reg_graph.jac");
    args = ["30", "10", "5"];
    with tempfile.TemporaryDirectory() as tmp {
        nb = os.path.join(tmp, "native");
        _nacompile(src, "cycles", nb);
        (nd, nm) = _run(nb, args);
        proc = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", src] + args,
            capture_output=True,
            text=True,
            timeout=300,
        );
        assert proc.returncode == 0 , f"jac run failed: {proc.stderr[-400:]}";
        py_lines = [
            ln
            for ln in proc.stdout.splitlines()
            if not (ln.startswith("ns=") or ln.startswith("m:"))
        ];
        assert "\n".join(py_lines) == nd , (
            f"python backend digest diverges from native:\n"
            f"--- py ---\n{chr(10).join(py_lines)}\n--- native ---\n{nd}"
        );
        assert nm["drops"] == 300;
    }
}

test "rtransfer: move, copy, and serial agree on the subgraph checksum" {
    src = os.path.join(OWNBENCH, "kernels", "reg_transfer.jac");
    with tempfile.TemporaryDirectory() as tmp {
        rb = os.path.join(tmp, "reg_transfer");
        _nacompile(src, "cycles", rb);
        digests: set = set();
        for strategy in ["move", "copy", "serial"] {
            (d, _m) = _run(rb, [strategy, "80", "3"]);
            digests.add(d);
        }
        assert len(digests) == 1 , f"strategy digests diverge: {digests}";
    }
}

test "wspawn: walker and resource drops fire once per request" {
    src = os.path.join(OWNBENCH, "kernels", "reg_wspawn.jac");
    with tempfile.TemporaryDirectory() as tmp {
        for mode in MODES {
            wb = os.path.join(tmp, f"reg_wspawn_{mode}");
            _nacompile(src, mode, wb);
            (_d, m) = _run(wb, ["10", "50"]);
            assert m["wdrops"] == 50 , f"{mode}: wdrops={m['wdrops']}, want 50";
            assert m["rdrops"] == 50 , f"{mode}: rdrops={m['rdrops']}, want 50";
        }
    }
}

test "roverhead: managed and region anchored allocation both run" {
    src = os.path.join(OWNBENCH, "kernels", "reg_overhead.jac");
    with tempfile.TemporaryDirectory() as tmp {
        ob = os.path.join(tmp, "reg_overhead");
        _nacompile(src, "cycles", ob);
        (d, m) = _run(ob, ["50000"]);
        assert d.startswith("roverhead:") , f"unexpected digest: {d}";
        (lhs, rhs) = d.split(":")[1:3];
        assert lhs == rhs , f"managed and region sinks diverge: {d}";
        assert m["managed_alloc_ns"] >= 0 and m["region_alloc_ns"] >= 0;
    }
}
