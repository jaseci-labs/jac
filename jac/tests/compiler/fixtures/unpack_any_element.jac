glob ANY_TUPLE: tuple[any, any] = (("a", int), ("b", str)),
     ANY_LIST: list[any] = [(1, "x"), (2, "y")];

def takes_type(t: type) -> str {
    return t.__name__;
}

def loop_unpack_tuple -> str {
    out = "";
    for (nm, ty) in ANY_TUPLE {
        out += str(nm) + takes_type(ty);
    }
    return out;
}

def loop_unpack_list -> str {
    out = "";
    for (num, label) in ANY_LIST {
        out += str(num) + str(label);
    }
    return out;
}

def assign_unpack_annotated_any -> str {
    pair: any = ("a", int);
    (nm, ty) = pair;
    return str(nm) + takes_type(ty);
}

def assign_unpack_bare_generic_element -> str {
    ctx: dict[str, any] = {"slots": [("a", 0, int)]};
    (nm, off, ty) = ctx["slots"][-1];
    return str(nm) + str(off) + takes_type(ty);
}

def loop_unpack_explicit_any_iterable(cfg: any) -> str {
    out = "";
    for (name, app) in cfg.apps.items() {
        out += str(name) + str(app.kind);
    }
    widths = [len(str(k)) + len(str(v)) for (k, v) in cfg.apps.items()];
    return out + str(sum(widths));
}
