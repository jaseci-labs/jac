enum Color {
    WHITE = 0,
    BLACK = 1
}

enum Kind {
    PAWN = 0,
    KNIGHT = 1,
    BISHOP = 2
}

def opposite_color(c: int) -> Color {
    if c == Color.WHITE {
        return Color.BLACK;
    }
    return Color.WHITE;
}

def sum_range(n: int) -> int {
    total: int = 0;
    for i in range(n) {
        total = total + i;
    }
    return total;
}

def first_break(n: int) -> int {
    result: int = 0;
    for i in range(n) {
        if i == 5 {
            break;
        }
        result = result + 1;
    }
    return result;
}

def skip_even(n: int) -> int {
    total: int = 0;
    for i in range(n) {
        if i % 2 == 0 {
            continue;
        }
        total = total + i;
    }
    return total;
}

def bool_and(a: int, b: int) -> int {
    if a > 0 and b > 0 {
        return 1;
    }
    return 0;
}

def bool_or(a: int, b: int) -> int {
    if a > 0 or b > 0 {
        return 1;
    }
    return 0;
}

def ternary_test(x: int) -> int {
    result: int = 10 if x > 0 else -10;
    return result;
}

# Mixed-type ternary: branches need a numeric coercion before the merge phi
# (#6987). The cast must land in the predecessor block, not ahead of the phi
# in the merge block, or the LLVM verifier rejects the module ("PHI nodes not
# grouped at top of basic block"). The two below exercise each predecessor
# side; ternary_widen_test exercises the int-width zext path.
def ternary_int_float_test(x: int) -> float {
    # float "then" + int "else": the int else-branch gets sitofp'd.
    v = 1.5 if x > 0 else 2;
    return v;
}

def ternary_float_int_test(x: int) -> float {
    # int "then" + float "else": the int then-branch gets sitofp'd.
    v = 2 if x > 0 else 1.5;
    return v;
}

def ternary_widen_test(x: int) -> int {
    # bool "then" (i1) + int "else" (i64): the narrow then-branch gets zext'd.
    v = True if x > 0 else 5;
    return v;
}

def enum_kind_test(k: int) -> int {
    if k == Kind.PAWN {
        return 100;
    } elif k == Kind.KNIGHT {
        return 200;
    } elif k == Kind.BISHOP {
        return 300;
    }
    return 0;
}
