"""A merge module the native import walk classifies Python-side.

The inline `::py::` body is the statically-known native-incompatible
construct, so the walk registers no struct type for `Merger` in any importing
unit. `merge` is a *static* method, which is the form #8248 dropped: the
importing unit found no native `Merger`, and the class-qualified call form had
no arm that said so.
"""
import from abc { ABC }
import from xmod_static_types { Item }

obj PyMergeBase(ABC) {
    has tag: str = "merge";

    def describe -> str {
        ::py::
        return "py:" + self.tag
        ::py::
    }
}

obj Merger(PyMergeBase) {
    static def merge(a: Item, b: Item) -> int {
        return a.value + b.value;
    }
}
