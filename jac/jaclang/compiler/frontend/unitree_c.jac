"""C semantic surface in UniTree.

These nodes preserve C operations until target-aware semantic lowering exists.
They must not be passed directly to Jac code generation: in particular a C
integer, pointer operation or assignment expression is not a Jac equivalent.
"""
import from .unitree { UniNode, Token }
import from .roles { ChildrenRole }

node CNode(UniNode) {
    has kind: str postinit,
        value: str postinit;

    def init(kind: str, anchor: Token, children: list[CNode] = [],
             value: str = "", end: Token | None = None) {
        self.kind = kind;
        self.value = value;
        kids: list[UniNode] = [anchor];
        kids.extend(children);
        if end is not None { kids.append(end); }
        self._link(kids, {ChildrenRole: children});
        UniNode.postinit(self);
    }

    has operands: list[CNode] {
        getter {
            return [child for child in self.kid if isinstance(child, CNode)];
        }
    }
}

node CTranslationUnit(CNode) {}
node CPreprocessingUnit(CNode) {}
node CDeclaration(CNode) {}
node CTypeSpec(CNode) {}
node CDeclarator(CNode) {}
node CExpression(CNode) {}
node CStatement(CNode) {}

# Compile-time preprocessing operations retain inactive branches and tokens.
# They are deliberately distinct from evaluated Jac comptime expressions.
node CPreprocessorDirective(CNode) {
    has active: bool = True;
}

node CPreprocessorText(CNode) {
    has active: bool = True;
}

node CPreprocessorToken(CNode) {
    has leading_space: bool = False;
}
