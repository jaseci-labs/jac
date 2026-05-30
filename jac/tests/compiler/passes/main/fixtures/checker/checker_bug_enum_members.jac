"""Bug #ENUM-META-1: Enum.__members__ falsely flagged as E1030.

__members__ lives on EnumMeta (metaclass), not in the enum MRO.
Expected: 0 errors.
"""

enum Color { RED = 1, GREEN = 2, BLUE = 3 }

with entry {
    # Direct access
    members = Color.__members__;

    # `in` operator (proves @property unwrapped to MappingProxyType)
    exists: bool = "RED" in Color.__members__;

    # Subscript (proves it's MappingProxyType, not the property object)
    red = Color.__members__["RED"];
}
