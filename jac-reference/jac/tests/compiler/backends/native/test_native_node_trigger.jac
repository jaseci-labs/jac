"""`with Node entry` in a walker matched no node natively (it ran once, like
a bare `with entry`), and `Node`-typed collections compared nodes as
strings. The trigger now matches every node and `Node` lowers to an opaque
reference."""

import ctypes;
import from tests.support { compile_native, get_func }

def call(name: str) -> int {
    (engine, _) = compile_native("node_trigger.jac");
    return get_func(engine, name, ctypes.c_int64)();
}

test "a Node-triggered walker ability runs at every node" {
    got = call("sweep");
    assert got == 103 , str(got);
}

test "nodes held as Node keep their identity in collections" {
    got = call("identity");
    assert got == 111111 , str(got);
}
