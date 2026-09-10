import from jaclang.runtime.osp_kernel { osp_skip_rest }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.frontend.unitree {
    Ability,
    AssertStmt,
    Assignment,
    GlobalVars,
    IfStmt,
    Import,
    InForStmt,
    ParamVar,
    TypeParam,
    UniNode
}

def _is_comptime_marker(nd: UniNode) -> bool {
    if isinstance(nd, GlobalVars) {
        return nd.is_frozen;
    }
    if isinstance(
        nd,
        (
            Ability,
            AssertStmt,
            Assignment,
            IfStmt,
            Import,
            InForStmt,
            ParamVar,
            TypeParam
        )
    ) {
        return nd.is_comptime;
    }
    return False;
}

def comptime_reach(top: UniNode) -> set[int] {
    keep: set[int] = set();
    stack: list[UniNode] = [top];
    marked: list[UniNode] = [];
    while stack {
        nd = stack.pop();
        if _is_comptime_marker(nd) {
            marked.append(nd);
        }
        for k in nd.kid {
            if k {
                stack.append(k);
            }
        }
    }
    for m in marked {
        cur: (UniNode | None) = m;
        while cur is not None and id(cur) not in keep {
            keep.add(id(cur));
            cur = cur.parent;
        }
        inner: list[UniNode] = [m];
        while inner {
            nd = inner.pop();
            keep.add(id(nd));
            for k in nd.kid {
                if k {
                    inner.append(k);
                }
            }
        }
    }
    return keep;
}

walker ComptimeResolvePass(TypeCheckPass) {
    has _armed: bool = False,
        _keep: set[int] = set();

    static has HOST_PASS: bool = True;

    override def before_pass {
        self._keep = comptime_reach(self.ir_in);
        self._armed = bool(self._keep) and not self.ir_in.ct_resolved;
        if self._armed {
            super.before_pass();
        }
    }

    override def after_pass -> None {
        if not self._armed {
            return;
        }
        self.ir_in.ct_resolved = True;
    }

    can enter_walk with UniNode entry {
        if self.is_canceled() or here.ct_pruned {
            osp_skip_rest();
            return;
        }
        self.cur_node = here;
        if not self._armed or id(here) not in self._keep {
            osp_skip_rest();
        }
    }

    can exit_walk with UniNode exit {
        if here.ct_pruned {
            osp_skip_rest();
            return;
        }
        self.cur_node = here;
        if self.is_canceled() or not self._armed or id(here) not in self._keep {
            osp_skip_rest();
        }
    }
}
