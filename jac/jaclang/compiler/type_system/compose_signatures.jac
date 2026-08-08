enum ComposeParamKind {
    VALUE = "value",
    MODIFIER = "modifier",
    EVENT = "event",
    SLOT = "slot"
}

obj SigParam {
    has name: str = "",
        kind: ComposeParamKind = ComposeParamKind.VALUE,
        ptype: str = "",
        has_default: bool = True;
}

obj ComposeSig {
    has name: str = "",
        params: list[SigParam] = [];
}

obj ConstMember {
    has name: str = "",
        ptype: str = "";
}

def _split_top_level(s: str) -> list[str] {
    parts: list[str] = [];
    depth = 0;
    cur = "";
    for ch in s {
        if ch == '<' or ch == '(' {
            depth += 1;
            cur += ch;
        } elif ch == '>' or ch == ')' {
            depth -= 1;
            cur += ch;
        } elif ch == ',' and depth == 0 {
            parts.append(cur);
            cur = "";
        } else {
            cur += ch;
        }
    }
    if cur.strip() {
        parts.append(cur);
    }
    return parts;
}

def _classify_param(raw: str) -> (SigParam | None) {
    p = raw.strip();
    if not p {
        return None;
    }

    has_default = p.startswith("optional ");
    if has_default {
        p = p[9:].strip();
    }
    if p.startswith("vararg ") {
        p = p[7:].strip();
    }
    if " " not in p {
        return None;
    }

    split = p.rsplit(" ", 1);
    ptype = split[0].strip();
    pname = split[1].strip();
    if not pname {
        return None;
    }
    if ptype == "androidx.compose.ui.Modifier" {
        return SigParam(
            name=pname,
            kind=ComposeParamKind.MODIFIER,
            ptype=ptype,
            has_default=has_default
        );
    }
    is_lambda = "kotlin.jvm.functions.Function" in ptype;
    returns_unit = ptype.endswith("kotlin.Unit>");
    if is_lambda and returns_unit {
        if (
            pname.startswith("on")
            and len(pname) > 2
            and pname[2] == pname[2].upper()
            and pname[2] != pname[2].lower()
        ) {
            return SigParam(
                name=pname,
                kind=ComposeParamKind.EVENT,
                ptype=ptype,
                has_default=has_default
            );
        }
        return SigParam(
            name=pname, kind=ComposeParamKind.SLOT, ptype=ptype, has_default=has_default
        );
    }
    return SigParam(
        name=pname, kind=ComposeParamKind.VALUE, ptype=ptype, has_default=has_default
    );
}

def _parse_line(line: str) -> (ComposeSig | None) {
    stripped = line.strip();
    if "@androidx.compose.runtime.Composable" not in stripped {
        return None;
    }
    if " void " not in stripped {
        return None;
    }
    open_paren = stripped.find("(");
    if open_paren < 0 {
        return None;
    }
    head = stripped[:open_paren];
    name = head.rsplit(" ", 1)[-1].strip() if " " in head else head.strip();
    if not name or name[0] != name[0].upper() or name[0] == name[0].lower() {
        return None;
    }
    close_paren = stripped.rfind(")");
    if close_paren <= open_paren {
        return None;
    }
    inner = stripped[open_paren + 1:close_paren];
    params: list[SigParam] = [];
    for raw in _split_top_level(inner) {
        cp = _classify_param(raw);
        if cp is not None {
            params.append(cp);
        }
    }
    return ComposeSig(name=name, params=params);
}

def _dedup_richest(sigs: list[ComposeSig]) -> list[ComposeSig] {
    best: dict[str, ComposeSig] = {};
    for sig in sigs {
        prev = best.get(sig.name);
        if prev is None or len(sig.params) > len(prev.params) {
            best[sig.name] = sig;
        }
    }
    out: list[ComposeSig] = [];
    for key in sorted(best.keys()) {
        out.append(best[key]);
    }
    return out;
}

def parse_signature_text(text: str) -> list[ComposeSig] {
    sigs: list[ComposeSig] = [];
    for line in text.split("\n") {
        sig = _parse_line(line);
        if sig is not None {
            sigs.append(sig);
        }
    }
    return _dedup_richest(sigs);
}

