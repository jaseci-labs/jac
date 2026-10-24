glob BANNER = "jac · impls · ✓";

obj Foo {
    has a: int = 0;

    # bar comment
    def bar(x: int, y: str = "s") -> int {
        # inner comment
        return x + self.a;
    }

    def declared -> int;

    obj Inner {
        def deep -> int {
            return 3;
        }
    }

    static def make -> Foo {
        return Foo();
    }

    def quiet_hook(program_name: str, module_path: str, detail_text: str, flag: bool) {}
    def tiny {}

    def generic[T](x: T) -> T {
        return x;
    }
}

class Field {
    has `init: bool;

    def init(self: Field, flag: bool) {
        self.`init = flag;
    }
}

walker W {
    can visit_root with Root entry {
        visit [-->];
    }

    can with Root entry {
        disengage;
    }
}

def wide(
    alpha_parameter: int,
    beta_parameter: str,
    gamma_parameter: list[int],
    delta_parameter: int
) -> str {
    return beta_parameter;
}

def badge(label: str) -> JsxElement {
    return <span>{label}</span>;
}

def counter {
    has clicks: int = 0;
    clicks += 1;
}

def top(a: int) -> int {
    def helper(b: int) -> int {
        return b * 2;
    }
    return helper(a);
}

impl Foo.declared -> int {
    return 1;
}

with entry {
    top(1);
}
