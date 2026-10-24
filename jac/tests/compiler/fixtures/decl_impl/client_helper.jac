def inline_helper(x: float) -> float {
    return Math.cos(x);
}

def helper(x: float) -> float;

def:pub view -> JsxElement {
    return <div>{inline_helper(1.0)}{helper(1.0)}</div>;
}
