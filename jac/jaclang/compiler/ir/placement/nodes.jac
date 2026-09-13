import from jaclang.compiler.ir.identity { GraphNode }
import type from collections.abc { Sequence }
import from jaclang.compiler.ir.enums { CodeContext }

import from jaclang.compiler.ir.base { UniNode }

node ContextAwareNode(UniNode) {
    has codespace_dual: bool = False;
    has code_context: CodeContext { getter; setter(code_context: CodeContext); }

    def init(*, codespace_dual: bool = False, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}


node Codespace(GraphNode) {
    has kind: CodeContext;
}

def codespace_node(kind: CodeContext) -> Codespace {
    return Codespace(kind=kind);
}
