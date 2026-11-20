"""The OSP adjacency store answers typed hops from a per-edge-tag index.

`OspGraph.refs_into` used to walk every edge row of the origin node and test
each row's tag, so `[hub->:Rare:->]` on a hub owning thousands of edges of
other types cost the hub's whole degree, and unlinking an edge scanned the
row lists of both endpoints. Each node now indexes its rows by tag as well,
and every row remembers its slot in each list so unlinking just tombstones
it.

The index must be invisible: hops return peers in connect order (also when a
query matches several subtype tags, or mixes outgoing and undirected rows),
edges are deduplicated as before, freed rows are reused, and removal keeps
the order of the survivors. The model-based test replays random mutations
against a plain list-of-edges model of those semantics.
"""

import random;
import time;
import jaclang.runtime.osp_graph as _g;
import from jaclang.runtime.osp_graph { OspGraph }

glob T_A: int = 9200100,
     T_B: int = 9200101,
     T_C: int = 9200102,
     T_BASE: int = 9200110,
     T_SUB1: int = 9200111,
     T_SUB2: int = 9200112,
     T_LEAF: int = 9200113,
     OUT: int = 2,
     IN: int = 1,
     ANY: int = 3;

# Tag-index thresholds: index every node side from its first row, index
# sides as they cross a small degree, and never index (the plain scan).
glob INDEX_AT: list[int] = [0, 3, 100000];

def _graph(idx: int = 8) -> OspGraph {
    return OspGraph(
        adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={}, index_at=idx
    );
}

def _register {
    _g.osp_register_type(T_BASE, []);
    _g.osp_register_type(T_SUB1, [T_BASE]);
    _g.osp_register_type(T_SUB2, [T_BASE]);
    _g.osp_register_type(T_LEAF, [T_SUB1]);
}

test "typed hops keep connect order across interleaved edge types" {
    for idx in INDEX_AT {
        g = _graph(idx);
        tags = [T_A, T_B, T_A, T_C, T_B, T_A, T_C];
        for (i, t) in enumerate(tags) {
            g.connect(1, 100 + i, 500 + i, False, t, 0, 0);
        }
        assert g.refs(1, OUT, T_A, False) == [100, 102, 105];
        assert g.refs(1, OUT, T_B, False) == [101, 104];
        assert g.refs(1, OUT, T_C, True) == [503, 506];
        assert g.refs(1, OUT, -1, False) == [100 + i for i in range(7)];
        assert g.refs(1, IN, T_A, False) == [];
        assert g.refs(102, IN, T_A, False) == [1];
        assert g.refs(102, IN, T_B, False) == [];
        assert g.refs(1, OUT, 9200199, False) == [];
    }
}

test "a base-tag hop merges its subtype rows back into connect order" {
    for idx in INDEX_AT {
        _register();
        g = _graph(idx);
        tags = [T_SUB2, T_A, T_BASE, T_SUB1, T_LEAF, T_SUB2, T_SUB1, T_BASE];
        for (i, t) in enumerate(tags) {
            g.connect(1, 100 + i, 500 + i, False, t, 0, 0);
        }
        assert g.refs(1, OUT, T_BASE, False) == [100, 102, 103, 104, 105, 106, 107];
        assert g.refs(1, OUT, T_SUB1, False) == [103, 104, 106];
        assert g.refs(1, OUT, T_LEAF, False) == [104];
        assert g.refs(1, OUT, T_SUB2, True) == [500, 505];
        # Incoming side: several sources pointing at one sink.
        for (i, t) in enumerate(tags) {
            g.connect(200 + i, 2, 600 + i, False, t, 0, 0);
        }
        assert g.refs(2, IN, T_BASE, False) == [200, 202, 203, 204, 205, 206, 207];
        assert g.disconnect_between(1, 103, OUT, T_BASE) == 1;
        assert g.disconnect_between(1, 101, OUT, T_BASE) == 0;
        assert g.refs(1, OUT, T_BASE, False) == [100, 102, 104, 105, 106, 107];
        assert g.refs(1, OUT, T_SUB1, False) == [104, 106];
    }
}

