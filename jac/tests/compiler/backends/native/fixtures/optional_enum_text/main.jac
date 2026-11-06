"""A base-typed str renders a subclass whose fields hold an optional enum."""
import from .kinds { Shape, Param, Category }

node Other(Shape) {
    has ps: list[Param] = [];
}

def show(s: Shape) -> str {
    return str(s);
}

def chk_optional_enum_text -> int {
    text = show(Other(sides=1, ps=[Param(name="a", category=Category.Second)]));
    return 1 if text.startswith("Other(sides=1") else 0;
}

with entry {
    print(chk_optional_enum_text());
}
