"""Archetype-level generics: generic interface + specialized subclass (#7626 C7).

The primitives.jac emitter shape: an all-abstract generic base class
(`Emitter[V, C]`) whose methods mention class-level TypeVars, and a concrete
subclass that fixes the type args in its base list. Nothing used to consume
`Archetype.type_params`, so the base's TypeVar-typed signatures hit
`_lower_type` with no solution and the module demoted (E5092 "type 'Emitter'").
"""

obj Ctx {
    has scale: int;
}

obj Box {
    has val: int;
}

class Emitter[V, C] {
    def emit(self: Emitter, ctx: C, target: V) -> (V | None) abst;
    def emit_pair(self: Emitter, ctx: C, target: V, args: list[V]) -> (V | None) abst;
}

class BoxEmitter(Emitter[(Box, Ctx)]) {
    def emit(self: BoxEmitter, ctx: Ctx, target: Box) -> (Box | None) {
        return Box(val=target.val * ctx.scale);
    }

    def emit_pair(
        self: BoxEmitter, ctx: Ctx, target: Box, args: list[Box]
    ) -> (Box | None) {
        total = target.val;
        for a in args {
            total += a.val;
        }
        return Box(val=total * ctx.scale);
    }
}

def generic_classes_py -> dict {
    em = BoxEmitter();
    ctx = Ctx(scale=3);
    r1 = em.emit(ctx, Box(val=7));
    r2 = em.emit_pair(ctx, Box(val=1), [Box(val=2), Box(val=3)]);
    return {"r1": 0 if r1 is None else r1.val, "r2": 0 if r2 is None else r2.val,};
}

cl def generic_classes_cl -> dict {
    return {};
}

na {
    def generic_classes_na -> dict[str, any] {
        em = BoxEmitter();
        ctx = Ctx(scale=3);
        r1 = em.emit(ctx, Box(val=7));
        r2 = em.emit_pair(ctx, Box(val=1), [Box(val=2), Box(val=3)]);
        return {"r1": 0 if r1 is None else r1.val, "r2": 0 if r2 is None else r2.val,};
    }
}
