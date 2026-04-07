"""Entry fixture for import-name-shadows-stdlib fix test.

Imports from a module named 'ast' — a Python stdlib name.  Before the fix
this silently dropped struct registration for ast.na.jac, causing a
TypeError crash when collect_kinds (list[Node] param) was compiled.

Expected: run_shadow_test() returns 3  (node kinds 1 + 2).
"""

import from ast { Node, make_node, collect_kinds }

def:pub run_shadow_test() -> int {
    nodes: list[Node] = [];
    nodes.append(make_node(1, 10));
    nodes.append(make_node(2, 20));
    return collect_kinds(nodes);
}

with entry {}
