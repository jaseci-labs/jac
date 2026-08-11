"""One union representation rule, exercised from both of its callers.

The native backend has to decide a single representation whenever several
Jac types share one slot. The rule is: members that share a lowering keep
it, an all-pointer set keeps the first member's layout, and a genuinely
mixed set (pointer against i64) boxes to a tagged jacval.

Two call sites need that decision, and they used to disagree.

`a if cond else b` (`same_rep`, `all_ptr`, `mixed_rep`, `call_arg`,
`nested`, `closure_arm`) builds a phi over the two branch values. A mixed
pair emitted a phi whose incoming values had different LLVM types (a List
pointer phi fed an i64 constant), which the IR parser rejects, so the whole
module failed to lower and the workaround was an `any`-typed local plus an
if/else assignment.

A declared multi-member union (`u_param`, `u_return`, `u_glob_int` /
`u_glob_str`) lowered to whatever its FIRST member lowered to, so the other
members were silently reinterpreted through that layout. These three pin
the parameter, return and global positions, which is where `_lower_type`
feeds function signatures and global slots.

`same_rep` and `all_ptr` pin the free half of the rule: a shared lowering
and an all-pointer pair must keep lowering exactly as they do today, with
no boxing anywhere in the function.

`probe` reads back through the boxed value so the tests check the payload
survived, not merely that the module compiled: an int arrives as itself, a
container arrives as the negation of its length.
"""

def probe(v: any) -> int {
    if isinstance(v, int) {
        return v;
    }
    return 0 - len(v);
}


def same_rep(n: int) -> int {
    x = n * 2 if n > 0 else n * 3;
    return x + 1;
}


def all_ptr(flag: int) -> int {
    v = [1, 2, 3] if flag > 0 else ["a", "b"];
    return len(v);
}


def mixed_rep(flag: int) -> int {
    v = [1, 2, 3] if flag > 0 else 7;
    return probe(v);
}


def call_arg(flag: int) -> int {
    return probe([1, 2, 3, 4] if flag > 0 else 9);
}


def nested(flag: int) -> int {
    v = [1, 2, 3] if flag > 1 else (["a", "b"] if flag > 0 else 5);
    return probe(v);
}


def make_adder(k: int) -> Callable[[int], int] {
    return lambda (x: int) -> int { x + k; };
}


def quad(x: int) -> int {
    return x * 4;
}


def closure_arm(flag: int) -> int {
    f: Callable[[int], int] = make_adder(10) if flag > 0 else quad;
    return f(5);
}


glob u_glob_int: int | str = 11,
     u_glob_str: int | str = "abcde";


def u_param(v: int | str) -> int {
    if isinstance(v, int) {
        return v;
    }
    return 0 - len(v);
}


def use_u_param(flag: int) -> int {
    return u_param(7) if flag > 0 else u_param("abcd");
}


def u_return(flag: int) -> int | str {
    if flag > 0 {
        return 5;
    }
    return "xyz";
}


def use_u_return(flag: int) -> int {
    r = u_return(flag);
    if isinstance(r, int) {
        return r;
    }
    return 0 - len(r);
}


def use_u_glob(flag: int) -> int {
    g = u_glob_str if flag > 0 else u_glob_int;
    if isinstance(g, int) {
        return g;
    }
    return 0 - len(g);
}
