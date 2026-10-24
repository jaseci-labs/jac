import os;
import re;

glob WIRE_PREFIX: str = "wire:",
     WIRE_SCHEME: str = "jac://wire/",
     MAP_SCHEME: str = "jac://map/",
     DEPS_SCHEME: str = "jac://deps/",
     JAC_MIME: str = "text/x-jac",
     MAX_DECL_LINES: int = 300,
     MAX_MODULE_SOURCE: int = 120,
     MAX_BLOCK_LINES: int = 600,
     MAX_WIRES: int = 12,
     MAX_OUTLINE: int = 80;

def context_blocks(model: ProjectModel, keys: list[str]) -> list[dict[str, any]];

def context_block(model: ProjectModel, key: str) -> (dict[str, any] | None);

def symbol_context(model: ProjectModel, key: str) -> str;

def resolve_key(model: ProjectModel, query: str) -> str;

def wire_key(w: WireInfo) -> str;

def find_wire(model: ProjectModel, key: str) -> (WireInfo | None);

def module_of(model: ProjectModel, key: str) -> str;

def rel(model: ProjectModel, path: str) -> str;

def read_lines(path: str, first: int, last: int, budget: int) -> list[str];

def source_section(
    model: ProjectModel, label: str, path: str, first: int, last: int, budget: int
) -> list[str];

def wire_line(w: WireInfo, direction: str) -> str;

def tidy_sig(sig: str) -> str;

def sig_suffix(sig: str) -> str;

def names_of(w: WireInfo) -> list[str];

def carrying_wires(model: ProjectModel, nd: StNode) -> list[WireInfo];

def rule_lines(model: ProjectModel, mod_key: str) -> list[str];

def node_header(model: ProjectModel, nd: StNode) -> list[str];

def module_text(model: ProjectModel, mod: StModule) -> str;

def symbol_text(model: ProjectModel, nd: StNode) -> str;

def wire_text(model: ProjectModel, w: WireInfo) -> str;

impl context_blocks(model: ProjectModel, keys: list[str]) -> list[dict[str, any]] {
    blocks: list[dict[str, any]] = [];
    seen: set[str] = set();
    for key in keys {
        if key in seen {
            continue;
        }
        seen.add(key);
        b = context_block(model, key);
        if b is not None {
            blocks.append(b);
        }
    }
    return blocks;
}

impl context_block(model: ProjectModel, key: str) -> (dict[str, any] | None) {
    if key.startswith(MAP_PREFIX) {
        (scope, spec) = split_spec(key[len(MAP_PREFIX):]);
        only = filter_modules(model, spec);
        level = graph_level(model, scope, only);
        text = level_text(level, model);
        if only is not None {
            text = f"Only the {len(only)} module(s) in the {filter_label(spec)}.\n"
                + text;
        }
        return {
            "type": "resource",
            "resource": {
                "uri": MAP_SCHEME + key[len(MAP_PREFIX):],
                "text": text,
                "mimeType": "text/plain"
            }
        };
    }
    pair = parse_deps_key(key);
    if pair is not None {
        spec = split_spec(key)[1];
        only = filter_modules(model, spec);
        text = deps_text(model, pair[0], pair[1], only);
        if only is not None {
            text = f"Only wires inside the {filter_label(spec)}.\n" + text;
        }
        return {
            "type": "resource",
            "resource": {
                "uri": DEPS_SCHEME + key[len(DEPS_PREFIX):],
                "text": text,
                "mimeType": "text/plain"
            }
        };
    }
    if key.startswith(WIRE_PREFIX) {
        w = find_wire(model, key);
        if w is None {
            return None;
        }
        return {
            "type": "resource",
            "resource": {
                "uri": WIRE_SCHEME + key[len(WIRE_PREFIX):],
                "text": wire_text(model, w),
                "mimeType": JAC_MIME
            }
        };
    }
    text = symbol_context(model, key);
    if not text {
        return None;
    }
    return {
        "type": "resource",
        "resource": {"uri": sym_uri(key), "text": text, "mimeType": JAC_MIME}
    };
}

