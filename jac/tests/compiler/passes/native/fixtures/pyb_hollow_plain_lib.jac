"""The same shape with no type parameters anywhere.

The control that separates the two candidate causes: if genericity were
the defect, this module's subclass would construct correctly. It does
not, which places the fault in shadow construction rather than in the
generic machinery.
"""
import from abc { ABC }

obj PlainBase(ABC) {
    has seed: int = 0;

    def postinit -> None {
        self.seed = self.hook(self.seed);
    }

    def hook(n: int) -> int {
        return n + 1;
    }

    def note_origin {
        ::py::
        self.seed = self.seed + 0
        ::py::
    }
}
