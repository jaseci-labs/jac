obj Box {
    def doubled -> int;
    def tripled -> int abst;
    def quadrupled -> int;
    @overload
    def pick(k: Literal['a']) -> int;

    @overload
    def pick(k: Literal['b']) -> str;

    def pick(k: str) -> int | str {
        return 0;
    }
}

impl Box.quadrupled -> int {
    return 4;
}

edge Knows;

def free_fn(x: int) -> int;

def implemented_fn(x: int) -> int;

impl implemented_fn(x: int) -> int {
    return x;
}

obj Widget {
    has label: str = "";

    def render -> str;
}

impl Widget{
    def render -> str {
        return self.label;
    }
}
