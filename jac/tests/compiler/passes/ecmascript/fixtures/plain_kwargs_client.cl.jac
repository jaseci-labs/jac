"""Plain client-side kwargs calls should lower by known function signature."""

def add(a: int, b: int) -> int {
    return a + b;
}

def add3(a: int, b: int, c: int) -> int {
    return a + b + c;
}

def add_defaults(a: int = 1, b: int = 2) -> int {
    return a + b;
}

def get_kw -> dict {
    return {"a": 1, "b": 2, "c": 3};
}

obj Counter {
    def bump(amount: int, mul: int) -> int {
        return amount * mul;
    }
}

def:pub index -> JsxElement {
    has total: int = 0,
        mixed: int = 0,
        defaulted: int = 0,
        spread_total: int = 0,
        spread_call_total: int = 0,
        spread_merge_total: int = 0,
        spread_override_total: int = 0,
        method_total: int = 0;

    def call_add -> None {
        total = add(b=10, a=5);
        mixed = add(1, b=2);
        defaulted = add_defaults(b=99);
        kw: dict = {"a": 7, "b": 8};
        spread_total = add(**kw);
        kw1: dict = {"a": 1, "b": 2};
        kw2: dict = {"b": 20, "c": 30};
        spread_call_total = add3(**get_kw());
        spread_merge_total = add3(**kw1, **kw2);
        spread_override_total = add3(**kw1, **kw2, b=99);
        counter = Counter();
        method_total = counter.bump(amount=5, mul=3);
    }

    return
        <div>
            <p>{total}</p>
            <p>{mixed}</p>
            <p>{defaulted}</p>
            <p>{spread_total}</p>
            <p>{spread_call_total}</p>
            <p>{spread_merge_total}</p>
            <p>{spread_override_total}</p>
            <p>{method_total}</p>
        </div>;
}
