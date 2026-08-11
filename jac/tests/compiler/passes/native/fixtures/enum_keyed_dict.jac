"""Fixture: dicts keyed by enum members, string-valued and int-valued.

A native dict stores an enum key as the enum's native int representation:
the member ordinal for a string-valued enum, the declared value for an
int-valued enum. Hashing and equality therefore run on an i64, which is
what makes `dict[Kind, str]` a cheaper table than the `dict[str, str]`
spelling it is often worked around with.

The two representations must not be confused once a key is read back out of
the table. `Level` below is chosen so they diverge: LOW's value (2) equals
HIGH's ordinal (2), and MID/HIGH's values sit past the end of the member
list. Reading `.name`/`.value` off a key recovered from the table has to
route through the value->ordinal mapping for an int-valued enum, and pass
the ordinal straight through for a string-valued one.
"""

enum Kind { NAME = "NAME", NUMBER = "NUMBER", STRING = "STRING", PLUS = "+" }

enum Level { LOW = 2, MID = 25, HIGH = 40 }

glob KIND_TAB: dict[Kind, str] = {
         Kind.NAME: "n",
         Kind.NUMBER: "#",
         Kind.STRING: "s"
     },
     LEVEL_TAB: dict[Level, str] = {Level.LOW: "l", Level.MID: "m", Level.HIGH: "h"};

# Opaque producers: the returned member is not a compile-time constant at the
# lookup site, so the table is probed with a runtime enum-typed value.
def pick_kind(i: int) -> Kind {
    if i == 0 {
        return Kind.NAME;
    }
    if i == 1 {
        return Kind.NUMBER;
    }
    if i == 2 {
        return Kind.STRING;
    }
    return Kind.PLUS;
}

def pick_level(i: int) -> Level {
    if i == 0 {
        return Level.LOW;
    }
    if i == 1 {
        return Level.MID;
    }
    return Level.HIGH;
}

def str_by_member -> str {
    return KIND_TAB[Kind.NUMBER];
}

def str_by_runtime_key -> str {
    k = pick_kind(2);
    return KIND_TAB[k];
}

def str_contains -> int {
    hit = pick_kind(0) in KIND_TAB;
    miss = pick_kind(3) in KIND_TAB;
    return (1 if hit else 0) + (10 if miss else 0);
}

def str_get_default -> str {
    return KIND_TAB.get(pick_kind(3), "?") + KIND_TAB.get(Kind.NAME, "?");
}

def str_get_no_default -> str {
    absent = KIND_TAB.get(pick_kind(3));
    present = KIND_TAB.get(Kind.STRING);
    left = "none" if absent is None else absent;
    right = "none" if present is None else present;
    return left + right;
}

def str_iter_keys -> str {
    out = "";
    for k in KIND_TAB {
        out += k.value;
        out += ";";
    }
    return out;
}

def str_iter_names -> str {
    out = "";
    for k in KIND_TAB {
        out += k.name;
        out += "=";
        out += KIND_TAB[k];
        out += ";";
    }
    return out;
}

def str_incremental -> str {
    d: dict[Kind, str] = {};
    d[Kind.PLUS] = "p";
    d[Kind.NAME] = "n";
    d[Kind.PLUS] = "q";
    return d[Kind.PLUS] + d[Kind.NAME];
}

def str_incremental_len -> int {
    d: dict[Kind, str] = {};
    d[Kind.PLUS] = "p";
    d[Kind.NAME] = "n";
    d[Kind.PLUS] = "q";
    return len(d);
}

def int_by_member -> str {
    return LEVEL_TAB[Level.HIGH];
}

def int_by_runtime_key -> str {
    lv = pick_level(1);
    return LEVEL_TAB[lv];
}

def int_contains -> int {
    return 1 if pick_level(2) in LEVEL_TAB else 0;
}

def int_get_default -> str {
    return LEVEL_TAB.get(Level.LOW, "?");
}

def int_iter_values -> int {
    total = 0;
    for lv in LEVEL_TAB {
        total += lv.value;
    }
    return total;
}

def int_iter_names -> str {
    out = "";
    for lv in LEVEL_TAB {
        out += lv.name;
        out += "=";
        out += LEVEL_TAB[lv];
        out += ";";
    }
    return out;
}

def int_incremental -> str {
    d: dict[Level, str] = {};
    d[Level.HIGH] = "h";
    d[Level.LOW] = "l";
    return d[Level.HIGH] + d[Level.LOW];
}

# Every member of a four-member enum keys its own slot: no two distinct
# members may land on the same entry, and none may shadow another.
def distinct_members -> str {
    d: dict[Kind, str] = {};
    d[Kind.NAME] = "0";
    d[Kind.NUMBER] = "1";
    d[Kind.STRING] = "2";
    d[Kind.PLUS] = "3";
    out = "";
    for i in range(4) {
        out += d[pick_kind(i)];
    }
    return out;
}

def distinct_members_len -> int {
    d: dict[Kind, str] = {};
    d[Kind.NAME] = "0";
    d[Kind.NUMBER] = "1";
    d[Kind.STRING] = "2";
    d[Kind.PLUS] = "3";
    return len(d);
}

# A string-keyed and an int-keyed table alive at once: Kind.STRING's ordinal
# (2) equals Level.LOW's value (2), so a shared key representation would let
# one table answer for the other.
def mixed_no_collision -> str {
    kd: dict[Kind, str] = {Kind.STRING: "ks", Kind.PLUS: "kp"};
    ld: dict[Level, str] = {Level.LOW: "ll", Level.HIGH: "lh"};
    return kd[Kind.STRING] + ld[Level.LOW] + kd[Kind.PLUS] + ld[Level.HIGH];
}

# The glob tables are initialized by jac_entry; the JIT tests call it before
# reading them.
with entry {
    _ready: int = len(KIND_TAB) + len(LEVEL_TAB);
}
