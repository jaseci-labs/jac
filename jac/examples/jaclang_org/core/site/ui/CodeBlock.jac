def:pub TokenSpan(tk: Token) -> JsxElement;

def:pub CodeLines(
    lines: list[str],
    lang: str = "jac",
    numbers: bool = False,
    start: int = 1,
    hl_from: int = 0,
    hl_to: int = -1
) -> JsxElement;

def:pub CodeBlock(
    lines: list[str], title: str = "", className: str = ""
) -> JsxElement;
