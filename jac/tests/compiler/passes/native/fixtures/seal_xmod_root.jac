"""Fixture: a clean root whose native import carries the demotion.

Everything in this module lowers. The un-lowerable method is in
`seal_xmod_dep.jac`, reached as a native cross-module import, so the abort stub
enters the sealed artifact through the dependency-linking path rather than the
root's own codegen.
"""

import from seal_xmod_dep { dep_scale }

def root_total(n: int) -> int {
    acc = 0;
    i = 0;
    while i < n {
        acc += dep_scale(i);
        i += 1;
    }
    return acc;
}
