"""Cross-module virtual-dispatch base for the jac2c Emit leg of #7145.

`Shape` is defined here and imported by `xmod_main.jac`. Its `who` method is
compiled in THIS translation unit yet calls `self.speak()` virtually, so the
call must dispatch through the vtable to a subclass override that lives in a
different module. That only works if lib's `Shape__vtable` and the importer's
`Sq__vtable` agree on the `speak`/`who` slot numbering, which the whole-program
shared layout is what guarantees.
"""

obj Shape {
    has base: int;

    def init(b: int) {
        self.base = b;
    }

    def speak -> int {
        return 1;
    }

    def who -> int {
        return (self.speak() + self.base);
    }
}
