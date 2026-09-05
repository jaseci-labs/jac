import from core.utils { cn }
import from core.jac_tokenizer { Token, tokenize_lines }

def:pub TokenSpan(tk: Token) -> JsxElement {
    return
        <span className={("tok-" + tk.kind) if tk.kind != "plain" else ""}>
            {tk.text}
        </span>;
}

def:pub CodeLines(
    lines: list[str],
    lang: str = "jac",
    numbers: bool = False,
    start: int = 1,
    hl_from: int = 0,
    hl_to: int = -1
) -> JsxElement {
    line_toks = tokenize_lines(lines, lang);
    return
        <div className="code-plain font-mono text-[12px] leading-relaxed">
            {for (li, ltoks) in enumerate(line_toks) {
                <div
                    key={str(li)}
                    className={"flex min-h-[1.45em]"
                        + (
                            " bg-orange-400/[0.08]"
                                if (start + li >= hl_from and start + li <= hl_to)
                                else ""
                        )}
                >
                    {if numbers {
                        <span
                            className={"sticky left-0 w-10 shrink-0 select-none border-r border-white/5 bg-[#060607] pr-3 text-right "
                                + (
                                    "text-orange-300/70"
                                        if (
                                            start + li >= hl_from
                                            and start + li <= hl_to
                                        )
                                        else "text-white/25"
                                )}
                        >
                            {str(start + li)}
                        </span>
                    }}
                    <span className="whitespace-pre pl-3 pr-4">
                        {for (ti, tk) in enumerate(ltoks) {
                            <TokenSpan key={str(ti)} tk={tk}/>
                        }}
                    </span>
                </div>
            }}
        </div>;
}

def:pub CodeBlock(
    lines: list[str], title: str = "", className: str = ""
) -> JsxElement {
    line_toks = tokenize_lines(lines, "jac");
    return
        <div
            className={cn(
                "code-window rounded-xl overflow-hidden text-left", className
            )}
        >
            {if title != "" {
                <div
                    className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
                >
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="ml-2 font-mono text-xs text-white/45">
                        {title}
                    </span>
                    <span
                        className="ml-auto font-mono text-[10px] uppercase tracking-widest text-orange-400/80"
                    >
                        jac
                    </span>
                </div>
            }}
            <pre
                className="code-scroll code-plain pt-4 pb-4 pl-5 pr-5 text-[13px] leading-relaxed"
            >
                {for (li, ltoks) in enumerate(line_toks) {
                    <div key={str(li)} className="min-h-[1.45em] whitespace-pre">
                        {for (ti, tk) in enumerate(ltoks) {
                            <TokenSpan key={str(ti)} tk={tk}/>
                        }}
                    </div>
                }}
            </pre>
        </div>;
}