test "undirected rows answer both directions; outgoing rows come first" {
    for idx in INDEX_AT {
        g = _graph(idx);
        g.connect(1, 10, 501, False, T_A, 0, 0);
        g.connect(11, 1, 502, True, T_A, 0, 0);
        g.connect(12, 1, 503, False, T_A, 0, 0);
        g.connect(1, 13, 504, True, T_A, 0, 0);
        g.connect(1, 14, 505, False, T_B, 0, 0);
        assert g.refs(1, OUT, T_A, False) == [10, 13, 11];
        assert g.refs(1, IN, T_A, False) == [13, 11, 12];
        assert g.refs(1, ANY, T_A, False) == [10, 13, 11, 12];
        assert g.refs(1, ANY, -1, False) == [10, 13, 14, 11, 12];
        assert g.refs(11, OUT, T_A, False) == [1];
        assert g.refs(11, IN, T_A, False) == [1];
        assert g.refs(13, OUT, T_A, True) == [504];
        assert g.refs(13, OUT, T_B, False) == [];
        # A backward disconnect-between reaches an undirected row stored
        # outgoing, and leaves the directed rows alone.
        assert g.disconnect_between(13, 1, OUT, T_A) == 1;
        assert g.refs(1, ANY, T_A, False) == [10, 11, 12];
        assert g.disconnect_between(1, 12, OUT, T_A) == 0;
        assert g.disconnect_between(1, 12, IN, T_A) == 1;
        assert g.refs(1, ANY, -1, False) == [10, 14, 11];
    }
}

test "parallel edges and self loops dedupe peers but not edges" {
    for idx in INDEX_AT {
        g = _graph(idx);
        g.connect(1, 2, 501, False, T_A, 0, 0);
        g.connect(1, 3, 502, False, T_B, 0, 0);
        g.connect(1, 2, 503, False, T_A, 0, 0);
        g.connect(1, 1, 504, False, T_A, 0, 0);
        assert g.refs(1, OUT, T_A, False) == [2, 1];
        assert g.refs(1, OUT, T_A, True) == [501, 503, 504];
        assert g.refs(1, ANY, T_A, True) == [501, 503, 504];
        assert g.refs(1, IN, T_A, False) == [1];
        assert g.refs_many([1, 2], ANY, T_A, False) == [2, 1];
        assert g.disconnect_between(1, 1, ANY, T_A) == 1;
        assert g.disconnect_between(1, 2, OUT, -1) == 2;
        assert g.refs(1, ANY, -1, True) == [502];
    }
}

test "peers dedupe to first occurrences for small and large results" {
    for idx in INDEX_AT {
        for (edges, peers) in [(10, 4), (16, 16), (17, 9), (60, 23)] {
            g = _graph(idx);
            want: list[int] = [];
            for i in range(edges) {
                p = 100 + (i * 7) % peers;
                g.connect(1, p, 1000 + i, False, T_A if i % 3 else T_B, 0, 0);
                if p not in want {
                    want.append(p);
                }
            }
            g.connect(100, 1, 999, False, T_A, 0, 0);
            assert g.refs(1, OUT, -1, False) == want;
            assert g.refs(1, ANY, -1, False) == want;
            assert g.refs(1, OUT, -1, True) == [1000 + i for i in range(edges)];
            assert g.refs_many([1, 1], OUT, -1, False) == want;
            assert g.refs(1, IN, -1, False) == [100];
        }
    }
}

