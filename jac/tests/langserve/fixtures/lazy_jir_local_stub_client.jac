"""Client file that imports a sibling .pyi stub module."""

import from lazy_jir_local_stub { Widget }

def total(w: Widget) -> int {
    return w.count;
}
