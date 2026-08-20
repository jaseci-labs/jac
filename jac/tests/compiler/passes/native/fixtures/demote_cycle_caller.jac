"""The caller half of a demotion/emission ordering cycle.

`CycleReporter.describe` calls `cycle_bad_fmt`, a function whose defining
module demotes it -- but that module is inflight above this one when this
module compiles (the `import type` back-edge), so the verdict is unknowable
at emission time. This is `Alert.pretty_print` calling
`pretty_print_source_location` in miniature: without verdict re-validation
the emitted IR keeps a live call to a symbol the callee's rename-and-pop
then removes, and the linked artifact carries an undefined symbol.
"""

import from .demote_cycle_helpers { cycle_bad_fmt }

obj CycleReporter {
    has count: int = 0;

    def describe(n: int) -> str {
        return cycle_bad_fmt(n);
    }

    def bump -> int {
        self.count += 1;
        return self.count;
    }
}