test "removal keeps survivors in order and freed rows rejoin at the end" {
    for idx in INDEX_AT {
        g = _graph(idx);
        n = 400;
        for i in range(n) {
            g.connect(1, 1000 + i, 5000 + i, False, T_A if i % 3 else T_B, 0, 0);
        }
        kept: list[int] = [];
        for i in range(n) {
            if i % 4 == 1 or i > 300 {
                assert g.disconnect(5000 + i);
            } else {
                kept.append(i);
            }
        }
        assert g.refs(1, OUT, -1, False) == [1000 + i for i in kept];
        assert g.refs(1, OUT, T_A, False)
            == [
                1000 + i
                for i in kept
                if i % 3
            ];
        assert g.refs(1, OUT, T_B, True)
            == [
                5000 + i
                for i in kept
                if i % 3 == 0
            ];
        for i in kept {
            assert g.refs(1000 + i, IN, -1, True) == [5000 + i];
        }
        assert len(g.free_rows) == n - len(kept);
        # Fresh connects reuse freed rows yet still land after every survivor.
        for j in range(50) {
            g.connect(1, 9000 + j, 9500 + j, False, T_B, 0, 0);
        }
        assert len(g.free_rows) == n - len(kept) - 50;
        assert g.refs(1, OUT, T_B, False)
            == [
                1000 + i
                for i in kept
                if i % 3 == 0
            ]
                + [9000 + j for j in range(50)];
        assert g.refs(1, OUT, -1, False)
            == [1000 + i for i in kept] + [9000 + j for j in range(50)];
        # Emptying a tag drops it; later rows of that tag start a fresh list.
        for i in kept {
            if i % 3 {
                g.disconnect(5000 + i);
            }
        }
        assert g.refs(1, OUT, T_A, False) == [];
        g.connect(1, 7777, 7778, False, T_A, 0, 0);
        assert g.refs(1, OUT, T_A, False) == [7777];
        assert g.refs(1, OUT, -1, False)[-1] == 7777;
    }
}

test "destroying a peer or a region unlinks it from the hub's typed lists" {
    for idx in INDEX_AT {
        g = _graph(idx);
        for i in range(20) {
            g.connect(1, 100 + i, 500 + i, False, T_A if i % 2 else T_B, 0, 0);
        }
        assert g.node_destroy(103) == 1;
        assert g.node_destroy(104) == 1;
        assert g.refs(1, OUT, T_A, False)
            == [
                100 + i
                for i in range(20)
                if i % 2 and i != 3
            ];
        assert g.refs(1, OUT, T_B, False)
            == [
                100 + i
                for i in range(20)
                if i % 2 == 0 and i != 4
            ];
        assert g.refs(103, IN, -1, False) == [];
        assert g.connect(1, 103, 999, False, T_A, 0, 0) == -1;
        assert g.drop_node(1) == 18;
        assert g.refs(105, IN, T_A, False) == [];

        r = _graph(idx);
        r.connect(1, 2, 601, False, T_A, 0, 7);
        r.connect(3, 1, 602, False, T_B, 7, 0);
        r.connect(1, 4, 603, False, T_A, 0, 0);
        assert r.region_died(7) == 2;
        assert r.refs(1, ANY, -1, False) == [4];
        assert r.refs(1, OUT, T_A, False) == [4];
        assert r.refs(1, IN, T_B, False) == [];
        r.connect(1, 5, 604, False, T_B, 0, 0);
        assert r.refs(1, ANY, -1, True) == [603, 604];
    }
}

"""The rows the old full scan returned, from a plain ordered edge list."""
def _model_refs(
    edges: list[tuple[int, int, int, int, bool]],
    dead: set[int],
    origin: int,
    dir: int,
    want: int,
    eo: bool
) -> list[int] {
    out: list[int] = [];
    seen: set[int] = set();
    if origin in dead {
        return out;
    }
    for (eid, s, t, tag, und) in edges {
        if s == origin
            and (dir in (2, 3) or und)
            and (want == -1 or _g.osp_is_a(tag, want)) {
            o = eid if eo else t;
            if o not in seen {
                seen.add(o);
                out.append(o);
            }
        }
    }
    for (eid, s, t, tag, und) in edges {
        if t == origin
            and (dir in (1, 3) or und)
            and (want == -1 or _g.osp_is_a(tag, want)) {
            o = eid if eo else s;
            if o not in seen {
                seen.add(o);
                out.append(o);
            }
        }
    }
    return out;
}

