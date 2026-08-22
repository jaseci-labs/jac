import sys;
import time;

obj Box {
    has v: list = [],
        w: str = "";
}

def mode_local_list(n: int) -> int {
    i = 0;
    acc = 0;
    while i < n {
        x = [i, i + 1, i + 2];
        acc += x[0];
        i += 1;
    }
    return acc;
}

def mode_field_list(n: int) -> int {
    b = Box();
    i = 0;
    while i < n {
        b.v = [i, i + 1, i + 2];
        i += 1;
    }
    return len(b.v);
}

def mode_tuple(n: int) -> int {
    stack: list[tuple[int, int]] = [];
    stack.append((0, 0));
    i = 0;
    acc = 0;
    while i < n {
        (a, p) = stack.pop();
        acc += a + p;
        stack.append((i, 1));
        i += 1;
    }
    return acc;
}

def mode_slice_concat(n: int) -> int {
    q: list = [1, 2];
    i = 0;
    acc = 0;
    while i < n {
        q = q[:1] + [i] + q[1:];
        if len(q) > 4 {
            q = q[:2];
        }
        acc += q[0];
        i += 1;
    }
    return acc;
}

def mode_obj_alloc(n: int) -> int {
    i = 0;
    acc = 0;
    while i < n {
        b = Box(w="x");
        acc += len(b.w);
        i += 1;
    }
    return acc;
}

with entry {
    mode = sys.argv[1] if len(sys.argv) > 1 else "local_list";
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 1000000;
    t0 = time.perf_counter_ns();
    r = 0;
    if mode == "local_list" {
        r = mode_local_list(n);
    } elif mode == "field_list" {
        r = mode_field_list(n);
    } elif mode == "tuple" {
        r = mode_tuple(n);
    } elif mode == "slice_concat" {
        r = mode_slice_concat(n);
    } elif mode == "dict" {
        r = mode_dict(n);
    } elif mode == "listidx" {
        r = mode_listidx(n);
    } else {
        r = mode_obj_alloc(n);
    }
    t1 = time.perf_counter_ns();
    print("probe:" + mode + ":" + str(r));
    print("ns=" + str(t1 - t0));
}

def mode_dict(n: int) -> int {
    d: dict[int, int] = {};
    i = 0;
    acc = 0;
    while i < n {
        k = i % 1024;
        d[k] = i;
        acc += d.get(k, 0);
        i += 1;
    }
    return acc;
}

def mode_listidx(n: int) -> int {
    xs: list[int] = [];
    j = 0;
    while j < 1024 {
        xs.append(j);
        j += 1;
    }
    i = 0;
    acc = 0;
    while i < n {
        k = i % 1024;
        xs[k] = i;
        acc += xs[k];
        i += 1;
    }
    return acc;
}
