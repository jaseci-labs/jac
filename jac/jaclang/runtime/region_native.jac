import from c { def malloc(n: int) -> int;  }
import from c { def free(p: int) -> None;  }
import from c { def __jac_region_tls_get -> int;  }
import from c { def __jac_region_tls_set(v: int) -> None;  }
import from c { def __jac_region_died_hook(rgn: int) -> None;  }

glob HDR_ALLOC_ID_OFF: int = -32,
     HDR_TAG_OFF: int = -24,
     HDR_RC_OFF: int = -16,
     HDR_DTOR_OFF: int = -8,
     HDR_TOTAL: int = 32,
     HDR_MAGIC: int = 44061,
     HDR_MAGIC_SHIFT_BASE: int = 189240554029056,
     ARENA_MAGIC_SHIFT_BASE: int = 189244848996352,
     RC_SENTINEL: int = 9223372036854775807;

glob RGN_CHUNK: int = 0,
     RGN_OFF: int = 8,
     RGN_CAP: int = 16,
     RGN_DTL: int = 24,
     RGN_CNT: int = 32,
     RGN_PARENT: int = 40,
     RGN_KIDS: int = 48,
     RGN_MERGED: int = 56,
     RGN_SIB: int = 64,
     RGN_FLAGS: int = 72,
     RGN_RUNS: int = 80,
     RGN_FREEPG: int = 88,
     RGN_LOCK: int = 96,
     RGN_CTRL_SIZE: int = 112,
     CHUNK_PREV: int = 0,
     CHUNK_RGN: int = 8,
     CHUNK_SIZE: int = 16,
     CHUNK_HDR: int = 32,
     CHUNK_DEFAULT: int = 32768,
     DTOR_NEXT: int = 0,
     DTOR_OBJ: int = 8,
     DTOR_FN: int = 16,
     DTOR_ENTRY: int = 24,
     RUN_HDR: int = 16,
     RUN_PAGES: int = 4,
     TLS_CUR: int = 0,
     TLS_STACK: int = 8,
     TLS_DEPTH: int = 16,
     TLS_CAP: int = 24,
     TLS_BLOCK: int = 32,
     FLAG_ZOMBIE: int = 1;

def _tls_block -> int {
    blk = __jac_region_tls_get();
    if blk == 0 {
        blk = malloc(TLS_BLOCK);
        __mem_store_i64(blk + TLS_CUR, 0);
        __mem_store_i64(blk + TLS_STACK, 0);
        __mem_store_i64(blk + TLS_DEPTH, 0);
        __mem_store_i64(blk + TLS_CAP, 0);
        __jac_region_tls_set(blk);
    }
    return blk;
}

def _stack_push(blk: int, hdl: int) {
    depth = __mem_load_i64(blk + TLS_DEPTH);
    cap = __mem_load_i64(blk + TLS_CAP);
    stk = __mem_load_i64(blk + TLS_STACK);
    if depth >= cap {
        ncap = 16 if cap == 0 else cap * 2;
        nstk = malloc(ncap * 8);
        i = 0;
        while i < depth {
            __mem_store_i64(nstk + i * 8, __mem_load_i64(stk + i * 8));
            i += 1;
        }
        if stk != 0 {
            free(stk);
        }
        stk = nstk;
        __mem_store_i64(blk + TLS_STACK, stk);
        __mem_store_i64(blk + TLS_CAP, ncap);
    }
    __mem_store_i64(stk + depth * 8, hdl);
    __mem_store_i64(blk + TLS_DEPTH, depth + 1);
}

def:pub __jac_region_current -> int {
    blk = __jac_region_tls_get();
    if blk == 0 {
        return 0;
    }
    return __mem_load_i64(blk + TLS_CUR);
}

def:pub __jac_region_depth -> int {
    blk = __jac_region_tls_get();
    if blk == 0 {
        return 0;
    }
    return __mem_load_i64(blk + TLS_DEPTH);
}

