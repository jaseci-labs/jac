"""Server binding for the portable Object-Spatial kernel.

Builds the kernel's dispatch descriptors (`WalkerDesc` / `NodeDesc`) and
type-tag relation from live archetype classes -- the server's analogue of the
static descriptors the native backend emits at compile time. The kernel stays
backend-free; this module is the `OspRuntime` the server supplies.

The sv runtime stores `NodeAnchor` / `EdgeAnchor` wrappers in
`walker.next` / `walker.path` / `walker.ignores`, but ability functions receive
the underlying archetype (`anchor.archetype`). The slot wrappers below unwrap
any anchor argument before invoking the user's ability function, so the kernel
can be anchor-agnostic and uniformly call `slot.fn(a, b)`.

Reports bubble: a nested spawn forwards its collected reports up to the
outer scope (mirroring the sv `CallState` contextvar semantics); the outermost
spawn drains them onto the walker and commits the persistence buffer on
success.
"""

import inspect;
import jaclang.jac0core.osp_kernel as _kernel;
import from contextvars { ContextVar }
import from types { UnionType }
import from typing { cast }
import from jaclang.jac0core.archetype {
    NodeAnchor,
    EdgeAnchor,
    ObjectSpatialFunction,
    WalkerArchetype
}
import from jaclang.jac0core.osp_kernel {
    Slot,
    WalkerDesc,
    NodeDesc,
    WalkScope,
    OspRuntime,
    UNTYPED
}

"""ContextVar-backed list proxy. Provides per-request isolation of the OSP
walk-scope stack so concurrent walker spawns (different requests, asyncio
tasks) get isolated stacks -- matching the per-request isolation the legacy
sv engine got from its `CallState` contextvar. The kernel does
`_walk_stack.append(scope)`, `_walk_stack.pop()`, `_walk_stack[-1]`, and
truthiness checks; this proxy delegates each to a per-context list. The
portable kernel itself stays as a plain `glob _walk_stack: list = []`
(correct for the single-program cl/na runtimes); the sv binding swaps in
this proxy at module load."""
obj _ContextStack {
    has _var: any by postinit;

    def postinit {
        self._var = ContextVar('osp_walk_stack', default=None);
    }

    def _list -> list {
        # Read-only view of the current context's stack. Never `.set()` here:
        # a bare read must not bind a list into the (possibly ancestor) context,
        # or descendant asyncio tasks would inherit and share that object.
        v = self._var.get();
        return v if v is not None else [];
    }

    def append(x: any) {
        # Copy-on-write. A ContextVar only isolates on `.set()`; mutating a list
        # obtained from `.get()` in place leaks across every context that
        # inherited the same list object -- e.g. concurrent walker spawns in
        # `asyncio.gather` tasks created under a context where the stack was
        # already populated would all push onto one shared list and clobber each
        # other's scope. Rebinding a fresh list keeps each context isolated.
        cur = self._var.get();
        new = `list(cur) if cur is not None else [];
        new.append(x);
        self._var.set(new);
    }

    def pop -> any {
        cur = self._var.get();
        new = `list(cur) if cur is not None else [];
        val = new.pop();
        self._var.set(new);
        return val;
    }

    def __getitem__(k: any) -> any {
        return self._list()[k];
    }

    def __bool__ -> bool {
        return bool(self._list());
    }

    def __len__ -> int {
        return len(self._list());
    }
}

# Swap the kernel's plain-global walk stack for a ContextVar-backed proxy so
# concurrent spawns in different asyncio tasks / threads (e.g. concurrent HTTP
# requests served by sv) get isolated scope stacks. Python re-resolves module
# globals by name on every access, so the kernel's `_walk_stack.append(...)` /
# `_walk_stack.pop()` / `_walk_stack[-1]` keep working through the proxy.
with entry {
    _kernel._walk_stack = _ContextStack();
}

"""Install a fresh, empty walk-scope stack for the current request context.

The sv server shares process-global ContextVars across in-process requests:
an in-process sv-to-sv RPC (or any nested in-process request, e.g. a
`TestClient` call made from inside a walker) runs in a *copy* of the caller's
context and so inherits the caller's walk-scope stack. Without resetting it,
the provider request's walk would see the caller's scope already on the stack,
be misclassified as a *nested* spawn by `_sv_on_complete`, and bubble its
reports into the caller's scope instead of delivering them to its own
request's `CallState` -- so the RPC response would come back with empty
`reports`. (In separate-process deployments each process has its own stack, so
the leak only shows in-process, e.g. under the test client.)

Call this at the request boundary, alongside the per-request `CallState`
reset. Each request runs in its own ContextVar context, so the fresh stack is
isolated to that request and discarded with its context -- no restore needed,
and genuine in-process nested spawns (which do not cross a request boundary)
keep their report-bubbling. No-op when the stack is the plain-list kernel
default (cl / na, which never serve requests)."""
def isolate_request_walk_stack {
    if isinstance(_kernel._walk_stack, _ContextStack) {
        _kernel._walk_stack._var.set([]);
    }
}

