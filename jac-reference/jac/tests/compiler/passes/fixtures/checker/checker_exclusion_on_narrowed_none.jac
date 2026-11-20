obj Spot {
    has x: float = 0.0;
}

obj Box {
    has goal: Spot | None = None,
        trail: list[Spot] = [];

    def plan(start: Spot) {
        self.goal = None;
        if self.goal is not None {
            self.trail = [start, self.goal];
        }
    }
}

def is_not_none_after_none(start: int) -> list[int] {
    aim: int | None = None;
    if aim is not None {
        out: list[int] = [start, aim];
        return out;
    }
    return [];
}

def else_of_is_none(start: int) -> list[int] {
    aim: int | None = None;
    if aim is None {
        return [];
    } else {
        out: list[int] = [start, aim];
        return out;
    }
}

def past_an_is_none_return(start: int) -> list[int] {
    aim: int | None = None;
    if aim is None {
        return [];
    }
    out: list[int] = [start, aim];
    return out;
}

def not_equal_none(start: int) -> list[int] {
    aim: int | None = None;
    if aim != None {
        out: list[int] = [start, aim];
        return out;
    }
    return [];
}

def none_still_possible(start: int, pick: bool) -> list[int] {
    aim: int | None = None;
    if pick {
        aim = start;
    }
    out: list[int] = [start, aim];
    return out;
}

obj Lam {}

obj Fnc {
    has prop: bool = False;
}

def needs_fnc(f: Fnc) -> int {
    return 1;
}

def impossible_arm_keeps_earlier_narrowing(scope: Lam | Fnc) -> int {
    if isinstance(scope, Lam) {
        return 0;
    }
    if isinstance(scope, Fnc) and scope.prop {
        return 2;
    }
    return needs_fnc(scope);
}

obj Top {}

obj Ctx(Top) {
    has native: bool = False;
}

obj Fun(Ctx) {}

obj Arch(Ctx) {}

def impossible_arm_in_a_loop(items: list[Top | None]) -> list[Ctx] {
    out: list[Ctx] = [];
    for top in items {
        if top is None {
            continue;
        }
        if not isinstance(top, (Fun, Arch)) {
            continue;
        }
        if isinstance(top, Ctx) and top.native {
            continue;
        }
        out.append(top);
    }
    return out;
}
