"""`JsxPage`, `JsxLayout` and unions are components too, and lower through the
props protocol exactly as `JsxElement` does."""

def:pub PageComp(title: str) -> JsxPage {
    return <div>{title}</div>;
}

def:pub LayoutComp(title: str) -> JsxLayout {
    return <div>{title}</div>;
}

def:pub UnionComp(title: str) -> JsxElement | None {
    return <div>{title}</div>;
}

def:pub ElementComp(title: str) -> JsxElement {
    return <div>{title}</div>;
}
