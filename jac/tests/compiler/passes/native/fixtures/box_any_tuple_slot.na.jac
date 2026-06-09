"""Boxing concrete scalars into `any` tuple slots inside a bare `list` (issue #6511).

A bare `list` erases its elements to `any`. When a list is seeded with a tuple
whose first slot is `any` (e.g. `[(seed, 0)]` with `seed: any`), the boxed
element layout is `{JacVal, i64}`. Appending or list-literal-adding a tuple built
from a concrete `int`/`float` (`(7, 0)` -> `{i64, i64}`) used to store the raw
scalar without boxing it to the `any` representation, so reading it back through
the `any` seam yielded 0/garbage. This is exactly the portable OSP kernel's work
stack shape (`stack.append((child, 0))` with `child` a raw handle).
"""

def unwrap_i(x: any) -> int { return x as int; }

def unwrap_f(x: any) -> float { return x as float; }

"""An `any`-typed seed value, so the list's first element fixes an `any` slot."""
def any_seed() -> any { return 99; }

"""OSP shape: seed a bare list with an `any`-slot tuple, then append a concrete-int tuple."""
def osp_append(seed: any) -> int {
    stack: list = [(seed, 0)];
    stack.append((7, 0));
    (a, pa) = stack.pop();
    return unwrap_i(a);
}

def osp_append_entry() -> int { return osp_append(any_seed()); }

"""Two concrete-int appends into the `any` slot, popped LIFO."""
def many_append(seed: any) -> int {
    stack: list = [(seed, 0)];
    stack.append((10, 1));
    stack.append((20, 2));
    (b, pb) = stack.pop();
    (c, pc) = stack.pop();
    return unwrap_i(b) + unwrap_i(c);
}

def many_append_entry() -> int { return many_append(any_seed()); }

"""List literal mixing an `any`-slot tuple with a concrete-int tuple."""
def lit_mix(seed: any) -> int {
    s: list = [(seed, 1), (7, 2)];
    (a, pa) = s.pop();
    return unwrap_i(a);
}

def lit_mix_entry() -> int { return lit_mix(any_seed()); }

"""A concrete `float` boxed into an `any` slot round-trips."""
def flt_append(seed: any) -> float {
    s: list = [(seed, 0)];
    s.append((3.5, 1));
    (d, pd) = s.pop();
    return unwrap_f(d);
}

def flt_append_entry() -> float { return flt_append(99.0); }

"""The already-working control: an `any` value entering the slot stays boxed."""
def via_param(seed: any) -> int {
    stack: list = [(seed, 0)];
    (a, pa) = stack.pop();
    return unwrap_i(a);
}

def via_param_entry() -> int { return via_param(7); }
