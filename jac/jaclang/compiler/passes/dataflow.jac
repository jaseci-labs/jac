type SymId = int;
type DataflowTransfer = Callable[[UniCFGNode, set[SymId]], set[SymId]];

def _state_at(state: dict[int, set[SymId]], key: int) -> set[SymId];

def solve_forward(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]];

def solve_forward_must(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer, universe: set[SymId]
) -> dict[int, set[SymId]];

def solve_backward_gen_kill(
    cfg_nodes: list[UniCFGNode], gen: dict[int, set[SymId]], kill: dict[int, set[SymId]]
) -> dict[int, set[SymId]];

def solve_backward(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]];
