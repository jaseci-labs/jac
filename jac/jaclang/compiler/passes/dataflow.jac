import from typing { TypeAlias }
import from jaclang.compiler.frontend.unitree { UniCFGNode }

glob SymId: TypeAlias = int,
     DataflowTransfer: TypeAlias = Callable[[UniCFGNode, set[SymId]], set[SymId]];

def _state_at(state: dict[int, set[SymId]], key: int) -> set[SymId] {
    _cur = state.get(key);
    if _cur is None {
        _empty: set[SymId] = set();
        return _empty;
    }
    return _cur;
}

def solve_forward(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        _seed: set[SymId] = set();
        state[id(n)] = _seed;
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_state: set[SymId] = set();
        for pred in n.bb_in {
            for x in transfer(pred, _state_at(state, id(pred))) {
                new_state.add(x);
            }
        }
        if new_state != _state_at(state, id(n)) {
            state[id(n)] = new_state;
            for nb in n.bb_out {
                worklist.append(nb);
            }
        }
    }
    return state;
}

def solve_forward_must(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer, universe: set[SymId]
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        state[id(n)] = set() if not n.bb_in else set(universe);
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        if not n.bb_in {
            continue;
        }
        new_state: set[SymId] | None = None;
        for pred in n.bb_in {
            pred_out = transfer(pred, _state_at(state, id(pred)));
            new_state = set(pred_out) if new_state is None else new_state & pred_out;
        }
        if new_state is not None and new_state != _state_at(state, id(n)) {
            state[id(n)] = new_state;
            for nb in n.bb_out {
                worklist.append(nb);
            }
        }
    }
    return state;
}

def solve_backward_gen_kill(
    cfg_nodes: list[UniCFGNode], gen: dict[int, set[SymId]], kill: dict[int, set[SymId]]
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        _seed: set[SymId] = set();
        state[id(n)] = _seed;
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        _key = id(n);
        new_state: set[SymId] = set();
        for x in _state_at(gen, _key) {
            new_state.add(x);
        }
        _kill = _state_at(kill, _key);
        for succ in n.bb_out {
            for x in _state_at(state, id(succ)) {
                if x not in _kill {
                    new_state.add(x);
                }
            }
        }
        if new_state != _state_at(state, _key) {
            state[_key] = new_state;
            for nb in n.bb_in {
                worklist.append(nb);
            }
        }
    }
    return state;
}

def solve_backward(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        _seed: set[SymId] = set();
        state[id(n)] = _seed;
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        joined: set[SymId] = set();
        for succ in n.bb_out {
            for x in _state_at(state, id(succ)) {
                joined.add(x);
            }
        }
        new_state = transfer(n, joined);
        if new_state != _state_at(state, id(n)) {
            state[id(n)] = new_state;
            for nb in n.bb_in {
                worklist.append(nb);
            }
        }
    }
    return state;
}
