"""A pass constructed inside a native root, which is the rung-3 gate.

Measured by `test_pass_base_chain_lowers.jac`. `probe_construct` is the
smallest thing a fused root has to be able to do: construct a pass over a
tree it already holds and read a field back off it. Nothing here is
Python-lane -- the construction passes no `prog`, because the pass base
declares none.
"""

import from jaclang.jac0core.unitree { Module, Name }
import from jaclang.jac0core.passes.uni_pass { UniPass }

obj LocalCountPass(UniPass) {
    has seen: int = 0;

    def enter_name(nd: Name) {
        self.seen = self.seen + 1;
    }
}

def probe_construct(m: Module) -> int {
    p = LocalCountPass(ir_in=m);
    return p.seen;
}
