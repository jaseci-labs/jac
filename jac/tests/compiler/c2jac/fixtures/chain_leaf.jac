"""Leaf module for the jac2c transitive-import test (#7145).

Defines a reference-type `Cell` (heap object behind the RC header). It is
imported by the middle module `chain_mid.jac` and reaches the top module
`chain_main.jac` only transitively: `chain_main` never names `chain_leaf`, yet
the emitted C for `chain_main`'s translation unit must forward-declare
`struct Cell` and `extern` its methods. That only happens if jac2c walks the
import graph transitively instead of stopping at direct imports.
"""

obj Cell {
    has v: int;

    def init(start: int) {
        self.v = start;
    }

    def bump -> int {
        self.v = self.v + 1;
        return self.v;
    }

    def get -> int {
        return self.v;
    }
}