impl symbol_context(model: ProjectModel, key: str) -> str {
    nd = model.node_for(key);
    if nd is None {
        return "";
    }
    if isinstance(nd, StModule) {
        return module_text(model, nd);
    }
    return symbol_text(model, nd);
}

impl resolve_key(model: ProjectModel, query: str) -> str {
    q = query.strip();
    if q.startswith(WIRE_PREFIX) {
        return q if find_wire(model, q) is not None else "";
    }
    if q.startswith(MAP_PREFIX) or parse_deps_key(q) is not None {
        return q;
    }
    if model.node_for(q) is not None {
        return q;
    }
    hits = [
        h
        for h in model.search(q, limit=10)
        if h.kind not in ["impl", "package", "external"]
    ];
    return hits[0].key if hits else "";
}

impl wire_key(w: WireInfo) -> str {
    scope = f".{w.scope}" if w.scope else "";
    return f"{WIRE_PREFIX}{w.provider}->{w.consumer}{scope}";
}

impl find_wire(model: ProjectModel, key: str) -> (WireInfo | None) {
    for w in model.wires {
        if wire_key(w) == key {
            return w;
        }
    }
    body = key[len(WIRE_PREFIX):] if key.startswith(WIRE_PREFIX) else key;
    if "->" not in body {
        return None;
    }
    (prov, cons) = body.split("->", 1);
    for w in model.wires {
        if w.provider == prov and w.consumer == cons {
            return w;
        }
    }
    return None;
}

impl module_of(model: ProjectModel, key: str) -> str {
    parts = key.split(".");
    while parts {
        cand = ".".join(parts);
        if cand in model.modules {
            return cand;
        }
        parts = parts[:-1];
    }
    return "";
}

impl rel(model: ProjectModel, path: str) -> str {
    if not path {
        return "";
    }
    try {
        r = os.path.relpath(path, model.root_dir);
    } except ValueError {
        return path;
    }
    return path if r.startswith("..") else r;
}

impl read_lines(path: str, first: int, last: int, budget: int) -> list[str] {
    if not path or first <= 0 {
        return [];
    }
    try {
        with open(path, encoding="utf-8", errors="replace") as f {
            lines = f.read().splitlines();
        }
    } except OSError {
        return [];
    }
    last = len(lines) if last <= 0 else max(last, first);
    chunk = lines[first - 1:last];
    if len(chunk) > budget {
        hidden = len(chunk) - budget;
        chunk = chunk[:budget] + [f"... ({hidden} more lines)"];
    }
    return chunk;
}

impl source_section(
    model: ProjectModel, label: str, path: str, first: int, last: int, budget: int
) -> list[str] {
    body = read_lines(path, first, last, budget);
    if not body {
        return [];
    }
    if last <= 0 {
        last = first + len(body) - 1;
    }
    span = f"{first}-{last}" if last > first else str(first);
    return ["", f"## {label} ({rel(model, path)}:{span})", "```jac", *body, "```"];
}

impl names_of(w: WireInfo) -> list[str] {
    return [n.split(" as ")[0].strip() for n in w.names];
}

impl wire_line(w: WireInfo, direction: str) -> str {
    names = ", ".join(w.names) if w.names else "(whole module)";
    scope = f" (into {w.scope})" if w.scope else "";
    form = "" if w.form == "import from" else f" [{w.form}]";
    other = w.provider if direction == "from" else w.consumer;
    return f"  {direction} {other}{scope}{form}: {{ {names} }}";
}

impl carrying_wires(model: ProjectModel, nd: StNode) -> list[WireInfo] {
    mod_key = module_of(model, nd.key);
    if not mod_key {
        return [];
    }
    rest = nd.key[len(mod_key) + 1:];
    top = rest.split(".")[0] if rest else "";
    return [
        w
        for w in model.consumers(mod_key)
        if not w.names or top in names_of(w)
    ];
}

impl rule_lines(model: ProjectModel, mod_key: str) -> list[str] {
    out: list[str] = [];
    for r in model.rules_for(mod_key) {
        tgt = " | ".join(r.targets) if r.targets else "(nothing)";
        src = " | ".join(r.sources);
        names = f" {{ {', '.join(r.names)} }}" if r.names else "";
        out.append(f"  {r.name}: {src} --> {tgt}{names}");
    }
    return out;
}

