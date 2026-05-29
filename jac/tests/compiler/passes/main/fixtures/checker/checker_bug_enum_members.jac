"""Bug #ENUM-META-1: Enum.__members__ falsely flagged as E1030.

`Color.__members__` is provided by `EnumMeta` (the metaclass), not by `Enum`
or any entry in the class MRO. The type checker only walked the MRO and never
checked the metaclass, so accessing `__members__` on an enum class raised:

  E1030: Attribute '__members__' not found in type 'Color'

Additionally, because `__members__` is a `@property` on `EnumMeta`, the raw
symbol was a FunctionType; without property-descriptor unwrapping the follow-on
`in` check raised a false "right operand does not support __contains__".

Expected: 0 errors. All patterns below are valid Python/Jac.
"""

enum Color { RED = 1, GREEN = 2, BLUE = 3 }

enum Direction {
    NORTH = "N",
    SOUTH = "S",
    EAST = "E",
    WEST = "W"
}

with entry {
    # Case 1: Direct access to __members__
    members = Color.__members__;

    # Case 2: Membership test — `name in Color.__members__`
    name: str = "RED";
    exists: bool = name in Color.__members__;

    # Case 3: Subscript access — `Color.__members__["RED"]`
    red = Color.__members__["RED"];

    # Case 4: __members__ on a different enum
    dir_members = Direction.__members__;

    # Case 5: Membership test with variable
    direction_name: str = "NORTH";
    dir_exists: bool = direction_name in Direction.__members__;
}
