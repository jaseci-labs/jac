impl HomeSection(id: str, children: any = None, className: str = "") -> JsxElement {
    return
        <section
            id={id}
            className={cn(
                "scroll-mt-16 border-t border-border/60 pt-24 pb-24 sm:pt-32 sm:pb-32",
                className
            )}
        >
            <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">{children}</div>
        </section>;
}

impl SectionHead(
    num: str, kicker: str, title: str, lede: str = "", children: any = None
) -> JsxElement {
    return
        <Reveal>
            <div className="max-w-3xl">
                <div
                    className="flex items-center gap-3 font-mono text-xs uppercase tracking-[0.2em] text-muted-foreground"
                >
                    {if num != "" {
                        <span className="text-primary">{num}</span>
                    }}
                    {if num != "" {
                        <span className="h-px w-8 bg-border"></span>
                    }}
                    <span>{kicker}</span>
                </div>
                <h2
                    className="mt-6 text-balance text-4xl font-semibold tracking-tight sm:text-5xl"
                >
                    {title}
                </h2>
                {if lede != "" {
                    <p
                        className="mt-6 max-w-2xl text-pretty text-lg leading-8 text-muted-foreground"
                    >
                        <Prose text={lede}/>
                    </p>
                }}
                {children}
            </div>
        </Reveal>;
}

impl Figure(
    label: str = "", caption: str = "", children: any = None, className: str = ""
) -> JsxElement {
    return
        <Reveal delay={100}>
            <figure className={cn("mt-14 sm:mt-16", className)}>
                <div
                    className="rounded-2xl border border-border/70 bg-card/20 p-4 sm:p-8"
                >
                    {children}
                </div>
                {if caption != "" {
                    <figcaption
                        className="mt-4 flex gap-3 text-sm leading-relaxed text-muted-foreground"
                    >
                        {if label != "" {
                            <span
                                className="shrink-0 font-mono text-xs leading-6 text-primary"
                            >
                                {label}
                            </span>
                        }}
                        <span>
                            <Prose text={caption}/>
                        </span>
                    </figcaption>
                }}
            </figure>
        </Reveal>;
}

impl CodeWindow(
    lines: list[str],
    title: str = "",
    lang: str = "jac",
    numbers: bool = False,
    hl_from: int = 0,
    hl_to: int = -1,
    className: str = ""
) -> JsxElement {
    return
        <div
            className={cn(
                "code-window overflow-hidden rounded-xl text-left", className
            )}
        >
            {if title != "" {
                <div className="code-titlebar flex items-center gap-2 px-4 py-2.5">
                    <span className="font-mono text-xs text-white/55">{title}</span>
                    <span
                        className="ml-auto font-mono text-[10px] uppercase tracking-widest text-orange-400/80"
                    >
                        {lang}
                    </span>
                </div>
            }}
            <div className="code-scroll py-4">
                <CodeLines
                    lines={lines}
                    lang={lang}
                    numbers={numbers}
                    hl_from={hl_from}
                    hl_to={hl_to}
                />
            </div>
        </div>;
}

impl Prose(text: str) -> JsxElement {
    parts = text.split("`");
    return
        <>
            {for (i, part) in enumerate(parts) {
                <span
                    key={str(i)}
                    className={"rounded bg-muted px-1 py-px font-mono text-[0.88em] text-foreground"
                        if i % 2 == 1
                        else ""}
                >
                    {part}
                </span>
            }}
        </>;
}

impl Fact(title: str, body: str) -> JsxElement {
    return
        <div className="border-t border-border pt-5">
            <h3 className="text-base font-semibold tracking-tight">{title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                <Prose text={body}/>
            </p>
        </div>;
}
