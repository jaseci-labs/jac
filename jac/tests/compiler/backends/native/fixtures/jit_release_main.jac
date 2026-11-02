"""Fixture: a JIT unit whose entry calls a demoted callee of a linked unit.

The entry cannot demote on its own, so the whole module falls back to the
server codespace -- after it has already compiled `jit_release_mid.jac` and
its dependency to learn their verdicts. Python then imports `jit_release_mid`
as a JIT unit of its own, which must still lower: `mid_add` and its call into
`jit_release_leaf.jac` stay native.
"""

import from jit_release_mid { mid_seam, mid_add }

with entry {
    print(mid_seam(2));
    print(mid_add(2));
}
