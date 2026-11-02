"""Lazy-empty containers: a fresh list/dict/set is ONE header allocation.

Data buffers start NULL with cap 0 and materialize on first insert (list
grow 0 -> 8, hash rehash 0 -> 8). Every function returns a value that
distinguishes wrong results from crashes; the shapes cover each cap-0
touch point: len/iterate/contains/clear on never-filled containers,
first-insert growth, and dropping empty containers (destructor walks
NULL buffers).
"""

def empty_list_ops(n: int) -> int {
    l: list[int] = [];
    r: int = len(l);
    for x in l {
        r = r + 1000;
    }
    return r + n;
}

def list_fill_from_empty(n: int) -> int {
    l: list[int] = [];
    i: int = 0;
    while i < n {
        l.append(i);
        i = i + 1;
    }
    s: int = 0;
    i = 0;
    while i < n {
        s = s + l[i];
        i = i + 1;
    }
    return s + len(l);
}

def list_insert_into_empty -> int {
    l: list[int] = [];
    l.insert(0, 42);
    return l[0] + len(l);
}

def empty_dict_ops(k: int) -> int {
    d: dict[int, int] = {};
    r: int = len(d);
    if k in d {
        r = r + 1000;
    }
    for kk in d {
        r = r + 1000;
    }
    d.clear();
    return r;
}

def dict_fill_from_empty(n: int) -> int {
    d: dict[int, int] = {};
    i: int = 0;
    while i < n {
        d[i] = i * 2;
        i = i + 1;
    }
    s: int = 0;
    i = 0;
    while i < n {
        s = s + d[i];
        i = i + 1;
    }
    return s + len(d);
}

def str_dict_from_empty -> int {
    d: dict[str, int] = {};
    if "missing" in d {
        return -1;
    }
    d["a"] = 5;
    d["b"] = 6;
    d["a"] = 7;
    return d["a"] + d["b"] + len(d);
}

def set_ops(n: int) -> int {
    s: set[int] = {0};
    s.remove(0);
    i: int = 0;
    while i < n {
        s.add(i);
        i = i + 1;
    }
    c: int = 0;
    i = 0;
    while i < n * 2 {
        if i in s {
            c = c + 1;
        }
        i = i + 1;
    }
    return c;
}

def many_empty_dropped(n: int) -> int {
    t: int = 0;
    i: int = 0;
    while i < n {
        l: list[int] = [];
        d: dict[int, int] = {};
        if i % 10 == 0 {
            l.append(i);
            d[i] = i;
        }
        t = t + len(l) + len(d);
        i = i + 1;
    }
    return t;
}

def clear_then_refill -> int {
    d: dict[int, int] = {};
    d.clear();
    d[1] = 10;
    d.clear();
    d[2] = 20;
    return d[2] + len(d);
}

def nested_empty(n: int) -> int {
    outer: dict[int, list[int]] = {};
    i: int = 0;
    while i < n {
        inner: list[int] = [];
        if i % 2 == 0 {
            inner.append(i);
        }
        outer[i] = inner;
        i = i + 1;
    }
    s: int = 0;
    i = 0;
    while i < n {
        s = s + len(outer[i]);
        i = i + 1;
    }
    return s;
}
