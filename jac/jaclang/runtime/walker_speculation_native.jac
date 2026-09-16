import from c { def malloc(n: int) -> int;  }
import from c { def calloc(n: int, size: int) -> int;  }
import from c { def free(p: int) -> None;  }
import from c { def memcpy(dst: int, src: int, n: int) -> int;  }
import from c { def memset(dst: int, value: i32, n: int) -> int;  }
import from c { def __jac_spec_tls_get -> int;  }
import from c { def __jac_spec_tls_set(p: int) -> None;  }
import from c { def __jac_spec_jump(p: int) -> None;  }
import from c { def __jac_spec_stack_addr -> int;  }
import from c { def __jac_spec_apply(fn: int, a: int, b: int) -> None;  }

glob SPEC_TABLE: int = 0,
     SPEC_CELLS: int = 8,
     SPEC_FIRST: int = 16,
     SPEC_LAST: int = 24,
     SPEC_ALLOCS: int = 32,
     SPEC_BYTES: int = 40,
     SPEC_STEPS: int = 48,
     SPEC_MODE: int = 56,
     SPEC_STACK: int = 64,
     SPEC_IGNORES: int = 72,
     SPEC_RETIRED: int = 80,
     SPEC_ENV: int = 96,
     SPEC_ACCESS: int = 1120,
     SPEC_ACCESS_HEAD: int = 1128,
     SPEC_UNKNOWN: int = 1136,
     SPEC_TOPOLOGY: int = 1144,
     SPEC_SIZE: int = 1152,
     SPEC_CAP: int = 65536,
     SPEC_LIMIT: int = 33554432,
     SPEC_STEP_LIMIT: int = 10000000,
     SPEC_STACK_LIMIT: int = 1048576,
     SPEC_REGISTRY: int = 0,
     SPEC_DISABLED: bool = False;

def __jac_spec_disable -> None {
    SPEC_DISABLED = True;
    return;
}

def __jac_spec_new(ignores: int) -> int {
    if SPEC_DISABLED {
        return 0;
    }
    ctx = calloc(1, SPEC_SIZE);
    if ctx != 0 {
        __mem_store_i64(ctx + SPEC_IGNORES, ignores);
    }
    return ctx;
}

def __jac_spec_abort -> None {
    ctx = __jac_spec_tls_get();
    if ctx != 0 and __mem_load_i64(ctx + SPEC_MODE) in (1, 5) {
        __mem_store_i64(ctx + SPEC_UNKNOWN, 1);
        __mem_store_i64(ctx + SPEC_MODE, 3);
        __jac_spec_jump(ctx + SPEC_ENV);
    }
    return;
}

def __jac_spec_tick -> None {
    ctx = __jac_spec_tls_get();
    if ctx != 0 {
        steps = __mem_load_i64(ctx + SPEC_STEPS) + 1;
        __mem_store_i64(ctx + SPEC_STEPS, steps);
        if steps > SPEC_STEP_LIMIT
            or __mem_load_i64(ctx + SPEC_STACK) - __jac_spec_stack_addr()
                > SPEC_STACK_LIMIT {
            __jac_spec_abort();
        }
    }
    return;
}

def __jac_spec_guard(failed: bool) -> None {
    if failed {
        __jac_spec_abort();
    }
    return;
}

def __jac_spec_charge(ctx: int, size: int) -> None {
    if size < 0 or size > SPEC_LIMIT {
        __jac_spec_abort();
    }
    total = __mem_load_i64(ctx + SPEC_BYTES) + size;
    if size < 0 or total > SPEC_LIMIT or total < 0 {
        __jac_spec_abort();
    }
    __mem_store_i64(ctx + SPEC_BYTES, total);
    return;
}

def __jac_spec_private(ctx: int, addr: int) -> bool {
    if addr >= __jac_spec_stack_addr() and addr <= __mem_load_i64(ctx + SPEC_STACK) {
        return True;
    }
    item = __mem_load_i64(ctx + SPEC_ALLOCS);
    while item != 0 {
        start = __mem_load_i64(item + 8);
        if addr >= start and addr < start + __mem_load_i64(item + 16) {
            return True;
        }
        item = __mem_load_i64(item);
    }
    return False;
}

