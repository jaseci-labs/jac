impl _state_at(state: dict[int, set[SymId]], key: int) -> set[SymId] {
    _cur = state.get(key);
    if _cur is None {
        _empty: set[SymId] = set();
        return _empty;
    }
    return _cur;
}

impl solve_forward(
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

impl solve_forward_must(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer, universe: set[SymId]
) -> dict[int, set[SymId]] {
    return solve_forward_must_edges(
        cfg_nodes,
        lambda (nd: UniCFGNode) -> list[UniCFGNode] { return nd.bb_out; },
        [
            n
            for n in cfg_nodes
            if not n.bb_in
        ],
        lambda (pred: UniCFGNode, succ: UniCFGNode, in_set: set[SymId]) -> set[SymId] { return transfer(
            pred, in_set
        ); },
        universe
    );
}

impl solve_forward_must_edges(
    nodes: list[UniCFGNode],
    successors: CfgSuccessors,
    entries: list[UniCFGNode],
    transfer: EdgeTransfer,
    universe: set[SymId]
) -> dict[int, set[SymId]] {
    members: dict[int, UniCFGNode] = {id(n): n for n in nodes};
    succs: dict[int, list[UniCFGNode]] = {};
    preds: dict[int, list[UniCFGNode]] = {id(n): [] for n in nodes};
    for n in nodes {
        inside = [
            s
            for s in successors(n)
            if id(s) in members
        ];
        succs[id(n)] = inside;
        for s in inside {
            preds[id(s)].append(n);
        }
    }
    entry_ids = {id(n) for n in entries};
    state: dict[int, set[SymId]] = {};
    for n in nodes {
        state[id(n)] = set() if id(n) in entry_ids else set(universe);
    }
    worklist = list(nodes);
    while worklist {
        n = worklist.pop();
        key = id(n);
        if key in entry_ids or not preds[key] {
            continue;
        }
        new_state: set[SymId] | None = None;
        for pred in preds[key] {
            pred_out = transfer(pred, n, _state_at(state, id(pred)));
            new_state = set(pred_out) if new_state is None else new_state & pred_out;
        }
        if new_state is not None and new_state != _state_at(state, key) {
            state[key] = new_state;
            for nb in succs[key] {
                worklist.append(nb);
            }
        }
    }
    return state;
}

impl solve_backward_gen_kill(
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

impl solve_backward(
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
