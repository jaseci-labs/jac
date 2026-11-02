obj Painter {
    def paint(x: float) -> float;
    def inline_paint(x: float) -> float {
        return Math.cos(x);
    }
}

impl Painter.paint(x: float) -> float {
    return Math.sin(x);
}

def:pub view -> JsxElement {
    p = Painter();
    return <div>{p.paint(1.0)}{p.inline_paint(1.0)}</div>;
}
