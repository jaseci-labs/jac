"""Portable Object-Spatial traversal kernel.

The walker traversal engine written once in the language's portable subset
(structs, lists, function pointers, control flow) so the server, client, and
native backends can each compile it. `spawn`/`visit`/`disengage`/`report` lower
to calls into this module; the per-archetype dispatch descriptors and the
type-tag relation are supplied by the compiler/backend through `OspRuntime`.

Dispatch mirrors the server engine: the walker's untyped entry abilities run
once at the spawn root, then each visited location runs (1) the walker's
abilities whose trigger matches the location, (2) the location's untyped
abilities, and (3) the location's abilities whose trigger matches the walker —
all subtyping-aware. An ability whose trigger is `UNTYPED` fires regardless of
type.

Scope note: this first cut implements the entry traversal as breadth-first,
visit-once. Exit abilities and exact depth-first ordering parity with the
server engine are layered on next, before this replaces the per-site native
dispatch. The walker handle is named `wlk` throughout because `walker` is a
reserved word.
"""

"""Trigger tag meaning "fires on any location" (an untyped `with entry`)."""
glob UNTYPED: int = -1;

"""One dispatch entry: ability `fn` fires when the matched type-tag is-a
`trig_tag` (or `trig_tag` is UNTYPED)."""
obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

"""Compiler-emitted dispatch descriptor for a walker archetype."""
obj WalkerDesc {
    has type_tag: int,
        entry: list[Slot],
        exit: list[Slot];
}

"""Compiler-emitted dispatch descriptor for a node/edge archetype."""
obj NodeDesc {
    has type_tag: int,
        entry: list[Slot],
        exit: list[Slot];
}

"""Per-spawn mutable traversal state."""
obj WalkScope {
    has wlk: any,
        next: list,
        ignores: list,
        reports: list,
        disengaged: bool = False;
}

"""Backend seam: type-tag intrinsics, dispatch-descriptor lookup, and the
side-effect boundary (persistence + report delivery). The server, client, and
native backends each supply an instance; the kernel stays backend-free.

`tag_of(handle)` -> the archetype type-tag of a node/walker handle.
`is_a(tag, base)` -> True if `tag` is `base` or a subtype of it.
`node_desc(tag)` -> the dispatch descriptor for a location's type.
`on_complete(scope, ok)` -> deliver reports + commit at the spawn boundary.
"""
obj OspRuntime {
    has tag_of: Callable[([any], int)],
        is_a: Callable[([int, int], bool)],
        node_desc: Callable[([int], NodeDesc)],
        on_complete: Callable[([WalkScope, bool], None)];
}

"""Stack of active walk scopes (innermost last). `visit`/`report`/`disengage`
act on the innermost scope, mirroring the server's per-call context."""
glob _walk_stack: list[WalkScope] = [];

"""Innermost active scope, or None outside any walk."""
def _current_scope -> (WalkScope | None) {
    if _walk_stack {
        return _walk_stack[-1];
    }
    return None;
}

"""`visit <targets>`: enqueue locations onto the current walk."""
def osp_visit(targets: list) {
    scope = _current_scope();
    if scope is not None {
        for t in targets {
            scope.next.append(t);
        }
    }
}

"""`disengage`: stop the current walk after the in-flight ability returns."""
def osp_disengage {
    scope = _current_scope();
    if scope is not None {
        scope.disengaged = True;
    }
}

"""`report <val>`: collect a value to deliver at the spawn boundary."""
def osp_report(val: any) {
    scope = _current_scope();
    if scope is not None {
        scope.reports.append(val);
    }
}

"""Run typed slots whose trigger matches `b`'s type, calling `fn(a, b)`.
Stops early if an ability disengages the walk."""
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

"""Run untyped slots, calling `fn(a, b)`. Stops early on disengage."""
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

"""`walker spawn location`: run a breadth-first, visit-once traversal from
`start`. Returns the walker handle (the value of a `spawn` expression)."""
def osp_spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, start: any) -> any {
    scope = WalkScope(wlk=wlk, next=[start], ignores=[], reports=[]);
    _walk_stack.append(scope);
    ok = False;
    try {
        # Walker untyped-entry runs once at the spawn root.
        run_untyped(wdesc.entry, wlk, start);
        while scope.next and (not scope.disengaged) {
            loc = scope.next.pop(0);
            if loc not in scope.ignores {
                scope.ignores.append(loc);
                loc_tag: int = rt.tag_of(loc);
                ndesc = rt.node_desc(loc_tag);
                # (1) walker abilities matching this location.
                run_typed(rt, wdesc.entry, wlk, loc);
                if scope.disengaged {
                    break;
                }
                # (2) location's untyped abilities, then (3) those matching the
                # walker.
                run_untyped(ndesc.entry, loc, wlk);
                if scope.disengaged {
                    break;
                }
                run_typed(rt, ndesc.entry, loc, wlk);
            }
        }
        ok = True;
    } finally {
        _walk_stack.pop();
        rt.on_complete(scope, ok);
    }
    return wlk;
}
