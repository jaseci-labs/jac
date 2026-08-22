"""An ABC arm over an operand whose class inherits a Python-side base.

`PyBase` lives in a module the native import walk never registers, and it
inherits `abc.ABC` there, so `Kid`'s real MRO runs through classes this unit
only holds a shadow handle to. Which abstract base classes a `Kid` inhabits is
therefore not answerable from the native layout: reducing `Sequence` to the
builtin containers would report `False` for a `PyBase` that happened to inherit
one. The check refuses instead.

`Kid` carries a `postinit` of its own so that the construction itself
stays legal: without one, `PyBase.postinit` would run on the Python
shadow where `Kid`'s native slots do not exist, and E5088 would refuse
the construction before the isinstance check this fixture exists to
measure was ever reached. Chaining with `super.postinit()` is the
supported shape and bridges.
"""

import from pyb_base_lib { PyBase }

obj Kid(PyBase) {
    has extra: int = 1;

    def postinit {
        super.postinit();
    }
}

def chk -> int {
    k = Kid(label="x");
    if isinstance(k, Sequence) {
        return 1;
    }
    return 0;
}
