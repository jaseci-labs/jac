def param_text(p: ApiParam) -> str;

def call_text(name: str, params: list[ApiParam], returns: str) -> str;

def symbol_text(sym: ApiSymbol) -> str;

def member_text(m: ApiMember) -> str;

def:pub DocText(text: str) -> JsxElement;

def:pub ApiSymbolCard(sym: ApiSymbol, anchor: str) -> JsxElement;

def:pub ApiDocs(modules: list[ApiModule]) -> JsxElement;

impl param_text(p: ApiParam) -> str {
    lead = "*" if p.kind == "varargs" else ("**" if p.kind == "kwargs" else "");
    text = lead + p.name;
    if p.type and p.type != "any" {
        text = text + ": " + p.type;
    }
    if p.optional {
        text = text + " = " + (p.value or "…");
    }
    return text;
}

impl call_text(name: str, params: list[ApiParam], returns: str) -> str {
    args = ", ".join([param_text(p) for p in params]);
    text = "def " + name + "(" + args + ")";
    if returns and returns != "None" {
        text = text + " -> " + returns;
    }
    return text;
}

impl symbol_text(sym: ApiSymbol) -> str {
    if sym.kind == "function" {
        return call_text(sym.name, sym.params, sym.returns);
    }
    if sym.kind == "global" {
        return "glob " + sym.name + ": " + sym.type;
    }
    if sym.kind == "type" {
        return "type " + sym.name + " = " + sym.type;
    }
    bases = "(" + ", ".join(sym.bases) + ")" if len(sym.bases) > 0 else "";
    return sym.kind + " " + sym.name + bases;
}

impl member_text(m: ApiMember) -> str {
    if m.kind == "field" {
        text = "has " + m.name + ": " + m.type;
        if m.value {
            text = text + " = " + m.value;
        }
        return text;
    }
    if m.kind == "method" {
        return call_text(m.name, m.params, m.returns);
    }
    return m.name;
}
