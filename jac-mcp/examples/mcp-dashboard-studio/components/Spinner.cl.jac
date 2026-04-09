"""Inline loading spinner."""
def:pub Spinner(size: str = "md") -> JsxElement {
    sz = "w-3 h-3 border"
        if size == "sm"
        else ("w-5 h-5 border-2" if size == "lg" else "w-4 h-4 border-2");

    cls = "animate-spin rounded-full border-slate-600 border-t-orange-500 inline-block " + sz;

    return
        <span className={cls}/>;
}
