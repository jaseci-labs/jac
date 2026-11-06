"""A clib `-> str` return that is a NULL `char*` reads as None.

libc `getenv` returns NULL for an unset variable. Python's ctypes `c_char_p`
gives None, and a native build must agree: `== None`, `!= None`, `is None`,
`is not None` and truthiness all see the absent value, and a set variable reads
as its text. The test sets `JAC_CSTR_NONE_SET=42` and leaves
`JAC_CSTR_NONE_UNSET` unset."""

import from "libc.so.6" { def getenv(name: str) -> str;  }

def gate_on(name: &str) -> bool {
    gv: str = getenv(name);
    if gv == None {
        return True;
    }
    return gv != "0";
}

def env_text(name: &str) -> own str {
    return getenv(name);
}

def number_or(name: &str, fallback: int) -> int {
    held: str = getenv(name);
    if held is not None {
        return int(held);
    }
    return fallback;
}

def probe(label: &str, name: &str) {
    print(label, "eq", getenv(name) == None);
    print(label, "ne", getenv(name) != None);
    print(label, "is", getenv(name) is None);
    print(label, "isnt", getenv(name) is not None);
    print(label, "lit", getenv(name) == "42");
    v: str = getenv(name);
    if v {
        print(label, "truthy");
    } else {
        print(label, "falsy");
    }
    print(label, "not", not v);
    if v is not None {
        print(label, "int", int(v) + 1);
    }
    print(label, "gate", gate_on(name));
    print(label, "ret", env_text(name) is None);
    print(label, "num", number_or(name, 7));
    w: str = getenv(name);
    scaled = int(w) * 2 if w != None else 0;
    print(label, "scaled", scaled);
}

with entry {
    probe("unset", "JAC_CSTR_NONE_UNSET");
    probe("set", "JAC_CSTR_NONE_SET");
}
