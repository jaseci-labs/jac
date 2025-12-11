# Test keyword-only parameters
def simple_kwonly( * , x: int)  -> int {
    return x;
}

def kwonly_with_defaults( * , x: int = 10 , y: str = "def")  -> str {
    return f"{x}-{y}";
}

def regular_plus_kwonly(normal: int, *, kw: str) -> str {
    return f"{normal}|{kw}";
}

def mixed_kwonly(pos: int, reg: str = "def", *, kw1: float, kw2: bool = True) -> str {
    return f"{pos}-{reg}-{kw1}-{kw2}";
}

def all_kwonly( * , a: int , b: str = "test" , c: float = 1.0)  -> str {
    return f"{a}:{b}:{c}";
}

with entry {
    print("KW_SIMPLE:", simple_kwonly(x=42));
    print("KW_DEF:", kwonly_with_defaults(), kwonly_with_defaults(x=20));
    print("REG_KW:", regular_plus_kwonly(10, kw="test"));
    print(
        "MIXED_KW:",
        mixed_kwonly(1, kw1=2.5),
        mixed_kwonly(2, "custom", kw1=3.5, kw2=False)
    );
    print("ALL_KW:", all_kwonly(a=100), all_kwonly(a=200, b="hi", c=9.9));
}
