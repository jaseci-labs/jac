"""Module-form `typing.List` is the deliberate escape hatch and stays legal.

E1123 refuses the shapes that BIND a deprecated alias as a jac spelling of a
type. Reflection *over* annotations is a different thing: a tool that reads
`__annotations__` and wants to report "this one was written with the deprecated
alias" needs the runtime object to compare against, not a name in the type
namespace. Reached through the module it is untouched, exactly as `typing.Any`
is under E1122.

Note the comparison is against the raw annotation, not against
`typing.get_origin(...)` -- get_origin normalizes `List` and `List[int]` alike
to `list`, so an `is typing.List` test downstream of it can never be true.
"""

import typing;

def annotation_uses_deprecated_alias(annotation: any) -> bool {
    return annotation is typing.List or annotation is typing.Dict;
}
