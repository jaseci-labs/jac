"""Managed native nodes and edges are reclaimed once nothing refers to them.
A live edge row pins both endpoints and its edge object, so a connected
subgraph stays alive until it is disconnected or destroyed. Nodes and edges
used to be immortal, so a program that built and dropped graphs (a game
loading level after level) kept every node, edge and everything they held
for its whole run, even after destroying them."""

import ctypes;
import from tests.support { compile_native, get_func }

glob fixture = "graph_reclaim.jac";

def call(name: str, *args: int) -> int {
    (engine, _) = compile_native(fixture);
    fn = get_func(engine, name, ctypes.c_int64, *[ctypes.c_int64 for _ in args]);
    return fn(*args);
}

test "a node never connected is freed with its last reference" {
    got = call("loose", 5);
    assert got == 5 , str(got);
}

test "connected nodes stay alive while the graph holds them" {
    got = call("held", 4);
    assert got == 10 , str(got);
}

test "disconnecting frees a target and edge nothing else refers to" {
    got = call("cut", 3);
    assert got == 33 , str(got);
}

test "a variable keeps a disconnected node alive" {
    got = call("kept_by_variable");
    assert got == 51 , str(got);
}

test "destroying a subgraph reclaims its nodes and edges" {
    got = call("destroy_tree", 3);
    assert got == 706 , str(got);
}

test "a walk keeps nodes it queued alive when an ability cuts them loose" {
    got = call("walk_cut");
    assert got == 321 , str(got);
}

test "a walk over a chain visits each node once and frees nothing" {
    got = call("tour", 5);
    assert got == 601 , str(got);
}

test "edge objects read back from the graph stay valid while held" {
    got = call("edges_held");
    assert got == 701 , str(got);
}

test "a reused node address starts with a clean graph entry" {
    got = call("reuse", 4);
    assert got == 4 , str(got);
}

test "a connected subgraph keeps itself alive until it is destroyed" {
    got = call("destroyed_tree", 5);
    assert got == 99 , str(got);
}

test "destroying a subgraph reclaims its nodes and edges" {
    got = call("teardown_tree", 5);
    assert got == 11010 , str(got);
}

test "an edge keeps its source reachable from the target" {
    got = call("backward_reach");
    assert got == 150 , str(got);
}

test "a node two parents point to lives until both edges are gone" {
    got = call("shared_child");
    assert got == 301 , str(got);
}

test "a program destroying each world before the next keeps only the current one" {
    got = call("levels", 20);
    assert got == 1920100 , str(got);
}

test "graph operations release temporary nodes" {
    got = call("temporaries_released");
    assert got == 11111 , str(got);
}
