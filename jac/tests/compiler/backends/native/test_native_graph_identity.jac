"""`jid` and bound endpoints over reclaimable native nodes and edges. The
graph kernel keeps a jid per live object, so the entry has to go wherever the
object's address is retired: a node or edge freed by its last reference, by a
disconnect, or with its region. Otherwise the next object allocated at that
address would answer with the dead one's id."""

import ctypes;
import from tests.support { compile_native, get_func, native_address }

glob fixture = "graph_identity.jac";

def call(name: str, *args: int) -> int {
    (engine, _) = compile_native(fixture);
    fn = get_func(engine, name, ctypes.c_int64, *[ctypes.c_int64 for _ in args]);
    return fn(*args);
}

test "a node never connected takes its jid with it" {
    got = call("loose_ids", 6);
    assert got == 6 , str(got);
}

test "a node cut loose and freed takes its jid with it" {
    got = call("cut_ids", 6);
    assert got == 6 , str(got);
}

test "an edge freed by a disconnect takes its jid with it" {
    got = call("edge_ids", 6);
    assert got == 6006 , str(got);
}

test "an edge never connected takes its jid with it" {
    got = call("loose_edge_ids", 6);
    assert got == 6 , str(got);
}

test "a jid stays with a held node and edge across a disconnect" {
    got = call("stable_while_held");
    assert got == 110 , str(got);
}

test "a bound endpoint holds only the results it returns" {
    got = call("endpoint_balance", 3);
    assert got == 270033 , str(got);
}

test "edges a bound endpoint returned stay valid while held" {
    got = call("endpoint_edges_held");
    assert got == 701 , str(got);
}

test "bound endpoints and jid release temporary operands" {
    got = call("temporaries_released");
    assert got == 12311 , str(got);
}

test "a region's nodes and edges take their jids with the region" {
    got = call("region_ids", 6);
    assert got == 606 , str(got);
}

test "a tuple or set endpoint is refused instead of being read as a list" {
    (engine, _) = compile_native("graph_identity_refused.jac");
    got = get_func(engine, "list_end", ctypes.c_int64)();
    assert got == 2 , str(got);
    assert native_address(engine, "tuple_end") == 0 , "tuple endpoint lowered";
    assert native_address(engine, "set_end") == 0 , "set endpoint lowered";
}
