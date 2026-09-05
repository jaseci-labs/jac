import from core.source.files { source_span, SourceSpan }
import from core.site.ui.CodeBlock { CodeLines }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowUpRight01Icon }

glob CONTEXT_PAD: int = 60,
     RETURN_DELAY_MS: int = 1400;

def:pub CodeSpotlight(
    path: str,
    needle: str,
    hl_lines: int = 1,
    before: int = 3,
    after: int = 12,
    className: str = "",
    on_pop: any = None,
    compact: bool = False
) -> JsxElement {
    has span: SourceSpan | None = None,
        failed: bool = False,
        scrollRef: Ref[any] = Ref(),
        anchorTop: Ref[any] = Ref(0),
        idleTimer: Ref[any] = Ref(0),
        returning: Ref[any] = Ref(False);

    async can with entry {
        got = await source_span(
            path, needle, hl_lines, before + CONTEXT_PAD, after + CONTEXT_PAD
        );
        if got is None {
            failed = True;
        } else {
            span = got;
            failed = not got.found;
        }
    }

    def settle_to_anchor {
        el: any = scrollRef.current;
        if not el or span is None {
            return;
        }
        hl: any = el.querySelector("[class*='bg-orange-400']");
        if not hl {
            return;
        }
        sp = span as SourceSpan;
        rows = sp.hl_to - sp.hl_from + 1;
        target = (hl.offsetTop as float)
            - ((el.clientHeight as float) - (hl.offsetHeight as float) * rows) * 0.35;
        if target < 0.0 {
            target = 0.0;
        }
        anchorTop.current = target;
        el.scrollTop = target;
    }

    can with [span] entry {
        if span is not None {
            _ = setTimeout(
                lambda {
                    settle_to_anchor();
                    el: any = scrollRef.current;
                    if el {
                        el.addEventListener("scroll", on_scroll);
                    }
                },
                30
            );
        }
    }

    def on_scroll(_e: any) {
        el: any = scrollRef.current;
        if not el {
            return;
        }
        if returning.current {
            gap = (el.scrollTop as float) - (anchorTop.current as float);
            if gap < 3.0 and gap > -3.0 {
                returning.current = False;
            }
            return;
        }
        if idleTimer.current {
            clearTimeout(idleTimer.current);
        }
        idleTimer.current = setTimeout(
            lambda {
                target: any = scrollRef.current;
                if target {
                    returning.current = True;
                    target.scrollTo({"top": anchorTop.current, "behavior": "smooth"});
                    _ = setTimeout(lambda { returning.current = False; }, 900);
                }
            },
            RETURN_DELAY_MS
        );
    }

    def pop_out(_e: MouseEvent) {
        if on_pop is not None {
            on_pop(path);
        }
    }

    return
        <div
            className={"code-window flex flex-col overflow-hidden rounded-xl text-left "
                + className}
        >
            <div
                className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
            >
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="ml-2 truncate font-mono text-xs text-white/45">
                    {path}
                </span>
                {if span {
                    <span
                        className="ml-auto shrink-0 font-mono text-[10px] text-white/30"
                    >
                        {"lines "}{str(span.start)}{"-"}{str(
                            span.start + len(span.raw_lines) - 1
                        )}{" of "}{str(span.total_lines)}
                    </span>
                }}
                <span
                    className="ml-3 flex shrink-0 items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest text-emerald-400"
                >
                    <span
                        className="size-1.5 animate-pulse rounded-full bg-emerald-400"
                    ></span>
                    live source
                </span>
                {if on_pop is not None {
                    <button
                        onClick={pop_out}
                        title="Pop out into the file explorer"
                        className="ml-2 flex size-6 shrink-0 cursor-pointer items-center justify-center rounded-md border border-white/10 text-white/45 transition-colors hover:border-primary/50 hover:text-white"
                    >
                        <HugeiconsIcon
                            icon={ArrowUpRight01Icon}
                            strokeWidth={2}
                            className="size-3.5"
                        />
                    </button>
                }}
            </div>
            <div
                ref={scrollRef}
                className={"code-scroll overflow-auto pt-2 pb-3 "
                    + ("h-[220px]" if compact else "h-[360px]")}
            >
                {if failed {
                    <p className="pl-4 pt-3 pb-3 font-mono text-xs text-red-400">
                        {"anchor \""}{needle}{"\" not found in "}{path}
                    </p>
                } elif span {
                    <div key={path} className="anim-fade-in">
                        <CodeLines
                            lines={span.raw_lines}
                            lang={span.language}
                            numbers={True}
                            start={span.start}
                            hl_from={span.hl_from}
                            hl_to={span.hl_to}
                        />
                    </div>
                } else {
                    <p className="pl-4 pt-3 pb-3 font-mono text-xs text-white/35">
                        resolving span
                        <span className="caret ml-1"></span>
                    </p>
                }  }
            </div>
        </div>;
}