def __jac_spec_cell(ctx: int, addr: int) -> int {
    if addr < 4096 {
        __jac_spec_abort();
    }
    table = __mem_load_i64(ctx + SPEC_TABLE);
    if table == 0 {
        table = calloc(SPEC_CAP, 40);
        if table == 0 {
            __jac_spec_abort();
        }
        __mem_store_i64(ctx + SPEC_TABLE, table);
    }
    idx = ((addr >> 3) ^ (addr * 17)) & (SPEC_CAP - 1);
    attempts = 0;
    while attempts < SPEC_CAP {
        cell = table + idx * 40;
        key = __mem_load_i64(cell);
        if key == addr {
            return cell;
        }
        if key == 0 {
            initial = int(__mem_load_i8(addr)) & 255;
            __mem_store_i64(cell, addr);
            __mem_store_i64(cell + 8, initial);
            __mem_store_i64(cell + 16, initial);
            __mem_store_i64(cell + 32, __mem_load_i64(ctx + SPEC_CELLS));
            __mem_store_i64(ctx + SPEC_CELLS, cell);
            return cell;
        }
        idx = (idx + 1) & (SPEC_CAP - 1);
        attempts += 1;
    }
    __jac_spec_abort();
    return 0;
}

def __jac_spec_read(addr: int, size: int, dst: int) -> None {
    ctx = __jac_spec_tls_get();
    if ctx == 0 or __jac_spec_private(ctx, addr) {
        memcpy(dst, addr, size);
        return;
    }
    __jac_spec_tick();
    i = 0;
    while i < size {
        cell = __jac_spec_cell(ctx, addr + i);
        flags = __mem_load_i64(cell + 24);
        if (flags & 2) == 0 {
            __mem_store_i64(cell + 24, flags | 1);
        }
        octet = __mem_load_i64(cell + 16);
        __mem_store_i8(dst + i, i8(octet if octet < 128 else octet - 256));
        i += 1;
    }
}

def __jac_spec_event(ctx: int, fn: int, a: int, b: int, size: int) -> int {
    if size < 0 or size > SPEC_LIMIT - 32 {
        __jac_spec_abort();
    }
    __jac_spec_charge(ctx, size + 32);
    item = malloc(size + 32);
    if item == 0 {
        __jac_spec_abort();
    }
    __mem_store_i64(item, fn);
    __mem_store_i64(item + 8, a);
    __mem_store_i64(item + 16, b);
    __mem_store_i64(item + 24, 0);
    tail = __mem_load_i64(ctx + SPEC_LAST);
    if tail == 0 {
        __mem_store_i64(ctx + SPEC_FIRST, item);
    } else {
        __mem_store_i64(tail + 24, item);
    }
    __mem_store_i64(ctx + SPEC_LAST, item);
    return item;
}

def __jac_spec_effect(fn: int, a: int, b: int) -> None {
    ctx = __jac_spec_tls_get();
    top = __mem_load_i64(ctx + SPEC_STACK);
    bottom = __jac_spec_stack_addr();
    if (a >= bottom and a <= top) or (b >= bottom and b <= top) {
        __jac_spec_abort();
    }
    __jac_spec_event(ctx, fn, a, b, 0);
    return;
}

def __jac_spec_write(addr: int, size: int, src: int) -> None {
    ctx = __jac_spec_tls_get();
    if ctx == 0
        or (
            addr >= __jac_spec_stack_addr() and addr <= __mem_load_i64(ctx + SPEC_STACK)
        ) {
        memcpy(addr, src, size);
        return;
    }
    __jac_spec_tick();
    item = __jac_spec_event(ctx, 0, addr, size, size);
    memcpy(item + 32, src, size);
    if __jac_spec_private(ctx, addr) {
        memcpy(addr, src, size);
        return;
    }
    i = 0;
    while i < size {
        cell = __jac_spec_cell(ctx, addr + i);
        __mem_store_i64(cell + 16, int(__mem_load_i8(src + i)) & 255);
        __mem_store_i64(cell + 24, __mem_load_i64(cell + 24) | 2);
        i += 1;
    }
}

def __jac_spec_malloc(size: int) -> int {
    ctx = __jac_spec_tls_get();
    if ctx == 0 or __mem_load_i64(ctx + SPEC_MODE) not in (1, 5) {
        return malloc(size);
    }
    if size < 0 or size > SPEC_LIMIT - 24 {
        __jac_spec_abort();
    }
    __jac_spec_charge(ctx, size + 24);
    item = malloc(24);
    if item == 0 {
        __jac_spec_abort();
    }
    ptr = malloc(size);
    __mem_store_i64(item, __mem_load_i64(ctx + SPEC_ALLOCS));
    __mem_store_i64(item + 8, ptr);
    __mem_store_i64(item + 16, size);
    __mem_store_i64(ctx + SPEC_ALLOCS, item);
    if ptr == 0 {
        __jac_spec_abort();
    }
    return ptr;
}

