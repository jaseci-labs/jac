enum Kind {
    MODULE = 'module',
    MOD_VAR = 'mod_var',
    VAR = 'variable',
    IMM_VAR = 'imm',
    ABILITY = 'ability',
    OBJECT_ARCH = 'object',
    NODE_ARCH = 'node',
    EDGE_ARCH = 'edge',
    WALKER_ARCH = 'walker',
    TYPE = 'type'
}

def flags(name: str) -> bool {
    return {"a": True, "b": False}.get(name, False);
}

def kind_code(name: str) -> int {
    k = {
        "node": Kind.NODE_ARCH,
        "edge": Kind.EDGE_ARCH,
        "walker": Kind.WALKER_ARCH
    }.get(
        name, Kind.TYPE
    );
    if k == Kind.NODE_ARCH {
        return 6;
    }
    if k == Kind.EDGE_ARCH {
        return 7;
    }
    if k == Kind.WALKER_ARCH {
        return 8;
    }
    if k == Kind.TYPE {
        return 11;
    }
    if k == Kind.MODULE {
        return 0;
    }
    if k == Kind.MOD_VAR {
        return 1;
    }
    return -1;
}

def ints(name: str) -> int {
    return {"six": 6, "seven": 7}.get(name, 11);
}

def probe(i: int) -> int {
    name = "node";
    if i == 1 {
        name = "edge";
    } elif i == 2 {
        name = "walker";
    } elif i == 3 {
        name = "zzz";
    }
    _f = flags("a");
    return kind_code(name) * 100
        + ints("six" if i == 0 else ("seven" if i == 1 else "zzz"));
}
