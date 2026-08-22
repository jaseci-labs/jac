"""Module-form `typing.Any` is the deliberate escape hatch and stays legal.

E1122 refuses the shapes that BIND the bare name `Any` as a jac spelling of a
type. Reflection over annotations needs the runtime `typing.Any` object, which
is not a type spelling at all -- reached through the module, it is untouched.
"""

import typing;

def is_any_sentinel(target: any) -> bool {
    return target is typing.Any;
}
