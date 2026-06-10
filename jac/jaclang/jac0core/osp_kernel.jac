"""Portable Object-Spatial traversal kernel.

The walker traversal engine written once in the language's portable subset
(structs, lists, function pointers, control flow) so the server, client, and
native backends can each compile it. `spawn` / `visit` / `disengage` / `report`
lower to calls into this module; the per-archetype dispatch descriptors and the
type-tag relation are supplied by the compiler / backend through `OspRuntime`.

Traversal is depth-first recursive: entries fire on entry, children added by
the entries are visited (recursively), exits fire in post-order. The walker's
UNTYPED entries fire once at the spawn root, and its UNTYPED exits fire once at
spawn end against the final visited location. Dispatch at each location runs
(1) the walker's abilities whose trigger matches the location, (2) the
location's untyped abilities, then (3) the location's abilities whose trigger
matches the walker -- subtyping-aware. Exits run in reverse phase order. An
ability whose trigger is `UNTYPED` fires regardless of type.

`visit` filters out targets already in `scope.ignores`; the kernel does NOT
auto-track visited locations -- visit-once is opt-in (a user/system ability or
the Host can populate `scope.ignores`). `disengage` halts the walk after the
in-flight ability returns. `report` collects values delivered at the spawn
boundary via `OspHost.on_complete`. The walker handle is named `wlk` throughout
because `walker` is a reserved word.
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

"""Compiler-emitted dispatch descriptor for a node / edge archetype."""
obj NodeDesc {
    has type_tag: int,
        entry: list[Slot],
        exit: list[Slot];
}

"""Per-spawn mutable traversal state. `path` records the locations visited so
far (the DFS path; the last element is the current location). `next` is the
FIFO queue of children to recurse into at the current level. `ignores` is the
opt-in skip set consulted by `osp_visit`. `reports` accumulates values for the
Host to deliver at the spawn boundary."""
obj WalkScope {
    has wlk: any,
        path: list,
        next: list,
        ignores: list,
        reports: list,
        disengaged: bool = False;
}

"""Backend seam: type-tag intrinsics, dispatch-descriptor lookup, and the
side-effect boundary (persistence + report delivery). The server, client, and
native backends each supply an instance; the kernel stays backend-free.

`tag_of(handle)` -> the archetype type-tag of a node / walker handle.
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

"""Stack of active walk scopes (innermost last). `visit` / `report` /
`disengage` act on the innermost scope, mirroring the server's per-call
context."""
glob _walk_stack: list[WalkScope] = [];

"""Innermost active scope, or None outside any walk."""
def _current_scope -> (WalkScope | None) {
    if _walk_stack {
        return _walk_stack[-1];
    }
    return None;
}

"""`visit <targets>`: enqueue locations onto the current walk, skipping any
already present in `scope.ignores`. `insert_loc` controls where the filtered
targets land in `scope.next` (default `-1` = append at end); negative values
count from the end (Python-style). Returns True if any target was enqueued."""
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

"""Iterative DFS visit — avoids Python recursion limit for deep graphs.

Mirrors the recursive version exactly: after running entries for a node,
take ONE child from scope.next at a time (the shared queue), process it
fully (entries -> its children -> exits) before taking the next sibling.
This preserves the nested DFS order where siblings share scope.next.

Entry phase order per location:
  (1) walker abilities whose trigger matches `loc`,
  (2) loc's untyped abilities,
  (3) loc's abilities whose trigger matches the walker.

Exit phase order (reverse of entry, post-order):
  (4) loc's abilities whose trigger matches the walker,
  (5) loc's untyped abilities,
  (6) walker abilities whose trigger matches `loc`.

Returns False if the walk disengaged mid-visit."""
def _visit_recursive(
    rt: OspRuntime, scope: WalkScope, wdesc: WalkerDesc, loc: any
) -> bool {
    # Stack entries: (loc, phase)
    # phase 0 -> execute entries, then push phase 1
    # phase 1 -> take one child from scope.next if available, push self
    #            again (phase 1) then push child (phase 0); if no children
    #            left, push phase 2
    # phase 2 -> execute exits
    stack: list = [(loc, 0)];
    while stack {
        (cur, phase) = stack.pop();
        if scope.disengaged {
            return False;
        }
        if phase == 0 {
            # Entry phase
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
            # After entries, move to child-processing phase.
            stack.append((cur, 1));
        } elif phase == 1 {
            # Child-processing phase: pop ONE child from scope.next.
            # This mirrors the recursive `while scope.next` loop that
            # processes one child at a time, allowing nested children
            # to interleave via the shared scope.next queue.
            child = None;
            while scope.next {
                candidate = scope.next.pop(0);
                if candidate not in scope.ignores {
                    child = candidate;
                    break;
                }
            }
            if child is not None {
                # Push self again to check for more children after this
                # child's subtree completes.
                stack.append((cur, 1));
                # Push child for entry processing.
                stack.append((child, 0));
            } else {
                # No more children — proceed to exits.
                stack.append((cur, 2));
            }
        } else {
            # Exit phase (phase 2)
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

"""`walker spawn location`: DFS-recursive traversal from `starts` (typically a
single-element `[node]`; `[edge, edge.target]` for an edge spawn). Walker
UNTYPED entries fire once at the spawn root against `starts[0]`; walker UNTYPED
exits fire once at spawn end against the final visited location. Returns the
walker handle (the value of a `spawn` expression)."""
def osp_spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list) -> any {
    scope = WalkScope(wlk=wlk, path=[], next=`list(starts), ignores=[], reports=[]);
    _walk_stack.append(scope);
    ok = False;
    try {
        if scope.next {
            anchor = scope.next[0];
            # Walker UNTYPED entries at spawn root.
            run_untyped(wdesc.entry, wlk, anchor);
        }
        # DFS through the queue.
        while scope.next and (not scope.disengaged) {
            nxt = scope.next.pop(0);
            if nxt not in scope.ignores {
                if not _visit_recursive(rt, scope, wdesc, nxt) {
                    break;
                }
            }
        }
        # Walker UNTYPED exits at end against final visited location.
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
