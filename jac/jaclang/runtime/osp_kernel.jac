glob UNTYPED: int = -1;

obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj Plan {
    has ctag: int,
        enter: list[tuple[Slot, bool]],
        leave: list[tuple[Slot, bool]],
        enter_first: bool,
        leave_first: bool;
}

obj WalkerDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot],
        plans: (dict[int, Plan] | None) = None;
}

obj NodeDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot];
}

obj Frame {
    has loc: int,
        phase: int = 0,
        idx: int = 0,
        budget: int = 0,
        plan: (Plan | None) = None;
}

obj WalkScope {
    has wlk: any,
        path: list[int],
        next: list[int],
        front: list[int],
        ignores: list[int],
        reports: list[any],
        disengaged: bool = False,
        next_head: int = 0,
        nested: bool = False,
        fenced: bool = False,
        pending_fence: int = 0,
        skip_node: bool = False,
        stage: int = 0,
        sidx: int = 0,
        frames: (list[Frame] | None) = None,
        cur_a: any = None,
        cur_b: any = None;
}

obj OspRuntime {
    has tag_of: Callable[([any], int)],
        is_a: Callable[([int, int], bool)],
        node_desc: Callable[([int], NodeDesc)],
        on_complete: Callable[([WalkScope, bool], None)];
}

glob _descs: dict[int, NodeDesc] = {};

def osp_register_desc(tag: int, desc: NodeDesc) {
    _descs[tag] = desc;
}

def osp_has_desc(tag: int) -> bool {
    return tag in _descs;
}

def osp_node_desc(tag: int) -> NodeDesc {
    if tag in _descs {
        found: NodeDesc = _descs[tag];
        return found;
    }
    return NodeDesc(type_tag=tag, `entry=[], `exit=[]);
}

def _new_plans -> dict[int, Plan] {
    out: dict[int, Plan] = {};
    return out;
}

def _plan_for(
    rt: OspRuntime, wdesc: WalkerDesc, wtag: int, ndesc: NodeDesc, ctag: int
) -> Plan {
    w_entry = [
        s
        for s in wdesc.`entry
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag)
    ];
    w_exit = [
        s
        for s in wdesc.`exit
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag)
    ];
    n_entry_u = [
        s
        for s in ndesc.`entry
        if s.trig_tag == UNTYPED
    ];
    n_entry_t = [
        s
        for s in ndesc.`entry
        if s.trig_tag != UNTYPED and rt.is_a(wtag, s.trig_tag)
    ];
    n_exit_t = [
        s
        for s in ndesc.`exit
        if s.trig_tag != UNTYPED and rt.is_a(wtag, s.trig_tag)
    ];
    n_exit_u = [
        s
        for s in ndesc.`exit
        if s.trig_tag == UNTYPED
    ];
    return Plan(
        ctag=ctag,
        enter=[(s, True) for s in w_entry]
            + [(s, False) for s in n_entry_u]
            + [(s, False) for s in n_entry_t],
        leave=[(s, False) for s in n_exit_t]
            + [(s, False) for s in n_exit_u]
            + [(s, True) for s in w_exit],
        enter_first=bool(w_entry),
        leave_first=bool(n_exit_t)
    );
}


def _dequeue(scope: WalkScope) -> (int | None) {
    while scope.front {
        candidate = scope.front.pop();
        if (not scope.ignores) or (candidate not in scope.ignores) {
            return candidate;
        }
    }
    while scope.next_head < len(scope.next) {
        candidate = scope.next[scope.next_head];
        scope.next_head += 1;
        if (not scope.ignores) or (candidate not in scope.ignores) {
            return candidate;
        }
    }
    if scope.next_head > 0 {
        scope.next.clear();
        scope.next_head = 0;
    }
    return None;
}

