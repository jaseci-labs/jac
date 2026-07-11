"""Fixture for enum metaclass data-attribute type resolution.

`__members__`, `_member_names_`, `_member_map_` and `_value2member_map_` live
on the enum metaclass (EnumType), not in the enum's own MRO. The checker
synthesizes their types so valid usage type-checks and misuse is still caught.
Exactly one line below is expected to error.
"""

import from enum { StrEnum }

class Tokens(StrEnum) {
    A = "a";
    B = "b";
}

def member_names() -> list[str] {
    out: list[str] = [];
    for k in Tokens.__members__ {
        out.append(k);
    }
    return out;
}

with entry {
    names_ok: list[str] = Tokens._member_names_;
    members_ok: dict[str, Tokens] = Tokens._member_map_;
    v2m_ok: dict[str, Tokens] = Tokens._value2member_map_;
    val_ok: str = Tokens.__members__["A"].value;
    # __members__ is dict[str, Tokens], not int: this must error.
    bad: int = Tokens.__members__;
}