def _parse_modifier_line(line: str) -> (ComposeSig | None) {
    stripped = line.strip();
    if "@androidx.compose.runtime.Composable" in stripped {
        return None;
    }
    open_paren = stripped.find("(");
    if open_paren < 0 {
        return None;
    }
    head = stripped[:open_paren];

    parts = head.rsplit(" ", 2);
    if len(parts) < 2 or parts[len(parts) - 2] != "androidx.compose.ui.Modifier" {
        return None;
    }
    name = parts[len(parts) - 1].strip();
    if not name {
        return None;
    }
    close_paren = stripped.rfind(")");
    if close_paren <= open_paren {
        return None;
    }
    inner = stripped[open_paren + 1:close_paren];
    params: list[SigParam] = [];
    for raw in _split_top_level(inner) {
        cp = _classify_param(raw);
        if cp is not None {
            params.append(cp);
        }
    }
    return ComposeSig(name=name, params=params);
}

def parse_modifier_text(text: str) -> list[ComposeSig] {
    sigs: list[ComposeSig] = [];
    for line in text.split("\n") {
        sig = _parse_modifier_line(line);
        if sig is not None {
            sigs.append(sig);
        }
    }
    return _dedup_richest(sigs);
}

def _parse_const_class_name(line: str) -> (str | None) {
    stripped = line.strip();
    if " class " not in stripped or not stripped.rstrip().endswith("{") {
        return None;
    }
    after = stripped.split(" class ", 1)[1].strip();

    name = after.split("{", 1)[0].strip();
    if " " in name {
        return None;
    }
    if name.endswith(".Companion") {
        name = name[:len(name) - len(".Companion")];
    }

    if "." in name {
        name = name.rsplit(".", 1)[-1];
    }
    return name;
}

def _parse_const_line(line: str) -> (ConstMember | None) {
    stripped = line.strip();
    if not (stripped.startswith("property ") or stripped.startswith("field ")) {
        return None;
    }
    if "(" in stripped {
        return None;
    }
    body = stripped.rstrip(";").strip();
    toks = body.split();
    if len(toks) < 2 {
        return None;
    }
    name = toks[len(toks) - 1];
    ptype = toks[len(toks) - 2];
    if not name or name == "INSTANCE" {
        return None;
    }
    return ConstMember(name=name, ptype=ptype);
}

def parse_const_text(text: str) -> dict[str, list[ConstMember]] {
    out: dict[str, list[ConstMember]] = {};
    current: str = "";
    for line in text.split("\n") {
        cls = _parse_const_class_name(line);
        if cls is not None {
            current = cls;
            if current not in out {
                out[current] = [];
            }
            continue;
        }
        if not current {
            continue;
        }
        cm = _parse_const_line(line);
        if cm is not None {
            out[current].append(cm);
        }
    }

    return {
        k: v
        for (k, v) in out.items()
        if v
    };
}

glob _WIDGET_PARAM_KINDS_CACHE:
         dict[str, dict[str, dict[str, ComposeParamKind]]] = {};

def _compose_widgets_path -> str {
    import os;
    import jaclang;
    return os.path.join(
        os.path.dirname(jaclang.__file__),
        "compiler",
        "type_system",
        "compose_widgets.txt"
    );
}

def widget_attr_param_kind(
    widget_name: str, attr_name: str
) -> (ComposeParamKind | None) {
    kinds = widget_param_kind_table().get(widget_name);
    if kinds is None {
        return None;
    }
    return kinds.get(attr_name);
}

def widget_param_kind_table -> dict[str, dict[str, ComposeParamKind]] {
    if "table" in _WIDGET_PARAM_KINDS_CACHE {
        return _WIDGET_PARAM_KINDS_CACHE["table"];
    }
    import os;
    table: dict[str, dict[str, ComposeParamKind]] = {};
    path = _compose_widgets_path();
    try {
        if os.path.exists(path) {
            with open(path, "r", encoding="utf-8", errors="replace") as f {
                text = f.read();
            }
            for sig in parse_signature_text(text) {
                table[sig.name] = {p.name: p.kind for p in sig.params};
            }
        }
    } except OSError {
        table = {};
    }
    _WIDGET_PARAM_KINDS_CACHE["table"] = table;
    return table;
}

def slot_table(sigs: list[ComposeSig]) -> dict[str, list[str]] {
    table: dict[str, list[str]] = {};
    for sig in sigs {
        slots = [
            p.name
            for p in sig.params
            if p.kind == ComposeParamKind.SLOT
        ];
        if slots {
            table[sig.name] = slots;
        }
    }
    return table;
}
