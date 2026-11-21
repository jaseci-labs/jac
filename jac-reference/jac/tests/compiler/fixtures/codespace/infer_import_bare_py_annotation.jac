"""Annotation-only use of a bare (Python) import inside client code: ES
output erases annotations, so the client bundle needs no binding and this
must NOT fire E5084. Covers param types, local annotations, and return
types (spanify is pulled client by the component's reference). The server
helper's value-level use of `datetime` stays legal."""

import from datetime { datetime, timedelta }

def server_side(moment: datetime) -> str {
    return str(moment + timedelta(days=1));
}

def spanify(days: int) -> timedelta | None {
    return None;
}

def:pub Label(text: str, when: datetime | None) -> JsxElement {
    stamp: datetime | None = None;
    span = spanify(1);
    <div>{text}</div>
}
