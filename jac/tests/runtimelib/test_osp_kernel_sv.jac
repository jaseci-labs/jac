"""Parity tests: the portable OSP kernel driven with server-derived dispatch
descriptors (jaclang.jac0core.osp_kernel_sv) must reproduce the live server
`spawn` engine on real archetypes — same walker state, same subtyping and
untyped-entry semantics. This validates the descriptor-emission model before it
replaces per-backend dispatch."""

import asyncio;
import jaclang.jac0core.osp_kernel as _kernel;
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
    osp_spawn(rt, via_kernel, desc_for(Acc), [Sub(v=5)]);
    assert real.total == 5;
    assert via_kernel.total == real.total;
}

test "kernel parity: untyped walker entry runs once at the root" {
    rt = make_sv_runtime();
    real = Starter();
    real spawn Base(v=0);
    via_kernel = Starter();
    osp_spawn(rt, via_kernel, desc_for(Starter), [Base(v=0)]);
    assert real.hits == 1;
    assert via_kernel.hits == real.hits;
}

test "kernel parity: typed ability does not fire on an unrelated type" {
    rt = make_sv_runtime();
    # `grab with Base entry` must not fire on an Other node (not a Base).
    real = Acc();
    real spawn Other();
    via_kernel = Acc();
    osp_spawn(rt, via_kernel, desc_for(Acc), [Other()]);
    assert real.total == 0;
    assert via_kernel.total == real.total;
}

test "sv walk-scope stack is isolated across concurrent asyncio tasks" {
    # The sv binding swaps `osp_kernel._walk_stack` for a ContextVar-backed
    # proxy so concurrent spawns (different requests / asyncio tasks) get
    # isolated scope stacks. Regression guard: a ContextVar only isolates on
    # `.set()`, so a proxy that mutated the `.get()`-ed list in place would let
    # gather() tasks -- created under a context where the stack was already
    # populated -- share one list and clobber each other's scopes (reports then
    # bubble to the wrong walk). Poison the root context first to expose it.
    stack = _kernel._walk_stack;
    stack.append("root");
    stack.pop();

    async def probe(name: str) -> tuple {
        stack.append(name);
        await asyncio.sleep(0.01);
        seen = stack[-1];
        depth = len(stack);
        stack.pop();
        return (name, seen, depth);
    }
    async def run -> list {
        return await asyncio.gather(probe("a"), probe("b"), probe("c"));
    }
    results = asyncio.run(run());
    for (name, seen, depth) in results {
        assert seen == name , (
            f"task {name} saw {seen} on top of the walk stack -- scopes leaked across tasks"
        );
        assert depth == 1 , (
            f"task {name} saw stack depth {depth} -- the walk stack is shared across tasks"
        );
    }
}
