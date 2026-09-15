"""Transitive native imports across directories: this entry reaches
`walkup_pkg.inner.mid` by the dotted walk-up path, and `mid` reaches its
sibling `leaf` by a relative import. The sibling hop is the regression pin: a
module compiled as a native dependency stamps its import facts before its own
codespace is decided, so without native intent the relative import was
resolved with inference off, never found `leaf.jac`, and `mid_tag` was
demoted to Python-only. Driven by test_walkup_imports.jac through `jac
nacompile` (the AOT path the single-binary launcher is built with).
"""

import from walkup_pkg.inner.mid { mid_tag }

with entry {
    print(mid_tag(7));
}
