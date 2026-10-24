def:pub Field(value: str, onChange: any) -> JsxElement {
    return <span>{value}</span>;
}

def:pub Editor -> JsxElement {
    has text: str = "";
    return <Field value={text} onChange={lambda (t: str) { text = t; }} />;
}

def wave(x: float) -> float {
    return Math.cos(x);
}

obj Painter {
    has scale: float = 1.0;

    def paint(x: float) -> float {
        return Math.sin(x) * self.scale;
    }
}

def:pub view -> JsxElement {
    p = Painter();
    return <div>{wave(1.0)}{p.paint(1.0)}<Editor /></div>;
}