def __jac_spec_calloc(n: int, size: int) -> int {
    if n < 0 or size < 0 or (n != 0 and size > SPEC_LIMIT // n) {
        __jac_spec_abort();
        return 0;
    }
    ptr = __jac_spec_malloc(n * size);
    memset(ptr, i32(0), n * size);
    return ptr;
}

def __jac_spec_free(ptr: int) -> None {
    if ptr == 0 {
        return;
    }
    ctx = __jac_spec_tls_get();
    if ctx == 0 {
        free(ptr);
    } elif __mem_load_i64(ctx + SPEC_MODE) == 5 {
        return;
    } elif __mem_load_i64(ctx + SPEC_MODE) == 1 {
        __jac_spec_event(ctx, -1, ptr, 0, 0);
    } else {
        item = malloc(16);
        __mem_store_i64(item, __mem_load_i64(ctx + SPEC_RETIRED));
        __mem_store_i64(item + 8, ptr);
        __mem_store_i64(ctx + SPEC_RETIRED, item);
    }
}

def __jac_spec_copy(dst: int, src: int, size: int) -> int {
    ctx = __jac_spec_tls_get();
    __jac_spec_charge(ctx, size);
    buf = __jac_spec_malloc(size);
    if buf == 0 {
        __jac_spec_abort();
    }
    __jac_spec_read(src, size, buf);
    __jac_spec_write(dst, size, buf);
    __jac_spec_free(buf);
    return dst;
}

def __jac_spec_set(dst: int, value: i32, size: int) -> int {
    ctx = __jac_spec_tls_get();
    __jac_spec_charge(ctx, size);
    buf = __jac_spec_malloc(size);
    if buf == 0 {
        __jac_spec_abort();
    }
    memset(buf, value, size);
    __jac_spec_write(dst, size, buf);
    __jac_spec_free(buf);
    return dst;
}

def __jac_spec_byte(addr: int) -> int {
    ctx = __jac_spec_tls_get();
    if __jac_spec_private(ctx, addr) {
        return int(__mem_load_i8(addr)) & 255;
    }
    cell = __jac_spec_cell(ctx, addr);
    flags = __mem_load_i64(cell + 24);
    if (flags & 2) == 0 {
        __mem_store_i64(cell + 24, flags | 1);
    }
    return __mem_load_i64(cell + 16);
}

def __jac_spec_strlen(addr: int) -> int {
    n = 0;
    while __jac_spec_byte(addr + n) != 0 {
        n += 1;
        __jac_spec_tick();
    }
    return n;
}

def __jac_spec_compare(a: int, b: int, n: int, terminated: bool) -> i32 {
    i = 0;
    while i < n {
        av = __jac_spec_byte(a + i);
        bv = __jac_spec_byte(b + i);
        if av != bv {
            return i32(av - bv);
        }
        if terminated and av == 0 {
            return i32(0);
        }
        i += 1;
        __jac_spec_tick();
    }
    return i32(0);
}

def __jac_spec_memcmp(a: int, b: int, n: int) -> i32 {
    return __jac_spec_compare(a, b, n, False);
}

def __jac_spec_strncmp(a: int, b: int, n: int) -> i32 {
    return __jac_spec_compare(a, b, n, True);
}

def __jac_spec_strcmp(a: int, b: int) -> i32 {
    return __jac_spec_compare(a, b, SPEC_LIMIT, True);
}

def __jac_spec_ignored(target: int) -> bool {
    ctx = __jac_spec_tls_get();
    ignored = __mem_load_i64(ctx + SPEC_IGNORES);
    count = __jac_spec_word(ignored);
    data = __jac_spec_word(ignored + 16);
    i = 0;
    while i < count {
        if __jac_spec_word(data + i * 8) == target {
            return True;
        }
        i += 1;
    }
    return False;
}

def __jac_spec_word(addr: int) -> int {
    value = 0;
    i = 0;
    while i < 8 {
        octet = __jac_spec_byte(addr + i);
        if i == 7 and octet >= 128 {
            octet -= 256;
        }
        value |= octet << (i * 8);
        i += 1;
    }
    return value;
}

