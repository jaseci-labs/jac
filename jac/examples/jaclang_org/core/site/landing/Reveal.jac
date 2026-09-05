import from react { useEffect }
import from core.utils { cn }

def:pub Reveal(
    children: any = None, delay: int = 0, className: str = ""
) -> JsxElement {
    has el: Ref[HTMLDivElement] = Ref(),
        shown: bool = False;

    useEffect(
        lambda {
            target = el.current;
            if not target {
                shown = True;
                return lambda {};
            }
            obs: any = new(
                IntersectionObserver,  # jac:ignore[E1053]
                lambda (entries: any) { if entries[0].isIntersecting {
                    shown = True;
                    obs.disconnect();
                }},
                {"threshold": 0.12}
            );
            obs.observe(target);
            return lambda { obs.disconnect(); };
        },
        []
    );

    return
        <div
            ref={el}
            className={cn("reveal", "reveal-shown" if shown else "", className)}
            style={{"transitionDelay": str(delay) + "ms"}}
        >
            {children}
        </div>;
}
