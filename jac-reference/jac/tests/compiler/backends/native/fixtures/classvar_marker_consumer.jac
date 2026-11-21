"""A consumer that links the `ClassVar`-importing dependency natively."""

import from .classvar_marker_dep { Tagged, make_tagged }


def run -> int {
    t: Tagged = make_tagged(21);
    return t.doubled();
}
