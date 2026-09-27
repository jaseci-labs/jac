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
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR, native_address, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "osp_typed_adjacency.jac";

glob _MEMO: list[any] = [];

"""Compile the fixture once and return (coverage record, errors, engine)."""
def measured -> tuple[any, ...] {
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    na_coverage_begin();
    ir = None;
    try {
        ir = prog.compile(file_path=path, options=native_force_opts());
    } finally {
        coverage = na_coverage_end();
    }
    errors = [str(e) for e in (prog.errors_had or [])];
    rec = coverage.get(os.path.realpath(path)) or coverage.get(path);
    out = (rec, errors, (ir.gen.native_engine if ir is not None else None), );
    _MEMO.append(out);
    return out;
}

"""Call a no-argument fixture function through the JIT."""
def answer(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"function '{name}' is not in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

test "the typed-adjacency fixture lowers natively" {
    (rec, errors, eng) = measured();
    assert not errors , f"the fixture must compile: {errors}";
    assert rec is not None , "the fixture produced no native coverage record";
    assert rec.get("outcome") == "native" , (
        f"the fixture must lower natively, got {rec.get('outcome')}: "
        f"{rec.get('code')} {rec.get('detail')}"
    );
    assert eng is not None , "no JIT engine was produced for the fixture";
}

test "a base edge type gathers its subtypes in connect order" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "base_hop_merges_subtypes") == 1345;
}

test "exact and untyped hops keep connect order" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "exact_hops") == 1526007;
    assert answer(eng, "untyped_hop") == 1234567;
}

test "removals keep survivors in order and new edges follow them" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "removal_and_reuse") == 357926807;
    for _ in range(3) {
        assert answer(eng, "many_edges_one_rare") == 123206;
    }
}

test "undirected edges answer typed hops in both directions" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "undirected_both_ways") == 2334101;
}

test "a walker visits a typed hop in connect order" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "visit_order") == 1345;
}
