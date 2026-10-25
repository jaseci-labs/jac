impl DocText(text: str) -> JsxElement {
    return
        <p className="mt-2 whitespace-pre-line text-sm text-muted-foreground">
            {text}
        </p>;
}

impl ApiSymbolCard(sym: ApiSymbol, anchor: str) -> JsxElement {
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

impl ApiDocs(modules: list[ApiModule]) -> JsxElement {
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
