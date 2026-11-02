obj Ex {
    has tag: str = "e";
}

obj Unary(Ex) {
    has operand: Ex = Ex();
}

obj Nm(Ex) {}

obj Trailer(Ex) {
    has right: Ex = Ex(),
        is_attr: bool = True;
}

obj KW {
    has v: int = 0;
}

def check(params: list[Ex | KW]) -> list[str] {
    out: list[str] = [];
    for param in params {
        place = param.operand if isinstance(param, Unary) else param;
        if not (
            isinstance(place, Nm)
            or (
                isinstance(place, Trailer)
                and place.is_attr
                and isinstance(place.right, Nm)
            )
        ) {
            out.append("bad");
            continue;
        }
        nm = place if isinstance(place, Nm) else place.right;
        out.append("ok:" + ("name" if isinstance(nm, Nm) else "other"));
    }
    return out;
}

with entry {
    items: list[Ex | KW] = [
        Nm(tag="n"),
        Trailer(right=Nm(tag="r")),
        Unary(operand=Nm(tag="u")),
        Trailer(right=Ex()),
        Ex()
    ];
    print(check(items));
}
