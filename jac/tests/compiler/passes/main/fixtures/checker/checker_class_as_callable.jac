"""A class object is callable via its constructor.

`type[str]` is `(object) -> str`, so passing the class itself where a
Callable parameter is expected must be accepted (pyright:
createFunctionFromConstructor). Regression for `json.dumps(default=str)`.
"""
import json;
import from typing { Any, Callable }

obj Greeter {
    has prefix: str = "hi";
}

def apply(f: Callable[[Any], Any], v: Any) -> Any {
    return f(v);
}

with entry {
    s = json.dumps({"a": 1}, default=str);
    print(s);
    k1: Callable[[Any], Any] = str;
    print(k1);
    print(apply(str, 42));
    maker: Callable[..., Greeter] = Greeter;
    print(maker());
    bad: Callable[[int], int] = str;   # Error: str(int) returns str, not int
    print(bad);
}
