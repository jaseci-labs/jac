"""The `cast` erasure has to reach a body written in an annexed impl file.

Every one of the compiler's own `cast` sites lives in a `.impl.jac` annex
while the `import from typing { cast }` that binds the name sits in the
declaring module, so an erasure that only looked at the body's own file would
clear none of them.
"""

import from typing { cast }


obj Box {
    has n: int = 0;

    def doubled -> int;
}


def run -> int;
