"""Natively compiled typed hops keep their order on mixed-type nodes.

The OSP adjacency store answers a typed hop such as `[hub->:Heavy:->]` from a
per-edge-tag index instead of scanning every edge of the origin node. The
fixture pins what the index must not change for compiled code: a base edge
type still gathers its subtypes' edges in connect order, exact and untyped
hops keep connect order, removals (`hub del --> n`) keep the survivors'
order and later connects land after them, undirected edges answer both
directions, and a walker's `visit` follows the same order. The expected
values are what the full-scan store produced before the index existed.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_mir, compile_native, native_address }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "osp_typed_adjacency.jac";

glob _MEMO: list[any] = [];

"""JIT the fixture once and return its engine."""
def engine -> any {
    if _MEMO {
        return _MEMO[0];
    }
    (eng, _fx) = compile_native(os.path.join(FIXTURES, FIXTURE));
    _MEMO.append(eng);
    return eng;
}

"""Call a no-argument fixture function through the JIT."""
def answer(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"function '{name}' is not in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

test "the typed-adjacency fixture lowers natively" {
    fx = compile_mir(os.path.join(FIXTURES, FIXTURE));
    assert not fx.demoted() , f"the fixture must lower natively: {fx.demoted()}";
    assert engine() is not None , "no JIT engine was produced for the fixture";
}

test "a base edge type gathers its subtypes in connect order" {
    eng = engine();
    assert answer(eng, "base_hop_merges_subtypes") == 1345;
}

test "exact and untyped hops keep connect order" {
    eng = engine();
    assert answer(eng, "exact_hops") == 1526007;
    assert answer(eng, "untyped_hop") == 1234567;
}

test "removals keep survivors in order and new edges follow them" {
    eng = engine();
    assert answer(eng, "removal_and_reuse") == 357926807;
    for _ in range(3) {
        assert answer(eng, "many_edges_one_rare") == 123206;
    }
}

test "undirected edges answer typed hops in both directions" {
    eng = engine();
    assert answer(eng, "undirected_both_ways") == 2334101;
}

test "a walker visits a typed hop in connect order" {
    eng = engine();
    assert answer(eng, "visit_order") == 1345;
}
