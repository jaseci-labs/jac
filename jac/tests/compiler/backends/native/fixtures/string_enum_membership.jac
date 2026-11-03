"""Text tested against containers of a string enum's members.

A `StrEnum` member is its string, so `"KW_ROOT" in {Tok.KW_ROOT}` holds in
Python. Natively a member is its ordinal: the probe text is matched to the
member whose value it spells (or to none) and that ordinal is looked up.
"""
import from enum { StrEnum }

class Tok(StrEnum) {
    with entry {
        KW_ROOT = 'KW_ROOT';
        KW_SUPER = 'KW_SUPER';
        NAME = 'NAME';
    }
}

obj Named {
    has name: str = "";
}

def in_set(n: Named) -> bool {
    banned = {Tok.KW_ROOT, Tok.KW_SUPER};
    return n.name in banned;
}

def in_dict(n: Named) -> bool {
    spelled = {Tok.NAME: 1, Tok.KW_SUPER: 2};
    return n.name in spelled;
}

def not_in_list(n: Named) -> bool {
    return n.name not in [Tok.KW_ROOT, Tok.NAME];
}

def chk_membership -> int {
    top = Named(name="KW_ROOT");
    sup = Named(name="KW_SUPER");
    other = Named(name="other");
    return int(in_set(top))
        + 2 * int(in_set(sup))
        + 4 * int(in_set(other))
        + 8 * int(in_dict(sup))
        + 16 * int(in_dict(top))
        + 32 * int(not_in_list(other))
        + 64 * int(not_in_list(top));
}

with entry {
    print(chk_membership());
}