"""class -> int tag, the inverse list (index == tag), and a descriptor cache."""
glob _tag_of_cls: dict[(any, int)] = {},
     _cls_of_tag: list[any] = [],
     _desc_of_cls: dict[(any, WalkerDesc)] = {};

"""Assign (or fetch) the stable type-tag for an archetype class."""
def _tag_for(cls: any) -> int {
    if cls in _tag_of_cls {
        return _tag_of_cls[cls];
    }
    t = len(_cls_of_tag);
    _tag_of_cls[cls] = t;
    _cls_of_tag.append(cls);
    return t;
}

"""Expand a trigger (single type / union / tuple / None) into member types."""
def _trigger_members(trig: any) -> list[any] {
    if trig is None {
        return [];
    }
    if isinstance(trig, UnionType) {
        return `list(trig.__args__);
    }
    if isinstance(trig, tuple) {
        return `list(trig);
    }
    return [trig];
}

"""Unwrap a sv `NodeAnchor` / `EdgeAnchor` to its archetype; pass through any
non-anchor value. Lets ability functions written against archetypes be invoked
uniformly from a kernel that carries anchors in its scope."""
def _unwrap(x: any) -> any {
    if isinstance(x, (NodeAnchor, EdgeAnchor)) {
        return x.archetype;
    }
    return x;
}

"""Wrap an ability function so kernel-side `(a, b)` arguments are unwrapped to
archetypes before the user's code runs. Captures `f` by default-arg so each
slot binds its own function."""
def _wrap_ability(f: any) -> any {
    def call(a: any, b: any, fn: any = f) -> any {
        return fn(_unwrap(a), _unwrap(b));
    }
    return call;
}

"""Build the dispatch slots for one ability-function list."""
def _slots_from(funcs: list[ObjectSpatialFunction]) -> list[Slot] {
    slots: list[Slot] = [];
    for f in funcs {
        members = _trigger_members(f.trigger);
        wrapped = _wrap_ability(f.func);
        if not members {
            slots.append(Slot(trig_tag=UNTYPED, fn=wrapped));
        } else {
            for m in members {
                slots.append(Slot(trig_tag=_tag_for(m), fn=wrapped));
            }
        }
    }
    return slots;
}

"""Build (and cache) the dispatch descriptor for an archetype class."""
def desc_for(cls: any) -> WalkerDesc {
    if cls in _desc_of_cls {
        return _desc_of_cls[cls];
    }
    desc = WalkerDesc(
        type_tag=_tag_for(cls),
        entry=_slots_from(cast(list[ObjectSpatialFunction], cls._jac_entry_funcs_)),
        exit=_slots_from(cast(list[ObjectSpatialFunction], cls._jac_exit_funcs_))
    );
    _desc_of_cls[cls] = desc;
    return desc;
}

"""`tag_of`: archetype class tag of a node / walker handle. Unwraps anchors so
dispatch keys on the user-defined archetype class, not on the anchor wrapper."""
def _sv_tag_of(handle: any) -> int {
    return _tag_for(`type(_unwrap(handle)));
}

"""`is_a`: subtype test over the registered archetype classes."""
def _sv_is_a(tag: int, base: int) -> bool {
    return issubclass(cast(type, _cls_of_tag[tag]), cast(type, _cls_of_tag[base]));
}

"""`node_desc`: descriptor for a location's type-tag (as a NodeDesc view)."""
def _sv_node_desc(tag: int) -> NodeDesc {
    d = desc_for(_cls_of_tag[tag]);
    return NodeDesc(type_tag=d.type_tag, entry=d.entry, exit=d.exit);
}

"""`on_complete`: deliver reports + commit persistence at the spawn boundary.

Nested spawns bubble their collected reports up to the outer scope (matching
the sv `CallState` contextvar semantics where a nested spawn shares the
outermost report queue). The outermost spawn drains `scope.reports` onto the
walker and commits the persistence buffer on success."""
def _sv_on_complete(scope: WalkScope, ok: bool) {
    # Mirror the kernel scope onto the walker anchor (sv legacy contract:
    # walker.path holds the visited locations; next/ignores reset at spawn end).
    if isinstance(scope.wlk, WalkerArchetype) {
        anch = scope.wlk.__jac__;
        anch.path = `list(scope.path);
        anch.next = [];
        anch.ignores = [];
    }
    if _kernel._walk_stack {
        # Nested spawn: bubble reports up to the outer scope; the outermost
        # spawn drains them onto the walker and commits.
        outer = _kernel._walk_stack[-1];
        for r in scope.reports {
            outer.reports.append(r);
        }
        return;
    }
    # Outermost spawn: drain reports onto the walker and commit on success.
    if isinstance(scope.wlk, WalkerArchetype) {
        scope.wlk.reports = scope.reports;
    }
    # Bridge collected reports into the request-scoped CallState so the sv
    # HTTP server's `_finalize_call_response` (which serializes reports into
    # the API response envelope) keeps working unchanged.
    import from jaclang.jac0core.runtime { JacRuntimeInterface }
    try {
        ctx = JacRuntimeInterface.get_context();
        cs = ctx.call_state.get(None);
        if cs is not None {
            for r in scope.reports {
                cs.reports.put_nowait(r);
            }
        }
    } except Exception {
        ;
    }
    if ok {
        # Commit the deferred L1 buffer to durable storage (mirrors sv's
        # ExecutionManager.spawn_walker so direct `walker spawn node` flows
        # persist without manual Jac.commit()). On native / client builds the
        # context's mem.commit is a no-op so this is safe to call uniformly.
        try {
            JacRuntimeInterface.get_context().mem.commit();
        } except Exception {
            ;
        }
    }
}

