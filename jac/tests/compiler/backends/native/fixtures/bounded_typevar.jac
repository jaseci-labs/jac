"""Construction through `type[W]` and field reads on a `W` bounded by an archetype."""

import from bounded_typevar_lib { Ctx, PassBase, CountPass }

def run_walker[W: PassBase](walker_type: type[W], label: str) -> W {
    ctx = Ctx(name=label);
    walk = walker_type(ctx=ctx, label=label);
    return walk;
}

def run_pass[W: PassBase](pass_cls: type[W], label: str) -> W {
    inst: (W | None) = None;
    try {
        inst = run_walker(pass_cls, label);
        return inst;
    } finally {
        eff = inst.ctx.name if (inst is not None and inst.ctx.name) else "none";
        print("ran", eff);
        if inst is not None {
            print("time", inst.ctx.time_taken);
        }
    }
}

with entry {
    p = run_pass(CountPass, "count");
    print(p.label);
    w = run_walker(PassBase, "base");
    print(w.ctx.name, w.label);
}
