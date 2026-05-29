"""Parity tests: the portable OSP kernel driven with server-derived dispatch
descriptors (jaclang.jac0core.osp_kernel_sv) must reproduce the live server
`spawn` engine on real archetypes — same walker state, same subtyping and
untyped-entry semantics. This validates the descriptor-emission model before it
replaces per-backend dispatch."""

import from jaclang.jac0core.osp_kernel { osp_spawn }
import from jaclang.jac0core.osp_kernel_sv { make_sv_runtime, desc_for }

node Base {
    has v: int;
}

node Sub(Base) {}

node Other {
    has v: int = 0;
}

walker Acc {
    has total: int = 0;

    can grab with Base entry {
        self.total += here.v;
    }
}

walker Starter {
    has hits: int = 0;

    can begin with entry {
        self.hits += 1;
    }
}

test "kernel parity: subtyping entry dispatch and walker state" {
    rt = make_sv_runtime();
    # Ground truth: the server engine fires `grab with Base entry` on a Sub
    # node (subtyping) and accumulates into walker state.
    real = Acc();
    real spawn Sub(v=5);
    # Kernel + server-derived descriptors must produce the same result.
    via_kernel = Acc();
    osp_spawn(rt, via_kernel, desc_for(Acc), Sub(v=5));
    assert real.total == 5;
    assert via_kernel.total == real.total;
}

test "kernel parity: untyped walker entry runs once at the root" {
    rt = make_sv_runtime();
    real = Starter();
    real spawn Base(v=0);
    via_kernel = Starter();
    osp_spawn(rt, via_kernel, desc_for(Starter), Base(v=0));
    assert real.hits == 1;
    assert via_kernel.hits == real.hits;
}

test "kernel parity: typed ability does not fire on an unrelated type" {
    rt = make_sv_runtime();
    # `grab with Base entry` must not fire on an Other node (not a Base).
    real = Acc();
    real spawn Other();
    via_kernel = Acc();
    osp_spawn(rt, via_kernel, desc_for(Acc), Other());
    assert real.total == 0;
    assert via_kernel.total == real.total;
}
