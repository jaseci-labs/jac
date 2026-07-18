"""Top module for the jac2c transitive-import test (#7145).

Imports only `make_cell` from `chain_mid` and never names `chain_leaf`, yet it
receives and drives a `Cell` value defined two modules down. jac2c must resolve
`w.bump()` / `w.get()` to the mangled `Cell__bump` / `Cell__get` symbols and
`extern`-declare `struct Cell` in this translation unit, which is only possible
with a transitive walk of the import graph.
"""

import from chain_mid { make_cell }

def run_chain -> int {
    w = make_cell(5);
    w.bump();
    return w.get();
}

def run_sum -> int {
    a = make_cell(1);
    b = make_cell(10);
    return (a.get() + b.get());
}