def __jac_spec_visit_possible(targets: int, insert: int) -> bool {
    if insert != -1 {
        __jac_spec_abort();
    }
    count = __jac_spec_word(targets);
    data = __jac_spec_word(targets + 16);
    if data >= __jac_spec_stack_addr()
        and data <= __mem_load_i64(__jac_spec_tls_get() + SPEC_STACK) {
        __jac_spec_abort();
    }
    i = 0;
    while i < count {
        if not __jac_spec_ignored(__jac_spec_word(data + i * 8)) {
            return True;
        }
        i += 1;
        __jac_spec_tick();
    }
    return False;
}

def __jac_spec_commit(ctx: int) -> bool {
    if ctx == 0 or __mem_load_i64(ctx + SPEC_MODE) != 2 {
        return False;
    }
    cell = __mem_load_i64(ctx + SPEC_CELLS);
    while cell != 0 {
        if (__mem_load_i64(cell + 24) & 1) != 0
            and (int(__mem_load_i8(__mem_load_i64(cell))) & 255)
                != __mem_load_i64(cell + 8) {
            return False;
        }
        cell = __mem_load_i64(cell + 32);
    }
    __jac_spec_tls_set(ctx);
    if __jac_spec_tls_get() != ctx {
        return False;
    }
    __mem_store_i64(ctx + SPEC_MODE, 4);
    item = __mem_load_i64(ctx + SPEC_FIRST);
    while item != 0 {
        fn = __mem_load_i64(item);
        a = __mem_load_i64(item + 8);
        b = __mem_load_i64(item + 16);
        if fn == 0 {
            memcpy(a, item + 32, b);
        } elif fn == -1 {
            __jac_spec_free(a);
        } else {
            __jac_spec_apply(fn, a, b);
        }
        item = __mem_load_i64(item + 24);
    }
    __jac_spec_tls_set(0);
    return True;
}

def __jac_spec_drop(ctx: int) -> None {
    if ctx == 0 {
        return;
    }
    committed = __mem_load_i64(ctx + SPEC_MODE) == 4;
    item = __mem_load_i64(ctx + SPEC_FIRST);
    while item != 0 {
        nxt = __mem_load_i64(item + 24);
        free(item);
        item = nxt;
    }
    item = __mem_load_i64(ctx + SPEC_ALLOCS);
    while item != 0 {
        nxt = __mem_load_i64(item);
        if not committed {
            free(__mem_load_i64(item + 8));
        }
        free(item);
        item = nxt;
    }
    item = __mem_load_i64(ctx + SPEC_RETIRED);
    while item != 0 {
        nxt = __mem_load_i64(item);
        free(__mem_load_i64(item + 8));
        free(item);
        item = nxt;
    }
    free(__mem_load_i64(ctx + SPEC_TABLE));
    free(__mem_load_i64(ctx + SPEC_ACCESS));
    free(ctx);
}

def __jac_spec_register(original: int, trial: int, inspect: int) -> None {
    item = SPEC_REGISTRY;
    while item != 0 {
        if __mem_load_i64(item + 8) == original {
            return;
        }
        item = __mem_load_i64(item);
    }
    item = malloc(32);
    __mem_store_i64(item, SPEC_REGISTRY);
    __mem_store_i64(item + 8, original);
    __mem_store_i64(item + 16, trial);
    __mem_store_i64(item + 24, inspect);
    SPEC_REGISTRY = item;
}

def __jac_spec_topology -> None {
    ctx = __jac_spec_tls_get();
    if ctx != 0 {
        __mem_store_i64(ctx + SPEC_TOPOLOGY, 1);
    }
    return;
}

def __jac_spec_has_topology(ctx: int) -> bool {
    return ctx != 0 and __mem_load_i64(ctx + SPEC_TOPOLOGY) != 0;
}

def __jac_spec_completed(ctx: int) -> bool {
    return ctx != 0 and __mem_load_i64(ctx + SPEC_MODE) == 2;
}

def __jac_inspect_unknown -> None {
    ctx = __jac_spec_tls_get();
    if ctx != 0 {
        __mem_store_i64(ctx + SPEC_UNKNOWN, 1);
    }
    return;
}

def __jac_inspect_resolve(original: int) -> int {
    item = SPEC_REGISTRY;
    while item != 0 {
        if __mem_load_i64(item + 8) == original {
            inspect = __mem_load_i64(item + 24);
            if inspect != 0 {
                return inspect;
            }
            break;
        }
        item = __mem_load_i64(item);
    }
    __jac_inspect_unknown();
    return 0;
}

