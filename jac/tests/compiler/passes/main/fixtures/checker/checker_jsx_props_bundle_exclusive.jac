"""A `props` bundle must be the only parameter -- E1109.

Positionally the codegen emits `const {props, tone} = props` (a SyntaxError);
keyword-only it emits a positional signature the renderer never calls that way,
so every other parameter keeps its default. Component-hood comes from
`jaclang.compiler.jsx_component`, so `JsxPage`, `JsxLayout` and unions are in
scope and `__jac` runtime helpers are not."""

def Bag(props: any) -> JsxElement {
    return <div>{props.children}</div>;
}

def Named(title: str, tone: str = "flat") -> JsxElement {
    return <div>{title}{tone}</div>;
}

def Mixed(props: any, tone: str = "flat") -> JsxElement {
    return <div>{props.children}{tone}</div>;
}

def MixedKw(props: any, *, tone: str = "flat") -> JsxElement {
    return <div>{props.children}{tone}</div>;
}

def NotAComponent(props: any, tone: str = "flat") -> str {
    return f"{props}{tone}";
}

def MixedPage(props: any, tone: str = "flat") -> JsxPage {
    return <div>{props.children}{tone}</div>;
}

def MixedLayout(props: any, tone: str = "flat") -> JsxLayout {
    return <div>{props.children}{tone}</div>;
}

def MixedUnion(props: any, tone: str = "flat") -> JsxElement | None {
    return <div>{props.children}{tone}</div>;
}

def BagPage(props: any) -> JsxPage {
    return <div>{props.children}</div>;
}

def __jacMixedHelper(props: any, tone: str = "flat") -> JsxElement {
    return <div>{props.children}{tone}</div>;
}
