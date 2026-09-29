"""A brand whose base is reached through a comptime import.

`comptime import` emits no runtime binding, and a distinct alias is an erased
brand over a primitive, so the lowered module must bind the primitive itself --
binding the spelling of the base instead leaves the name unbound at load time.
"""

comptime import from base_alias { MyInt }


type Brand := MyInt;


def mk(raw: int) -> Brand {
    return Brand(raw);
}
