def:pub Reveal(children: any = None, delay: int = 0, className: str = "") -> JsxElement {
    has el: Ref[HTMLDivElement] = Ref(),
        watching: Ref[any] = Ref(None),
        shown: bool = False;

    can with entry {
        target = el.current;
        if not target {
            shown = True;
            return;
        }
        obs: any = None;
        obs = new(
            IntersectionObserver,  # jac:ignore[E1053]
            lambda (entries: any) {
                if entries[0].isIntersecting {
                    shown = True;
                    obs.disconnect();
                }
            },
            {"threshold": 0.12},
        );
        obs.observe(target);
        watching.current = obs;
    }

    can with exit {
        if watching.current {
            watching.current.disconnect();
            watching.current = None;
        }
    }

    return <div
        ref={el}
        className={cn("reveal", "reveal-shown" if shown else "", className)}
        style={{"transitionDelay": str(delay) + "ms"}}
    >{children}</div>;
}
