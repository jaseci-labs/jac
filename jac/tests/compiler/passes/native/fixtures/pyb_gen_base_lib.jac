"""A generic base class that stays Python-side.

The inline `::py::` block keeps this module out of any native closure, the
same device `pyb_base_lib.jac` uses: the fixture must measure the interop
bridge against a genuinely Python-resident base, not against a generic
class the placement solver happens to pull into the unit.
"""
import from abc { ABC }

obj PyGenBase[T](ABC) {
    has count: int = 0;

    def bump(n: int) -> int {
        self.count += n;
        return self.count;
    }

    def note_origin {
        ::py::
        self.count = self.count + 0
        ::py::
    }
}
