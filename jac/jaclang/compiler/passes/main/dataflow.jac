import from collections.abc { Callable }
import from typing { TypeAlias }
import jaclang.jac0core.unitree as uni;

glob DataflowTransfer: TypeAlias = Callable[[uni.UniCFGNode, set], set];

def solve_forward(
    cfg_nodes: list[uni.UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set] {
    state: dict[int, set] = {};
    for n in cfg_nodes {
        state[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_state: set = set();
        for pred in n.bb_in {
            for x in transfer(pred, state.get(id(pred), set())) {
                new_state.add(x);
            }
        }
        if new_state != state.get(id(n), set()) {
            state[id(n)] = new_state;
            for nb in n.bb_out {
                worklist.append(nb);
            }
        }
    }
    return state;
}

def solve_backward(
    cfg_nodes: list[uni.UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set] {
    state: dict[int, set] = {};
    for n in cfg_nodes {
        state[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        joined: set = set();
        for succ in n.bb_out {
            for x in state.get(id(succ), set()) {
                joined.add(x);
            }
        }
        new_state = transfer(n, joined);
        if new_state != state.get(id(n), set()) {
            state[id(n)] = new_state;
            for nb in n.bb_in {
                worklist.append(nb);
            }
        }
    }
    return state;
}
