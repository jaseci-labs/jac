"""Fixture: a Python descriptor (defines __get__) is unwrapped on access.

Expected: 0 errors. `r.rowcount` resolves to __get__'s instance-access return
(int), not the descriptor object, so the comparison typechecks.
"""

import from checker_descriptor_get_mod { Result }

def use_it {
    r = Result();
    x = r.rowcount > 0;
}
