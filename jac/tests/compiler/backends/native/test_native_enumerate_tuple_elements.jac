"""A tuple taken out of a list by `enumerate` is a tuple, not a string.

A list keeps each tuple element boxed, as a pointer to the tuple's struct.
`enumerate(raw)` paired the index with that raw pointer, and the loop bound
`member` to it as an `i8*`, so `member[0]` compiled as a C-string index: a
garbage name, or "string index out of range". The kernel's layout pass hit
it on every enum without explicit values, built by
`for (ordinal, member) in enumerate(raw_members)`. Each unpacked field is
now retyped to its target's tuple type, as an indexed or plain loop does.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "enumerate and zip over lists of tuples bind tuples" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "enumerate_tuple_elements.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-2] == "6 WORK 7 BUNCH Y" , out;
}
