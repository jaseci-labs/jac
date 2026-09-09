import from core.utils { cn }
import from .SourceBrowser { SourceBrowser }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowExpand01Icon,
    ArrowShrink01Icon,
    Cancel01Icon
}

def:pub FloatingSource(
    always_float: bool = False,
    closable: bool = False,
    initial_path: str = "web/main.jac"
) -> JsxElement {
    has floating: bool = False,
        pulled: bool = False,
        expanded: bool = False,
        size_anim: bool = False,
        yielded: bool = False,
        closed: bool = False,
        anchorRef: Ref[HTMLDivElement] = Ref(),
        winRef: Ref[HTMLDivElement] = Ref(),
        offX: Ref[any] = Ref(0),
        offY: Ref[any] = Ref(0);

    can with entry {
        if always_float {
            size_anim = True;
            return;
        }
        target = anchorRef.current;
        if not target {
            return;
        }
        obs: any = new(
            IntersectionObserver,  # jac:ignore[E1053]
            lambda (entries: any) { floating = not entries[0].isIntersecting; },
            {"threshold": 0.0}
        );
        obs.observe(target);
        finale: any = document.getElementById("explorer");
        fobs: any = None;
        if finale {
            fobs = new(
                IntersectionObserver,  # jac:ignore[E1053]
                lambda (entries: any) { yielded = entries[0].isIntersecting; },
                {"threshold": 0.12}
            );
            fobs.observe(finale);
        }
        return lambda {
            obs.disconnect();
            if fobs {
                fobs.disconnect();
            }
        };
    }

    def apply_offset(nx: float, ny: float, force: bool = False) {
        el: any = winRef.current;
        if not el or (not force and not (floating or always_float or pulled)) {
            return;
        }
        cur_x = (offX.current or 0) as float;
        cur_y = (offY.current or 0) as float;
        rect: any = el.getBoundingClientRect();
        base_left = (rect.left as float) - cur_x;
        base_top = (rect.top as float) - cur_y;
        bar: any = el.querySelector(".code-titlebar");
        bar_h = (bar.offsetHeight as float) if bar else 40.0;
        gap = 8.0;
        top_guard = gap;
        nav: any = document.querySelector("header");
        if nav {
            nav_style: any = window.getComputedStyle(nav);
            nav_pos = nav_style.position;
            if nav_pos == "fixed" or nav_pos == "sticky" {
                nav_rect: any = nav.getBoundingClientRect();
                if (nav_rect.top as float) <= gap
                    and (nav_rect.bottom as float) > 0.0 {
                    top_guard = (nav_rect.bottom as float) + gap;
                }
            }
        }
        min_x = gap - base_left;
        max_x = (window.innerWidth as float) - gap - (rect.width as float) - base_left;
        min_y = top_guard - base_top;
        max_y = (window.innerHeight as float) - gap - bar_h - base_top;
        if nx > max_x {
            nx = max_x;
        }
        if nx < min_x {
            nx = min_x;
        }
        if ny > max_y {
            ny = max_y;
        }
        if ny < min_y {
            ny = min_y;
        }
        offX.current = nx;
        offY.current = ny;
        el.style.transform = "translate(" + str(nx) + "px, " + str(ny) + "px)";
    }

    can with [floating, always_float, pulled] entry {
        on_resize = lambda (_ev: any) { apply_offset(
            (offX.current or 0) as float, (offY.current or 0) as float
        ); };
        window.addEventListener("resize", on_resize);
        return lambda { window.removeEventListener("resize", on_resize); };
    }

    can with [floating, always_float, pulled] entry {
        active = floating or always_float or pulled;
        if winRef.current {
            if active {
                winRef.current.style.transform = "translate("
                    + str(offX.current)
                    + "px, "
                    + str(offY.current)
                    + "px)";
                apply_offset(
                    (offX.current or 0) as float, (offY.current or 0) as float
                );
            } else {
                winRef.current.style.transform = "";
            }
        }
        if active {
            timer = setTimeout(lambda { size_anim = True; }, 500);
            return lambda { clearTimeout(timer); };
        } else {
            size_anim = False;
        }
    }

    def start_drag(e: MouseEvent) {
        tgt: any = e.target;
        if not tgt.closest(".code-titlebar") {
            return;
        }
        if floating or always_float or pulled {
            e.preventDefault();
            sx = e.clientX;
            sy = e.clientY;
            bx = (offX.current or 0) as float;
            `by = (offY.current or 0) as float;
            move = lambda (ev: any) { apply_offset(
                bx + ((ev.clientX as float) - sx), `by + ((ev.clientY as float) - sy)
            ); };
            up = lambda (ev: any) {
                document.removeEventListener("mousemove", move);
                document.removeEventListener("mouseup", up);
            };
            document.addEventListener("mousemove", move);
            document.addEventListener("mouseup", up);
            return;
        }
        # docked: dragging the titlebar past a small threshold pulls the
        # browser out of the hero into its floating window, which then
        # follows the cursor for the rest of the gesture
        e.preventDefault();
        sx = e.clientX;
        sy = e.clientY;
        detached: any = {"on": False, "x": 0.0, "y": 0.0};
        follow = lambda {
            el: any = winRef.current;
            if not el {
                return;
            }
            rect: any = el.getBoundingClientRect();
            cur_x = (offX.current or 0) as float;
            cur_y = (offY.current or 0) as float;
            bar: any = el.querySelector(".code-titlebar");
            bar_h = (bar.offsetHeight as float) if bar else 40.0;
            apply_offset(
                (detached["x"] as float)
                    - ((rect.left as float) - cur_x)
                    - (rect.width as float) / 2.0,
                (detached["y"] as float) - ((rect.top as float) - cur_y) - bar_h / 2.0,
                True
            );
        };
        pull_move = lambda (ev: any) {
            detached["x"] = ev.clientX;
            detached["y"] = ev.clientY;
            dx = (ev.clientX as float) - sx;
            dy = (ev.clientY as float) - sy;
            if not detached["on"] and (dx * dx + dy * dy) > 144.0 {
                detached["on"] = True;
                closed = False;
                pulled = True;
                _ = setTimeout(follow, 30);
                return;
            }
            if detached["on"] {
                follow();
            }
        };
        pull_up = lambda (ev: any) {
            document.removeEventListener("mousemove", pull_move);
            document.removeEventListener("mouseup", pull_up);
        };
        document.addEventListener("mousemove", pull_move);
        document.addEventListener("mouseup", pull_up);
    }

    def reclamp_after_resize {
        # the width/height transition runs 300ms; clamp once it settles so an
        # expand near a viewport edge cannot push the titlebar off-screen
        _ = setTimeout(
            lambda { apply_offset(
                (offX.current or 0) as float, (offY.current or 0) as float
            ); },
            320
        );
    }

    def toggle_expand(_e: MouseEvent) {
        expanded = not expanded;
        reclamp_after_resize();
    }

    def maybe_toggle(e: MouseEvent) {
        tgt: any = e.target;
        if (floating or always_float) and tgt.closest(".code-titlebar") {
            expanded = not expanded;
            reclamp_after_resize();
        }
    }

    def do_close(_e: MouseEvent) {
        # closing dismisses the float in place; the panel stays docked in the
        # hero for the main site, while the always-floating docs browser has
        # no dock and simply hides
        closed = True;
        pulled = False;
        offX.current = 0;
        offY.current = 0;
        if winRef.current {
            winRef.current.style.transform = "";
        }
    }

    if closed and always_float {
        return <></>;
    }
    is_float = always_float or pulled or (floating and not closed);
    return
        <div ref={anchorRef} className="relative">
            {if is_float and not always_float {
                <div
                    className="flex h-[540px] items-center justify-center rounded-xl border border-dashed border-border/60 bg-card/10"
                >
                    <p className="font-mono text-xs text-muted-foreground/60">
                        source browser floating ↘
                    </p>
                </div>
            }}
            <div
                ref={winRef}
                onMouseDown={start_drag}
                onDoubleClick={maybe_toggle}
                className={cn(
                    "relative h-[540px] w-full [&_.code-titlebar]:cursor-move",
                    is_float
                        and cn(
                            "float-in fixed z-40 h-auto w-auto shadow-2xl [&_.code-titlebar]:cursor-move",
                            "bottom-6 right-6 max-h-[calc(100vh-6rem)] max-w-[calc(100vw-3rem)]",
                            "transition-opacity duration-500",
                            yielded
                                and "pointer-events-none opacity-0"
                                or "opacity-100",
                        )
                        or ""
                )}
            >
                <div
                    className={cn(
                        "h-full",
                        size_anim and "transition-[width,height] duration-300" or "",
                        is_float
                            and (
                                expanded
                                and "h-[620px] w-[860px]"
                                or "h-[340px] w-[470px]"
                            )
                            or "w-full"
                    )}
                >
                    <SourceBrowser className="h-full" initial_path={initial_path}/>
                </div>
                {if is_float {
                    <div className="absolute -top-3 -right-3 flex gap-2">
                        <button
                            onClick={toggle_expand}
                            title={"Shrink" if expanded else "Expand"}
                            className="flex size-8 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-muted-foreground shadow-md transition-colors hover:border-primary/50 hover:text-foreground"
                        >
                            {if expanded {
                                <HugeiconsIcon
                                    icon={ArrowShrink01Icon}
                                    strokeWidth={2}
                                    className="size-4"
                                />
                            } else {
                                <HugeiconsIcon
                                    icon={ArrowExpand01Icon}
                                    strokeWidth={2}
                                    className="size-4"
                                />
                            } }
                        </button>
                        {if closable {
                            <button
                                onClick={do_close}
                                title="Close"
                                className="flex size-8 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-muted-foreground shadow-md transition-colors hover:border-destructive/60 hover:text-foreground"
                            >
                                <HugeiconsIcon
                                    icon={Cancel01Icon}
                                    strokeWidth={2}
                                    className="size-4"
                                />
                            </button>
                        }}
                    </div>
                }}
            </div>
        </div>;
}