def __jac_inspect_access(owner: int, flags: int) -> int {
    ctx = __jac_spec_tls_get();
    if owner < 4096 {
        __jac_spec_abort();
    }
    if __jac_spec_private(ctx, owner) {
        if (flags & 4) != 0 {
            __jac_spec_abort();
        }
        return 0;
    }
    __jac_spec_tick();
    table = __mem_load_i64(ctx + SPEC_ACCESS);
    if table == 0 {
        table = calloc(SPEC_CAP, 24);
        if table == 0 {
            __jac_spec_abort();
        }
        __mem_store_i64(ctx + SPEC_ACCESS, table);
    }
    idx = ((owner >> 3) ^ (owner * 17)) & (SPEC_CAP - 1);
    attempts = 0;
    while attempts < SPEC_CAP {
        item = table + idx * 24;
        key = __mem_load_i64(item);
        if key == 0 {
            __mem_store_i64(item, owner);
            __mem_store_i64(item + 16, __mem_load_i64(ctx + SPEC_ACCESS_HEAD));
            __mem_store_i64(ctx + SPEC_ACCESS_HEAD, item);
        }
        if key == 0 or key == owner {
            previous = __mem_load_i64(item + 8);
            __mem_store_i64(item + 8, previous | flags);
            return previous;
        }
        idx = (idx + 1) & (SPEC_CAP - 1);
        attempts += 1;
    }
    __jac_spec_abort();
    return 0;
}

def __jac_inspect_read(owner: int, addr: int, size: int, dst: int) -> None {
    ctx = __jac_spec_tls_get();
    if not __jac_spec_private(ctx, addr) {
        flags = __jac_inspect_access(owner, 1);
        if (flags & 4) != 0 {
            __jac_spec_abort();
        }
    }
    memcpy(dst, addr, size);
    return;
}

def __jac_inspect_write(owner: int, addr: int, size: int, src: int) -> None {
    ctx = __jac_spec_tls_get();
    if __jac_spec_private(ctx, addr) {
        memcpy(addr, src, size);
    } else {
        __jac_inspect_access(owner, 6);
    }
    return;
}

def __jac_inspect_copy(dst: int, src: int, size: int) -> int {
    ctx = __jac_spec_tls_get();
    if not __jac_spec_private(ctx, src) or not __jac_spec_private(ctx, dst) {
        __jac_inspect_unknown();
    }
    buf = __jac_spec_malloc(size);
    __jac_inspect_read(src, src, size, buf);
    __jac_inspect_write(dst, dst, size, buf);
    return dst;
}

def __jac_inspect_set(dst: int, value: i32, size: int) -> int {
    if not __jac_spec_private(__jac_spec_tls_get(), dst) {
        __jac_inspect_unknown();
    }
    buf = __jac_spec_malloc(size);
    memset(buf, value, size);
    __jac_inspect_write(dst, dst, size, buf);
    return dst;
}

def __jac_inspect_calloc(n: int, size: int) -> int {
    return __jac_spec_calloc(n, size);
}

def __jac_inspect_strlen(addr: int) -> int {
    if (__jac_inspect_access(addr, 1) & 4) != 0 {
        __jac_spec_abort();
    }
    return __jac_spec_strlen(addr);
}

def __jac_inspect_compare(a: int, b: int, n: int, terminated: bool) -> i32 {
    if ((__jac_inspect_access(a, 1) | __jac_inspect_access(b, 1)) & 4) != 0 {
        __jac_spec_abort();
    }
    return __jac_spec_compare(a, b, n, terminated);
}

def __jac_inspect_strcmp(a: int, b: int) -> i32 {
    return __jac_inspect_compare(a, b, SPEC_LIMIT, True);
}

def __jac_inspect_strncmp(a: int, b: int, n: int) -> i32 {
    return __jac_inspect_compare(a, b, n, True);
}

def __jac_inspect_memcmp(a: int, b: int, n: int) -> i32 {
    return __jac_inspect_compare(a, b, n, False);
}

def __jac_spec_resolve(original: int) -> int {
    item = SPEC_REGISTRY;
    while item != 0 {
        if __mem_load_i64(item + 8) == original {
            return __mem_load_i64(item + 16);
        }
        item = __mem_load_i64(item);
    }
    __jac_spec_abort();
    return 0;
}
