"""A Python-side base whose ordinary methods self-dispatch.

`pyb_hollow_plain_lib.jac` carries the same hazard through `postinit`, which
E5088 refuses at the construction site. This base has no `postinit` at all:
the self-dispatch sits in an ordinary method, so nothing about constructing
the subclass is suspicious and the hazard only appears when that method is
called (#8310).

`dispatches` and `dispatches_twice` reach `self.hook`, which a subclass may
override. `plain` reaches nothing, and `calls_free` reaches a module function
rather than `self` -- both are the control: they carry no shadow hazard and
must keep lowering, or the refusal is over-broad.

The `::py::` block in `note_origin` is what keeps this module Python-side, so
a subclass in a native unit gets a pyb shadow rather than a lowered base.
"""
import from abc { ABC }

def _double(n: int) -> int {
    return n * 2;
}


obj DispatchBase(ABC) {
    has seed: int = 0;

    """Reaches `self.hook`, which a subclass may override."""
    def dispatches(n: int) -> int {
        return self.hook(n) * 10;
    }

    """The same hazard, reached through a second call in a longer body."""
    def dispatches_twice(n: int) -> int {
        acc = self.plain(n);
        return acc + self.hook(n);
    }

    """A subclass overriding this changes what `dispatches` computes."""
    def hook(n: int) -> int {
        return n + 1;
    }

    """Reaches nothing on `self`: no shadow hazard."""
    def plain(n: int) -> int {
        return n * 3;
    }

    """Reaches a module function rather than `self`: no shadow hazard."""
    def calls_free(n: int) -> int {
        return _double(n);
    }

    def note_origin {
        ::py::
        self.seed = self.seed + 0
        ::py::
    }
}
