"""A generic base chain that stays Python-side, shaped like the pass chain.

`HollowGenBase[T_in, T_out]` / `HollowGenMid[T, R]` is `BaseTransform` /
`Transform` in miniature: two type parameters threaded through a middle
class, a slot typed by a parameter, and a `postinit` that runs the work
and stores its answer. The inline `::py::` block is what keeps the module
out of any native closure, so a native unit inheriting the chain must
reach it through the interop bridge.
"""
import from abc { ABC }

obj HollowGenBase[T_in, T_out](ABC) {
    has ir_in: T_in,
        marker: int = 0,
        ir_out: T_out postinit;

    def postinit -> None {
        self.marker = self.marker + 10;
        self.ir_out = self.transform(ir_in=self.ir_in);
    }

    def transform(ir_in: T_in) -> T_out {
        return ir_in;
    }

    def note_origin {
        ::py::
        self.marker = self.marker + 0
        ::py::
    }
}

obj HollowGenMid[T, R](HollowGenBase[T, R]) {
    has cur: int = 0;
}
