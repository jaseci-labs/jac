import from c {
    obj JacRtTraceSlot {
        has trace: Callable[[ptr[u8], ptr[u8]], None];
    }  def malloc(n: int) -> int;  def free(p: int) -> None;  def realloc(
        p: int, n: int
    ) -> int;  def calloc(n: int, size: int) -> int;  def pthread_getspecific(
        key: int
    ) -> int;
}

glob HDR_ALLOC_ID_BACK: int = 32,
     HDR_TAG_BACK: int = 24,
     HDR_RC_BACK: int = 16,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32,
     HDR_MAGIC: int = 44061,
     HDR_MAGIC_SHIFT_BASE: int = 189240554029056,
     RC_SENTINEL: int = 9223372036854775807,
     RC_SENTINEL_TOP: int = 127;

glob STR_LEN_TAG_BIT: int = 1,
     STR_LEN_PAYLOAD_MASK: int = 9223372036854775807,
     STR_LEN_TAG_SHIFT: int = 1;

glob RC_COLOR_BLACK: int = 0,
     RC_COLOR_WHITE: int = 1,
     RC_COLOR_GRAY: int = 2,
     RC_COLOR_PURPLE: int = 3,
     RC_BUFFERED_BIT: int = 4,
     RC_UNTRACED_BIT: int = 8,
     RC_COLOR_SHIFT: int = 48,
     RC_CYCLE_THRESHOLD: int = 1000,
     RC_CYCLE_PACE: int = 4;

glob RC_WORD_COLOR_BITS: int = 844424930131968,
     RC_WORD_BUFFERED: int = 1125899906842624,
     RC_WORD_ROOT_BITS: int = 1970324836974592,
     RC_WORD_UNTRACED: int = 2251799813685248,
     RC_WORD_SLOT_MASK: int = 4294967295;

glob POOL_CLASS_SHIFT: int = 28,
     POOL_CLASS_MASK: int = 15,
     POOL_CLASSES: int = 6,
     POOL_CAP: int = 262144,
     POOL_MIN_TOTAL: int = 48,
     POOL_MAX_TOTAL: int = 128;

glob ROOTS_INITIAL_CAP: int = 256,
     TREG_INITIAL_CAP: int = 1024;

glob UTF8_CURSOR_MIN_BYTES: int = 64,
     UTF8_CURSOR_WAYS: int = 4,
     UTF8_CURSOR_WORDS: int = 8,
     UTF8_CURSOR_BASE: int = 0,
     UTF8_CURSOR_EPOCH: int = 3,
     UTF8_CURSOR_USED: int = 7;

def _g_gc_disabled -> int;

def _g_threaded -> int;

def _g_pool_free -> int;

def _g_pool_count -> int;

def _g_roots_buf -> int;

def _g_roots_cap -> int;

def _g_roots_count -> int;

def _g_roots_threshold -> int;

def _g_traced -> int;

def _g_collecting -> int;

def _g_release_depth -> int;

def _g_cycles_enabled -> int;

def _g_garbage_buf -> int;

def _g_garbage_cap -> int;

def _g_garbage_count -> int;

def _g_treg_keys -> int;

def _g_treg_vals -> int;

def _g_treg_cap -> int;

def _g_treg_count -> int;

def _flag_on(addr: int) -> bool;

def _threaded -> bool;

def _roots_threshold -> int;

def _magic_ok(o: int) -> bool;

def _color_bits(o: int) -> int;

def _color_store(o: int, color: int);

def _color_reset(o: int);

def _mark_untraced(o: int);

def _clear_buffered(o: int);

def _not_root(o: int) -> bool;

def _mark_root(o: int);

def _utf8_forget(o: int);

def _utf8_forget_on_free(o: int);

def _raw_free(o: int);

def _release_impl(o: int, may_cycle: bool);

def _release_fast(o: int, may_cycle: bool);

def _unbuffer(o: int);

def _push_root(o: int);

def _push_garbage(o: int);

def _treg_hash(key: int, mask: int) -> int;

def _treg_put(keys: int, vals: int, mask: int, key: int, val: int);

def _treg_slot(key: int) -> int;

def _trace_dispatch(o: int, visitor: int);

def _mark_gray(o: int);

def _mark_gray_visitor(child: int);

def _scan_black(o: int);

def _scan_black_visitor(child: int);

def _scan(o: int);

def _scan_visitor(child: int);

def _collect_white(o: int);

def _collect_white_visitor(child: int);

def _root_pass(count: int, phase: int);

def _reclaim_one(o: int);

def _reclaim_garbage -> None;

def:pub __jac_rt_alloc(size: int) -> int;

def:pub __jac_rt_set_type(o: int, tag: int);

def:pub __jac_rt_is_heap(o: int) -> bool;

def:pub __jac_rt_retain(o: int);

def:pub __jac_rt_release(o: int);

def:pub __jac_rt_release_acyclic(o: int);

def:pub __jac_rt_release_impl(o: int, may_cycle: bool);

def:pub __jac_rt_possible_root(o: int);

def:pub __jac_rt_free_block(raw: int);

def:pub __jac_rt_safe_free(raw: int);

def:pub __jac_rt_gc_disable -> None;

def:pub __jac_rt_gc_enable -> None;

def:pub __jac_rt_cycles_enable -> None;

def:pub __jac_rt_mark_threaded -> None;

def:pub __jac_rt_collect_cycles -> None;

def:pub __jac_rt_trace_register(dtor: int, trace: int);

def:pub __jac_rt_trace_lookup(dtor: int) -> int;

def:pub jac_retain(o: ptr[u8]);

def:pub jac_release(o: ptr[u8]);
