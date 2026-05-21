"""Implementation for Counter declared in counter.na.jac.

Before fix: discover_base_file returned None for this file (only checked
.jac and .cl.jac, not .na.jac), so self was Unknown → E1032 on every
self.value / self.step access.

After fix: discovers counter.na.jac → self is Counter → no false errors.
"""

impl Counter.increment {
    self.value += self.step;
}

impl Counter.reset {
    self.value = 0;
}

impl Counter.current -> int {
    return self.value;
}
