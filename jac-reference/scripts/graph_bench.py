#!/usr/bin/env python3
"""Bench trail for the graph-shaped compiler (#8744 WS0).

Run through the jac launcher in python mode so `jaclang` binds to the checkout:

    jac scripts/graph_bench.py [file.jac ...]

Reports the bytecode kernel's connect and hop cost, then parse time, node and
edge counts, and RSS for each file (default: the language circle fixture and
the compiler's own unitree.jac).
"""

from __future__ import annotations

import os
import resource
import sys
import time
from dataclasses import dataclass


def _rss_mb() -> float:
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0


def kernel_bench(n: int = 8000) -> None:
    from jaclang.lib.jaclib import Edge, Node, build_edge, connect
    import jaclang.jac0core.osp0 as osp0

    @dataclass(eq=False)
    class N(Node):
        i: int = 0

    @dataclass(eq=False)
    class Body(Edge):
        idx: int = 0

    nodes = [N(i=i) for i in range(n)]
    par = nodes[0]
    t0 = time.perf_counter()
    for i in range(1, n):
        connect(left=par, right=nodes[i], edge=Body, conn_assign=(("idx",), (i,)))
        if i % 8 == 0:
            par = nodes[i]
    t1 = time.perf_counter()
    hops = 0
    t2 = time.perf_counter()
    for i in range(0, n, 7):
        hops += 1
        osp0.refs0(nodes[i], 2, Body, False)
    t3 = time.perf_counter()
    print(
        f"kernel n={n}: connect {(t1 - t0) / n * 1e6:.1f} us/edge, "
        f"adjacency hop {(t3 - t2) / hops * 1e6:.1f} us/hop"
    )


def parse_bench(paths: list[str]) -> None:
    from jaclang.compiler.driver.program import JacProgram

    prog = JacProgram()
    for path in paths:
        src = open(path, encoding="utf-8").read()
        before = _rss_mb()
        t0 = time.perf_counter()
        mod = prog.parse_str(src, file_path=path)
        t1 = time.perf_counter()
        if mod is None:
            print(f"{path}: parse failed ({len(prog.errors_had)} errors)")
            continue
        nodes = mod.flatten()
        edges = sum(len(nd._role_pairs()) for nd in nodes)
        print(
            f"{path}: {len(src.splitlines())} lines, {len(nodes)} nodes, {edges} edges, "
            f"parse {t1 - t0:.2f}s ({(t1 - t0) / max(len(nodes), 1) * 1e6:.0f} us/node), "
            f"rss +{_rss_mb() - before:.0f} MB"
        )


if __name__ == "__main__":
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sys.argv[1:] or [
        os.path.join(here, "jac", "tests", "language", "fixtures", "circle.jac"),
        os.path.join(here, "jac", "jaclang", "compiler", "frontend", "unitree.jac"),
    ]
    kernel_bench()
    parse_bench(files)