obj OspEngine {
    has stack: list[WalkScope];

    def scope_of(wlk: any) -> (WalkScope | None) {
        i = len(self.stack) - 1;
        while i >= 0 {
            sc: WalkScope = self.stack[i];
            if sc.wlk is wlk {
                return sc;
            }
            i -= 1;
        }
        return None;
    }

    def current -> (WalkScope | None) {
        if self.stack {
            found: WalkScope = self.stack[-1];
            return found;
        }
        return None;
    }

    def `visit(targets: list[int], insert_loc: int = -1) -> bool {
        scope = self.current();
        if scope is None {
            return False;
        }
        filtered = targets;
        if scope.ignores {
            kept: list[int] = [];
            for t in targets {
                if t not in scope.ignores {
                    kept.append(t);
                }
            }
            filtered = kept;
        }
        if not filtered {
            return False;
        }
        if insert_loc == -1 {
            scope.next.extend(filtered);
            return True;
        }
        if insert_loc == 0 {
            scope.front.extend(reversed(filtered));
            scope.fenced = True;
            scope.pending_fence += len(filtered);
            return True;
        }
        logical: list[int] = [];
        i = len(scope.front) - 1;
        while i >= 0 {
            logical.append(scope.front[i]);
            i -= 1;
        }
        j = scope.next_head;
        while j < len(scope.next) {
            logical.append(scope.next[j]);
            j += 1;
        }
        pos = insert_loc;
        if pos < -len(logical) {
            pos = 0;
        } elif pos < 0 {
            pos = pos + len(logical) + 1;
        }
        scope.front = [];
        scope.next = logical[:pos] + filtered + logical[pos:];
        scope.next_head = 0;
        return True;
    }

    def forget(target: int) {
        for scope in self.stack {
            if target not in scope.ignores {
                scope.ignores.append(target);
            }
        }
    }

    def `disengage {
        scope = self.current();
        if scope is not None {
            scope.disengaged = True;
        }
    }

    def skip_rest {
        scope = self.current();
        if scope is not None {
            scope.skip_node = True;
        }
    }

    def `report(val: any) {
        scope = self.current();
        if scope is not None {
            scope.reports.append(val);
        }
    }

    def begin(wlk: any, starts: list[int]) -> WalkScope {
        scope = WalkScope(
            wlk=wlk,
            path=[],
            next=`list(starts),
            front=[],
            ignores=[],
            reports=[],
            nested=(len(self.stack) > 0)
        );
        scope.frames = [];
        self.stack.append(scope);
        return scope;
    }

    def finish(scope: WalkScope, ok: bool, rt: OspRuntime) {
        self.stack.pop();
        if scope.nested and self.stack {
            outer: WalkScope = self.stack[-1];
            for r in scope.reports {
                outer.reports.append(r);
            }
        }
        rt.on_complete(scope, ok);
    }

    def next_slot(
        rt: OspRuntime, scope: WalkScope, wdesc: WalkerDesc
    ) -> (Slot | None) {
        if scope.frames is None {
            scope.frames = [];
        }
        frames: list[Frame] = scope.frames;
        while True {
            if scope.stage == 0 {
                if scope.disengaged or scope.skip_node or (not scope.next) {
                    scope.stage = 1;
                    continue;
                }
                if scope.sidx == 0 {
                    scope.cur_b = scope.next[0];
                }
                while scope.sidx < len(wdesc.`entry) {
                    s: Slot = wdesc.`entry[scope.sidx];
                    scope.sidx += 1;
                    if s.trig_tag == UNTYPED {
                        scope.cur_a = scope.wlk;
                        return s;
                    }
                }
                scope.stage = 1;
            } elif scope.stage == 1 {
                if scope.disengaged {
                    scope.stage = 3;
                    return None;
                }
                if not frames {
                    nxt = _dequeue(scope);
                    if nxt is None {
                        scope.stage = 2;
                        scope.sidx = 0;
                        continue;
                    }
                    frames.append(Frame(loc=nxt));
                    continue;
                }
                f: Frame = frames[-1];
                if f.phase == 0 {
                    if f.plan is None {
                        scope.path.append(f.loc);
                        ctag: int = rt.tag_of(f.loc);
                        if wdesc.plans is None {
                            wdesc.plans = _new_plans();
                        }
                        plans = wdesc.plans;
                        if ctag in plans {
                            f.plan = plans[ctag];
                        } else {
                            ndesc = rt.node_desc(ctag);
                            f.plan = _plan_for(rt, wdesc, wdesc.type_tag, ndesc, ctag);
                            plans[ctag] = f.plan;
                        }
                        scope.pending_fence = 0;
                    }
                    plan: Plan = f.plan;
                    if f.idx < len(plan.enter)
                        and (
                            not scope.skip_node or (f.idx == 0 and plan.enter_first)
                        ) {
                        (s, on_walker) = plan.enter[f.idx];
                        f.idx += 1;
                        scope.cur_a = scope.wlk if on_walker else f.loc;
                        scope.cur_b = f.loc if on_walker else scope.wlk;
                        return s;
                    }
                    scope.skip_node = False;
                    f.phase = 1;
                    f.idx = 0;
                    f.budget = scope.pending_fence;
                    continue;
                } elif f.phase == 1 {
                    if scope.fenced {
                        budget: int = f.budget;
                        found = False;
                        child = f.loc;
                        while (budget > 0) and (not found) {
                            if scope.front {
                                candidate = scope.front.pop();
                                budget -= 1;
                                if (not scope.ignores)
                                    or (candidate not in scope.ignores) {
                                    child = candidate;
                                    found = True;
                                }
                            } else {
                                budget = 0;
                            }
                        }
                        f.budget = budget;
                        if found {
                            frames.append(Frame(loc=child));
                        } else {
                            f.phase = 2;
                            scope.pending_fence = 0;
                        }
                    } else {
                        nxt = _dequeue(scope);
                        if nxt is not None {
                            frames.append(Frame(loc=nxt));
                        } else {
                            f.phase = 2;
                            scope.pending_fence = 0;
                        }
                    }
                    continue;
                } else {
                    if f.plan is None {
                        frames.pop();
                        continue;
                    }
                    plan: Plan = f.plan;
                    if f.idx < len(plan.leave)
                        and (
                            not scope.skip_node or (f.idx == 0 and plan.leave_first)
                        ) {
                        (s, on_walker) = plan.leave[f.idx];
                        f.idx += 1;
                        scope.cur_a = scope.wlk if on_walker else f.loc;
                        scope.cur_b = f.loc if on_walker else scope.wlk;
                        return s;
                    }
                    scope.skip_node = False;
                    frames.pop();
                    if scope.fenced and (scope.pending_fence > 0) and frames {
                        parent: Frame = frames[-1];
                        parent.budget += scope.pending_fence;
                    }
                    continue;
                }
            } elif scope.stage == 2 {
                if scope.disengaged or (not scope.path) {
                    scope.stage = 3;
                    return None;
                }
                if scope.sidx > 0 and scope.skip_node {
                    scope.stage = 3;
                    return None;
                }
                while scope.sidx < len(wdesc.`exit) {
                    s: Slot = wdesc.`exit[scope.sidx];
                    scope.sidx += 1;
                    if s.trig_tag == UNTYPED {
                        scope.cur_a = scope.wlk;
                        scope.cur_b = scope.path[-1];
                        return s;
                    }
                }
                scope.stage = 3;
                return None;
            } else {
                return None;
            }
        }
        return None;
    }

    def `spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list[int]) -> any {
        scope = self.begin(wlk, starts);
        ok = False;
        try {
            while True {
                s = self.next_slot(rt, scope, wdesc);
                if s is None {
                    break;
                }
                s.fn(scope.cur_a, scope.cur_b);
            }
            ok = True;
        } finally {
            self.finish(scope, ok, rt);
        }
        return wlk;
    }
}

glob DEFAULT: OspEngine = OspEngine(stack=[]);

def scope_of(wlk: any) -> (WalkScope | None) {
    return DEFAULT.scope_of(wlk);
}

def _current_scope -> (WalkScope | None) {
    return DEFAULT.current();
}

def osp_visit(targets: list[int], insert_loc: int = -1) -> bool {
    return DEFAULT.`visit(targets, insert_loc);
}

def osp_forget(target: int) {
    DEFAULT.forget(target);
}

def osp_forget_all(targets: list[int]) {
    i = 0;
    while i < len(targets) {
        DEFAULT.forget(targets[i]);
        i += 1;
    }
}

def osp_disengage {
    DEFAULT.`disengage();
}

def osp_skip_rest {
    DEFAULT.skip_rest();
}

def osp_report(val: any) {
    DEFAULT.`report(val);
}

def osp_spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list[int]) -> any {
    return DEFAULT.`spawn(rt, wlk, wdesc, starts);
}
