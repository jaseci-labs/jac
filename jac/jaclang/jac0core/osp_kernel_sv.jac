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

obj _ContextStack {
    has _var: any by postinit;

    def postinit {
        self._var = ContextVar('osp_walk_stack', default=None);
    }

    def _list -> list {
        v = self._var.get();
        return v if v is not None else [];
    }

    def append(x: any) {
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

with entry {
    _kernel._walk_stack = _ContextStack();
}

def isolate_request_walk_stack {
    if isinstance(_kernel._walk_stack, _ContextStack) {
        _kernel._walk_stack._var.set([]);
    }
}

glob _tag_of_cls: dict[(any, int)] = {},
     _cls_of_tag: list[any] = [],
     _desc_of_cls: dict[(any, WalkerDesc)] = {};

def _tag_for(cls: any) -> int {
    if cls in _tag_of_cls {
        return _tag_of_cls[cls];
    }
    t = len(_cls_of_tag);
    _tag_of_cls[cls] = t;
    _cls_of_tag.append(cls);
    return t;
}

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

def _unwrap(x: any) -> any {
    if isinstance(x, (NodeAnchor, EdgeAnchor)) {
        return x.archetype;
    }
    return x;
}

def _wrap_ability(f: any) -> any {
    def call(a: any, b: any, fn: any = f) -> any {
        return fn(_unwrap(a), _unwrap(b));
    }
    return call;
}

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

def _sv_tag_of(handle: any) -> int {
    return _tag_for(`type(_unwrap(handle)));
}

def _sv_is_a(tag: int, base: int) -> bool {
    return issubclass(cast(type, _cls_of_tag[tag]), cast(type, _cls_of_tag[base]));
}

def _sv_node_desc(tag: int) -> NodeDesc {
    d = desc_for(_cls_of_tag[tag]);
    return NodeDesc(type_tag=d.type_tag, entry=d.entry, exit=d.exit);
}

def _sv_on_complete(scope: WalkScope, ok: bool) {
    if isinstance(scope.wlk, WalkerArchetype) {
        anch = scope.wlk.__jac__;
        anch.path = `list(scope.path);
        anch.next = [];
        anch.ignores = [];
    }
    if _kernel._walk_stack {
        outer = _kernel._walk_stack[-1];
        for r in scope.reports {
            outer.reports.append(r);
        }
        return;
    }

    if isinstance(scope.wlk, WalkerArchetype) {
        scope.wlk.reports = scope.reports;
    }

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
        try {
            JacRuntimeInterface.get_context().mem.commit();
        } except Exception {
            ;
        }
    }
}

def make_sv_runtime -> OspRuntime {
    return OspRuntime(
        tag_of=_sv_tag_of,
        is_a=_sv_is_a,
        node_desc=_sv_node_desc,
        on_complete=_sv_on_complete
    );
}

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
