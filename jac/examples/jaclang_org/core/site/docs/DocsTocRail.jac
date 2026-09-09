import from core.docs.graph { TocEntry }
import from core.utils { cn }

def:pub DocsTocRail(toc: list[TocEntry]) -> JsxElement {
    return
        <aside className="hidden xl:block">
            {if len(toc) > 0 {
                <div className="sticky top-20">
                    <p
                        className="mb-3 font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                    >
                        On this page
                    </p>
                    <nav className="flex flex-col gap-1.5 border-l border-border/60">
                        {for (ti, t) in enumerate(toc) {
                            <a
                                key={str(ti)}
                                href={"#" + t.anchor}
                                className={cn(
                                    "-ml-px block truncate border-l border-transparent text-[13px] text-muted-foreground transition-colors hover:border-primary hover:text-foreground",
                                    "pl-3" if t.level == 2 else "pl-6"
                                )}
                            >
                                {t.text}
                            </a>
                        }}
                    </nav>
                </div>
            }}
        </aside>;
}