"""The server's OspRuntime: type-tag intrinsics + descriptor lookup, bridged to
live archetype reflection."""
def make_sv_runtime -> OspRuntime {
    return OspRuntime(
        tag_of=_sv_tag_of,
        is_a=_sv_is_a,
        node_desc=_sv_node_desc,
        on_complete=_sv_on_complete
    );
}

# ---------------------------------------------------------------------------
# Async variant: mirrors the sync kernel algorithm but `await`s any coroutine
# result returned by an ability so async walker abilities run to completion.
# Lives in the sv binding (not the portable kernel) because `Coroutine` and
# `await` are Python-specific; cl / na will provide their own async handling
# in their own bindings.
# ---------------------------------------------------------------------------
"""Run typed slots whose trigger matches `b`'s type, awaiting any coroutine
returned by an ability. Stops early on disengage."""
async def _run_typed_async(rt: OspRuntime, slots: list[Slot], a: any, b: any) -> None {
    btag: int = rt.tag_of(b);
    for s in slots {
        if (s.trig_tag != UNTYPED) and rt.is_a(btag, s.trig_tag) {
            result = s.fn(a, b);
            if inspect.iscoroutine(result) {
                await result;
            }
            if _kernel._walk_stack and _kernel._walk_stack[-1].disengaged {
                return;
            }
        }
    }
}

"""Run untyped slots, awaiting any coroutine returned by an ability."""
async def _run_untyped_async(slots: list[Slot], a: any, b: any) -> None {
    for s in slots {
        if s.trig_tag == UNTYPED {
            result = s.fn(a, b);
            if inspect.iscoroutine(result) {
                await result;
            }
            if _kernel._walk_stack and _kernel._walk_stack[-1].disengaged {
                return;
            }
        }
    }
}

"""Async iterative DFS visit (mirrors `osp_kernel._visit_recursive` but
`await`s coroutine returns from abilities)."""
async def _visit_recursive_async(
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
            await _run_typed_async(rt, wdesc.entry, scope.wlk, cur);
            if scope.disengaged {
                return False;
            }
            await _run_untyped_async(ndesc.entry, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            await _run_typed_async(rt, ndesc.entry, cur, scope.wlk);
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
            await _run_typed_async(rt, ndesc.exit, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            await _run_untyped_async(ndesc.exit, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            await _run_typed_async(rt, wdesc.exit, scope.wlk, cur);
            if scope.disengaged {
                return False;
            }
        }
    }
    return not scope.disengaged;
}

"""Async counterpart to `osp_kernel.osp_spawn`. Uses the same `WalkScope` /
`_walk_stack` / `on_complete` plumbing so async walks participate in the same
scope-stack the sync kernel does; that lets `osp_visit` / `osp_report` /
`osp_disengage` work inside async abilities without a separate path."""
async def osp_spawn_async(
    rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list
) -> any {
    scope = WalkScope(wlk=wlk, path=[], next=`list(starts), ignores=[], reports=[]);
    _kernel._walk_stack.append(scope);
    ok = False;
    try {
        if scope.next {
            anchor = scope.next[0];
            await _run_untyped_async(wdesc.entry, wlk, anchor);
        }
        while scope.next and (not scope.disengaged) {
            nxt = scope.next.pop(0);
            if nxt not in scope.ignores {
                if not await _visit_recursive_async(rt, scope, wdesc, nxt) {
                    break;
                }
            }
        }
        if scope.path and (not scope.disengaged) {
            await _run_untyped_async(wdesc.exit, wlk, scope.path[-1]);
        }
        ok = True;
    } finally {
        _kernel._walk_stack.pop();
        rt.on_complete(scope, ok);
    }
    return wlk;
}
