glob UNTYPED: int = -1;

obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj WalkerDesc {
    has type_tag: int,
        entry: list[Slot],
        exit: list[Slot];
}

obj NodeDesc {
    has type_tag: int,
        entry: list[Slot],
        exit: list[Slot];
}

obj WalkScope {
    has wlk: any,
        path: list,
        next: list,
        ignores: list,
        reports: list,
        disengaged: bool = False;
}

obj OspRuntime {
    has tag_of: Callable[([any], int)],
        is_a: Callable[([int, int], bool)],
        node_desc: Callable[([int], NodeDesc)],
        on_complete: Callable[([WalkScope, bool], None)];
}

glob _walk_stack: list[WalkScope] = [];

def _current_scope -> (WalkScope | None) {
    if _walk_stack {
        return _walk_stack[-1];
    }
    return None;
}

def osp_visit(targets: list, insert_loc: int = -1) -> bool {
    scope = _current_scope();
    if scope is None {
        return False;
    }
    filtered: list = [];
    for t in targets {
        if t not in scope.ignores {
            filtered.append(t);
        }
    }
    if not filtered {
        return False;
    }
    pos = insert_loc;
    if pos < -len(scope.next) {
        pos = 0;
    } elif pos < 0 {
        pos = pos + len(scope.next) + 1;
    }
    scope.next = scope.next[:pos] + filtered + scope.next[pos:];
    return True;
}

def osp_disengage {
    scope = _current_scope();
    if scope is not None {
        scope.disengaged = True;
    }
}

def osp_report(val: any) {
    scope = _current_scope();
    if scope is not None {
        scope.reports.append(val);
    }
}

def run_typed(rt: OspRuntime, slots: list[Slot], a: any, b: any) -> None {
    btag: int = rt.tag_of(b);
    for s in slots {
        if (s.trig_tag != UNTYPED) and rt.is_a(btag, s.trig_tag) {
            s.fn(a, b);
            sc = _current_scope();
            if (sc is not None) and sc.disengaged {
                return;
            }
        }
    }
}

def run_untyped(slots: list[Slot], a: any, b: any) -> None {
    for s in slots {
        if s.trig_tag == UNTYPED {
            s.fn(a, b);
            sc = _current_scope();
            if (sc is not None) and sc.disengaged {
                return;
            }
        }
    }
}

def _visit_recursive(
    rt: OspRuntime, scope: WalkScope, wdesc: WalkerDesc, loc: any
) -> bool {
    stack: list = [(loc, 0)];
    while stack {
        (cur, phase) = stack.pop();
        if scope.disengaged {
            return False;
        }
        if phase == 0 {
            scope.path.append(cur);
            loc_tag: int = rt.tag_of(cur);
            ndesc = rt.node_desc(loc_tag);
            run_typed(rt, wdesc.entry, scope.wlk, cur);
            if scope.disengaged {
                return False;
            }
            run_untyped(ndesc.entry, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            run_typed(rt, ndesc.entry, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }

            stack.append((cur, 1));
        } elif phase == 1 {
            child = None;
            while scope.next {
                candidate = scope.next.pop(0);
                if candidate not in scope.ignores {
                    child = candidate;
                    break;
                }
            }
            if child is not None {
                stack.append((cur, 1));

                stack.append((child, 0));
            } else {
                stack.append((cur, 2));
            }
        } else {
            loc_tag: int = rt.tag_of(cur);
            ndesc = rt.node_desc(loc_tag);
            run_typed(rt, ndesc.exit, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            run_untyped(ndesc.exit, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            run_typed(rt, wdesc.exit, scope.wlk, cur);
            if scope.disengaged {
                return False;
            }
        }
    }
    return not scope.disengaged;
}

def osp_spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list) -> any {
    scope = WalkScope(wlk=wlk, path=[], next=`list(starts), ignores=[], reports=[]);
    _walk_stack.append(scope);
    ok = False;
    try {
        if scope.next {
            anchor = scope.next[0];

            run_untyped(wdesc.entry, wlk, anchor);
        }

        while scope.next and (not scope.disengaged) {
            nxt = scope.next.pop(0);
            if nxt not in scope.ignores {
                if not _visit_recursive(rt, scope, wdesc, nxt) {
                    break;
                }
            }
        }

        if scope.path and (not scope.disengaged) {
            run_untyped(wdesc.exit, wlk, scope.path[-1]);
        }
        ok = True;
    } finally {
        _walk_stack.pop();
        rt.on_complete(scope, ok);
    }
    return wlk;
}
