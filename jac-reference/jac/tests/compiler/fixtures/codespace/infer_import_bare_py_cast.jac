"""Cast-only use of a bare (Python) import inside client code: an `as` cast is
a directive to the checker that ES output erases, exactly like an annotation,
so the client bundle needs no binding and this must NOT fire E5084. The
server helper's value-level use of `datetime` stays legal."""

import from datetime { datetime, timedelta }

def server_side(moment: datetime) -> str {
    return str(moment + timedelta(days=1));
}

def:pub Label(text: str, raw: any) -> JsxElement {
    when = raw as datetime;
    <div>{text}{when}</div>
}
