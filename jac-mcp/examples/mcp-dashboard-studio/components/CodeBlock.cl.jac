"""Monospace code block with copy-to-clipboard."""
def:pub CodeBlock(code: str, maxHeight: str = "320px") -> JsxElement {
    has copied: bool = False;

    def handleCopy {
        navigator.clipboard.writeText(code);
        copied = True;
        setTimeout(lambda { copied = False; }, 1500);
    }

    return
        <div className="relative mt-2">
            <pre
                style={{"maxHeight": maxHeight}}
                className="bg-slate-950 border border-slate-800 rounded p-3 text-xs text-slate-300 overflow-auto whitespace-pre font-mono"
            >
                {code}
            </pre>
            <button
                onClick={handleCopy}
                className="absolute top-2 right-2 px-2 py-0.5 text-xs rounded bg-slate-700 hover:bg-slate-600 text-slate-300 transition"
            >
                {("Copied!" if copied else "Copy")}
            </button>
        </div>;
}
