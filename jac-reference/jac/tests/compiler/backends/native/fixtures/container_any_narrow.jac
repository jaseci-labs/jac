"""Consume-side isinstance narrowing of an `any` container (jac#8052).

A container that crossed the boxing boundary is canonically heterogeneous:
an any-held list stores tagged jacval slots and an any-held dict stores
string keys with jacval values, which is the layout any-subscript and
any-iteration already assume. `isinstance(x, list)` narrows the checker
type to the BARE `list`, and the bare container's default native lowering
is the unboxed i64 flavor -- so the narrowed unbox used to produce a
`List.i64`-typed pointer that then met a `list[any]` destination and died
on the cross-flavor guard (E5092, or a mismatching-types store). The
minimal shape is `peek` below: it crashes the emitter even when no caller
ever passes a list. The rest value-checks the narrowed consume against
the sv/bytecode run of this same fixture.
"""

def peek(val: any) -> int {
    if isinstance(val, list) {
        lst: list[any] = val;
        return len(lst);
    }
    return -1;
}

def narrowed_list_miss -> int {
    return peek(5);
}

def list_probe(val: any) -> int {
    if isinstance(val, list) {
        lst: list[any] = val;
        n: int = len(lst);
        first: int = lst[0];
        total: int = 0;
        for e in lst {
            if isinstance(e, int) {
                iv: int = e;
                total += iv;
            }
        }
        return n * 1000 + first * 10 + total;
    }
    return -1;
}

def narrowed_list_consume -> int {
    arr: list[any] = [];
    arr.append(7);
    arr.append("two");
    arr.append(4);
    return list_probe(arr);
}

def dict_probe(val: any) -> int {
    if isinstance(val, dict) {
        d: dict[str, any] = val;
        klen: int = 0;
        for k in d {
            klen += len(k);
        }
        return klen * 10 + len(d);
    }
    return -1;
}

def narrowed_dict_consume -> int {
    m: dict[str, any] = {};
    m["ab"] = 1;
    m["c"] = "x";
    return dict_probe(m);
}

def narrowed_dict_miss -> int {
    return dict_probe("s");
}
