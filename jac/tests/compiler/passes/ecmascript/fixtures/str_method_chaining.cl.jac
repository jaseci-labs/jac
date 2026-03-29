"""Test string method transpilation on local variables and chained calls."""

def:pub str_chain_demo() -> JsxElement {
    has text: str = "hi";

    temp = text.strip();
    a = temp.lower();
    b = text.strip().lower();
    c = text.upper().strip();
    d = text.strip().upper();
    e = text.upper().strip().lower();

    return <div>{a}{b}{c}{d}{e}</div>;
}
