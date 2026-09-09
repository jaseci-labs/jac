"""Heterogeneous container matrix: tagged jacval element storage.

Mixed-element lists and dicts lower to `List.jacval` / `Dict.<k>.jacval`;
every element is self-describing, so store/load/overwrite/clear/death all
route ownership through the element tag. The functions here exercise each
operation for read-back correctness; the churn functions build and drop
containers (or overwrite/clear slots in a long-lived one) so the test can
assert full reclamation from allocator in-use counters. The entry block
self-checks and prints OK so the same fixture drives the AOT gc-mode runs.
"""

def hl_read_str(s: &str) -> str {
    l: list = [1, s + "!", 2.5];
    return l[1];
}


def hl_read_int -> int {
    l: list = [41, "a", 2.5];
    a: int = l[0];
    return a + 1;
}


def hl_read_float -> float {
    l: list = [1, "a", 2.5];
    return l[2];
}


def hl_overwrite(s: &str) -> str {
    l: list = [7, "seed"];
    l[1] = s + "-one";
    l[1] = s + "-two";
    return l[1];
}


def hl_append_pop -> int {
    l: list = [1, "a"];
    l.append("bb" + "cc");
    x: str = l.pop();
    return len(x) + len(l);
}


def hl_iter_int_total -> int {
    l: list = [3, "x", 4.5, True, 9];
    total: int = 0;
    for v in l {
        if isinstance(v, int) {
            iv: int = v;
            total = total + iv;
        }
    }
    return total;
}


def hl_repr -> str {
    l: list = [1, "two", 3.5, True];
    return repr(l);
}


def hl_annotated(s: &str) -> str {
    l: list[int | str] = [1, s + "?"];
    v = l[1];
    out = "";
    if isinstance(v, str) {
        # Copy the bytes while `l` is still alive: the slot read is a
        # borrow, and rc-facts releases the list at its last use.
        out = v + "";
    }
    _keep = len(l);
    return out;
}


def hd_read_str -> str {
    d: dict = {"a": 1, "b": "be" + "e", "c": 2.5};
    return d["b"];
}


def hd_read_int -> int {
    d: dict = {"a": 40, "b": "x"};
    a: int = d["a"];
    return a + 2;
}


def hd_overwrite(s: &str) -> str {
    d: dict = {"k": 1, "pad": 2.5};
    d["k"] = s + "-first";
    d["k"] = s + "-second";
    return d["k"];
}


def hd_pop_len(s: &str) -> int {
    d: dict = {"a": s + "abc", "b": 5};
    x: str = d.pop("a");
    return len(x) + len(d);
}


def hd_clear_len(s: &str) -> int {
    d: dict = {"a": s + "abc", "b": 5, "c": 1.5};
    d.clear();
    return len(d);
}


def hd_repr -> str {
    d: dict = {"a": 1, "b": "two"};
    return repr(d);
}


def hl_churn(n: int) -> int {
    total: int = 0;
    i: int = 0;
    while i < n {
        m: list = [i, "v" + str(i), i * 1.5];
        cc: str = m[1];
        total = total + len(cc);
        i = i + 1;
    }
    return total;
}


def hd_churn(n: int) -> int {
    total: int = 0;
    i: int = 0;
    while i < n {
        d: dict = {"num": i, "tag": "v" + str(i)};
        cc: str = d["tag"];
        total = total + len(cc);
        i = i + 1;
    }
    return total;
}


def hl_overwrite_churn(n: int) -> int {
    l: list = [0, "seed"];
    i: int = 0;
    while i < n {
        l[1] = "ow" + str(i);
        i = i + 1;
    }
    cc: str = l[1];
    return len(cc);
}


def hd_overwrite_churn(n: int) -> int {
    d: dict = {"k": "seed", "num": 0};
    i: int = 0;
    while i < n {
        d["k"] = "ow" + str(i);
        i = i + 1;
    }
    cc: str = d["k"];
    return len(cc);
}


def hd_clear_churn(n: int) -> int {
    i: int = 0;
    hits: int = 0;
    d: dict = {"seed": 0, "pad": 1.5};
    while i < n {
        d["s" + str(i % 8)] = "val" + str(i);
        if i % 8 == 7 {
            d.clear();
            hits = hits + 1;
        }
        i = i + 1;
    }
    return hits;
}


with entry {
    assert hl_read_str("in") == "in!";
    assert hl_read_int() == 42;
    assert hl_read_float() == 2.5;
    assert hl_overwrite("ow") == "ow-two";
    assert hl_append_pop() == 6;
    assert hl_iter_int_total() == 13;
    assert hl_annotated("q") == "q?";
    assert hd_read_str() == "bee";
    assert hd_read_int() == 42;
    assert hd_overwrite("dv") == "dv-second";
    assert hd_pop_len("z") == 5;
    assert hd_clear_len("z") == 0;
    assert hl_churn(500) == hl_churn(500);
    assert hd_churn(200) > 0;
    assert hl_overwrite_churn(300) == 5;
    assert hd_overwrite_churn(300) == 5;
    assert hd_clear_churn(64) == 8;
    print("OK hetero_matrix");
}
