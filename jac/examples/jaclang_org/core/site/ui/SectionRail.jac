def:pub SectionRail(items: list[dict]) -> JsxElement {
    has active: str = "",
        visible: bool = False,
        lastRef: Ref[any] = Ref(""),
        hoverRef: Ref[any] = Ref(False),
        timerRef: Ref[any] = Ref(None);

    def go(sec_id: str) {
        el: any = document.getElementById(sec_id);
        if el {
            el.scrollIntoView({"behavior": "smooth", "block": "start"});
        }
    }

    def reveal {
        if timerRef.current {
            clearTimeout(timerRef.current);
            timerRef.current = None;
        }
        visible = True;
    }

    def schedule_fade {
        if timerRef.current {
            clearTimeout(timerRef.current);
        }
        timerRef.current = setTimeout(
            lambda {
                timerRef.current = None;
                if not hoverRef.current {
                    visible = False;
                }
            },
            1800,
        );
    }

    can with entry {
        on_scroll = lambda (_e: any) {
            best = "";
            for it in items {
                el: any = document.getElementById(it["id"] as str);
                if el {
                    r: any = el.getBoundingClientRect();
                    if (r.top as float) < (window.innerHeight as float) * 0.45 {
                        best = it["id"] as str;
                    }
                }
            }
            if best != lastRef.current {
                lastRef.current = best;
                active = best;
                reveal();
                schedule_fade();
            }
        };
        window.addEventListener("scroll", on_scroll);
        on_scroll(None);
        return lambda {
            window.removeEventListener("scroll", on_scroll);
            if timerRef.current {
                clearTimeout(timerRef.current);
                timerRef.current = None;
            }
        };
    }

    return
        <nav
            onMouseEnter={lambda (_e: MouseEvent) {
                hoverRef.current = True;
                reveal();
            }}
            onMouseLeave={lambda (_e: MouseEvent) {
                hoverRef.current = False;
                schedule_fade();
            }}
            className={"fixed left-5 top-1/2 z-30 hidden -translate-y-1/2 transition-opacity duration-500 xl:block "
                + ("opacity-100" if visible else "opacity-0")}
        >
            <div
                className="flex flex-col gap-1 rounded-2xl border border-border/60 bg-card/80 p-1.5 shadow-lg backdrop-blur"
            >
                {for it in items {
                    <button
                        key={it["id"] as str}
                        onClick={lambda (_e: MouseEvent) { go(it["id"] as str); }}
                        className={"cursor-pointer rounded-xl pl-3 pr-3 pt-1.5 pb-1.5 text-left font-mono text-[11px] transition-colors "
                            + (
                                "bg-primary/10"
                                    if (it["id"] as str) == active
                                    else "text-muted-foreground hover:text-foreground"
                            )}
                    >
                        {if (it["id"] as str) == active {
                            <span className="text-gradient font-semibold">
                                {it["label"] as str}
                            </span>
                        } else {
                            <span>{it["label"] as str}</span>
                        } }
                    </button>
                }}
            </div>
        </nav>;
}
