"""The shared bodies both merge probes operate on.

Hosting the archetypes in a native-clean module of their own is the
`annex_weave.jac` workaround the seal work reached for; keeping them here lets
the two merge modules differ in exactly one thing -- whether their class
inherits a Python-side base.
"""

obj Item {
    has value: int = 0;
}