def:pub __jac_region_enter(hdl: int) {
    blk = _tls_block();
    _stack_push(blk, hdl);
    __mem_store_i64(blk + TLS_CUR, hdl);
}

def:pub __jac_region_unwind(depth: int) {
    blk = _tls_block();
    if depth < 0 {
        depth = 0;
    }
    if depth > __mem_load_i64(blk + TLS_DEPTH) {
        return;
    }
    __mem_store_i64(blk + TLS_DEPTH, depth);
    if depth == 0 {
        __mem_store_i64(blk + TLS_CUR, 0);
        return;
    }
    stk = __mem_load_i64(blk + TLS_STACK);
    __mem_store_i64(blk + TLS_CUR, __mem_load_i64(stk + (depth - 1) * 8));
}

def:pub __jac_region_leave {
    blk = _tls_block();
    __jac_region_unwind(__mem_load_i64(blk + TLS_DEPTH) - 1);
}

def _lock(hdl: int) {
    spins = 0;
    while __atomic_xchg_i64(hdl + RGN_LOCK, 1) != 0 {
        spins += 1;
    }
}

def _unlock(hdl: int) {
    __atomic_xchg_i64(hdl + RGN_LOCK, 0);
}

def:pub __jac_region_new -> int {
    raw = malloc(HDR_TOTAL + RGN_CTRL_SIZE);
    hdl = raw + HDR_TOTAL;
    __mem_store_i64(hdl + HDR_ALLOC_ID_OFF, HDR_MAGIC_SHIFT_BASE);
    __mem_store_i64(hdl + HDR_TAG_OFF, 0);
    __mem_store_i64(hdl + HDR_RC_OFF, RC_SENTINEL);
    __mem_store_i64(hdl + HDR_DTOR_OFF, 0);
    i = 0;
    while i < RGN_CTRL_SIZE {
        __mem_store_i64(hdl + i, 0);
        i += 8;
    }
    return hdl;
}

def _draw_page(parent: int) -> int {
    _lock(parent);
    head = __mem_load_i64(parent + RGN_FREEPG);
    if head != 0 {
        __mem_store_i64(parent + RGN_FREEPG, __mem_load_i64(head));
        _unlock(parent);
        return head;
    }
    run = malloc(RUN_HDR + RUN_PAGES * CHUNK_DEFAULT);
    __mem_store_i64(run, __mem_load_i64(parent + RGN_RUNS));
    __mem_store_i64(parent + RGN_RUNS, run);
    pg = 1;
    while pg < RUN_PAGES {
        page = run + RUN_HDR + pg * CHUNK_DEFAULT;
        __mem_store_i64(page, __mem_load_i64(parent + RGN_FREEPG));
        __mem_store_i64(parent + RGN_FREEPG, page);
        pg += 1;
    }
    _unlock(parent);
    return run + RUN_HDR;
}

