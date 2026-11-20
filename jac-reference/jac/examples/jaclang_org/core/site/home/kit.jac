def:pub HomeSection(id: str, children: any = None, className: str = "") -> JsxElement;

def:pub SectionHead(
    num: str, kicker: str, title: str, lede: str = "", children: any = None
) -> JsxElement;

def:pub Figure(
    label: str = "", caption: str = "", children: any = None, className: str = ""
) -> JsxElement;

def:pub CodeWindow(
    lines: list[str],
    title: str = "",
    lang: str = "jac",
    numbers: bool = False,
    hl_from: int = 0,
    hl_to: int = -1,
    className: str = ""
) -> JsxElement;

def:pub Prose(text: str) -> JsxElement;

def:pub Fact(title: str, body: str) -> JsxElement;
