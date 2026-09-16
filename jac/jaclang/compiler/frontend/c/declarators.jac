"""C declarator topology shared by parsing and semantic analysis."""
import from jaclang.compiler.frontend.unitree_c { CNode }

def declarator_name(nd: CNode) -> str {
    if nd.kind == "name" { return nd.value; }
    children = nd.operands;
    if nd.kind == "declarator" { return declarator_name(children[-1]) if children else ""; }
    if nd.kind in ["group", "array", "function", "attributed"] { return declarator_name(children[0]); }
    return "";
}

# Operators ordered from the declared identifier outward. This distinguishes
# a function returning a pointer from an object pointing to a function.
def derived_operators(nd: CNode) -> list[CNode] {
    children = nd.operands;
    if nd.kind == "declarator" {
        return derived_operators(children[-1]) + list(reversed(children[:-1]));
    }
    if nd.kind == "group" { return derived_operators(children[0]); }
    if nd.kind == "attributed" { return derived_operators(children[0]) + children[1:]; }
    if nd.kind in ["array", "function"] { return derived_operators(children[0]) + [nd]; }
    return [];
}
