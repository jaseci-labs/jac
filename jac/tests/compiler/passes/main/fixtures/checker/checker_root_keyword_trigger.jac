"""Regression fixture for issue #5049.

Using the `root` keyword (lowercase) as a walker ability trigger compiles
silently but the ability body never fires at runtime, because `root` resolves
to a Root node instance rather than the Root class the dispatcher needs.

The checker must emit E1116 for the `root` keyword case and leave the
correct `Root` class case clean.
"""

walker GoodWalker {
    can visit with Root entry { ; }   # valid — Root is the class
}

walker BadWalker {
    can visit with root entry { ; }   # E1116 — root is a runtime instance
}
