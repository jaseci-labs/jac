glob UNTYPED: int = -1;

obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj Plan {
    has ctag: int,
        w_entry: list[Slot],
        n_entry_u: list[Slot],
        n_entry_t: list[Slot],
        n_exit_t: list[Slot],
        n_exit_u: list[Slot],
        w_exit: list[Slot];
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
        band: int = 0,
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
        cur_b: any = None,
        cur_entry: bool = False;
}

obj OspTask {
    has slot: Slot,
        a: any,
        b: any,
        ignores: list[int],
        state: int = 0;
}

def _osp_no_tasks(tasks: list[OspTask]) {}
def _osp_no_commit(task: OspTask) -> bool {
    return False;
}

def _osp_no_drop(task: OspTask) {}
def _osp_call_slot(slot: Slot, a: any, b: any) {
    slot.fn(a, b);
}

obj OspRuntime {
    has tag_of: Callable[([any], int)],
        is_a: Callable[([int, int], bool)],
        node_desc: Callable[([int], NodeDesc)],
        on_complete: Callable[([WalkScope, bool], None)],
        task_width: int = 0,
        run_tasks: Callable[([list[OspTask]], None)] = _osp_no_tasks,
        commit_task: Callable[([OspTask], bool)] = _osp_no_commit,
        drop_task: Callable[([OspTask], None)] = _osp_no_drop;
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
    plan = Plan(
        ctag=ctag,
        w_entry=[],
        n_entry_u=[],
        n_entry_t=[],
        n_exit_t=[],
        n_exit_u=[],
        w_exit=[]
    );
    for s in wdesc.`entry {
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag) {
            plan.w_entry.append(s);
        }
    }
    for s in wdesc.`exit {
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag) {
            plan.w_exit.append(s);
        }
    }
    for s in ndesc.`entry {
        if s.trig_tag == UNTYPED {
            plan.n_entry_u.append(s);
        } elif rt.is_a(wtag, s.trig_tag) {
            plan.n_entry_t.append(s);
        }
    }
    for s in ndesc.`exit {
        if s.trig_tag == UNTYPED {
            plan.n_exit_u.append(s);
        } elif rt.is_a(wtag, s.trig_tag) {
            plan.n_exit_t.append(s);
        }
    }
    return plan;
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
        scope.cur_entry = False;
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
                        scope.cur_entry = True;
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
                    if f.band == 0 {
                        if f.idx > 0 and scope.skip_node {
                            f.idx = 0;
                            f.band = 1;
                            continue;
                        }
                        if f.idx < len(plan.w_entry) {
                            s = plan.w_entry[f.idx];
                            f.idx += 1;
                            scope.cur_a = scope.wlk;
                            scope.cur_b = f.loc;
                            scope.cur_entry = True;
                            return s;
                        }
                        f.idx = 0;
                        f.band = 1;
                        continue;
                    }
                    if f.band == 1 {
                        if scope.skip_node {
                            f.idx = 0;
                            f.band = 2;
                            continue;
                        }
                        if f.idx < len(plan.n_entry_u) {
                            s = plan.n_entry_u[f.idx];
                            f.idx += 1;
                            scope.cur_a = f.loc;
                            scope.cur_b = scope.wlk;
                            scope.cur_entry = True;
                            return s;
                        }
                        f.idx = 0;
                        f.band = 2;
                        continue;
                    }
                    if scope.skip_node {
                        f.idx = 0;
                    } elif f.idx < len(plan.n_entry_t) {
                        s = plan.n_entry_t[f.idx];
                        f.idx += 1;
                        scope.cur_a = f.loc;
                        scope.cur_b = scope.wlk;
                        scope.cur_entry = True;
                        return s;
                    } else {
                        f.idx = 0;
                    }
                    scope.skip_node = False;
                    f.phase = 1;
                    f.band = 0;
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
                            if f.plan is not None
                                and not f.plan.n_exit_t
                                and not f.plan.n_exit_u
                                and not f.plan.w_exit {
                                f.loc = nxt;
                                f.phase = 0;
                                f.band = 0;
                                f.idx = 0;
                                f.budget = 0;
                                f.plan = None;
                            } else {
                                frames.append(Frame(loc=nxt));
                            }
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
                    if f.band == 0 {
                        if f.idx > 0 and scope.skip_node {
                            f.idx = 0;
                            f.band = 1;
                            continue;
                        }
                        if f.idx < len(plan.n_exit_t) {
                            s = plan.n_exit_t[f.idx];
                            f.idx += 1;
                            scope.cur_a = f.loc;
                            scope.cur_b = scope.wlk;
                            return s;
                        }
                        f.idx = 0;
                        f.band = 1;
                        continue;
                    }
                    if f.band == 1 {
                        if scope.skip_node {
                            f.idx = 0;
                            f.band = 2;
                            continue;
                        }
                        if f.idx < len(plan.n_exit_u) {
                            s = plan.n_exit_u[f.idx];
                            f.idx += 1;
                            scope.cur_a = f.loc;
                            scope.cur_b = scope.wlk;
                            return s;
                        }
                        f.idx = 0;
                        f.band = 2;
                        continue;
                    }
                    if scope.skip_node {
                        f.idx = 0;
                    } elif f.idx < len(plan.w_exit) {
                        s = plan.w_exit[f.idx];
                        f.idx += 1;
                        scope.cur_a = scope.wlk;
                        scope.cur_b = f.loc;
                        return s;
                    } else {
                        f.idx = 0;
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

    def preview(scope: WalkScope) -> WalkScope {
        frames: list[Frame] = [];
        if scope.frames is not None {
            for f in scope.frames {
                frames.append(
                    Frame(
                        loc=f.loc,
                        phase=f.phase,
                        band=f.band,
                        idx=f.idx,
                        budget=f.budget,
                        plan=f.plan
                    )
                );
            }
        }
        return WalkScope(
            wlk=scope.wlk,
            path=`list(scope.path),
            next=`list(scope.next),
            front=`list(scope.front),
            ignores=`list(scope.ignores),
            reports=[],
            disengaged=scope.disengaged,
            next_head=scope.next_head,
            nested=scope.nested,
            fenced=scope.fenced,
            pending_fence=scope.pending_fence,
            skip_node=scope.skip_node,
            stage=scope.stage,
            sidx=scope.sidx,
            frames=frames,
            cur_a=scope.cur_a,
            cur_b=scope.cur_b,
            cur_entry=scope.cur_entry
        );
    }

    def tasks(
        rt: OspRuntime, scope: WalkScope, wdesc: WalkerDesc, first: Slot
    ) -> list[OspTask] {
        out = [OspTask(first, scope.cur_a, scope.cur_b, scope.ignores)];
        preview = self.preview(scope);
        while len(out) < rt.task_width {
            slot = self.next_slot(rt, preview, wdesc);
            if slot is None or not preview.cur_entry {
                break;
            }
            out.append(OspTask(slot, preview.cur_a, preview.cur_b, scope.ignores));
        }
        return out;
    }

    def `spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list[int]) -> any {
        scope = self.begin(wlk, starts);
        ok = False;
        try {
            s = self.next_slot(rt, scope, wdesc);
            while True {
                if s is None {
                    break;
                }
                run_tasks = rt.run_tasks;
                commit_task = rt.commit_task;
                drop_task = rt.drop_task;
                if not scope.cur_entry
                    or scope.fenced
                    or rt.task_width < 2
                    or run_tasks is None
                    or commit_task is None
                    or drop_task is None {
                    _osp_call_slot(s, scope.cur_a, scope.cur_b);
                    s = self.next_slot(rt, scope, wdesc);
                    continue;
                }
                tasks = self.tasks(rt, scope, wdesc, s);
                if len(tasks) < 2 {
                    _osp_call_slot(s, scope.cur_a, scope.cur_b);
                    s = self.next_slot(rt, scope, wdesc);
                    continue;
                }
                retry = False;
                try {
                    run_tasks(tasks);
                    for task in tasks {
                        if s is None
                            or not scope.cur_entry
                            or s is not task.slot
                            or scope.cur_a != task.a
                            or scope.cur_b != task.b
                            or scope.ignores is not task.ignores {
                            break;
                        }
                        if not commit_task(task) {
                            retry = True;
                            break;
                        }
                        s = self.next_slot(rt, scope, wdesc);
                    }
                } finally {
                    for task in tasks {
                        drop_task(task);
                    }
                }
                if retry and s is not None {
                    _osp_call_slot(s, scope.cur_a, scope.cur_b);
                    s = self.next_slot(rt, scope, wdesc);
                }
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
