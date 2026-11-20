"""Construct and spawn a compiler walker from a native root.

The context carries diagnostics; the walker owns its traversal state.
"""

import from jaclang.compiler.frontend.unitree { Module, TreeWalker, UniNode, Name }
import from jaclang.compiler.passes.context { CompileContext }

walker LocalCountPass(TreeWalker) {
    can enter_walk with UniNode entry {
        self.ctx.enter_node(here);
    }

    can exit_walk with UniNode exit {
        self.ctx.exit_node(here);
    }

    has ctx: CompileContext,
        module: Module,
        seen: int = 0;

    can enter_name with Name entry {
        self.seen = self.seen + 1;
    }
}

def probe_construct(m: Module) -> int {
    p = LocalCountPass(
        module=m,
        ctx=CompileContext(
            current_node=m, from_pass=LocalCountPass, pass_name="LocalCountPass"
        )
    );
    m spawn p;
    return p.seen;
}