test "random connects and removals match an ordered edge-list model" {
    _register();
    tag_pool = [T_A, T_B, T_C, T_BASE, T_SUB1, T_SUB2, T_LEAF, -1];
    queries = [-1, T_A, T_B, T_BASE, T_SUB1, T_SUB2, T_LEAF];
    for seed in range(9) {
        rng = random.Random(seed);
        g = _graph(INDEX_AT[seed % 3]);
        edges: list[tuple[int, int, int, int, bool]] = [];
        dead: set[int] = set();
        nodes = list(range(1, 9));
        next_eid = 10000;
        for step in range(900) {
            op = rng.random();
            if op < 0.55 or not edges {
                s = rng.choice(nodes);
                t = rng.choice(nodes);
                tag = rng.choice(tag_pool);
                und = rng.random() < 0.15;
                next_eid += 1;
                res = g.connect(s, t, next_eid, und, tag, 0, 0);
                if s in dead or t in dead {
                    assert res == -1;
                } else {
                    assert res == t;
                    edges.append((next_eid, s, t, tag, und));
                }
            } elif op < 0.8 {
                victim = rng.choice(edges);
                assert g.disconnect(victim[0]);
                edges.remove(victim);
            } elif op < 0.97 {
                s = rng.choice(nodes);
                t = rng.choice(nodes);
                dir = rng.choice([1, 2, 3]);
                want = rng.choice(queries);
                gone = [
                    e
                    for e in edges
                    if (want == -1 or _g.osp_is_a(e[3], want))
                        and (
                            (e[1] == s and e[2] == t and (dir in (2, 3) or e[4]))
                            or (e[1] == t and e[2] == s and (dir in (1, 3) or e[4]))
                        )
                ];
                assert g.disconnect_between(s, t, dir, want) == len(gone);
                edges = [
                    e
                    for e in edges
                    if e not in gone
                ];
            } else {
                h = rng.choice(nodes);
                g.node_destroy(h);
                dead.add(h);
                edges = [
                    e
                    for e in edges
                    if e[1] != h and e[2] != h
                ];
            }
            if step % 7 == 0 or step > 880 {
                for h in nodes {
                    for dir in [1, 2, 3] {
                        for want in queries {
                            for eo in [False, True] {
                                got = g.refs(h, dir, want, eo);
                                exp = _model_refs(edges, dead, h, dir, want, eo);
                                assert got == exp , (
                                    f"seed {seed} step {step}: refs({h}, {dir}, "
                                    f"{want}, {eo}) = {got}, model {exp}"
                                );
                            }
                        }
                    }
                }
            }
        }
        assert len(g.rows) - len(g.free_rows) == len(edges);
        assert len(g.row_of) == len(edges);
    }
}

"""Wall time of `reps` typed hops of a one-edge tag on a hub of `degree` edges."""
def _rare_hop_cost(degree: int, reps: int) -> float {
    g = _graph();
    for i in range(degree) {
        g.connect(1, 100000 + i, 200000 + i, False, T_A + i % 3, 0, 0);
    }
    g.connect(1, 99, 199, False, T_C + 1, 0, 0);
    t0 = time.perf_counter();
    for _ in range(reps) {
        assert g.refs(1, OUT, T_C + 1, False) == [99];
    }
    return time.perf_counter() - t0;
}

test "a typed hop does not pay for the hub's other edge types" {
    small = min(_rare_hop_cost(64, 400) for _ in range(3));
    large = min(_rare_hop_cost(8192, 400) for _ in range(3));
    assert large < small * 8 , (
        f"a rare-type hop on a 128x larger hub cost {large / small:.1f}x"
    );
}

test "unlinking from a high-degree hub is not linear in its degree" {
    for n in [500, 4000] {
        g = _graph();
        for i in range(n) {
            g.connect(1, 100000 + i, 200000 + i, False, T_A, 0, 0);
        }
        t0 = time.perf_counter();
        for i in reversed(range(n)) {
            g.disconnect(200000 + i);
        }
        per = (time.perf_counter() - t0) / n;
        if n == 500 {
            base = per;
        } else {
            assert per < base * 4 , f"per-unlink cost grew {per
                / base:.1f}x for 8x degree";
        }
        assert g.refs(1, OUT, -1, False) == [];
    }
}
