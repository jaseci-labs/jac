"""Status and label badges."""
def:pub Badge(label: str, variant: str = "default") -> JsxElement {
    vr = "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
        if variant == "ok"
        else (
            "bg-red-500/20 text-red-400 border border-red-500/30"
                if variant == "error"
                else (
                    "bg-amber-500/20 text-amber-400 border border-amber-500/30"
                        if variant == "warning"
                        else (
                            "bg-blue-500/20 text-blue-400 border border-blue-500/30"
                                if variant == "info"
                                else "bg-slate-700 text-slate-300"
                        )
                )
        );

    cls = "inline-block px-2 py-0.5 rounded text-xs font-medium " + vr;

    return
        <span className={cls}>{label}</span>;
}
