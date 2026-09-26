import from jaclang.compiler.frontend.roles { Kid }
import jaclang.compiler.frontend.unitree as uni;

def unparse_node(nd: uni.UniNode) -> str {
    if nd.gen.jac {
        return nd.gen.jac;
    }
    if isinstance(nd, uni.Token) {
        return nd.value;
    }
    _kids = list([nd->:Kid:->]);
    if not _kids and isinstance(nd, uni.JsxText) and isinstance(nd.value, str) {
        return nd.value;
    }
    return ' '.join([unparse_node(i) for i in _kids]);
}
