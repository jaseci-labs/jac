"""Native cross-module flow-narrowing consumer (issue #6667): imports `use_it`
from xmod_narrow_lib, where the `is not None` narrowing actually lives, and just
calls it. The narrowing must apply on the imported-dependency compile path the
same way it does when the code is the entry module. Native-only (a .na.jac
library is not @sv-importable); the @sv result
{"present": "hit", "size": 5, "absent": "void"} is pinned in xmod_narrow_lib."""

import from xmod_narrow_lib { use_it }

def narrow_na() -> dict[str, any] {
    return use_it();
}
