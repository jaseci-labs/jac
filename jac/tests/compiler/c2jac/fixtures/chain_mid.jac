"""Middle module for the jac2c transitive-import test (#7145).

Imports the ref-type `Cell` from `chain_leaf` and hands it up to `chain_main`
through the free function `make_cell`, which constructs and pre-bumps a `Cell`.
`chain_main` imports only THIS module, so `Cell` reaches the top of the chain
transitively.
"""

import from chain_leaf { Cell }

def make_cell(start: int) -> Cell {
    c = Cell(start);
    c.bump();
    return c;
}
