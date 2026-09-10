import inspect;
import jaclang.runtime.osp_kernel as _kernel;
import from contextvars { ContextVar }
import from types { UnionType }
import from typing { cast }
import from jaclang.runtime.archetype {
    NodeAnchor,
    EdgeAnchor,
    ObjectSpatialFunction,
    WalkerArchetype
}
import from jaclang.runtime.osp_graph_sv { cls_of_tag, tag_of_cls }
import from jaclang.runtime.osp_kernel {
    Slot,
    WalkerDesc,
    NodeDesc,
    WalkScope,
    OspRuntime,
    UNTYPED
}

obj _ContextStack {
    has _var: any postinit;

    def postinit {
        self._var = ContextVar('osp_walk_stack', `default=None);
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
    _kernel.DEFAULT.stack = cast(list[WalkScope], _ContextStack());
}

def isolate_request_walk_stack {
    if isinstance(_kernel.DEFAULT.stack, _ContextStack) {
        _kernel.DEFAULT.stack._var.set([]);
    }
}

glob _desc_of_cls: dict[(any, WalkerDesc)] = {};

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

def _slots_from(funcs: list[ObjectSpatialFunction]) -> list[Slot] {
    slots: list[Slot] = [];
    for f in funcs {
        members = _trigger_members(f.trigger);
        if not members {
            slots.append(Slot(trig_tag=UNTYPED, fn=f.func));
        } else {
            for m in members {
                slots.append(Slot(trig_tag=tag_of_cls(m), fn=f.func));
            }
        }
    }
    return slots;
}

def _mro_funcs(cls: any, attr: str) -> list {
    merged: dict = {};
    for c in reversed(cls.__mro__) {
        clsfns = c.__dict__.get(attr);
        if clsfns {
            for fn in clsfns {
                merged[fn.name] = fn;
            }
        }
    }
    return `list(merged.values());
}

def desc_for(cls: any) -> WalkerDesc {
    if cls in _desc_of_cls {
        return _desc_of_cls[cls];
    }
    desc = WalkerDesc(
        type_tag=tag_of_cls(cls),
        `entry=_slots_from(
            cast(list[ObjectSpatialFunction], _mro_funcs(cls, '_jac_entry_funcs_'))
        ),
        `exit=_slots_from(
            cast(list[ObjectSpatialFunction], _mro_funcs(cls, '_jac_exit_funcs_'))
        )
    );
    _desc_of_cls[cls] = desc;
    return desc;
}

def _sv_tag_of(handle: any) -> int {
    return tag_of_cls(`type(handle));
}

def _sv_is_a(tag: int, base: int) -> bool {
    tc = cls_of_tag(tag);
    bc = cls_of_tag(base);
    return tc is not None and bc is not None and issubclass(tc, bc);
}

glob _ndesc_of_cls: dict[type, NodeDesc] = {};

def _sv_node_desc(tag: int) -> NodeDesc {
    cls = cls_of_tag(tag);
    if cls is None {
        return NodeDesc(type_tag=tag, `entry=[], `exit=[]);
    }
    cached = _ndesc_of_cls.get(cls);
    if cached is not None {
        return cached;
    }
    d = desc_for(cls);
    nd = NodeDesc(type_tag=d.type_tag, `entry=d.`entry, `exit=d.`exit);
    _ndesc_of_cls[cls] = nd;
    return nd;
}

def _sv_on_complete(scope: WalkScope, ok: bool) {
    if isinstance(scope.wlk, WalkerArchetype) {
        anch = scope.wlk.__jac__;
        walked: list[(NodeAnchor | EdgeAnchor)] = [];
        for step in scope.path {
            step_anchor = step?.__jac__;
            if isinstance(step_anchor, (NodeAnchor, EdgeAnchor)) {
                walked.append(step_anchor);
            }
        }
        anch.path = walked;
        anch.next = [];
        anch.ignores = [];
    }
    if scope.nested {
        return;
    }

    if isinstance(scope.wlk, WalkerArchetype) {
        scope.wlk.reports = scope.reports;
    }

    import from jaclang.runtime.runtime { JacRuntime }
    ctx = None;
    try {
        ctx = JacRuntime.peek_context();
        if ctx is None {
            return;
        }
        cs = ctx.call_state.get(None);
        if cs is not None {
            for r in scope.reports {
                cs.reports.put_nowait(r);
            }
        }
    } except Exception {}
    if ok and (ctx is not None) {
        try {
            ctx.mem.commit();
        } except Exception {}
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

async def osp_spawn_async(
    rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list
) -> any {
    eng = _kernel.DEFAULT;
    scope = eng.begin(wlk, starts);
    ok = False;
    try {
        while True {
            s = eng.next_slot(rt, scope, wdesc);
            if s is None {
                break;
            }
            result = s.fn(scope.cur_a, scope.cur_b);
            if inspect.iscoroutine(result) {
                await result;
            }
        }
        ok = True;
    } finally {
        eng.finish(scope, ok, rt);
    }
    return wlk;
}
