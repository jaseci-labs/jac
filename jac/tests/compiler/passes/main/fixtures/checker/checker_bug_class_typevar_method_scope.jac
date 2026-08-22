"""A generic archetype's type parameters are in scope over its methods."""

obj Leaf {
    has num: int = 0;
}

obj Ctx[T] {
    has value: (T | None) = None;

    def body_local;
    def sig_param(v: T) -> None;
    def collect -> list[T];
    def nested_sig;
    def own_tp[U](x: U) -> U {
        holder: list[U] = [];
        holder.append(x);
        return holder[0];
    }

    def opt_tp[U](x: (U | None)) -> int {
        holder: list[U] = [];
        if x is not None {
            holder.append(x);
        }
        return len(holder);
    }
}

impl Ctx.body_local{
    vals: list[T] = [];
    print(vals);
}

impl Ctx.sig_param(v: T) -> None {
    self.value = v;
}

impl Ctx.collect -> list[T] {
    out: list[T] = [];
    if self.value is not None {
        out.append(self.value);
    }
    return out;
}

impl Ctx.nested_sig{
    def inner(x: list[T]) -> list[T] {
        spare: list[T] = [];
        return x + spare;
    }
    print(inner([]));
}

def drive -> int {
    c = Ctx[Leaf]();
    c.sig_param(Leaf(num=3));
    got = c.collect();
    c.body_local();
    c.nested_sig();
    return got[0].num + c.own_tp(1) + c.opt_tp("s");
}
