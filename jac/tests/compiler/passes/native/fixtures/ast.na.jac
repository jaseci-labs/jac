"""Fixture for import-name-shadows-stdlib fix test.

This module is intentionally named 'ast' to collide with Python's stdlib
ast module.  Before the fix, _register_imported_struct_types called
resolve_relative_path() which returned the typeshed ast.pyi stub; since
the path ended in .pyi (not .jac) the module was silently skipped, its
struct was never registered, and any call passing list[Node] crashed with
TypeError: Type of #0 arg mismatch: i64 != %"List.i64"*.

After the fix _resolve_nm checks for a local .na.jac file directly via
os.path.join(base_dir, ...) — stdlib stubs can no longer shadow it.
"""

obj:pub Node {
    has kind: int;
    has value: int;
}

def:pub make_node(kind: int, value: int) -> Node {
    n = Node();
    n.kind = kind;
    n.value = value;
    return n;
}

def:pub node_kind(n: Node) -> int {
    return n.kind;
}

"""Sum of .kind for every node in the list — list[Node] param exercises
the struct-registration path that was broken by the stdlib shadow."""
def:pub collect_kinds(nodes: list[Node]) -> int {
    total: int = 0;
    for nd in nodes {
        total = total + nd.kind;
    }
    return total;
}

with entry {}