impl node_header(model: ProjectModel, nd: StNode) -> list[str] {
    span = f"{nd.line}-{nd.end_line}" if nd.end_line > nd.line else str(nd.line);
    where = rel(model, nd.file);
    if nd.line > 0 {
        where = f"{where}:{span}";
    }
    lines = [f"# {nd.kind} {nd.key}", f"file: {where}"];
    if isinstance(nd, StAbility) and nd.signature {
        owner = f" (method of {nd.owner})" if nd.owner else "";
        sig = tidy_sig(nd.signature);
        sep = " " if sig.startswith(("->", "with")) else "";
        lines.append(f"signature: {nd.name}{sep}{sig}{owner}");
    } elif isinstance(nd, StField) {
        lines.append(f"type: {tidy_sig(nd.type_str) or '?'} (field of {nd.owner})");
    } elif isinstance(nd, StArchetype) {
        if nd.bases {
            lines.append("bases: " + ", ".join(nd.bases));
        }
        if nd.kind == "walker" {
            trav = [t.key for t in model.traversals(nd.key)];
            if trav {
                lines.append("visits: " + ", ".join(trav));
            }
        } elif nd.kind in ["node", "edge"] {
            ws = [w.key for w in model.walkers_of(nd.key)];
            if ws {
                lines.append("visited by: " + ", ".join(ws));
            }
        }
    }
    if nd.doc {
        lines.append("doc: " + " ".join(nd.doc.split())[:400]);
    }
    return lines;
}

impl module_text(model: ProjectModel, mod: StModule) -> str {
    lines = node_header(model, mod);
    if mod.kind == "external" {
        lines.append("external provider (not part of this project)");
    }
    provs = model.providers(mod.key);
    cons = model.consumers(mod.key);
    if provs {
        lines.append(f"feeds this module ({len(provs)} wires):");
        lines.extend([wire_line(w, "from") for w in provs[:MAX_WIRES]]);
        if len(provs) > MAX_WIRES {
            lines.append(f"  ... {len(provs) - MAX_WIRES} more");
        }
    }
    if cons {
        lines.append(f"consumed by ({len(cons)} wires):");
        lines.extend([wire_line(w, "to") for w in cons[:MAX_WIRES]]);
        if len(cons) > MAX_WIRES {
            lines.append(f"  ... {len(cons) - MAX_WIRES} more");
        }
    }
    rules = rule_lines(model, mod.key);
    if rules {
        lines.append("governed by:");
        lines.extend(rules);
    }
    kids = model.children(mod.key);
    if kids {
        lines.append("");
        lines.append("## outline");
        for k in kids[:MAX_OUTLINE] {
            sig = tidy_sig(getattr(k, "signature", "") or getattr(k, "type_str", ""));
            impl_at = "";
            ifile = str(getattr(k, "impl_file", "") or "");
            if ifile {
                impl_at = f"  (impl {rel(model, ifile)}:{getattr(k, 'impl_line', 0)})";
            }
            lines.append(f"  {k.kind} {k.name}{sig_suffix(sig)}  :{k.line}{impl_at}");
        }
        if len(kids) > MAX_OUTLINE {
            lines.append(f"  ... {len(kids) - MAX_OUTLINE} more");
        }
    }
    if mod.file {
        lines.extend(
            source_section(model, "source", mod.file, 1, 0, MAX_MODULE_SOURCE)
        );
    }
    return "\n".join(lines);
}

