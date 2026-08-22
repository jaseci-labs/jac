# ceval slice for na_concat native build (P3.2b: re-export from ceval.jac).
# na_concat fuses objects.jac + this module; runtime consumers import ceval directly.

import from ceval { PyModule, PyNoOpInit, py_truth, }
