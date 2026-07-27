"""Behavioral fixture for native variadic parameters (*args / **kwargs).

The call site materializes the pack: a `*args: T` parameter slot IS a native
List of T (List.jacval for `*args: any`), a `**kwargs: T` slot IS a native
str-keyed Dict, both built at the call site, passed as one pointer, and
released after the call. The callee body needs no special lowering because
the checker already types the parameter name as list[T] / dict[str, T].

Every wrapper below returns an int so the ctypes harness reads a plain
c_int64; expected values are pinned against CPython in
test_native_varargs.jac. This absorbs the `total(*nums)` shape of the
retired guardrail fixture py_varargs_err.na.jac (#7320), minus its def:pub
caller (pub variadics stay a loud E5090).
"""

import from varargs_lib { lib_sum }

def sum_all(*nums: int) -> int {
    acc = 0;
    for n in nums {
        acc += n;
    }
    return acc;
}

def mixed(base: int, *nums: int) -> int {
    s = 0;
    for n in nums {
        s += n;
    }
    return base * 1000 + s;
}

def with_default(scale: int = 2, *nums: int) -> int {
    s = 0;
    for n in nums {
        s += n;
    }
    return scale * len(nums) + s;
}

def idx_ends(*nums: int) -> int {
    return nums[0] * 10 + nums[len(nums) - 1];
}

def join_lens(*words: str) -> int {
    total = 0;
    for w in words {
        total += len(w);
    }
    return total;
}

def any_pack(*stuff: any) -> int {
    return len(stuff);
}

def kw_get(**opts: int) -> int {
    return opts["bias"] if "bias" in opts else -1;
}

def kw_sum(**opts: int) -> int {
    total = 0;
    for k in opts {
        total += opts[k];
    }
    return total;
}

def combo(a: int, *rest: int, flag: int = 0, **extra: int) -> int {
    s = 0;
    for r in rest {
        s += r;
    }
    e = 0;
    for k in extra {
        e += extra[k];
    }
    return a * 100000 + s * 1000 + flag * 100 + e;
}

obj Acc {
    has base: int;

    def add_all(*nums: int) -> int {
        s = self.base;
        for n in nums {
            s += n;
        }
        return s;
    }
}

# --- zero-arg wrappers, one observable number per binding shape ---

# sum_all(1, 2, 3) == 6
def test_sum_all -> int {
    return sum_all(1, 2, 3);
}

# empty pack still materializes a list: len 0, no null deref -> 0
def test_sum_empty -> int {
    return sum_all();
}

# fixed param binds before the pack: 7*1000 + (1+2) == 7003
def test_mixed -> int {
    return mixed(7, 1, 2);
}

# leading positional fills the default, rest go to the pack: 3*2 + 30 == 36
def test_default_packed -> int {
    return with_default(3, 10, 20);
}

# no args: default kept, empty pack -> 2*0 + 0 == 0
def test_default_empty -> int {
    return with_default();
}

# indexing both ends of the pack: 4*10 + 7 == 47
def test_idx_ends -> int {
    return idx_ends(4, 9, 7);
}

# str pack (RC pointer elements): len("ab") + len("cde") == 5
def test_join_lens -> int {
    return join_lens("ab", "cde");
}

# heterogeneous pack boxes to jacval: 3 elements
def test_any_pack -> int {
    return any_pack(1, "ab", 3.5);
}

# kwargs get through a real str-key lookup -> 4
def test_kw_hit -> int {
    return kw_get(bias=4);
}

# kwargs contains-miss on an empty (still materialized) dict -> -1
def test_kw_miss -> int {
    return kw_get();
}

# kwargs iteration sums values: 1+2+3 == 6
def test_kw_sum -> int {
    return kw_sum(a=1, b=2, c=3);
}

# empty kwargs iteration -> 0
def test_kw_sum_empty -> int {
    return kw_sum();
}

# fixed only: 1*100000 == 100000
def test_combo_min -> int {
    return combo(1);
}

# fixed + pack: 2*100000 + 7*1000 == 207000
def test_combo_rest -> int {
    return combo(2, 3, 4);
}

# kwonly binds by name after the pack: 207000 + 5*100 == 207500
def test_combo_kwonly -> int {
    return combo(2, 3, 4, flag=5);
}

# all four slots at once: 100000 + 2000 + 300 + 9 == 102309
def test_combo_full -> int {
    return combo(1, 2, flag=3, x=4, y=5);
}

# method receives the pack after self: 100 + 6 == 106
def test_method_pack -> int {
    a = Acc(base=100);
    return a.add_all(1, 2, 3);
}

# cross-module variadic callee: 4+5+6 == 15
def test_xmod_pack -> int {
    return lib_sum(4, 5, 6);
}
