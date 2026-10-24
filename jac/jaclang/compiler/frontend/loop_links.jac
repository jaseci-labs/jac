type LoopStmt = InForStmt | IterForStmt | WhileStmt | ForeverStmt;

obj PassLink {
    has loop: LoopStmt,
        sym: Symbol,
        index: int;
}

obj LoopLinks {
    has by_loop: dict[UniNode, list[PassLink]] = {},
        by_closure: dict[UniNode, list[PassLink]] = {},
        by_name: dict[UniNode, PassLink] = {},
        by_symbol: dict[Symbol, list[PassLink]] = {},
        by_rebind: dict[UniNode, list[Symbol]] = {},
        _local: dict[UniNode, dict[Symbol, bool]] = {},
        _made: int = 0;

    static def of(tree: UniNode) -> LoopLinks;
    def of_loop(loop: UniNode) -> list[PassLink];
    def of_closure(closure: UniNode) -> list[PassLink];
    def of_name(name: UniNode) -> (PassLink | None);
    def of_symbol(sym: Symbol) -> list[PassLink];
    def rebinds_of(closure: UniNode) -> list[Symbol];
    def linked_within(scope: UniNode) -> set[Symbol];
    def _link_closure(closure: UniNode) -> None;
    def _link(loop: LoopStmt, sym: Symbol, closure: UniNode) -> PassLink;
    def _is_local(sym: Symbol, loop: LoopStmt) -> bool;
}


def enclosing_pass_loops(closure: UniNode) -> list[LoopStmt];

def made_in_comprehension(closure: UniNode) -> bool;

def made_per_element(sym: Symbol, closure: UniNode) -> bool;

def enclosing_loop(ctrl: CtrlStmt) -> (LoopStmt | None);

def confined_to(sym: Symbol, loop: LoopStmt) -> bool;

def binds_target(sym: Symbol, loop: LoopStmt) -> bool;

def assigned_on_entry(sym: Symbol, loop: LoopStmt) -> bool;

def frame_owns(frame: UniNode, sym: Symbol) -> bool;

def is_plain_variable(sym: Symbol) -> bool;

def owned_within(sym: Symbol, scope: UniNode) -> bool;

def binding_sites(sym: Symbol) -> list[UniNode];
