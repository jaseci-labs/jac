"""A brand whose base is reached through a type-only import.

`import type` is a checker-only binding, so the same rule holds as for a
comptime import: the brand binds the primitive it resolved to.
"""

import type from base_alias { MyInt }


type Brand := MyInt;


def mk(raw: int) -> Brand {
    return Brand(raw);
}
