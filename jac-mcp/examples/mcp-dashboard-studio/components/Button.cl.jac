"""Reusable button with variant and size props."""

def:pub Button(
    children: Any,
    onClick: Any = None,
    variant: str = "primary",
    size: str = "md",
    disabled: bool = False,
    className: str = ""
) -> JsxElement {
    base = "font-medium rounded transition";

    sz = "px-2.5 py-1 text-xs"
        if size == "sm"
        else ("px-4 py-2 text-sm" if size == "lg" else "px-3 py-1.5 text-sm");

    vr = "bg-slate-700 hover:bg-slate-600 text-white disabled:opacity-50"
        if variant == "secondary"
        else (
            "text-slate-400 hover:text-white disabled:opacity-50"
                if variant == "ghost"
                else "bg-orange-500 hover:bg-orange-600 text-white disabled:opacity-50 disabled:cursor-wait"
        );

    cls = base + " " + sz + " " + vr + " " + className;

    return
        <button onClick={onClick} disabled={disabled} className={cls}>
            {children}
        </button>;
}
