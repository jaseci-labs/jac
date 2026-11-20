"""Graph refs through an unbounded class value, and any/all results, match Python.

A traversal whose edge class is an unbounded `type` value has no static
endpoint, so its elements are typed `any`. Native used to keep those
elements as raw integer handles: `t is old` folded to False against a
node pointer and `==`/`in` refused to lower. The refs now carry the node
handle representation (the builtin `Node` layout bound), so identity,
equality and membership compare the same object addresses a bounded
traversal does. `any()` and `all()` return real booleans, so they render
as `True`/`False` rather than `1`/`0`.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "unbounded edge refs keep identity and any/all render as bools" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "unbounded_edge_refs.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    assert "['BodyRole', 'ExprRole'] [3] [2]" in out , out;
    assert "unbounded [True] [True] [True] True False 1" in out , out;
}
