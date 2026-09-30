"""A generic base's dispatch returns what a subclass override returns."""
obj Ctx {
    has tag: str = "";
}

class Emitter[V, C] {
    def emit_add(self: Emitter, ctx: C, target: V, args: list[V]) -> (V | None) abst;
    def dispatch(
        self: Emitter, name: str, ctx: C, target: V, args: list[V]
    ) -> (V | None) {
        if name == "add" {
            return self.emit_add(ctx, target, args);
        }
        return None;
    }
}

class StrEmit(Emitter[str, Ctx]) {
    def emit_add(
        self: StrEmit, ctx: Ctx, target: str, args: list[str]
    ) -> (str | None) {
        return "(" + target + " + " + args[0] + ")";
    }
}

def render(emitters: dict[str, Emitter[str, Ctx]], kind: str, left: str) -> str {
    em = emitters.get(kind);
    if em is None {
        return "no emitter";
    }
    result = em.dispatch("add", Ctx(tag="t"), left, ["x"]);
    if result is None {
        return "none";
    }
    return result;
}

with entry {
    emitters: dict[str, Emitter[str, Ctx]] = {"str": StrEmit()};
    for _ in range(2) {
        print(render(emitters, "str", "\"task-title \""));
    }
}
