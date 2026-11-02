"""Regression fixture for jaseci-labs/jac#9643.

A parameter, local or loop variable named after a builtin type keyword
(`type`, `list`, `dict`, `str`, `set`) is a binding like any other, so every
read of it must yield the bound value. Each read used to lower to the runtime's
type object (`_jac.types.type`), so `type.upper()` threw and `len(list)` read
the length of a type. The type itself must keep working where it is a type: a
call target, a classinfo, an annotation.
"""

def upper_type(type: str) -> str {
    return type.upper();
}

def count_items(list: list[str]) -> int {
    return len(list);
}

def value_of(dict: dict[str, int], key: str) -> int {
    return dict[key];
}

def exclaim(str: str) -> str {
    return str + "!";
}

def uppers(items: list[str]) -> list[str] {
    out: list[str] = [];
    for type in items {
        out.append(type.upper());
    }
    set = "done";
    out.append(set);
    return out;
}

def still_types(x: any) -> list[any] {
    return [str(x), isinstance(x, str)];
}

def:pub Card(type: str) -> JsxElement {
    return <p>{type.upper()}</p>;
}
