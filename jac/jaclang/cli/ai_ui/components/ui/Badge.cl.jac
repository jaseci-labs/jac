"""Badge primitive -- a small status pill, optionally with a live pulse dot."""

def:pub Badge(label: str, variant: str = "", pulse: bool = False) -> JsxElement {
    cls = "badge" if not variant else ("badge " + variant);
    dot_cls = "pulse-dot live" if pulse else "pulse-dot";
    return
        <span className={cls}>
            {<span className={dot_cls}/> if pulse else None}{label}
        </span>;
}
