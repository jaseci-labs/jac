def param_text(p: ApiParam) -> str {
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

def call_text(name: str, params: list[ApiParam], returns: str) -> str {
    args = ", ".join([param_text(p) for p in params]);
    text = "def " + name + "(" + args + ")";
    if returns and returns != "None" {
        text = text + " -> " + returns;
    }
    return text;
}

def symbol_text(sym: ApiSymbol) -> str {
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

def member_text(m: ApiMember) -> str {
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

def:pub DocText(text: str) -> JsxElement {
    return
        <p className="mt-2 whitespace-pre-line text-sm text-muted-foreground">
            {text}
        </p>;
}

def:pub ApiSymbolCard(sym: ApiSymbol, anchor: str) -> JsxElement {
    return
        <div
            id={anchor}
            className="scroll-mt-24 rounded-lg border border-border/60 p-4"
        >
            <code className="block overflow-x-auto whitespace-pre font-mono text-sm">
                {symbol_text(sym)}
            </code>
            {if sym.doc {
                <DocText text={sym.doc}/>
            }}
            {if len(sym.members) > 0 {
                <ul className="mt-3 flex flex-col gap-2 border-l border-border/60 pl-4">
                    {for m in sym.members {
                        <li key={m.name}>
                            <code
                                className="block overflow-x-auto whitespace-pre font-mono text-xs"
                            >
                                {member_text(m)}
                            </code>
                            {if m.doc {
                                <DocText text={m.doc}/>
                            }}
                        </li>
                    }}
                </ul>
            }}
        </div>;
}

def:pub ApiDocs(modules: list[ApiModule]) -> JsxElement {
    if len(modules) == 0 {
        return
            <p className="text-muted-foreground">
                This package publishes no API surface.
            </p>;
    }
    return
        <div className="flex flex-col gap-10">
            {for mod in modules {
                <section key={mod.name}>
                    <h3 className="font-mono text-lg font-semibold">{mod.name}</h3>
                    {if mod.doc {
                        <DocText text={mod.doc}/>
                    }}
                    <div className="mt-4 flex flex-col gap-3">
                        {for sym in mod.symbols {
                            <ApiSymbolCard
                                key={sym.name}
                                sym={sym}
                                anchor={mod.name + "." + sym.name}
                            />
                        }}
                    </div>
                </section>
            }}
        </div>;
}
