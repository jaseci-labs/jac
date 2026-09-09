"""Differential identity over the everyday owned-code shapes of #8984.

Each fixture is an ordinary program written against the ownership surface. It
is built headerless (`nogc`), under plain reference counting, under the cycle
collector, and run on the Python backend, and every output must agree byte
for byte with the Python backend's. That agreement is the erasure contract of
the design: annotations never change behavior, and a zero-RC build behaves
exactly like a managed one. Drop hooks in the fixtures make lifetimes part of
the output, so a leak, a double drop, or a read of freed memory shows up as a
diff rather than luck.

ownbench's kernels are the other differential surface; these fixtures cover
the shapes those kernels do not: optional own-field moves, owned-parameter
drops, `pop()` on owned lists, subclass elements, borrow returns, generics.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "nogc_identity"
     );

def _fixture(name: str) -> str {
    return os.path.join(FIXTURES, name);
}

test "cleanup tolerates an owned local whose branch was not entered" {
    out = assert_native_identity(_fixture("branch_cleanup.jac"));
    assert out.splitlines() == ["1", "drop 1", "2", "drop 2", "1", "drop 1"];
}

test "runtime errors propagate through Jac calls without an unwinder" {
    out = assert_native_identity(_fixture("runtime_errors.jac"));
    assert out.splitlines()
        == ["bounds caught", "bounds finalized", "assertion caught"];
}

test "finalizers run on returns, breaks and continues" {
    out = assert_native_identity(_fixture("finally_exits.jac"));
    assert out.splitlines()
        == ["inner", "outer", "7", "0", "1", "after loop", "after try"];
}

test "error propagation preserves pending errors and finalizes handlers" {
    out = assert_native_identity(_fixture("error_nested.jac"));
    assert out.splitlines()
        == [
            "temporary handled",
            "inner finally",
            "original handled",
            "handler finally",
            "replacement handled",
            "reraised"
        ];
}

test "a named own local moved into an optional own field is owned by the field" {
    out = assert_native_identity(_fixture("optfield_move.jac"));
    assert out.splitlines()
        == [
            "a.next.v=2",
            "h.slot.v=3",
            "drop node 3",
            "drop node 1",
            "drop node 2",
            "done"
        ] , out;
}

test "a named own local moved into an inline-flattened own field drops once" {
    out = assert_native_identity(_fixture("inline_field_move.jac"));
    assert out.splitlines()
        == ["drop node 0", "h.slot.v=2", "drop node 2", "done"] , out;
}

test "an owned singly linked list with take() and swap() behaves identically" {
    out = assert_native_identity(_fixture("linked_list.jac"));
    assert out.strip() == "10409" , out;
}

test "own parameters are dropped by the callee and own returns by the receiver" {
    out = assert_native_identity(_fixture("own_param_drop.jac"));
    assert out.splitlines() == ["drop job 1", "drop job 7", "8", "done"] , out;
}

test "pop() on a list[own T] hands the element to the receiver" {
    out = assert_native_identity(_fixture("pop_owned.jac"));
    assert out.splitlines() == ["drop 3", "drop 2", "drop 1", "6", "done"] , out;
}

test "subclass instances in a list[own Base] keep their layout and dispatch" {
    out = assert_native_identity(_fixture("subclass_owned_list.jac"));
    assert out.strip() == "1010" , out;
}

test "a borrow of a list element returned under -> &T reads the element" {
    out = assert_native_identity(_fixture("elem_borrow_return.jac"));
    assert out.strip() == "9" , out;
}

test "a generic over a borrowed list returns a borrow of the element" {
    out = assert_native_identity(_fixture("generic_elem.jac"));
    assert out.strip() == "77" , out;
}

test "pop, insert, del, index-assign and extend on a list of owned elements" {
    out = assert_native_identity(_fixture("owned_list_ops.jac"));
    assert out.splitlines()
        == [
            "popped 1 -> 0,2,3,4",
            "drop 1",
            "inserted -> 9,0,2,3,4",
            "drop 2",
            "deleted -> 9,0,3,4",
            "drop 9",
            "assigned -> 7,0,3,4",
            "extended -> 7,0,3,4,11,12",
            "drop 12",
            "drop 11",
            "drop 4",
            "drop 3",
            "drop 0",
            "drop 7",
            "6",
            "done"
        ] , out;
}

test "a self: own method consumes and drops its receiver exactly once" {
    out = assert_native_identity(_fixture("own_self_method.jac"));
    assert out.splitlines() == ["drop counter 2", "22", "done"] , out;
}

test "views over a borrowed list never own its elements" {
    out = assert_native_identity(_fixture("view_cursor.jac"));
    assert out.splitlines()
        == [
            "drop item 4",
            "drop item 3",
            "drop item 2",
            "drop item 1",
            "123406",
            "done"
        ] , out;
}

test "owned archetype values in a dict: overwrite, pop, del and the dict drop" {
    out = assert_native_identity(_fixture("owned_dict_values.jac"));
    assert out.splitlines()
        == [
            "drop 1",
            "a=10",
            "popped=2",
            "drop 10",
            "sink 2",
            "drop 2",
            "drop 3",
            "1",
            "done"
        ] , out;
}

test "named own archetypes move into append, insert, a dict store and a list literal" {
    out = assert_native_identity(_fixture("named_move_containers.jac"));
    assert out.splitlines()
        == [
            "xs=21",
            "m=34",
            "ys=5",
            "sink 1",
            "drop 1",
            "sink 4",
            "drop 4",
            "drop 3",
            "sink 5",
            "drop 5",
            "drop 2",
            "2",
            "done"
        ] , out;
}

test "a lin binding lowers exactly like own in every memory mode" {
    out = assert_native_identity(_fixture("lin_handle.jac"));
    assert out.splitlines() == ["using 7", "close 7", "drop 7", "1", "done"] , out;
}

test "raise propagates through the hidden error slot with static drops and finally" {
    out = assert_native_identity(_fixture("error_slot.jac"));
    assert out.splitlines()
        == ["drop 1", "81", "drop 1", "8080", "caught", "finally", "done"] , out;
}

test "inferred local states never change behavior" {
    out = assert_native_identity(_fixture("local_inference.jac"));
    assert out.splitlines()
        == [
            "a,b,c a1 yes svc 2",
            "15",
            "drop cfg",
            "a!",
            "b",
            "x,X,y,Y",
            "4",
            "012",
            "drop item 2",
            "drop item 1"
        ];
}