def _region_grow(hdl: int, size: int) {
    want = ((size + CHUNK_HDR + 15) // 16) * 16;
    small = want < CHUNK_DEFAULT;
    csize = CHUNK_DEFAULT if small else want;
    parent = __mem_load_i64(hdl + RGN_PARENT);
    chunk = 0;
    from_run = 0;
    if small and parent != 0 {
        chunk = _draw_page(parent);
        if chunk != 0 {
            from_run = 1;
            csize = CHUNK_DEFAULT;
        }
    }
    if chunk == 0 {
        chunk = malloc(csize);
    }
    __mem_store_i64(chunk + CHUNK_PREV, __mem_load_i64(hdl + RGN_CHUNK));
    __mem_store_i64(chunk + CHUNK_RGN, hdl + from_run);
    __mem_store_i64(chunk + CHUNK_SIZE, csize);
    __mem_store_i64(hdl + RGN_CHUNK, chunk);
    __mem_store_i64(hdl + RGN_OFF, CHUNK_HDR);
    __mem_store_i64(hdl + RGN_CAP, csize);
}

def _region_raw(hdl: int, size: int) -> int {
    size = ((size + 15) // 16) * 16;
    chunk = __mem_load_i64(hdl + RGN_CHUNK);
    off = __mem_load_i64(hdl + RGN_OFF);
    cap = __mem_load_i64(hdl + RGN_CAP);
    if chunk == 0 or off + size > cap {
        _region_grow(hdl, size);
        chunk = __mem_load_i64(hdl + RGN_CHUNK);
        off = __mem_load_i64(hdl + RGN_OFF);
    }
    __mem_store_i64(hdl + RGN_OFF, off + size);
    __mem_store_i64(hdl + RGN_CNT, __mem_load_i64(hdl + RGN_CNT) + 1);
    return chunk + off;
}

def:pub __jac_region_alloc(hdl: int, size: int) -> int {
    o = _region_raw(hdl, size + HDR_TOTAL) + HDR_TOTAL;
    __mem_store_i64(o + HDR_ALLOC_ID_OFF, ARENA_MAGIC_SHIFT_BASE);
    __mem_store_i64(o + HDR_TAG_OFF, 0);
    __mem_store_i64(o + HDR_RC_OFF, RC_SENTINEL);
    __mem_store_i64(o + HDR_DTOR_OFF, hdl);
    return o;
}

def:pub __jac_region_log_dtor(hdl: int, o: int, fn: int) {
    ent = _region_raw(hdl, DTOR_ENTRY);
    __mem_store_i64(ent + DTOR_NEXT, __mem_load_i64(hdl + RGN_DTL));
    __mem_store_i64(ent + DTOR_OBJ, o);
    __mem_store_i64(ent + DTOR_FN, fn);
    __mem_store_i64(hdl + RGN_DTL, ent);
}

def:pub __jac_region_of(o: int) -> int {
    if o == 0 {
        return 0;
    }
    aid = __mem_load_i64(o + HDR_ALLOC_ID_OFF);
    if ((aid >> 32) & 65535) != HDR_MAGIC + 1 {
        return 0;
    }
    return __mem_load_i64(o + HDR_DTOR_OFF);
}

def:pub __jac_region_partition(parent: int) -> int {
    child = __jac_region_new();
    __mem_store_i64(child + RGN_PARENT, parent);
    __mem_store_i64(parent + RGN_KIDS, __mem_load_i64(parent + RGN_KIDS) + 1);
    return child;
}

def _region_holds(hdl: int, ptr: int) -> int {
    ck = __mem_load_i64(hdl + RGN_CHUNK);
    while ck != 0 {
        if ptr >= ck + CHUNK_HDR and ptr < ck + __mem_load_i64(ck + CHUNK_SIZE) {
            return 1;
        }
        ck = __mem_load_i64(ck + CHUNK_PREV);
    }
    return 0;
}

def:pub __jac_region_owns(ptr: int) -> int {
    blk = __jac_region_tls_get();
    if blk == 0 or ptr == 0 {
        return 0;
    }
    depth = __mem_load_i64(blk + TLS_DEPTH);
    stk = __mem_load_i64(blk + TLS_STACK);
    i = depth - 1;
    while i >= 0 {
        hdl = __mem_load_i64(stk + i * 8);
        if hdl != 0 and _region_holds(hdl, ptr) != 0 {
            return 1;
        }
        i -= 1;
    }
    return 0;
}

def _list_tail(head: int, link_off: int) -> int {
    cur = head;
    while __mem_load_i64(cur + link_off) != 0 {
        cur = __mem_load_i64(cur + link_off);
    }
    return cur;
}

def _reabsorb(child: int, parent: int) {
    ch = __mem_load_i64(child + RGN_CHUNK);
    if ch != 0 {
        ph = __mem_load_i64(parent + RGN_CHUNK);
        if ph == 0 {
            __mem_store_i64(parent + RGN_CHUNK, ch);
        } else {
            tail = _list_tail(ch, CHUNK_PREV);
            __mem_store_i64(tail + CHUNK_PREV, __mem_load_i64(ph + CHUNK_PREV));
            __mem_store_i64(ph + CHUNK_PREV, ch);
        }
    }
    dl = __mem_load_i64(child + RGN_DTL);
    if dl != 0 {
        tail = _list_tail(dl, DTOR_NEXT);
        __mem_store_i64(tail + DTOR_NEXT, __mem_load_i64(parent + RGN_DTL));
        __mem_store_i64(parent + RGN_DTL, dl);
    }
    _lock(parent);
    rn = __mem_load_i64(child + RGN_RUNS);
    if rn != 0 {
        tail = _list_tail(rn, 0);
        __mem_store_i64(tail, __mem_load_i64(parent + RGN_RUNS));
        __mem_store_i64(parent + RGN_RUNS, rn);
    }
    fp = __mem_load_i64(child + RGN_FREEPG);
    if fp != 0 {
        tail = _list_tail(fp, 0);
        __mem_store_i64(tail, __mem_load_i64(parent + RGN_FREEPG));
        __mem_store_i64(parent + RGN_FREEPG, fp);
    }
    _unlock(parent);
    __mem_store_i64(
        parent + RGN_CNT,
        __mem_load_i64(parent + RGN_CNT) + __mem_load_i64(child + RGN_CNT)
    );
    cm = __mem_load_i64(child + RGN_MERGED);
    if cm != 0 {
        tail = _list_tail(cm, RGN_SIB);
        __mem_store_i64(tail + RGN_SIB, __mem_load_i64(parent + RGN_MERGED));
        __mem_store_i64(parent + RGN_MERGED, cm);
        __mem_store_i64(child + RGN_MERGED, 0);
    }
    __mem_store_i64(child + RGN_SIB, __mem_load_i64(parent + RGN_MERGED));
    __mem_store_i64(parent + RGN_MERGED, child);
    kids = __mem_load_i64(parent + RGN_KIDS) - 1;
    __mem_store_i64(parent + RGN_KIDS, kids);
    flags = __mem_load_i64(parent + RGN_FLAGS);
    if kids == 0 and (flags & FLAG_ZOMBIE) != 0 {
        __mem_store_i64(parent + RGN_FLAGS, 0);
        __jac_region_drop(parent);
    }
}

def _teardown(hdl: int) {
    __jac_region_died_hook(hdl);
    cur = __mem_load_i64(hdl + RGN_DTL);
    while cur != 0 {
        __mem_call_dtor(__mem_load_i64(cur + DTOR_FN), __mem_load_i64(cur + DTOR_OBJ));
        cur = __mem_load_i64(cur + DTOR_NEXT);
    }
    ck = __mem_load_i64(hdl + RGN_CHUNK);
    while ck != 0 {
        prev = __mem_load_i64(ck + CHUNK_PREV);
        if (__mem_load_i64(ck + CHUNK_RGN) & 1) == 0 {
            free(ck);
        }
        ck = prev;
    }
    rn = __mem_load_i64(hdl + RGN_RUNS);
    while rn != 0 {
        nx = __mem_load_i64(rn);
        free(rn);
        rn = nx;
    }
    m = __mem_load_i64(hdl + RGN_MERGED);
    while m != 0 {
        nx = __mem_load_i64(m + RGN_SIB);
        __jac_region_died_hook(m);
        free(m - HDR_TOTAL);
        m = nx;
    }
    free(hdl - HDR_TOTAL);
}

def:pub __jac_region_drop(hdl: int) {
    if hdl == 0 {
        return;
    }
    if __mem_load_i64(hdl + RGN_KIDS) > 0 {
        __mem_store_i64(hdl + RGN_FLAGS, __mem_load_i64(hdl + RGN_FLAGS) | FLAG_ZOMBIE);
        return;
    }
    parent = __mem_load_i64(hdl + RGN_PARENT);
    if parent != 0 {
        _reabsorb(hdl, parent);
        return;
    }
    _teardown(hdl);
}
