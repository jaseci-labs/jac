"""Cross-module virtual-dispatch importer for the jac2c Emit leg of #7145.

`Sq` subclasses the imported `Shape` and overrides `speak` only. Calling
`Sq(100).who()` enters the base `who` (compiled in xmod_base's TU), which
dispatches `self.speak()` back to `Sq__speak` in THIS TU through the shared
vtable slot. `run_base` exercises the non-overridden path.
"""

import from xmod_base { Shape }

obj Sq(Shape) {
    def speak -> int {
        return 2;
    }
}

def run_base -> int {
    a = Shape(10);
    return a.who();
}

def run_derived -> int {
    d = Sq(100);
    return d.who();
}