impl symbol_text(model: ProjectModel, nd: StNode) -> str {
    lines = node_header(model, nd);
    mod_key = module_of(model, nd.key);
    carriers = carrying_wires(model, nd);
    if carriers {
        lines.append(f"carried by ({len(carriers)} wires):");
        lines.extend([wire_line(w, "to") for w in carriers[:MAX_WIRES]]);
        if len(carriers) > MAX_WIRES {
            lines.append(f"  ... {len(carriers) - MAX_WIRES} more");
        }
    }
    if mod_key {
        provs = model.providers(mod_key);
        if provs {
            names = sorted({n for w in provs for n in w.names});
            lines.append(
                f"module {mod_key} imports from: "
                    + ", ".join(sorted({w.provider for w in provs}))
            );
            if names {
                lines.append("  names in scope: " + ", ".join(names[:40]));
            }
        }
        rules = rule_lines(model, mod_key);
        if rules {
            lines.append("governed by:");
            lines.extend(rules);
        }
    }
    users = model.users_of(nd.key);
    if users {
        lines.append(
            f"used by ({len(users)}): "
                + ", ".join([u.key for u in users[:12]])
                + (" ..." if len(users) > 12 else "")
        );
    }
    uses = model.uses_of(nd.key);
    if uses {
        lines.append(
            f"uses ({len(uses)}): "
                + ", ".join([u.key for u in uses[:12]])
                + (" ..." if len(uses) > 12 else "")
        );
    }
    budget = MAX_BLOCK_LINES;
    decl = source_section(
        model, "declaration", nd.file, nd.line, nd.end_line, min(budget, MAX_DECL_LINES)
    );
    lines.extend(decl);
    budget -= len(decl);
    impl_spans: list[tuple[str, str, int, int]] = [];
    if isinstance(nd, StAbility) and nd.impl_file {
        impl_spans.append(("impl", nd.impl_file, nd.impl_line, nd.impl_end_line));
    }
    for i in model.implementations(nd.key) {
        span = ("impl", i.file, i.line, i.end_line);
        if not any(s[1] == i.file and s[2] == i.line for s in impl_spans) {
            impl_spans.append(span);
        }
    }
    if isinstance(nd, StArchetype) {
        for kid in model.children(nd.key) {
            if isinstance(kid, StAbility) and kid.impl_file {
                impl_spans.append(
                    (
                        f"impl {kid.name}",
                        kid.impl_file,
                        kid.impl_line,
                        kid.impl_end_line
                    )
                );
            }
        }
    }
    skipped: list[str] = [];
    for (label, path, first, last) in impl_spans {
        if budget <= 20 {
            skipped.append(f"{label} at {rel(model, path)}:{first}");
            continue;
        }
        sec = source_section(model, label, path, first, last, budget - 5);
        lines.extend(sec);
        budget -= len(sec);
    }
    if skipped {
        lines.append("");
        lines.append("not shown (ask for them by key): " + "; ".join(skipped));
    }
    return "\n".join(lines);
}

impl wire_text(model: ProjectModel, w: WireInfo) -> str {
    arch = rel(model, w.archwire);
    lines = [
        f"# wire {w.provider} -> {w.consumer}",
        f"declared in: {arch}:{w.line}" if w.line else f"declared in: {arch}",
        f"form: {w.form}{'' if w.injected else ' (written in the file)'}"
    ];
    if w.scope {
        lines.append(f"into scope: {w.scope}");
    }
    lines.append(
        "payload: " + (", ".join(w.names) if w.names else "(the whole module)")
    );
    rules = rule_lines(model, w.consumer) + rule_lines(model, w.provider);
    if rules {
        lines.append("rules on these modules:");
        lines.extend(sorted(set(rules)));
    }
    for n in names_of(w) {
        nd = model.node_for(f"{w.provider}.{n}");
        if nd is None {
            continue;
        }
        sig = tidy_sig(getattr(nd, "signature", "") or getattr(nd, "type_str", ""));
        lines.append(
            f"  {nd.kind} {nd.key}{sig_suffix(sig)}  ({rel(model, nd.file)}:{nd.line})"
        );
    }
    return "\n".join(lines);
}

impl tidy_sig(sig: str) -> str {
    s = " ".join(sig.split());
    s = re.sub(r"\s+([,)\]:])", r"\1", s);
    s = re.sub(r"([(\[])\s+", r"\1", s);
    s = re.sub(r"(\w)\s+([(\[])", r"\1\2", s);
    s = re.sub(r":(?=\S)", ": ", s);
    return s;
}

impl sig_suffix(sig: str) -> str {
    if not sig {
        return "";
    }
    return sig if sig.startswith("(") else " " + sig;
}
