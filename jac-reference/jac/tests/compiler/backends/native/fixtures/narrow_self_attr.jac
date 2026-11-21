"""N5: attribute access on a narrowed `self`.

`UniNode.codespace` opened with

    if isinstance(self, ContextAwareNode) {
        if (self.code_context == CodeContext.CLIENT) { ... }
    }

before walking `self.parent` upward. The receiver of the field read is
`self`, narrowed from the declaring class to a subclass that owns the field.
The workaround deleted the whole fast path -- starting the walk at `self`
instead -- and paid for it with a `nd is not self` guard on the loop's other
rule, so that a node which is *both* context-aware and a module keeps the
old answer.

`Mod` inherits from `CtxNode` here for exactly that reason: `pick == 5`
builds a module whose own context is unset, which is the one case where the
two spellings would disagree if the compensating guard were dropped. Both
spellings are compiled and both are checked against sv, so the fixture pins
the equivalence as well as the lowering.
"""

enum Ctx { SERVER = 'server', CLIENT = 'client', NATIVE = 'native' }

obj Node {
    has parent: Node | None = None;

    def space -> int;
    def space_walk_only -> int;
    def ctx_or_zero -> int;
}


obj CtxNode(Node) {
    has code_context: Ctx = Ctx.SERVER;
}


obj Mod(CtxNode) {
    has decided: Ctx = Ctx.SERVER;
}


def _rank(c: Ctx) -> int {
    if c == Ctx.CLIENT {
        return 1;
    }
    if c == Ctx.NATIVE {
        return 2;
    }
    return 0;
}


"""`codespace` with its `self` fast path: a field read off a narrowed `self`."""
impl Node.space -> int {
    if isinstance(self, CtxNode) {
        if self.code_context == Ctx.CLIENT {
            return 1;
        }
        if self.code_context == Ctx.NATIVE {
            return 2;
        }
    }
    nd: (Node | None) = self.parent;
    while nd is not None {
        if isinstance(nd, CtxNode) {
            context = nd.code_context;
            if context == Ctx.CLIENT {
                return 1;
            }
            if context == Ctx.NATIVE {
                return 2;
            }
        }
        if isinstance(nd, Mod) {
            return _rank(nd.decided);
        }
        nd = nd.parent;
    }
    return 0;
}


"""The workaround: start the walk at `self` and guard the module rule."""
impl Node.space_walk_only -> int {
    nd: (Node | None) = self;
    while nd is not None {
        if isinstance(nd, CtxNode) {
            context = nd.code_context;
            if context == Ctx.CLIENT {
                return 1;
            }
            if context == Ctx.NATIVE {
                return 2;
            }
        }
        if isinstance(nd, Mod) and (nd is not self) {
            return _rank(nd.decided);
        }
        nd = nd.parent;
    }
    return 0;
}


"""The narrowed-`self` field read on its own, with no walk after it."""
impl Node.ctx_or_zero -> int {
    if isinstance(self, CtxNode) {
        return _rank(self.code_context);
    }
    return -1;
}


"""Chains that separate the fast path, the walk, and their interaction."""
def _chain(pick: int) -> Node {
    if pick == 1 {
        return Node(parent=Mod(decided=Ctx.NATIVE));
    }
    if pick == 2 {
        return Node(
            parent=CtxNode(code_context=Ctx.CLIENT, parent=Mod(decided=Ctx.NATIVE))
        );
    }
    if pick == 3 {
        return CtxNode(code_context=Ctx.CLIENT, parent=Mod(decided=Ctx.NATIVE));
    }
    if pick == 4 {
        return CtxNode(code_context=Ctx.SERVER, parent=Mod(decided=Ctx.NATIVE));
    }
    if pick == 5 {
        return Mod(code_context=Ctx.SERVER, decided=Ctx.NATIVE);
    }
    if pick == 6 {
        return Mod(code_context=Ctx.CLIENT, decided=Ctx.NATIVE);
    }
    return Node();
}


def space(pick: int) -> int {
    return _chain(pick).space();
}


def space_walk_only(pick: int) -> int {
    return _chain(pick).space_walk_only();
}


def ctx_or_zero(pick: int) -> int {
    return _chain(pick).ctx_or_zero();
}
