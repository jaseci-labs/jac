glob x: str = "glob";

def f(x: int, y: int = x) -> int {
    return y;
}

def g(a: int = later) -> int {
    return a;
}

glob later: int = 5;




def fresh(xs: list[int] = []) -> list[int] {
    xs.append(1);
    return xs;
}

def show(v: object) -> None { v; }

with entry {
    assert f(1) == 1;
    assert g() == 5;
    assert fresh() == [1];
    assert fresh() == [1];
}
