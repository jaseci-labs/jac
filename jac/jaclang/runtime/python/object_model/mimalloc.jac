import from c {
    def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memmove(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def strlen(
        text: ptr[u8]
    ) -> u64;  def snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def abort;  def sched_yield -> i32;  obj MiStack {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0),
            w12: u64 = u64(0),
            w13: u64 = u64(0),
            w14: u64 = u64(0),
            w15: u64 = u64(0),
            w16: u64 = u64(0),
            w17: u64 = u64(0),
            w18: u64 = u64(0),
            w19: u64 = u64(0),
            w20: u64 = u64(0),
            w21: u64 = u64(0),
            w22: u64 = u64(0),
            w23: u64 = u64(0),
            w24: u64 = u64(0),
            w25: u64 = u64(0),
            w26: u64 = u64(0),
            w27: u64 = u64(0),
            w28: u64 = u64(0),
            w29: u64 = u64(0),
            w30: u64 = u64(0),
            w31: u64 = u64(0),
            w32: u64 = u64(0),
            w33: u64 = u64(0),
            w34: u64 = u64(0),
            w35: u64 = u64(0),
            w36: u64 = u64(0),
            w37: u64 = u64(0),
            w38: u64 = u64(0),
            w39: u64 = u64(0),
            w40: u64 = u64(0),
            w41: u64 = u64(0),
            w42: u64 = u64(0),
            w43: u64 = u64(0),
            w44: u64 = u64(0),
            w45: u64 = u64(0),
            w46: u64 = u64(0),
            w47: u64 = u64(0),
            w48: u64 = u64(0),
            w49: u64 = u64(0),
            w50: u64 = u64(0),
            w51: u64 = u64(0),
            w52: u64 = u64(0),
            w53: u64 = u64(0),
            w54: u64 = u64(0),
            w55: u64 = u64(0),
            w56: u64 = u64(0),
            w57: u64 = u64(0),
            w58: u64 = u64(0),
            w59: u64 = u64(0),
            w60: u64 = u64(0),
            w61: u64 = u64(0),
            w62: u64 = u64(0),
            w63: u64 = u64(0),
            w64: u64 = u64(0),
            w65: u64 = u64(0),
            w66: u64 = u64(0),
            w67: u64 = u64(0),
            w68: u64 = u64(0),
            w69: u64 = u64(0),
            w70: u64 = u64(0),
            w71: u64 = u64(0),
            w72: u64 = u64(0),
            w73: u64 = u64(0),
            w74: u64 = u64(0),
            w75: u64 = u64(0),
            w76: u64 = u64(0),
            w77: u64 = u64(0),
            w78: u64 = u64(0),
            w79: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut MiStack) -> int;  def _PyMem_mi_page_clear_qsbr(
        page: ptr
    );  def _PyMem_mi_page_is_safe_to_free(page: ptr) -> bool;  def _PyMem_mi_page_maybe_free(
        page: ptr, pq: ptr, force: bool
    ) -> bool;  def _PyMem_mi_page_reclaimed(page: ptr);  def _PyMem_mi_heap_collect_qsbr(
        heap: ptr
    );  def memchr(s: ptr, c: i32, n: u64) -> ptr;  def realpath(
        path: ptr[u8], resolved_path: ptr[u8]
    ) -> ptr[u8];  def free(p: ptr);  def getenv(name: ptr[u8]) -> ptr[u8];  def atexit(
        func: ptr
    ) -> i32;  def strstr(haystack: ptr[u8], needle: ptr[u8]) -> ptr[u8];  def strtol(
        text: ptr[u8], end: ptr, base: i32
    ) -> i64;  def jacpy_stdio_stream(stream: i32) -> ptr;  def mmap(
        addr: ptr, length: u64, prot: i32, flags: i32, fd: i32, offset: i64
    ) -> ptr;  def munmap(addr: ptr, length: u64) -> i32;  def mprotect(
        addr: ptr, length: u64, prot: i32
    ) -> i32;  def madvise(addr: ptr, length: u64, advice: i32) -> i32;  def sysconf(
        name: i32
    ) -> i64;  def open(path: ptr[u8], flags: i32, *args: any) -> i32;  def read(
        fd: i32, buf: ptr, count: u64
    ) -> i64;  def close(fd: i32) -> i32;  def access(
        path: ptr[u8], mode: i32
    ) -> i32;  def write(fd: i32, buf: ptr, count: u64) -> i64;  def syscall(
        number: i64, *args: any
    ) -> i64;  def clock_gettime(clock: i32, value: ptr) -> i32;  def getrusage(
        who: i32, usage: ptr
    ) -> i32;  def pthread_key_create(key: ptr[u64], destructor: ptr) -> i32;  def pthread_setspecific(
        key: u64, value: ptr
    ) -> i32;
}

glob:priv MI_MALLOC_VERSION: Final[i32] = 212,
     MI_SECURE: Final[i32] = 0,
     MI_MAX_ALIGN_SIZE: Final[u64] = u64(16),
     MI_CACHE_LINE: Final[u64] = u64(64),
     MI_INTPTR_SHIFT: Final[u64] = u64(3),
     MI_SIZE_SHIFT: Final[u64] = u64(3),
     MI_INTPTR_SIZE: Final[u64] = u64(8),
     MI_INTPTR_BITS: Final[u64] = u64(64),
     MI_SIZE_SIZE: Final[u64] = u64(8),
     MI_SIZE_BITS: Final[u64] = u64(64),
     MI_SIZE_MAX: Final[u64] = u64(0xFFFFFFFFFFFFFFFF),
     MI_KiB: Final[u64] = u64(1024),
     MI_MiB: Final[u64] = u64(1048576),
     MI_GiB: Final[u64] = u64(1073741824),
     MI_SEGMENT_SLICE_SHIFT: Final[u64] = u64(16),
     MI_SEGMENT_SHIFT: Final[u64] = u64(25),
     MI_SMALL_PAGE_SHIFT: Final[u64] = u64(16),
     MI_MEDIUM_PAGE_SHIFT: Final[u64] = u64(19),
     MI_SEGMENT_SIZE: Final[u64] = u64(33554432),
     MI_SEGMENT_ALIGN: Final[u64] = u64(33554432),
     MI_SEGMENT_MASK: Final[u64] = u64(33554431),
     MI_SEGMENT_SLICE_SIZE: Final[u64] = u64(65536),
     MI_SLICES_PER_SEGMENT: Final[u64] = u64(512),
     MI_SMALL_PAGE_SIZE: Final[u64] = u64(65536),
     MI_MEDIUM_PAGE_SIZE: Final[u64] = u64(524288),
     MI_MEDIUM_OBJ_WSIZE_MAX: Final[u64] = u64(16384),
     MI_LARGE_OBJ_WSIZE_MAX: Final[u64] = u64(2097152),
     MI_ALIGNMENT_MAX: Final[u64] = u64(16777216),
     MI_MAX_SLICE_OFFSET: Final[u64] = u64(255),
     MI_HUGE_BLOCK_SIZE: Final[u32] = u32(2147483648),
     MI_MAX_ALIGN_GUARANTEE: Final[u64] = u64(128),
     MI_SMALL_WSIZE_MAX: Final[u64] = u64(128),
     MI_SMALL_SIZE_MAX: Final[u64] = u64(1024),
     MI_PADDING_SIZE: Final[u64] = u64(0),
     MI_PADDING_WSIZE: Final[u64] = u64(0),
     MI_PAGES_DIRECT: Final[u64] = u64(129),
     MI_BIN_FULL: Final[u64] = u64(74),
     MI_MINIMAL_COMMIT_SIZE: Final[u64] = u64(65536),
     MI_COMMIT_SIZE: Final[u64] = u64(65536),
     MI_COMMIT_MASK_BITS: Final[u64] = u64(512),
     MI_COMMIT_MASK_FIELD_BITS: Final[u64] = u64(64),
     MI_COMMIT_MASK_FIELD_COUNT: Final[u64] = u64(8),
     MI_SEGMENT_BIN_MAX: Final[u64] = u64(35),
     MI_DEBUG_UNINIT: Final[i32] = 205,
     MI_DEBUG_FREED: Final[i32] = 221,
     MI_DEBUG_PADDING: Final[i32] = 253;

glob:priv MI_USE_DELAYED_FREE: Final[u64] = u64(0),
     MI_DELAYED_FREEING: Final[u64] = u64(1),
     MI_NO_DELAYED_FREE: Final[u64] = u64(2),
     MI_NEVER_DELAYED_FREE: Final[u64] = u64(3);

glob:priv MI_PAGE_FLAG_IN_FULL: Final[u8] = u8(1),
     MI_PAGE_FLAG_HAS_ALIGNED: Final[u8] = u8(2);

glob:priv MI_PAGE_SMALL: Final[i32] = 0,
     MI_PAGE_MEDIUM: Final[i32] = 1,
     MI_PAGE_LARGE: Final[i32] = 2,
     MI_PAGE_HUGE: Final[i32] = 3,
     MI_SEGMENT_NORMAL: Final[i32] = 0,
     MI_SEGMENT_HUGE: Final[i32] = 1,
     MI_MEM_NONE: Final[i32] = 0,
     MI_MEM_EXTERNAL: Final[i32] = 1,
     MI_MEM_STATIC: Final[i32] = 2,
     MI_MEM_OS: Final[i32] = 3,
     MI_MEM_OS_HUGE: Final[i32] = 4,
     MI_MEM_OS_REMAP: Final[i32] = 5,
     MI_MEM_ARENA: Final[i32] = 6;

glob:priv mi_option_show_errors: Final[i32] = 0,
     mi_option_show_stats: Final[i32] = 1,
     mi_option_verbose: Final[i32] = 2,
     mi_option_eager_commit: Final[i32] = 3,
     mi_option_arena_eager_commit: Final[i32] = 4,
     mi_option_purge_decommits: Final[i32] = 5,
     mi_option_allow_large_os_pages: Final[i32] = 6,
     mi_option_reserve_huge_os_pages: Final[i32] = 7,
     mi_option_reserve_huge_os_pages_at: Final[i32] = 8,
     mi_option_reserve_os_memory: Final[i32] = 9,
     mi_option_deprecated_segment_cache: Final[i32] = 10,
     mi_option_deprecated_page_reset: Final[i32] = 11,
     mi_option_abandoned_page_purge: Final[i32] = 12,
     mi_option_deprecated_segment_reset: Final[i32] = 13,
     mi_option_eager_commit_delay: Final[i32] = 14,
     mi_option_purge_delay: Final[i32] = 15,
     mi_option_use_numa_nodes: Final[i32] = 16,
     mi_option_limit_os_alloc: Final[i32] = 17,
     mi_option_os_tag: Final[i32] = 18,
     mi_option_max_errors: Final[i32] = 19,
     mi_option_max_warnings: Final[i32] = 20,
     mi_option_max_segment_reclaim: Final[i32] = 21,
     mi_option_destroy_on_exit: Final[i32] = 22,
     mi_option_arena_reserve: Final[i32] = 23,
     mi_option_arena_purge_mult: Final[i32] = 24,
     mi_option_purge_extend_delay: Final[i32] = 25,
     _mi_option_last: Final[i32] = 26,
     mi_option_large_os_pages: Final[i32] = 6,
     mi_option_eager_region_commit: Final[i32] = 4,
     mi_option_reset_decommits: Final[i32] = 5,
     mi_option_reset_delay: Final[i32] = 15,
     mi_option_abandoned_page_reset: Final[i32] = 12;

glob:priv mi_block_t_SIZE: Final[u64] = u64(8),
     mi_page_t_CLEAR_FROM: Final[i64] = 13,
     mi_page_t_XTHREAD_FREE: Final[i64] = 48,
     mi_page_t_XHEAP: Final[i64] = 56,
     mi_page_t_SIZE: Final[u64] = u64(80),
     mi_page_queue_t_SIZE: Final[u64] = u64(24),
     mi_span_queue_t_SIZE: Final[u64] = u64(24),
     mi_memid_t_SIZE: Final[u64] = u64(24),
     mi_commit_mask_t_SIZE: Final[u64] = u64(64),
     mi_segment_t_MEMID: Final[i64] = 0,
     mi_segment_t_PURGE_MASK: Final[i64] = 48,
     mi_segment_t_COMMIT_MASK: Final[i64] = 112,
     mi_segment_t_ABANDONED_NEXT: Final[i64] = 176,
     mi_segment_t_NEXT: Final[i64] = 184,
     mi_segment_t_THREAD_ID: Final[i64] = 256,
     mi_segment_t_SLICES: Final[i64] = 264,
     mi_segment_t_SIZE: Final[u64] = u64(41304),
     mi_random_ctx_t_INPUT: Final[i64] = 0,
     mi_random_ctx_t_OUTPUT: Final[i64] = 64,
     mi_random_ctx_t_SIZE: Final[u64] = u64(136),
     mi_heap_t_THREAD_DELAYED_FREE: Final[i64] = 8,
     mi_heap_t_KEYS: Final[i64] = 40,
     mi_heap_t_RANDOM: Final[i64] = 56,
     mi_heap_t_PAGES_FREE_DIRECT: Final[i64] = 232,
     mi_heap_t_PAGES: Final[i64] = 1264,
     mi_heap_t_SIZE: Final[u64] = u64(3064),
     mi_stat_count_t_SIZE: Final[u64] = u64(32),
     mi_stat_counter_t_SIZE: Final[u64] = u64(16),
     mi_stats_t_SEGMENTS: Final[i64] = 0,
     mi_stats_t_PAGES: Final[i64] = 32,
     mi_stats_t_RESERVED: Final[i64] = 64,
     mi_stats_t_COMMITTED: Final[i64] = 96,
     mi_stats_t_RESET: Final[i64] = 128,
     mi_stats_t_PURGED: Final[i64] = 160,
     mi_stats_t_PAGE_COMMITTED: Final[i64] = 192,
     mi_stats_t_SEGMENTS_ABANDONED: Final[i64] = 224,
     mi_stats_t_PAGES_ABANDONED: Final[i64] = 256,
     mi_stats_t_THREADS: Final[i64] = 288,
     mi_stats_t_NORMAL: Final[i64] = 320,
     mi_stats_t_HUGE: Final[i64] = 352,
     mi_stats_t_LARGE: Final[i64] = 384,
     mi_stats_t_MALLOC: Final[i64] = 416,
     mi_stats_t_SEGMENTS_CACHE: Final[i64] = 448,
     mi_stats_t_PAGES_EXTENDED: Final[i64] = 480,
     mi_stats_t_MMAP_CALLS: Final[i64] = 496,
     mi_stats_t_COMMIT_CALLS: Final[i64] = 512,
     mi_stats_t_RESET_CALLS: Final[i64] = 528,
     mi_stats_t_PURGE_CALLS: Final[i64] = 544,
     mi_stats_t_PAGE_NO_RETIRE: Final[i64] = 560,
     mi_stats_t_SEARCHES: Final[i64] = 576,
     mi_stats_t_NORMAL_COUNT: Final[i64] = 592,
     mi_stats_t_HUGE_COUNT: Final[i64] = 608,
     mi_stats_t_LARGE_COUNT: Final[i64] = 624,
     mi_stats_t_SIZE: Final[u64] = u64(640),
     mi_segments_tld_t_SPANS: Final[i64] = 0,
     mi_tld_t_SEGMENTS: Final[i64] = 32,
     mi_tld_t_OS: Final[i64] = 952,
     mi_tld_t_STATS: Final[i64] = 968,
     mi_tld_t_SIZE: Final[u64] = u64(1608),
     mi_abandoned_pool_t_ABANDONED_VISITED: Final[i64] = 0,
     mi_abandoned_pool_t_ABANDONED: Final[i64] = 8,
     mi_abandoned_pool_t_ABANDONED_COUNT: Final[i64] = 16,
     mi_abandoned_pool_t_ABANDONED_VISITED_COUNT: Final[i64] = 24,
     mi_abandoned_pool_t_ABANDONED_READERS: Final[i64] = 32,
     mi_heap_area_t_SIZE: Final[u64] = u64(48),
     mi_heap_area_ex_t_PAGE: Final[i64] = 48,
     mi_heap_area_ex_t_SIZE: Final[u64] = u64(56),
     mi_os_mem_config_t_SIZE: Final[u64] = u64(32),
     mi_process_info_t_SIZE: Final[u64] = u64(64);

glob:priv MI_SHUFFLE_MUL1: Final[u64] = u64(0xbf58476d1ce4e5b9),
     MI_SHUFFLE_MUL2: Final[u64] = u64(0x94d049bb133111eb);

import from c {
    obj mi_block_t {
        has next: u64;
    }  obj mi_page_t {
        has slice_count: u32,
            slice_offset: u32,
            is_committed: bool,
            is_zero_init: bool,
            use_qsbr: bool,
            tag: u8,
            debug_offset: u8,
            flags: u8,
            free_is_zero: bool,
            retire_expire: u8,
            capacity: u16,
            reserved: u16,
            used: u32,
            xblock_size: u32,
            pad0: u32,
            free: ptr[mi_block_t],
            local_free: ptr[mi_block_t],
            xthread_free: u64,
            xheap: u64,
            next: ptr[mi_page_t],
            prev: ptr[mi_page_t];
    }  obj mi_page_queue_t {
        has first: ptr[mi_page_t],
            last: ptr[mi_page_t],
            block_size: u64;
    }  obj mi_span_queue_t {
        has first: ptr[mi_page_t],
            last: ptr[mi_page_t],
            slice_count: u64;
    }  obj mi_commit_mask_t {
        has mask0: u64,
            mask1: u64,
            mask2: u64,
            mask3: u64,
            mask4: u64,
            mask5: u64,
            mask6: u64,
            mask7: u64;
    }  obj mi_memid_t {
        has mem_os_base: ptr[u8],
            mem_os_alignment: u64,
            is_pinned: bool,
            initially_committed: bool,
            initially_zero: bool,
            pad0: u8,
            memkind: i32;
    }  obj mi_segment_t {
        has memid: mi_memid_t,
            allow_decommit: bool,
            allow_purge: bool,
            pad0: u16,
            pad1: u32,
            segment_size: u64,
            purge_expire: i64,
            purge_mask: mi_commit_mask_t,
            commit_mask: mi_commit_mask_t,
            abandoned_next: u64,
            next: ptr[mi_segment_t],
            abandoned: u64,
            abandoned_visits: u64,
            used: u64,
            cookie: u64,
            segment_slices: u64,
            segment_info_slices: u64,
            kind: i32,
            pad2: u32,
            slice_entries: u64,
            thread_id: u64;
    }  obj mi_abandoned_pool_t {
        has abandoned_visited: u64,
            abandoned: u64,
            abandoned_count: u64,
            abandoned_visited_count: u64,
            abandoned_readers: u64;
    }  obj MiU32x16 {
        has w0: u32,
            w1: u32,
            w2: u32,
            w3: u32,
            w4: u32,
            w5: u32,
            w6: u32,
            w7: u32,
            w8: u32,
            w9: u32,
            w10: u32,
            w11: u32,
            w12: u32,
            w13: u32,
            w14: u32,
            w15: u32;
    }  obj MiPagePtrs8 {
        has p0: ptr[mi_page_t],
            p1: ptr[mi_page_t],
            p2: ptr[mi_page_t],
            p3: ptr[mi_page_t],
            p4: ptr[mi_page_t],
            p5: ptr[mi_page_t],
            p6: ptr[mi_page_t],
            p7: ptr[mi_page_t];
    }  obj MiPagePtrs64 {
        has a0: MiPagePtrs8,
            a1: MiPagePtrs8,
            a2: MiPagePtrs8,
            a3: MiPagePtrs8,
            a4: MiPagePtrs8,
            a5: MiPagePtrs8,
            a6: MiPagePtrs8,
            a7: MiPagePtrs8;
    }  obj MiPagePtrs129 {
        has lo: MiPagePtrs64,
            hi: MiPagePtrs64,
            last: ptr[mi_page_t];
    }  obj MiPageQueues75 {
        has q0: mi_page_queue_t,
            q1: mi_page_queue_t,
            q2: mi_page_queue_t,
            q3: mi_page_queue_t,
            q4: mi_page_queue_t,
            q5: mi_page_queue_t,
            q6: mi_page_queue_t,
            q7: mi_page_queue_t,
            q8: mi_page_queue_t,
            q9: mi_page_queue_t,
            q10: mi_page_queue_t,
            q11: mi_page_queue_t,
            q12: mi_page_queue_t,
            q13: mi_page_queue_t,
            q14: mi_page_queue_t,
            q15: mi_page_queue_t,
            q16: mi_page_queue_t,
            q17: mi_page_queue_t,
            q18: mi_page_queue_t,
            q19: mi_page_queue_t,
            q20: mi_page_queue_t,
            q21: mi_page_queue_t,
            q22: mi_page_queue_t,
            q23: mi_page_queue_t,
            q24: mi_page_queue_t,
            q25: mi_page_queue_t,
            q26: mi_page_queue_t,
            q27: mi_page_queue_t,
            q28: mi_page_queue_t,
            q29: mi_page_queue_t,
            q30: mi_page_queue_t,
            q31: mi_page_queue_t,
            q32: mi_page_queue_t,
            q33: mi_page_queue_t,
            q34: mi_page_queue_t,
            q35: mi_page_queue_t,
            q36: mi_page_queue_t,
            q37: mi_page_queue_t,
            q38: mi_page_queue_t,
            q39: mi_page_queue_t,
            q40: mi_page_queue_t,
            q41: mi_page_queue_t,
            q42: mi_page_queue_t,
            q43: mi_page_queue_t,
            q44: mi_page_queue_t,
            q45: mi_page_queue_t,
            q46: mi_page_queue_t,
            q47: mi_page_queue_t,
            q48: mi_page_queue_t,
            q49: mi_page_queue_t,
            q50: mi_page_queue_t,
            q51: mi_page_queue_t,
            q52: mi_page_queue_t,
            q53: mi_page_queue_t,
            q54: mi_page_queue_t,
            q55: mi_page_queue_t,
            q56: mi_page_queue_t,
            q57: mi_page_queue_t,
            q58: mi_page_queue_t,
            q59: mi_page_queue_t,
            q60: mi_page_queue_t,
            q61: mi_page_queue_t,
            q62: mi_page_queue_t,
            q63: mi_page_queue_t,
            q64: mi_page_queue_t,
            q65: mi_page_queue_t,
            q66: mi_page_queue_t,
            q67: mi_page_queue_t,
            q68: mi_page_queue_t,
            q69: mi_page_queue_t,
            q70: mi_page_queue_t,
            q71: mi_page_queue_t,
            q72: mi_page_queue_t,
            q73: mi_page_queue_t,
            q74: mi_page_queue_t;
    }  obj MiSpanQueues36 {
        has q0: mi_span_queue_t,
            q1: mi_span_queue_t,
            q2: mi_span_queue_t,
            q3: mi_span_queue_t,
            q4: mi_span_queue_t,
            q5: mi_span_queue_t,
            q6: mi_span_queue_t,
            q7: mi_span_queue_t,
            q8: mi_span_queue_t,
            q9: mi_span_queue_t,
            q10: mi_span_queue_t,
            q11: mi_span_queue_t,
            q12: mi_span_queue_t,
            q13: mi_span_queue_t,
            q14: mi_span_queue_t,
            q15: mi_span_queue_t,
            q16: mi_span_queue_t,
            q17: mi_span_queue_t,
            q18: mi_span_queue_t,
            q19: mi_span_queue_t,
            q20: mi_span_queue_t,
            q21: mi_span_queue_t,
            q22: mi_span_queue_t,
            q23: mi_span_queue_t,
            q24: mi_span_queue_t,
            q25: mi_span_queue_t,
            q26: mi_span_queue_t,
            q27: mi_span_queue_t,
            q28: mi_span_queue_t,
            q29: mi_span_queue_t,
            q30: mi_span_queue_t,
            q31: mi_span_queue_t,
            q32: mi_span_queue_t,
            q33: mi_span_queue_t,
            q34: mi_span_queue_t,
            q35: mi_span_queue_t;
    }  obj mi_random_ctx_t {
        has input: MiU32x16,
            output: MiU32x16,
            output_available: i32,
            weak: bool,
            pad0: u8,
            pad1: u16;
    }  obj mi_heap_t {
        has tld: ptr[mi_tld_t],
            thread_delayed_free: u64,
            thread_id: u64,
            arena_id: i32,
            pad0: u32,
            cookie: u64,
            keys0: u64,
            keys1: u64,
            random: mi_random_ctx_t,
            page_count: u64,
            page_retired_min: u64,
            page_retired_max: u64,
            next: ptr[mi_heap_t],
            no_reclaim: bool,
            tag: u8,
            debug_offset: u8,
            page_use_qsbr: bool,
            pad1: u32,
            pages_free_direct: MiPagePtrs129,
            pages: MiPageQueues75;
    }  obj mi_stat_count_t {
        has allocated: i64,
            freed: i64,
            peak: i64,
            current: i64;
    }  obj mi_stat_counter_t {
        has total: i64,
            count: i64;
    }  obj mi_stats_t {
        has segments: mi_stat_count_t,
            pages: mi_stat_count_t,
            reserved: mi_stat_count_t,
            committed: mi_stat_count_t,
            reset: mi_stat_count_t,
            purged: mi_stat_count_t,
            page_committed: mi_stat_count_t,
            segments_abandoned: mi_stat_count_t,
            pages_abandoned: mi_stat_count_t,
            threads: mi_stat_count_t,
            normal: mi_stat_count_t,
            huge: mi_stat_count_t,
            large: mi_stat_count_t,
            malloc: mi_stat_count_t,
            segments_cache: mi_stat_count_t,
            pages_extended: mi_stat_counter_t,
            mmap_calls: mi_stat_counter_t,
            commit_calls: mi_stat_counter_t,
            reset_calls: mi_stat_counter_t,
            purge_calls: mi_stat_counter_t,
            page_no_retire: mi_stat_counter_t,
            searches: mi_stat_counter_t,
            normal_count: mi_stat_counter_t,
            huge_count: mi_stat_counter_t,
            large_count: mi_stat_counter_t;
    }  obj mi_os_tld_t {
        has region_idx: u64,
            stats: ptr[mi_stats_t];
    }  obj mi_segments_tld_t {
        has spans: MiSpanQueues36,
            count: u64,
            peak_count: u64,
            current_size: u64,
            peak_size: u64,
            stats: ptr[mi_stats_t],
            os: ptr[mi_os_tld_t],
            abandoned: ptr[mi_abandoned_pool_t];
    }  obj mi_tld_t {
        has heartbeat: u64,
            recurse: bool,
            pad0: u8,
            pad1: u16,
            pad2: u32,
            heap_backing: ptr[mi_heap_t],
            heaps: ptr[mi_heap_t],
            segments: mi_segments_tld_t,
            os: mi_os_tld_t,
            stats: mi_stats_t;
    }  obj mi_heap_area_t {
        has blocks: ptr[u8],
            reserved: u64,
            committed: u64,
            used: u64,
            block_size: u64,
            full_block_size: u64;
    }  obj mi_heap_area_ex_t {
        has area: mi_heap_area_t,
            page: ptr[mi_page_t];
    }  obj mi_os_mem_config_t {
        has page_size: u64,
            large_page_size: u64,
            alloc_granularity: u64,
            has_overcommit: bool,
            must_free_whole: bool,
            has_virtual_reserve: bool,
            pad0: u8,
            pad1: u32;
    }  obj mi_process_info_t {
        has elapsed: i64,
            utime: i64,
            stime: i64,
            current_rss: u64,
            peak_rss: u64,
            current_commit: u64,
            peak_commit: u64,
            page_faults: u64;
    }  obj MiOutputCall {
        has call: Callable[[ptr[u8], ptr], None] = 0;
    }  obj MiErrorCall {
        has call: Callable[[i32, ptr], None] = 0;
    }  obj MiDeferredFreeCall {
        has call: Callable[[bool, u64, ptr], None] = 0;
    }  obj MiBlockVisitCall {
        has call: Callable[[ptr, ptr, ptr, u64, ptr], bool] = 0;
    }  obj MiBitmapPredCall {
        has call: Callable[[u64, ptr], bool] = 0;
    }  obj MiPageVisitCall {
        has call:
            Callable[
                [ptr[mi_heap_t], ptr[mi_page_queue_t], ptr[mi_page_t], ptr, ptr],
                u8
            ] = 0;
    }  obj MiVoidCall {
        has call: Callable[[], None] = 0;
    }  obj MiAreaVisitCall {
        has call: Callable[[ptr[mi_heap_t], ptr[mi_heap_area_ex_t], ptr], u8] = 0;
    }  obj MiGlobals {
        has numa_node_count: u64,
            process_is_initialized: bool,
            pad0: u8,
            pad1: u16,
            pad2: u32;
    }
}

import from c {
    glob:priv _mi_page_empty: mi_page_t = mi_page_t(); glob:priv _mi_stats_main:
             mi_stats_t = mi_stats_t(); glob:priv _mi_abandoned_default:
             mi_abandoned_pool_t = mi_abandoned_pool_t(); glob:priv mi_globals:
             MiGlobals = MiGlobals(); glob:priv _mi_heap_empty: mi_heap_t = mi_heap_t(
             random=mi_random_ctx_t(weak=True),
             page_retired_min=u64(74),
             pages_free_direct=MiPagePtrs129(
                 lo=MiPagePtrs64(
                     a0=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a1=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a2=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a3=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a4=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a5=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a6=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a7=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     )
                 ),
                 hi=MiPagePtrs64(
                     a0=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a1=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a2=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a3=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a4=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a5=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a6=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a7=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     )
                 ),
                 last=addressof(_mi_page_empty)
             ),
             pages=MiPageQueues75(
                 q0=mi_page_queue_t(block_size=u64(8)),
                 q1=mi_page_queue_t(block_size=u64(8)),
                 q2=mi_page_queue_t(block_size=u64(16)),
                 q3=mi_page_queue_t(block_size=u64(24)),
                 q4=mi_page_queue_t(block_size=u64(32)),
                 q5=mi_page_queue_t(block_size=u64(40)),
                 q6=mi_page_queue_t(block_size=u64(48)),
                 q7=mi_page_queue_t(block_size=u64(56)),
                 q8=mi_page_queue_t(block_size=u64(64)),
                 q9=mi_page_queue_t(block_size=u64(80)),
                 q10=mi_page_queue_t(block_size=u64(96)),
                 q11=mi_page_queue_t(block_size=u64(112)),
                 q12=mi_page_queue_t(block_size=u64(128)),
                 q13=mi_page_queue_t(block_size=u64(160)),
                 q14=mi_page_queue_t(block_size=u64(192)),
                 q15=mi_page_queue_t(block_size=u64(224)),
                 q16=mi_page_queue_t(block_size=u64(256)),
                 q17=mi_page_queue_t(block_size=u64(320)),
                 q18=mi_page_queue_t(block_size=u64(384)),
                 q19=mi_page_queue_t(block_size=u64(448)),
                 q20=mi_page_queue_t(block_size=u64(512)),
                 q21=mi_page_queue_t(block_size=u64(640)),
                 q22=mi_page_queue_t(block_size=u64(768)),
                 q23=mi_page_queue_t(block_size=u64(896)),
                 q24=mi_page_queue_t(block_size=u64(1024)),
                 q25=mi_page_queue_t(block_size=u64(1280)),
                 q26=mi_page_queue_t(block_size=u64(1536)),
                 q27=mi_page_queue_t(block_size=u64(1792)),
                 q28=mi_page_queue_t(block_size=u64(2048)),
                 q29=mi_page_queue_t(block_size=u64(2560)),
                 q30=mi_page_queue_t(block_size=u64(3072)),
                 q31=mi_page_queue_t(block_size=u64(3584)),
                 q32=mi_page_queue_t(block_size=u64(4096)),
                 q33=mi_page_queue_t(block_size=u64(5120)),
                 q34=mi_page_queue_t(block_size=u64(6144)),
                 q35=mi_page_queue_t(block_size=u64(7168)),
                 q36=mi_page_queue_t(block_size=u64(8192)),
                 q37=mi_page_queue_t(block_size=u64(10240)),
                 q38=mi_page_queue_t(block_size=u64(12288)),
                 q39=mi_page_queue_t(block_size=u64(14336)),
                 q40=mi_page_queue_t(block_size=u64(16384)),
                 q41=mi_page_queue_t(block_size=u64(20480)),
                 q42=mi_page_queue_t(block_size=u64(24576)),
                 q43=mi_page_queue_t(block_size=u64(28672)),
                 q44=mi_page_queue_t(block_size=u64(32768)),
                 q45=mi_page_queue_t(block_size=u64(40960)),
                 q46=mi_page_queue_t(block_size=u64(49152)),
                 q47=mi_page_queue_t(block_size=u64(57344)),
                 q48=mi_page_queue_t(block_size=u64(65536)),
                 q49=mi_page_queue_t(block_size=u64(81920)),
                 q50=mi_page_queue_t(block_size=u64(98304)),
                 q51=mi_page_queue_t(block_size=u64(114688)),
                 q52=mi_page_queue_t(block_size=u64(131072)),
                 q53=mi_page_queue_t(block_size=u64(163840)),
                 q54=mi_page_queue_t(block_size=u64(196608)),
                 q55=mi_page_queue_t(block_size=u64(229376)),
                 q56=mi_page_queue_t(block_size=u64(262144)),
                 q57=mi_page_queue_t(block_size=u64(327680)),
                 q58=mi_page_queue_t(block_size=u64(393216)),
                 q59=mi_page_queue_t(block_size=u64(458752)),
                 q60=mi_page_queue_t(block_size=u64(524288)),
                 q61=mi_page_queue_t(block_size=u64(655360)),
                 q62=mi_page_queue_t(block_size=u64(786432)),
                 q63=mi_page_queue_t(block_size=u64(917504)),
                 q64=mi_page_queue_t(block_size=u64(1048576)),
                 q65=mi_page_queue_t(block_size=u64(1310720)),
                 q66=mi_page_queue_t(block_size=u64(1572864)),
                 q67=mi_page_queue_t(block_size=u64(1835008)),
                 q68=mi_page_queue_t(block_size=u64(2097152)),
                 q69=mi_page_queue_t(block_size=u64(2621440)),
                 q70=mi_page_queue_t(block_size=u64(3145728)),
                 q71=mi_page_queue_t(block_size=u64(3670016)),
                 q72=mi_page_queue_t(block_size=u64(4194304)),
                 q73=mi_page_queue_t(block_size=u64(131080)),
                 q74=mi_page_queue_t(block_size=u64(131088))
             )
         ); glob:priv _mi_heap_main: mi_heap_t = mi_heap_t(
             tld=addressof(tld_main),
             random=mi_random_ctx_t(input=MiU32x16(w0=u32(0x846ca68b)), weak=True),
             page_retired_min=u64(74),
             pages_free_direct=MiPagePtrs129(
                 lo=MiPagePtrs64(
                     a0=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a1=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a2=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a3=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a4=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a5=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a6=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a7=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     )
                 ),
                 hi=MiPagePtrs64(
                     a0=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a1=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a2=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a3=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a4=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a5=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a6=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     ),
                     a7=MiPagePtrs8(
                         p0=addressof(_mi_page_empty),
                         p1=addressof(_mi_page_empty),
                         p2=addressof(_mi_page_empty),
                         p3=addressof(_mi_page_empty),
                         p4=addressof(_mi_page_empty),
                         p5=addressof(_mi_page_empty),
                         p6=addressof(_mi_page_empty),
                         p7=addressof(_mi_page_empty)
                     )
                 ),
                 last=addressof(_mi_page_empty)
             ),
             pages=MiPageQueues75(
                 q0=mi_page_queue_t(block_size=u64(8)),
                 q1=mi_page_queue_t(block_size=u64(8)),
                 q2=mi_page_queue_t(block_size=u64(16)),
                 q3=mi_page_queue_t(block_size=u64(24)),
                 q4=mi_page_queue_t(block_size=u64(32)),
                 q5=mi_page_queue_t(block_size=u64(40)),
                 q6=mi_page_queue_t(block_size=u64(48)),
                 q7=mi_page_queue_t(block_size=u64(56)),
                 q8=mi_page_queue_t(block_size=u64(64)),
                 q9=mi_page_queue_t(block_size=u64(80)),
                 q10=mi_page_queue_t(block_size=u64(96)),
                 q11=mi_page_queue_t(block_size=u64(112)),
                 q12=mi_page_queue_t(block_size=u64(128)),
                 q13=mi_page_queue_t(block_size=u64(160)),
                 q14=mi_page_queue_t(block_size=u64(192)),
                 q15=mi_page_queue_t(block_size=u64(224)),
                 q16=mi_page_queue_t(block_size=u64(256)),
                 q17=mi_page_queue_t(block_size=u64(320)),
                 q18=mi_page_queue_t(block_size=u64(384)),
                 q19=mi_page_queue_t(block_size=u64(448)),
                 q20=mi_page_queue_t(block_size=u64(512)),
                 q21=mi_page_queue_t(block_size=u64(640)),
                 q22=mi_page_queue_t(block_size=u64(768)),
                 q23=mi_page_queue_t(block_size=u64(896)),
                 q24=mi_page_queue_t(block_size=u64(1024)),
                 q25=mi_page_queue_t(block_size=u64(1280)),
                 q26=mi_page_queue_t(block_size=u64(1536)),
                 q27=mi_page_queue_t(block_size=u64(1792)),
                 q28=mi_page_queue_t(block_size=u64(2048)),
                 q29=mi_page_queue_t(block_size=u64(2560)),
                 q30=mi_page_queue_t(block_size=u64(3072)),
                 q31=mi_page_queue_t(block_size=u64(3584)),
                 q32=mi_page_queue_t(block_size=u64(4096)),
                 q33=mi_page_queue_t(block_size=u64(5120)),
                 q34=mi_page_queue_t(block_size=u64(6144)),
                 q35=mi_page_queue_t(block_size=u64(7168)),
                 q36=mi_page_queue_t(block_size=u64(8192)),
                 q37=mi_page_queue_t(block_size=u64(10240)),
                 q38=mi_page_queue_t(block_size=u64(12288)),
                 q39=mi_page_queue_t(block_size=u64(14336)),
                 q40=mi_page_queue_t(block_size=u64(16384)),
                 q41=mi_page_queue_t(block_size=u64(20480)),
                 q42=mi_page_queue_t(block_size=u64(24576)),
                 q43=mi_page_queue_t(block_size=u64(28672)),
                 q44=mi_page_queue_t(block_size=u64(32768)),
                 q45=mi_page_queue_t(block_size=u64(40960)),
                 q46=mi_page_queue_t(block_size=u64(49152)),
                 q47=mi_page_queue_t(block_size=u64(57344)),
                 q48=mi_page_queue_t(block_size=u64(65536)),
                 q49=mi_page_queue_t(block_size=u64(81920)),
                 q50=mi_page_queue_t(block_size=u64(98304)),
                 q51=mi_page_queue_t(block_size=u64(114688)),
                 q52=mi_page_queue_t(block_size=u64(131072)),
                 q53=mi_page_queue_t(block_size=u64(163840)),
                 q54=mi_page_queue_t(block_size=u64(196608)),
                 q55=mi_page_queue_t(block_size=u64(229376)),
                 q56=mi_page_queue_t(block_size=u64(262144)),
                 q57=mi_page_queue_t(block_size=u64(327680)),
                 q58=mi_page_queue_t(block_size=u64(393216)),
                 q59=mi_page_queue_t(block_size=u64(458752)),
                 q60=mi_page_queue_t(block_size=u64(524288)),
                 q61=mi_page_queue_t(block_size=u64(655360)),
                 q62=mi_page_queue_t(block_size=u64(786432)),
                 q63=mi_page_queue_t(block_size=u64(917504)),
                 q64=mi_page_queue_t(block_size=u64(1048576)),
                 q65=mi_page_queue_t(block_size=u64(1310720)),
                 q66=mi_page_queue_t(block_size=u64(1572864)),
                 q67=mi_page_queue_t(block_size=u64(1835008)),
                 q68=mi_page_queue_t(block_size=u64(2097152)),
                 q69=mi_page_queue_t(block_size=u64(2621440)),
                 q70=mi_page_queue_t(block_size=u64(3145728)),
                 q71=mi_page_queue_t(block_size=u64(3670016)),
                 q72=mi_page_queue_t(block_size=u64(4194304)),
                 q73=mi_page_queue_t(block_size=u64(131080)),
                 q74=mi_page_queue_t(block_size=u64(131088))
             )
         ); glob:priv tld_empty: mi_tld_t = mi_tld_t(
             segments=mi_segments_tld_t(
                 spans=MiSpanQueues36(
                     q0=mi_span_queue_t(slice_count=u64(1)),
                     q1=mi_span_queue_t(slice_count=u64(1)),
                     q2=mi_span_queue_t(slice_count=u64(2)),
                     q3=mi_span_queue_t(slice_count=u64(3)),
                     q4=mi_span_queue_t(slice_count=u64(4)),
                     q5=mi_span_queue_t(slice_count=u64(5)),
                     q6=mi_span_queue_t(slice_count=u64(6)),
                     q7=mi_span_queue_t(slice_count=u64(7)),
                     q8=mi_span_queue_t(slice_count=u64(10)),
                     q9=mi_span_queue_t(slice_count=u64(12)),
                     q10=mi_span_queue_t(slice_count=u64(14)),
                     q11=mi_span_queue_t(slice_count=u64(16)),
                     q12=mi_span_queue_t(slice_count=u64(20)),
                     q13=mi_span_queue_t(slice_count=u64(24)),
                     q14=mi_span_queue_t(slice_count=u64(28)),
                     q15=mi_span_queue_t(slice_count=u64(32)),
                     q16=mi_span_queue_t(slice_count=u64(40)),
                     q17=mi_span_queue_t(slice_count=u64(48)),
                     q18=mi_span_queue_t(slice_count=u64(56)),
                     q19=mi_span_queue_t(slice_count=u64(64)),
                     q20=mi_span_queue_t(slice_count=u64(80)),
                     q21=mi_span_queue_t(slice_count=u64(96)),
                     q22=mi_span_queue_t(slice_count=u64(112)),
                     q23=mi_span_queue_t(slice_count=u64(128)),
                     q24=mi_span_queue_t(slice_count=u64(160)),
                     q25=mi_span_queue_t(slice_count=u64(192)),
                     q26=mi_span_queue_t(slice_count=u64(224)),
                     q27=mi_span_queue_t(slice_count=u64(256)),
                     q28=mi_span_queue_t(slice_count=u64(320)),
                     q29=mi_span_queue_t(slice_count=u64(384)),
                     q30=mi_span_queue_t(slice_count=u64(448)),
                     q31=mi_span_queue_t(slice_count=u64(512)),
                     q32=mi_span_queue_t(slice_count=u64(640)),
                     q33=mi_span_queue_t(slice_count=u64(768)),
                     q34=mi_span_queue_t(slice_count=u64(896)),
                     q35=mi_span_queue_t(slice_count=u64(1024))
                 ),
                 abandoned=addressof(_mi_abandoned_default)
             )
         ); glob:priv tld_main: mi_tld_t = mi_tld_t(
             heap_backing=addressof(_mi_heap_main),
             heaps=addressof(_mi_heap_main),
             segments=mi_segments_tld_t(
                 spans=MiSpanQueues36(
                     q0=mi_span_queue_t(slice_count=u64(1)),
                     q1=mi_span_queue_t(slice_count=u64(1)),
                     q2=mi_span_queue_t(slice_count=u64(2)),
                     q3=mi_span_queue_t(slice_count=u64(3)),
                     q4=mi_span_queue_t(slice_count=u64(4)),
                     q5=mi_span_queue_t(slice_count=u64(5)),
                     q6=mi_span_queue_t(slice_count=u64(6)),
                     q7=mi_span_queue_t(slice_count=u64(7)),
                     q8=mi_span_queue_t(slice_count=u64(10)),
                     q9=mi_span_queue_t(slice_count=u64(12)),
                     q10=mi_span_queue_t(slice_count=u64(14)),
                     q11=mi_span_queue_t(slice_count=u64(16)),
                     q12=mi_span_queue_t(slice_count=u64(20)),
                     q13=mi_span_queue_t(slice_count=u64(24)),
                     q14=mi_span_queue_t(slice_count=u64(28)),
                     q15=mi_span_queue_t(slice_count=u64(32)),
                     q16=mi_span_queue_t(slice_count=u64(40)),
                     q17=mi_span_queue_t(slice_count=u64(48)),
                     q18=mi_span_queue_t(slice_count=u64(56)),
                     q19=mi_span_queue_t(slice_count=u64(64)),
                     q20=mi_span_queue_t(slice_count=u64(80)),
                     q21=mi_span_queue_t(slice_count=u64(96)),
                     q22=mi_span_queue_t(slice_count=u64(112)),
                     q23=mi_span_queue_t(slice_count=u64(128)),
                     q24=mi_span_queue_t(slice_count=u64(160)),
                     q25=mi_span_queue_t(slice_count=u64(192)),
                     q26=mi_span_queue_t(slice_count=u64(224)),
                     q27=mi_span_queue_t(slice_count=u64(256)),
                     q28=mi_span_queue_t(slice_count=u64(320)),
                     q29=mi_span_queue_t(slice_count=u64(384)),
                     q30=mi_span_queue_t(slice_count=u64(448)),
                     q31=mi_span_queue_t(slice_count=u64(512)),
                     q32=mi_span_queue_t(slice_count=u64(640)),
                     q33=mi_span_queue_t(slice_count=u64(768)),
                     q34=mi_span_queue_t(slice_count=u64(896)),
                     q35=mi_span_queue_t(slice_count=u64(1024))
                 ),
                 abandoned=addressof(_mi_abandoned_default)
             )
         );
}

def mi_atomic_load_relaxed(p: ptr[u64]) -> u64;

def mi_atomic_load_acquire(p: ptr[u64]) -> u64;

def mi_atomic_load_seq_cst(p: ptr[u64]) -> u64;

def mi_atomic_store_seq_cst(p: ptr[u64], x: u64);

def mi_atomic_store_relaxed(p: ptr[u64], x: u64);

def mi_atomic_store_release(p: ptr[u64], x: u64);

def mi_atomic_exchange_release(p: ptr[u64], x: u64) -> u64;

def mi_atomic_exchange_acq_rel(p: ptr[u64], x: u64) -> u64;

def mi_atomic_cas_strong_release(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64];

def mi_atomic_cas_strong_acq_rel(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64];

def mi_atomic_cas_weak_release(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64];

def mi_atomic_cas_weak_acq_rel(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64];

def mi_atomic_add_relaxed(p: ptr[u64], x: u64) -> u64;

def mi_atomic_sub_relaxed(p: ptr[u64], x: u64) -> u64;

def mi_atomic_add_acq_rel(p: ptr[u64], x: u64) -> u64;

def mi_atomic_sub_acq_rel(p: ptr[u64], x: u64) -> u64;

def mi_atomic_and_acq_rel(p: ptr[u64], x: u64) -> u64;

def mi_atomic_or_acq_rel(p: ptr[u64], x: u64) -> u64;

def mi_atomic_increment_relaxed(p: ptr[u64]) -> u64;

def mi_atomic_decrement_relaxed(p: ptr[u64]) -> u64;

def mi_atomic_increment_acq_rel(p: ptr[u64]) -> u64;

def mi_atomic_decrement_acq_rel(p: ptr[u64]) -> u64;

def mi_atomic_addi(p: ptr[i64], add: i64) -> i64;

def mi_atomic_subi(p: ptr[i64], sub: i64) -> i64;

def mi_atomic_addi64_relaxed(p: ptr[i64], add: i64) -> i64;

def mi_atomic_addi64_acq_rel(p: ptr[i64], add: i64) -> i64;

def mi_atomic_maxi64_relaxed(p: ptr[i64], x: i64);

def mi_atomic_loadi64_relaxed(p: ptr[i64]) -> i64;

def mi_atomic_loadi64_acquire(p: ptr[i64]) -> i64;

def mi_atomic_storei64_relaxed(p: ptr[i64], x: i64);

def mi_atomic_storei64_release(p: ptr[i64], x: i64);

def mi_atomic_casi64_strong_acq_rel(
    p: ptr[i64], expected: i64, desired: i64
) -> tuple[bool, i64];

def mi_atomic_once(once: ptr[u64]) -> bool;

def mi_atomic_yield;

def mi_heap_default_slot -> ptr[ptr[mi_heap_t]];

def mi_prim_get_default_heap -> ptr[mi_heap_t];

def _mi_prim_thread_id -> u64;

def mi_call_output(fun: ptr, msg: ptr[u8], arg: ptr);

def mi_call_void(fun: ptr);

def mi_call_error(fun: ptr, err: i32, arg: ptr);

def mi_call_deferred_free(fun: ptr, force: bool, heartbeat: u64, arg: ptr);

def mi_call_block_visit(
    fun: ptr, heap: ptr, area: ptr, block: ptr, block_size: u64, arg: ptr
) -> bool;

def mi_call_bitmap_pred(fun: ptr, bitmap_idx: u64, pred_arg: ptr) -> bool;

def mi_call_page_visitor(
    fun: ptr,
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg1: ptr,
    arg2: ptr
) -> bool;

def mi_call_area_visitor(
    fun: ptr, heap: ptr[mi_heap_t], xarea: ptr[mi_heap_area_ex_t], arg: ptr
) -> bool;

def mi_word_addr(base: ptr[u8], ofs: i64) -> ptr[u64];

def mi_page_xthread_free_addr(page: ptr[mi_page_t]) -> ptr[u64];

def mi_page_xheap_addr(page: ptr[mi_page_t]) -> ptr[u64];

def mi_heap_thread_delayed_free_addr(heap: ptr[mi_heap_t]) -> ptr[u64];

def mi_heap_keys(heap: ptr[mi_heap_t]) -> ptr[u64];

def mi_heap_random(heap: ptr[mi_heap_t]) -> ptr[mi_random_ctx_t];

def mi_heap_pages_free_direct(heap: ptr[mi_heap_t]) -> ptr[ptr[mi_page_t]];

def mi_heap_pages(heap: ptr[mi_heap_t]) -> ptr[mi_page_queue_t];

def mi_heap_page_queue(heap: ptr[mi_heap_t], bin: u64) -> ptr[mi_page_queue_t];

def mi_random_input(ctx: ptr[mi_random_ctx_t]) -> ptr[u32];

def mi_random_output(ctx: ptr[mi_random_ctx_t]) -> ptr[u32];

def mi_segment_memid(segment: ptr[mi_segment_t]) -> ptr[mi_memid_t];

def mi_segment_purge_mask_of(segment: ptr[mi_segment_t]) -> ptr[mi_commit_mask_t];

def mi_segment_commit_mask_of(segment: ptr[mi_segment_t]) -> ptr[mi_commit_mask_t];

def mi_segment_abandoned_next_addr(segment: ptr[mi_segment_t]) -> ptr[u64];

def mi_segment_thread_id_addr(segment: ptr[mi_segment_t]) -> ptr[u64];

def mi_segment_slices(segment: ptr[mi_segment_t]) -> ptr[mi_page_t];

def mi_tld_segments(tld: ptr[mi_tld_t]) -> ptr[mi_segments_tld_t];

def mi_tld_os(tld: ptr[mi_tld_t]) -> ptr[mi_os_tld_t];

def mi_tld_stats(tld: ptr[mi_tld_t]) -> ptr[mi_stats_t];

def mi_segments_tld_span_queue(
    tld: ptr[mi_segments_tld_t], bin: u64
) -> ptr[mi_span_queue_t];

def mi_stat_count_at(stats: ptr[mi_stats_t], ofs: i64) -> ptr[mi_stat_count_t];

def mi_stat_counter_at(stats: ptr[mi_stats_t], ofs: i64) -> ptr[mi_stat_counter_t];

def mi_heap_area_ex_area(xarea: ptr[mi_heap_area_ex_t]) -> ptr[mi_heap_area_t];

def mi_numa_node_count_addr -> ptr[u64];

def mi_page_empty -> ptr[mi_page_t];

def mi_tld_main_link;

def _mi_is_power_of_two(x: u64) -> bool;

def _mi_is_aligned(p: ptr[u8], alignment: u64) -> bool;

def _mi_align_up(sz: u64, alignment: u64) -> u64;

def _mi_align_down(sz: u64, alignment: u64) -> u64;

def _mi_divide_up(size: u64, divider: u64) -> u64;

def mi_mem_is_zero(p: ptr[u8], size: u64) -> bool;

def _mi_wsize_from_size(size: u64) -> u64;

def mi_mul_overflow(count: u64, size: u64) -> tuple[bool, u64];

def mi_count_size_overflow(count: u64, size: u64) -> tuple[bool, u64];

def _mi_random_shuffle(x: u64) -> u64;

def mi_clz(x: u64) -> u64;

def mi_ctz(x: u64) -> u64;

def mi_bsr(x: u64) -> u64;

def mi_rotl(x: u64, shift: u64) -> u64;

def mi_rotr(x: u64, shift: u64) -> u64;

def _mi_memcpy(dst: ptr, src: ptr, n: u64);

def _mi_memzero(dst: ptr, n: u64);

def _mi_memcpy_aligned(dst: ptr, src: ptr, n: u64);

def _mi_memzero_aligned(dst: ptr, n: u64);

def mi_heap_is_backing(heap: ptr[mi_heap_t]) -> bool;

def mi_heap_is_initialized(heap: ptr[mi_heap_t]) -> bool;

def _mi_ptr_cookie(p: ptr[u8]) -> u64;

def _mi_heap_get_free_small_page(heap: ptr[mi_heap_t], size: u64) -> ptr[mi_page_t];

def _mi_ptr_segment(p: ptr[u8]) -> ptr[mi_segment_t];

def _mi_page_segment(page: ptr[mi_page_t]) -> ptr[mi_segment_t];

def mi_slice_first(slice: ptr[mi_page_t]) -> ptr[mi_page_t];

def _mi_segment_page_of(segment: ptr[mi_segment_t], p: ptr[u8]) -> ptr[mi_page_t];

def _mi_page_start(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t]
) -> tuple[ptr[u8], u64];

def _mi_ptr_page(p: ptr[u8]) -> ptr[mi_page_t];

def mi_page_block_size(page: ptr[mi_page_t]) -> u64;

def mi_page_is_huge(page: ptr[mi_page_t]) -> bool;

def mi_page_usable_block_size(page: ptr[mi_page_t]) -> u64;

def mi_segment_size(segment: ptr[mi_segment_t]) -> u64;

def mi_segment_end(segment: ptr[mi_segment_t]) -> ptr[u8];

def mi_page_thread_free(page: ptr[mi_page_t]) -> ptr[mi_block_t];

def mi_page_thread_free_flag(page: ptr[mi_page_t]) -> u64;

def mi_page_heap(page: ptr[mi_page_t]) -> ptr[mi_heap_t];

def mi_page_set_heap(page: ptr[mi_page_t], heap: ptr[mi_heap_t]);

def mi_tf_block(tf: u64) -> ptr[mi_block_t];

def mi_tf_delayed(tf: u64) -> u64;

def mi_tf_make(block: ptr[mi_block_t], delayed: u64) -> u64;

def mi_tf_set_delayed(tf: u64, delayed: u64) -> u64;

def mi_tf_set_block(tf: u64, block: ptr[mi_block_t]) -> u64;

def mi_page_all_free(page: ptr[mi_page_t]) -> bool;

def mi_page_has_any_available(page: ptr[mi_page_t]) -> bool;

def mi_page_immediate_available(page: ptr[mi_page_t]) -> bool;

def mi_page_mostly_used(page: ptr[mi_page_t]) -> bool;

def mi_page_queue(heap: ptr[mi_heap_t], size: u64) -> ptr[mi_page_queue_t];

def mi_page_is_in_full(page: ptr[mi_page_t]) -> bool;

def mi_page_set_in_full(page: ptr[mi_page_t], in_full: bool);

def mi_page_has_aligned(page: ptr[mi_page_t]) -> bool;

def mi_page_set_has_aligned(page: ptr[mi_page_t], has_aligned: bool);

def mi_is_in_same_segment(p: ptr[u8], q: ptr[u8]) -> bool;

def mi_is_in_same_page(p: ptr[u8], q: ptr[u8]) -> bool;

def mi_ptr_decode(null_: ptr[u8], x: u64, keys: ptr[u64]) -> ptr[u8];

def mi_ptr_encode(null_: ptr[u8], p: ptr[u8], keys: ptr[u64]) -> u64;

def mi_block_nextx(
    null_: ptr[u8], block: ptr[mi_block_t], keys: ptr[u64]
) -> ptr[mi_block_t];

def mi_block_set_nextx(
    null_: ptr[u8], block: ptr[mi_block_t], next: ptr[mi_block_t], keys: ptr[u64]
);

def mi_block_next(page: ptr[mi_page_t], block: ptr[mi_block_t]) -> ptr[mi_block_t];

def mi_block_set_next(
    page: ptr[mi_page_t], block: ptr[mi_block_t], next: ptr[mi_block_t]
);

def mi_commit_mask_create_empty(cm: ptr[mi_commit_mask_t]);

def mi_commit_mask_create_full(cm: ptr[mi_commit_mask_t]);

def mi_commit_mask_is_empty(cm: ptr[mi_commit_mask_t]) -> bool;

def mi_commit_mask_is_full(cm: ptr[mi_commit_mask_t]) -> bool;

def mi_memkind_is_os(memkind: i32) -> bool;

def mi_memid_init(memid: ptr[mi_memid_t], memkind: i32);

def mi_memid_init_none(memid: ptr[mi_memid_t]);

def mi_memid_init_os(
    memid: ptr[mi_memid_t], committed: bool, is_zero: bool, is_large: bool
);

def mi_memid_copy(dst: ptr[mi_memid_t], src: ptr[mi_memid_t]);

def mi_memid_arena_block_index(memid: ptr[mi_memid_t]) -> u64;

def mi_memid_set_arena_block_index(memid: ptr[mi_memid_t], block_index: u64);

def mi_memid_arena_id(memid: ptr[mi_memid_t]) -> i32;

def mi_memid_set_arena_id(memid: ptr[mi_memid_t], id: i32);

def mi_memid_arena_is_exclusive(memid: ptr[mi_memid_t]) -> bool;

def mi_memid_set_arena_is_exclusive(memid: ptr[mi_memid_t], is_exclusive: bool);

def _mi_os_numa_node(tld: ptr[mi_os_tld_t]) -> i32;

def _mi_os_numa_node_count -> u64;


glob:priv MI_ALLOC_MUL_NO_OVERFLOW: Final[u64] = u64(4294967296);

def mi_alloc_count_size_overflows(count: u64, size: u64) -> bool;

def _mi_page_malloc(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t], size: u64, zero: bool
) -> ptr[u8];

def mi_heap_malloc_small_zero(heap: ptr[mi_heap_t], size: u64, zero: bool) -> ptr[u8];

import from c {
    def mi_heap_malloc_small(heap: ptr, size: u64) -> ptr {
        return ptr(mi_heap_malloc_small_zero(ptr[mi_heap_t](heap), size, False));
    }  def mi_malloc_small(size: u64) -> ptr {
        return ptr(mi_heap_malloc_small_zero(mi_prim_get_default_heap(), size, False));
    }
}

def _mi_heap_malloc_zero_ex(
    heap: ptr[mi_heap_t], size: u64, zero: bool, huge_alignment: u64
) -> ptr[u8];

def _mi_heap_malloc_zero(heap: ptr[mi_heap_t], size: u64, zero: bool) -> ptr[u8];

import from c {
    def mi_heap_malloc(heap: ptr, size: u64) -> ptr {
        return ptr(_mi_heap_malloc_zero(ptr[mi_heap_t](heap), size, False));
    }  def mi_malloc(size: u64) -> ptr {
        return ptr(_mi_heap_malloc_zero(mi_prim_get_default_heap(), size, False));
    }  def mi_zalloc_small(size: u64) -> ptr {
        return ptr(mi_heap_malloc_small_zero(mi_prim_get_default_heap(), size, True));
    }  def mi_heap_zalloc(heap: ptr, size: u64) -> ptr {
        return ptr(_mi_heap_malloc_zero(ptr[mi_heap_t](heap), size, True));
    }  def mi_zalloc(size: u64) -> ptr {
        return ptr(_mi_heap_malloc_zero(mi_prim_get_default_heap(), size, True));
    }
}

def mi_page_usable_size_of(page: ptr[mi_page_t], block: ptr[mi_block_t]) -> u64;

def _mi_padding_shrink(page: ptr[mi_page_t], block: ptr[mi_block_t], min_size: u64);

def _mi_free_block_mt(page: ptr[mi_page_t], block: ptr[mi_block_t]);

def _mi_free_block(page: ptr[mi_page_t], local: bool, block: ptr[mi_block_t]);

def _mi_page_ptr_unalign(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], p: ptr[u8]
) -> ptr[mi_block_t];

def _mi_free_generic(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], is_local: bool, p: ptr[u8]
);

def mi_checked_ptr_segment(p: ptr[u8]) -> ptr[mi_segment_t];

def mi_alloc_free(p: ptr[u8]);

import from c {
    def mi_free(block: ptr) {
        mi_alloc_free(ptr[u8](block));
    }
}

def _mi_free_delayed_block(block: ptr[mi_block_t]) -> bool;

def mi_page_usable_aligned_size_of(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], p: ptr[u8]
) -> u64;

def _mi_usable_size(p: ptr[u8]) -> u64;

import from c {
    def mi_usable_size(p: ptr) -> u64 {
        return _mi_usable_size(ptr[u8](p));
    }  def mi_free_size(p: ptr, size: u64) {
        mi_alloc_free(ptr[u8](p));
    }  def mi_free_size_aligned(p: ptr, size: u64, alignment: u64) {
        mi_free_size(p, size);
    }  def mi_free_aligned(p: ptr, alignment: u64) {
        mi_alloc_free(ptr[u8](p));
    }
}

def mi_alloc_heap_calloc(heap: ptr[mi_heap_t], count: u64, size: u64) -> ptr[u8];

import from c {
    def mi_heap_calloc(heap: ptr, count: u64, size: u64) -> ptr {
        return ptr(mi_alloc_heap_calloc(ptr[mi_heap_t](heap), count, size));
    }  def mi_calloc(count: u64, size: u64) -> ptr {
        return ptr(mi_alloc_heap_calloc(mi_prim_get_default_heap(), count, size));
    }  def mi_heap_mallocn(heap: ptr, count: u64, size: u64) -> ptr {
        (overflow, total) = mi_count_size_overflow(count, size);
        if overflow {
            return ptr();
        }
        return ptr(_mi_heap_malloc_zero(ptr[mi_heap_t](heap), total, False));
    }  def mi_mallocn(count: u64, size: u64) -> ptr {
        return mi_heap_mallocn(ptr(mi_prim_get_default_heap()), count, size);
    }  def mi_expand(p: ptr, newsize: u64) -> ptr {
        if int(p) == 0 {
            return ptr();
        }
        size = _mi_usable_size(ptr[u8](p));
        if newsize > size {
            return ptr();
        }

        return p;
    }
}

def _mi_heap_realloc_zero(
    heap: ptr[mi_heap_t], p: ptr[u8], newsize: u64, zero: bool
) -> ptr[u8];

import from c {
    def mi_heap_realloc(heap: ptr, p: ptr, newsize: u64) -> ptr {
        return ptr(
            _mi_heap_realloc_zero(ptr[mi_heap_t](heap), ptr[u8](p), newsize, False)
        );
    }  def mi_heap_reallocn(heap: ptr, p: ptr, count: u64, size: u64) -> ptr {
        (overflow, total) = mi_count_size_overflow(count, size);
        if overflow {
            return ptr();
        }
        return mi_heap_realloc(heap, p, total);
    }  def mi_heap_reallocf(heap: ptr, p: ptr, newsize: u64) -> ptr {
        newp = mi_heap_realloc(heap, p, newsize);
        if int(newp) == 0 and int(p) != 0 {
            mi_alloc_free(ptr[u8](p));
        }
        return newp;
    }  def mi_heap_rezalloc(heap: ptr, p: ptr, newsize: u64) -> ptr {
        return ptr(
            _mi_heap_realloc_zero(ptr[mi_heap_t](heap), ptr[u8](p), newsize, True)
        );
    }  def mi_heap_recalloc(heap: ptr, p: ptr, newcount: u64, size: u64) -> ptr {
        (overflow, total) = mi_count_size_overflow(newcount, size);
        if overflow {
            return ptr();
        }
        return mi_heap_rezalloc(heap, p, total);
    }  def mi_realloc(block: ptr, newsize: u64) -> ptr {
        return ptr(
            _mi_heap_realloc_zero(
                mi_prim_get_default_heap(), ptr[u8](block), newsize, False
            )
        );
    }  def mi_reallocn(p: ptr, count: u64, size: u64) -> ptr {
        return mi_heap_reallocn(ptr(mi_prim_get_default_heap()), p, count, size);
    }  def mi_reallocf(p: ptr, newsize: u64) -> ptr {
        return mi_heap_reallocf(ptr(mi_prim_get_default_heap()), p, newsize);
    }  def mi_rezalloc(p: ptr, newsize: u64) -> ptr {
        return mi_heap_rezalloc(ptr(mi_prim_get_default_heap()), p, newsize);
    }  def mi_recalloc(p: ptr, newcount: u64, size: u64) -> ptr {
        return mi_heap_recalloc(ptr(mi_prim_get_default_heap()), p, newcount, size);
    }  def mi_heap_strdup(heap: ptr, s: ptr[u8]) -> ptr[u8] {
        if not s {
            return ptr[u8]();
        }
        n = strlen(s);
        t = ptr[u8](mi_heap_malloc(heap, wrapping_add(n, u64(1))));
        if not t {
            return ptr[u8]();
        }
        _mi_memcpy(ptr(t), ptr(s), n);
        (t + i64.wrap(n)).view(1)[0] = u8(0);
        return t;
    }  def mi_strdup(s: ptr[u8]) -> ptr[u8] {
        return mi_heap_strdup(ptr(mi_prim_get_default_heap()), s);
    }  def mi_heap_strndup(heap: ptr, s: ptr[u8], n: u64) -> ptr[u8] {
        if not s {
            return ptr[u8]();
        }

        end = memchr(ptr(s), 0, n);
        m = n;
        if int(end) != 0 {
            m = u64.wrap(int(end) - int(s));
        }
        t = ptr[u8](mi_heap_malloc(heap, wrapping_add(m, u64(1))));
        if not t {
            return ptr[u8]();
        }
        _mi_memcpy(ptr(t), ptr(s), m);
        (t + i64.wrap(m)).view(1)[0] = u8(0);
        return t;
    }  def mi_strndup(s: ptr[u8], n: u64) -> ptr[u8] {
        return mi_heap_strndup(ptr(mi_prim_get_default_heap()), s, n);
    }  def mi_heap_realpath(
        heap: ptr, fname: ptr[u8], resolved_name: ptr[u8]
    ) -> ptr[u8] {
        if resolved_name {
            return realpath(fname, resolved_name);
        }
        rname = realpath(fname, ptr[u8]());
        if not rname {
            return ptr[u8]();
        }
        result = mi_heap_strdup(heap, rname);

        free(ptr(rname));
        return result;
    }  def mi_realpath(fname: ptr[u8], resolved_name: ptr[u8]) -> ptr[u8] {
        return mi_heap_realpath(ptr(mi_prim_get_default_heap()), fname, resolved_name);
    }
}

def _Py__ZSt15get_new_handlerv -> ptr;

def mi_get_new_handler -> ptr;

def mi_try_new_handler(nothrow: bool) -> bool;

import from c {
    def mi_heap_try_new(heap: ptr, size: u64, nothrow: bool) -> ptr {
        p = ptr[u8]();
        while not p and mi_try_new_handler(nothrow) {
            p = ptr[u8](mi_heap_malloc(heap, size));
        }
        return ptr(p);
    }
}

def mi_try_new(size: u64, nothrow: bool) -> ptr;

import from c {
    def mi_heap_alloc_new(heap: ptr, size: u64) -> ptr {
        p = mi_heap_malloc(heap, size);
        if int(p) == 0 {
            return mi_heap_try_new(heap, size, False);
        }
        return p;
    }  def mi_new(size: u64) -> ptr {
        return mi_heap_alloc_new(ptr(mi_prim_get_default_heap()), size);
    }  def mi_heap_alloc_new_n(heap: ptr, count: u64, size: u64) -> ptr {
        (overflow, total) = mi_count_size_overflow(count, size);
        if overflow {
            mi_try_new_handler(False);
            return ptr();
        }
        return mi_heap_alloc_new(heap, total);
    }  def mi_new_n(count: u64, size: u64) -> ptr {
        return mi_heap_alloc_new_n(ptr(mi_prim_get_default_heap()), size, count);
    }  def mi_new_nothrow(size: u64) -> ptr {
        p = mi_malloc(size);
        if int(p) == 0 {
            return mi_try_new(size, True);
        }
        return p;
    }  def mi_new_aligned(size: u64, alignment: u64) -> ptr {
        p = mi_malloc_aligned(size, alignment);
        while int(p) == 0 and mi_try_new_handler(False) {
            p = mi_malloc_aligned(size, alignment);
        }
        return p;
    }  def mi_new_aligned_nothrow(size: u64, alignment: u64) -> ptr {
        p = mi_malloc_aligned(size, alignment);
        while int(p) == 0 and mi_try_new_handler(True) {
            p = mi_malloc_aligned(size, alignment);
        }
        return p;
    }  def mi_new_realloc(p: ptr, newsize: u64) -> ptr {
        q = mi_realloc(p, newsize);
        while int(q) == 0 and mi_try_new_handler(False) {
            q = mi_realloc(p, newsize);
        }
        return q;
    }  def mi_new_reallocn(p: ptr, newcount: u64, size: u64) -> ptr {
        (overflow, total) = mi_count_size_overflow(newcount, size);
        if overflow {
            mi_try_new_handler(False);
            return ptr();
        }
        return mi_new_realloc(p, total);
    }
}


glob:priv MI_ALLOC_ALIGNED_PTRDIFF_MAX: Final[u64] = u64(0x7FFFFFFFFFFFFFFF);

def mi_heap_malloc_zero_aligned_at_fallback(
    heap: ptr[mi_heap_t], size: u64, alignment: u64, offset: u64, zero: bool
) -> ptr[u8];

def mi_heap_malloc_zero_aligned_at(
    heap: ptr[mi_heap_t], size: u64, alignment: u64, offset: u64, zero: bool
) -> ptr[u8];

import from c {
    def mi_heap_malloc_aligned_at(
        heap: ptr, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        return ptr(
            mi_heap_malloc_zero_aligned_at(
                ptr[mi_heap_t](heap), size, alignment, offset, False
            )
        );
    }  def mi_heap_malloc_aligned(heap: ptr, size: u64, alignment: u64) -> ptr {
        if alignment == u64(0) or not _mi_is_power_of_two(alignment) {
            return ptr();
        }

        if _mi_is_power_of_two(size)
            and size >= alignment
            and size <= MI_SMALL_SIZE_MAX {
            return mi_heap_malloc_small(heap, size);
        }
        return mi_heap_malloc_aligned_at(heap, size, alignment, u64(0));
    }  def mi_heap_zalloc_aligned_at(
        heap: ptr, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        return ptr(
            mi_heap_malloc_zero_aligned_at(
                ptr[mi_heap_t](heap), size, alignment, offset, True
            )
        );
    }  def mi_heap_zalloc_aligned(heap: ptr, size: u64, alignment: u64) -> ptr {
        return mi_heap_zalloc_aligned_at(heap, size, alignment, u64(0));
    }  def mi_heap_calloc_aligned_at(
        heap: ptr, count: u64, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        (overflow, total) = mi_count_size_overflow(count, size);
        if overflow {
            return ptr();
        }
        return mi_heap_zalloc_aligned_at(heap, total, alignment, offset);
    }  def mi_heap_calloc_aligned(
        heap: ptr, count: u64, size: u64, alignment: u64
    ) -> ptr {
        return mi_heap_calloc_aligned_at(heap, count, size, alignment, u64(0));
    }  def mi_malloc_aligned_at(size: u64, alignment: u64, offset: u64) -> ptr {
        return mi_heap_malloc_aligned_at(
            ptr(mi_prim_get_default_heap()), size, alignment, offset
        );
    }  def mi_malloc_aligned(size: u64, alignment: u64) -> ptr {
        return mi_heap_malloc_aligned(ptr(mi_prim_get_default_heap()), size, alignment);
    }  def mi_zalloc_aligned_at(size: u64, alignment: u64, offset: u64) -> ptr {
        return mi_heap_zalloc_aligned_at(
            ptr(mi_prim_get_default_heap()), size, alignment, offset
        );
    }  def mi_zalloc_aligned(size: u64, alignment: u64) -> ptr {
        return mi_heap_zalloc_aligned(ptr(mi_prim_get_default_heap()), size, alignment);
    }  def mi_calloc_aligned_at(
        count: u64, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        return mi_heap_calloc_aligned_at(
            ptr(mi_prim_get_default_heap()), count, size, alignment, offset
        );
    }  def mi_calloc_aligned(count: u64, size: u64, alignment: u64) -> ptr {
        return mi_heap_calloc_aligned(
            ptr(mi_prim_get_default_heap()), count, size, alignment
        );
    }
}

def mi_heap_realloc_zero_aligned_at(
    heap: ptr[mi_heap_t],
    p: ptr[u8],
    newsize: u64,
    alignment: u64,
    offset: u64,
    zero: bool
) -> ptr[u8];

def mi_heap_realloc_zero_aligned(
    heap: ptr[mi_heap_t], p: ptr[u8], newsize: u64, alignment: u64, zero: bool
) -> ptr[u8];

import from c {
    def mi_heap_realloc_aligned_at(
        heap: ptr, p: ptr, newsize: u64, alignment: u64, offset: u64
    ) -> ptr {
        return ptr(
            mi_heap_realloc_zero_aligned_at(
                ptr[mi_heap_t](heap), ptr[u8](p), newsize, alignment, offset, False
            )
        );
    }  def mi_heap_realloc_aligned(
        heap: ptr, p: ptr, newsize: u64, alignment: u64
    ) -> ptr {
        return ptr(
            mi_heap_realloc_zero_aligned(
                ptr[mi_heap_t](heap), ptr[u8](p), newsize, alignment, False
            )
        );
    }  def mi_heap_rezalloc_aligned_at(
        heap: ptr, p: ptr, newsize: u64, alignment: u64, offset: u64
    ) -> ptr {
        return ptr(
            mi_heap_realloc_zero_aligned_at(
                ptr[mi_heap_t](heap), ptr[u8](p), newsize, alignment, offset, True
            )
        );
    }  def mi_heap_rezalloc_aligned(
        heap: ptr, p: ptr, newsize: u64, alignment: u64
    ) -> ptr {
        return ptr(
            mi_heap_realloc_zero_aligned(
                ptr[mi_heap_t](heap), ptr[u8](p), newsize, alignment, True
            )
        );
    }  def mi_heap_recalloc_aligned_at(
        heap: ptr, p: ptr, newcount: u64, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        (overflow, total) = mi_count_size_overflow(newcount, size);
        if overflow {
            return ptr();
        }
        return mi_heap_rezalloc_aligned_at(heap, p, total, alignment, offset);
    }  def mi_heap_recalloc_aligned(
        heap: ptr, p: ptr, newcount: u64, size: u64, alignment: u64
    ) -> ptr {
        (overflow, total) = mi_count_size_overflow(newcount, size);
        if overflow {
            return ptr();
        }
        return mi_heap_rezalloc_aligned(heap, p, total, alignment);
    }  def mi_realloc_aligned_at(
        p: ptr, newsize: u64, alignment: u64, offset: u64
    ) -> ptr {
        return mi_heap_realloc_aligned_at(
            ptr(mi_prim_get_default_heap()), p, newsize, alignment, offset
        );
    }  def mi_realloc_aligned(p: ptr, newsize: u64, alignment: u64) -> ptr {
        return mi_heap_realloc_aligned(
            ptr(mi_prim_get_default_heap()), p, newsize, alignment
        );
    }  def mi_rezalloc_aligned_at(
        p: ptr, newsize: u64, alignment: u64, offset: u64
    ) -> ptr {
        return mi_heap_rezalloc_aligned_at(
            ptr(mi_prim_get_default_heap()), p, newsize, alignment, offset
        );
    }  def mi_rezalloc_aligned(p: ptr, newsize: u64, alignment: u64) -> ptr {
        return mi_heap_rezalloc_aligned(
            ptr(mi_prim_get_default_heap()), p, newsize, alignment
        );
    }  def mi_recalloc_aligned_at(
        p: ptr, newcount: u64, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        return mi_heap_recalloc_aligned_at(
            ptr(mi_prim_get_default_heap()), p, newcount, size, alignment, offset
        );
    }  def mi_recalloc_aligned(
        p: ptr, newcount: u64, size: u64, alignment: u64
    ) -> ptr {
        return mi_heap_recalloc_aligned(
            ptr(mi_prim_get_default_heap()), p, newcount, size, alignment
        );
    }
}

import from c {
    def mi_malloc_size(p: ptr) -> u64 {
        return mi_usable_size(p);
    }  def mi_malloc_usable_size(p: ptr) -> u64 {
        return mi_usable_size(p);
    }  def mi_malloc_good_size(size: u64) -> u64 {
        return mi_good_size(size);
    }  def mi_cfree(p: ptr) {
        if mi_is_in_heap_region(p) {
            mi_free(p);
        }
    }  def mi_posix_memalign(p: ptr[ptr[u8]], alignment: u64, size: u64) -> i32 {
        if not p {
            return EINVAL;
        }

        if (alignment % MI_INTPTR_SIZE) != u64(0) {
            return EINVAL;
        }

        if alignment == u64(0) or not _mi_is_power_of_two(alignment) {
            return EINVAL;
        }
        q = mi_malloc_aligned(size, alignment);
        if int(q) == 0 and size != u64(0) {
            return ENOMEM;
        }
        p.view(1)[0] = ptr[u8](q);
        return 0;
    }  def mi_memalign(alignment: u64, size: u64) -> ptr {
        return mi_malloc_aligned(size, alignment);
    }  def mi_valloc(size: u64) -> ptr {
        return mi_memalign(_mi_os_page_size(), size);
    }  def mi_pvalloc(size: u64) -> ptr {
        psize = _mi_os_page_size();

        if size >= MI_SIZE_MAX - psize {
            return ptr();
        }
        asize = _mi_align_up(size, psize);
        return mi_malloc_aligned(asize, psize);
    }  def mi_aligned_alloc(alignment: u64, size: u64) -> ptr {
        return mi_malloc_aligned(size, alignment);
    }  def mi_reallocarray(p: ptr, count: u64, size: u64) -> ptr {
        newp = mi_reallocn(p, count, size);
        if int(newp) == 0 {
            jacpy_set_errno(i64(ENOMEM));
        }
        return newp;
    }  def mi_reallocarr(p: ptr, count: u64, size: u64) -> i32 {
        if int(p) == 0 {
            jacpy_set_errno(i64(EINVAL));
            return EINVAL;
        }
        op = ptr[ptr[u8]](p);
        newp = mi_reallocarray(ptr(op.view(1)[0]), count, size);
        if int(newp) == 0 {
            return i32.wrap(jacpy_errno());
        }
        op.view(1)[0] = ptr[u8](newp);
        return 0;
    }  def mi__expand(p: ptr, newsize: u64) -> ptr {
        res = mi_expand(p, newsize);
        if int(res) == 0 {
            jacpy_set_errno(i64(ENOMEM));
        }
        return res;
    }  def mi_wcsdup(s: ptr[u16]) -> ptr[u16] {
        if not s {
            return ptr[u16]();
        }
        n: i64 = 0;
        while (s + n).view(1)[0] != u16(0) {
            n = n + 1;
        }
        size = u64.wrap(n + 1) * u64(2);
        p = ptr[u16](mi_malloc(size));
        if p {
            _mi_memcpy(ptr(p), ptr(s), size);
        }
        return p;
    }  def mi_mbsdup(s: ptr[u8]) -> ptr[u8] {
        return mi_strdup(s);
    }  def mi_dupenv_s(buf: ptr[ptr[u8]], size: ptr[u64], name: ptr[u8]) -> i32 {
        if not buf {
            return EINVAL;
        }
        if not name {
            return EINVAL;
        }
        if size {
            size.view(1)[0] = u64(0);
        }
        p = getenv(name);
        if not p {
            buf.view(1)[0] = ptr[u8]();
        } else {
            t = mi_strdup(p);
            buf.view(1)[0] = t;
            if not t {
                return ENOMEM;
            }
            if size {
                size.view(1)[0] = _mi_strlen(p);
            }
        }
        return 0;
    }  def mi_wdupenv_s(buf: ptr[ptr[u16]], size: ptr[u64], name: ptr[u16]) -> i32 {
        if not buf {
            return EINVAL;
        }
        if not name {
            return EINVAL;
        }
        if size {
            size.view(1)[0] = u64(0);
        }

        buf.view(1)[0] = ptr[u16]();
        return EINVAL;
    }  def mi_aligned_offset_recalloc(
        p: ptr, newcount: u64, size: u64, alignment: u64, offset: u64
    ) -> ptr {
        return mi_recalloc_aligned_at(p, newcount, size, alignment, offset);
    }  def mi_aligned_recalloc(
        p: ptr, newcount: u64, size: u64, alignment: u64
    ) -> ptr {
        return mi_recalloc_aligned(p, newcount, size, alignment);
    }
}


glob:priv MI_ARENA_BLOCK_SIZE: Final[u64] = u64(33554432),
     MI_ARENA_MIN_OBJ_SIZE: Final[u64] = u64(16777216),
     MI_MAX_ARENAS: Final[u64] = u64(112),
     MI_ARENA_STATIC_MAX: Final[u64] = u64(8192);

glob:priv mi_arena_t_MEMID: Final[i64] = 8,
     mi_arena_t_START: Final[i64] = 32,
     mi_arena_t_META_MEMID: Final[i64] = 64,
     mi_arena_t_SEARCH_IDX: Final[i64] = 96,
     mi_arena_t_PURGE_EXPIRE: Final[i64] = 104,
     mi_arena_t_BLOCKS_INUSE: Final[i64] = 136,
     mi_arena_t_SIZE: Final[u64] = u64(144);

glob:priv mi_arena_state_ARENA_COUNT: Final[i64] = 0,
     mi_arena_state_STATIC_TOP: Final[i64] = 8,
     mi_arena_state_PURGE_GUARD: Final[i64] = 16;

import from c {
    obj mi_arena_t {
        has id: i32,
            pad0: u32,
            memid: mi_memid_t,
            start: u64,
            block_count: u64,
            field_count: u64,
            meta_size: u64,
            meta_memid: mi_memid_t,
            numa_node: i32,
            exclusive: bool,
            is_large: bool,
            pad1: u16,
            search_idx: u64,
            purge_expire: i64,
            blocks_dirty: ptr[u64],
            blocks_committed: ptr[u64],
            blocks_purge: ptr[u64],
            blocks_inuse: u64;
    }  obj MiArenaWords8 {
        has w0: u64,
            w1: u64,
            w2: u64,
            w3: u64,
            w4: u64,
            w5: u64,
            w6: u64,
            w7: u64;
    }  obj MiArenaWords64 {
        has w0: MiArenaWords8,
            w1: MiArenaWords8,
            w2: MiArenaWords8,
            w3: MiArenaWords8,
            w4: MiArenaWords8,
            w5: MiArenaWords8,
            w6: MiArenaWords8,
            w7: MiArenaWords8;
    }  obj MiArenaWords512 {
        has w0: MiArenaWords64,
            w1: MiArenaWords64,
            w2: MiArenaWords64,
            w3: MiArenaWords64,
            w4: MiArenaWords64,
            w5: MiArenaWords64,
            w6: MiArenaWords64,
            w7: MiArenaWords64;
    }  obj MiArenaPtrs112 {
        has a0: MiArenaWords64,
            a1: MiArenaWords8,
            a2: MiArenaWords8,
            a3: MiArenaWords8,
            a4: MiArenaWords8,
            a5: MiArenaWords8,
            a6: MiArenaWords8;
    }  obj MiArenaStatic8K {
        has b0: MiArenaWords512,
            b1: MiArenaWords512;
    }  obj MiArenaState {
        has arena_count: u64,
            static_top: u64,
            purge_guard: u64;
    }
}

import from c {
    glob:priv mi_arenas: MiArenaPtrs112 = MiArenaPtrs112(); glob:priv mi_arena_static:
             MiArenaStatic8K = MiArenaStatic8K(); glob:priv mi_arena_state:
             MiArenaState = MiArenaState();
}

def mi_arenas_slot(i: u64) -> ptr[u64];

def mi_arenas_load_acquire(i: u64) -> ptr[mi_arena_t];

def mi_arena_count_addr -> ptr[u64];

def mi_arena_static_top_addr -> ptr[u64];

def mi_arena_purge_guard_addr -> ptr[u64];

def mi_arena_memid_of(arena: ptr[mi_arena_t]) -> ptr[mi_memid_t];

def mi_arena_meta_memid_of(arena: ptr[mi_arena_t]) -> ptr[mi_memid_t];

def mi_arena_start_addr(arena: ptr[mi_arena_t]) -> ptr[u64];

def mi_arena_search_idx_addr(arena: ptr[mi_arena_t]) -> ptr[u64];

def mi_arena_purge_expire_addr(arena: ptr[mi_arena_t]) -> ptr[i64];

def mi_arena_start_of(arena: ptr[mi_arena_t]) -> ptr[u8];

def mi_arena_blocks_inuse_of(arena: ptr[mi_arena_t]) -> ptr[u64];

def mi_arena_id_index(id: i32) -> u64;

def mi_arena_id_create(arena_index: u64) -> i32;

def _mi_arena_id_none -> i32;

def mi_arena_id_is_suitable(
    arena_id: i32, arena_is_exclusive: bool, req_arena_id: i32
) -> bool;

def _mi_arena_memid_is_suitable(memid: ptr[mi_memid_t], request_arena_id: i32) -> bool;

def _mi_arena_memid_is_os_allocated(memid: ptr[mi_memid_t]) -> bool;

def mi_block_count_of_size(size: u64) -> u64;

def mi_arena_block_size(bcount: u64) -> u64;

def mi_arena_size(arena: ptr[mi_arena_t]) -> u64;

def mi_memid_create_arena(
    memid: ptr[mi_memid_t], id: i32, is_exclusive: bool, bitmap_index: u64
);

def mi_arena_memid_indices(memid: ptr[mi_memid_t]) -> tuple[bool, u64, u64];

def mi_arena_static_zalloc(
    size: u64, alignment: u64, memid: ptr[mi_memid_t]
) -> ptr[u8];

def mi_arena_meta_zalloc(
    size: u64, memid: ptr[mi_memid_t], stats: ptr[mi_stats_t]
) -> ptr[u8];

def mi_arena_meta_free(
    p: ptr[u8], memid: ptr[mi_memid_t], size: u64, stats: ptr[mi_stats_t]
);

def mi_arena_block_start(arena: ptr[mi_arena_t], bindex: u64) -> ptr[u8];

def mi_arena_try_claim(arena: ptr[mi_arena_t], blocks: u64) -> tuple[bool, u64];

def mi_arena_try_alloc_at(
    arena: ptr[mi_arena_t],
    arena_index: u64,
    needed_bcount: u64,
    commit: bool,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8];

def mi_arena_try_alloc_at_id(
    arena_id: i32,
    match_numa_node: bool,
    numa_node: i32,
    size: u64,
    alignment: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8];

def mi_arena_try_alloc(
    numa_node: i32,
    size: u64,
    alignment: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8];

def mi_arena_reserve(
    req_size: u64, allow_large: bool, req_arena_id: i32
) -> tuple[bool, i32];

def _mi_arena_alloc_aligned(
    size: u64,
    alignment: u64,
    align_offset: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8];

def _mi_arena_alloc(
    size: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8];

import from c {
    def mi_arena_area(arena_id: i32, size: ptr[u64]) -> ptr {
        if size {
            size.view(1)[0] = u64(0);
        }
        arena_index = mi_arena_id_index(arena_id);
        if arena_index >= MI_MAX_ARENAS {
            return ptr();
        }
        arena = mi_arenas_load_acquire(arena_index);
        if not arena {
            return ptr();
        }
        if size {
            size.view(1)[0] = mi_arena_block_size(arena.view(1)[0].block_count);
        }
        return ptr(mi_arena_start_of(arena));
    }
}

def mi_arena_purge_delay -> i64;

def mi_arena_purge(
    arena: ptr[mi_arena_t], bitmap_idx: u64, blocks: u64, stats: ptr[mi_stats_t]
);

def mi_arena_schedule_purge(
    arena: ptr[mi_arena_t], bitmap_idx: u64, blocks: u64, stats: ptr[mi_stats_t]
);

def mi_arena_purge_range(
    arena: ptr[mi_arena_t],
    idx: u64,
    startidx: u64,
    bitlen: u64,
    purge: u64,
    stats: ptr[mi_stats_t]
) -> bool;

def mi_arena_try_purge(
    arena: ptr[mi_arena_t], now: i64, force: bool, stats: ptr[mi_stats_t]
) -> bool;

def mi_arenas_try_purge(force: bool, visit_all: bool, stats: ptr[mi_stats_t]);

def _mi_arena_free(
    p: ptr[u8],
    size: u64,
    still_committed_size: u64,
    memid: ptr[mi_memid_t],
    stats: ptr[mi_stats_t]
);

def mi_arenas_unsafe_destroy;

def _mi_arena_collect(force_purge: bool, stats: ptr[mi_stats_t]);

def _mi_arena_unsafe_destroy_all(stats: ptr[mi_stats_t]);

def _mi_arena_contains(p: ptr[u8]) -> bool;

def mi_arena_add(arena: ptr[mi_arena_t]) -> tuple[bool, i32];

def mi_manage_os_memory_ex2(
    start: ptr[u8],
    size: u64,
    is_large: bool,
    numa_node: i32,
    exclusive: bool,
    memid: ptr[mi_memid_t]
) -> tuple[bool, i32];

import from c {
    def mi_manage_os_memory_ex(
        start: ptr,
        size: u64,
        is_committed: bool,
        is_large: bool,
        is_zero: bool,
        numa_node: i32,
        exclusive: bool,
        arena_id: ptr[i32]
    ) -> bool {
        slots: own MiStack = MiStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        memid = ptr[mi_memid_t](base);
        mi_memid_init(memid, MI_MEM_EXTERNAL);
        memid.view(1)[0].initially_committed = is_committed;
        memid.view(1)[0].initially_zero = is_zero;
        memid.view(1)[0].is_pinned = is_large;
        (added, id) = mi_manage_os_memory_ex2(
            ptr[u8](start), size, is_large, numa_node, exclusive, memid
        );
        if arena_id {
            arena_id.view(1)[0] = id;
        }
        return added;
    }
}

def mi_arena_reserve_os_memory(
    size: u64, commit: bool, allow_large: bool, exclusive: bool
) -> tuple[i32, i32];

import from c {
    def mi_reserve_os_memory_ex(
        size: u64, commit: bool, allow_large: bool, exclusive: bool, arena_id: ptr[i32]
    ) -> i32 {
        (err, id) = mi_arena_reserve_os_memory(size, commit, allow_large, exclusive);
        if arena_id {
            arena_id.view(1)[0] = id;
        }
        return err;
    }  def mi_manage_os_memory(
        start: ptr,
        size: u64,
        is_committed: bool,
        is_large: bool,
        is_zero: bool,
        numa_node: i32
    ) -> bool {
        return mi_manage_os_memory_ex(
            start, size, is_committed, is_large, is_zero, numa_node, False, ptr[i32]()
        );
    }  def mi_reserve_os_memory(size: u64, commit: bool, allow_large: bool) -> i32 {
        return mi_reserve_os_memory_ex(size, commit, allow_large, False, ptr[i32]());
    }
}

def mi_debug_show_bitmap(prefix: ptr[u8], fields: ptr[u64], field_count: u64) -> u64;

import from c {
    def mi_debug_show_arenas {
        max_arenas = mi_atomic_load_relaxed(mi_arena_count_addr());
        i: u64 = 0;
        while i < max_arenas {
            arena = ptr[mi_arena_t](
                i64.wrap(mi_atomic_load_relaxed(mi_arenas_slot(i)))
            );
            if not arena {
                break;
            }
            inuse_count: u64 = 0;
            _mi_verbose_message(
                ptr[u8]("arena %zu: %zu blocks with %zu fields\n"),
                i,
                arena.view(1)[0].block_count,
                arena.view(1)[0].field_count,
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            inuse_count = inuse_count
                + mi_debug_show_bitmap(
                    ptr[u8]("  "),
                    mi_arena_blocks_inuse_of(arena),
                    arena.view(1)[0].field_count
                );
            _mi_verbose_message(
                ptr[u8]("  blocks in use ('x'): %zu\n"),
                inuse_count,
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            i = i + u64(1);
        }
    }  def mi_reserve_huge_os_pages_at_ex(
        pages: u64,
        numa_node: i32,
        timeout_msecs: u64,
        exclusive: bool,
        arena_id: ptr[i32]
    ) -> i32 {
        if arena_id {
            arena_id.view(1)[0] = i32(-1);
        }
        if pages == u64(0) {
            return i32(0);
        }
        numa = numa_node;
        if numa < -1 {
            numa = i32(-1);
        }
        if numa >= 0 {
            numa = i32.wrap(u64(numa) % _mi_os_numa_node_count());
        }
        slots: own MiStack = MiStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        memid = ptr[mi_memid_t](base);
        (p, pages_reserved, hsize) = _mi_os_alloc_huge_os_pages(
            pages, numa, i64.wrap(timeout_msecs), memid
        );
        if not p or pages_reserved == u64(0) {
            _mi_warning_message(
                ptr[u8]("failed to reserve %zu GiB huge pages\n"),
                pages,
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            return ENOMEM;
        }
        _mi_verbose_message(
            ptr[u8](
                "numa node %i: reserved %zu GiB huge pages (of the %zu GiB requested)\n"
            ),
            u64.wrap(i64(numa)),
            pages_reserved,
            pages,
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        (added, id) = mi_manage_os_memory_ex2(p, hsize, True, numa, exclusive, memid);
        if arena_id {
            arena_id.view(1)[0] = id;
        }
        if not added {
            _mi_os_free(p, hsize, memid, addressof(_mi_stats_main));
            return ENOMEM;
        }
        return i32(0);
    }  def mi_reserve_huge_os_pages_at(
        pages: u64, numa_node: i32, timeout_msecs: u64
    ) -> i32 {
        return mi_reserve_huge_os_pages_at_ex(
            pages, numa_node, timeout_msecs, False, ptr[i32]()
        );
    }  def mi_reserve_huge_os_pages_interleave(
        pages: u64, numa_nodes: u64, timeout_msecs: u64
    ) -> i32 {
        if pages == u64(0) {
            return i32(0);
        }

        numa_count = numa_nodes;
        if numa_count == u64(0) {
            numa_count = _mi_os_numa_node_count();
        }
        if numa_count <= u64(0) {
            numa_count = u64(1);
        }
        pages_per = pages // numa_count;
        pages_mod = pages % numa_count;
        timeout_per = u64(0);
        if timeout_msecs != u64(0) {
            timeout_per = (timeout_msecs // numa_count) + u64(50);
        }

        left = pages;
        numa_node: u64 = 0;
        while numa_node < numa_count and left > u64(0) {
            node_pages = pages_per;
            if numa_node < pages_mod {
                node_pages = node_pages + u64(1);
            }
            err = mi_reserve_huge_os_pages_at(
                node_pages, i32.wrap(numa_node), timeout_per
            );
            if err != 0 {
                return err;
            }
            if left < node_pages {
                left = u64(0);
            } else {
                left = left - node_pages;
            }
            numa_node = numa_node + u64(1);
        }
        return i32(0);
    }  def mi_reserve_huge_os_pages(
        pages: u64, max_secs: f64, pages_reserved: ptr[u64]
    ) -> i32 {
        _mi_warning_message(
            ptr[u8](
                "mi_reserve_huge_os_pages is deprecated: use mi_reserve_huge_os_pages_interleave/at instead\n"
            ),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        if pages_reserved {
            pages_reserved.view(1)[0] = u64(0);
        }
        err = mi_reserve_huge_os_pages_interleave(
            pages, u64(0), u64.wrap(i64(max_secs * 1000.0))
        );
        if err == 0 and pages_reserved {
            pages_reserved.view(1)[0] = pages;
        }
        return err;
    }
}


glob:priv MI_BITMAP_FIELD_BITS: Final[u64] = u64(64),
     MI_BITMAP_FIELD_FULL: Final[u64] = u64(0xFFFFFFFFFFFFFFFF);

def mi_bitmap_index_create(idx: u64, bitidx: u64) -> u64;

def mi_bitmap_index_create_from_bit(full_bitidx: u64) -> u64;

def mi_bitmap_index_field(bitmap_idx: u64) -> u64;

def mi_bitmap_index_bit_in_field(bitmap_idx: u64) -> u64;

def mi_bitmap_index_bit(bitmap_idx: u64) -> u64;

def mi_bitmap_mask_(count: u64, bitidx: u64) -> u64;

def _mi_bitmap_try_find_claim_field(
    bitmap: ptr[u64], idx: u64, count: u64
) -> tuple[bool, u64];

def _mi_bitmap_try_find_from_claim(
    bitmap: ptr[u64], bitmap_fields: u64, start_field_idx: u64, count: u64
) -> tuple[bool, u64];

def _mi_bitmap_try_find_from_claim_pred(
    bitmap: ptr[u64],
    bitmap_fields: u64,
    start_field_idx: u64,
    count: u64,
    pred_fun: ptr,
    pred_arg: ptr
) -> tuple[bool, u64];

def _mi_bitmap_unclaim(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;

def _mi_bitmap_claim(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool];

def mi_bitmap_is_claimedx(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool];

def _mi_bitmap_try_claim(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;

def _mi_bitmap_is_claimed(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;

def _mi_bitmap_is_any_claimed(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;

def mi_bitmap_try_find_claim_field_across(
    bitmap: ptr[u64], bitmap_fields: u64, idx: u64, count: u64, retries: u64
) -> tuple[bool, u64];

def _mi_bitmap_try_find_from_claim_across(
    bitmap: ptr[u64], bitmap_fields: u64, start_field_idx: u64, count: u64
) -> tuple[bool, u64];

def mi_bitmap_mask_across(
    bitmap_idx: u64, bitmap_fields: u64, count: u64
) -> tuple[u64, u64, u64, u64];

def _mi_bitmap_unclaim_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;

def _mi_bitmap_claim_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool];

def mi_bitmap_is_claimedx_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool];

def _mi_bitmap_is_claimed_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;

def _mi_bitmap_is_any_claimed_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool;


glob:priv MI_NORMAL: Final[i32] = 0,
     MI_FORCE: Final[i32] = 1,
     MI_ABANDON: Final[i32] = 2;

import from c {
    obj mi_visit_blocks_args_t {
        has visit_blocks: bool,
            pad0: u8,
            pad1: u16,
            pad2: u32,
            visit_fn: ptr[u8],
            arg: ptr[u8];
    }
}

def mi_heap_visit_pages(heap: ptr[mi_heap_t], fun: ptr, arg1: ptr, arg2: ptr) -> bool;

def mi_heap_page_collect(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg_collect: ptr,
    arg2: ptr
) -> u8;

def mi_heap_page_never_delayed_free(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg1: ptr,
    arg2: ptr
) -> u8;

def mi_heap_collect_ex(heap: ptr[mi_heap_t], collect: i32);

def _mi_heap_collect_abandon(heap: ptr[mi_heap_t]);

import from c {
    def mi_heap_collect(heap: ptr, force: bool) {
        if force {
            mi_heap_collect_ex(ptr[mi_heap_t](heap), MI_FORCE);
        } else {
            mi_heap_collect_ex(ptr[mi_heap_t](heap), MI_NORMAL);
        }
    }  def mi_collect(force: bool) {
        mi_heap_collect(ptr(mi_prim_get_default_heap()), force);
    }  def mi_heap_get_default -> ptr {
        mi_thread_init();
        return ptr(mi_prim_get_default_heap());
    }
}

def mi_heap_is_default(heap: ptr[mi_heap_t]) -> bool;

import from c {
    def mi_heap_get_backing -> ptr {
        heap = ptr[mi_heap_t](mi_heap_get_default());

        bheap = heap.view(1)[0].tld.view(1)[0].heap_backing;

        return ptr(bheap);
    }
}

def _mi_heap_init_ex(
    heap: ptr[mi_heap_t], tld: ptr[mi_tld_t], arena_id: i32, no_reclaim: bool, tag: u8
);

import from c {
    def mi_heap_new_in_arena(arena_id: i32) -> ptr {
        bheap = ptr[mi_heap_t](mi_heap_get_backing());

        heap = ptr[mi_heap_t](mi_heap_malloc(ptr(bheap), mi_heap_t_SIZE));
        if not heap {
            return ptr();
        }

        _mi_heap_init_ex(heap, bheap.view(1)[0].tld, arena_id, True, u8(0));
        return ptr(heap);
    }  def mi_heap_new -> ptr {
        return mi_heap_new_in_arena(_mi_arena_id_none());
    }
}

def _mi_heap_memid_is_suitable(heap: ptr[mi_heap_t], memid: ptr[mi_memid_t]) -> bool;

def _mi_heap_random_next(heap: ptr[mi_heap_t]) -> u64;

def mi_heap_reset_pages(heap: ptr[mi_heap_t]);

def mi_heap_free(heap: ptr[mi_heap_t]);

def _mi_heap_page_destroy(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg1: ptr,
    arg2: ptr
) -> u8;

def _mi_heap_destroy_pages(heap: ptr[mi_heap_t]);

import from c {
    def mi_heap_destroy(heap: ptr) {
        h = ptr[mi_heap_t](heap);

        if not h {
            return;
        }
        if not mi_heap_is_initialized(h) {
            return;
        }
        if not h.view(1)[0].no_reclaim {
            mi_heap_delete(heap);
        } else {
            _mi_heap_destroy_pages(h);
            mi_heap_free(h);
        }
    }
}

def _mi_heap_unsafe_destroy_all;

def mi_heap_absorb(heap: ptr[mi_heap_t], from_heap: ptr[mi_heap_t]);

import from c {
    def mi_heap_delete(heap: ptr) {
        h = ptr[mi_heap_t](heap);

        if not h {
            return;
        }
        if not mi_heap_is_initialized(h) {
            return;
        }
        if not mi_heap_is_backing(h) {
            mi_heap_absorb(h.view(1)[0].tld.view(1)[0].heap_backing, h);
        } else {
            _mi_heap_collect_abandon(h);
        }

        mi_heap_free(h);
    }  def mi_heap_set_default(heap: ptr) -> ptr {
        h = ptr[mi_heap_t](heap);
        if not h {
            return ptr();
        }
        if not mi_heap_is_initialized(h) {
            return ptr();
        }
        old = mi_prim_get_default_heap();
        _mi_heap_set_default_direct(h);
        return ptr(old);
    }
}

def mi_heap_of_block(p: ptr[u8]) -> ptr[mi_heap_t];

import from c {
    def mi_heap_contains_block(heap: ptr, p: ptr) -> bool {
        h = ptr[mi_heap_t](heap);

        if not h {
            return False;
        }
        if not mi_heap_is_initialized(h) {
            return False;
        }
        return h == mi_heap_of_block(ptr[u8](p));
    }
}

def mi_heap_page_check_owned(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    p: ptr,
    vfound: ptr
) -> u8;

import from c {
    def mi_heap_check_owned(heap: ptr, p: ptr) -> bool {
        h = ptr[mi_heap_t](heap);

        if not h {
            return False;
        }
        if not mi_heap_is_initialized(h) {
            return False;
        }

        if (u64.wrap(int(p)) & (MI_INTPTR_SIZE - u64(1))) != u64(0) {
            return False;
        }
        slots: own MiStack = MiStack();
        found = ptr[u8](jacpy_stack_address(&mut slots));
        found.view(1)[0] = u8(0);
        mi_heap_visit_pages(h, ptr(mi_heap_page_check_owned), p, ptr(found));
        return found.view(1)[0] != u8(0);
    }  def mi_check_owned(p: ptr) -> bool {
        return mi_heap_check_owned(ptr(mi_prim_get_default_heap()), p);
    }
}

def mi_fast_divisor(divisor: u64) -> tuple[u64, u64];

def mi_fast_divide(n: u64, magic: u64, shift: u64) -> u64;

def mi_heap_free_map_word(lo: ptr[u64], hi: ptr[u64], i: u64) -> ptr[u64];

def _mi_heap_area_visit_blocks(
    area: ptr[mi_heap_area_t], page: ptr[mi_page_t], visit_fn: ptr, arg: ptr
) -> bool;

def _mi_heap_area_init(area: ptr[mi_heap_area_t], page: ptr[mi_page_t]);

def mi_heap_visit_areas_page(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    vfun: ptr,
    arg: ptr
) -> u8;

def mi_heap_visit_areas(heap: ptr[mi_heap_t], visit_fn: ptr, arg: ptr) -> bool;

def mi_heap_area_visitor(
    heap: ptr[mi_heap_t], xarea: ptr[mi_heap_area_ex_t], arg: ptr
) -> u8;

import from c {
    def mi_heap_visit_blocks(
        heap: ptr, visit_all_blocks: bool, visit_fn: ptr, arg: ptr
    ) -> bool {
        slots: own MiStack = MiStack();
        args = ptr[mi_visit_blocks_args_t](jacpy_stack_address(&mut slots));
        args.view(1)[0].visit_blocks = visit_all_blocks;
        args.view(1)[0].visit_fn = ptr[u8](visit_fn);
        args.view(1)[0].arg = ptr[u8](arg);
        h = ptr[mi_heap_t](heap);
        _mi_heap_delayed_free_partial(h);
        return mi_heap_visit_areas(h, ptr(mi_heap_area_visitor), ptr(args));
    }
}


glob:priv TD_CACHE_SIZE: Final[i64] = 16;

glob:priv mi_thread_data_t_TLD: Final[i64] = 3064,
     mi_thread_data_t_MEMID: Final[i64] = 4672,
     mi_thread_data_t_SIZE: Final[u64] = u64(4696);

glob:priv MiInitStatics_THREAD_COUNT: Final[i64] = 0,
     MiInitStatics_PROCESS_LOAD: Final[i64] = 8,
     MiInitStatics_PROCESS_INIT: Final[i64] = 16;

import from c {
    obj mi_thread_data_t {
        has heap: mi_heap_t,
            tld: mi_tld_t,
            memid: mi_memid_t;
    }  obj MiInitStatics {
        has thread_count: u64,
            process_load: u64,
            process_init: u64,
            os_preloading: bool,
            mi_redirected: bool,
            process_done: bool,
            tls_initialized: bool,
            pad0: u32;
    }  glob:priv mi_init_statics: MiInitStatics = MiInitStatics(
             thread_count=u64(1), os_preloading=True
         ); glob:priv td_cache: list[u64] = [
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0),
             u64(0)
         ];
}

def mi_init_statics_word(ofs: i64) -> ptr[u64];

def mi_init_td_cache_slot(i: i64) -> ptr[u64];

def mi_thread_data_heap(td: ptr[mi_thread_data_t]) -> ptr[mi_heap_t];

def mi_thread_data_tld(td: ptr[mi_thread_data_t]) -> ptr[mi_tld_t];

def mi_thread_data_memid(td: ptr[mi_thread_data_t]) -> ptr[mi_memid_t];

def _mi_thread_id -> u64;

def mi_heap_main_init;

def _mi_heap_main_get -> ptr[mi_heap_t];

def mi_thread_data_zalloc -> ptr[mi_thread_data_t];

def mi_thread_data_free(tdfree: ptr[mi_thread_data_t]);

def _mi_thread_data_collect;

def _mi_heap_init -> bool;

def _mi_tld_init(tld: ptr[mi_tld_t], bheap: ptr[mi_heap_t]);

def _mi_heap_done(heap: ptr[mi_heap_t]) -> bool;

def mi_process_setup_auto_thread_done;

def _mi_is_main_thread -> bool;

def _mi_current_thread_count -> u64;

def _mi_thread_done(heap: ptr[mi_heap_t]);

def _mi_heap_set_default_direct(heap: ptr[mi_heap_t]);

def _mi_preloading -> bool;

def mi_allocator_init -> tuple[bool, ptr[u8]];

def mi_allocator_done;

def mi_process_load;

def mi_detect_cpu_features;

def mi_process_done;

import from c {
    def mi_thread_init {
        mi_process_init();

        if _mi_heap_init() {
            return;
        }
        _mi_stat_increase(
            mi_stat_count_at(addressof(_mi_stats_main), mi_stats_t_THREADS), u64(1)
        );
        mi_atomic_increment_relaxed(mi_init_statics_word(MiInitStatics_THREAD_COUNT));
    }  def mi_thread_done {
        _mi_thread_done(ptr[mi_heap_t]());
    }  def mi_is_redirected -> bool {
        return addressof(mi_init_statics).view(1)[0].mi_redirected;
    }  def mi_process_init {
        if mi_atomic_once(mi_init_statics_word(MiInitStatics_PROCESS_LOAD)) {
            mi_process_load();
            return;
        }

        if not mi_atomic_once(mi_init_statics_word(MiInitStatics_PROCESS_INIT)) {
            return;
        }
        addressof(mi_globals).view(1)[0].process_is_initialized = True;
        _mi_verbose_message(
            ptr[u8]("process init: 0x%zx\n"),
            _mi_thread_id(),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        mi_process_setup_auto_thread_done();
        mi_detect_cpu_features();
        _mi_os_init();
        mi_heap_main_init();

        _mi_verbose_message(
            ptr[u8]("secure level: %d\n"),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );

        _mi_verbose_message(
            ptr[u8]("mem tracking: %s\n"),
            u64.wrap(int(ptr[u8]("none"))),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        mi_thread_init();

        mi_stats_reset();
        if mi_option_is_enabled(mi_option_reserve_huge_os_pages) {
            pages = u64.wrap(
                mi_option_get_clamp(
                    mi_option_reserve_huge_os_pages, i64(0), i64(131072)
                )
            );
            reserve_at = mi_option_get(mi_option_reserve_huge_os_pages_at);
            if reserve_at != i64(-1) {
                mi_reserve_huge_os_pages_at(
                    pages, i32.wrap(reserve_at), pages * u64(500)
                );
            } else {
                mi_reserve_huge_os_pages_interleave(pages, u64(0), pages * u64(500));
            }
        }
        if mi_option_is_enabled(mi_option_reserve_os_memory) {
            ksize = mi_option_get(mi_option_reserve_os_memory);
            if ksize > i64(0) {
                mi_reserve_os_memory(wrapping_mul(u64.wrap(ksize), MI_KiB), True, True);
            }
        }
    }
}


glob:priv UNINIT: Final[i32] = 0,
     DEFAULTED: Final[i32] = 1,
     INITIALIZED: Final[i32] = 2;

glob:priv MI_MAX_DELAY_OUTPUT: Final[u64] = u64(32768);

glob:priv MiOptionsStatics_OUT_LEN: Final[i64] = 16,
     MiOptionsStatics_OUT_ARG: Final[i64] = 32,
     MiOptionsStatics_ERROR_COUNT: Final[i64] = 40,
     MiOptionsStatics_WARNING_COUNT: Final[i64] = 48,
     MiOptionsStatics_ERROR_ARG: Final[i64] = 64;

import from c {
    obj mi_option_desc_t {
        has value: i64 = 0,
            init_: i32 = 0,
            option: i32 = 0,
            name: ptr[u8] = ptr[u8](),
            legacy_name: ptr[u8] = ptr[u8]();
    }  obj MiOptionsStatics {
        has mi_max_error_count: i64,
            mi_max_warning_count: i64,
            out_len: u64,
            mi_out_default: u64,
            mi_out_arg: u64,
            error_count: u64,
            warning_count: u64,
            mi_error_handler: u64,
            mi_error_arg: u64;
    }  obj MiOptionsWords8 {
        has w0: u64,
            w1: u64,
            w2: u64,
            w3: u64,
            w4: u64,
            w5: u64,
            w6: u64,
            w7: u64;
    }  obj MiOptionsWords64 {
        has w0: MiOptionsWords8,
            w1: MiOptionsWords8,
            w2: MiOptionsWords8,
            w3: MiOptionsWords8,
            w4: MiOptionsWords8,
            w5: MiOptionsWords8,
            w6: MiOptionsWords8,
            w7: MiOptionsWords8;
    }  obj MiOptionsWords512 {
        has w0: MiOptionsWords64,
            w1: MiOptionsWords64,
            w2: MiOptionsWords64,
            w3: MiOptionsWords64,
            w4: MiOptionsWords64,
            w5: MiOptionsWords64,
            w6: MiOptionsWords64,
            w7: MiOptionsWords64;
    }  obj MiOptionsWords4096 {
        has w0: MiOptionsWords512,
            w1: MiOptionsWords512,
            w2: MiOptionsWords512,
            w3: MiOptionsWords512,
            w4: MiOptionsWords512,
            w5: MiOptionsWords512,
            w6: MiOptionsWords512,
            w7: MiOptionsWords512;
    }  obj MiOptionsOutBuf {
        has words: MiOptionsWords4096,
            tail: u64;
    }  glob:priv mi_options_statics: MiOptionsStatics = MiOptionsStatics(
             mi_max_error_count=i64(16), mi_max_warning_count=i64(16)
         ); glob:priv out_buf: MiOptionsOutBuf = MiOptionsOutBuf(); glob:priv options:
             list[mi_option_desc_t] = [
             mi_option_desc_t(
                 value=i64(0), option=mi_option_show_errors, name=ptr[u8]("show_errors")
             ),
             mi_option_desc_t(
                 value=i64(0), option=mi_option_show_stats, name=ptr[u8]("show_stats")
             ),
             mi_option_desc_t(
                 value=i64(0), option=mi_option_verbose, name=ptr[u8]("verbose")
             ),
             mi_option_desc_t(
                 value=i64(1),
                 option=mi_option_eager_commit,
                 name=ptr[u8]("eager_commit")
             ),
             mi_option_desc_t(
                 value=i64(2),
                 option=mi_option_arena_eager_commit,
                 name=ptr[u8]("arena_eager_commit"),
                 legacy_name=ptr[u8]("eager_region_commit")
             ),
             mi_option_desc_t(
                 value=i64(1),
                 option=mi_option_purge_decommits,
                 name=ptr[u8]("purge_decommits"),
                 legacy_name=ptr[u8]("reset_decommits")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_allow_large_os_pages,
                 name=ptr[u8]("allow_large_os_pages"),
                 legacy_name=ptr[u8]("large_os_pages")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_reserve_huge_os_pages,
                 name=ptr[u8]("reserve_huge_os_pages")
             ),
             mi_option_desc_t(
                 value=i64(-1),
                 option=mi_option_reserve_huge_os_pages_at,
                 name=ptr[u8]("reserve_huge_os_pages_at")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_reserve_os_memory,
                 name=ptr[u8]("reserve_os_memory")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_deprecated_segment_cache,
                 name=ptr[u8]("deprecated_segment_cache")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_deprecated_page_reset,
                 name=ptr[u8]("deprecated_page_reset")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_abandoned_page_purge,
                 name=ptr[u8]("abandoned_page_purge"),
                 legacy_name=ptr[u8]("abandoned_page_reset")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_deprecated_segment_reset,
                 name=ptr[u8]("deprecated_segment_reset")
             ),
             mi_option_desc_t(
                 value=i64(1),
                 option=mi_option_eager_commit_delay,
                 name=ptr[u8]("eager_commit_delay")
             ),
             mi_option_desc_t(
                 value=i64(10),
                 option=mi_option_purge_delay,
                 name=ptr[u8]("purge_delay"),
                 legacy_name=ptr[u8]("reset_delay")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_use_numa_nodes,
                 name=ptr[u8]("use_numa_nodes")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_limit_os_alloc,
                 name=ptr[u8]("limit_os_alloc")
             ),
             mi_option_desc_t(
                 value=i64(100), option=mi_option_os_tag, name=ptr[u8]("os_tag")
             ),
             mi_option_desc_t(
                 value=i64(16), option=mi_option_max_errors, name=ptr[u8]("max_errors")
             ),
             mi_option_desc_t(
                 value=i64(16),
                 option=mi_option_max_warnings,
                 name=ptr[u8]("max_warnings")
             ),
             mi_option_desc_t(
                 value=i64(8),
                 option=mi_option_max_segment_reclaim,
                 name=ptr[u8]("max_segment_reclaim")
             ),
             mi_option_desc_t(
                 value=i64(0),
                 option=mi_option_destroy_on_exit,
                 name=ptr[u8]("destroy_on_exit")
             ),
             mi_option_desc_t(
                 value=i64(1048576),
                 option=mi_option_arena_reserve,
                 name=ptr[u8]("arena_reserve")
             ),
             mi_option_desc_t(
                 value=i64(10),
                 option=mi_option_arena_purge_mult,
                 name=ptr[u8]("arena_purge_mult")
             ),
             mi_option_desc_t(
                 value=i64(1),
                 option=mi_option_purge_extend_delay,
                 name=ptr[u8]("purge_extend_delay"),
                 legacy_name=ptr[u8]("decommit_extend_delay")
             )
         ];
}

def mi_options_desc(option: i32) -> ptr[mi_option_desc_t];

def mi_options_statics_word(ofs: i64) -> ptr[u64];

def mi_options_out_buf -> ptr[u8];

def _mi_options_init;

def mi_out_stderr(msg: ptr[u8], arg: ptr);

def mi_out_buf(msg: ptr[u8], arg: ptr) -> None;

def mi_out_buf_flush(out: ptr, no_more_buf: bool, arg: ptr);

def mi_out_buf_stderr(msg: ptr[u8], arg: ptr);

def mi_out_get_default -> tuple[ptr, ptr];

def mi_add_stderr_output;

def mi_recurse_enter_prim -> bool;

def mi_recurse_exit_prim;

def mi_recurse_enter -> bool;

def mi_recurse_exit;

def _mi_fputs(out: ptr, arg: ptr, prefix: ptr[u8], message: ptr[u8]);

def mi_vfprintf(
    out: ptr,
    arg: ptr,
    prefix: ptr[u8],
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
);

def _mi_fprintf(
    out: ptr,
    arg: ptr,
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
);

def mi_vfprintf_thread(
    out: ptr,
    arg: ptr,
    prefix: ptr[u8],
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
);

def _mi_trace_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
);

def _mi_verbose_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
);

def mi_show_error_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
);

def _mi_warning_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
);

def mi_error_default(err: i32);

def _mi_error_message(
    err: i32,
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
);

def _mi_toupper(c: u8) -> u8;

def _mi_strnicmp(s: ptr[u8], t: ptr[u8], n: u64) -> i32;

def _mi_strlcpy(dest: ptr[u8], src: ptr[u8], dest_size: u64);

def _mi_strlcat(dest: ptr[u8], src: ptr[u8], dest_size: u64);

def _mi_strlen(s: ptr[u8]) -> u64;

def _mi_strnlen(s: ptr[u8], max_len: u64) -> u64;

def mi_getenv(name: ptr[u8], result: ptr[u8], result_size: u64) -> bool;

def mi_option_init(desc: ptr[mi_option_desc_t]);

import from c {
    def mi_version -> i32 {
        return MI_MALLOC_VERSION;
    }  def mi_option_get(option: i32) -> i64 {
        if option < i32(0) or option >= _mi_option_last {
            return i64(0);
        }
        desc = mi_options_desc(option);

        if desc.view(1)[0].init_ == UNINIT {
            mi_option_init(desc);
        }
        return desc.view(1)[0].value;
    }  def mi_option_get_clamp(option: i32, min_value: i64, max_value: i64) -> i64 {
        x = mi_option_get(option);
        if x < min_value {
            return min_value;
        }
        if x > max_value {
            return max_value;
        }
        return x;
    }  def mi_option_get_size(option: i32) -> u64 {
        x = mi_option_get(option);
        if x < i64(0) {
            return u64(0);
        }
        return wrapping_mul(u64.wrap(x), MI_KiB);
    }  def mi_option_set(option: i32, value: i64) {
        if option < i32(0) or option >= _mi_option_last {
            return;
        }
        desc = mi_options_desc(option);
        desc.view(1)[0].value = value;
        desc.view(1)[0].init_ = INITIALIZED;
    }  def mi_option_set_default(option: i32, value: i64) {
        if option < i32(0) or option >= _mi_option_last {
            return;
        }
        desc = mi_options_desc(option);
        if desc.view(1)[0].init_ != INITIALIZED {
            desc.view(1)[0].value = value;
        }
    }  def mi_option_is_enabled(option: i32) -> bool {
        return mi_option_get(option) != i64(0);
    }  def mi_option_set_enabled(option: i32, enable: bool) {
        if enable {
            mi_option_set(option, i64(1));
        } else {
            mi_option_set(option, i64(0));
        }
    }  def mi_option_set_enabled_default(option: i32, enable: bool) {
        if enable {
            mi_option_set_default(option, i64(1));
        } else {
            mi_option_set_default(option, i64(0));
        }
    }  def mi_option_enable(option: i32) {
        mi_option_set_enabled(option, True);
    }  def mi_option_disable(option: i32) {
        mi_option_set_enabled(option, False);
    }  def mi_register_output(out: ptr, arg: ptr) {
        if int(out) == 0 {
            addressof(mi_options_statics).view(1)[0].mi_out_default = u64.wrap(
                int(ptr(mi_out_stderr))
            );
        } else {
            addressof(mi_options_statics).view(1)[0].mi_out_default = u64.wrap(
                int(out)
            );
        }
        mi_atomic_store_release(
            mi_options_statics_word(MiOptionsStatics_OUT_ARG), u64.wrap(int(arg))
        );
        if int(out) != 0 {
            mi_out_buf_flush(out, True, arg);
        }
    }  def mi_register_error(fun: ptr, arg: ptr) {
        addressof(mi_options_statics).view(1)[0].mi_error_handler = u64.wrap(int(fun));
        mi_atomic_store_release(
            mi_options_statics_word(MiOptionsStatics_ERROR_ARG), u64.wrap(int(arg))
        );
    }
}

import from c {
    obj MiOsState {
        has aligned_base: u64,
            pad0: u64,
            pad1: u64,
            pad2: u64,
            pad3: u64,
            pad4: u64,
            pad5: u64,
            pad6: u64,
            huge_start: u64,
            pad7: u64,
            pad8: u64,
            pad9: u64,
            pad10: u64,
            pad11: u64,
            pad12: u64,
            pad13: u64;
    }  glob:priv mi_os_mem_config: mi_os_mem_config_t = mi_os_mem_config_t(
             page_size=u64(4096),
             large_page_size=u64(0),
             alloc_granularity=u64(4096),
             has_overcommit=True,
             must_free_whole=False,
             has_virtual_reserve=True
         ); glob:priv mi_os_state: MiOsState = MiOsState();
}

glob:priv MI_HINT_BASE: Final[u64] = u64(2199023255552),
     MI_HINT_AREA: Final[u64] = u64(4398046511104),
     MI_HINT_MAX: Final[u64] = u64(32985348833280),
     MI_HUGE_OS_PAGE_SIZE: Final[u64] = u64(1073741824),
     MI_HUGE_OS_PAGES_START: Final[u64] = u64(35184372088832),
     MiOsState_ALIGNED_BASE: Final[i64] = 0,
     MiOsState_HUGE_START: Final[i64] = 64;

def _mi_os_has_overcommit -> bool;

def _mi_os_has_virtual_reserve -> bool;

def _mi_os_page_size -> u64;

def _mi_os_large_page_size -> u64;

def _mi_os_use_large_page(size: u64, alignment: u64) -> bool;

def _mi_os_good_alloc_size(size: u64) -> u64;

def _mi_os_init;

def mi_align_up_ptr(p: ptr[u8], alignment: u64) -> ptr[u8];

def mi_align_down_ptr(p: ptr[u8], alignment: u64) -> ptr[u8];

def _mi_os_get_aligned_hint(try_alignment: u64, size: u64) -> ptr[u8];

def mi_os_prim_free(
    addr: ptr[u8], size: u64, still_committed: bool, tld_stats: ptr[mi_stats_t]
);

def _mi_os_free_ex(
    addr: ptr[u8],
    size: u64,
    still_committed: bool,
    memid: ptr[mi_memid_t],
    tld_stats: ptr[mi_stats_t]
);

def _mi_os_free(
    p: ptr[u8], size: u64, memid: ptr[mi_memid_t], tld_stats: ptr[mi_stats_t]
);

def mi_os_prim_alloc(
    size: u64,
    try_alignment: u64,
    commit: bool,
    allow_large: bool,
    stats: ptr[mi_stats_t]
) -> tuple[ptr[u8], bool, bool];

def mi_os_prim_alloc_aligned(
    size: u64, alignment: u64, commit: bool, allow_large: bool, stats: ptr[mi_stats_t]
) -> tuple[ptr[u8], bool, bool, ptr[u8]];

def _mi_os_alloc(
    size: u64, memid: ptr[mi_memid_t], tld_stats: ptr[mi_stats_t]
) -> ptr[u8];

def _mi_os_alloc_aligned(
    size: u64,
    alignment: u64,
    commit: bool,
    allow_large: bool,
    memid: ptr[mi_memid_t],
    tld_stats: ptr[mi_stats_t]
) -> ptr[u8];

def _mi_os_alloc_aligned_at_offset(
    size: u64,
    alignment: u64,
    align_offset: u64,
    commit: bool,
    allow_large: bool,
    memid: ptr[mi_memid_t],
    tld_stats: ptr[mi_stats_t]
) -> ptr[u8];

def mi_os_page_align_areax(
    conservative: bool, addr: ptr[u8], size: u64
) -> tuple[ptr[u8], u64];

def mi_os_page_align_area_conservative(
    addr: ptr[u8], size: u64
) -> tuple[ptr[u8], u64];

def _mi_os_commit(
    addr: ptr[u8], size: u64, tld_stats: ptr[mi_stats_t]
) -> tuple[bool, bool];

def mi_os_decommit_ex(
    addr: ptr[u8], size: u64, needs_recommit: bool, tld_stats: ptr[mi_stats_t]
) -> tuple[bool, bool];

def _mi_os_decommit(addr: ptr[u8], size: u64, tld_stats: ptr[mi_stats_t]) -> bool;

def _mi_os_reset(addr: ptr[u8], size: u64, stats: ptr[mi_stats_t]) -> bool;

def _mi_os_purge_ex(
    p: ptr[u8], size: u64, allow_reset: bool, stats: ptr[mi_stats_t]
) -> bool;

def _mi_os_purge(p: ptr[u8], size: u64, stats: ptr[mi_stats_t]) -> bool;

def mi_os_protectx(addr: ptr[u8], size: u64, protect_: bool) -> bool;

def _mi_os_protect(addr: ptr[u8], size: u64) -> bool;

def _mi_os_unprotect(addr: ptr[u8], size: u64) -> bool;

def mi_os_claim_huge_pages(pages: u64) -> tuple[ptr[u8], u64];

def _mi_os_alloc_huge_os_pages(
    pages: u64, numa_node: i32, max_msecs: i64, memid: ptr[mi_memid_t]
) -> tuple[ptr[u8], u64, u64];

def mi_os_free_huge_os_pages(p: ptr[u8], size: u64, stats: ptr[mi_stats_t]);

def _mi_os_numa_node_count_get -> u64;

def _mi_os_numa_node_get(tld: ptr[mi_os_tld_t]) -> i32;


glob:priv MI_MAX_RETIRE_SIZE: Final[u64] = u64(131072),
     MI_RETIRE_CYCLES: Final[u8] = u8(16),
     MI_MAX_SLICE_SHIFT: Final[u64] = u64(6),
     MI_MAX_SLICES: Final[u64] = u64(64),
     MI_MIN_SLICES: Final[u64] = u64(2),
     MI_MAX_EXTEND_SIZE: Final[u64] = u64(4096),
     MI_MIN_EXTEND: Final[u64] = u64(4);

import from c {
    obj MiPageDeferred {
        has deferred_free: ptr[u8],
            deferred_arg: u64;
    }  glob:priv mi_page_deferred: MiPageDeferred = MiPageDeferred();
}


def mi_page_queue_is_huge(pq: ptr[mi_page_queue_t]) -> bool;

def mi_page_queue_is_full(pq: ptr[mi_page_queue_t]) -> bool;

def mi_page_queue_is_special(pq: ptr[mi_page_queue_t]) -> bool;

def mi_bin(size: u64) -> u8;

def _mi_bin(size: u64) -> u8;

def _mi_bin_size(bin: u8) -> u64;

import from c {
    def mi_good_size(size: u64) -> u64 {
        if size <= MI_MEDIUM_OBJ_SIZE_MAX {
            return _mi_bin_size(mi_bin(size));
        }
        return _mi_align_up(size, _mi_os_page_size());
    }
}

def mi_page_queue_of(page: ptr[mi_page_t]) -> ptr[mi_page_queue_t];

def mi_heap_page_queue_of(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t]
) -> ptr[mi_page_queue_t];

def mi_heap_queue_first_update(heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t]);

def mi_page_queue_remove(queue: ptr[mi_page_queue_t], page: ptr[mi_page_t]);

def mi_page_queue_push(
    heap: ptr[mi_heap_t], queue: ptr[mi_page_queue_t], page: ptr[mi_page_t]
);

def mi_page_queue_enqueue_from(
    to: ptr[mi_page_queue_t], from_q: ptr[mi_page_queue_t], page: ptr[mi_page_t]
);

def _mi_page_queue_append(
    heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t], append: ptr[mi_page_queue_t]
) -> u64;


def mi_page_block_at(
    page: ptr[mi_page_t], page_start: ptr[u8], block_size: u64, i: u64
) -> ptr[mi_block_t];

def _mi_page_use_delayed_free(page: ptr[mi_page_t], delay: u64, override_never: bool);

def _mi_page_try_use_delayed_free(
    page: ptr[mi_page_t], delay: u64, override_never: bool
) -> bool;

def _mi_page_thread_free_collect(page: ptr[mi_page_t]);

def _mi_page_free_collect(page: ptr[mi_page_t], force: bool);

def _mi_page_reclaim(heap: ptr[mi_heap_t], page: ptr[mi_page_t]);

def mi_page_fresh_alloc(
    heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t], block_size: u64, page_alignment: u64
) -> ptr[mi_page_t];

def mi_page_fresh(heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t]) -> ptr[mi_page_t];

def _mi_heap_delayed_free_all(heap: ptr[mi_heap_t]);

def _mi_heap_delayed_free_partial(heap: ptr[mi_heap_t]) -> bool;

def _mi_page_unfull(page: ptr[mi_page_t]);

def mi_page_to_full(page: ptr[mi_page_t], pq: ptr[mi_page_queue_t]);

def _mi_page_abandon(page: ptr[mi_page_t], pq: ptr[mi_page_queue_t]);

import from c {
    def _mi_page_free(page: ptr, pq: ptr, force: bool) {
        pg = ptr[mi_page_t](page);
        queue = ptr[mi_page_queue_t](pq);

        mi_page_set_has_aligned(pg, False);
        heap = mi_page_heap(pg);

        segments_tld = mi_tld_segments(heap.view(1)[0].tld);
        mi_page_queue_remove(queue, pg);

        mi_page_set_heap(pg, ptr[mi_heap_t]());
        _mi_segment_page_free(pg, force, segments_tld);
    }
}

def _mi_page_retire(page: ptr[mi_page_t]);

def _mi_heap_collect_retired(heap: ptr[mi_heap_t], force: bool);

def mi_page_free_list_extend_secure(
    heap: ptr[mi_heap_t],
    page: ptr[mi_page_t],
    bsize: u64,
    extend: u64,
    stats: ptr[mi_stats_t]
);

def mi_page_free_list_extend(
    page: ptr[mi_page_t], bsize: u64, extend: u64, stats: ptr[mi_stats_t]
);

def mi_page_extend_free(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t], tld: ptr[mi_tld_t]
);

def mi_page_init(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t], block_size: u64, tld: ptr[mi_tld_t]
);

def mi_page_queue_find_free_ex(
    heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t], first_try: bool
) -> ptr[mi_page_t];

def mi_find_free_page(heap: ptr[mi_heap_t], size: u64) -> ptr[mi_page_t];

def _mi_deferred_free(heap: ptr[mi_heap_t], force: bool);

import from c {
    def mi_register_deferred_free(deferred_free: ptr, arg: ptr) {
        deferred = addressof(mi_page_deferred);
        deferred.view(1)[0].deferred_free = ptr[u8](deferred_free);
        mi_atomic_store_release(mi_word_addr(ptr[u8](deferred), 8), u64.wrap(int(arg)));
    }
}

def mi_large_huge_page_alloc(
    heap: ptr[mi_heap_t], size: u64, page_alignment: u64
) -> ptr[mi_page_t];

def mi_find_page(
    heap: ptr[mi_heap_t], size: u64, huge_alignment: u64
) -> ptr[mi_page_t];

def _mi_malloc_generic(
    heap: ptr[mi_heap_t], size: u64, zero: bool, huge_alignment: u64
) -> ptr[u8];


glob:priv MI_CHACHA_ROUNDS: Final[i64] = 20;

def rotl(x: u32, shift: u32) -> u32;

def qround(x: ptr[u32], a: i64, b: i64, c: i64, d: i64);

def chacha_block(ctx: ptr[mi_random_ctx_t]);

def chacha_next32(ctx: ptr[mi_random_ctx_t]) -> u32;

def read32(p: ptr[u8], idx32: u64) -> u32;

def chacha_init(ctx: ptr[mi_random_ctx_t], key: ptr[u8], nonce: u64);

def chacha_split(ctx: ptr[mi_random_ctx_t], nonce: u64, ctx_new: ptr[mi_random_ctx_t]);

def _mi_random_split(ctx: ptr[mi_random_ctx_t], ctx_new: ptr[mi_random_ctx_t]);

def _mi_random_next(ctx: ptr[mi_random_ctx_t]) -> u64;

def _mi_os_random_weak(extra_seed: u64) -> u64;

def mi_random_init_ex(ctx: ptr[mi_random_ctx_t], use_weak: bool);

def _mi_random_init(ctx: ptr[mi_random_ctx_t]);

def _mi_random_init_weak(ctx: ptr[mi_random_ctx_t]);

def _mi_random_reinit_if_weak(ctx: ptr[mi_random_ctx_t]);


glob:priv MI_PAGE_HUGE_ALIGN: Final[u64] = u64(262144),
     MI_TAGGED_MASK: Final[u64] = u64(33554431);

def mi_segment_slice_diff(a: ptr[mi_page_t], b: ptr[mi_page_t]) -> i64;

def mi_commit_mask_all_set(
    commit: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]
) -> bool;

def mi_commit_mask_any_set(
    commit: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]
) -> bool;

def mi_commit_mask_create_intersect(
    commit: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t], res: ptr[mi_commit_mask_t]
);

def mi_commit_mask_clear(res: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]);

def mi_commit_mask_set(res: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]);

def mi_commit_mask_create(bitidx: u64, bitcount: u64, cm: ptr[mi_commit_mask_t]);

def _mi_commit_mask_committed_size(cm: ptr[mi_commit_mask_t], total: u64) -> u64;

def _mi_commit_mask_next_run(cm: ptr[mi_commit_mask_t], idx: u64) -> tuple[u64, u64];

def mi_segment_slices_end(segment: ptr[mi_segment_t]) -> ptr[mi_page_t];

def mi_slice_start(slice: ptr[mi_page_t]) -> ptr[u8];

def mi_slice_bin8(slice_count: u64) -> u64;

def mi_slice_bin(slice_count: u64) -> u64;

def mi_slice_index(slice: ptr[mi_page_t]) -> u64;

def mi_span_queue_push(sq: ptr[mi_span_queue_t], slice: ptr[mi_page_t]);

def mi_span_queue_for(
    slice_count: u64, tld: ptr[mi_segments_tld_t]
) -> ptr[mi_span_queue_t];

def mi_span_queue_delete(sq: ptr[mi_span_queue_t], slice: ptr[mi_page_t]);

def mi_slice_is_used(slice: ptr[mi_page_t]) -> bool;

def mi_segment_info_size(segment: ptr[mi_segment_t]) -> u64;

def _mi_segment_page_start_from_slice(
    segment: ptr[mi_segment_t], slice: ptr[mi_page_t], xblock_size: u64
) -> tuple[ptr[u8], u64];

def _mi_segment_page_start(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t]
) -> tuple[ptr[u8], u64];

def mi_segment_calculate_slices(required: u64) -> tuple[u64, u64, u64];

def mi_segments_track_size(segment_size: i64, tld: ptr[mi_segments_tld_t]);

def mi_segment_os_free(segment: ptr[mi_segment_t], tld: ptr[mi_segments_tld_t]);

def _mi_segment_thread_collect(tld: ptr[mi_segments_tld_t]);

def mi_segment_commit_mask(
    segment: ptr[mi_segment_t],
    conservative: bool,
    p: ptr[u8],
    size: u64,
    cm: ptr[mi_commit_mask_t]
) -> tuple[ptr[u8], u64];

def mi_segment_commit(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) -> bool;

def mi_segment_ensure_committed(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) -> bool;

def mi_segment_purge(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) -> bool;

def mi_segment_schedule_purge(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
);

def mi_segment_try_purge(
    segment: ptr[mi_segment_t], force: bool, stats: ptr[mi_stats_t]
);

def mi_segment_is_abandoned(segment: ptr[mi_segment_t]) -> bool;

def mi_segment_span_free(
    segment: ptr[mi_segment_t],
    slice_index: u64,
    slice_count: u64,
    allow_purge: bool,
    tld: ptr[mi_segments_tld_t]
);

def mi_segment_span_remove_from_queue(
    slice: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]
);

def mi_segment_span_free_coalesce(
    slice: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t];

def mi_segment_span_allocate(
    segment: ptr[mi_segment_t],
    slice_index: u64,
    slice_count: u64,
    tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t];

def mi_segment_slice_split(
    segment: ptr[mi_segment_t],
    slice: ptr[mi_page_t],
    slice_count: u64,
    tld: ptr[mi_segments_tld_t]
);

def mi_segments_page_find_and_allocate(
    slice_count: u64, req_arena_id: i32, tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t];

def mi_segment_os_alloc(
    required: u64,
    page_alignment: u64,
    eager_delayed: bool,
    req_arena_id: i32,
    psegment_slices: u64,
    ppre_size: u64,
    pinfo_slices: u64,
    commit: bool,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> tuple[ptr[mi_segment_t], u64, u64, u64];

def mi_segment_alloc(
    required: u64,
    page_alignment: u64,
    req_arena_id: i32,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> tuple[ptr[mi_segment_t], ptr[mi_page_t]];

def mi_segment_free(
    segment: ptr[mi_segment_t], force: bool, tld: ptr[mi_segments_tld_t]
);

def mi_segment_page_clear(
    page: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t];

def _mi_segment_page_free(
    page: ptr[mi_page_t], force: bool, tld: ptr[mi_segments_tld_t]
);

def mi_tagged_segment_ptr(ts: u64) -> ptr[mi_segment_t];

def mi_tagged_segment(segment: ptr[mi_segment_t], ts: u64) -> u64;

def mi_abandoned_visited_push(
    pool: ptr[mi_abandoned_pool_t], segment: ptr[mi_segment_t]
);

def mi_abandoned_visited_revisit(pool: ptr[mi_abandoned_pool_t]) -> bool;

def mi_abandoned_push(pool: ptr[mi_abandoned_pool_t], segment: ptr[mi_segment_t]);

def _mi_abandoned_await_readers(pool: ptr[mi_abandoned_pool_t]);

def mi_abandoned_pop(pool: ptr[mi_abandoned_pool_t]) -> ptr[mi_segment_t];

def mi_segment_abandon(segment: ptr[mi_segment_t], tld: ptr[mi_segments_tld_t]);

def _mi_segment_page_abandon(page: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]);

def mi_slices_start_iterate(
    segment: ptr[mi_segment_t]
) -> tuple[ptr[mi_page_t], ptr[mi_page_t]];

def mi_segment_check_free(
    segment: ptr[mi_segment_t],
    slices_needed: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t]
) -> bool;

def mi_heap_by_tag(heap: ptr[mi_heap_t], tag: u8) -> ptr[mi_heap_t];

def mi_segment_reclaim(
    segment: ptr[mi_segment_t],
    heap: ptr[mi_heap_t],
    requested_block_size: u64,
    tld: ptr[mi_segments_tld_t]
) -> tuple[ptr[mi_segment_t], bool];

def _mi_abandoned_reclaim_all(heap: ptr[mi_heap_t], tld: ptr[mi_segments_tld_t]);

def mi_segment_try_reclaim(
    heap: ptr[mi_heap_t],
    needed_slices: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t]
) -> tuple[ptr[mi_segment_t], bool];

def _mi_abandoned_collect(
    heap: ptr[mi_heap_t], force: bool, tld: ptr[mi_segments_tld_t]
);

def mi_segment_reclaim_or_alloc(
    heap: ptr[mi_heap_t],
    needed_slices: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_segment_t];

def mi_segments_page_alloc(
    heap: ptr[mi_heap_t],
    page_kind: i32,
    required: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_page_t];

def mi_segment_huge_page_alloc(
    size: u64,
    page_alignment: u64,
    req_arena_id: i32,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_page_t];

def _mi_segment_huge_page_reset(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], block: ptr[mi_block_t]
);

def _mi_segment_page_alloc(
    heap: ptr[mi_heap_t],
    block_size: u64,
    page_alignment: u64,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_page_t];

def mi_segment_visit_page(
    segment: ptr[mi_segment_t],
    page: ptr[mi_page_t],
    visit_blocks: bool,
    visit_fn: ptr,
    arg: ptr
) -> bool;

def mi_segment_visit_pages(
    segment: ptr[mi_segment_t],
    page_tag: u8,
    visit_blocks: bool,
    visit_fn: ptr,
    arg: ptr
) -> bool;

def _mi_abandoned_pool_visit_blocks(
    pool: ptr[mi_abandoned_pool_t],
    page_tag: u8,
    visit_blocks: bool,
    visit_fn: ptr,
    arg: ptr
) -> bool;


glob:priv MI_MAX_ADDRESS: Final[u64] = u64(43980465111040),
     MI_SEGMENT_MAP_BITS: Final[u64] = u64(1310720),
     MI_SEGMENT_MAP_SIZE: Final[u64] = u64(163840),
     MI_SEGMENT_MAP_WSIZE: Final[u64] = u64(20480);

import from c {
    obj MiSegmentMapWords8 {
        has w0: u64,
            w1: u64,
            w2: u64,
            w3: u64,
            w4: u64,
            w5: u64,
            w6: u64,
            w7: u64;
    }  obj MiSegmentMapWords64 {
        has w0: MiSegmentMapWords8,
            w1: MiSegmentMapWords8,
            w2: MiSegmentMapWords8,
            w3: MiSegmentMapWords8,
            w4: MiSegmentMapWords8,
            w5: MiSegmentMapWords8,
            w6: MiSegmentMapWords8,
            w7: MiSegmentMapWords8;
    }  obj MiSegmentMapWords512 {
        has w0: MiSegmentMapWords64,
            w1: MiSegmentMapWords64,
            w2: MiSegmentMapWords64,
            w3: MiSegmentMapWords64,
            w4: MiSegmentMapWords64,
            w5: MiSegmentMapWords64,
            w6: MiSegmentMapWords64,
            w7: MiSegmentMapWords64;
    }  obj MiSegmentMapWords4096 {
        has w0: MiSegmentMapWords512,
            w1: MiSegmentMapWords512,
            w2: MiSegmentMapWords512,
            w3: MiSegmentMapWords512,
            w4: MiSegmentMapWords512,
            w5: MiSegmentMapWords512,
            w6: MiSegmentMapWords512,
            w7: MiSegmentMapWords512;
    }  obj MiSegmentMapStorage {
        has w0: MiSegmentMapWords4096,
            w1: MiSegmentMapWords4096,
            w2: MiSegmentMapWords4096,
            w3: MiSegmentMapWords4096,
            w4: MiSegmentMapWords4096,
            w5: u64;
    }
}

import from c { glob:priv mi_segment_map: MiSegmentMapStorage = MiSegmentMapStorage(); }

def mi_segment_map_word(index: u64) -> ptr[u64];

def mi_segment_map_index_of(segment: ptr[mi_segment_t]) -> tuple[u64, u64];

def _mi_segment_map_allocated_at(segment: ptr[mi_segment_t]);

def _mi_segment_map_freed_at(segment: ptr[mi_segment_t]);

def _mi_segment_of(p: ptr[u8]) -> ptr[mi_segment_t];

def mi_is_valid_pointer(p: ptr[u8]) -> bool;

import from c {
    def mi_is_in_heap_region(p: ptr) -> bool {
        return mi_is_valid_pointer(ptr[u8](p));
    }
}

import from c {
    obj buffered_t {
        has out: u64,
            arg: u64,
            buf: ptr[u8],
            used: u64,
            count: u64;
    }  obj MiStatsStatics {
        has mi_process_start: i64,
            mi_clock_diff: i64;
    }  glob:priv mi_stats_statics: MiStatsStatics = MiStatsStatics();
}

def mi_stats_div_trunc(a: i64, b: i64) -> i64;

def mi_stats_rem_trunc(a: i64, b: i64) -> i64;

def mi_is_in_main(stat: ptr[u8]) -> bool;

def mi_stat_update(stat: ptr[mi_stat_count_t], amount: i64);

def _mi_stat_counter_increase(stat: ptr[mi_stat_counter_t], amount: u64);

def _mi_stat_increase(stat: ptr[mi_stat_count_t], amount: u64);

def _mi_stat_decrease(stat: ptr[mi_stat_count_t], amount: u64);

def mi_stat_add(stat: ptr[mi_stat_count_t], src: ptr[mi_stat_count_t], unit: i64);

def mi_stat_counter_add(
    stat: ptr[mi_stat_counter_t], src: ptr[mi_stat_counter_t], unit: i64
);

def mi_stats_add(stats: ptr[mi_stats_t], src: ptr[mi_stats_t]);

def mi_printf_amount(n: i64, unit: i64, out: ptr, arg: ptr, fmt: ptr[u8]);

def mi_print_amount(n: i64, unit: i64, out: ptr, arg: ptr);

def mi_print_count(n: i64, unit: i64, out: ptr, arg: ptr);

def mi_stat_print_ex(
    stat: ptr[mi_stat_count_t],
    msg: ptr[u8],
    unit: i64,
    out: ptr,
    arg: ptr,
    notok: ptr[u8]
);

def mi_stat_print(
    stat: ptr[mi_stat_count_t], msg: ptr[u8], unit: i64, out: ptr, arg: ptr
);

def mi_stat_peak_print(
    stat: ptr[mi_stat_count_t], msg: ptr[u8], unit: i64, out: ptr, arg: ptr
);

def mi_stat_counter_print(
    stat: ptr[mi_stat_counter_t], msg: ptr[u8], out: ptr, arg: ptr
);

def mi_stat_counter_print_avg(
    stat: ptr[mi_stat_counter_t], msg: ptr[u8], out: ptr, arg: ptr
);

def mi_print_header(out: ptr, arg: ptr);

def mi_buffered_flush(buf: ptr[buffered_t]);

def mi_buffered_out(msg: ptr[u8], arg: ptr) -> None;

def _mi_stats_print(stats: ptr[mi_stats_t], out0: ptr, arg0: ptr);

def mi_stats_get_default -> ptr[mi_stats_t];

def mi_stats_merge_from(stats: ptr[mi_stats_t]);

def _mi_stats_done(stats: ptr[mi_stats_t]);

def _mi_clock_now -> i64;

def _mi_clock_start -> i64;

def _mi_clock_end(start: i64) -> i64;

def mi_stats_msecs_clamp(t: i64) -> u64;

import from c {
    def mi_stats_reset {
        stats = mi_stats_get_default();
        if stats != addressof(_mi_stats_main) {
            memset(ptr(stats), 0, mi_stats_t_SIZE);
        }
        memset(ptr(addressof(_mi_stats_main)), 0, mi_stats_t_SIZE);
        st = addressof(mi_stats_statics);
        if st.view(1)[0].mi_process_start == i64(0) {
            st.view(1)[0].mi_process_start = _mi_clock_start();
        }
    }  def mi_stats_merge {
        mi_stats_merge_from(mi_stats_get_default());
    }  def mi_stats_print_out(out: ptr, arg: ptr) {
        mi_stats_merge_from(mi_stats_get_default());
        _mi_stats_print(addressof(_mi_stats_main), out, arg);
    }  def mi_stats_print(out: ptr) {
        mi_stats_print_out(out, ptr());
    }  def mi_thread_stats_print_out(out: ptr, arg: ptr) {
        _mi_stats_print(mi_stats_get_default(), out, arg);
    }  def mi_process_info(
        elapsed_msecs: ptr[u64],
        user_msecs: ptr[u64],
        system_msecs: ptr[u64],
        current_rss: ptr[u64],
        peak_rss: ptr[u64],
        current_commit: ptr[u64],
        peak_commit: ptr[u64],
        page_faults: ptr[u64]
    ) {
        slots: own MiStack = MiStack();
        pinfo = ptr[mi_process_info_t](jacpy_stack_address(&mut slots));
        _mi_memzero(ptr(pinfo), mi_process_info_t_SIZE);
        committed = ptr[i64](
            mi_stat_count_at(addressof(_mi_stats_main), mi_stats_t_COMMITTED)
        );
        pinfo.view(1)[0].elapsed = _mi_clock_end(
            addressof(mi_stats_statics).view(1)[0].mi_process_start
        );

        pinfo.view(1)[0].current_commit = u64.wrap(
            mi_atomic_loadi64_relaxed(committed + 3)
        );
        pinfo.view(1)[0].peak_commit = u64.wrap(
            mi_atomic_loadi64_relaxed(committed + 2)
        );
        pinfo.view(1)[0].current_rss = pinfo.view(1)[0].current_commit;
        pinfo.view(1)[0].peak_rss = pinfo.view(1)[0].peak_commit;
        pinfo.view(1)[0].utime = i64(0);
        pinfo.view(1)[0].stime = i64(0);
        pinfo.view(1)[0].page_faults = u64(0);
        _mi_prim_process_info(pinfo);
        if elapsed_msecs {
            elapsed_msecs.view(1)[0] = mi_stats_msecs_clamp(pinfo.view(1)[0].elapsed);
        }
        if user_msecs {
            user_msecs.view(1)[0] = mi_stats_msecs_clamp(pinfo.view(1)[0].utime);
        }
        if system_msecs {
            system_msecs.view(1)[0] = mi_stats_msecs_clamp(pinfo.view(1)[0].stime);
        }
        if current_rss {
            current_rss.view(1)[0] = pinfo.view(1)[0].current_rss;
        }
        if peak_rss {
            peak_rss.view(1)[0] = pinfo.view(1)[0].peak_rss;
        }
        if current_commit {
            current_commit.view(1)[0] = pinfo.view(1)[0].current_commit;
        }
        if peak_commit {
            peak_commit.view(1)[0] = pinfo.view(1)[0].peak_commit;
        }
        if page_faults {
            page_faults.view(1)[0] = pinfo.view(1)[0].page_faults;
        }
    }
}

import from c {
    obj MiPrimState {
        has heap_default_key: u64,
            large_page_try_ok: u64,
            reset_advice: u64,
            no_getrandom: u64,
            heap_default_key_created: bool,
            huge_pages_available: bool,
            pad0: u16,
            pad1: u32;
    }  glob:priv mi_prim_state: MiPrimState = MiPrimState(
             huge_pages_available=True
         );
}

glob:priv MiPrimState_HEAP_DEFAULT_KEY: Final[i64] = 0,
     MiPrimState_LARGE_PAGE_TRY_OK: Final[i64] = 8,
     MiPrimState_RESET_ADVICE: Final[i64] = 16,
     MiPrimState_NO_GETRANDOM: Final[i64] = 24,
     MPOL_PREFERRED: Final[u64] = u64(1),
     MI_PRIM_STDERR_FD: Final[i32] = 2;

def mi_prim_state_word(ofs: i64) -> ptr[u64];

def mi_prim_open(fpath: ptr[u8], open_flags: i32) -> i32;

def mi_prim_read(fd: i32, buf: ptr[u8], bufsize: u64) -> i64;

def mi_prim_close(fd: i32) -> i32;

def mi_prim_access(fpath: ptr[u8], mode: i32) -> i32;

def unix_detect_overcommit -> bool;

def _mi_prim_mem_init(config: ptr[mi_os_mem_config_t]);

def _mi_prim_free(addr: ptr[u8], size: u64) -> i32;

def unix_madvise(addr: ptr[u8], size: u64, advice: i32) -> i32;

def unix_mmap_prim(
    addr: ptr[u8],
    size: u64,
    try_alignment: u64,
    protect_flags: i32,
    flags: i32,
    fd: i32
) -> ptr[u8];

def unix_mmap_fd -> i32;

def unix_mmap(
    addr: ptr[u8],
    size: u64,
    try_alignment: u64,
    protect_flags: i32,
    large_only: bool,
    allow_large: bool,
    is_large_in: bool
) -> tuple[ptr[u8], bool];

def _mi_prim_alloc(
    size: u64, try_alignment: u64, commit: bool, allow_large: bool
) -> tuple[i32, bool, bool, ptr[u8]];

def unix_mprotect_hint(err: i32);

def _mi_prim_commit(start: ptr[u8], size: u64) -> tuple[i32, bool];

def _mi_prim_decommit(start: ptr[u8], size: u64) -> tuple[i32, bool];

def _mi_prim_reset(start: ptr[u8], size: u64) -> i32;

def _mi_prim_protect(start: ptr[u8], size: u64, protect_: bool) -> i32;

def mi_prim_mbind(
    start: ptr[u8], length: u64, mode: u64, nmask: ptr[u64], maxnode: u64, flags: u32
) -> i64;

def _mi_prim_alloc_huge_os_pages(
    hint_addr: ptr[u8], size: u64, numa_node: i32
) -> tuple[i32, bool, ptr[u8]];

def _mi_prim_numa_node -> u64;

def _mi_prim_numa_node_count -> u64;

def _mi_prim_clock_now -> i64;

def timeval_secs(tv: ptr[u8]) -> i64;

def _mi_prim_process_info(pinfo: ptr[mi_process_info_t]);

def _mi_prim_out_stderr(msg: ptr[u8]);

def _mi_prim_getenv(name: ptr[u8], result: ptr[u8], result_size: u64) -> bool;

def mi_prim_getentropy(buf: ptr[u8], buf_len: u64) -> i32;

def _mi_prim_random_buf(buf: ptr[u8], buf_len: u64) -> bool;

def mi_pthread_done(value: ptr);

def _mi_prim_thread_init_auto_done;

def _mi_prim_thread_done_auto_done;

def _mi_prim_thread_associate_default_heap(heap: ptr[mi_heap_t]);

impl mi_atomic_load_relaxed(p: ptr[u64]) -> u64 {
    return u64.wrap(__atomic_load_i64(int(p), 0));
}

impl mi_atomic_load_acquire(p: ptr[u64]) -> u64 {
    return u64.wrap(__atomic_load_i64(int(p), 2));
}

impl mi_atomic_load_seq_cst(p: ptr[u64]) -> u64 {
    return u64.wrap(__atomic_load_i64(int(p), 5));
}

impl mi_atomic_store_seq_cst(p: ptr[u64], x: u64) {
    __atomic_store_i64(int(p), i64.wrap(x), 5);
}

impl mi_atomic_store_relaxed(p: ptr[u64], x: u64) {
    __atomic_store_i64(int(p), i64.wrap(x), 0);
}

impl mi_atomic_store_release(p: ptr[u64], x: u64) {
    __atomic_store_i64(int(p), i64.wrap(x), 3);
}

impl mi_atomic_exchange_release(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_swap_i64(int(p), i64.wrap(x), 3));
}

impl mi_atomic_exchange_acq_rel(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_swap_i64(int(p), i64.wrap(x), 4));
}

impl mi_atomic_cas_strong_release(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64] {
    seen = u64.wrap(__atomic_cas_i64(int(p), i64.wrap(expected), i64.wrap(desired), 3));
    return (seen == expected, seen);
}

impl mi_atomic_cas_strong_acq_rel(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64] {
    seen = u64.wrap(__atomic_cas_i64(int(p), i64.wrap(expected), i64.wrap(desired), 4));
    return (seen == expected, seen);
}

impl mi_atomic_cas_weak_release(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64] {
    seen = u64.wrap(__atomic_cas_i64(int(p), i64.wrap(expected), i64.wrap(desired), 3));
    return (seen == expected, seen);
}

impl mi_atomic_cas_weak_acq_rel(
    p: ptr[u64], expected: u64, desired: u64
) -> tuple[bool, u64] {
    seen = u64.wrap(__atomic_cas_i64(int(p), i64.wrap(expected), i64.wrap(desired), 4));
    return (seen == expected, seen);
}

impl mi_atomic_add_relaxed(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_add_i64(int(p), i64.wrap(x), 0));
}

impl mi_atomic_sub_relaxed(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_sub_i64(int(p), i64.wrap(x), 0));
}

impl mi_atomic_add_acq_rel(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_add_i64(int(p), i64.wrap(x), 4));
}

impl mi_atomic_sub_acq_rel(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_sub_i64(int(p), i64.wrap(x), 4));
}

impl mi_atomic_and_acq_rel(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_and_i64(int(p), i64.wrap(x), 4));
}

impl mi_atomic_or_acq_rel(p: ptr[u64], x: u64) -> u64 {
    return u64.wrap(__atomic_or_i64(int(p), i64.wrap(x), 4));
}

impl mi_atomic_increment_relaxed(p: ptr[u64]) -> u64 {
    return mi_atomic_add_relaxed(p, u64(1));
}

impl mi_atomic_decrement_relaxed(p: ptr[u64]) -> u64 {
    return mi_atomic_sub_relaxed(p, u64(1));
}

impl mi_atomic_increment_acq_rel(p: ptr[u64]) -> u64 {
    return mi_atomic_add_acq_rel(p, u64(1));
}

impl mi_atomic_decrement_acq_rel(p: ptr[u64]) -> u64 {
    return mi_atomic_sub_acq_rel(p, u64(1));
}

impl mi_atomic_addi(p: ptr[i64], add: i64) -> i64 {
    return __atomic_add_i64(int(p), add, 4);
}

impl mi_atomic_subi(p: ptr[i64], sub: i64) -> i64 {
    return __atomic_sub_i64(int(p), sub, 4);
}

impl mi_atomic_addi64_relaxed(p: ptr[i64], add: i64) -> i64 {
    return __atomic_add_i64(int(p), add, 0);
}

impl mi_atomic_addi64_acq_rel(p: ptr[i64], add: i64) -> i64 {
    return __atomic_add_i64(int(p), add, 4);
}

impl mi_atomic_maxi64_relaxed(p: ptr[i64], x: i64) {
    current = __atomic_load_i64(int(p), 0);
    while current < x {
        seen = __atomic_cas_i64(int(p), current, x, 3);
        if seen == current {
            return;
        }
        current = seen;
    }
}

impl mi_atomic_loadi64_relaxed(p: ptr[i64]) -> i64 {
    return __atomic_load_i64(int(p), 0);
}

impl mi_atomic_loadi64_acquire(p: ptr[i64]) -> i64 {
    return __atomic_load_i64(int(p), 2);
}

impl mi_atomic_storei64_relaxed(p: ptr[i64], x: i64) {
    __atomic_store_i64(int(p), x, 0);
}

impl mi_atomic_storei64_release(p: ptr[i64], x: i64) {
    __atomic_store_i64(int(p), x, 3);
}

impl mi_atomic_casi64_strong_acq_rel(
    p: ptr[i64], expected: i64, desired: i64
) -> tuple[bool, i64] {
    seen = __atomic_cas_i64(int(p), expected, desired, 4);
    return (seen == expected, seen);
}

impl mi_atomic_once(once: ptr[u64]) -> bool {
    if mi_atomic_load_relaxed(once) != u64(0) {
        return False;
    }
    (ok, seen) = mi_atomic_cas_strong_acq_rel(once, u64(0), u64(1));
    return ok;
}

impl mi_atomic_yield {
    sched_yield();
}

impl mi_heap_default_slot -> ptr[ptr[mi_heap_t]] {
    return ptr[ptr[mi_heap_t]](__thread_local("jac_mi_heap_default"));
}

impl mi_prim_get_default_heap -> ptr[mi_heap_t] {
    heap = mi_heap_default_slot().view(1)[0];
    if not heap {
        return addressof(_mi_heap_empty);
    }
    return heap;
}

impl _mi_prim_thread_id -> u64 {
    return u64.wrap(__thread_local("jac_mi_heap_default"));
}

impl mi_call_output(fun: ptr, msg: ptr[u8], arg: ptr) {
    slot = ptr[MiOutputCall](__thread_local("jac_mi_call_output"));
    slot.view(1)[0].call = int(fun);
    slot.view(1)[0].call(msg, arg);
}

impl mi_call_void(fun: ptr) {
    slot = ptr[MiVoidCall](__thread_local("jac_mi_call_void"));
    slot.view(1)[0].call = int(fun);
    slot.view(1)[0].call();
}

impl mi_call_error(fun: ptr, err: i32, arg: ptr) {
    slot = ptr[MiErrorCall](__thread_local("jac_mi_call_error"));
    slot.view(1)[0].call = int(fun);
    slot.view(1)[0].call(err, arg);
}

impl mi_call_deferred_free(fun: ptr, force: bool, heartbeat: u64, arg: ptr) {
    slot = ptr[MiDeferredFreeCall](__thread_local("jac_mi_call_deferred_free"));
    slot.view(1)[0].call = int(fun);
    slot.view(1)[0].call(force, heartbeat, arg);
}

impl mi_call_block_visit(
    fun: ptr, heap: ptr, area: ptr, block: ptr, block_size: u64, arg: ptr
) -> bool {
    slot = ptr[MiBlockVisitCall](__thread_local("jac_mi_call_block_visit"));
    slot.view(1)[0].call = int(fun);
    return slot.view(1)[0].call(heap, area, block, block_size, arg);
}

impl mi_call_bitmap_pred(fun: ptr, bitmap_idx: u64, pred_arg: ptr) -> bool {
    slot = ptr[MiBitmapPredCall](__thread_local("jac_mi_call_bitmap_pred"));
    slot.view(1)[0].call = int(fun);
    return slot.view(1)[0].call(bitmap_idx, pred_arg);
}

impl mi_call_page_visitor(
    fun: ptr,
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg1: ptr,
    arg2: ptr
) -> bool {
    slot = ptr[MiPageVisitCall](__thread_local("jac_mi_call_page_visitor"));
    slot.view(1)[0].call = int(fun);
    return slot.view(1)[0].call(heap, pq, page, arg1, arg2) != u8(0);
}

impl mi_call_area_visitor(
    fun: ptr, heap: ptr[mi_heap_t], xarea: ptr[mi_heap_area_ex_t], arg: ptr
) -> bool {
    slot = ptr[MiAreaVisitCall](__thread_local("jac_mi_call_area_visitor"));
    slot.view(1)[0].call = int(fun);
    return slot.view(1)[0].call(heap, xarea, arg) != u8(0);
}

impl mi_word_addr(base: ptr[u8], ofs: i64) -> ptr[u64] {
    return ptr[u64](base + ofs);
}

impl mi_page_xthread_free_addr(page: ptr[mi_page_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](page) + mi_page_t_XTHREAD_FREE);
}

impl mi_page_xheap_addr(page: ptr[mi_page_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](page) + mi_page_t_XHEAP);
}

impl mi_heap_thread_delayed_free_addr(heap: ptr[mi_heap_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](heap) + mi_heap_t_THREAD_DELAYED_FREE);
}

impl mi_heap_keys(heap: ptr[mi_heap_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](heap) + mi_heap_t_KEYS);
}

impl mi_heap_random(heap: ptr[mi_heap_t]) -> ptr[mi_random_ctx_t] {
    return ptr[mi_random_ctx_t](ptr[u8](heap) + mi_heap_t_RANDOM);
}

impl mi_heap_pages_free_direct(heap: ptr[mi_heap_t]) -> ptr[ptr[mi_page_t]] {
    return ptr[ptr[mi_page_t]](ptr[u8](heap) + mi_heap_t_PAGES_FREE_DIRECT);
}

impl mi_heap_pages(heap: ptr[mi_heap_t]) -> ptr[mi_page_queue_t] {
    return ptr[mi_page_queue_t](ptr[u8](heap) + mi_heap_t_PAGES);
}

impl mi_heap_page_queue(heap: ptr[mi_heap_t], bin: u64) -> ptr[mi_page_queue_t] {
    return mi_heap_pages(heap) + i64.wrap(bin);
}

impl mi_random_input(ctx: ptr[mi_random_ctx_t]) -> ptr[u32] {
    return ptr[u32](ptr[u8](ctx) + mi_random_ctx_t_INPUT);
}

impl mi_random_output(ctx: ptr[mi_random_ctx_t]) -> ptr[u32] {
    return ptr[u32](ptr[u8](ctx) + mi_random_ctx_t_OUTPUT);
}

impl mi_segment_memid(segment: ptr[mi_segment_t]) -> ptr[mi_memid_t] {
    return ptr[mi_memid_t](ptr[u8](segment) + mi_segment_t_MEMID);
}

impl mi_segment_purge_mask_of(segment: ptr[mi_segment_t]) -> ptr[mi_commit_mask_t] {
    return ptr[mi_commit_mask_t](ptr[u8](segment) + mi_segment_t_PURGE_MASK);
}

impl mi_segment_commit_mask_of(segment: ptr[mi_segment_t]) -> ptr[mi_commit_mask_t] {
    return ptr[mi_commit_mask_t](ptr[u8](segment) + mi_segment_t_COMMIT_MASK);
}

impl mi_segment_abandoned_next_addr(segment: ptr[mi_segment_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](segment) + mi_segment_t_ABANDONED_NEXT);
}

impl mi_segment_thread_id_addr(segment: ptr[mi_segment_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](segment) + mi_segment_t_THREAD_ID);
}

impl mi_segment_slices(segment: ptr[mi_segment_t]) -> ptr[mi_page_t] {
    return ptr[mi_page_t](ptr[u8](segment) + mi_segment_t_SLICES);
}

impl mi_tld_segments(tld: ptr[mi_tld_t]) -> ptr[mi_segments_tld_t] {
    return ptr[mi_segments_tld_t](ptr[u8](tld) + mi_tld_t_SEGMENTS);
}

impl mi_tld_os(tld: ptr[mi_tld_t]) -> ptr[mi_os_tld_t] {
    return ptr[mi_os_tld_t](ptr[u8](tld) + mi_tld_t_OS);
}

impl mi_tld_stats(tld: ptr[mi_tld_t]) -> ptr[mi_stats_t] {
    return ptr[mi_stats_t](ptr[u8](tld) + mi_tld_t_STATS);
}

impl mi_segments_tld_span_queue(
    tld: ptr[mi_segments_tld_t], bin: u64
) -> ptr[mi_span_queue_t] {
    return ptr[mi_span_queue_t](ptr[u8](tld) + mi_segments_tld_t_SPANS) + i64.wrap(bin);
}

impl mi_stat_count_at(stats: ptr[mi_stats_t], ofs: i64) -> ptr[mi_stat_count_t] {
    return ptr[mi_stat_count_t](ptr[u8](stats) + ofs);
}

impl mi_stat_counter_at(stats: ptr[mi_stats_t], ofs: i64) -> ptr[mi_stat_counter_t] {
    return ptr[mi_stat_counter_t](ptr[u8](stats) + ofs);
}

impl mi_heap_area_ex_area(xarea: ptr[mi_heap_area_ex_t]) -> ptr[mi_heap_area_t] {
    return ptr[mi_heap_area_t](xarea);
}

impl mi_numa_node_count_addr -> ptr[u64] {
    return ptr[u64](addressof(mi_globals));
}

impl mi_page_empty -> ptr[mi_page_t] {
    return addressof(_mi_page_empty);
}

impl mi_tld_main_link {
    tld = addressof(tld_main);
    segs = mi_tld_segments(tld);
    segs.view(1)[0].stats = mi_tld_stats(tld);
    segs.view(1)[0].os = mi_tld_os(tld);
    mi_tld_os(tld).view(1)[0].stats = mi_tld_stats(tld);
}

impl _mi_is_power_of_two(x: u64) -> bool {
    return (x & wrapping_sub(x, u64(1))) == u64(0);
}

impl _mi_is_aligned(p: ptr[u8], alignment: u64) -> bool {
    return (u64.wrap(int(p)) % alignment) == u64(0);
}

impl _mi_align_up(sz: u64, alignment: u64) -> u64 {
    mask = alignment - u64(1);
    if (alignment & mask) == u64(0) {
        return wrapping_add(sz, mask) & ~mask;
    }
    return (wrapping_add(sz, mask) // alignment) * alignment;
}

impl _mi_align_down(sz: u64, alignment: u64) -> u64 {
    mask = alignment - u64(1);
    if (alignment & mask) == u64(0) {
        return sz & ~mask;
    }
    return (sz // alignment) * alignment;
}

impl _mi_divide_up(size: u64, divider: u64) -> u64 {
    if divider == u64(0) {
        return size;
    }
    return wrapping_add(size, divider - u64(1)) // divider;
}

impl mi_mem_is_zero(p: ptr[u8], size: u64) -> bool {
    n = i64.wrap(size);
    i: i64 = 0;
    while i < n {
        if (p + i).view(1)[0] != u8(0) {
            return False;
        }
        i = i + 1;
    }
    return True;
}

impl _mi_wsize_from_size(size: u64) -> u64 {
    return wrapping_add(size, MI_INTPTR_SIZE - u64(1)) // MI_INTPTR_SIZE;
}

impl mi_mul_overflow(count: u64, size: u64) -> tuple[bool, u64] {
    total = wrapping_mul(count, size);
    if size == u64(0) {
        return (False, total);
    }
    return ((MI_SIZE_MAX // size) < count, total);
}

impl mi_count_size_overflow(count: u64, size: u64) -> tuple[bool, u64] {
    if count == u64(1) {
        return (False, size);
    }
    (overflow, total) = mi_mul_overflow(count, size);
    if overflow {
        return (True, MI_SIZE_MAX);
    }
    return (False, total);
}

impl _mi_random_shuffle(x: u64) -> u64 {
    v = x;
    if v == u64(0) {
        v = u64(17);
    }
    v = v ^ (v >> u64(30));
    v = wrapping_mul(v, MI_SHUFFLE_MUL1);
    v = v ^ (v >> u64(27));
    v = wrapping_mul(v, MI_SHUFFLE_MUL2);
    v = v ^ (v >> u64(31));
    return v;
}

impl mi_clz(x: u64) -> u64 {
    if x == u64(0) {
        return MI_INTPTR_BITS;
    }
    n: u64 = 0;
    v = x;
    if (v >> u64(32)) == u64(0) {
        n = n + u64(32);
        v = wrapping_shl(v, u64(32));
    }
    if (v >> u64(48)) == u64(0) {
        n = n + u64(16);
        v = wrapping_shl(v, u64(16));
    }
    if (v >> u64(56)) == u64(0) {
        n = n + u64(8);
        v = wrapping_shl(v, u64(8));
    }
    if (v >> u64(60)) == u64(0) {
        n = n + u64(4);
        v = wrapping_shl(v, u64(4));
    }
    if (v >> u64(62)) == u64(0) {
        n = n + u64(2);
        v = wrapping_shl(v, u64(2));
    }
    if (v >> u64(63)) == u64(0) {
        n = n + u64(1);
    }
    return n;
}

impl mi_ctz(x: u64) -> u64 {
    if x == u64(0) {
        return MI_INTPTR_BITS;
    }
    n: u64 = 0;
    v = x;
    if (v & u64(0xFFFFFFFF)) == u64(0) {
        n = n + u64(32);
        v = v >> u64(32);
    }
    if (v & u64(0xFFFF)) == u64(0) {
        n = n + u64(16);
        v = v >> u64(16);
    }
    if (v & u64(0xFF)) == u64(0) {
        n = n + u64(8);
        v = v >> u64(8);
    }
    if (v & u64(0xF)) == u64(0) {
        n = n + u64(4);
        v = v >> u64(4);
    }
    if (v & u64(0x3)) == u64(0) {
        n = n + u64(2);
        v = v >> u64(2);
    }
    if (v & u64(0x1)) == u64(0) {
        n = n + u64(1);
    }
    return n;
}

impl mi_bsr(x: u64) -> u64 {
    if x == u64(0) {
        return MI_INTPTR_BITS;
    }
    return MI_INTPTR_BITS - u64(1) - mi_clz(x);
}

impl mi_rotl(x: u64, shift: u64) -> u64 {
    s = shift % MI_INTPTR_BITS;
    if s == u64(0) {
        return x;
    }
    return wrapping_shl(x, s) | (x >> (MI_INTPTR_BITS - s));
}

impl mi_rotr(x: u64, shift: u64) -> u64 {
    s = shift % MI_INTPTR_BITS;
    if s == u64(0) {
        return x;
    }
    return (x >> s) | wrapping_shl(x, MI_INTPTR_BITS - s);
}

impl _mi_memcpy(dst: ptr, src: ptr, n: u64) {
    memcpy(dst, src, n);
}

impl _mi_memzero(dst: ptr, n: u64) {
    memset(dst, 0, n);
}

impl _mi_memcpy_aligned(dst: ptr, src: ptr, n: u64) {
    memcpy(dst, src, n);
}

impl _mi_memzero_aligned(dst: ptr, n: u64) {
    memset(dst, 0, n);
}

impl mi_heap_is_backing(heap: ptr[mi_heap_t]) -> bool {
    return heap.view(1)[0].tld.view(1)[0].heap_backing == heap;
}

impl mi_heap_is_initialized(heap: ptr[mi_heap_t]) -> bool {
    return heap != addressof(_mi_heap_empty);
}

impl _mi_ptr_cookie(p: ptr[u8]) -> u64 {
    return u64.wrap(int(p)) ^ addressof(_mi_heap_main).view(1)[0].cookie;
}

impl _mi_heap_get_free_small_page(heap: ptr[mi_heap_t], size: u64) -> ptr[mi_page_t] {
    idx = _mi_wsize_from_size(size);
    return (mi_heap_pages_free_direct(heap) + i64.wrap(idx)).view(1)[0];
}

impl _mi_ptr_segment(p: ptr[u8]) -> ptr[mi_segment_t] {
    return ptr[mi_segment_t](
        i64.wrap(wrapping_sub(u64.wrap(int(p)), u64(1)) & ~MI_SEGMENT_MASK)
    );
}

impl _mi_page_segment(page: ptr[mi_page_t]) -> ptr[mi_segment_t] {
    return _mi_ptr_segment(ptr[u8](page));
}

impl mi_slice_first(slice: ptr[mi_page_t]) -> ptr[mi_page_t] {
    return ptr[mi_page_t](
        ptr[u8](slice) + (i64(0) - i64(slice.view(1)[0].slice_offset))
    );
}

impl _mi_segment_page_of(segment: ptr[mi_segment_t], p: ptr[u8]) -> ptr[mi_page_t] {
    idx = i64.wrap(u64.wrap(int(p) - int(segment)) >> MI_SEGMENT_SLICE_SHIFT);
    return mi_slice_first(mi_segment_slices(segment) + idx);
}

impl _mi_page_start(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t]
) -> tuple[ptr[u8], u64] {
    return _mi_segment_page_start(segment, page);
}

impl _mi_ptr_page(p: ptr[u8]) -> ptr[mi_page_t] {
    return _mi_segment_page_of(_mi_ptr_segment(p), p);
}

impl mi_page_block_size(page: ptr[mi_page_t]) -> u64 {
    bsize = page.view(1)[0].xblock_size;
    if bsize < MI_HUGE_BLOCK_SIZE {
        return u64(bsize);
    }
    (start, psize) = _mi_segment_page_start(_mi_page_segment(page), page);
    return psize;
}

impl mi_page_is_huge(page: ptr[mi_page_t]) -> bool {
    return _mi_page_segment(page).view(1)[0].kind == MI_SEGMENT_HUGE;
}

impl mi_page_usable_block_size(page: ptr[mi_page_t]) -> u64 {
    return mi_page_block_size(page) - MI_PADDING_SIZE;
}

impl mi_segment_size(segment: ptr[mi_segment_t]) -> u64 {
    return segment.view(1)[0].segment_slices * MI_SEGMENT_SLICE_SIZE;
}

impl mi_segment_end(segment: ptr[mi_segment_t]) -> ptr[u8] {
    return ptr[u8](segment) + i64.wrap(mi_segment_size(segment));
}

impl mi_page_thread_free(page: ptr[mi_page_t]) -> ptr[mi_block_t] {
    return ptr[mi_block_t](
        i64.wrap(mi_atomic_load_relaxed(mi_page_xthread_free_addr(page)) & ~u64(3))
    );
}

impl mi_page_thread_free_flag(page: ptr[mi_page_t]) -> u64 {
    return mi_atomic_load_relaxed(mi_page_xthread_free_addr(page)) & u64(3);
}

impl mi_page_heap(page: ptr[mi_page_t]) -> ptr[mi_heap_t] {
    return ptr[mi_heap_t](i64.wrap(mi_atomic_load_relaxed(mi_page_xheap_addr(page))));
}

impl mi_page_set_heap(page: ptr[mi_page_t], heap: ptr[mi_heap_t]) {
    mi_atomic_store_release(mi_page_xheap_addr(page), u64.wrap(int(heap)));
}

impl mi_tf_block(tf: u64) -> ptr[mi_block_t] {
    return ptr[mi_block_t](i64.wrap(tf & ~u64(3)));
}

impl mi_tf_delayed(tf: u64) -> u64 {
    return tf & u64(3);
}

impl mi_tf_make(block: ptr[mi_block_t], delayed: u64) -> u64 {
    return u64.wrap(int(block)) | delayed;
}

impl mi_tf_set_delayed(tf: u64, delayed: u64) -> u64 {
    return (tf & ~u64(3)) | delayed;
}

impl mi_tf_set_block(tf: u64, block: ptr[mi_block_t]) -> u64 {
    return mi_tf_make(block, mi_tf_delayed(tf));
}

impl mi_page_all_free(page: ptr[mi_page_t]) -> bool {
    return page.view(1)[0].used == u32(0);
}

impl mi_page_has_any_available(page: ptr[mi_page_t]) -> bool {
    if page.view(1)[0].used < u32(page.view(1)[0].reserved) {
        return True;
    }
    if mi_page_thread_free(page) {
        return True;
    }
    return False;
}

impl mi_page_immediate_available(page: ptr[mi_page_t]) -> bool {
    if page.view(1)[0].free {
        return True;
    }
    return False;
}

impl mi_page_mostly_used(page: ptr[mi_page_t]) -> bool {
    if not page {
        return True;
    }
    reserved = u32(page.view(1)[0].reserved);
    frac = reserved // u32(8);
    return wrapping_sub(reserved, page.view(1)[0].used) <= frac;
}

impl mi_page_queue(heap: ptr[mi_heap_t], size: u64) -> ptr[mi_page_queue_t] {
    return mi_heap_page_queue(heap, u64(_mi_bin(size)));
}

impl mi_page_is_in_full(page: ptr[mi_page_t]) -> bool {
    return (page.view(1)[0].flags & MI_PAGE_FLAG_IN_FULL) != u8(0);
}

impl mi_page_set_in_full(page: ptr[mi_page_t], in_full: bool) {
    if in_full {
        page.view(1)[0].flags = page.view(1)[0].flags | MI_PAGE_FLAG_IN_FULL;
    } else {
        page.view(1)[0].flags = page.view(1)[0].flags & ~MI_PAGE_FLAG_IN_FULL;
    }
}

impl mi_page_has_aligned(page: ptr[mi_page_t]) -> bool {
    return (page.view(1)[0].flags & MI_PAGE_FLAG_HAS_ALIGNED) != u8(0);
}

impl mi_page_set_has_aligned(page: ptr[mi_page_t], has_aligned: bool) {
    if has_aligned {
        page.view(1)[0].flags = page.view(1)[0].flags | MI_PAGE_FLAG_HAS_ALIGNED;
    } else {
        page.view(1)[0].flags = page.view(1)[0].flags & ~MI_PAGE_FLAG_HAS_ALIGNED;
    }
}

impl mi_is_in_same_segment(p: ptr[u8], q: ptr[u8]) -> bool {
    return _mi_ptr_segment(p) == _mi_ptr_segment(q);
}

impl mi_is_in_same_page(p: ptr[u8], q: ptr[u8]) -> bool {
    segment = _mi_ptr_segment(p);
    if _mi_ptr_segment(q) != segment {
        return False;
    }
    page = _mi_segment_page_of(segment, p);
    (start, psize) = _mi_segment_page_start(segment, page);
    return int(start) <= int(q) and int(q) < int(start) + i64.wrap(psize);
}

impl mi_ptr_decode(null_: ptr[u8], x: u64, keys: ptr[u64]) -> ptr[u8] {
    k0 = keys.view(2)[0];
    p = mi_rotr(wrapping_sub(x, k0), k0) ^ keys.view(2)[1];
    if p == u64.wrap(int(null_)) {
        return ptr[u8]();
    }
    return ptr[u8](i64.wrap(p));
}

impl mi_ptr_encode(null_: ptr[u8], p: ptr[u8], keys: ptr[u64]) -> u64 {
    x = u64.wrap(int(p));
    if not p {
        x = u64.wrap(int(null_));
    }
    k0 = keys.view(2)[0];
    return wrapping_add(mi_rotl(x ^ keys.view(2)[1], k0), k0);
}

impl mi_block_nextx(
    null_: ptr[u8], block: ptr[mi_block_t], keys: ptr[u64]
) -> ptr[mi_block_t] {
    return ptr[mi_block_t](__atomic_load_i64(int(block), 0));
}

impl mi_block_set_nextx(
    null_: ptr[u8], block: ptr[mi_block_t], next: ptr[mi_block_t], keys: ptr[u64]
) {
    __atomic_store_i64(int(block), int(next), 0);
}

impl mi_block_next(page: ptr[mi_page_t], block: ptr[mi_block_t]) -> ptr[mi_block_t] {
    return ptr[mi_block_t](__atomic_load_i64(int(block), 0));
}

impl mi_block_set_next(
    page: ptr[mi_page_t], block: ptr[mi_block_t], next: ptr[mi_block_t]
) {
    __atomic_store_i64(int(block), int(next), 0);
}

impl mi_commit_mask_create_empty(cm: ptr[mi_commit_mask_t]) {
    m = ptr[u64](cm);
    for i in range(8) {
        (m + i).view(1)[0] = u64(0);
    }
}

impl mi_commit_mask_create_full(cm: ptr[mi_commit_mask_t]) {
    m = ptr[u64](cm);
    for i in range(8) {
        (m + i).view(1)[0] = ~u64(0);
    }
}

impl mi_commit_mask_is_empty(cm: ptr[mi_commit_mask_t]) -> bool {
    m = ptr[u64](cm);
    for i in range(8) {
        if (m + i).view(1)[0] != u64(0) {
            return False;
        }
    }
    return True;
}

impl mi_commit_mask_is_full(cm: ptr[mi_commit_mask_t]) -> bool {
    m = ptr[u64](cm);
    for i in range(8) {
        if (m + i).view(1)[0] != ~u64(0) {
            return False;
        }
    }
    return True;
}

impl mi_memkind_is_os(memkind: i32) -> bool {
    return memkind >= MI_MEM_OS and memkind <= MI_MEM_OS_REMAP;
}

impl mi_memid_init(memid: ptr[mi_memid_t], memkind: i32) {
    memset(ptr(memid), 0, mi_memid_t_SIZE);
    memid.view(1)[0].memkind = memkind;
}

impl mi_memid_init_none(memid: ptr[mi_memid_t]) {
    mi_memid_init(memid, MI_MEM_NONE);
}

impl mi_memid_init_os(
    memid: ptr[mi_memid_t], committed: bool, is_zero: bool, is_large: bool
) {
    mi_memid_init(memid, MI_MEM_OS);
    memid.view(1)[0].initially_committed = committed;
    memid.view(1)[0].initially_zero = is_zero;
    memid.view(1)[0].is_pinned = is_large;
}

impl mi_memid_copy(dst: ptr[mi_memid_t], src: ptr[mi_memid_t]) {
    memcpy(ptr(dst), ptr(src), mi_memid_t_SIZE);
}

impl mi_memid_arena_block_index(memid: ptr[mi_memid_t]) -> u64 {
    return ptr[u64](memid).view(1)[0];
}

impl mi_memid_set_arena_block_index(memid: ptr[mi_memid_t], block_index: u64) {
    ptr[u64](memid).view(1)[0] = block_index;
}

impl mi_memid_arena_id(memid: ptr[mi_memid_t]) -> i32 {
    return ptr[i32](ptr[u8](memid) + 8).view(1)[0];
}

impl mi_memid_set_arena_id(memid: ptr[mi_memid_t], id: i32) {
    ptr[i32](ptr[u8](memid) + 8).view(1)[0] = id;
}

impl mi_memid_arena_is_exclusive(memid: ptr[mi_memid_t]) -> bool {
    return (ptr[u8](memid) + 12).view(1)[0] != u8(0);
}

impl mi_memid_set_arena_is_exclusive(memid: ptr[mi_memid_t], is_exclusive: bool) {
    if is_exclusive {
        (ptr[u8](memid) + 12).view(1)[0] = u8(1);
    } else {
        (ptr[u8](memid) + 12).view(1)[0] = u8(0);
    }
}

impl _mi_os_numa_node(tld: ptr[mi_os_tld_t]) -> i32 {
    if mi_atomic_load_relaxed(mi_numa_node_count_addr()) == u64(1) {
        return i32(0);
    }
    return _mi_os_numa_node_get(tld);
}

impl _mi_os_numa_node_count -> u64 {
    count = mi_atomic_load_relaxed(mi_numa_node_count_addr());
    if count > u64(0) {
        return count;
    }
    return _mi_os_numa_node_count_get();
}


impl mi_alloc_count_size_overflows(count: u64, size: u64) -> bool {
    if count == u64(1) {
        return False;
    }
    if size < MI_ALLOC_MUL_NO_OVERFLOW and count < MI_ALLOC_MUL_NO_OVERFLOW {
        return False;
    }
    if size == u64(0) {
        return False;
    }
    return (MI_SIZE_MAX // size) < count;
}

impl _mi_page_malloc(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t], size: u64, zero: bool
) -> ptr[u8] {
    block = page.view(1)[0].free;
    if not block {
        return _mi_malloc_generic(heap, size, zero, u64(0));
    }

    page.view(1)[0].used = wrapping_add(page.view(1)[0].used, u32(1));
    page.view(1)[0].free = mi_block_next(page, block);

    if zero {
        if page.view(1)[0].free_is_zero {
            block.view(1)[0].next = u64(0);
        } else {
            _mi_memzero_aligned(
                ptr(block), u64(page.view(1)[0].xblock_size) - MI_PADDING_SIZE
            );
        }
    }
    return ptr[u8](block);
}

impl mi_heap_malloc_small_zero(heap: ptr[mi_heap_t], size: u64, zero: bool) -> ptr[u8] {
    page = _mi_heap_get_free_small_page(heap, size + MI_PADDING_SIZE);
    return _mi_page_malloc(heap, page, size + MI_PADDING_SIZE, zero);
}

impl _mi_heap_malloc_zero_ex(
    heap: ptr[mi_heap_t], size: u64, zero: bool, huge_alignment: u64
) -> ptr[u8] {
    if size <= MI_SMALL_SIZE_MAX {
        return mi_heap_malloc_small_zero(heap, size, zero);
    }

    return _mi_malloc_generic(
        heap, wrapping_add(size, MI_PADDING_SIZE), zero, huge_alignment
    );
}

impl _mi_heap_malloc_zero(heap: ptr[mi_heap_t], size: u64, zero: bool) -> ptr[u8] {
    return _mi_heap_malloc_zero_ex(heap, size, zero, u64(0));
}

impl mi_page_usable_size_of(page: ptr[mi_page_t], block: ptr[mi_block_t]) -> u64 {
    return mi_page_usable_block_size(page);
}

impl _mi_padding_shrink(page: ptr[mi_page_t], block: ptr[mi_block_t], min_size: u64) {
    return;
}

impl _mi_free_block_mt(page: ptr[mi_page_t], block: ptr[mi_block_t]) {
    _mi_padding_shrink(page, block, mi_block_t_SIZE);
    segment = _mi_page_segment(page);
    if segment.view(1)[0].kind == MI_SEGMENT_HUGE {
        _mi_segment_huge_page_reset(segment, page, block);
    }

    xtf = mi_page_xthread_free_addr(page);
    tfreex: u64 = 0;
    use_delayed = False;
    tfree = mi_atomic_load_relaxed(xtf);
    while True {
        use_delayed = mi_tf_delayed(tfree) == MI_USE_DELAYED_FREE;
        if use_delayed {
            tfreex = mi_tf_set_delayed(tfree, MI_DELAYED_FREEING);
        } else {
            mi_block_set_next(page, block, mi_tf_block(tfree));
            tfreex = mi_tf_set_block(tfree, block);
        }
        (ok, seen) = mi_atomic_cas_weak_release(xtf, tfree, tfreex);
        if ok {
            break;
        }
        tfree = seen;
    }
    if use_delayed {
        heap = ptr[mi_heap_t](
            i64.wrap(mi_atomic_load_acquire(mi_page_xheap_addr(page)))
        );
        if heap {
            tdf = mi_heap_thread_delayed_free_addr(heap);
            dfree = mi_atomic_load_relaxed(tdf);
            while True {
                mi_block_set_nextx(
                    ptr[u8](heap),
                    block,
                    ptr[mi_block_t](i64.wrap(dfree)),
                    mi_heap_keys(heap)
                );
                (dok, dseen) = mi_atomic_cas_weak_release(
                    tdf, dfree, u64.wrap(int(block))
                );
                if dok {
                    break;
                }
                dfree = dseen;
            }
        }

        tfree = mi_atomic_load_relaxed(xtf);
        while True {
            tfreex = mi_tf_set_delayed(tfree, MI_NO_DELAYED_FREE);
            (rok, rseen) = mi_atomic_cas_weak_release(xtf, tfree, tfreex);
            if rok {
                break;
            }
            tfree = rseen;
        }
    }
}

impl _mi_free_block(page: ptr[mi_page_t], local: bool, block: ptr[mi_block_t]) {
    if local {
        mi_block_set_next(page, block, page.view(1)[0].local_free);
        page.view(1)[0].local_free = block;
        page.view(1)[0].used = wrapping_sub(page.view(1)[0].used, u32(1));
        if mi_page_all_free(page) {
            _mi_page_retire(page);
        } elif mi_page_is_in_full(page) {
            _mi_page_unfull(page);
        }
    } else {
        _mi_free_block_mt(page, block);
    }
}

impl _mi_page_ptr_unalign(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], p: ptr[u8]
) -> ptr[mi_block_t] {
    (start, psize) = _mi_page_start(segment, page);
    diff = u64.wrap(int(p) - int(start));
    adjust = diff % mi_page_block_size(page);
    return ptr[mi_block_t](i64.wrap(wrapping_sub(u64.wrap(int(p)), adjust)));
}

impl _mi_free_generic(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], is_local: bool, p: ptr[u8]
) {
    block = ptr[mi_block_t](p);
    if mi_page_has_aligned(page) {
        block = _mi_page_ptr_unalign(segment, page, p);
    }
    _mi_free_block(page, is_local, block);
}

impl mi_checked_ptr_segment(p: ptr[u8]) -> ptr[mi_segment_t] {
    return _mi_ptr_segment(p);
}

impl mi_alloc_free(p: ptr[u8]) {
    if not p {
        return;
    }
    segment = mi_checked_ptr_segment(p);
    is_local = _mi_prim_thread_id()
        == mi_atomic_load_relaxed(mi_segment_thread_id_addr(segment));
    page = _mi_segment_page_of(segment, p);
    if is_local {
        if page.view(1)[0].flags == u8(0) {
            block = ptr[mi_block_t](p);
            mi_block_set_next(page, block, page.view(1)[0].local_free);
            page.view(1)[0].local_free = block;
            used = wrapping_sub(page.view(1)[0].used, u32(1));
            page.view(1)[0].used = used;
            if used == u32(0) {
                _mi_page_retire(page);
            }
        } else {
            _mi_free_generic(segment, page, True, p);
        }
    } else {
        _mi_free_generic(segment, page, False, p);
    }
}

impl _mi_free_delayed_block(block: ptr[mi_block_t]) -> bool {
    segment = _mi_ptr_segment(ptr[u8](block));
    page = _mi_segment_page_of(segment, ptr[u8](block));

    if not _mi_page_try_use_delayed_free(page, MI_USE_DELAYED_FREE, False) {
        return False;
    }

    _mi_page_free_collect(page, False);

    _mi_free_block(page, True, block);
    return True;
}

impl mi_page_usable_aligned_size_of(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], p: ptr[u8]
) -> u64 {
    block = _mi_page_ptr_unalign(segment, page, p);
    size = mi_page_usable_size_of(page, block);
    adjust = int(p) - int(block);

    return wrapping_sub(size, u64.wrap(adjust));
}

impl _mi_usable_size(p: ptr[u8]) -> u64 {
    if not p {
        return u64(0);
    }
    segment = mi_checked_ptr_segment(p);
    page = _mi_segment_page_of(segment, p);
    if not mi_page_has_aligned(page) {
        return mi_page_usable_size_of(page, ptr[mi_block_t](p));
    }

    return mi_page_usable_aligned_size_of(segment, page, p);
}

impl mi_alloc_heap_calloc(heap: ptr[mi_heap_t], count: u64, size: u64) -> ptr[u8] {
    if mi_alloc_count_size_overflows(count, size) {
        return ptr[u8]();
    }
    return _mi_heap_malloc_zero(heap, wrapping_mul(count, size), True);
}

impl _mi_heap_realloc_zero(
    heap: ptr[mi_heap_t], p: ptr[u8], newsize: u64, zero: bool
) -> ptr[u8] {
    size = _mi_usable_size(p);

    if newsize <= size and newsize >= (size // u64(2)) and newsize > u64(0) {
        return p;
    }
    newp = _mi_heap_malloc_zero(heap, newsize, False);
    if newp {
        if zero and newsize > size {
            start: u64 = 0;
            if size >= MI_INTPTR_SIZE {
                start = size - MI_INTPTR_SIZE;
            }
            _mi_memzero(ptr(newp + i64.wrap(start)), newsize - start);
        } elif newsize == u64(0) {
            newp.view(1)[0] = u8(0);
        }
        if p {
            copysize = newsize;
            if newsize > size {
                copysize = size;
            }
            _mi_memcpy(ptr(newp), ptr(p), copysize);

            mi_alloc_free(p);
        }
    }
    return newp;
}

impl _Py__ZSt15get_new_handlerv -> ptr {
    return ptr();
}

impl mi_get_new_handler -> ptr {
    return _Py__ZSt15get_new_handlerv();
}

impl mi_try_new_handler(nothrow: bool) -> bool {
    h = mi_get_new_handler();
    if int(h) == 0 {
        _mi_error_message(
            ENOMEM,
            ptr[u8]("out of memory in 'new'"),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        if not nothrow {
            abort();
        }
        return False;
    }
    mi_call_void(h);
    return True;
}

impl mi_try_new(size: u64, nothrow: bool) -> ptr {
    return mi_heap_try_new(ptr(mi_prim_get_default_heap()), size, nothrow);
}


impl mi_heap_malloc_zero_aligned_at_fallback(
    heap: ptr[mi_heap_t], size: u64, alignment: u64, offset: u64, zero: bool
) -> ptr[u8] {
    align_mask = alignment - u64(1);
    padsize = size + MI_PADDING_SIZE;

    if offset == u64(0)
        and alignment <= padsize
        and padsize <= MI_MAX_ALIGN_GUARANTEE
        and (padsize & align_mask) == u64(0) {
        return _mi_heap_malloc_zero(heap, size, zero);
    }
    p = ptr[u8]();
    oversize: u64 = 0;
    if alignment > MI_ALIGNMENT_MAX {
        if offset != u64(0) {
            return ptr[u8]();
        }

        oversize = size;
        if size <= MI_SMALL_SIZE_MAX {
            oversize = MI_SMALL_SIZE_MAX + u64(1);
        }

        p = _mi_heap_malloc_zero_ex(heap, oversize, False, alignment);

        if not p {
            return ptr[u8]();
        }
    } else {
        oversize = size + alignment - u64(1);
        p = _mi_heap_malloc_zero(heap, oversize, zero);
        if not p {
            return ptr[u8]();
        }
    }

    poffset = wrapping_add(u64.wrap(int(p)), offset) & align_mask;
    adjust: u64 = 0;
    if poffset != u64(0) {
        adjust = alignment - poffset;
    }
    aligned_p = p + i64.wrap(adjust);
    if aligned_p != p {
        page = _mi_ptr_page(p);
        mi_page_set_has_aligned(page, True);
        _mi_padding_shrink(page, ptr[mi_block_t](p), adjust + size);
    }

    if alignment > MI_ALIGNMENT_MAX {
        if zero {
            _mi_memzero_aligned(ptr(aligned_p), _mi_usable_size(aligned_p));
        }
    }
    return aligned_p;
}

impl mi_heap_malloc_zero_aligned_at(
    heap: ptr[mi_heap_t], size: u64, alignment: u64, offset: u64, zero: bool
) -> ptr[u8] {
    if alignment == u64(0) or not _mi_is_power_of_two(alignment) {
        return ptr[u8]();
    }

    if size > MI_ALLOC_ALIGNED_PTRDIFF_MAX {
        return ptr[u8]();
    }

    align_mask = alignment - u64(1);

    padsize = size + MI_PADDING_SIZE;

    if padsize <= MI_SMALL_SIZE_MAX and alignment <= padsize {
        page = _mi_heap_get_free_small_page(heap, padsize);
        free_ = page.view(1)[0].free;
        is_aligned = (wrapping_add(u64.wrap(int(free_)), offset) & align_mask)
            == u64(0);
        if free_ {
            if is_aligned {
                return _mi_page_malloc(heap, page, padsize, zero);
            }
        }
    }

    return mi_heap_malloc_zero_aligned_at_fallback(heap, size, alignment, offset, zero);
}

impl mi_heap_realloc_zero_aligned_at(
    heap: ptr[mi_heap_t],
    p: ptr[u8],
    newsize: u64,
    alignment: u64,
    offset: u64,
    zero: bool
) -> ptr[u8] {
    if alignment <= MI_INTPTR_SIZE {
        return _mi_heap_realloc_zero(heap, p, newsize, zero);
    }
    if not p {
        return mi_heap_malloc_zero_aligned_at(heap, newsize, alignment, offset, zero);
    }
    size = _mi_usable_size(p);
    if newsize <= size
        and newsize >= (size - (size // u64(2)))
        and (wrapping_add(u64.wrap(int(p)), offset) % alignment) == u64(0) {
        return p;
    }

    newp = mi_heap_malloc_zero_aligned_at(heap, newsize, alignment, offset, False);
    if newp {
        if zero and newsize > size {
            start: u64 = 0;
            if size >= MI_INTPTR_SIZE {
                start = size - MI_INTPTR_SIZE;
            }
            _mi_memzero(ptr(newp + i64.wrap(start)), newsize - start);
        }
        copysize = newsize;
        if newsize > size {
            copysize = size;
        }
        _mi_memcpy_aligned(ptr(newp), ptr(p), copysize);

        mi_alloc_free(p);
    }
    return newp;
}

impl mi_heap_realloc_zero_aligned(
    heap: ptr[mi_heap_t], p: ptr[u8], newsize: u64, alignment: u64, zero: bool
) -> ptr[u8] {
    if alignment <= MI_INTPTR_SIZE {
        return _mi_heap_realloc_zero(heap, p, newsize, zero);
    }

    offset = u64.wrap(int(p)) % alignment;
    return mi_heap_realloc_zero_aligned_at(heap, p, newsize, alignment, offset, zero);
}


impl mi_arenas_slot(i: u64) -> ptr[u64] {
    return ptr[u64](addressof(mi_arenas)) + i64.wrap(i);
}

impl mi_arenas_load_acquire(i: u64) -> ptr[mi_arena_t] {
    return ptr[mi_arena_t](i64.wrap(mi_atomic_load_acquire(mi_arenas_slot(i))));
}

impl mi_arena_count_addr -> ptr[u64] {
    return mi_word_addr(ptr[u8](addressof(mi_arena_state)), mi_arena_state_ARENA_COUNT);
}

impl mi_arena_static_top_addr -> ptr[u64] {
    return mi_word_addr(ptr[u8](addressof(mi_arena_state)), mi_arena_state_STATIC_TOP);
}

impl mi_arena_purge_guard_addr -> ptr[u64] {
    return mi_word_addr(ptr[u8](addressof(mi_arena_state)), mi_arena_state_PURGE_GUARD);
}

impl mi_arena_memid_of(arena: ptr[mi_arena_t]) -> ptr[mi_memid_t] {
    return ptr[mi_memid_t](ptr[u8](arena) + mi_arena_t_MEMID);
}

impl mi_arena_meta_memid_of(arena: ptr[mi_arena_t]) -> ptr[mi_memid_t] {
    return ptr[mi_memid_t](ptr[u8](arena) + mi_arena_t_META_MEMID);
}

impl mi_arena_start_addr(arena: ptr[mi_arena_t]) -> ptr[u64] {
    return mi_word_addr(ptr[u8](arena), mi_arena_t_START);
}

impl mi_arena_search_idx_addr(arena: ptr[mi_arena_t]) -> ptr[u64] {
    return mi_word_addr(ptr[u8](arena), mi_arena_t_SEARCH_IDX);
}

impl mi_arena_purge_expire_addr(arena: ptr[mi_arena_t]) -> ptr[i64] {
    return ptr[i64](ptr[u8](arena) + mi_arena_t_PURGE_EXPIRE);
}

impl mi_arena_start_of(arena: ptr[mi_arena_t]) -> ptr[u8] {
    return ptr[u8](i64.wrap(mi_atomic_load_acquire(mi_arena_start_addr(arena))));
}

impl mi_arena_blocks_inuse_of(arena: ptr[mi_arena_t]) -> ptr[u64] {
    return ptr[u64](ptr[u8](arena) + mi_arena_t_BLOCKS_INUSE);
}

impl mi_arena_id_index(id: i32) -> u64 {
    if id <= 0 {
        return MI_MAX_ARENAS;
    }
    return u64(id - 1);
}

impl mi_arena_id_create(arena_index: u64) -> i32 {
    return i32.wrap(arena_index) + 1;
}

impl _mi_arena_id_none -> i32 {
    return i32(0);
}

impl mi_arena_id_is_suitable(
    arena_id: i32, arena_is_exclusive: bool, req_arena_id: i32
) -> bool {
    return (not arena_is_exclusive and req_arena_id == _mi_arena_id_none())
        or (arena_id == req_arena_id);
}

impl _mi_arena_memid_is_suitable(
    memid: ptr[mi_memid_t], request_arena_id: i32
) -> bool {
    if memid.view(1)[0].memkind == MI_MEM_ARENA {
        return mi_arena_id_is_suitable(
            mi_memid_arena_id(memid),
            mi_memid_arena_is_exclusive(memid),
            request_arena_id
        );
    }
    return mi_arena_id_is_suitable(i32(0), False, request_arena_id);
}

impl _mi_arena_memid_is_os_allocated(memid: ptr[mi_memid_t]) -> bool {
    return memid.view(1)[0].memkind == MI_MEM_OS;
}

impl mi_block_count_of_size(size: u64) -> u64 {
    return _mi_divide_up(size, MI_ARENA_BLOCK_SIZE);
}

impl mi_arena_block_size(bcount: u64) -> u64 {
    return wrapping_mul(bcount, MI_ARENA_BLOCK_SIZE);
}

impl mi_arena_size(arena: ptr[mi_arena_t]) -> u64 {
    return mi_arena_block_size(arena.view(1)[0].block_count);
}

impl mi_memid_create_arena(
    memid: ptr[mi_memid_t], id: i32, is_exclusive: bool, bitmap_index: u64
) {
    mi_memid_init(memid, MI_MEM_ARENA);
    mi_memid_set_arena_id(memid, id);
    mi_memid_set_arena_block_index(memid, bitmap_index);
    mi_memid_set_arena_is_exclusive(memid, is_exclusive);
}

impl mi_arena_memid_indices(memid: ptr[mi_memid_t]) -> tuple[bool, u64, u64] {
    arena_index = mi_arena_id_index(mi_memid_arena_id(memid));
    bitmap_index = mi_memid_arena_block_index(memid);
    return (mi_memid_arena_is_exclusive(memid), arena_index, bitmap_index);
}

impl mi_arena_static_zalloc(
    size: u64, alignment: u64, memid: ptr[mi_memid_t]
) -> ptr[u8] {
    mi_memid_init_none(memid);
    if size == u64(0) or size > MI_ARENA_STATIC_MAX {
        return ptr[u8]();
    }
    if wrapping_add(mi_atomic_load_relaxed(mi_arena_static_top_addr()), size)
        > MI_ARENA_STATIC_MAX {
        return ptr[u8]();
    }

    align = alignment;
    if align == u64(0) {
        align = u64(1);
    }
    oversize = wrapping_add(size, align - u64(1));
    if oversize > MI_ARENA_STATIC_MAX {
        return ptr[u8]();
    }
    oldtop = mi_atomic_add_acq_rel(mi_arena_static_top_addr(), oversize);
    top = wrapping_add(oldtop, oversize);
    if top > MI_ARENA_STATIC_MAX {
        mi_atomic_cas_strong_acq_rel(mi_arena_static_top_addr(), top, oldtop);
        return ptr[u8]();
    }

    mi_memid_init(memid, MI_MEM_STATIC);
    start = _mi_align_up(oldtop, align);
    p = ptr[u8](addressof(mi_arena_static)) + i64.wrap(start);
    _mi_memzero(ptr(p), size);
    return p;
}

impl mi_arena_meta_zalloc(
    size: u64, memid: ptr[mi_memid_t], stats: ptr[mi_stats_t]
) -> ptr[u8] {
    mi_memid_init_none(memid);

    p = mi_arena_static_zalloc(size, MI_ALIGNMENT_MAX, memid);
    if p {
        return p;
    }

    return _mi_os_alloc(size, memid, stats);
}

impl mi_arena_meta_free(
    p: ptr[u8], memid: ptr[mi_memid_t], size: u64, stats: ptr[mi_stats_t]
) {
    if mi_memkind_is_os(memid.view(1)[0].memkind) {
        _mi_os_free(p, size, memid, stats);
    }
}

impl mi_arena_block_start(arena: ptr[mi_arena_t], bindex: u64) -> ptr[u8] {
    return mi_arena_start_of(arena)
        + i64.wrap(mi_arena_block_size(mi_bitmap_index_bit(bindex)));
}

impl mi_arena_try_claim(arena: ptr[mi_arena_t], blocks: u64) -> tuple[bool, u64] {
    idx: u64 = 0;
    (found, bitmap_idx) = _mi_bitmap_try_find_from_claim_across(
        mi_arena_blocks_inuse_of(arena), arena.view(1)[0].field_count, idx, blocks
    );
    if found {
        mi_atomic_store_relaxed(
            mi_arena_search_idx_addr(arena), mi_bitmap_index_field(bitmap_idx)
        );
        return (True, bitmap_idx);
    }
    return (False, bitmap_idx);
}

impl mi_arena_try_alloc_at(
    arena: ptr[mi_arena_t],
    arena_index: u64,
    needed_bcount: u64,
    commit: bool,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8] {
    (claimed, bitmap_index) = mi_arena_try_claim(arena, needed_bcount);
    if not claimed {
        return ptr[u8]();
    }

    p = mi_arena_block_start(arena, bitmap_index);
    amemid = mi_arena_memid_of(arena);
    mi_memid_create_arena(
        memid, arena.view(1)[0].id, arena.view(1)[0].exclusive, bitmap_index
    );
    memid.view(1)[0].is_pinned = amemid.view(1)[0].is_pinned;
    field_count = arena.view(1)[0].field_count;

    if arena.view(1)[0].blocks_purge {
        _mi_bitmap_unclaim_across(
            arena.view(1)[0].blocks_purge, field_count, needed_bcount, bitmap_index
        );
    }

    if amemid.view(1)[0].initially_zero and arena.view(1)[0].blocks_dirty {
        (all_zero, dirty_any_zero) = _mi_bitmap_claim_across(
            arena.view(1)[0].blocks_dirty, field_count, needed_bcount, bitmap_index
        );
        memid.view(1)[0].initially_zero = all_zero;
    }

    if not arena.view(1)[0].blocks_committed {
        memid.view(1)[0].initially_committed = True;
    } elif commit {
        memid.view(1)[0].initially_committed = True;
        (all_uncommitted, any_uncommitted) = _mi_bitmap_claim_across(
            arena.view(1)[0].blocks_committed, field_count, needed_bcount, bitmap_index
        );
        if any_uncommitted {
            (commit_ok, commit_zero) = _mi_os_commit(
                p, mi_arena_block_size(needed_bcount), tld.view(1)[0].stats
            );
            if not commit_ok {
                memid.view(1)[0].initially_committed = False;
            } elif commit_zero {
                memid.view(1)[0].initially_zero = True;
            }
        }
    } else {
        memid.view(1)[0].initially_committed = _mi_bitmap_is_claimed_across(
            arena.view(1)[0].blocks_committed, field_count, needed_bcount, bitmap_index
        );
    }
    return p;
}

impl mi_arena_try_alloc_at_id(
    arena_id: i32,
    match_numa_node: bool,
    numa_node: i32,
    size: u64,
    alignment: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8] {
    bcount = mi_block_count_of_size(size);
    arena_index = mi_arena_id_index(arena_id);

    arena = mi_arenas_load_acquire(arena_index);
    if not arena {
        return ptr[u8]();
    }
    if not allow_large and arena.view(1)[0].is_large {
        return ptr[u8]();
    }
    if not mi_arena_id_is_suitable(
        arena.view(1)[0].id, arena.view(1)[0].exclusive, req_arena_id
    ) {
        return ptr[u8]();
    }
    if req_arena_id == _mi_arena_id_none() {
        arena_numa = arena.view(1)[0].numa_node;
        numa_suitable = numa_node < 0 or arena_numa < 0 or arena_numa == numa_node;
        if match_numa_node {
            if not numa_suitable {
                return ptr[u8]();
            }
        } else {
            if numa_suitable {
                return ptr[u8]();
            }
        }
    }

    return mi_arena_try_alloc_at(arena, arena_index, bcount, commit, memid, tld);
}

impl mi_arena_try_alloc(
    numa_node: i32,
    size: u64,
    alignment: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8] {
    max_arena = mi_atomic_load_relaxed(mi_arena_count_addr());
    if max_arena == u64(0) {
        return ptr[u8]();
    }
    if req_arena_id != _mi_arena_id_none() {
        if mi_arena_id_index(req_arena_id) < max_arena {
            p = mi_arena_try_alloc_at_id(
                req_arena_id,
                True,
                numa_node,
                size,
                alignment,
                commit,
                allow_large,
                req_arena_id,
                memid,
                tld
            );
            if p {
                return p;
            }
        }
    } else {
        i: u64 = 0;
        while i < max_arena {
            q = mi_arena_try_alloc_at_id(
                mi_arena_id_create(i),
                True,
                numa_node,
                size,
                alignment,
                commit,
                allow_large,
                req_arena_id,
                memid,
                tld
            );
            if q {
                return q;
            }
            i = i + u64(1);
        }
        if numa_node >= 0 {
            j: u64 = 0;
            while j < max_arena {
                r = mi_arena_try_alloc_at_id(
                    mi_arena_id_create(j),
                    False,
                    numa_node,
                    size,
                    alignment,
                    commit,
                    allow_large,
                    req_arena_id,
                    memid,
                    tld
                );
                if r {
                    return r;
                }
                j = j + u64(1);
            }
        }
    }
    return ptr[u8]();
}

impl mi_arena_reserve(
    req_size: u64, allow_large: bool, req_arena_id: i32
) -> tuple[bool, i32] {
    if _mi_preloading() {
        return (False, i32(0));
    }
    if req_arena_id != _mi_arena_id_none() {
        return (False, i32(0));
    }
    arena_count = mi_atomic_load_acquire(mi_arena_count_addr());
    if arena_count > (MI_MAX_ARENAS - u64(4)) {
        return (False, i32(0));
    }
    arena_reserve = mi_option_get_size(mi_option_arena_reserve);
    if arena_reserve == u64(0) {
        return (False, i32(0));
    }
    if not _mi_os_has_virtual_reserve() {
        arena_reserve = arena_reserve // u64(4);
    }
    arena_reserve = _mi_align_up(arena_reserve, MI_ARENA_BLOCK_SIZE);
    if arena_count >= u64(8) and arena_count <= u64(128) {
        arena_reserve = wrapping_mul(
            wrapping_shl(u64(1), arena_count // u64(8)), arena_reserve
        );
    }

    if arena_reserve < req_size {
        return (False, i32(0));
    }

    arena_commit = False;
    if mi_option_get(mi_option_arena_eager_commit) == 2 {
        arena_commit = _mi_os_has_overcommit();
    } elif mi_option_get(mi_option_arena_eager_commit) == 1 {
        arena_commit = True;
    }
    (err, arena_id) = mi_arena_reserve_os_memory(
        arena_reserve, arena_commit, allow_large, False
    );
    return (err == 0, arena_id);
}

impl _mi_arena_alloc_aligned(
    size: u64,
    alignment: u64,
    align_offset: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8] {
    mi_memid_init_none(memid);

    numa_node = _mi_os_numa_node(tld);

    if size >= MI_ARENA_MIN_OBJ_SIZE
        and alignment <= MI_SEGMENT_ALIGN
        and align_offset == u64(0) {
        p = mi_arena_try_alloc(
            numa_node, size, alignment, commit, allow_large, req_arena_id, memid, tld
        );
        if p {
            return p;
        }

        if req_arena_id == _mi_arena_id_none() {
            (reserved, arena_id) = mi_arena_reserve(size, allow_large, req_arena_id);
            if reserved {
                q = mi_arena_try_alloc_at_id(
                    arena_id,
                    True,
                    numa_node,
                    size,
                    alignment,
                    commit,
                    allow_large,
                    req_arena_id,
                    memid,
                    tld
                );
                if q {
                    return q;
                }
            }
        }
    }

    if mi_option_is_enabled(mi_option_limit_os_alloc)
        or req_arena_id != _mi_arena_id_none() {
        jacpy_set_errno(i64(ENOMEM));
        return ptr[u8]();
    }

    if align_offset > u64(0) {
        return _mi_os_alloc_aligned_at_offset(
            size,
            alignment,
            align_offset,
            commit,
            allow_large,
            memid,
            tld.view(1)[0].stats
        );
    }
    return _mi_os_alloc_aligned(
        size, alignment, commit, allow_large, memid, tld.view(1)[0].stats
    );
}

impl _mi_arena_alloc(
    size: u64,
    commit: bool,
    allow_large: bool,
    req_arena_id: i32,
    memid: ptr[mi_memid_t],
    tld: ptr[mi_os_tld_t]
) -> ptr[u8] {
    return _mi_arena_alloc_aligned(
        size, MI_ARENA_BLOCK_SIZE, u64(0), commit, allow_large, req_arena_id, memid, tld
    );
}

impl mi_arena_purge_delay -> i64 {
    return mi_option_get(mi_option_purge_delay)
        * mi_option_get(mi_option_arena_purge_mult);
}

impl mi_arena_purge(
    arena: ptr[mi_arena_t], bitmap_idx: u64, blocks: u64, stats: ptr[mi_stats_t]
) {
    size = mi_arena_block_size(blocks);
    p = mi_arena_block_start(arena, bitmap_idx);
    field_count = arena.view(1)[0].field_count;
    needs_recommit = False;
    if _mi_bitmap_is_claimed_across(
        arena.view(1)[0].blocks_committed, field_count, blocks, bitmap_idx
    ) {
        needs_recommit = _mi_os_purge(p, size, stats);
    } else {
        needs_recommit = _mi_os_purge_ex(p, size, False, stats);
        _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_COMMITTED), size);
    }

    _mi_bitmap_unclaim_across(
        arena.view(1)[0].blocks_purge, field_count, blocks, bitmap_idx
    );

    if needs_recommit {
        _mi_bitmap_unclaim_across(
            arena.view(1)[0].blocks_committed, field_count, blocks, bitmap_idx
        );
    }
}

impl mi_arena_schedule_purge(
    arena: ptr[mi_arena_t], bitmap_idx: u64, blocks: u64, stats: ptr[mi_stats_t]
) {
    delay = mi_arena_purge_delay();

    if delay < 0 {
        return;
    }
    if _mi_preloading() or delay == 0 {
        mi_arena_purge(arena, bitmap_idx, blocks, stats);
    } else {
        expire = mi_atomic_loadi64_relaxed(mi_arena_purge_expire_addr(arena));
        if expire != 0 {
            mi_atomic_addi64_acq_rel(mi_arena_purge_expire_addr(arena), delay // 10);
        } else {
            mi_atomic_storei64_release(
                mi_arena_purge_expire_addr(arena), _mi_clock_now() + delay
            );
        }
        _mi_bitmap_claim_across(
            arena.view(1)[0].blocks_purge,
            arena.view(1)[0].field_count,
            blocks,
            bitmap_idx
        );
    }
}

impl mi_arena_purge_range(
    arena: ptr[mi_arena_t],
    idx: u64,
    startidx: u64,
    bitlen: u64,
    purge: u64,
    stats: ptr[mi_stats_t]
) -> bool {
    endidx = startidx + bitlen;
    bitidx = startidx;
    all_purged = False;
    count: u64 = 0;
    while bitidx < endidx {
        count = u64(0);
        while bitidx + count < endidx
            and (purge & wrapping_shl(u64(1), bitidx + count)) != u64(0) {
            count = count + u64(1);
        }
        if count > u64(0) {
            range_idx = mi_bitmap_index_create(idx, bitidx);
            mi_arena_purge(arena, range_idx, count, stats);
            if count == bitlen {
                all_purged = True;
            }
        }

        bitidx = bitidx + count + u64(1);
    }
    return all_purged;
}

impl mi_arena_try_purge(
    arena: ptr[mi_arena_t], now: i64, force: bool, stats: ptr[mi_stats_t]
) -> bool {
    if mi_arena_memid_of(arena).view(1)[0].is_pinned
        or not arena.view(1)[0].blocks_purge {
        return False;
    }
    expire_addr = mi_arena_purge_expire_addr(arena);
    expire = mi_atomic_loadi64_relaxed(expire_addr);
    if expire == 0 {
        return False;
    }
    if not force and expire > now {
        return False;
    }

    mi_atomic_casi64_strong_acq_rel(expire_addr, expire, i64(0));

    any_purged = False;
    full_purge = True;
    field_count = arena.view(1)[0].field_count;
    blocks_purge = arena.view(1)[0].blocks_purge;
    blocks_inuse = mi_arena_blocks_inuse_of(arena);
    i: u64 = 0;
    bitidx: u64 = 0;
    bitlen: u64 = 0;
    while i < field_count {
        purge = mi_atomic_load_relaxed(blocks_purge + i64.wrap(i));
        if purge != u64(0) {
            bitidx = u64(0);
            while bitidx < MI_BITMAP_FIELD_BITS {
                bitlen = u64(0);
                while bitidx + bitlen < MI_BITMAP_FIELD_BITS
                    and (purge & wrapping_shl(u64(1), bitidx + bitlen)) != u64(0) {
                    bitlen = bitlen + u64(1);
                }

                bitmap_index = mi_bitmap_index_create(i, bitidx);
                while bitlen > u64(0) {
                    if _mi_bitmap_try_claim(
                        blocks_inuse, field_count, bitlen, bitmap_index
                    ) {
                        break;
                    }
                    bitlen = bitlen - u64(1);
                }

                if bitlen > u64(0) {
                    purge = mi_atomic_load_acquire(blocks_purge + i64.wrap(i));
                    if not mi_arena_purge_range(
                        arena, i, bitidx, bitlen, purge, stats
                    ) {
                        full_purge = False;
                    }
                    any_purged = True;

                    _mi_bitmap_unclaim(blocks_inuse, field_count, bitlen, bitmap_index);
                }

                bitidx = bitidx + bitlen + u64(1);
            }
        }
        i = i + u64(1);
    }

    if not full_purge {
        delay = mi_arena_purge_delay();
        mi_atomic_casi64_strong_acq_rel(expire_addr, i64(0), _mi_clock_now() + delay);
    }
    return any_purged;
}

impl mi_arenas_try_purge(force: bool, visit_all: bool, stats: ptr[mi_stats_t]) {
    if _mi_preloading() or mi_arena_purge_delay() <= 0 {
        return;
    }
    max_arena = mi_atomic_load_acquire(mi_arena_count_addr());
    if max_arena == u64(0) {
        return;
    }

    (guarded, guard_seen) = mi_atomic_cas_strong_acq_rel(
        mi_arena_purge_guard_addr(), u64(0), u64(1)
    );
    if not guarded {
        return;
    }
    now = _mi_clock_now();
    max_purge_count = u64(1);
    if visit_all {
        max_purge_count = max_arena;
    }
    i: u64 = 0;
    while i < max_arena {
        arena = mi_arenas_load_acquire(i);
        if arena {
            if mi_arena_try_purge(arena, now, force, stats) {
                if max_purge_count <= u64(1) {
                    break;
                }
                max_purge_count = max_purge_count - u64(1);
            }
        }
        i = i + u64(1);
    }
    mi_atomic_store_release(mi_arena_purge_guard_addr(), u64(0));
}

impl _mi_arena_free(
    p: ptr[u8],
    size: u64,
    still_committed_size: u64,
    memid: ptr[mi_memid_t],
    stats: ptr[mi_stats_t]
) {
    if not p {
        return;
    }
    if size == u64(0) {
        return;
    }
    committed_size = still_committed_size;
    memkind = memid.view(1)[0].memkind;
    all_committed = committed_size == size;
    if mi_memkind_is_os(memkind) {
        if not all_committed and committed_size > u64(0) {
            _mi_stat_decrease(
                mi_stat_count_at(stats, mi_stats_t_COMMITTED), committed_size
            );
        }
        _mi_os_free(p, size, memid, stats);
    } elif memkind == MI_MEM_ARENA {
        (is_exclusive, arena_idx, bitmap_idx) = mi_arena_memid_indices(memid);
        arena = mi_arenas_load_acquire(arena_idx);
        blocks = mi_block_count_of_size(size);
        if not arena {
            _mi_error_message(
                EINVAL,
                ptr[u8](
                    "trying to free from non-existent arena: %p, size %zu, memid: 0x%zx\n"
                ),
                u64.wrap(int(p)),
                size,
                bitmap_idx,
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            return;
        }
        field_count = arena.view(1)[0].field_count;
        if field_count <= mi_bitmap_index_field(bitmap_idx) {
            _mi_error_message(
                EINVAL,
                ptr[u8](
                    "trying to free from non-existent arena block: %p, size %zu, memid: 0x%zx\n"
                ),
                u64.wrap(int(p)),
                size,
                bitmap_idx,
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            return;
        }
        if not mi_arena_memid_of(arena).view(1)[0].is_pinned
            and arena.view(1)[0].blocks_committed {
            if not all_committed {
                _mi_bitmap_unclaim_across(
                    arena.view(1)[0].blocks_committed, field_count, blocks, bitmap_idx
                );
                if committed_size > u64(0) {
                    _mi_stat_decrease(
                        mi_stat_count_at(stats, mi_stats_t_COMMITTED), committed_size
                    );
                }
            }

            mi_arena_schedule_purge(arena, bitmap_idx, blocks, stats);
        }
        all_inuse = _mi_bitmap_unclaim_across(
            mi_arena_blocks_inuse_of(arena), field_count, blocks, bitmap_idx
        );
        if not all_inuse {
            _mi_error_message(
                EAGAIN,
                ptr[u8]("trying to free an already freed arena block: %p, size %zu\n"),
                u64.wrap(int(p)),
                size,
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            return;
        }
    }

    mi_arenas_try_purge(False, False, stats);
}

impl mi_arenas_unsafe_destroy {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    meta_memid = ptr[mi_memid_t](base);
    max_arena = mi_atomic_load_relaxed(mi_arena_count_addr());
    new_max_arena: u64 = 0;
    i: u64 = 0;
    while i < max_arena {
        arena = mi_arenas_load_acquire(i);
        if arena {
            start = mi_arena_start_of(arena);
            amemid = mi_arena_memid_of(arena);
            if start and mi_memkind_is_os(amemid.view(1)[0].memkind) {
                mi_atomic_store_release(mi_arenas_slot(i), u64(0));
                _mi_os_free(
                    start, mi_arena_size(arena), amemid, addressof(_mi_stats_main)
                );
            } else {
                new_max_arena = i;
            }

            mi_memid_copy(meta_memid, mi_arena_meta_memid_of(arena));
            meta_size = arena.view(1)[0].meta_size;
            mi_arena_meta_free(
                ptr[u8](arena), meta_memid, meta_size, addressof(_mi_stats_main)
            );
        }
        i = i + u64(1);
    }

    mi_atomic_cas_strong_acq_rel(mi_arena_count_addr(), max_arena, new_max_arena);
}

impl _mi_arena_collect(force_purge: bool, stats: ptr[mi_stats_t]) {
    mi_arenas_try_purge(force_purge, True, stats);
}

impl _mi_arena_unsafe_destroy_all(stats: ptr[mi_stats_t]) {
    mi_arenas_unsafe_destroy();

    _mi_arena_collect(True, stats);
}

impl _mi_arena_contains(p: ptr[u8]) -> bool {
    max_arena = mi_atomic_load_relaxed(mi_arena_count_addr());
    addr = u64.wrap(int(p));
    i: u64 = 0;
    while i < max_arena {
        arena = mi_arenas_load_acquire(i);
        if arena {
            start = u64.wrap(int(mi_arena_start_of(arena)));
            if start <= addr
                and wrapping_add(
                    start, mi_arena_block_size(arena.view(1)[0].block_count)
                )
                    > addr {
                return True;
            }
        }
        i = i + u64(1);
    }
    return False;
}

impl mi_arena_add(arena: ptr[mi_arena_t]) -> tuple[bool, i32] {
    i = mi_atomic_increment_acq_rel(mi_arena_count_addr());
    if i >= MI_MAX_ARENAS {
        mi_atomic_decrement_acq_rel(mi_arena_count_addr());
        return (False, i32(-1));
    }
    arena.view(1)[0].id = mi_arena_id_create(i);
    mi_atomic_store_release(mi_arenas_slot(i), u64.wrap(int(arena)));
    return (True, arena.view(1)[0].id);
}

impl mi_manage_os_memory_ex2(
    start: ptr[u8],
    size: u64,
    is_large: bool,
    numa_node: i32,
    exclusive: bool,
    memid: ptr[mi_memid_t]
) -> tuple[bool, i32] {
    if size < MI_ARENA_BLOCK_SIZE {
        return (False, _mi_arena_id_none());
    }

    is_pinned = memid.view(1)[0].is_pinned;
    bcount = size // MI_ARENA_BLOCK_SIZE;
    fields = _mi_divide_up(bcount, MI_BITMAP_FIELD_BITS);
    bitmaps = u64(4);
    if is_pinned {
        bitmaps = u64(2);
    }

    asize = mi_arena_t_SIZE + bitmaps * fields * u64(8);
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    meta_memid = ptr[mi_memid_t](base);

    arena = ptr[mi_arena_t](
        mi_arena_meta_zalloc(asize, meta_memid, addressof(_mi_stats_main))
    );
    if not arena {
        return (False, _mi_arena_id_none());
    }

    arena.view(1)[0].id = _mi_arena_id_none();
    mi_memid_copy(mi_arena_memid_of(arena), memid);
    arena.view(1)[0].exclusive = exclusive;
    arena.view(1)[0].meta_size = asize;
    mi_memid_copy(mi_arena_meta_memid_of(arena), meta_memid);
    arena.view(1)[0].block_count = bcount;
    arena.view(1)[0].field_count = fields;
    mi_atomic_store_release(mi_arena_start_addr(arena), u64.wrap(int(start)));

    arena.view(1)[0].numa_node = numa_node;
    arena.view(1)[0].is_large = is_large;
    mi_atomic_storei64_release(mi_arena_purge_expire_addr(arena), i64(0));
    mi_atomic_store_release(mi_arena_search_idx_addr(arena), u64(0));
    blocks_inuse = mi_arena_blocks_inuse_of(arena);

    arena.view(1)[0].blocks_dirty = blocks_inuse + i64.wrap(fields);
    if is_pinned {
        arena.view(1)[0].blocks_committed = ptr[u64]();
        arena.view(1)[0].blocks_purge = ptr[u64]();
    } else {
        arena.view(1)[0].blocks_committed = blocks_inuse + i64.wrap(u64(2) * fields);
        arena.view(1)[0].blocks_purge = blocks_inuse + i64.wrap(u64(3) * fields);
    }

    if arena.view(1)[0].blocks_committed
        and mi_arena_memid_of(arena).view(1)[0].initially_committed {
        memset(ptr(arena.view(1)[0].blocks_committed), 255, fields * u64(8));
    }

    post = (fields * MI_BITMAP_FIELD_BITS) - bcount;
    if post > u64(0) {
        postidx = mi_bitmap_index_create(fields - u64(1), MI_BITMAP_FIELD_BITS - post);
        _mi_bitmap_claim(blocks_inuse, fields, post, postidx);
    }
    return mi_arena_add(arena);
}

impl mi_arena_reserve_os_memory(
    size: u64, commit: bool, allow_large: bool, exclusive: bool
) -> tuple[i32, i32] {
    asize = _mi_align_up(size, MI_ARENA_BLOCK_SIZE);
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    memid = ptr[mi_memid_t](base);
    start = _mi_os_alloc_aligned(
        asize, MI_SEGMENT_ALIGN, commit, allow_large, memid, addressof(_mi_stats_main)
    );
    if not start {
        return (ENOMEM, _mi_arena_id_none());
    }

    is_large = memid.view(1)[0].is_pinned;
    (added, id) = mi_manage_os_memory_ex2(
        start, asize, is_large, i32(-1), exclusive, memid
    );
    if not added {
        _mi_os_free_ex(start, asize, commit, memid, addressof(_mi_stats_main));
        _mi_verbose_message(
            ptr[u8]("failed to reserve %zu k memory\n"),
            _mi_divide_up(asize, u64(1024)),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        return (ENOMEM, id);
    }
    large_note = ptr[u8]("");
    if is_large {
        large_note = ptr[u8](" (in large os pages)");
    }
    _mi_verbose_message(
        ptr[u8]("reserved %zu KiB memory%s\n"),
        _mi_divide_up(asize, u64(1024)),
        u64.wrap(int(large_note)),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );
    return (i32(0), id);
}

impl mi_debug_show_bitmap(prefix: ptr[u8], fields: ptr[u64], field_count: u64) -> u64 {
    slots: own MiStack = MiStack();

    buf = ptr[u8](jacpy_stack_address(&mut slots));
    inuse_count: u64 = 0;
    i: u64 = 0;
    while i < field_count {
        field = mi_atomic_load_relaxed(fields + i64.wrap(i));
        bit: u64 = 0;
        while bit < MI_BITMAP_FIELD_BITS {
            inuse = (wrapping_shl(u64(1), bit) & field) != u64(0);
            slot = buf + i64.wrap(MI_BITMAP_FIELD_BITS - u64(1) - bit);
            if inuse {
                inuse_count = inuse_count + u64(1);
                slot.view(1)[0] = u8(120);
            } else {
                slot.view(1)[0] = u8(46);
            }
            bit = bit + u64(1);
        }
        (buf + i64.wrap(MI_BITMAP_FIELD_BITS)).view(1)[0] = u8(0);
        _mi_verbose_message(
            ptr[u8]("%s%s\n"),
            u64.wrap(int(prefix)),
            u64.wrap(int(buf)),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        i = i + u64(1);
    }
    return inuse_count;
}


impl mi_bitmap_index_create(idx: u64, bitidx: u64) -> u64 {
    return (idx * MI_BITMAP_FIELD_BITS) + bitidx;
}

impl mi_bitmap_index_create_from_bit(full_bitidx: u64) -> u64 {
    return mi_bitmap_index_create(
        full_bitidx // MI_BITMAP_FIELD_BITS, full_bitidx % MI_BITMAP_FIELD_BITS
    );
}

impl mi_bitmap_index_field(bitmap_idx: u64) -> u64 {
    return bitmap_idx // MI_BITMAP_FIELD_BITS;
}

impl mi_bitmap_index_bit_in_field(bitmap_idx: u64) -> u64 {
    return bitmap_idx % MI_BITMAP_FIELD_BITS;
}

impl mi_bitmap_index_bit(bitmap_idx: u64) -> u64 {
    return bitmap_idx;
}

impl mi_bitmap_mask_(count: u64, bitidx: u64) -> u64 {
    if count >= MI_BITMAP_FIELD_BITS {
        return MI_BITMAP_FIELD_FULL;
    }
    if count == u64(0) {
        return u64(0);
    }
    return wrapping_shl(wrapping_shl(u64(1), count) - u64(1), bitidx);
}

impl _mi_bitmap_try_find_claim_field(
    bitmap: ptr[u64], idx: u64, count: u64
) -> tuple[bool, u64] {
    field = bitmap + i64.wrap(idx);
    bmap = mi_atomic_load_relaxed(field);

    if bmap == MI_BITMAP_FIELD_FULL {
        return (False, u64(0));
    }

    mask = mi_bitmap_mask_(count, u64(0));
    bitidx_max = MI_BITMAP_FIELD_BITS - count;

    bitidx = mi_ctz(~bmap);

    m = wrapping_shl(mask, bitidx);
    shift: u64 = 0;

    while bitidx <= bitidx_max {
        mapm = bmap & m;
        if mapm == u64(0) {
            newmap = bmap | m;

            (claimed, seen) = mi_atomic_cas_strong_acq_rel(field, bmap, newmap);
            if not claimed {
                bmap = seen;
                continue;
            }

            return (True, mi_bitmap_index_create(idx, bitidx));
        }

        if count == u64(1) {
            shift = u64(1);
        } else {
            shift = (MI_INTPTR_BITS - mi_clz(mapm)) - bitidx;
        }

        bitidx = bitidx + shift;
        m = wrapping_shl(m, shift);
    }

    return (False, u64(0));
}

impl _mi_bitmap_try_find_from_claim(
    bitmap: ptr[u64], bitmap_fields: u64, start_field_idx: u64, count: u64
) -> tuple[bool, u64] {
    idx = start_field_idx;
    visited: u64 = 0;
    while visited < bitmap_fields {
        if idx >= bitmap_fields {
            idx = u64(0);
        }
        (found, bitmap_idx) = _mi_bitmap_try_find_claim_field(bitmap, idx, count);
        if found {
            return (True, bitmap_idx);
        }
        visited = visited + u64(1);
        idx = idx + u64(1);
    }
    return (False, u64(0));
}

impl _mi_bitmap_try_find_from_claim_pred(
    bitmap: ptr[u64],
    bitmap_fields: u64,
    start_field_idx: u64,
    count: u64,
    pred_fun: ptr,
    pred_arg: ptr
) -> tuple[bool, u64] {
    idx = start_field_idx;
    visited: u64 = 0;
    while visited < bitmap_fields {
        if idx >= bitmap_fields {
            idx = u64(0);
        }
        (found, bitmap_idx) = _mi_bitmap_try_find_claim_field(bitmap, idx, count);
        if found {
            if int(pred_fun) == 0
                or mi_call_bitmap_pred(pred_fun, bitmap_idx, pred_arg) {
                return (True, bitmap_idx);
            }

            _mi_bitmap_unclaim(bitmap, bitmap_fields, count, bitmap_idx);
        }
        visited = visited + u64(1);
        idx = idx + u64(1);
    }
    return (False, u64(0));
}

impl _mi_bitmap_unclaim(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    idx = mi_bitmap_index_field(bitmap_idx);
    bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
    mask = mi_bitmap_mask_(count, bitidx);

    prev = mi_atomic_and_acq_rel(bitmap + i64.wrap(idx), ~mask);
    return (prev & mask) == mask;
}

impl _mi_bitmap_claim(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool] {
    idx = mi_bitmap_index_field(bitmap_idx);
    bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
    mask = mi_bitmap_mask_(count, bitidx);

    prev = mi_atomic_or_acq_rel(bitmap + i64.wrap(idx), mask);
    return ((prev & mask) == u64(0), (prev & mask) != mask);
}

impl mi_bitmap_is_claimedx(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool] {
    idx = mi_bitmap_index_field(bitmap_idx);
    bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
    mask = mi_bitmap_mask_(count, bitidx);

    field = mi_atomic_load_relaxed(bitmap + i64.wrap(idx));
    return ((field & mask) == mask, (field & mask) != u64(0));
}

impl _mi_bitmap_try_claim(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    idx = mi_bitmap_index_field(bitmap_idx);
    bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
    mask = mi_bitmap_mask_(count, bitidx);

    field = bitmap + i64.wrap(idx);
    expected = mi_atomic_load_relaxed(field);
    while True {
        if (expected & mask) != u64(0) {
            return False;
        }
        (claimed, seen) = mi_atomic_cas_strong_acq_rel(
            field, expected, expected | mask
        );
        if claimed {
            break;
        }
        expected = seen;
    }
    return True;
}

impl _mi_bitmap_is_claimed(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    (all_ones, any_ones) = mi_bitmap_is_claimedx(
        bitmap, bitmap_fields, count, bitmap_idx
    );
    return all_ones;
}

impl _mi_bitmap_is_any_claimed(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    (all_ones, any_ones) = mi_bitmap_is_claimedx(
        bitmap, bitmap_fields, count, bitmap_idx
    );
    return any_ones;
}

impl mi_bitmap_try_find_claim_field_across(
    bitmap: ptr[u64], bitmap_fields: u64, idx: u64, count: u64, retries: u64
) -> tuple[bool, u64] {
    first = i64.wrap(idx);
    fi = first;
    bmap = mi_atomic_load_relaxed(bitmap + fi);

    initial = mi_clz(bmap);
    if initial == u64(0) {
        return (False, u64(0));
    }

    if initial >= count {
        return _mi_bitmap_try_find_claim_field(bitmap, idx, count);
    }

    if _mi_divide_up(count - initial, MI_BITMAP_FIELD_BITS) >= (bitmap_fields - idx) {
        return (False, u64(0));
    }

    found = initial;

    mask: u64 = 0;
    mask_bits: u64 = 0;
    while found < count {
        fi = fi + 1;
        bmap = mi_atomic_load_relaxed(bitmap + fi);
        if found + MI_BITMAP_FIELD_BITS <= count {
            mask_bits = MI_BITMAP_FIELD_BITS;
        } else {
            mask_bits = count - found;
        }
        mask = mi_bitmap_mask_(mask_bits, u64(0));

        if (bmap & mask) != u64(0) {
            return (False, u64(0));
        }
        found = found + mask_bits;
    }

    final_fi = fi;
    final_mask = mask;
    initial_idx = MI_BITMAP_FIELD_BITS - initial;
    initial_mask = mi_bitmap_mask_(initial, initial_idx);
    rollback = False;
    newmap: u64 = 0;

    fi = first;
    bmap = mi_atomic_load_relaxed(bitmap + fi);
    while True {
        newmap = bmap | initial_mask;
        if (bmap & initial_mask) != u64(0) {
            rollback = True;
            break;
        }
        (ok_initial, seen_initial) = mi_atomic_cas_strong_acq_rel(
            bitmap + fi, bmap, newmap
        );
        if ok_initial {
            break;
        }
        bmap = seen_initial;
    }

    if not rollback {
        while True {
            fi = fi + 1;
            if fi >= final_fi {
                break;
            }
            newmap = MI_BITMAP_FIELD_FULL;
            bmap = u64(0);
            (ok_mid, seen_mid) = mi_atomic_cas_strong_acq_rel(
                bitmap + fi, bmap, newmap
            );
            if not ok_mid {
                rollback = True;
                break;
            }
        }
    }

    if not rollback {
        bmap = mi_atomic_load_relaxed(bitmap + fi);
        while True {
            newmap = bmap | final_mask;
            if (bmap & final_mask) != u64(0) {
                rollback = True;
                break;
            }
            (ok_final, seen_final) = mi_atomic_cas_strong_acq_rel(
                bitmap + fi, bmap, newmap
            );
            if ok_final {
                break;
            }
            bmap = seen_final;
        }
    }
    if not rollback {
        return (True, mi_bitmap_index_create(idx, initial_idx));
    }

    fi = fi - 1;
    while fi > first {
        newmap = u64(0);

        mi_atomic_store_release(bitmap + fi, newmap);
        fi = fi - 1;
    }

    if fi == first {
        bmap = mi_atomic_load_relaxed(bitmap + fi);
        while True {
            newmap = bmap & ~initial_mask;
            (ok_undo, seen_undo) = mi_atomic_cas_strong_acq_rel(
                bitmap + fi, bmap, newmap
            );
            if ok_undo {
                break;
            }
            bmap = seen_undo;
        }
    }

    if retries <= u64(2) {
        return mi_bitmap_try_find_claim_field_across(
            bitmap, bitmap_fields, idx, count, retries + u64(1)
        );
    }
    return (False, u64(0));
}

impl _mi_bitmap_try_find_from_claim_across(
    bitmap: ptr[u64], bitmap_fields: u64, start_field_idx: u64, count: u64
) -> tuple[bool, u64] {
    if count <= u64(2) {
        return _mi_bitmap_try_find_from_claim(
            bitmap, bitmap_fields, start_field_idx, count
        );
    }

    idx = start_field_idx;
    visited: u64 = 0;
    while visited < bitmap_fields {
        if idx >= bitmap_fields {
            idx = u64(0);
        }

        if count <= MI_BITMAP_FIELD_BITS {
            (found, bitmap_idx) = _mi_bitmap_try_find_claim_field(bitmap, idx, count);
            if found {
                return (True, bitmap_idx);
            }
        }

        (found_across, across_idx) = mi_bitmap_try_find_claim_field_across(
            bitmap, bitmap_fields, idx, count, u64(0)
        );
        if found_across {
            return (True, across_idx);
        }
        visited = visited + u64(1);
        idx = idx + u64(1);
    }
    return (False, u64(0));
}

impl mi_bitmap_mask_across(
    bitmap_idx: u64, bitmap_fields: u64, count: u64
) -> tuple[u64, u64, u64, u64] {
    bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
    if bitidx + count <= MI_BITMAP_FIELD_BITS {
        return (u64(0), mi_bitmap_mask_(count, bitidx), u64(0), u64(0));
    }
    pre_bits = MI_BITMAP_FIELD_BITS - bitidx;

    pre_mask = mi_bitmap_mask_(pre_bits, bitidx);
    rest = count - pre_bits;
    mid_count = rest // MI_BITMAP_FIELD_BITS;
    rest = rest % MI_BITMAP_FIELD_BITS;
    post_mask = u64(0);
    if rest != u64(0) {
        post_mask = mi_bitmap_mask_(rest, u64(0));
    }
    return (mid_count, pre_mask, MI_BITMAP_FIELD_FULL, post_mask);
}

impl _mi_bitmap_unclaim_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    idx = mi_bitmap_index_field(bitmap_idx);
    (mid_count, pre_mask, mid_mask, post_mask) = mi_bitmap_mask_across(
        bitmap_idx, bitmap_fields, count
    );
    all_one = True;
    field = bitmap + i64.wrap(idx);

    prev = mi_atomic_and_acq_rel(field, ~pre_mask);
    field = field + 1;
    if (prev & pre_mask) != pre_mask {
        all_one = False;
    }
    mid_left = mid_count;
    while mid_left > u64(0) {
        mid_left = mid_left - u64(1);

        prev = mi_atomic_and_acq_rel(field, ~mid_mask);
        field = field + 1;
        if (prev & mid_mask) != mid_mask {
            all_one = False;
        }
    }
    if post_mask != u64(0) {
        prev = mi_atomic_and_acq_rel(field, ~post_mask);
        if (prev & post_mask) != post_mask {
            all_one = False;
        }
    }
    return all_one;
}

impl _mi_bitmap_claim_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool] {
    idx = mi_bitmap_index_field(bitmap_idx);
    (mid_count, pre_mask, mid_mask, post_mask) = mi_bitmap_mask_across(
        bitmap_idx, bitmap_fields, count
    );
    all_zero = True;
    any_zero = False;
    field = bitmap + i64.wrap(idx);
    prev = mi_atomic_or_acq_rel(field, pre_mask);
    field = field + 1;
    if (prev & pre_mask) != u64(0) {
        all_zero = False;
    }
    if (prev & pre_mask) != pre_mask {
        any_zero = True;
    }
    mid_left = mid_count;
    while mid_left > u64(0) {
        mid_left = mid_left - u64(1);
        prev = mi_atomic_or_acq_rel(field, mid_mask);
        field = field + 1;
        if (prev & mid_mask) != u64(0) {
            all_zero = False;
        }
        if (prev & mid_mask) != mid_mask {
            any_zero = True;
        }
    }
    if post_mask != u64(0) {
        prev = mi_atomic_or_acq_rel(field, post_mask);
        if (prev & post_mask) != u64(0) {
            all_zero = False;
        }
        if (prev & post_mask) != post_mask {
            any_zero = True;
        }
    }
    return (all_zero, any_zero);
}

impl mi_bitmap_is_claimedx_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> tuple[bool, bool] {
    idx = mi_bitmap_index_field(bitmap_idx);
    (mid_count, pre_mask, mid_mask, post_mask) = mi_bitmap_mask_across(
        bitmap_idx, bitmap_fields, count
    );
    all_ones = True;
    any_ones = False;
    field = bitmap + i64.wrap(idx);
    prev = mi_atomic_load_relaxed(field);
    field = field + 1;
    if (prev & pre_mask) != pre_mask {
        all_ones = False;
    }
    if (prev & pre_mask) != u64(0) {
        any_ones = True;
    }
    mid_left = mid_count;
    while mid_left > u64(0) {
        mid_left = mid_left - u64(1);
        prev = mi_atomic_load_relaxed(field);
        field = field + 1;
        if (prev & mid_mask) != mid_mask {
            all_ones = False;
        }
        if (prev & mid_mask) != u64(0) {
            any_ones = True;
        }
    }
    if post_mask != u64(0) {
        prev = mi_atomic_load_relaxed(field);
        if (prev & post_mask) != post_mask {
            all_ones = False;
        }
        if (prev & post_mask) != u64(0) {
            any_ones = True;
        }
    }
    return (all_ones, any_ones);
}

impl _mi_bitmap_is_claimed_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    (all_ones, any_ones) = mi_bitmap_is_claimedx_across(
        bitmap, bitmap_fields, count, bitmap_idx
    );
    return all_ones;
}

impl _mi_bitmap_is_any_claimed_across(
    bitmap: ptr[u64], bitmap_fields: u64, count: u64, bitmap_idx: u64
) -> bool {
    (all_ones, any_ones) = mi_bitmap_is_claimedx_across(
        bitmap, bitmap_fields, count, bitmap_idx
    );
    return any_ones;
}


impl mi_heap_visit_pages(heap: ptr[mi_heap_t], fun: ptr, arg1: ptr, arg2: ptr) -> bool {
    if not heap {
        return True;
    }
    if heap.view(1)[0].page_count == u64(0) {
        return True;
    }

    i: u64 = 0;
    while i <= MI_BIN_FULL {
        pq = mi_heap_page_queue(heap, i);
        page = pq.view(1)[0].first;
        while page {
            next = page.view(1)[0].next;
            if not mi_call_page_visitor(fun, heap, pq, page, arg1, arg2) {
                return False;
            }
            page = next;
        }
        i = i + u64(1);
    }
    return True;
}

impl mi_heap_page_collect(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg_collect: ptr,
    arg2: ptr
) -> u8 {
    collect = ptr[i32](arg_collect).view(1)[0];
    _mi_page_free_collect(page, collect >= MI_FORCE);
    if mi_page_all_free(page) {
        freed = _PyMem_mi_page_maybe_free(ptr(page), ptr(pq), collect >= MI_FORCE);
        if not freed and collect == MI_ABANDON {
            bin: u64 = MI_BIN_FULL;
            if not mi_page_is_in_full(page) {
                bin = u64(_mi_bin(u64(page.view(1)[0].xblock_size)));
            }
            _mi_page_abandon(page, mi_heap_page_queue(heap, bin));
        }
    } elif collect == MI_ABANDON {
        _mi_page_abandon(page, pq);
    }

    return u8(1);
}

impl mi_heap_page_never_delayed_free(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg1: ptr,
    arg2: ptr
) -> u8 {
    _mi_page_use_delayed_free(page, MI_NEVER_DELAYED_FREE, False);

    return u8(1);
}

impl mi_heap_collect_ex(heap: ptr[mi_heap_t], collect: i32) {
    if not heap {
        return;
    }
    if not mi_heap_is_initialized(heap) {
        return;
    }
    force = collect >= MI_FORCE;
    _mi_deferred_free(heap, force);

    is_main_thread = _mi_is_main_thread()
        and heap.view(1)[0].thread_id == _mi_thread_id();

    force_main = (
        collect == MI_FORCE
        and is_main_thread
        and mi_heap_is_backing(heap)
        and not heap.view(1)[0].no_reclaim
    );
    if force_main {
        _mi_abandoned_reclaim_all(heap, mi_tld_segments(heap.view(1)[0].tld));
    }

    if collect == MI_ABANDON {
        mi_heap_visit_pages(heap, ptr(mi_heap_page_never_delayed_free), ptr(), ptr());
    }

    _mi_heap_delayed_free_all(heap);

    _mi_heap_collect_retired(heap, force);

    _PyMem_mi_heap_collect_qsbr(ptr(heap));

    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    collect_slot = ptr[i32](base);
    collect_slot.view(1)[0] = collect;
    mi_heap_visit_pages(heap, ptr(mi_heap_page_collect), ptr(collect_slot), ptr());

    _mi_abandoned_collect(
        heap, collect == MI_FORCE, mi_tld_segments(heap.view(1)[0].tld)
    );

    if force {
        _mi_segment_thread_collect(mi_tld_segments(heap.view(1)[0].tld));
    }

    if force and is_main_thread and mi_heap_is_backing(heap) {
        _mi_thread_data_collect();
        _mi_arena_collect(True, mi_tld_stats(heap.view(1)[0].tld));
    }
}

impl _mi_heap_collect_abandon(heap: ptr[mi_heap_t]) {
    mi_heap_collect_ex(heap, MI_ABANDON);
}

impl mi_heap_is_default(heap: ptr[mi_heap_t]) -> bool {
    return heap == mi_prim_get_default_heap();
}

impl _mi_heap_init_ex(
    heap: ptr[mi_heap_t], tld: ptr[mi_tld_t], arena_id: i32, no_reclaim: bool, tag: u8
) {
    _mi_memcpy_aligned(ptr(heap), ptr(addressof(_mi_heap_empty)), mi_heap_t_SIZE);
    heap.view(1)[0].tld = tld;
    heap.view(1)[0].thread_id = _mi_thread_id();
    heap.view(1)[0].arena_id = arena_id;
    if heap == tld.view(1)[0].heap_backing {
        _mi_random_init(mi_heap_random(heap));
    } else {
        _mi_random_split(
            mi_heap_random(tld.view(1)[0].heap_backing), mi_heap_random(heap)
        );
    }
    heap.view(1)[0].cookie = _mi_heap_random_next(heap) | u64(1);
    heap.view(1)[0].keys0 = _mi_heap_random_next(heap);
    heap.view(1)[0].keys1 = _mi_heap_random_next(heap);
    heap.view(1)[0].no_reclaim = no_reclaim;
    heap.view(1)[0].tag = tag;

    htld = heap.view(1)[0].tld;
    heap.view(1)[0].next = htld.view(1)[0].heaps;
    htld.view(1)[0].heaps = heap;
}

impl _mi_heap_memid_is_suitable(heap: ptr[mi_heap_t], memid: ptr[mi_memid_t]) -> bool {
    return _mi_arena_memid_is_suitable(memid, heap.view(1)[0].arena_id);
}

impl _mi_heap_random_next(heap: ptr[mi_heap_t]) -> u64 {
    return _mi_random_next(mi_heap_random(heap));
}

impl mi_heap_reset_pages(heap: ptr[mi_heap_t]) {
    memset(ptr(mi_heap_pages_free_direct(heap)), 0, MI_PAGES_DIRECT * MI_INTPTR_SIZE);
    _mi_memcpy_aligned(
        ptr(mi_heap_pages(heap)),
        ptr(mi_heap_pages(addressof(_mi_heap_empty))),
        (MI_BIN_FULL + u64(1)) * mi_page_queue_t_SIZE
    );
    mi_atomic_store_release(mi_heap_thread_delayed_free_addr(heap), u64(0));
    heap.view(1)[0].page_count = u64(0);
}

impl mi_heap_free(heap: ptr[mi_heap_t]) {
    if not heap {
        return;
    }
    if not mi_heap_is_initialized(heap) {
        return;
    }

    if mi_heap_is_backing(heap) {
        return;
    }

    if mi_heap_is_default(heap) {
        _mi_heap_set_default_direct(heap.view(1)[0].tld.view(1)[0].heap_backing);
    }

    tld = heap.view(1)[0].tld;
    prev = ptr[mi_heap_t]();
    curr = tld.view(1)[0].heaps;
    while curr != heap and int(curr) != 0 {
        prev = curr;
        curr = curr.view(1)[0].next;
    }
    if curr == heap {
        if prev {
            prev.view(1)[0].next = heap.view(1)[0].next;
        } else {
            tld.view(1)[0].heaps = heap.view(1)[0].next;
        }
    }

    mi_free(ptr(heap));
}

impl _mi_heap_page_destroy(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    arg1: ptr,
    arg2: ptr
) -> u8 {
    _mi_page_use_delayed_free(page, MI_NEVER_DELAYED_FREE, False);

    page.view(1)[0].used = u32(0);

    page.view(1)[0].next = ptr[mi_page_t]();
    page.view(1)[0].prev = ptr[mi_page_t]();
    _mi_segment_page_free(page, False, mi_tld_segments(heap.view(1)[0].tld));

    return u8(1);
}

impl _mi_heap_destroy_pages(heap: ptr[mi_heap_t]) {
    mi_heap_visit_pages(heap, ptr(_mi_heap_page_destroy), ptr(), ptr());
    mi_heap_reset_pages(heap);
}

impl _mi_heap_unsafe_destroy_all {
    bheap = ptr[mi_heap_t](mi_heap_get_backing());
    curr = bheap.view(1)[0].tld.view(1)[0].heaps;
    while curr {
        next = curr.view(1)[0].next;
        if curr.view(1)[0].no_reclaim {
            mi_heap_destroy(ptr(curr));
        } else {
            _mi_heap_destroy_pages(curr);
        }
        curr = next;
    }
}

impl mi_heap_absorb(heap: ptr[mi_heap_t], from_heap: ptr[mi_heap_t]) {
    if not from_heap {
        return;
    }
    if from_heap.view(1)[0].page_count == u64(0) {
        return;
    }

    _mi_heap_delayed_free_partial(from_heap);

    i: u64 = 0;
    while i <= MI_BIN_FULL {
        pq = mi_heap_page_queue(heap, i);
        append = mi_heap_page_queue(from_heap, i);
        pcount = _mi_page_queue_append(heap, pq, append);
        heap.view(1)[0].page_count = wrapping_add(heap.view(1)[0].page_count, pcount);
        from_heap.view(1)[0].page_count = wrapping_sub(
            from_heap.view(1)[0].page_count, pcount
        );
        i = i + u64(1);
    }

    _mi_heap_delayed_free_all(from_heap);

    mi_heap_reset_pages(from_heap);
}

impl mi_heap_of_block(p: ptr[u8]) -> ptr[mi_heap_t] {
    if not p {
        return ptr[mi_heap_t]();
    }
    segment = _mi_ptr_segment(p);
    valid = _mi_ptr_cookie(ptr[u8](segment)) == segment.view(1)[0].cookie;
    if not valid {
        return ptr[mi_heap_t]();
    }
    return mi_page_heap(_mi_segment_page_of(segment, p));
}

impl mi_heap_page_check_owned(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    p: ptr,
    vfound: ptr
) -> u8 {
    found = ptr[u8](vfound);
    segment = _mi_page_segment(page);
    (start, psize) = _mi_page_start(segment, page);
    end = start + i64.wrap(u64(page.view(1)[0].capacity) * mi_page_block_size(page));
    q = ptr[u8](p);
    is_found = int(q) >= int(start) and int(q) < int(end);
    if is_found {
        found.view(1)[0] = u8(1);
    } else {
        found.view(1)[0] = u8(0);
    }

    return u8(1) if not is_found else u8(0);
}

impl mi_fast_divisor(divisor: u64) -> tuple[u64, u64] {
    shift = MI_INTPTR_BITS - mi_clz(divisor - u64(1));
    span = wrapping_sub(wrapping_shl(u64(1), shift), divisor);
    magic = (wrapping_mul(u64(4294967296), span) // divisor) + u64(1);
    return (magic, shift);
}

impl mi_fast_divide(n: u64, magic: u64, shift: u64) -> u64 {
    return wrapping_add(wrapping_mul(n, magic) >> u64(32), n) >> shift;
}

impl mi_heap_free_map_word(lo: ptr[u64], hi: ptr[u64], i: u64) -> ptr[u64] {
    if i < u64(80) {
        return lo + i64.wrap(i);
    }
    return hi + i64.wrap(i - u64(80));
}

impl _mi_heap_area_visit_blocks(
    area: ptr[mi_heap_area_t], page: ptr[mi_page_t], visit_fn: ptr, arg: ptr
) -> bool {
    if not area {
        return True;
    }
    if not page {
        return True;
    }

    if page.view(1)[0].used == u32(0) {
        return True;
    }
    bsize = mi_page_block_size(page);

    ubsize = mi_page_usable_block_size(page);
    (pstart, psize) = _mi_page_start(_mi_page_segment(page), page);
    heap = mi_page_heap(page);
    capacity = u64(page.view(1)[0].capacity);
    if capacity == u64(1) {
        return mi_call_block_visit(
            visit_fn, ptr(heap), ptr(area), ptr(pstart), ubsize, arg
        );
    }
    if u64(page.view(1)[0].used) == capacity {
        fblock = pstart;
        k: u64 = 0;
        while k < capacity {
            if not mi_call_block_visit(
                visit_fn, ptr(heap), ptr(area), ptr(fblock), ubsize, arg
            ) {
                return False;
            }
            fblock = fblock + i64.wrap(bsize);
            k = k + u64(1);
        }
        return True;
    }

    lo_slots: own MiStack = MiStack();
    hi_slots: own MiStack = MiStack();
    map_lo = ptr[u64](jacpy_stack_address(&mut lo_slots));
    map_hi = ptr[u64](jacpy_stack_address(&mut hi_slots));
    bmapsize = (capacity + MI_INTPTR_BITS - u64(1)) // MI_INTPTR_BITS;
    if capacity % MI_INTPTR_BITS != u64(0) {
        tail_shift = capacity % MI_INTPTR_BITS;
        tail_mask = wrapping_shl(MI_SIZE_MAX, tail_shift);
        mi_heap_free_map_word(map_lo, map_hi, bmapsize - u64(1)).view(1)[0] = tail_mask;
    }

    (magic, div_shift) = mi_fast_divisor(bsize);
    block = page.view(1)[0].free;
    while block {
        offset = u64.wrap(int(block) - int(pstart));
        blockidx = mi_fast_divide(offset, magic, div_shift);
        bitidx = blockidx // MI_INTPTR_BITS;
        bit = blockidx - (bitidx * MI_INTPTR_BITS);
        word = mi_heap_free_map_word(map_lo, map_hi, bitidx);
        word.view(1)[0] = word.view(1)[0] | wrapping_shl(u64(1), bit);
        block = mi_block_next(page, block);
    }

    blk = pstart;
    i: u64 = 0;
    while i < bmapsize {
        fmap = mi_heap_free_map_word(map_lo, map_hi, i).view(1)[0];
        if fmap == u64(0) {
            j: u64 = 0;
            while j < MI_INTPTR_BITS {
                if not mi_call_block_visit(
                    visit_fn, ptr(heap), ptr(area), ptr(blk), ubsize, arg
                ) {
                    return False;
                }
                blk = blk + i64.wrap(bsize);
                j = j + u64(1);
            }
        } else {
            m = ~fmap;
            while m != u64(0) {
                set_idx = mi_ctz(m);
                if not mi_call_block_visit(
                    visit_fn,
                    ptr(heap),
                    ptr(area),
                    ptr(blk + i64.wrap(set_idx * bsize)),
                    ubsize,
                    arg
                ) {
                    return False;
                }
                m = m & (m - u64(1));
            }
            blk = blk + i64.wrap(bsize * MI_INTPTR_BITS);
        }
        i = i + u64(1);
    }
    return True;
}

impl _mi_heap_area_init(area: ptr[mi_heap_area_t], page: ptr[mi_page_t]) {
    _mi_page_free_collect(page, True);
    bsize = mi_page_block_size(page);
    ubsize = mi_page_usable_block_size(page);
    area.view(1)[0].reserved = u64(page.view(1)[0].reserved) * bsize;
    area.view(1)[0].committed = u64(page.view(1)[0].capacity) * bsize;
    (start, psize) = _mi_page_start(_mi_page_segment(page), page);
    area.view(1)[0].blocks = start;

    area.view(1)[0].used = u64(page.view(1)[0].used);
    area.view(1)[0].block_size = ubsize;
    area.view(1)[0].full_block_size = bsize;
}

impl mi_heap_visit_areas_page(
    heap: ptr[mi_heap_t],
    pq: ptr[mi_page_queue_t],
    page: ptr[mi_page_t],
    vfun: ptr,
    arg: ptr
) -> u8 {
    slots: own MiStack = MiStack();
    xarea = ptr[mi_heap_area_ex_t](jacpy_stack_address(&mut slots));
    xarea.view(1)[0].page = page;
    _mi_heap_area_init(mi_heap_area_ex_area(xarea), page);
    return u8(1) if mi_call_area_visitor(vfun, heap, xarea, arg) else u8(0);
}

impl mi_heap_visit_areas(heap: ptr[mi_heap_t], visit_fn: ptr, arg: ptr) -> bool {
    if int(visit_fn) == 0 {
        return False;
    }
    return mi_heap_visit_pages(heap, ptr(mi_heap_visit_areas_page), visit_fn, arg);
}

impl mi_heap_area_visitor(
    heap: ptr[mi_heap_t], xarea: ptr[mi_heap_area_ex_t], arg: ptr
) -> u8 {
    args = ptr[mi_visit_blocks_args_t](arg);
    visit_fn = ptr(args.view(1)[0].visit_fn);
    visit_arg = ptr(args.view(1)[0].arg);
    area = mi_heap_area_ex_area(xarea);
    if not mi_call_block_visit(
        visit_fn, ptr(heap), ptr(area), ptr(), area.view(1)[0].block_size, visit_arg
    ) {
        return u8(0);
    }
    if args.view(1)[0].visit_blocks {
        return u8(1)
            if _mi_heap_area_visit_blocks(
                area, xarea.view(1)[0].page, visit_fn, visit_arg
            )
            else u8(0);
    }
    return u8(1);
}


impl mi_init_statics_word(ofs: i64) -> ptr[u64] {
    return mi_word_addr(ptr[u8](addressof(mi_init_statics)), ofs);
}

impl mi_init_td_cache_slot(i: i64) -> ptr[u64] {
    return ptr[u64](addressof(td_cache)) + i;
}

impl mi_thread_data_heap(td: ptr[mi_thread_data_t]) -> ptr[mi_heap_t] {
    return ptr[mi_heap_t](td);
}

impl mi_thread_data_tld(td: ptr[mi_thread_data_t]) -> ptr[mi_tld_t] {
    return ptr[mi_tld_t](ptr[u8](td) + mi_thread_data_t_TLD);
}

impl mi_thread_data_memid(td: ptr[mi_thread_data_t]) -> ptr[mi_memid_t] {
    return ptr[mi_memid_t](ptr[u8](td) + mi_thread_data_t_MEMID);
}

impl _mi_thread_id -> u64 {
    return _mi_prim_thread_id();
}

impl mi_heap_main_init {
    hm = addressof(_mi_heap_main);
    if hm.view(1)[0].cookie == u64(0) {
        mi_tld_main_link();
        hm.view(1)[0].thread_id = _mi_thread_id();
        hm.view(1)[0].cookie = u64(1);
        _mi_random_init(mi_heap_random(hm));
        hm.view(1)[0].cookie = _mi_heap_random_next(hm);
        hm.view(1)[0].keys0 = _mi_heap_random_next(hm);
        hm.view(1)[0].keys1 = _mi_heap_random_next(hm);
    }
}

impl _mi_heap_main_get -> ptr[mi_heap_t] {
    mi_heap_main_init();
    return addressof(_mi_heap_main);
}

impl mi_thread_data_zalloc -> ptr[mi_thread_data_t] {
    slots: own MiStack = MiStack();
    memid = ptr[mi_memid_t](jacpy_stack_address(&mut slots));

    is_zero = False;
    td = ptr[mi_thread_data_t]();
    i: i64 = 0;
    while i < TD_CACHE_SIZE {
        slot = mi_init_td_cache_slot(i);
        if mi_atomic_load_relaxed(slot) != u64(0) {
            found = mi_atomic_exchange_acq_rel(slot, u64(0));
            if found != u64(0) {
                td = ptr[mi_thread_data_t](i64.wrap(found));
                break;
            }
        }
        i = i + 1;
    }

    if not td {
        td = ptr[mi_thread_data_t](
            _mi_os_alloc(mi_thread_data_t_SIZE, memid, addressof(_mi_stats_main))
        );
        if not td {
            td = ptr[mi_thread_data_t](
                _mi_os_alloc(mi_thread_data_t_SIZE, memid, addressof(_mi_stats_main))
            );
            if not td {
                _mi_error_message(
                    ENOMEM,
                    ptr[u8](
                        "unable to allocate thread local heap metadata (%zu bytes)\n"
                    ),
                    mi_thread_data_t_SIZE,
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0)
                );
            }
        }
        if td {
            mi_memid_copy(mi_thread_data_memid(td), memid);
            is_zero = memid.view(1)[0].initially_zero;
        }
    }
    if int(td) != 0 and not is_zero {
        _mi_memzero_aligned(ptr(td), mi_thread_data_t_SIZE);
    }
    return td;
}

impl mi_thread_data_free(tdfree: ptr[mi_thread_data_t]) {
    i: i64 = 0;
    while i < TD_CACHE_SIZE {
        slot = mi_init_td_cache_slot(i);
        if mi_atomic_load_relaxed(slot) == u64(0) {
            (ok, seen) = mi_atomic_cas_weak_acq_rel(
                slot, u64(0), u64.wrap(int(tdfree))
            );
            if ok {
                return;
            }
        }
        i = i + 1;
    }

    _mi_os_free(
        ptr[u8](tdfree),
        mi_thread_data_t_SIZE,
        mi_thread_data_memid(tdfree),
        addressof(_mi_stats_main)
    );
}

impl _mi_thread_data_collect {
    i: i64 = 0;
    while i < TD_CACHE_SIZE {
        slot = mi_init_td_cache_slot(i);
        if mi_atomic_load_relaxed(slot) != u64(0) {
            found = mi_atomic_exchange_acq_rel(slot, u64(0));
            if found != u64(0) {
                td = ptr[mi_thread_data_t](i64.wrap(found));
                _mi_os_free(
                    ptr[u8](td),
                    mi_thread_data_t_SIZE,
                    mi_thread_data_memid(td),
                    addressof(_mi_stats_main)
                );
            }
        }
        i = i + 1;
    }
}

impl _mi_heap_init -> bool {
    if mi_heap_is_initialized(mi_prim_get_default_heap()) {
        return True;
    }
    if _mi_is_main_thread() {
        mi_heap_main_init();
        _mi_heap_set_default_direct(addressof(_mi_heap_main));
    } else {
        td = mi_thread_data_zalloc();
        if not td {
            return False;
        }
        heap = mi_thread_data_heap(td);
        tld = mi_thread_data_tld(td);
        _mi_tld_init(tld, heap);
        _mi_heap_init_ex(heap, tld, _mi_arena_id_none(), False, u8(0));
        _mi_heap_set_default_direct(heap);
    }
    return False;
}

impl _mi_tld_init(tld: ptr[mi_tld_t], bheap: ptr[mi_heap_t]) {
    _mi_memcpy_aligned(ptr(tld), ptr(addressof(tld_empty)), mi_tld_t_SIZE);
    segs = mi_tld_segments(tld);
    segs.view(1)[0].stats = mi_tld_stats(tld);
    segs.view(1)[0].os = mi_tld_os(tld);
    segs.view(1)[0].abandoned = addressof(_mi_abandoned_default);
    mi_tld_os(tld).view(1)[0].stats = mi_tld_stats(tld);
    tld.view(1)[0].heap_backing = bheap;
}

impl _mi_heap_done(heap: ptr[mi_heap_t]) -> bool {
    if not mi_heap_is_initialized(heap) {
        return True;
    }

    if _mi_is_main_thread() {
        _mi_heap_set_default_direct(addressof(_mi_heap_main));
    } else {
        _mi_heap_set_default_direct(addressof(_mi_heap_empty));
    }

    bheap = heap.view(1)[0].tld.view(1)[0].heap_backing;
    if not mi_heap_is_initialized(bheap) {
        return False;
    }

    curr = bheap.view(1)[0].tld.view(1)[0].heaps;
    while curr {
        nxt = curr.view(1)[0].next;
        if curr != bheap {
            mi_heap_delete(ptr(curr));
        }
        curr = nxt;
    }

    if bheap != addressof(_mi_heap_main) {
        _mi_heap_collect_abandon(bheap);
    }

    _mi_stats_done(mi_tld_stats(bheap.view(1)[0].tld));

    if bheap != addressof(_mi_heap_main) {
        mi_thread_data_free(ptr[mi_thread_data_t](bheap));
    }

    return False;
}

impl mi_process_setup_auto_thread_done {
    st = addressof(mi_init_statics);
    if st.view(1)[0].tls_initialized {
        return;
    }
    st.view(1)[0].tls_initialized = True;
    _mi_prim_thread_init_auto_done();
    _mi_heap_set_default_direct(addressof(_mi_heap_main));
}

impl _mi_is_main_thread -> bool {
    tid = addressof(_mi_heap_main).view(1)[0].thread_id;
    return tid == u64(0) or tid == _mi_thread_id();
}

impl _mi_current_thread_count -> u64 {
    return mi_atomic_load_relaxed(mi_init_statics_word(MiInitStatics_THREAD_COUNT));
}

impl _mi_thread_done(heap: ptr[mi_heap_t]) {
    hp = heap;
    if not hp {
        hp = mi_prim_get_default_heap();
        if not hp {
            return;
        }
    }

    if not mi_heap_is_initialized(hp) {
        return;
    }

    mi_atomic_decrement_relaxed(mi_init_statics_word(MiInitStatics_THREAD_COUNT));
    _mi_stat_decrease(
        mi_stat_count_at(addressof(_mi_stats_main), mi_stats_t_THREADS), u64(1)
    );

    if hp.view(1)[0].thread_id != _mi_thread_id() {
        return;
    }

    if _mi_heap_done(hp) {
        return;
    }
}

impl _mi_heap_set_default_direct(heap: ptr[mi_heap_t]) {
    mi_heap_default_slot().view(1)[0] = heap;

    _mi_prim_thread_associate_default_heap(heap);
}

impl _mi_preloading -> bool {
    return addressof(mi_init_statics).view(1)[0].os_preloading;
}

impl mi_allocator_init -> tuple[bool, ptr[u8]] {
    return (True, ptr[u8]());
}

impl mi_allocator_done {
    return;
}

impl mi_process_load {
    mi_heap_main_init();
    if MI_PLATFORM_LINUX == 0 {
        dummy = mi_prim_get_default_heap();
        if not dummy {
            return;
        }
    }
    addressof(mi_init_statics).view(1)[0].os_preloading = False;

    atexit(ptr(mi_process_done));
    _mi_options_init();
    mi_process_setup_auto_thread_done();
    mi_process_init();
    if addressof(mi_init_statics).view(1)[0].mi_redirected {
        _mi_verbose_message(
            ptr[u8]("malloc is redirected.\n"),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
    }

    (ok, msg) = mi_allocator_init();
    if msg {
        if mi_option_is_enabled(mi_option_verbose)
            or mi_option_is_enabled(mi_option_show_errors) {
            _mi_fputs(ptr(), ptr(), ptr[u8](), msg);
        }
    }

    _mi_random_reinit_if_weak(mi_heap_random(addressof(_mi_heap_main)));
}

impl mi_detect_cpu_features {
    return;
}

impl mi_process_done {
    if not addressof(mi_globals).view(1)[0].process_is_initialized {
        return;
    }

    st = addressof(mi_init_statics);
    if st.view(1)[0].process_done {
        return;
    }
    st.view(1)[0].process_done = True;

    _mi_prim_thread_done_auto_done();

    mi_collect(True);

    if mi_option_is_enabled(mi_option_destroy_on_exit) {
        mi_collect(True);

        _mi_heap_unsafe_destroy_all();
        _mi_arena_unsafe_destroy_all(mi_tld_stats(_mi_heap_main_get().view(1)[0].tld));
    }
    if mi_option_is_enabled(mi_option_show_stats)
        or mi_option_is_enabled(mi_option_verbose) {
        mi_stats_print(ptr());
    }
    mi_allocator_done();
    _mi_verbose_message(
        ptr[u8]("process done: 0x%zx\n"),
        addressof(_mi_heap_main).view(1)[0].thread_id,
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );

    st.view(1)[0].os_preloading = True;
}


impl mi_options_desc(option: i32) -> ptr[mi_option_desc_t] {
    return ptr[mi_option_desc_t](addressof(options)) + i64(option);
}

impl mi_options_statics_word(ofs: i64) -> ptr[u64] {
    return mi_word_addr(ptr[u8](addressof(mi_options_statics)), ofs);
}

impl mi_options_out_buf -> ptr[u8] {
    return ptr[u8](addressof(out_buf));
}

impl _mi_options_init {
    mi_add_stderr_output();
    i: i32 = 0;
    while i < _mi_option_last {
        mi_option_get(i);
        desc = mi_options_desc(i);
        _mi_verbose_message(
            ptr[u8]("option '%s': %ld\n"),
            u64.wrap(int(desc.view(1)[0].name)),
            u64.wrap(desc.view(1)[0].value),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        i = i + 1;
    }
    st = addressof(mi_options_statics);
    st.view(1)[0].mi_max_error_count = mi_option_get(mi_option_max_errors);
    st.view(1)[0].mi_max_warning_count = mi_option_get(mi_option_max_warnings);
}

impl mi_out_stderr(msg: ptr[u8], arg: ptr) {
    if msg {
        if msg.view(1)[0] != u8(0) {
            _mi_prim_out_stderr(msg);
        }
    }
}

impl mi_out_buf(msg: ptr[u8], arg: ptr) -> None {
    if not msg {
        return;
    }
    out_len = mi_options_statics_word(MiOptionsStatics_OUT_LEN);
    if mi_atomic_load_relaxed(out_len) >= MI_MAX_DELAY_OUTPUT {
        return;
    }
    n: u64 = _mi_strlen(msg);
    if n == u64(0) {
        return;
    }

    start = mi_atomic_add_acq_rel(out_len, n);
    if start >= MI_MAX_DELAY_OUTPUT {
        return;
    }

    if start + n >= MI_MAX_DELAY_OUTPUT {
        n = MI_MAX_DELAY_OUTPUT - start - u64(1);
    }
    _mi_memcpy(ptr(mi_options_out_buf() + i64.wrap(start)), ptr(msg), n);
}

impl mi_out_buf_flush(out: ptr, no_more_buf: bool, arg: ptr) {
    if int(out) == 0 {
        return;
    }

    claim = u64(1);
    if no_more_buf {
        claim = MI_MAX_DELAY_OUTPUT;
    }
    count = mi_atomic_add_acq_rel(
        mi_options_statics_word(MiOptionsStatics_OUT_LEN), claim
    );

    if count > MI_MAX_DELAY_OUTPUT {
        count = MI_MAX_DELAY_OUTPUT;
    }
    buf = mi_options_out_buf();
    (buf + i64.wrap(count)).view(1)[0] = u8(0);
    mi_call_output(out, buf, arg);
    if not no_more_buf {
        (buf + i64.wrap(count)).view(1)[0] = u8(10);
    }
}

impl mi_out_buf_stderr(msg: ptr[u8], arg: ptr) {
    mi_out_stderr(msg, arg);
    mi_out_buf(msg, arg);
}

impl mi_out_get_default -> tuple[ptr, ptr] {
    st = addressof(mi_options_statics);
    arg = ptr(
        i64.wrap(
            mi_atomic_load_acquire(mi_options_statics_word(MiOptionsStatics_OUT_ARG))
        )
    );
    out = st.view(1)[0].mi_out_default;
    if out == u64(0) {
        return (ptr(mi_out_buf), arg);
    }
    return (ptr(i64.wrap(out)), arg);
}

impl mi_add_stderr_output {
    mi_out_buf_flush(ptr(mi_out_stderr), False, ptr());

    addressof(mi_options_statics).view(1)[0].mi_out_default = u64.wrap(
        int(ptr(mi_out_buf_stderr))
    );
}

impl mi_recurse_enter_prim -> bool {
    recurse = ptr[u64](__thread_local("jac_mi_recurse"));
    if recurse.view(1)[0] != u64(0) {
        return False;
    }
    recurse.view(1)[0] = u64(1);
    return True;
}

impl mi_recurse_exit_prim {
    recurse = ptr[u64](__thread_local("jac_mi_recurse"));
    recurse.view(1)[0] = u64(0);
}

impl mi_recurse_enter -> bool {
    if MI_PLATFORM_LINUX == 0 {
        if _mi_preloading() {
            return False;
        }
    }
    return mi_recurse_enter_prim();
}

impl mi_recurse_exit {
    if MI_PLATFORM_LINUX == 0 {
        if _mi_preloading() {
            return;
        }
    }
    mi_recurse_exit_prim();
}

impl _mi_fputs(out: ptr, arg: ptr, prefix: ptr[u8], message: ptr[u8]) {
    o = int(out);
    if o == 0
        or o == int(jacpy_stdio_stream(i32(1)))
        or o == int(jacpy_stdio_stream(i32(2))) {
        if not mi_recurse_enter() {
            return;
        }
        (dout, darg) = mi_out_get_default();
        if prefix {
            mi_call_output(dout, prefix, darg);
        }
        mi_call_output(dout, message, darg);
        mi_recurse_exit();
    } else {
        if prefix {
            mi_call_output(out, prefix, arg);
        }
        mi_call_output(out, message, arg);
    }
}

impl mi_vfprintf(
    out: ptr,
    arg: ptr,
    prefix: ptr[u8],
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
) {
    slots: own MiStack = MiStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    if not fmt {
        return;
    }
    if not mi_recurse_enter() {
        return;
    }
    snprintf(buf, u64(511), fmt, a0, a1, a2, a3, a4, a5, a6);
    mi_recurse_exit();
    _mi_fputs(out, arg, prefix, buf);
}

impl _mi_fprintf(
    out: ptr,
    arg: ptr,
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
) {
    mi_vfprintf(out, arg, ptr[u8](), fmt, a0, a1, a2, a3, a4, a5, a6);
}

impl mi_vfprintf_thread(
    out: ptr,
    arg: ptr,
    prefix: ptr[u8],
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
) {
    if int(prefix) != 0
        and _mi_strnlen(prefix, u64(33)) <= u64(32)
        and not _mi_is_main_thread() {
        slots: own MiStack = MiStack();
        tprefix = ptr[u8](jacpy_stack_address(&mut slots));
        snprintf(
            tprefix, u64(64), ptr[u8]("%sthread 0x%llx: "), prefix, _mi_thread_id()
        );
        mi_vfprintf(out, arg, tprefix, fmt, a0, a1, a2, a3, a4, a5, a6);
    } else {
        mi_vfprintf(out, arg, prefix, fmt, a0, a1, a2, a3, a4, a5, a6);
    }
}

impl _mi_trace_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
) {
    if mi_option_get(mi_option_verbose) <= i64(1) {
        return;
    }
    mi_vfprintf_thread(
        ptr(), ptr(), ptr[u8]("mimalloc: "), fmt, a0, a1, a2, a3, a4, a5, a6
    );
}

impl _mi_verbose_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
) {
    if not mi_option_is_enabled(mi_option_verbose) {
        return;
    }
    mi_vfprintf(ptr(), ptr(), ptr[u8]("mimalloc: "), fmt, a0, a1, a2, a3, a4, a5, a6);
}

impl mi_show_error_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
) {
    if not mi_option_is_enabled(mi_option_verbose) {
        if not mi_option_is_enabled(mi_option_show_errors) {
            return;
        }
        max_count = addressof(mi_options_statics).view(1)[0].mi_max_error_count;
        if max_count >= i64(0)
            and i64.wrap(
                mi_atomic_increment_acq_rel(
                    mi_options_statics_word(MiOptionsStatics_ERROR_COUNT)
                )
            )
                > max_count {
            return;
        }
    }
    mi_vfprintf_thread(
        ptr(), ptr(), ptr[u8]("mimalloc: error: "), fmt, a0, a1, a2, a3, a4, a5, a6
    );
}

impl _mi_warning_message(
    fmt: ptr[u8], a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64
) {
    if not mi_option_is_enabled(mi_option_verbose) {
        if not mi_option_is_enabled(mi_option_show_errors) {
            return;
        }
        max_count = addressof(mi_options_statics).view(1)[0].mi_max_warning_count;
        if max_count >= i64(0)
            and i64.wrap(
                mi_atomic_increment_acq_rel(
                    mi_options_statics_word(MiOptionsStatics_WARNING_COUNT)
                )
            )
                > max_count {
            return;
        }
    }
    mi_vfprintf_thread(
        ptr(), ptr(), ptr[u8]("mimalloc: warning: "), fmt, a0, a1, a2, a3, a4, a5, a6
    );
}

impl mi_error_default(err: i32) {
    return;
}

impl _mi_error_message(
    err: i32,
    fmt: ptr[u8],
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64
) {
    mi_show_error_message(fmt, a0, a1, a2, a3, a4, a5, a6);

    handler = addressof(mi_options_statics).view(1)[0].mi_error_handler;
    if handler != u64(0) {
        mi_call_error(
            ptr(i64.wrap(handler)),
            err,
            ptr(
                i64.wrap(
                    mi_atomic_load_acquire(
                        mi_options_statics_word(MiOptionsStatics_ERROR_ARG)
                    )
                )
            )
        );
    } else {
        mi_error_default(err);
    }
}

impl _mi_toupper(c: u8) -> u8 {
    if c >= u8(97) and c <= u8(122) {
        return c - u8(97) + u8(65);
    }
    return c;
}

impl _mi_strnicmp(s: ptr[u8], t: ptr[u8], n: u64) -> i32 {
    if n == u64(0) {
        return i32(0);
    }
    sp = s;
    tp = t;
    k = n;
    while sp.view(1)[0] != u8(0) and tp.view(1)[0] != u8(0) and k > u64(0) {
        if _mi_toupper(sp.view(1)[0]) != _mi_toupper(tp.view(1)[0]) {
            break;
        }
        sp = sp + 1;
        tp = tp + 1;
        k = k - u64(1);
    }
    if k == u64(0) {
        return i32(0);
    }
    return i32(sp.view(1)[0]) - i32(tp.view(1)[0]);
}

impl _mi_strlcpy(dest: ptr[u8], src: ptr[u8], dest_size: u64) {
    if not dest or not src or dest_size == u64(0) {
        return;
    }

    d = dest;
    s = src;
    size = dest_size;
    while s.view(1)[0] != u8(0) and size > u64(1) {
        d.view(1)[0] = s.view(1)[0];
        d = d + 1;
        s = s + 1;
        size = size - u64(1);
    }

    d.view(1)[0] = u8(0);
}

impl _mi_strlcat(dest: ptr[u8], src: ptr[u8], dest_size: u64) {
    if not dest or not src or dest_size == u64(0) {
        return;
    }

    d = dest;
    size = dest_size;
    while d.view(1)[0] != u8(0) and size > u64(1) {
        d = d + 1;
        size = size - u64(1);
    }

    _mi_strlcpy(d, src, size);
}

impl _mi_strlen(s: ptr[u8]) -> u64 {
    if not s {
        return u64(0);
    }
    n: u64 = 0;
    while (s + i64.wrap(n)).view(1)[0] != u8(0) {
        n = n + u64(1);
    }
    return n;
}

impl _mi_strnlen(s: ptr[u8], max_len: u64) -> u64 {
    if not s {
        return u64(0);
    }
    n: u64 = 0;
    while (s + i64.wrap(n)).view(1)[0] != u8(0) and n < max_len {
        n = n + u64(1);
    }
    return n;
}

impl mi_getenv(name: ptr[u8], result: ptr[u8], result_size: u64) -> bool {
    if not name or not result or result_size < u64(64) {
        return False;
    }
    return _mi_prim_getenv(name, result, result_size);
}

impl mi_option_init(desc: ptr[mi_option_desc_t]) {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    s = base;
    buf = base + 72;
    endp = ptr[ptr[u8]](base + 144);
    _mi_strlcpy(buf, ptr[u8]("mimalloc_"), u64(65));
    _mi_strlcat(buf, desc.view(1)[0].name, u64(65));
    found = mi_getenv(buf, s, u64(65));
    if not found and int(desc.view(1)[0].legacy_name) != 0 {
        _mi_strlcpy(buf, ptr[u8]("mimalloc_"), u64(65));
        _mi_strlcat(buf, desc.view(1)[0].legacy_name, u64(65));
        found = mi_getenv(buf, s, u64(65));
        if found {
            _mi_warning_message(
                ptr[u8](
                    "environment option \"mimalloc_%s\" is deprecated -- use \"mimalloc_%s\" instead.\n"
                ),
                u64.wrap(int(desc.view(1)[0].legacy_name)),
                u64.wrap(int(desc.view(1)[0].name)),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        }
    }
    if found {
        slen = _mi_strnlen(s, u64(64));
        i: u64 = 0;
        while i < slen {
            (buf + i64.wrap(i)).view(1)[0] = _mi_toupper((s + i64.wrap(i)).view(1)[0]);
            i = i + u64(1);
        }
        (buf + i64.wrap(slen)).view(1)[0] = u8(0);
        if buf.view(1)[0] == u8(0) or int(strstr(ptr[u8]("1;TRUE;YES;ON"), buf)) != 0 {
            desc.view(1)[0].value = i64(1);
            desc.view(1)[0].init_ = INITIALIZED;
        } elif int(strstr(ptr[u8]("0;FALSE;NO;OFF"), buf)) != 0 {
            desc.view(1)[0].value = i64(0);
            desc.view(1)[0].init_ = INITIALIZED;
        } else {
            endp.view(1)[0] = buf;
            value = strtol(buf, ptr(endp), i32(10));
            end_ = endp.view(1)[0];
            if desc.view(1)[0].option == mi_option_reserve_os_memory
                or desc.view(1)[0].option == mi_option_arena_reserve {
                c0 = end_.view(1)[0];
                if c0 == u8(75) {
                    end_ = end_ + 1;
                } elif c0 == u8(77) {
                    value = i64.wrap(wrapping_mul(u64.wrap(value), MI_KiB));
                    end_ = end_ + 1;
                } elif c0 == u8(71) {
                    value = i64.wrap(wrapping_mul(u64.wrap(value), MI_MiB));
                    end_ = end_ + 1;
                } else {
                    value = i64.wrap(
                        wrapping_add(u64.wrap(value), MI_KiB - u64(1)) // MI_KiB
                    );
                }
                if end_.view(1)[0] == u8(73) and (end_ + 1).view(1)[0] == u8(66) {
                    end_ = end_ + 2;
                } elif end_.view(1)[0] == u8(66) {
                    end_ = end_ + 1;
                }
            }
            if end_.view(1)[0] == u8(0) {
                desc.view(1)[0].value = value;
                desc.view(1)[0].init_ = INITIALIZED;
            } else {
                desc.view(1)[0].init_ = DEFAULTED;
                if desc.view(1)[0].option == mi_option_verbose
                    and desc.view(1)[0].value == i64(0) {
                    desc.view(1)[0].value = i64(1);
                    _mi_warning_message(
                        ptr[u8](
                            "environment option mimalloc_%s has an invalid value.\n"
                        ),
                        u64.wrap(int(desc.view(1)[0].name)),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0)
                    );
                    desc.view(1)[0].value = i64(0);
                } else {
                    _mi_warning_message(
                        ptr[u8](
                            "environment option mimalloc_%s has an invalid value.\n"
                        ),
                        u64.wrap(int(desc.view(1)[0].name)),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0)
                    );
                }
            }
        }
    } elif not _mi_preloading() {
        desc.view(1)[0].init_ = DEFAULTED;
    }
}


impl _mi_os_has_overcommit -> bool {
    return addressof(mi_os_mem_config).view(1)[0].has_overcommit;
}

impl _mi_os_has_virtual_reserve -> bool {
    return addressof(mi_os_mem_config).view(1)[0].has_virtual_reserve;
}

impl _mi_os_page_size -> u64 {
    return addressof(mi_os_mem_config).view(1)[0].page_size;
}

impl _mi_os_large_page_size -> u64 {
    large = addressof(mi_os_mem_config).view(1)[0].large_page_size;
    if large != u64(0) {
        return large;
    }
    return _mi_os_page_size();
}

impl _mi_os_use_large_page(size: u64, alignment: u64) -> bool {
    large = addressof(mi_os_mem_config).view(1)[0].large_page_size;
    if large == u64(0) or not mi_option_is_enabled(mi_option_allow_large_os_pages) {
        return False;
    }
    return (size % large) == u64(0) and (alignment % large) == u64(0);
}

impl _mi_os_good_alloc_size(size: u64) -> u64 {
    align_size: u64 = 0;
    if size < u64(512) * MI_KiB {
        align_size = _mi_os_page_size();
    } elif size < u64(2) * MI_MiB {
        align_size = u64(64) * MI_KiB;
    } elif size < u64(8) * MI_MiB {
        align_size = u64(256) * MI_KiB;
    } elif size < u64(32) * MI_MiB {
        align_size = MI_MiB;
    } else {
        align_size = u64(4) * MI_MiB;
    }
    if size >= MI_SIZE_MAX - align_size {
        return size;
    }
    return _mi_align_up(size, align_size);
}

impl _mi_os_init {
    _mi_prim_mem_init(addressof(mi_os_mem_config));
}

impl mi_align_up_ptr(p: ptr[u8], alignment: u64) -> ptr[u8] {
    return ptr[u8](i64.wrap(_mi_align_up(u64.wrap(int(p)), alignment)));
}

impl mi_align_down_ptr(p: ptr[u8], alignment: u64) -> ptr[u8] {
    return ptr[u8](i64.wrap(_mi_align_down(u64.wrap(int(p)), alignment)));
}

impl _mi_os_get_aligned_hint(try_alignment: u64, size: u64) -> ptr[u8] {
    if try_alignment <= u64(1) or try_alignment > MI_SEGMENT_SIZE {
        return ptr[u8]();
    }
    asize = _mi_align_up(size, MI_SEGMENT_SIZE);
    if asize > MI_GiB {
        return ptr[u8]();
    }
    base_addr = mi_word_addr(ptr[u8](addressof(mi_os_state)), MiOsState_ALIGNED_BASE);
    hint = mi_atomic_add_acq_rel(base_addr, asize);
    if hint == u64(0) or hint > MI_HINT_MAX {
        init_: u64 = MI_HINT_BASE;

        heap = mi_prim_get_default_heap();

        if mi_heap_is_initialized(heap) {
            r = _mi_heap_random_next(heap);

            init_ = init_
                + ((MI_SEGMENT_SIZE * ((r >> u64(17)) & u64(0xFFFFF))) % MI_HINT_AREA);
        }
        expected = wrapping_add(hint, asize);
        (swapped, seen) = mi_atomic_cas_strong_acq_rel(base_addr, expected, init_);

        hint = mi_atomic_add_acq_rel(base_addr, asize);
    }
    if (hint % try_alignment) != u64(0) {
        return ptr[u8]();
    }
    return ptr[u8](i64.wrap(hint));
}

impl mi_os_prim_free(
    addr: ptr[u8], size: u64, still_committed: bool, tld_stats: ptr[mi_stats_t]
) {
    if not addr or size == u64(0) {
        return;
    }
    err = _mi_prim_free(addr, size);
    if err != 0 {
        _mi_warning_message(
            ptr[u8](
                "unable to free OS memory (error: %d (0x%x), size: 0x%zx bytes, address: %p)\n"
            ),
            u64.wrap(i64(err)),
            u64.wrap(i64(err)),
            size,
            u64.wrap(int(addr)),
            u64(0),
            u64(0),
            u64(0)
        );
    }
    stats = addressof(_mi_stats_main);
    if still_committed {
        _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_COMMITTED), size);
    }
    _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_RESERVED), size);
}

impl _mi_os_free_ex(
    addr: ptr[u8],
    size: u64,
    still_committed: bool,
    memid: ptr[mi_memid_t],
    tld_stats: ptr[mi_stats_t]
) {
    memkind = memid.view(1)[0].memkind;
    os_base = memid.view(1)[0].mem_os_base;
    if mi_memkind_is_os(memkind) {
        csize = _mi_os_good_alloc_size(size);
        base = addr;

        if os_base {
            base = os_base;
            csize = wrapping_add(csize, u64.wrap(int(addr) - int(os_base)));
        }

        if memkind == MI_MEM_OS_HUGE {
            mi_os_free_huge_os_pages(base, csize, tld_stats);
        } else {
            mi_os_prim_free(base, csize, still_committed, tld_stats);
        }
    }
}

impl _mi_os_free(
    p: ptr[u8], size: u64, memid: ptr[mi_memid_t], tld_stats: ptr[mi_stats_t]
) {
    _mi_os_free_ex(p, size, True, memid, tld_stats);
}

impl mi_os_prim_alloc(
    size: u64,
    try_alignment: u64,
    commit: bool,
    allow_large: bool,
    stats: ptr[mi_stats_t]
) -> tuple[ptr[u8], bool, bool] {
    if size == u64(0) {
        return (ptr[u8](), False, False);
    }
    allow: bool = allow_large;
    if not commit {
        allow = False;
    }
    align: u64 = try_alignment;
    if align == u64(0) {
        align = u64(1);
    }
    (err, is_large, is_zero, p) = _mi_prim_alloc(size, align, commit, allow);
    if err != 0 {
        commit_arg: u64 = 0;
        if commit {
            commit_arg = u64(1);
        }
        allow_arg: u64 = 0;
        if allow {
            allow_arg = u64(1);
        }
        _mi_warning_message(
            ptr[u8](
                "unable to allocate OS memory (error: %d (0x%x), size: 0x%zx bytes, align: 0x%zx, commit: %d, allow large: %d)\n"
            ),
            u64.wrap(i64(err)),
            u64.wrap(i64(err)),
            size,
            align,
            commit_arg,
            allow_arg,
            u64(0)
        );
    }
    if p {
        _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_RESERVED), size);
        if commit {
            _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_COMMITTED), size);
        }
    }
    return (p, is_large, is_zero);
}

impl mi_os_prim_alloc_aligned(
    size: u64, alignment: u64, commit: bool, allow_large: bool, stats: ptr[mi_stats_t]
) -> tuple[ptr[u8], bool, bool, ptr[u8]] {
    allow: bool = allow_large;
    if not commit {
        allow = False;
    }
    page_size = _mi_os_page_size();
    if not (alignment >= page_size and (alignment & (alignment - u64(1))) == u64(0)) {
        return (ptr[u8](), False, False, ptr[u8]());
    }
    asize = _mi_align_up(size, page_size);
    base: ptr[u8] = ptr[u8]();

    (p0, large0, zero0) = mi_os_prim_alloc(asize, alignment, commit, allow, stats);
    p: ptr[u8] = p0;
    is_large: bool = large0;
    is_zero: bool = zero0;
    if not p {
        return (p, is_large, is_zero, base);
    }

    if (u64.wrap(int(p)) % alignment) == u64(0) {
        base = p;
    } else {
        mi_os_prim_free(p, asize, commit, stats);
        if asize >= MI_SIZE_MAX - alignment {
            return (ptr[u8](), is_large, is_zero, base);
        }
        over_size = asize + alignment;
        if addressof(mi_os_mem_config).view(1)[0].must_free_whole {
            (p1, large1, zero1) = mi_os_prim_alloc(
                over_size, u64(1), False, False, stats
            );
            is_large = large1;
            is_zero = zero1;
            if not p1 {
                return (p1, is_large, is_zero, base);
            }

            base = p1;
            p = mi_align_up_ptr(p1, alignment);

            if commit {
                (cok, czero) = _mi_os_commit(p, asize, stats);
            }
        } else {
            (p2, large2, zero2) = mi_os_prim_alloc(
                over_size, u64(1), commit, False, stats
            );
            is_large = large2;
            is_zero = zero2;
            if not p2 {
                return (p2, is_large, is_zero, base);
            }
            aligned_p = mi_align_up_ptr(p2, alignment);
            pre_size = u64.wrap(int(aligned_p) - int(p2));
            mid_size = _mi_align_up(asize, page_size);
            post_size = over_size - pre_size - mid_size;
            if pre_size > u64(0) {
                mi_os_prim_free(p2, pre_size, commit, stats);
            }
            if post_size > u64(0) {
                mi_os_prim_free(
                    aligned_p + i64.wrap(mid_size), post_size, commit, stats
                );
            }
            p = aligned_p;
            base = aligned_p;
        }
    }
    return (p, is_large, is_zero, base);
}

impl _mi_os_alloc(
    size: u64, memid: ptr[mi_memid_t], tld_stats: ptr[mi_stats_t]
) -> ptr[u8] {
    mi_memid_init_none(memid);
    stats = addressof(_mi_stats_main);
    if size == u64(0) {
        return ptr[u8]();
    }
    asize = _mi_os_good_alloc_size(size);
    (p, os_is_large, os_is_zero) = mi_os_prim_alloc(asize, u64(0), True, False, stats);
    if p {
        mi_memid_init_os(memid, True, os_is_zero, os_is_large);
    }
    return p;
}

impl _mi_os_alloc_aligned(
    size: u64,
    alignment: u64,
    commit: bool,
    allow_large: bool,
    memid: ptr[mi_memid_t],
    tld_stats: ptr[mi_stats_t]
) -> ptr[u8] {
    mi_memid_init_none(memid);
    if size == u64(0) {
        return ptr[u8]();
    }
    asize = _mi_os_good_alloc_size(size);
    aalign = _mi_align_up(alignment, _mi_os_page_size());
    (p, os_is_large, os_is_zero, os_base) = mi_os_prim_alloc_aligned(
        asize, aalign, commit, allow_large, addressof(_mi_stats_main)
    );
    if p {
        mi_memid_init_os(memid, commit, os_is_zero, os_is_large);
        memid.view(1)[0].mem_os_base = os_base;
        memid.view(1)[0].mem_os_alignment = aalign;
    }
    return p;
}

impl _mi_os_alloc_aligned_at_offset(
    size: u64,
    alignment: u64,
    align_offset: u64,
    commit: bool,
    allow_large: bool,
    memid: ptr[mi_memid_t],
    tld_stats: ptr[mi_stats_t]
) -> ptr[u8] {
    mi_memid_init_none(memid);
    if align_offset > MI_SEGMENT_SIZE {
        return ptr[u8]();
    }
    if align_offset == u64(0) {
        return _mi_os_alloc_aligned(
            size, alignment, commit, allow_large, memid, tld_stats
        );
    }

    extra = _mi_align_up(align_offset, alignment) - align_offset;
    oversize = size + extra;
    start = _mi_os_alloc_aligned(
        oversize, alignment, commit, allow_large, memid, tld_stats
    );
    if not start {
        return ptr[u8]();
    }
    p = start + i64.wrap(extra);

    if commit and extra > _mi_os_page_size() {
        _mi_os_decommit(start, extra, tld_stats);
    }
    return p;
}

impl mi_os_page_align_areax(
    conservative: bool, addr: ptr[u8], size: u64
) -> tuple[ptr[u8], u64] {
    if size == u64(0) or not addr {
        return (ptr[u8](), u64(0));
    }
    page_size = _mi_os_page_size();

    start: ptr[u8] = ptr[u8]();
    end: ptr[u8] = ptr[u8]();
    if conservative {
        start = mi_align_up_ptr(addr, page_size);
        end = mi_align_down_ptr(addr + i64.wrap(size), page_size);
    } else {
        start = mi_align_down_ptr(addr, page_size);
        end = mi_align_up_ptr(addr + i64.wrap(size), page_size);
    }
    diff = int(end) - int(start);
    if diff <= 0 {
        return (ptr[u8](), u64(0));
    }
    return (start, u64.wrap(diff));
}

impl mi_os_page_align_area_conservative(
    addr: ptr[u8], size: u64
) -> tuple[ptr[u8], u64] {
    return mi_os_page_align_areax(True, addr, size);
}

impl _mi_os_commit(
    addr: ptr[u8], size: u64, tld_stats: ptr[mi_stats_t]
) -> tuple[bool, bool] {
    stats = addressof(_mi_stats_main);
    is_zero: bool = False;

    _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_COMMITTED), size);
    _mi_stat_counter_increase(
        mi_stat_counter_at(stats, mi_stats_t_COMMIT_CALLS), u64(1)
    );

    (start, csize) = mi_os_page_align_areax(False, addr, size);
    if csize == u64(0) {
        return (True, is_zero);
    }

    (err, os_is_zero) = _mi_prim_commit(start, csize);
    if err != 0 {
        _mi_warning_message(
            ptr[u8](
                "cannot commit OS memory (error: %d (0x%x), address: %p, size: 0x%zx bytes)\n"
            ),
            u64.wrap(i64(err)),
            u64.wrap(i64(err)),
            u64.wrap(int(start)),
            csize,
            u64(0),
            u64(0),
            u64(0)
        );
        return (False, is_zero);
    }
    if os_is_zero {
        is_zero = True;
    }
    return (True, is_zero);
}

impl mi_os_decommit_ex(
    addr: ptr[u8], size: u64, needs_recommit: bool, tld_stats: ptr[mi_stats_t]
) -> tuple[bool, bool] {
    stats = addressof(_mi_stats_main);
    _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_COMMITTED), size);

    (start, csize) = mi_os_page_align_area_conservative(addr, size);
    if csize == u64(0) {
        return (True, needs_recommit);
    }

    (err, recommit) = _mi_prim_decommit(start, csize);
    if err != 0 {
        _mi_warning_message(
            ptr[u8](
                "cannot decommit OS memory (error: %d (0x%x), address: %p, size: 0x%zx bytes)\n"
            ),
            u64.wrap(i64(err)),
            u64.wrap(i64(err)),
            u64.wrap(int(start)),
            csize,
            u64(0),
            u64(0),
            u64(0)
        );
    }
    return (err == 0, recommit);
}

impl _mi_os_decommit(addr: ptr[u8], size: u64, tld_stats: ptr[mi_stats_t]) -> bool {
    (ok, needs_recommit) = mi_os_decommit_ex(addr, size, True, tld_stats);
    return ok;
}

impl _mi_os_reset(addr: ptr[u8], size: u64, stats: ptr[mi_stats_t]) -> bool {
    (start, csize) = mi_os_page_align_area_conservative(addr, size);
    if csize == u64(0) {
        return True;
    }
    _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_RESET), csize);
    _mi_stat_counter_increase(
        mi_stat_counter_at(stats, mi_stats_t_RESET_CALLS), u64(1)
    );
    err = _mi_prim_reset(start, csize);
    if err != 0 {
        _mi_warning_message(
            ptr[u8](
                "cannot reset OS memory (error: %d (0x%x), address: %p, size: 0x%zx bytes)\n"
            ),
            u64.wrap(i64(err)),
            u64.wrap(i64(err)),
            u64.wrap(int(start)),
            csize,
            u64(0),
            u64(0),
            u64(0)
        );
    }
    return err == 0;
}

impl _mi_os_purge_ex(
    p: ptr[u8], size: u64, allow_reset: bool, stats: ptr[mi_stats_t]
) -> bool {
    if mi_option_get(mi_option_purge_delay) < 0 {
        return False;
    }
    _mi_stat_counter_increase(
        mi_stat_counter_at(stats, mi_stats_t_PURGE_CALLS), u64(1)
    );
    _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_PURGED), size);

    if mi_option_is_enabled(mi_option_purge_decommits) and not _mi_preloading() {
        (ok, needs_recommit) = mi_os_decommit_ex(p, size, True, stats);
        return needs_recommit;
    }
    if allow_reset {
        _mi_os_reset(p, size, stats);
    }

    return False;
}

impl _mi_os_purge(p: ptr[u8], size: u64, stats: ptr[mi_stats_t]) -> bool {
    return _mi_os_purge_ex(p, size, True, stats);
}

impl mi_os_protectx(addr: ptr[u8], size: u64, protect_: bool) -> bool {
    (start, csize) = mi_os_page_align_area_conservative(addr, size);
    if csize == u64(0) {
        return False;
    }
    err = _mi_prim_protect(start, csize, protect_);
    if err != 0 {
        what: u64 = u64.wrap(int(ptr[u8]("unprotect")));
        if protect_ {
            what = u64.wrap(int(ptr[u8]("protect")));
        }
        _mi_warning_message(
            ptr[u8](
                "cannot %s OS memory (error: %d (0x%x), address: %p, size: 0x%zx bytes)\n"
            ),
            what,
            u64.wrap(i64(err)),
            u64.wrap(i64(err)),
            u64.wrap(int(start)),
            csize,
            u64(0),
            u64(0)
        );
    }
    return err == 0;
}

impl _mi_os_protect(addr: ptr[u8], size: u64) -> bool {
    return mi_os_protectx(addr, size, True);
}

impl _mi_os_unprotect(addr: ptr[u8], size: u64) -> bool {
    return mi_os_protectx(addr, size, False);
}

impl mi_os_claim_huge_pages(pages: u64) -> tuple[ptr[u8], u64] {
    size = wrapping_mul(pages, MI_HUGE_OS_PAGE_SIZE);
    huge_start_addr = mi_word_addr(
        ptr[u8](addressof(mi_os_state)), MiOsState_HUGE_START
    );
    start: u64 = 0;
    end: u64 = 0;
    huge_start = mi_atomic_load_relaxed(huge_start_addr);
    while True {
        start = huge_start;
        if start == u64(0) {
            start = MI_HUGE_OS_PAGES_START;

            heap = mi_prim_get_default_heap();

            if mi_heap_is_initialized(heap) {
                r = _mi_heap_random_next(heap);

                start = start + (MI_HUGE_OS_PAGE_SIZE * ((r >> u64(17)) & u64(0x0FFF)));
            }
        }
        end = wrapping_add(start, size);
        (ok, seen) = mi_atomic_cas_strong_acq_rel(huge_start_addr, huge_start, end);
        if ok {
            break;
        }
        huge_start = seen;
    }
    return (ptr[u8](i64.wrap(start)), size);
}

impl _mi_os_alloc_huge_os_pages(
    pages: u64, numa_node: i32, max_msecs: i64, memid: ptr[mi_memid_t]
) -> tuple[ptr[u8], u64, u64] {
    mi_memid_init_none(memid);
    (start, size) = mi_os_claim_huge_pages(pages);
    if not start {
        return (ptr[u8](), u64(0), u64(0));
    }
    start_t = _mi_clock_start();
    page: u64 = 0;
    all_zero: bool = True;
    while page < pages {
        addr = start + i64.wrap(wrapping_mul(page, MI_HUGE_OS_PAGE_SIZE));
        (err, is_zero, p) = _mi_prim_alloc_huge_os_pages(
            addr, MI_HUGE_OS_PAGE_SIZE, numa_node
        );
        if not is_zero {
            all_zero = False;
        }
        if err != 0 {
            _mi_warning_message(
                ptr[u8](
                    "unable to allocate huge OS page (error: %d (0x%x), address: %p, size: %zx bytes)\n"
                ),
                u64.wrap(i64(err)),
                u64.wrap(i64(err)),
                u64.wrap(int(addr)),
                MI_HUGE_OS_PAGE_SIZE,
                u64(0),
                u64(0),
                u64(0)
            );
            break;
        }

        if p != addr {
            if p {
                _mi_warning_message(
                    ptr[u8]("could not allocate contiguous huge OS page %zu at %p\n"),
                    page,
                    u64.wrap(int(addr)),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0)
                );
                mi_os_prim_free(
                    p, MI_HUGE_OS_PAGE_SIZE, True, addressof(_mi_stats_main)
                );
            }
            break;
        }

        page = page + u64(1);
        main_stats = addressof(_mi_stats_main);
        _mi_stat_increase(
            mi_stat_count_at(main_stats, mi_stats_t_COMMITTED), MI_HUGE_OS_PAGE_SIZE
        );
        _mi_stat_increase(
            mi_stat_count_at(main_stats, mi_stats_t_RESERVED), MI_HUGE_OS_PAGE_SIZE
        );

        if max_msecs > 0 {
            elapsed = _mi_clock_end(start_t);
            if page >= u64(1) {
                estimate = i64.wrap(
                    wrapping_mul(u64.wrap(elapsed) // (page + u64(1)), pages)
                );
                if estimate > 2 * max_msecs {
                    elapsed = max_msecs + 1;
                }
            }
            if elapsed > max_msecs {
                _mi_warning_message(
                    ptr[u8](
                        "huge OS page allocation timed out (after allocating %zu page(s))\n"
                    ),
                    page,
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0)
                );
                break;
            }
        }
    }

    psize = wrapping_mul(page, MI_HUGE_OS_PAGE_SIZE);
    if page == u64(0) {
        return (ptr[u8](), page, psize);
    }
    mi_memid_init_os(memid, True, all_zero, True);
    memid.view(1)[0].memkind = MI_MEM_OS_HUGE;
    return (start, page, psize);
}

impl mi_os_free_huge_os_pages(p: ptr[u8], size: u64, stats: ptr[mi_stats_t]) {
    if not p or size == u64(0) {
        return;
    }
    base = p;
    remaining = size;
    while remaining >= MI_HUGE_OS_PAGE_SIZE {
        mi_os_prim_free(base, MI_HUGE_OS_PAGE_SIZE, True, stats);
        remaining = remaining - MI_HUGE_OS_PAGE_SIZE;
        base = base + i64.wrap(MI_HUGE_OS_PAGE_SIZE);
    }
}

impl _mi_os_numa_node_count_get -> u64 {
    count_addr = mi_numa_node_count_addr();
    count = mi_atomic_load_acquire(count_addr);
    if count <= u64(0) {
        ncount = mi_option_get(mi_option_use_numa_nodes);
        if ncount > 0 {
            count = u64.wrap(ncount);
        } else {
            count = _mi_prim_numa_node_count();
            if count == u64(0) {
                count = u64(1);
            }
        }

        mi_atomic_store_release(count_addr, count);
        _mi_verbose_message(
            ptr[u8]("using %zd numa regions\n"),
            count,
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
    }
    return count;
}

impl _mi_os_numa_node_get(tld: ptr[mi_os_tld_t]) -> i32 {
    numa_count = _mi_os_numa_node_count();
    if numa_count <= u64(1) {
        return i32(0);
    }

    numa_node = _mi_prim_numa_node();
    if numa_node >= numa_count {
        numa_node = numa_node % numa_count;
    }
    return i32.wrap(numa_node);
}


impl mi_page_queue_is_huge(pq: ptr[mi_page_queue_t]) -> bool {
    return pq.view(1)[0].block_size == MI_MEDIUM_OBJ_SIZE_MAX + MI_INTPTR_SIZE;
}

impl mi_page_queue_is_full(pq: ptr[mi_page_queue_t]) -> bool {
    return pq.view(1)[0].block_size
        == MI_MEDIUM_OBJ_SIZE_MAX + (u64(2) * MI_INTPTR_SIZE);
}

impl mi_page_queue_is_special(pq: ptr[mi_page_queue_t]) -> bool {
    return pq.view(1)[0].block_size > MI_MEDIUM_OBJ_SIZE_MAX;
}

impl mi_bin(size: u64) -> u8 {
    wsize = _mi_wsize_from_size(size);
    bin: u8 = 0;
    if wsize <= u64(1) {
        bin = u8(1);
    } elif wsize <= u64(8) {
        bin = u8.wrap(wrapping_add(wsize, u64(1)) & ~u64(1));
    } elif wsize > MI_MEDIUM_OBJ_WSIZE_MAX {
        bin = u8.wrap(MI_BIN_HUGE);
    } else {
        w = wsize - u64(1);
        b = u8.wrap(mi_bsr(w));
        bin = u8.wrap(
            wrapping_sub(
                wrapping_add(
                    wrapping_shl(u64(b), u64(2)),
                    (w >> wrapping_sub(u64(b), u64(2))) & u64(3)
                ),
                u64(3)
            )
        );
    }

    return bin;
}

impl _mi_bin(size: u64) -> u8 {
    return mi_bin(size);
}

impl _mi_bin_size(bin: u8) -> u64 {
    return mi_heap_page_queue(addressof(_mi_heap_empty), u64(bin)).view(1)[
        0
    ].block_size;
}

impl mi_page_queue_of(page: ptr[mi_page_t]) -> ptr[mi_page_queue_t] {
    bin: u64 = MI_BIN_FULL;
    if not mi_page_is_in_full(page) {
        bin = u64(mi_bin(u64(page.view(1)[0].xblock_size)));
    }
    heap = mi_page_heap(page);

    return mi_heap_page_queue(heap, bin);
}

impl mi_heap_page_queue_of(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t]
) -> ptr[mi_page_queue_t] {
    bin: u64 = MI_BIN_FULL;
    if not mi_page_is_in_full(page) {
        bin = u64(mi_bin(u64(page.view(1)[0].xblock_size)));
    }
    return mi_heap_page_queue(heap, bin);
}

impl mi_heap_queue_first_update(heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t]) {
    size = pq.view(1)[0].block_size;
    if size > MI_SMALL_SIZE_MAX {
        return;
    }
    page = pq.view(1)[0].first;
    if not page {
        page = mi_page_empty();
    }

    start: u64 = 0;
    idx = _mi_wsize_from_size(size);
    pages_free = mi_heap_pages_free_direct(heap);

    if (pages_free + i64.wrap(idx)).view(1)[0] == page {
        return;
    }

    if idx <= u64(1) {
        start = u64(0);
    } else {
        bin = mi_bin(size);
        first_q = mi_heap_pages(heap);
        prev = pq + (i64(0) - 1);
        while bin == mi_bin(prev.view(1)[0].block_size) and int(prev) > int(first_q) {
            prev = prev + (i64(0) - 1);
        }
        start = u64(1) + _mi_wsize_from_size(prev.view(1)[0].block_size);
        if start > idx {
            start = idx;
        }
    }

    sz = start;
    while sz <= idx {
        (pages_free + i64.wrap(sz)).view(1)[0] = page;
        sz = sz + u64(1);
    }
}

impl mi_page_queue_remove(queue: ptr[mi_page_queue_t], page: ptr[mi_page_t]) {
    heap = mi_page_heap(page);
    prev = page.view(1)[0].prev;
    next = page.view(1)[0].next;
    if prev {
        prev.view(1)[0].next = next;
    }
    if next {
        next.view(1)[0].prev = prev;
    }
    if page == queue.view(1)[0].last {
        queue.view(1)[0].last = prev;
    }
    if page == queue.view(1)[0].first {
        queue.view(1)[0].first = next;

        mi_heap_queue_first_update(heap, queue);
    }
    heap.view(1)[0].page_count = wrapping_sub(heap.view(1)[0].page_count, u64(1));
    page.view(1)[0].next = ptr[mi_page_t]();
    page.view(1)[0].prev = ptr[mi_page_t]();
    mi_page_set_in_full(page, False);
}

impl mi_page_queue_push(
    heap: ptr[mi_heap_t], queue: ptr[mi_page_queue_t], page: ptr[mi_page_t]
) {
    mi_page_set_in_full(page, mi_page_queue_is_full(queue));
    first = queue.view(1)[0].first;
    page.view(1)[0].next = first;
    page.view(1)[0].prev = ptr[mi_page_t]();
    if first {
        first.view(1)[0].prev = page;
        queue.view(1)[0].first = page;
    } else {
        queue.view(1)[0].first = page;
        queue.view(1)[0].last = page;
    }

    mi_heap_queue_first_update(heap, queue);
    heap.view(1)[0].page_count = wrapping_add(heap.view(1)[0].page_count, u64(1));
}

impl mi_page_queue_enqueue_from(
    to: ptr[mi_page_queue_t], from_q: ptr[mi_page_queue_t], page: ptr[mi_page_t]
) {
    heap = mi_page_heap(page);
    prev = page.view(1)[0].prev;
    next = page.view(1)[0].next;
    if prev {
        prev.view(1)[0].next = next;
    }
    if next {
        next.view(1)[0].prev = prev;
    }
    if page == from_q.view(1)[0].last {
        from_q.view(1)[0].last = prev;
    }
    if page == from_q.view(1)[0].first {
        from_q.view(1)[0].first = next;

        mi_heap_queue_first_update(heap, from_q);
    }
    last = to.view(1)[0].last;
    page.view(1)[0].prev = last;
    page.view(1)[0].next = ptr[mi_page_t]();
    if last {
        last.view(1)[0].next = page;
        to.view(1)[0].last = page;
    } else {
        to.view(1)[0].first = page;
        to.view(1)[0].last = page;
        mi_heap_queue_first_update(heap, to);
    }
    mi_page_set_in_full(page, mi_page_queue_is_full(to));
}

impl _mi_page_queue_append(
    heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t], append: ptr[mi_page_queue_t]
) -> u64 {
    if not append.view(1)[0].first {
        return u64(0);
    }

    count: u64 = 0;
    page = append.view(1)[0].first;
    while page {
        mi_atomic_store_release(mi_page_xheap_addr(page), u64.wrap(int(heap)));

        _mi_page_use_delayed_free(page, MI_USE_DELAYED_FREE, False);
        count = count + u64(1);
        page = page.view(1)[0].next;
    }
    if not pq.view(1)[0].last {
        pq.view(1)[0].first = append.view(1)[0].first;
        pq.view(1)[0].last = append.view(1)[0].last;
        mi_heap_queue_first_update(heap, pq);
    } else {
        pq_last = pq.view(1)[0].last;
        append_first = append.view(1)[0].first;
        pq_last.view(1)[0].next = append_first;
        append_first.view(1)[0].prev = pq_last;
        pq.view(1)[0].last = append.view(1)[0].last;
    }
    return count;
}


impl mi_page_block_at(
    page: ptr[mi_page_t], page_start: ptr[u8], block_size: u64, i: u64
) -> ptr[mi_block_t] {
    return ptr[mi_block_t](page_start + i64.wrap(wrapping_mul(i, block_size)));
}

impl _mi_page_use_delayed_free(page: ptr[mi_page_t], delay: u64, override_never: bool) {
    while not _mi_page_try_use_delayed_free(page, delay, override_never) {
        mi_atomic_yield();
    }
}

impl _mi_page_try_use_delayed_free(
    page: ptr[mi_page_t], delay: u64, override_never: bool
) -> bool {
    xtf = mi_page_xthread_free_addr(page);
    yield_count: u64 = 0;
    while True {
        tfree = mi_atomic_load_acquire(xtf);
        tfreex = mi_tf_set_delayed(tfree, delay);
        old_delay = mi_tf_delayed(tfree);
        if old_delay == MI_DELAYED_FREEING {
            if yield_count >= u64(4) {
                return False;
            }
            yield_count = yield_count + u64(1);

            mi_atomic_yield();
            continue;
        } elif delay == old_delay {
            break;
        } elif not override_never and old_delay == MI_NEVER_DELAYED_FREE {
            break;
        }
        (ok, seen) = mi_atomic_cas_weak_release(xtf, tfree, tfreex);
        if ok {
            break;
        }
    }

    return True;
}

impl _mi_page_thread_free_collect(page: ptr[mi_page_t]) {
    xtf = mi_page_xthread_free_addr(page);
    tfree = mi_atomic_load_relaxed(xtf);
    head = mi_tf_block(tfree);
    while True {
        head = mi_tf_block(tfree);
        tfreex = mi_tf_set_block(tfree, ptr[mi_block_t]());
        (ok, seen) = mi_atomic_cas_weak_acq_rel(xtf, tfree, tfreex);
        if ok {
            break;
        }
        tfree = seen;
    }

    if not head {
        return;
    }

    max_count = u32(page.view(1)[0].capacity);
    count: u32 = 1;
    tail = head;
    next = mi_block_next(page, tail);
    while int(next) != 0 and count <= max_count {
        count = count + u32(1);
        tail = next;
        next = mi_block_next(page, tail);
    }

    if count > max_count {
        _mi_error_message(
            EFAULT,
            ptr[u8]("corrupted thread-free list\n"),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );

        return;
    }

    mi_block_set_next(page, tail, page.view(1)[0].local_free);
    page.view(1)[0].local_free = head;

    page.view(1)[0].used = wrapping_sub(page.view(1)[0].used, count);
    if page.view(1)[0].used == u32(0) {
        _PyMem_mi_page_clear_qsbr(ptr(page));
    }
}

impl _mi_page_free_collect(page: ptr[mi_page_t], force: bool) {
    if force or int(mi_page_thread_free(page)) != 0 {
        _mi_page_thread_free_collect(page);
    }

    local_free = page.view(1)[0].local_free;
    if local_free {
        if not page.view(1)[0].free {
            page.view(1)[0].free = local_free;
            page.view(1)[0].local_free = ptr[mi_block_t]();
            page.view(1)[0].free_is_zero = False;
        } elif force {
            tail = local_free;
            next = mi_block_next(page, tail);
            while next {
                tail = next;
                next = mi_block_next(page, tail);
            }
            mi_block_set_next(page, tail, page.view(1)[0].free);
            page.view(1)[0].free = local_free;
            page.view(1)[0].local_free = ptr[mi_block_t]();
            page.view(1)[0].free_is_zero = False;
        }
    }
}

impl _mi_page_reclaim(heap: ptr[mi_heap_t], page: ptr[mi_page_t]) {
    pq = mi_page_queue(heap, mi_page_block_size(page));
    mi_page_queue_push(heap, pq, page);
    _PyMem_mi_page_reclaimed(ptr(page));
}

impl mi_page_fresh_alloc(
    heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t], block_size: u64, page_alignment: u64
) -> ptr[mi_page_t] {
    tld = heap.view(1)[0].tld;
    page = _mi_segment_page_alloc(
        heap, block_size, page_alignment, mi_tld_segments(tld), mi_tld_os(tld)
    );
    if not page {
        return ptr[mi_page_t]();
    }

    full_block_size: u64 = block_size;
    if not pq {
        full_block_size = mi_page_block_size(page);
    } elif mi_page_queue_is_huge(pq) {
        full_block_size = mi_page_block_size(page);
    }
    mi_page_init(heap, page, full_block_size, heap.view(1)[0].tld);
    if pq {
        mi_page_queue_push(heap, pq, page);
    }
    return page;
}

impl mi_page_fresh(heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t]) -> ptr[mi_page_t] {
    page = mi_page_fresh_alloc(heap, pq, pq.view(1)[0].block_size, u64(0));
    if not page {
        return ptr[mi_page_t]();
    }
    return page;
}

impl _mi_heap_delayed_free_all(heap: ptr[mi_heap_t]) {
    while not _mi_heap_delayed_free_partial(heap) {
        mi_atomic_yield();
    }
}

impl _mi_heap_delayed_free_partial(heap: ptr[mi_heap_t]) -> bool {
    tdf = mi_heap_thread_delayed_free_addr(heap);

    head = mi_atomic_load_relaxed(tdf);
    while head != u64(0) {
        (taken, seen) = mi_atomic_cas_weak_acq_rel(tdf, head, u64(0));
        if taken {
            break;
        }
        head = seen;
    }
    all_freed = True;

    block = ptr[mi_block_t](i64.wrap(head));
    while block {
        next = mi_block_nextx(ptr[u8](heap), block, mi_heap_keys(heap));

        if not _mi_free_delayed_block(block) {
            all_freed = False;
            dfree = mi_atomic_load_relaxed(tdf);
            while True {
                mi_block_set_nextx(
                    ptr[u8](heap),
                    block,
                    ptr[mi_block_t](i64.wrap(dfree)),
                    mi_heap_keys(heap)
                );
                (stored, found) = mi_atomic_cas_weak_release(
                    tdf, dfree, u64.wrap(int(block))
                );
                if stored {
                    break;
                }
                dfree = found;
            }
        }
        block = next;
    }
    return all_freed;
}

impl _mi_page_unfull(page: ptr[mi_page_t]) {
    if not mi_page_is_in_full(page) {
        return;
    }
    heap = mi_page_heap(page);
    pqfull = mi_heap_page_queue(heap, MI_BIN_FULL);

    mi_page_set_in_full(page, False);
    pq = mi_heap_page_queue_of(heap, page);
    mi_page_set_in_full(page, True);
    mi_page_queue_enqueue_from(pq, pqfull, page);
}

impl mi_page_to_full(page: ptr[mi_page_t], pq: ptr[mi_page_queue_t]) {
    if mi_page_is_in_full(page) {
        return;
    }
    mi_page_queue_enqueue_from(
        mi_heap_page_queue(mi_page_heap(page), MI_BIN_FULL), pq, page
    );

    _mi_page_free_collect(page, False);
}

impl _mi_page_abandon(page: ptr[mi_page_t], pq: ptr[mi_page_queue_t]) {
    pheap = mi_page_heap(page);

    segments_tld = mi_tld_segments(pheap.view(1)[0].tld);
    mi_page_queue_remove(pq, page);

    mi_page_set_heap(page, ptr[mi_heap_t]());

    _mi_segment_page_abandon(page, segments_tld);
}

impl _mi_page_retire(page: ptr[mi_page_t]) {
    mi_page_set_has_aligned(page, False);

    _PyMem_mi_page_clear_qsbr(ptr(page));

    pq = mi_page_queue_of(page);
    xblock_size = u64(page.view(1)[0].xblock_size);

    if xblock_size <= MI_MAX_RETIRE_SIZE and not mi_page_queue_is_special(pq) {
        if pq.view(1)[0].last == page and pq.view(1)[0].first == page {
            if xblock_size <= MI_SMALL_OBJ_SIZE_MAX {
                page.view(1)[0].retire_expire = u8(1) + MI_RETIRE_CYCLES;
            } else {
                page.view(1)[0].retire_expire = u8(1) + (MI_RETIRE_CYCLES // u8(4));
            }
            heap = mi_page_heap(page);

            index = u64.wrap(int(pq) - int(mi_heap_pages(heap)))
                // mi_page_queue_t_SIZE;
            if index < heap.view(1)[0].page_retired_min {
                heap.view(1)[0].page_retired_min = index;
            }
            if index > heap.view(1)[0].page_retired_max {
                heap.view(1)[0].page_retired_max = index;
            }

            return;
        }
    }
    _PyMem_mi_page_maybe_free(ptr(page), ptr(pq), False);
}

impl _mi_heap_collect_retired(heap: ptr[mi_heap_t], force: bool) {
    min_bin: u64 = MI_BIN_FULL;
    max_bin: u64 = 0;
    bin = heap.view(1)[0].page_retired_min;
    while bin <= heap.view(1)[0].page_retired_max {
        pq = mi_heap_page_queue(heap, bin);
        page = pq.view(1)[0].first;
        if page {
            if page.view(1)[0].retire_expire != u8(0) {
                if mi_page_all_free(page) {
                    page.view(1)[0].retire_expire = page.view(1)[0].retire_expire
                        - u8(1);
                    if force or page.view(1)[0].retire_expire == u8(0) {
                        _PyMem_mi_page_maybe_free(ptr(page), ptr(pq), force);
                    } else {
                        if bin < min_bin {
                            min_bin = bin;
                        }
                        if bin > max_bin {
                            max_bin = bin;
                        }
                    }
                } else {
                    page.view(1)[0].retire_expire = u8(0);
                }
            }
        }
        bin = bin + u64(1);
    }
    heap.view(1)[0].page_retired_min = min_bin;
    heap.view(1)[0].page_retired_max = max_bin;
}

impl mi_page_free_list_extend_secure(
    heap: ptr[mi_heap_t],
    page: ptr[mi_page_t],
    bsize: u64,
    extend: u64,
    stats: ptr[mi_stats_t]
) {
    (page_area, page_size) = _mi_page_start(_mi_page_segment(page), page);

    shift = MI_MAX_SLICE_SHIFT;
    while (extend >> shift) == u64(0) {
        shift = shift - u64(1);
    }
    slice_count = wrapping_shl(u64(1), shift);
    slice_extend = extend // slice_count;

    blocks_slots: own MiStack = MiStack();

    counts_slots: own MiStack = MiStack();
    blocks = ptr[ptr[mi_block_t]](jacpy_stack_address(&mut blocks_slots));
    counts = ptr[u64](jacpy_stack_address(&mut counts_slots));
    capacity = u64(page.view(1)[0].capacity);
    i: u64 = 0;
    while i < slice_count {
        (blocks + i64.wrap(i)).view(1)[0] = mi_page_block_at(
            page, page_area, bsize, capacity + (i * slice_extend)
        );
        (counts + i64.wrap(i)).view(1)[0] = slice_extend;
        i = i + u64(1);
    }

    last_count = counts + i64.wrap(slice_count - u64(1));
    last_count.view(1)[0] = last_count.view(1)[0] + (extend % slice_count);

    r = _mi_heap_random_next(heap);
    current = r % slice_count;
    (counts + i64.wrap(current)).view(1)[0] = (counts + i64.wrap(current)).view(1)[0]
        - u64(1);
    free_start = (blocks + i64.wrap(current)).view(1)[0];

    rnd = _mi_random_shuffle(r | u64(1));
    i = u64(1);
    while i < extend {
        rnd_round = i % MI_INTPTR_SIZE;
        if rnd_round == u64(0) {
            rnd = _mi_random_shuffle(rnd);
        }

        next = (rnd >> (u64(8) * rnd_round)) & (slice_count - u64(1));

        while (counts + i64.wrap(next)).view(1)[0] == u64(0) {
            next = next + u64(1);
            if next == slice_count {
                next = u64(0);
            }
        }

        (counts + i64.wrap(next)).view(1)[0] = (counts + i64.wrap(next)).view(1)[0]
            - u64(1);
        block = (blocks + i64.wrap(current)).view(1)[0];

        (blocks + i64.wrap(current)).view(1)[0] = ptr[mi_block_t](
            ptr[u8](block) + i64.wrap(bsize)
        );

        mi_block_set_next(page, block, (blocks + i64.wrap(next)).view(1)[0]);
        current = next;
        i = i + u64(1);
    }

    mi_block_set_next(
        page, (blocks + i64.wrap(current)).view(1)[0], page.view(1)[0].free
    );
    page.view(1)[0].free = free_start;
}

impl mi_page_free_list_extend(
    page: ptr[mi_page_t], bsize: u64, extend: u64, stats: ptr[mi_stats_t]
) {
    (page_area, page_size) = _mi_page_start(_mi_page_segment(page), page);
    capacity = u64(page.view(1)[0].capacity);
    start = mi_page_block_at(page, page_area, bsize, capacity);

    last = mi_page_block_at(page, page_area, bsize, capacity + extend - u64(1));
    block = start;
    while int(block) <= int(last) {
        next = ptr[mi_block_t](ptr[u8](block) + i64.wrap(bsize));
        mi_block_set_next(page, block, next);
        block = next;
    }

    mi_block_set_next(page, last, page.view(1)[0].free);
    page.view(1)[0].free = start;
}

impl mi_page_extend_free(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t], tld: ptr[mi_tld_t]
) {
    if page.view(1)[0].free {
        return;
    }
    if page.view(1)[0].capacity >= page.view(1)[0].reserved {
        return;
    }
    (page_start, page_size) = _mi_page_start(_mi_page_segment(page), page);

    xblock_size = page.view(1)[0].xblock_size;
    bsize: u64 = page_size;
    if xblock_size < MI_HUGE_BLOCK_SIZE {
        bsize = u64(xblock_size);
    }
    extend = u64(page.view(1)[0].reserved) - u64(page.view(1)[0].capacity);

    max_extend: u64 = MI_MIN_EXTEND;
    if bsize < MI_MAX_EXTEND_SIZE {
        max_extend = MI_MAX_EXTEND_SIZE // u64(u32.wrap(bsize));
    }
    if max_extend < MI_MIN_EXTEND {
        max_extend = MI_MIN_EXTEND;
    }
    if extend > max_extend {
        extend = max_extend;
    }

    if extend < MI_MIN_SLICES or MI_SECURE == 0 {
        mi_page_free_list_extend(page, bsize, extend, mi_tld_stats(tld));
    } else {
        mi_page_free_list_extend_secure(heap, page, bsize, extend, mi_tld_stats(tld));
    }

    page.view(1)[0].capacity = page.view(1)[0].capacity + u16.wrap(extend);
}

impl mi_page_init(
    heap: ptr[mi_heap_t], page: ptr[mi_page_t], block_size: u64, tld: ptr[mi_tld_t]
) {
    segment = _mi_page_segment(page);

    mi_page_set_heap(page, heap);
    page.view(1)[0].tag = heap.view(1)[0].tag;
    page.view(1)[0].use_qsbr = heap.view(1)[0].page_use_qsbr;
    page.view(1)[0].debug_offset = heap.view(1)[0].debug_offset;

    if block_size < u64(MI_HUGE_BLOCK_SIZE) {
        page.view(1)[0].xblock_size = u32.wrap(block_size);
    } else {
        page.view(1)[0].xblock_size = MI_HUGE_BLOCK_SIZE;
    }
    (page_start, page_size) = _mi_segment_page_start(segment, page);

    page.view(1)[0].reserved = u16.wrap(page_size // block_size);
    page.view(1)[0].free_is_zero = page.view(1)[0].is_zero_init;

    mi_page_extend_free(heap, page, tld);
}

impl mi_page_queue_find_free_ex(
    heap: ptr[mi_heap_t], pq: ptr[mi_page_queue_t], first_try: bool
) -> ptr[mi_page_t] {
    page = pq.view(1)[0].first;
    while page {
        next = page.view(1)[0].next;

        _mi_page_free_collect(page, False);

        if mi_page_immediate_available(page) {
            break;
        }

        if page.view(1)[0].capacity < page.view(1)[0].reserved {
            mi_page_extend_free(heap, page, heap.view(1)[0].tld);
            break;
        }

        mi_page_to_full(page, pq);
        page = next;
    }

    if not page {
        _PyMem_mi_heap_collect_qsbr(ptr(heap));

        _mi_heap_collect_retired(heap, False);
        page = mi_page_fresh(heap, pq);
        if not page and first_try {
            page = mi_page_queue_find_free_ex(heap, pq, False);
        }
    } else {
        page.view(1)[0].retire_expire = u8(0);
        _PyMem_mi_page_clear_qsbr(ptr(page));
    }
    return page;
}

impl mi_find_free_page(heap: ptr[mi_heap_t], size: u64) -> ptr[mi_page_t] {
    pq = mi_page_queue(heap, size);
    page = pq.view(1)[0].first;
    if page {
        _mi_page_free_collect(page, False);
        if mi_page_immediate_available(page) {
            page.view(1)[0].retire_expire = u8(0);
            _PyMem_mi_page_clear_qsbr(ptr(page));

            return page;
        }
    }
    return mi_page_queue_find_free_ex(heap, pq, True);
}

impl _mi_deferred_free(heap: ptr[mi_heap_t], force: bool) {
    tld = heap.view(1)[0].tld;
    tld.view(1)[0].heartbeat = wrapping_add(tld.view(1)[0].heartbeat, u64(1));
    deferred = addressof(mi_page_deferred);
    fun = deferred.view(1)[0].deferred_free;
    if int(fun) != 0 and not tld.view(1)[0].recurse {
        tld.view(1)[0].recurse = True;
        arg = mi_atomic_load_relaxed(mi_word_addr(ptr[u8](deferred), 8));
        mi_call_deferred_free(
            ptr(fun), force, tld.view(1)[0].heartbeat, ptr(ptr[u8](i64.wrap(arg)))
        );
        tld.view(1)[0].recurse = False;
    }
}

impl mi_large_huge_page_alloc(
    heap: ptr[mi_heap_t], size: u64, page_alignment: u64
) -> ptr[mi_page_t] {
    block_size = _mi_os_good_alloc_size(size);

    is_huge = block_size > MI_LARGE_OBJ_SIZE_MAX or page_alignment > u64(0);

    queue_size: u64 = block_size;
    if is_huge {
        queue_size = u64(MI_HUGE_BLOCK_SIZE);
    }
    pq = mi_page_queue(heap, queue_size);
    page = mi_page_fresh_alloc(heap, pq, block_size, page_alignment);

    return page;
}

impl mi_find_page(
    heap: ptr[mi_heap_t], size: u64, huge_alignment: u64
) -> ptr[mi_page_t] {
    req_size = wrapping_sub(size, MI_PADDING_SIZE);
    if req_size > (MI_MEDIUM_OBJ_SIZE_MAX - MI_PADDING_SIZE)
        or huge_alignment > u64(0) {
        if req_size > u64(0x7FFFFFFFFFFFFFFF) {
            _mi_error_message(
                EOVERFLOW,
                ptr[u8]("allocation request is too large (%zu bytes)\n"),
                req_size,
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            return ptr[mi_page_t]();
        }
        _PyMem_mi_heap_collect_qsbr(ptr(heap));
        return mi_large_huge_page_alloc(heap, size, huge_alignment);
    }

    return mi_find_free_page(heap, size);
}

impl _mi_malloc_generic(
    heap: ptr[mi_heap_t], size: u64, zero: bool, huge_alignment: u64
) -> ptr[u8] {
    hp = heap;

    if not mi_heap_is_initialized(hp) {
        hp = ptr[mi_heap_t](mi_heap_get_default());
        if not mi_heap_is_initialized(hp) {
            return ptr[u8]();
        }
    }

    _mi_deferred_free(hp, False);

    _mi_heap_delayed_free_partial(hp);

    page = mi_find_page(hp, size, huge_alignment);
    if not page {
        mi_heap_collect(ptr(hp), True);
        page = mi_find_page(hp, size, huge_alignment);
    }
    if not page {
        req_size = wrapping_sub(size, MI_PADDING_SIZE);
        _mi_error_message(
            ENOMEM,
            ptr[u8]("unable to allocate memory (%zu bytes)\n"),
            req_size,
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        return ptr[u8]();
    }

    if zero and page.view(1)[0].xblock_size == u32(0) {
        p = _mi_page_malloc(hp, page, size, False);
        _mi_memzero_aligned(ptr(p), mi_page_usable_block_size(page));
        return p;
    }
    return _mi_page_malloc(hp, page, size, zero);
}


impl rotl(x: u32, shift: u32) -> u32 {
    return wrapping_shl(x, shift) | (x >> (u32(32) - shift));
}

impl qround(x: ptr[u32], a: i64, b: i64, c: i64, d: i64) {
    x.view(16)[a] = wrapping_add(x.view(16)[a], x.view(16)[b]);
    x.view(16)[d] = rotl(x.view(16)[d] ^ x.view(16)[a], u32(16));
    x.view(16)[c] = wrapping_add(x.view(16)[c], x.view(16)[d]);
    x.view(16)[b] = rotl(x.view(16)[b] ^ x.view(16)[c], u32(12));
    x.view(16)[a] = wrapping_add(x.view(16)[a], x.view(16)[b]);
    x.view(16)[d] = rotl(x.view(16)[d] ^ x.view(16)[a], u32(8));
    x.view(16)[c] = wrapping_add(x.view(16)[c], x.view(16)[d]);
    x.view(16)[b] = rotl(x.view(16)[b] ^ x.view(16)[c], u32(7));
}

impl chacha_block(ctx: ptr[mi_random_ctx_t]) {
    slots: own MiStack = MiStack();
    x = ptr[u32](jacpy_stack_address(&mut slots));
    inp = mi_random_input(ctx);
    outp = mi_random_output(ctx);

    for i in range(16) {
        x.view(16)[i] = inp.view(16)[i];
    }
    r: i64 = 0;
    while r < MI_CHACHA_ROUNDS {
        qround(x, 0, 4, 8, 12);
        qround(x, 1, 5, 9, 13);
        qround(x, 2, 6, 10, 14);
        qround(x, 3, 7, 11, 15);
        qround(x, 0, 5, 10, 15);
        qround(x, 1, 6, 11, 12);
        qround(x, 2, 7, 8, 13);
        qround(x, 3, 4, 9, 14);
        r = r + 2;
    }

    for i in range(16) {
        outp.view(16)[i] = wrapping_add(x.view(16)[i], inp.view(16)[i]);
    }
    ctx.view(1)[0].output_available = 16;

    inp.view(16)[12] = wrapping_add(inp.view(16)[12], u32(1));
    if inp.view(16)[12] == u32(0) {
        inp.view(16)[13] = wrapping_add(inp.view(16)[13], u32(1));
        if inp.view(16)[13] == u32(0) {
            inp.view(16)[14] = wrapping_add(inp.view(16)[14], u32(1));
        }
    }
}

impl chacha_next32(ctx: ptr[mi_random_ctx_t]) -> u32 {
    if ctx.view(1)[0].output_available <= 0 {
        chacha_block(ctx);

        ctx.view(1)[0].output_available = 16;
    }
    slot = mi_random_output(ctx) + i64(16 - ctx.view(1)[0].output_available);
    x = slot.view(1)[0];

    slot.view(1)[0] = u32(0);
    ctx.view(1)[0].output_available = ctx.view(1)[0].output_available - 1;
    return x;
}

impl read32(p: ptr[u8], idx32: u64) -> u32 {
    i = i64.wrap(u64(4) * idx32);
    return (
        u32((p + i).view(1)[0])
        | (u32((p + (i + 1)).view(1)[0]) << u32(8))
        | (u32((p + (i + 2)).view(1)[0]) << u32(16))
        | (u32((p + (i + 3)).view(1)[0]) << u32(24))
    );
}

impl chacha_init(ctx: ptr[mi_random_ctx_t], key: ptr[u8], nonce: u64) {
    memset(ptr(ctx), 0, mi_random_ctx_t_SIZE);
    inp = mi_random_input(ctx);
    sigma = ptr[u8]("expand 32-byte k");
    for i in range(4) {
        inp.view(16)[i] = read32(sigma, u64(i));
    }
    for i in range(8) {
        inp.view(16)[i + 4] = read32(key, u64(i));
    }
    inp.view(16)[12] = u32(0);
    inp.view(16)[13] = u32(0);
    inp.view(16)[14] = u32.wrap(nonce);
    inp.view(16)[15] = u32.wrap(nonce >> u64(32));
}

impl chacha_split(
    ctx: ptr[mi_random_ctx_t], nonce: u64, ctx_new: ptr[mi_random_ctx_t]
) {
    memset(ptr(ctx_new), 0, mi_random_ctx_t_SIZE);
    inp_new = mi_random_input(ctx_new);
    _mi_memcpy(ptr(inp_new), ptr(mi_random_input(ctx)), u64(64));
    inp_new.view(16)[12] = u32(0);
    inp_new.view(16)[13] = u32(0);
    inp_new.view(16)[14] = u32.wrap(nonce);
    inp_new.view(16)[15] = u32.wrap(nonce >> u64(32));

    chacha_block(ctx_new);
}

impl _mi_random_split(ctx: ptr[mi_random_ctx_t], ctx_new: ptr[mi_random_ctx_t]) {
    chacha_split(ctx, u64.wrap(int(ctx_new)), ctx_new);
}

impl _mi_random_next(ctx: ptr[mi_random_ctx_t]) -> u64 {
    hi = chacha_next32(ctx);
    lo = chacha_next32(ctx);
    return wrapping_shl(u64(hi), u64(32)) | u64(lo);
}

impl _mi_os_random_weak(extra_seed: u64) -> u64 {
    x = u64.wrap(int(ptr(_mi_os_random_weak))) ^ extra_seed;
    x = x ^ u64.wrap(_mi_prim_clock_now());

    max_steps = ((x ^ (x >> u64(17))) & u64(0x0F)) + u64(1);
    i: u64 = 0;
    while i < max_steps {
        x = _mi_random_shuffle(x);
        i = i + u64(1);
    }
    return x;
}

impl mi_random_init_ex(ctx: ptr[mi_random_ctx_t], use_weak: bool) {
    slots: own MiStack = MiStack();
    key = ptr[u8](jacpy_stack_address(&mut slots));
    if use_weak or not _mi_prim_random_buf(key, u64(32)) {
        if not use_weak {
            _mi_warning_message(
                ptr[u8]("unable to use secure randomness\n"),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        }
        x = _mi_os_random_weak(u64(0));
        words = ptr[u32](key);
        for i in range(8) {
            x = _mi_random_shuffle(x);
            words.view(8)[i] = u32.wrap(x);
        }
        ctx.view(1)[0].weak = True;
    } else {
        ctx.view(1)[0].weak = False;
    }
    chacha_init(ctx, key, u64.wrap(int(ctx)));
}

impl _mi_random_init(ctx: ptr[mi_random_ctx_t]) {
    mi_random_init_ex(ctx, False);
}

impl _mi_random_init_weak(ctx: ptr[mi_random_ctx_t]) {
    mi_random_init_ex(ctx, True);
}

impl _mi_random_reinit_if_weak(ctx: ptr[mi_random_ctx_t]) {
    if ctx.view(1)[0].weak {
        _mi_random_init(ctx);
    }
}


impl mi_segment_slice_diff(a: ptr[mi_page_t], b: ptr[mi_page_t]) -> i64 {
    return (int(a) - int(b)) // i64(mi_page_t_SIZE);
}

impl mi_commit_mask_all_set(
    commit: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]
) -> bool {
    a = ptr[u64](commit);
    b = ptr[u64](cm);
    for i in range(8) {
        if ((a + i).view(1)[0] & (b + i).view(1)[0]) != (b + i).view(1)[0] {
            return False;
        }
    }
    return True;
}

impl mi_commit_mask_any_set(
    commit: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]
) -> bool {
    a = ptr[u64](commit);
    b = ptr[u64](cm);
    for i in range(8) {
        if ((a + i).view(1)[0] & (b + i).view(1)[0]) != u64(0) {
            return True;
        }
    }
    return False;
}

impl mi_commit_mask_create_intersect(
    commit: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t], res: ptr[mi_commit_mask_t]
) {
    a = ptr[u64](commit);
    b = ptr[u64](cm);
    r = ptr[u64](res);
    for i in range(8) {
        (r + i).view(1)[0] = (a + i).view(1)[0] & (b + i).view(1)[0];
    }
}

impl mi_commit_mask_clear(res: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]) {
    r = ptr[u64](res);
    b = ptr[u64](cm);
    for i in range(8) {
        (r + i).view(1)[0] = (r + i).view(1)[0] & ~(b + i).view(1)[0];
    }
}

impl mi_commit_mask_set(res: ptr[mi_commit_mask_t], cm: ptr[mi_commit_mask_t]) {
    r = ptr[u64](res);
    b = ptr[u64](cm);
    for i in range(8) {
        (r + i).view(1)[0] = (r + i).view(1)[0] | (b + i).view(1)[0];
    }
}

impl mi_commit_mask_create(bitidx: u64, bitcount: u64, cm: ptr[mi_commit_mask_t]) {
    if bitcount == MI_COMMIT_MASK_BITS {
        mi_commit_mask_create_full(cm);
    } elif bitcount == u64(0) {
        mi_commit_mask_create_empty(cm);
    } else {
        mi_commit_mask_create_empty(cm);
        m = ptr[u64](cm);
        i = bitidx // MI_COMMIT_MASK_FIELD_BITS;
        ofs = bitidx % MI_COMMIT_MASK_FIELD_BITS;
        left = bitcount;
        while left > u64(0) {
            avail = MI_COMMIT_MASK_FIELD_BITS - ofs;
            count = left;
            if left > avail {
                count = avail;
            }
            mask = ~u64(0);
            if count < MI_COMMIT_MASK_FIELD_BITS {
                mask = wrapping_shl(wrapping_shl(u64(1), count) - u64(1), ofs);
            }
            (m + i64.wrap(i)).view(1)[0] = mask;
            left = left - count;
            ofs = u64(0);
            i = i + u64(1);
        }
    }
}

impl _mi_commit_mask_committed_size(cm: ptr[mi_commit_mask_t], total: u64) -> u64 {
    m = ptr[u64](cm);
    count: u64 = 0;
    for i in range(8) {
        mask = (m + i).view(1)[0];
        if ~mask == u64(0) {
            count = count + MI_COMMIT_MASK_FIELD_BITS;
        } else {
            while mask != u64(0) {
                if (mask & u64(1)) != u64(0) {
                    count = count + u64(1);
                }
                mask = mask >> u64(1);
            }
        }
    }
    return (total // MI_COMMIT_MASK_BITS) * count;
}

impl _mi_commit_mask_next_run(cm: ptr[mi_commit_mask_t], idx: u64) -> tuple[u64, u64] {
    m = ptr[u64](cm);
    i = idx // MI_COMMIT_MASK_FIELD_BITS;
    ofs = idx % MI_COMMIT_MASK_FIELD_BITS;
    mask: u64 = 0;

    while i < MI_COMMIT_MASK_FIELD_COUNT {
        mask = (m + i64.wrap(i)).view(1)[0];
        mask = mask >> ofs;
        if mask != u64(0) {
            while (mask & u64(1)) == u64(0) {
                mask = mask >> u64(1);
                ofs = ofs + u64(1);
            }
            break;
        }
        i = i + u64(1);
        ofs = u64(0);
    }
    if i >= MI_COMMIT_MASK_FIELD_COUNT {
        return (u64(0), MI_COMMIT_MASK_BITS);
    }

    count: u64 = 0;
    start = (i * MI_COMMIT_MASK_FIELD_BITS) + ofs;
    while True {
        while True {
            count = count + u64(1);
            mask = mask >> u64(1);
            if (mask & u64(1)) != u64(1) {
                break;
            }
        }
        if ((start + count) % MI_COMMIT_MASK_FIELD_BITS) == u64(0) {
            i = i + u64(1);
            if i >= MI_COMMIT_MASK_FIELD_COUNT {
                break;
            }
            mask = (m + i64.wrap(i)).view(1)[0];
            ofs = u64(0);
        }
        if (mask & u64(1)) != u64(1) {
            break;
        }
    }
    return (count, start);
}

impl mi_segment_slices_end(segment: ptr[mi_segment_t]) -> ptr[mi_page_t] {
    return mi_segment_slices(segment) + i64.wrap(segment.view(1)[0].slice_entries);
}

impl mi_slice_start(slice: ptr[mi_page_t]) -> ptr[u8] {
    segment = _mi_ptr_segment(ptr[u8](slice));
    idx = mi_segment_slice_diff(slice, mi_segment_slices(segment));
    return ptr[u8](segment) + (idx * i64(MI_SEGMENT_SLICE_SIZE));
}

impl mi_slice_bin8(slice_count: u64) -> u64 {
    if slice_count <= u64(1) {
        return slice_count;
    }
    sc = slice_count - u64(1);
    s = mi_bsr(sc);
    if s <= u64(2) {
        return sc + u64(1);
    }
    return ((s << u64(2)) | ((sc >> (s - u64(2))) & u64(3))) - u64(4);
}

impl mi_slice_bin(slice_count: u64) -> u64 {
    return mi_slice_bin8(slice_count);
}

impl mi_slice_index(slice: ptr[mi_page_t]) -> u64 {
    segment = _mi_ptr_segment(ptr[u8](slice));
    return u64.wrap(mi_segment_slice_diff(slice, mi_segment_slices(segment)));
}

impl mi_span_queue_push(sq: ptr[mi_span_queue_t], slice: ptr[mi_page_t]) {
    slice.view(1)[0].prev = ptr[mi_page_t]();
    slice.view(1)[0].next = sq.view(1)[0].first;
    sq.view(1)[0].first = slice;
    nxt = slice.view(1)[0].next;
    if nxt {
        nxt.view(1)[0].prev = slice;
    } else {
        sq.view(1)[0].last = slice;
    }

    slice.view(1)[0].xblock_size = u32(0);
}

impl mi_span_queue_for(
    slice_count: u64, tld: ptr[mi_segments_tld_t]
) -> ptr[mi_span_queue_t] {
    bin = mi_slice_bin(slice_count);
    return mi_segments_tld_span_queue(tld, bin);
}

impl mi_span_queue_delete(sq: ptr[mi_span_queue_t], slice: ptr[mi_page_t]) {
    prv = slice.view(1)[0].prev;
    nxt = slice.view(1)[0].next;
    if prv {
        prv.view(1)[0].next = nxt;
    }
    if slice == sq.view(1)[0].first {
        sq.view(1)[0].first = nxt;
    }
    if nxt {
        nxt.view(1)[0].prev = prv;
    }
    if slice == sq.view(1)[0].last {
        sq.view(1)[0].last = prv;
    }
    slice.view(1)[0].prev = ptr[mi_page_t]();
    slice.view(1)[0].next = ptr[mi_page_t]();

    slice.view(1)[0].xblock_size = u32(1);
}

impl mi_slice_is_used(slice: ptr[mi_page_t]) -> bool {
    return slice.view(1)[0].xblock_size > u32(0);
}

impl mi_segment_info_size(segment: ptr[mi_segment_t]) -> u64 {
    return segment.view(1)[0].segment_info_slices * MI_SEGMENT_SLICE_SIZE;
}

impl _mi_segment_page_start_from_slice(
    segment: ptr[mi_segment_t], slice: ptr[mi_page_t], xblock_size: u64
) -> tuple[ptr[u8], u64] {
    idx = mi_segment_slice_diff(slice, mi_segment_slices(segment));
    psize = u64(slice.view(1)[0].slice_count) * MI_SEGMENT_SLICE_SIZE;
    start_offset: u64 = 0;
    if xblock_size >= MI_INTPTR_SIZE {
        if xblock_size <= u64(64) {
            start_offset = u64(3) * xblock_size;
        } elif xblock_size <= u64(512) {
            start_offset = xblock_size;
        }
    }
    start = ptr[u8](segment)
        + (idx * i64(MI_SEGMENT_SLICE_SIZE) + i64.wrap(start_offset));
    return (start, wrapping_sub(psize, start_offset));
}

impl _mi_segment_page_start(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t]
) -> tuple[ptr[u8], u64] {
    return _mi_segment_page_start_from_slice(
        segment, page, u64(page.view(1)[0].xblock_size)
    );
}

impl mi_segment_calculate_slices(required: u64) -> tuple[u64, u64, u64] {
    page_size = _mi_os_page_size();
    isize = _mi_align_up(mi_segment_t_SIZE, page_size);
    pre_size = isize;
    isize = _mi_align_up(isize, MI_SEGMENT_SLICE_SIZE);
    info_slices = isize // MI_SEGMENT_SLICE_SIZE;
    segment_size = MI_SEGMENT_SIZE;
    if required != u64(0) {
        segment_size = _mi_align_up(
            wrapping_add(required, isize), MI_SEGMENT_SLICE_SIZE
        );
    }
    return (segment_size // MI_SEGMENT_SLICE_SIZE, pre_size, info_slices);
}

impl mi_segments_track_size(segment_size: i64, tld: ptr[mi_segments_tld_t]) {
    stats = tld.view(1)[0].stats;
    if segment_size >= 0 {
        _mi_stat_increase(mi_stat_count_at(stats, mi_stats_t_SEGMENTS), u64(1));
        tld.view(1)[0].count = wrapping_add(tld.view(1)[0].count, u64(1));
    } else {
        _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_SEGMENTS), u64(1));
        tld.view(1)[0].count = wrapping_sub(tld.view(1)[0].count, u64(1));
    }
    if tld.view(1)[0].count > tld.view(1)[0].peak_count {
        tld.view(1)[0].peak_count = tld.view(1)[0].count;
    }
    tld.view(1)[0].current_size = wrapping_add(
        tld.view(1)[0].current_size, u64.wrap(segment_size)
    );
    if tld.view(1)[0].current_size > tld.view(1)[0].peak_size {
        tld.view(1)[0].peak_size = tld.view(1)[0].current_size;
    }
}

impl mi_segment_os_free(segment: ptr[mi_segment_t], tld: ptr[mi_segments_tld_t]) {
    mi_atomic_store_seq_cst(mi_segment_thread_id_addr(segment), u64(0));
    _mi_segment_map_freed_at(segment);
    mi_segments_track_size(-i64.wrap(mi_segment_size(segment)), tld);

    size = mi_segment_size(segment);
    csize = _mi_commit_mask_committed_size(mi_segment_commit_mask_of(segment), size);

    _mi_abandoned_await_readers(tld.view(1)[0].abandoned);
    _mi_arena_free(
        ptr[u8](segment),
        mi_segment_size(segment),
        csize,
        mi_segment_memid(segment),
        tld.view(1)[0].stats
    );
}

impl _mi_segment_thread_collect(tld: ptr[mi_segments_tld_t]) {
    return;
}

impl mi_segment_commit_mask(
    segment: ptr[mi_segment_t],
    conservative: bool,
    p: ptr[u8],
    size: u64,
    cm: ptr[mi_commit_mask_t]
) -> tuple[ptr[u8], u64] {
    mi_commit_mask_create_empty(cm);
    if size == u64(0)
        or size > MI_SEGMENT_SIZE
        or segment.view(1)[0].kind == MI_SEGMENT_HUGE {
        return (ptr[u8](), u64(0));
    }
    segstart = mi_segment_info_size(segment);
    segsize = mi_segment_size(segment);
    if int(p) >= int(segment) + i64.wrap(segsize) {
        return (ptr[u8](), u64(0));
    }
    pstart = u64.wrap(int(p) - int(segment));
    start: u64 = 0;
    end: u64 = 0;
    if conservative {
        start = _mi_align_up(pstart, MI_COMMIT_SIZE);
        end = _mi_align_down(pstart + size, MI_COMMIT_SIZE);
    } else {
        start = _mi_align_down(pstart, MI_MINIMAL_COMMIT_SIZE);
        end = _mi_align_up(pstart + size, MI_MINIMAL_COMMIT_SIZE);
    }

    if pstart >= segstart and start < segstart {
        start = segstart;
    }
    if end > segsize {
        end = segsize;
    }
    start_p = ptr[u8](segment) + i64.wrap(start);
    full_size: u64 = 0;
    if end > start {
        full_size = end - start;
    }
    if full_size == u64(0) {
        return (start_p, full_size);
    }
    bitidx = start // MI_COMMIT_SIZE;

    bitcount = full_size // MI_COMMIT_SIZE;
    if bitidx + bitcount > MI_COMMIT_MASK_BITS {
        _mi_warning_message(
            ptr[u8](
                "commit mask overflow: idx=%zu count=%zu start=%zx end=%zx p=0x%p size=%zu fullsize=%zu\n"
            ),
            bitidx,
            bitcount,
            start,
            end,
            u64.wrap(int(p)),
            size,
            full_size
        );
    }
    mi_commit_mask_create(bitidx, bitcount, cm);
    return (start_p, full_size);
}

impl mi_segment_commit(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) -> bool {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    mask = ptr[mi_commit_mask_t](base);
    cmask = ptr[mi_commit_mask_t](base + 64);

    (start, full_size) = mi_segment_commit_mask(segment, False, p, size, mask);
    if mi_commit_mask_is_empty(mask) or full_size == u64(0) {
        return True;
    }
    commit_mask = mi_segment_commit_mask_of(segment);
    if not mi_commit_mask_all_set(commit_mask, mask) {
        mi_commit_mask_create_intersect(commit_mask, mask, cmask);

        _mi_stat_decrease(
            mi_stat_count_at(addressof(_mi_stats_main), mi_stats_t_COMMITTED),
            _mi_commit_mask_committed_size(cmask, MI_SEGMENT_SIZE)
        );
        (ok, is_zero) = _mi_os_commit(start, full_size, stats);
        if not ok {
            return False;
        }
        mi_commit_mask_set(commit_mask, mask);
    }

    purge_mask = mi_segment_purge_mask_of(segment);
    if mi_commit_mask_any_set(purge_mask, mask) {
        segment.view(1)[0].purge_expire = _mi_clock_now()
            + mi_option_get(mi_option_purge_delay);
    }

    mi_commit_mask_clear(purge_mask, mask);
    return True;
}

impl mi_segment_ensure_committed(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) -> bool {
    if mi_commit_mask_is_full(mi_segment_commit_mask_of(segment))
        and mi_commit_mask_is_empty(mi_segment_purge_mask_of(segment)) {
        return True;
    }
    return mi_segment_commit(segment, p, size, stats);
}

impl mi_segment_purge(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) -> bool {
    if not segment.view(1)[0].allow_purge {
        return True;
    }
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    mask = ptr[mi_commit_mask_t](base);
    cmask = ptr[mi_commit_mask_t](base + 64);

    (start, full_size) = mi_segment_commit_mask(segment, True, p, size, mask);
    if mi_commit_mask_is_empty(mask) or full_size == u64(0) {
        return True;
    }
    commit_mask = mi_segment_commit_mask_of(segment);
    if mi_commit_mask_any_set(commit_mask, mask) {
        decommitted = _mi_os_purge(start, full_size, stats);
        if decommitted {
            mi_commit_mask_create_intersect(commit_mask, mask, cmask);

            _mi_stat_increase(
                mi_stat_count_at(addressof(_mi_stats_main), mi_stats_t_COMMITTED),
                wrapping_sub(
                    full_size, _mi_commit_mask_committed_size(cmask, MI_SEGMENT_SIZE)
                )
            );
            mi_commit_mask_clear(commit_mask, mask);
        }
    }

    mi_commit_mask_clear(mi_segment_purge_mask_of(segment), mask);
    return True;
}

impl mi_segment_schedule_purge(
    segment: ptr[mi_segment_t], p: ptr[u8], size: u64, stats: ptr[mi_stats_t]
) {
    if not segment.view(1)[0].allow_purge {
        return;
    }
    if mi_option_get(mi_option_purge_delay) == 0 {
        mi_segment_purge(segment, p, size, stats);
    } else {
        slots: own MiStack = MiStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        mask = ptr[mi_commit_mask_t](base);
        cmask = ptr[mi_commit_mask_t](base + 64);
        (start, full_size) = mi_segment_commit_mask(segment, True, p, size, mask);
        if mi_commit_mask_is_empty(mask) or full_size == u64(0) {
            return;
        }
        mi_commit_mask_create_intersect(
            mi_segment_commit_mask_of(segment), mask, cmask
        );
        mi_commit_mask_set(mi_segment_purge_mask_of(segment), cmask);
        now = _mi_clock_now();
        if segment.view(1)[0].purge_expire == 0 {
            segment.view(1)[0].purge_expire = now
                + mi_option_get(mi_option_purge_delay);
        } elif segment.view(1)[0].purge_expire <= now {
            if segment.view(1)[0].purge_expire
                + mi_option_get(mi_option_purge_extend_delay)
                <= now {
                mi_segment_try_purge(segment, True, stats);
            } else {
                segment.view(1)[0].purge_expire = now
                    + mi_option_get(mi_option_purge_extend_delay);
            }
        } else {
            segment.view(1)[0].purge_expire = segment.view(1)[0].purge_expire
                + mi_option_get(mi_option_purge_extend_delay);
        }
    }
}

impl mi_segment_try_purge(
    segment: ptr[mi_segment_t], force: bool, stats: ptr[mi_stats_t]
) {
    purge_mask = mi_segment_purge_mask_of(segment);
    if not segment.view(1)[0].allow_purge or mi_commit_mask_is_empty(purge_mask) {
        return;
    }
    now = _mi_clock_now();
    if not force and now < segment.view(1)[0].purge_expire {
        return;
    }
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    mask = ptr[mi_commit_mask_t](base);
    memcpy(ptr(mask), ptr(purge_mask), mi_commit_mask_t_SIZE);
    segment.view(1)[0].purge_expire = 0;
    mi_commit_mask_create_empty(purge_mask);

    idx: u64 = 0;
    while True {
        (count, run) = _mi_commit_mask_next_run(mask, idx);
        if count == u64(0) {
            break;
        }
        idx = run;

        if count > u64(0) {
            p = ptr[u8](segment) + i64.wrap(idx * MI_COMMIT_SIZE);
            size = count * MI_COMMIT_SIZE;
            mi_segment_purge(segment, p, size, stats);
        }
        idx = idx + count;
    }
}

impl mi_segment_is_abandoned(segment: ptr[mi_segment_t]) -> bool {
    return mi_atomic_load_seq_cst(mi_segment_thread_id_addr(segment)) == u64(0);
}

impl mi_segment_span_free(
    segment: ptr[mi_segment_t],
    slice_index: u64,
    slice_count: u64,
    allow_purge: bool,
    tld: ptr[mi_segments_tld_t]
) {
    sq = ptr[mi_span_queue_t]();
    if not (
        segment.view(1)[0].kind == MI_SEGMENT_HUGE or mi_segment_is_abandoned(segment)
    ) {
        sq = mi_span_queue_for(slice_count, tld);
    }
    count = slice_count;
    if count == u64(0) {
        count = u64(1);
    }

    slice = mi_segment_slices(segment) + i64.wrap(slice_index);
    slice.view(1)[0].slice_count = u32.wrap(count);
    slice.view(1)[0].slice_offset = u32(0);
    if count > u64(1) {
        last = mi_segment_slices(segment) + i64.wrap(slice_index + count - u64(1));
        last.view(1)[0].slice_count = u32(0);
        last.view(1)[0].slice_offset = u32.wrap(mi_page_t_SIZE * (count - u64(1)));
        last.view(1)[0].xblock_size = u32(0);
    }

    if allow_purge {
        mi_segment_schedule_purge(
            segment,
            mi_slice_start(slice),
            count * MI_SEGMENT_SLICE_SIZE,
            tld.view(1)[0].stats
        );
    }

    if sq {
        mi_span_queue_push(sq, slice);
    } else {
        slice.view(1)[0].xblock_size = u32(0);
    }
}

impl mi_segment_span_remove_from_queue(
    slice: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]
) {
    sq = mi_span_queue_for(u64(slice.view(1)[0].slice_count), tld);
    mi_span_queue_delete(sq, slice);
}

impl mi_segment_span_free_coalesce(
    slice: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t] {
    segment = _mi_ptr_segment(ptr[u8](slice));
    is_abandoned = mi_segment_is_abandoned(segment);

    if segment.view(1)[0].kind == MI_SEGMENT_HUGE {
        slice.view(1)[0].xblock_size = u32(0);

        return slice;
    }

    slice_count = u64(slice.view(1)[0].slice_count);
    nxt = slice + i64(slice.view(1)[0].slice_count);
    if int(nxt) < int(mi_segment_slices_end(segment))
        and nxt.view(1)[0].xblock_size == u32(0) {
        slice_count = slice_count + u64(nxt.view(1)[0].slice_count);
        if not is_abandoned {
            mi_segment_span_remove_from_queue(nxt, tld);
        }
    }
    first = slice;
    if int(slice) > int(mi_segment_slices(segment)) {
        prv = mi_slice_first(slice + i64(-1));
        if prv.view(1)[0].xblock_size == u32(0) {
            slice_count = slice_count + u64(prv.view(1)[0].slice_count);
            if not is_abandoned {
                mi_segment_span_remove_from_queue(prv, tld);
            }
            first = prv;
        }
    }

    mi_segment_span_free(segment, mi_slice_index(first), slice_count, True, tld);
    return first;
}

impl mi_segment_span_allocate(
    segment: ptr[mi_segment_t],
    slice_index: u64,
    slice_count: u64,
    tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t] {
    slice = mi_segment_slices(segment) + i64.wrap(slice_index);

    (pstart, psize) = _mi_segment_page_start_from_slice(segment, slice, u64(0));
    if not mi_segment_ensure_committed(
        segment, pstart, slice_count * MI_SEGMENT_SLICE_SIZE, tld.view(1)[0].stats
    ) {
        return ptr[mi_page_t]();
    }

    slice.view(1)[0].slice_offset = u32(0);
    slice.view(1)[0].slice_count = u32.wrap(slice_count);
    bsize = slice_count * MI_SEGMENT_SLICE_SIZE;
    if bsize >= u64(MI_HUGE_BLOCK_SIZE) {
        slice.view(1)[0].xblock_size = MI_HUGE_BLOCK_SIZE;
    } else {
        slice.view(1)[0].xblock_size = u32.wrap(bsize);
    }
    page = slice;

    extra = wrapping_sub(slice_count, u64(1));
    if extra > MI_MAX_SLICE_OFFSET {
        extra = MI_MAX_SLICE_OFFSET;
    }

    entries = segment.view(1)[0].slice_entries;
    if slice_index + extra >= entries {
        extra = entries - slice_index - u64(1);
    }
    slice_next = slice + 1;
    i: u64 = 1;
    while i <= extra {
        slice_next.view(1)[0].slice_offset = u32.wrap(mi_page_t_SIZE * i);
        slice_next.view(1)[0].slice_count = u32(0);
        slice_next.view(1)[0].xblock_size = u32(1);
        i = i + u64(1);
        slice_next = slice_next + 1;
    }

    last = slice + i64.wrap(wrapping_sub(slice_count, u64(1)));
    end = mi_segment_slices_end(segment);
    if int(last) > int(end) {
        last = end;
    }
    if int(last) > int(slice) {
        last.view(1)[0].slice_offset = u32.wrap(
            mi_page_t_SIZE * u64.wrap(mi_segment_slice_diff(last, slice))
        );
        last.view(1)[0].slice_count = u32(0);
        last.view(1)[0].xblock_size = u32(1);
    }

    page.view(1)[0].is_committed = True;
    segment.view(1)[0].used = segment.view(1)[0].used + u64(1);
    return page;
}

impl mi_segment_slice_split(
    segment: ptr[mi_segment_t],
    slice: ptr[mi_page_t],
    slice_count: u64,
    tld: ptr[mi_segments_tld_t]
) {
    if u64(slice.view(1)[0].slice_count) <= slice_count {
        return;
    }
    next_index = mi_slice_index(slice) + slice_count;
    next_count = u64(slice.view(1)[0].slice_count) - slice_count;

    mi_segment_span_free(segment, next_index, next_count, False, tld);
    slice.view(1)[0].slice_count = u32.wrap(slice_count);
}

impl mi_segments_page_find_and_allocate(
    slice_count: u64, req_arena_id: i32, tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t] {
    sq = mi_span_queue_for(slice_count, tld);
    needed = slice_count;
    if needed == u64(0) {
        needed = u64(1);
    }
    last_sq = mi_segments_tld_span_queue(tld, MI_SEGMENT_BIN_MAX);
    while int(sq) <= int(last_sq) {
        slice = sq.view(1)[0].first;
        while slice {
            if u64(slice.view(1)[0].slice_count) >= needed {
                segment = _mi_ptr_segment(ptr[u8](slice));
                if _mi_arena_memid_is_suitable(
                    mi_segment_memid(segment), req_arena_id
                ) {
                    mi_span_queue_delete(sq, slice);
                    if u64(slice.view(1)[0].slice_count) > needed {
                        mi_segment_slice_split(segment, slice, needed, tld);
                    }
                    page = mi_segment_span_allocate(
                        segment,
                        mi_slice_index(slice),
                        u64(slice.view(1)[0].slice_count),
                        tld
                    );
                    if not page {
                        mi_segment_span_free_coalesce(slice, tld);
                        return ptr[mi_page_t]();
                    }
                    return page;
                }
            }
            slice = slice.view(1)[0].next;
        }
        sq = sq + 1;
    }

    return ptr[mi_page_t]();
}

impl mi_segment_os_alloc(
    required: u64,
    page_alignment: u64,
    eager_delayed: bool,
    req_arena_id: i32,
    psegment_slices: u64,
    ppre_size: u64,
    pinfo_slices: u64,
    commit: bool,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> tuple[ptr[mi_segment_t], u64, u64, u64] {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    memid = ptr[mi_memid_t](base);
    commit_mask = ptr[mi_commit_mask_t](base + 24);
    segment_slices = psegment_slices;
    pre_size = ppre_size;
    info_slices = pinfo_slices;

    allow_large = not eager_delayed;
    align_offset: u64 = 0;
    alignment = MI_SEGMENT_ALIGN;
    if page_alignment > u64(0) {
        alignment = page_alignment;
        info_size = info_slices * MI_SEGMENT_SLICE_SIZE;
        align_offset = _mi_align_up(info_size, MI_SEGMENT_ALIGN);
        extra = align_offset - info_size;

        (new_slices, new_pre_size, new_info_slices) = mi_segment_calculate_slices(
            wrapping_add(required, extra)
        );
        segment_slices = new_slices;
        pre_size = new_pre_size;
        info_slices = new_info_slices;

        if segment_slices > u64(0xFFFFFFFF) {
            return (ptr[mi_segment_t](), segment_slices, pre_size, info_slices);
        }
    }
    segment_size = segment_slices * MI_SEGMENT_SLICE_SIZE;
    segment = ptr[mi_segment_t](
        _mi_arena_alloc_aligned(
            segment_size,
            alignment,
            align_offset,
            commit,
            allow_large,
            req_arena_id,
            memid,
            os_tld
        )
    );
    if not segment {
        return (ptr[mi_segment_t](), segment_slices, pre_size, info_slices);
    }

    if memid.view(1)[0].initially_committed {
        mi_commit_mask_create_full(commit_mask);
    } else {
        commit_needed = _mi_divide_up(
            info_slices * MI_SEGMENT_SLICE_SIZE, MI_COMMIT_SIZE
        );
        mi_commit_mask_create(u64(0), commit_needed, commit_mask);
        (ok, is_zero) = _mi_os_commit(
            ptr[u8](segment), commit_needed * MI_COMMIT_SIZE, tld.view(1)[0].stats
        );
        if not ok {
            _mi_arena_free(
                ptr[u8](segment), segment_size, u64(0), memid, tld.view(1)[0].stats
            );
            return (ptr[mi_segment_t](), segment_slices, pre_size, info_slices);
        }
    }
    mi_memid_copy(mi_segment_memid(segment), memid);
    segment.view(1)[0].allow_decommit = not memid.view(1)[0].is_pinned;
    segment.view(1)[0].allow_purge = segment.view(1)[0].allow_decommit
        and (mi_option_get(mi_option_purge_delay) >= 0);
    segment.view(1)[0].segment_size = segment_size;
    memcpy(
        ptr(mi_segment_commit_mask_of(segment)), ptr(commit_mask), mi_commit_mask_t_SIZE
    );
    segment.view(1)[0].purge_expire = 0;
    mi_commit_mask_create_empty(mi_segment_purge_mask_of(segment));

    mi_atomic_store_release(mi_segment_abandoned_next_addr(segment), u64(0));
    mi_segments_track_size(i64.wrap(segment_size), tld);
    _mi_segment_map_allocated_at(segment);
    return (segment, segment_slices, pre_size, info_slices);
}

impl mi_segment_alloc(
    required: u64,
    page_alignment: u64,
    req_arena_id: i32,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> tuple[ptr[mi_segment_t], ptr[mi_page_t]] {
    (calc_slices, calc_pre_size, calc_info_slices) = mi_segment_calculate_slices(
        required
    );

    if calc_slices > u64(0xFFFFFFFF) {
        return (ptr[mi_segment_t](), ptr[mi_page_t]());
    }

    eager_delay = _mi_current_thread_count() > u64(1)
        and tld.view(1)[0].count
            < u64.wrap(mi_option_get(mi_option_eager_commit_delay));
    eager = not eager_delay and mi_option_is_enabled(mi_option_eager_commit);
    commit = eager or (required > u64(0));

    (segment, segment_slices, pre_size, info_slices) = mi_segment_os_alloc(
        required,
        page_alignment,
        eager_delay,
        req_arena_id,
        calc_slices,
        calc_pre_size,
        calc_info_slices,
        commit,
        tld,
        os_tld
    );
    if not segment {
        return (ptr[mi_segment_t](), ptr[mi_page_t]());
    }

    if not mi_segment_memid(segment).view(1)[0].initially_zero {
        ofs = mi_segment_t_NEXT;
        prefix = u64.wrap(mi_segment_t_SLICES - ofs);

        zsize = prefix + (mi_page_t_SIZE * (segment_slices + u64(1)));
        _mi_memzero(ptr(ptr[u8](segment) + ofs), zsize);
    }

    slice_entries = segment_slices;
    if segment_slices > MI_SLICES_PER_SEGMENT {
        slice_entries = MI_SLICES_PER_SEGMENT;
    }
    segment.view(1)[0].segment_slices = segment_slices;
    segment.view(1)[0].segment_info_slices = info_slices;
    mi_atomic_store_seq_cst(mi_segment_thread_id_addr(segment), _mi_thread_id());
    segment.view(1)[0].cookie = _mi_ptr_cookie(ptr[u8](segment));
    segment.view(1)[0].slice_entries = slice_entries;
    if required == u64(0) {
        segment.view(1)[0].kind = MI_SEGMENT_NORMAL;
    } else {
        segment.view(1)[0].kind = MI_SEGMENT_HUGE;
    }
    _mi_stat_increase(
        mi_stat_count_at(tld.view(1)[0].stats, mi_stats_t_PAGE_COMMITTED),
        mi_segment_info_size(segment)
    );

    guard_slices: u64 = 0;

    page0 = mi_segment_span_allocate(segment, u64(0), info_slices, tld);
    if not page0 {
        return (ptr[mi_segment_t](), ptr[mi_page_t]());
    }

    segment.view(1)[0].used = u64(0);

    huge_page = ptr[mi_page_t]();
    if segment.view(1)[0].kind == MI_SEGMENT_NORMAL {
        mi_segment_span_free(
            segment,
            info_slices,
            segment.view(1)[0].slice_entries - info_slices,
            False,
            tld
        );
    } else {
        huge_page = mi_segment_span_allocate(
            segment, info_slices, segment_slices - info_slices - guard_slices, tld
        );
    }
    return (segment, huge_page);
}

impl mi_segment_free(
    segment: ptr[mi_segment_t], force: bool, tld: ptr[mi_segments_tld_t]
) {
    slice = mi_segment_slices(segment);
    end = mi_segment_slices_end(segment);
    while int(slice) < int(end) {
        if slice.view(1)[0].xblock_size == u32(0)
            and segment.view(1)[0].kind != MI_SEGMENT_HUGE {
            mi_segment_span_remove_from_queue(slice, tld);
        }
        slice = slice + i64(slice.view(1)[0].slice_count);
    }

    _mi_stat_decrease(
        mi_stat_count_at(tld.view(1)[0].stats, mi_stats_t_PAGE_COMMITTED),
        mi_segment_info_size(segment)
    );

    mi_segment_os_free(segment, tld);
}

impl mi_segment_page_clear(
    page: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]
) -> ptr[mi_page_t] {
    segment = _mi_ptr_segment(ptr[u8](page));
    stats = tld.view(1)[0].stats;
    inuse = u64(page.view(1)[0].capacity) * mi_page_block_size(page);
    _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_PAGE_COMMITTED), inuse);
    _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_PAGES), u64(1));

    if segment.view(1)[0].allow_decommit
        and mi_option_is_enabled(mi_option_deprecated_page_reset) {
        (start, psize) = _mi_page_start(segment, page);
        _mi_os_reset(start, psize, stats);
    }

    page.view(1)[0].is_zero_init = False;
    ofs = mi_page_t_CLEAR_FROM;
    _mi_memzero(ptr(ptr[u8](page) + ofs), mi_page_t_SIZE - u64(ofs));
    page.view(1)[0].xblock_size = u32(1);

    slice = mi_segment_span_free_coalesce(page, tld);
    segment.view(1)[0].used = wrapping_sub(segment.view(1)[0].used, u64(1));

    return slice;
}

impl _mi_segment_page_free(
    page: ptr[mi_page_t], force: bool, tld: ptr[mi_segments_tld_t]
) {
    segment = _mi_page_segment(page);

    mi_segment_page_clear(page, tld);
    if segment.view(1)[0].used == u64(0) {
        mi_segment_free(segment, force, tld);
    } elif segment.view(1)[0].used == segment.view(1)[0].abandoned {
        mi_segment_abandon(segment, tld);
    }
}

impl mi_tagged_segment_ptr(ts: u64) -> ptr[mi_segment_t] {
    return ptr[mi_segment_t](i64.wrap(ts & ~MI_TAGGED_MASK));
}

impl mi_tagged_segment(segment: ptr[mi_segment_t], ts: u64) -> u64 {
    tag = wrapping_add(ts & MI_TAGGED_MASK, u64(1)) & MI_TAGGED_MASK;
    return u64.wrap(int(segment)) | tag;
}

impl mi_abandoned_visited_push(
    pool: ptr[mi_abandoned_pool_t], segment: ptr[mi_segment_t]
) {
    visited = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_VISITED);
    anext = mi_atomic_load_relaxed(visited);
    while True {
        mi_atomic_store_release(mi_segment_abandoned_next_addr(segment), anext);
        (ok, seen) = mi_atomic_cas_weak_release(visited, anext, u64.wrap(int(segment)));
        if ok {
            break;
        }
        anext = seen;
    }
    mi_atomic_increment_relaxed(
        mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_VISITED_COUNT)
    );
}

impl mi_abandoned_visited_revisit(pool: ptr[mi_abandoned_pool_t]) -> bool {
    visited = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_VISITED);
    abandoned = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED);
    abandoned_count = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_COUNT);
    visited_count = mi_word_addr(
        ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_VISITED_COUNT
    );

    if mi_atomic_load_relaxed(visited) == u64(0) {
        return False;
    }

    first_word = mi_atomic_exchange_acq_rel(visited, u64(0));
    if first_word == u64(0) {
        return False;
    }
    first = ptr[mi_segment_t](i64.wrap(first_word));

    ts = mi_atomic_load_relaxed(abandoned);
    if not mi_tagged_segment_ptr(ts) {
        count = mi_atomic_load_relaxed(visited_count);
        afirst = mi_tagged_segment(first, ts);
        (swapped, found) = mi_atomic_cas_strong_acq_rel(abandoned, ts, afirst);
        if swapped {
            mi_atomic_add_relaxed(abandoned_count, count);
            mi_atomic_sub_relaxed(visited_count, count);
            return True;
        }
    }

    last = first;
    nxt = ptr[mi_segment_t](
        i64.wrap(mi_atomic_load_relaxed(mi_segment_abandoned_next_addr(last)))
    );
    while nxt {
        last = nxt;
        nxt = ptr[mi_segment_t](
            i64.wrap(mi_atomic_load_relaxed(mi_segment_abandoned_next_addr(last)))
        );
    }

    anext = mi_atomic_load_relaxed(abandoned);
    moved: u64 = 0;
    while True {
        moved = mi_atomic_load_relaxed(visited_count);
        mi_atomic_store_release(
            mi_segment_abandoned_next_addr(last),
            u64.wrap(int(mi_tagged_segment_ptr(anext)))
        );
        anew = mi_tagged_segment(first, anext);
        (ok, seen) = mi_atomic_cas_weak_release(abandoned, anext, anew);
        if ok {
            break;
        }
        anext = seen;
    }
    mi_atomic_add_relaxed(abandoned_count, moved);
    mi_atomic_sub_relaxed(visited_count, moved);
    return True;
}

impl mi_abandoned_push(pool: ptr[mi_abandoned_pool_t], segment: ptr[mi_segment_t]) {
    abandoned = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED);
    ts = mi_atomic_load_relaxed(abandoned);
    while True {
        mi_atomic_store_release(
            mi_segment_abandoned_next_addr(segment),
            u64.wrap(int(mi_tagged_segment_ptr(ts)))
        );
        nxt = mi_tagged_segment(segment, ts);
        (ok, seen) = mi_atomic_cas_weak_release(abandoned, ts, nxt);
        if ok {
            break;
        }
        ts = seen;
    }
    mi_atomic_increment_relaxed(
        mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_COUNT)
    );
}

impl _mi_abandoned_await_readers(pool: ptr[mi_abandoned_pool_t]) {
    readers = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_READERS);
    while True {
        n = mi_atomic_load_acquire(readers);
        if n != u64(0) {
            mi_atomic_yield();
        }
        if n == u64(0) {
            break;
        }
    }
}

impl mi_abandoned_pop(pool: ptr[mi_abandoned_pool_t]) -> ptr[mi_segment_t] {
    abandoned = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED);
    readers = mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_READERS);

    ts = mi_atomic_load_relaxed(abandoned);
    segment = mi_tagged_segment_ptr(ts);
    if not segment {
        if not mi_abandoned_visited_revisit(pool) {
            return ptr[mi_segment_t]();
        }
    }

    mi_atomic_increment_relaxed(readers);
    nxt: u64 = 0;
    ts = mi_atomic_load_acquire(abandoned);
    while True {
        segment = mi_tagged_segment_ptr(ts);
        if not segment {
            break;
        }
        anext = ptr[mi_segment_t](
            i64.wrap(mi_atomic_load_relaxed(mi_segment_abandoned_next_addr(segment)))
        );

        nxt = mi_tagged_segment(anext, ts);
        (ok, seen) = mi_atomic_cas_weak_acq_rel(abandoned, ts, nxt);
        if ok {
            break;
        }
        ts = seen;
    }

    mi_atomic_decrement_relaxed(readers);
    if segment {
        mi_atomic_store_release(mi_segment_abandoned_next_addr(segment), u64(0));
        mi_atomic_decrement_relaxed(
            mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_COUNT)
        );
    }
    return segment;
}

impl mi_segment_abandon(segment: ptr[mi_segment_t], tld: ptr[mi_segments_tld_t]) {
    slice = mi_segment_slices(segment);
    end = mi_segment_slices_end(segment);
    while int(slice) < int(end) {
        if slice.view(1)[0].xblock_size == u32(0) {
            mi_segment_span_remove_from_queue(slice, tld);

            slice.view(1)[0].xblock_size = u32(0);
        }
        slice = slice + i64(slice.view(1)[0].slice_count);
    }

    mi_segment_try_purge(
        segment,
        mi_option_is_enabled(mi_option_abandoned_page_purge),
        tld.view(1)[0].stats
    );

    _mi_stat_increase(
        mi_stat_count_at(tld.view(1)[0].stats, mi_stats_t_SEGMENTS_ABANDONED), u64(1)
    );
    mi_segments_track_size(-i64.wrap(mi_segment_size(segment)), tld);
    mi_atomic_store_seq_cst(mi_segment_thread_id_addr(segment), u64(0));
    mi_atomic_store_release(mi_segment_abandoned_next_addr(segment), u64(0));

    segment.view(1)[0].abandoned_visits = u64(1);
    mi_abandoned_push(tld.view(1)[0].abandoned, segment);
}

impl _mi_segment_page_abandon(page: ptr[mi_page_t], tld: ptr[mi_segments_tld_t]) {
    segment = _mi_page_segment(page);
    segment.view(1)[0].abandoned = segment.view(1)[0].abandoned + u64(1);
    _mi_stat_increase(
        mi_stat_count_at(tld.view(1)[0].stats, mi_stats_t_PAGES_ABANDONED), u64(1)
    );
    if segment.view(1)[0].used == segment.view(1)[0].abandoned {
        mi_segment_abandon(segment, tld);
    }
}

impl mi_slices_start_iterate(
    segment: ptr[mi_segment_t]
) -> tuple[ptr[mi_page_t], ptr[mi_page_t]] {
    slice = mi_segment_slices(segment);
    end = mi_segment_slices_end(segment);

    return (slice + i64(slice.view(1)[0].slice_count), end);
}

impl mi_segment_check_free(
    segment: ptr[mi_segment_t],
    slices_needed: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t]
) -> bool {
    has_page = False;

    (first, end) = mi_slices_start_iterate(segment);
    slice = first;
    while int(slice) < int(end) {
        if mi_slice_is_used(slice) {
            page = slice;
            _mi_page_free_collect(page, False);
            if mi_page_all_free(page) and _PyMem_mi_page_is_safe_to_free(ptr(page)) {
                _mi_stat_decrease(
                    mi_stat_count_at(tld.view(1)[0].stats, mi_stats_t_PAGES_ABANDONED),
                    u64(1)
                );
                segment.view(1)[0].abandoned = wrapping_sub(
                    segment.view(1)[0].abandoned, u64(1)
                );

                slice = mi_segment_page_clear(page, tld);
                if u64(slice.view(1)[0].slice_count) >= slices_needed {
                    has_page = True;
                }
            } elif u64(page.view(1)[0].xblock_size) == block_size
                and mi_page_has_any_available(page) {
                has_page = True;
            }
        } elif u64(slice.view(1)[0].slice_count) >= slices_needed {
            has_page = True;
        }
        slice = slice + i64(slice.view(1)[0].slice_count);
    }
    return has_page;
}

impl mi_heap_by_tag(heap: ptr[mi_heap_t], tag: u8) -> ptr[mi_heap_t] {
    if heap.view(1)[0].tag == tag {
        return heap;
    }
    curr = heap.view(1)[0].tld.view(1)[0].heaps;
    while curr {
        if curr.view(1)[0].tag == tag {
            return curr;
        }
        curr = curr.view(1)[0].next;
    }
    return ptr[mi_heap_t]();
}

impl mi_segment_reclaim(
    segment: ptr[mi_segment_t],
    heap: ptr[mi_heap_t],
    requested_block_size: u64,
    tld: ptr[mi_segments_tld_t]
) -> tuple[ptr[mi_segment_t], bool] {
    right_page_reclaimed = False;
    stats = tld.view(1)[0].stats;
    mi_atomic_store_seq_cst(mi_segment_thread_id_addr(segment), _mi_thread_id());
    segment.view(1)[0].abandoned_visits = u64(0);
    mi_segments_track_size(i64.wrap(mi_segment_size(segment)), tld);
    _mi_stat_decrease(mi_stat_count_at(stats, mi_stats_t_SEGMENTS_ABANDONED), u64(1));

    (first, end) = mi_slices_start_iterate(segment);
    slice = first;
    while int(slice) < int(end) {
        if mi_slice_is_used(slice) {
            page = slice;
            target_heap = mi_heap_by_tag(heap, page.view(1)[0].tag);

            _mi_stat_decrease(
                mi_stat_count_at(stats, mi_stats_t_PAGES_ABANDONED), u64(1)
            );
            segment.view(1)[0].abandoned = wrapping_sub(
                segment.view(1)[0].abandoned, u64(1)
            );

            mi_page_set_heap(page, target_heap);

            _mi_page_use_delayed_free(page, MI_USE_DELAYED_FREE, True);

            _mi_page_free_collect(page, False);
            if mi_page_all_free(page) and _PyMem_mi_page_is_safe_to_free(ptr(page)) {
                slice = mi_segment_page_clear(page, tld);
            } else {
                _mi_page_reclaim(target_heap, page);
                if requested_block_size == u64(page.view(1)[0].xblock_size)
                    and mi_page_has_any_available(page)
                    and requested_block_size <= MI_MEDIUM_OBJ_SIZE_MAX
                    and heap == target_heap {
                    right_page_reclaimed = True;
                }
            }
        } else {
            slice = mi_segment_span_free_coalesce(slice, tld);
        }
        slice = slice + i64(slice.view(1)[0].slice_count);
    }

    if segment.view(1)[0].used == u64(0) {
        mi_segment_free(segment, False, tld);
        return (ptr[mi_segment_t](), right_page_reclaimed);
    }
    return (segment, right_page_reclaimed);
}

impl _mi_abandoned_reclaim_all(heap: ptr[mi_heap_t], tld: ptr[mi_segments_tld_t]) {
    while True {
        segment = mi_abandoned_pop(tld.view(1)[0].abandoned);
        if not segment {
            break;
        }
        (reclaimed_segment, right_page) = mi_segment_reclaim(
            segment, heap, u64(0), tld
        );
    }
}

impl mi_segment_try_reclaim(
    heap: ptr[mi_heap_t],
    needed_slices: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t]
) -> tuple[ptr[mi_segment_t], bool] {
    max_tries = mi_option_get_clamp(mi_option_max_segment_reclaim, 8, 1024);
    while max_tries > 0 {
        max_tries = max_tries - 1;
        segment = mi_abandoned_pop(tld.view(1)[0].abandoned);
        if not segment {
            break;
        }
        segment.view(1)[0].abandoned_visits = segment.view(1)[0].abandoned_visits
            + u64(1);

        is_suitable = _mi_heap_memid_is_suitable(heap, mi_segment_memid(segment));

        has_page = mi_segment_check_free(segment, needed_slices, block_size, tld);
        if segment.view(1)[0].used == u64(0) {
            (freed_segment, freed_right) = mi_segment_reclaim(
                segment, heap, u64(0), tld
            );
        } elif has_page and is_suitable {
            (result, reclaimed) = mi_segment_reclaim(segment, heap, block_size, tld);
            return (result, reclaimed);
        } elif segment.view(1)[0].abandoned_visits > u64(3) and is_suitable {
            (visit_segment, visit_right) = mi_segment_reclaim(
                segment, heap, u64(0), tld
            );
        } else {
            mi_segment_try_purge(segment, True, tld.view(1)[0].stats);
            mi_abandoned_visited_push(tld.view(1)[0].abandoned, segment);
        }
    }
    return (ptr[mi_segment_t](), False);
}

impl _mi_abandoned_collect(
    heap: ptr[mi_heap_t], force: bool, tld: ptr[mi_segments_tld_t]
) {
    pool = tld.view(1)[0].abandoned;

    max_tries: i32 = 1024;
    if force {
        max_tries = i32(16 * 1024);
        mi_abandoned_visited_revisit(pool);
    }
    while max_tries > 0 {
        max_tries = max_tries - 1;
        segment = mi_abandoned_pop(pool);
        if not segment {
            break;
        }

        mi_segment_check_free(segment, u64(0), u64(0), tld);
        if segment.view(1)[0].used == u64(0) {
            (freed_segment, freed_right) = mi_segment_reclaim(
                segment, heap, u64(0), tld
            );
        } else {
            mi_segment_try_purge(segment, force, tld.view(1)[0].stats);
            mi_abandoned_visited_push(pool, segment);
        }
    }
}

impl mi_segment_reclaim_or_alloc(
    heap: ptr[mi_heap_t],
    needed_slices: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_segment_t] {
    (segment, reclaimed) = mi_segment_try_reclaim(heap, needed_slices, block_size, tld);
    if reclaimed {
        return ptr[mi_segment_t]();
    } elif segment {
        return segment;
    }

    (fresh, huge_page) = mi_segment_alloc(
        u64(0), u64(0), heap.view(1)[0].arena_id, tld, os_tld
    );
    return fresh;
}

impl mi_segments_page_alloc(
    heap: ptr[mi_heap_t],
    page_kind: i32,
    required: u64,
    block_size: u64,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_page_t] {
    page_align = MI_SEGMENT_SLICE_SIZE;
    if required > MI_MEDIUM_PAGE_SIZE {
        page_align = MI_MEDIUM_PAGE_SIZE;
    }
    page_size = _mi_align_up(required, page_align);
    slices_needed = page_size // MI_SEGMENT_SLICE_SIZE;
    page = mi_segments_page_find_and_allocate(
        slices_needed, heap.view(1)[0].arena_id, tld
    );
    if not page {
        if not mi_segment_reclaim_or_alloc(
            heap, slices_needed, block_size, tld, os_tld
        ) {
            return ptr[mi_page_t]();
        }

        return mi_segments_page_alloc(
            heap, page_kind, required, block_size, tld, os_tld
        );
    }
    mi_segment_try_purge(_mi_ptr_segment(ptr[u8](page)), False, tld.view(1)[0].stats);
    return page;
}

impl mi_segment_huge_page_alloc(
    size: u64,
    page_alignment: u64,
    req_arena_id: i32,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_page_t] {
    (segment, page) = mi_segment_alloc(size, page_alignment, req_arena_id, tld, os_tld);
    if not segment or not page {
        return ptr[mi_page_t]();
    }

    (start, psize) = _mi_segment_page_start(segment, page);
    if psize > u64(MI_HUGE_BLOCK_SIZE) {
        page.view(1)[0].xblock_size = MI_HUGE_BLOCK_SIZE;
    } else {
        page.view(1)[0].xblock_size = u32.wrap(psize);
    }

    if page_alignment > u64(0) and segment.view(1)[0].allow_decommit {
        aligned_p = ptr[u8](
            i64.wrap(_mi_align_up(u64.wrap(int(start)), page_alignment))
        );

        decommit_start = start + i64.wrap(mi_block_t_SIZE);
        decommit_size = int(aligned_p) - int(decommit_start);

        _mi_os_reset(
            decommit_start, u64.wrap(decommit_size), addressof(_mi_stats_main)
        );
    }
    return page;
}

impl _mi_segment_huge_page_reset(
    segment: ptr[mi_segment_t], page: ptr[mi_page_t], block: ptr[mi_block_t]
) {
    if segment.view(1)[0].allow_decommit {
        csize = mi_usable_size(ptr(block));
        if csize > mi_block_t_SIZE {
            rsize = csize - mi_block_t_SIZE;
            p = ptr[u8](block) + i64.wrap(mi_block_t_SIZE);

            _mi_os_reset(p, rsize, addressof(_mi_stats_main));
        }
    }
}

impl _mi_segment_page_alloc(
    heap: ptr[mi_heap_t],
    block_size: u64,
    page_alignment: u64,
    tld: ptr[mi_segments_tld_t],
    os_tld: ptr[mi_os_tld_t]
) -> ptr[mi_page_t] {
    page = ptr[mi_page_t]();
    if page_alignment > MI_ALIGNMENT_MAX {
        alignment = page_alignment;
        if alignment < MI_SEGMENT_SIZE {
            alignment = MI_SEGMENT_SIZE;
        }
        page = mi_segment_huge_page_alloc(
            block_size, alignment, heap.view(1)[0].arena_id, tld, os_tld
        );
    } elif block_size <= MI_SMALL_OBJ_SIZE_MAX {
        page = mi_segments_page_alloc(
            heap, MI_PAGE_SMALL, block_size, block_size, tld, os_tld
        );
    } elif block_size <= MI_MEDIUM_OBJ_SIZE_MAX {
        page = mi_segments_page_alloc(
            heap, MI_PAGE_MEDIUM, MI_MEDIUM_PAGE_SIZE, block_size, tld, os_tld
        );
    } elif block_size <= MI_LARGE_OBJ_SIZE_MAX {
        page = mi_segments_page_alloc(
            heap, MI_PAGE_LARGE, block_size, block_size, tld, os_tld
        );
    } else {
        page = mi_segment_huge_page_alloc(
            block_size, page_alignment, heap.view(1)[0].arena_id, tld, os_tld
        );
    }
    return page;
}

impl mi_segment_visit_page(
    segment: ptr[mi_segment_t],
    page: ptr[mi_page_t],
    visit_blocks: bool,
    visit_fn: ptr,
    arg: ptr
) -> bool {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    area = ptr[mi_heap_area_t](base);
    _mi_heap_area_init(area, page);
    if not mi_call_block_visit(
        visit_fn, ptr(), ptr(area), ptr(), area.view(1)[0].block_size, arg
    ) {
        return False;
    }
    if visit_blocks {
        return _mi_heap_area_visit_blocks(area, page, visit_fn, arg);
    }
    return True;
}

impl mi_segment_visit_pages(
    segment: ptr[mi_segment_t],
    page_tag: u8,
    visit_blocks: bool,
    visit_fn: ptr,
    arg: ptr
) -> bool {
    (first, end) = mi_slices_start_iterate(segment);
    slice = first;
    while int(slice) < int(end) {
        if mi_slice_is_used(slice) {
            page = slice;
            if page.view(1)[0].tag == page_tag {
                if not mi_segment_visit_page(
                    segment, page, visit_blocks, visit_fn, arg
                ) {
                    return False;
                }
            }
        }
        slice = slice + i64(slice.view(1)[0].slice_count);
    }
    return True;
}

impl _mi_abandoned_pool_visit_blocks(
    pool: ptr[mi_abandoned_pool_t],
    page_tag: u8,
    visit_blocks: bool,
    visit_fn: ptr,
    arg: ptr
) -> bool {
    segment = mi_tagged_segment_ptr(
        mi_atomic_load_seq_cst(
            mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED)
        )
    );
    while segment {
        if not mi_segment_visit_pages(segment, page_tag, visit_blocks, visit_fn, arg) {
            return False;
        }
        segment = ptr[mi_segment_t](
            i64.wrap(mi_atomic_load_seq_cst(mi_segment_abandoned_next_addr(segment)))
        );
    }
    segment = ptr[mi_segment_t](
        i64.wrap(
            mi_atomic_load_seq_cst(
                mi_word_addr(ptr[u8](pool), mi_abandoned_pool_t_ABANDONED_VISITED)
            )
        )
    );
    while segment {
        if not mi_segment_visit_pages(segment, page_tag, visit_blocks, visit_fn, arg) {
            return False;
        }
        segment = ptr[mi_segment_t](
            i64.wrap(mi_atomic_load_seq_cst(mi_segment_abandoned_next_addr(segment)))
        );
    }
    return True;
}


impl mi_segment_map_word(index: u64) -> ptr[u64] {
    return ptr[u64](addressof(mi_segment_map)) + i64.wrap(index);
}

impl mi_segment_map_index_of(segment: ptr[mi_segment_t]) -> tuple[u64, u64] {
    addr = u64.wrap(int(segment));
    if addr >= MI_MAX_ADDRESS {
        return (MI_SEGMENT_MAP_WSIZE, u64(0));
    }
    segindex = addr // MI_SEGMENT_SIZE;

    return (segindex // MI_INTPTR_BITS, segindex % MI_INTPTR_BITS);
}

impl _mi_segment_map_allocated_at(segment: ptr[mi_segment_t]) {
    (index, bitidx) = mi_segment_map_index_of(segment);
    if index == MI_SEGMENT_MAP_WSIZE {
        return;
    }
    word = mi_segment_map_word(index);
    mask = mi_atomic_load_relaxed(word);
    while True {
        newmask = mask | wrapping_shl(u64(1), bitidx);
        (ok, seen) = mi_atomic_cas_weak_release(word, mask, newmask);
        if ok {
            break;
        }
        mask = seen;
    }
}

impl _mi_segment_map_freed_at(segment: ptr[mi_segment_t]) {
    (index, bitidx) = mi_segment_map_index_of(segment);
    if index == MI_SEGMENT_MAP_WSIZE {
        return;
    }
    word = mi_segment_map_word(index);
    mask = mi_atomic_load_relaxed(word);
    while True {
        newmask = mask & ~wrapping_shl(u64(1), bitidx);
        (ok, seen) = mi_atomic_cas_weak_release(word, mask, newmask);
        if ok {
            break;
        }
        mask = seen;
    }
}

impl _mi_segment_of(p: ptr[u8]) -> ptr[mi_segment_t] {
    if not p {
        return ptr[mi_segment_t]();
    }
    segment = _mi_ptr_segment(p);
    (index, bitidx) = mi_segment_map_index_of(segment);

    mask = mi_atomic_load_relaxed(mi_segment_map_word(index));
    if (mask & wrapping_shl(u64(1), bitidx)) != u64(0) {
        return segment;
    }
    if index == MI_SEGMENT_MAP_WSIZE {
        return ptr[mi_segment_t]();
    }

    lobitidx: u64 = 0;
    loindex: u64 = 0;
    lobits = mask & (wrapping_shl(u64(1), bitidx) - u64(1));
    if lobits != u64(0) {
        loindex = index;

        lobitidx = mi_bsr(lobits);
    } elif index == u64(0) {
        return ptr[mi_segment_t]();
    } else {
        lomask = mask;
        loindex = index;
        while True {
            loindex = loindex - u64(1);
            lomask = mi_atomic_load_relaxed(mi_segment_map_word(loindex));
            if not (lomask != u64(0) and loindex > u64(0)) {
                break;
            }
        }
        if lomask == u64(0) {
            return ptr[mi_segment_t]();
        }
        lobitidx = mi_bsr(lomask);
    }

    diff = wrapping_mul(
        wrapping_sub(
            wrapping_add(
                wrapping_mul(index - loindex, u64(8) * MI_INTPTR_SIZE), bitidx
            ),
            lobitidx
        ),
        MI_SEGMENT_SIZE
    );
    segment = ptr[mi_segment_t](i64.wrap(wrapping_sub(u64.wrap(int(segment)), diff)));
    if not segment {
        return ptr[mi_segment_t]();
    }

    cookie_ok = _mi_ptr_cookie(ptr[u8](segment)) == segment.view(1)[0].cookie;
    if not cookie_ok {
        return ptr[mi_segment_t]();
    }

    if wrapping_add(u64.wrap(int(segment)), mi_segment_size(segment))
        <= u64.wrap(int(p)) {
        return ptr[mi_segment_t]();
    }

    return segment;
}

impl mi_is_valid_pointer(p: ptr[u8]) -> bool {
    if _mi_segment_of(p) {
        return True;
    }
    return _mi_arena_contains(p);
}


impl mi_stats_div_trunc(a: i64, b: i64) -> i64 {
    q = a // b;
    if a % b != i64(0) and (a < i64(0)) != (b < i64(0)) {
        q = q + i64(1);
    }
    return q;
}

impl mi_stats_rem_trunc(a: i64, b: i64) -> i64 {
    return a - mi_stats_div_trunc(a, b) * b;
}

impl mi_is_in_main(stat: ptr[u8]) -> bool {
    main_ = int(addressof(_mi_stats_main));
    return int(stat) >= main_ and int(stat) < main_ + i64.wrap(mi_stats_t_SIZE);
}

impl mi_stat_update(stat: ptr[mi_stat_count_t], amount: i64) {
    if amount == i64(0) {
        return;
    }
    if mi_is_in_main(ptr[u8](stat)) {
        words = ptr[i64](stat);
        current = mi_atomic_addi64_relaxed(words + 3, amount);
        mi_atomic_maxi64_relaxed(words + 2, current + amount);
        if amount > i64(0) {
            mi_atomic_addi64_relaxed(words, amount);
        } else {
            mi_atomic_addi64_relaxed(words + 1, -amount);
        }
    } else {
        stat.view(1)[0].current = stat.view(1)[0].current + amount;
        if stat.view(1)[0].current > stat.view(1)[0].peak {
            stat.view(1)[0].peak = stat.view(1)[0].current;
        }
        if amount > i64(0) {
            stat.view(1)[0].allocated = stat.view(1)[0].allocated + amount;
        } else {
            stat.view(1)[0].freed = stat.view(1)[0].freed + -amount;
        }
    }
}

impl _mi_stat_counter_increase(stat: ptr[mi_stat_counter_t], amount: u64) {
    if mi_is_in_main(ptr[u8](stat)) {
        words = ptr[i64](stat);
        mi_atomic_addi64_relaxed(words + 1, i64(1));
        mi_atomic_addi64_relaxed(words, i64.wrap(amount));
    } else {
        stat.view(1)[0].count = stat.view(1)[0].count + i64(1);
        stat.view(1)[0].total = stat.view(1)[0].total + i64.wrap(amount);
    }
}

impl _mi_stat_increase(stat: ptr[mi_stat_count_t], amount: u64) {
    mi_stat_update(stat, i64.wrap(amount));
}

impl _mi_stat_decrease(stat: ptr[mi_stat_count_t], amount: u64) {
    mi_stat_update(stat, -i64.wrap(amount));
}

impl mi_stat_add(stat: ptr[mi_stat_count_t], src: ptr[mi_stat_count_t], unit: i64) {
    if stat == src {
        return;
    }
    if src.view(1)[0].allocated == i64(0) and src.view(1)[0].freed == i64(0) {
        return;
    }
    words = ptr[i64](stat);
    mi_atomic_addi64_relaxed(words, src.view(1)[0].allocated * unit);
    mi_atomic_addi64_relaxed(words + 3, src.view(1)[0].current * unit);
    mi_atomic_addi64_relaxed(words + 1, src.view(1)[0].freed * unit);

    mi_atomic_addi64_relaxed(words + 2, src.view(1)[0].peak * unit);
}

impl mi_stat_counter_add(
    stat: ptr[mi_stat_counter_t], src: ptr[mi_stat_counter_t], unit: i64
) {
    if stat == src {
        return;
    }
    words = ptr[i64](stat);
    mi_atomic_addi64_relaxed(words, src.view(1)[0].total * unit);
    mi_atomic_addi64_relaxed(words + 1, src.view(1)[0].count * unit);
}

impl mi_stats_add(stats: ptr[mi_stats_t], src: ptr[mi_stats_t]) {
    if stats == src {
        return;
    }
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_SEGMENTS),
        mi_stat_count_at(src, mi_stats_t_SEGMENTS),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_PAGES),
        mi_stat_count_at(src, mi_stats_t_PAGES),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_RESERVED),
        mi_stat_count_at(src, mi_stats_t_RESERVED),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_COMMITTED),
        mi_stat_count_at(src, mi_stats_t_COMMITTED),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_RESET),
        mi_stat_count_at(src, mi_stats_t_RESET),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_PURGED),
        mi_stat_count_at(src, mi_stats_t_PURGED),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_PAGE_COMMITTED),
        mi_stat_count_at(src, mi_stats_t_PAGE_COMMITTED),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_PAGES_ABANDONED),
        mi_stat_count_at(src, mi_stats_t_PAGES_ABANDONED),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_SEGMENTS_ABANDONED),
        mi_stat_count_at(src, mi_stats_t_SEGMENTS_ABANDONED),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_THREADS),
        mi_stat_count_at(src, mi_stats_t_THREADS),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_MALLOC),
        mi_stat_count_at(src, mi_stats_t_MALLOC),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_SEGMENTS_CACHE),
        mi_stat_count_at(src, mi_stats_t_SEGMENTS_CACHE),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_NORMAL),
        mi_stat_count_at(src, mi_stats_t_NORMAL),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_HUGE),
        mi_stat_count_at(src, mi_stats_t_HUGE),
        i64(1)
    );
    mi_stat_add(
        mi_stat_count_at(stats, mi_stats_t_LARGE),
        mi_stat_count_at(src, mi_stats_t_LARGE),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_PAGES_EXTENDED),
        mi_stat_counter_at(src, mi_stats_t_PAGES_EXTENDED),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_MMAP_CALLS),
        mi_stat_counter_at(src, mi_stats_t_MMAP_CALLS),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_COMMIT_CALLS),
        mi_stat_counter_at(src, mi_stats_t_COMMIT_CALLS),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_RESET_CALLS),
        mi_stat_counter_at(src, mi_stats_t_RESET_CALLS),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_PURGE_CALLS),
        mi_stat_counter_at(src, mi_stats_t_PURGE_CALLS),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_PAGE_NO_RETIRE),
        mi_stat_counter_at(src, mi_stats_t_PAGE_NO_RETIRE),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_SEARCHES),
        mi_stat_counter_at(src, mi_stats_t_SEARCHES),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_NORMAL_COUNT),
        mi_stat_counter_at(src, mi_stats_t_NORMAL_COUNT),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_HUGE_COUNT),
        mi_stat_counter_at(src, mi_stats_t_HUGE_COUNT),
        i64(1)
    );
    mi_stat_counter_add(
        mi_stat_counter_at(stats, mi_stats_t_LARGE_COUNT),
        mi_stat_counter_at(src, mi_stats_t_LARGE_COUNT),
        i64(1)
    );
}

impl mi_printf_amount(n: i64, unit: i64, out: ptr, arg: ptr, fmt: ptr[u8]) {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    buf = base;
    unitdesc = base + 32;
    buf.view(1)[0] = u8(0);
    buf_len = u64(32);
    suffix = ptr[u8]("B");
    if unit <= i64(0) {
        suffix = ptr[u8](" ");
    }
    base_n: i64 = 1024;
    if unit == i64(0) {
        base_n = i64(1000);
    }
    v = n;
    if unit > i64(0) {
        v = v * unit;
    }
    pos = v;
    if v < i64(0) {
        pos = -v;
    }
    if pos < base_n {
        if v != i64(1) or suffix.view(1)[0] != u8(66) {
            if v == i64(0) {
                snprintf(buf, buf_len, ptr[u8]("%d   %-3s"), i32.wrap(v), ptr[u8](""));
            } else {
                snprintf(buf, buf_len, ptr[u8]("%d   %-3s"), i32.wrap(v), suffix);
            }
        }
    } else {
        divider = base_n;
        magnitude = ptr[u8]("K");
        if pos >= divider * base_n {
            divider = divider * base_n;
            magnitude = ptr[u8]("M");
        }
        if pos >= divider * base_n {
            divider = divider * base_n;
            magnitude = ptr[u8]("G");
        }
        tens = mi_stats_div_trunc(v, divider // i64(10));
        whole = mi_stats_div_trunc(tens, i64(10));
        frac1 = mi_stats_rem_trunc(tens, i64(10));
        if base_n == i64(1024) {
            snprintf(
                unitdesc, u64(8), ptr[u8]("%s%s%s"), magnitude, ptr[u8]("i"), suffix
            );
        } else {
            snprintf(
                unitdesc, u64(8), ptr[u8]("%s%s%s"), magnitude, ptr[u8](""), suffix
            );
        }
        frac_abs = frac1;
        if frac1 < i64(0) {
            frac_abs = -frac1;
        }
        snprintf(buf, buf_len, ptr[u8]("%ld.%ld %-3s"), whole, frac_abs, unitdesc);
    }
    if not fmt {
        _mi_fprintf(
            out,
            arg,
            ptr[u8]("%12s"),
            u64.wrap(int(buf)),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
    } else {
        _mi_fprintf(
            out,
            arg,
            fmt,
            u64.wrap(int(buf)),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
    }
}

impl mi_print_amount(n: i64, unit: i64, out: ptr, arg: ptr) {
    mi_printf_amount(n, unit, out, arg, ptr[u8]());
}

impl mi_print_count(n: i64, unit: i64, out: ptr, arg: ptr) {
    if unit == i64(1) {
        _mi_fprintf(
            out,
            arg,
            ptr[u8]("%12s"),
            u64.wrap(int(ptr[u8](" "))),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
    } else {
        mi_print_amount(n, i64(0), out, arg);
    }
}

impl mi_stat_print_ex(
    stat: ptr[mi_stat_count_t],
    msg: ptr[u8],
    unit: i64,
    out: ptr,
    arg: ptr,
    notok: ptr[u8]
) {
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s:"),
        u64.wrap(int(msg)),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );
    if unit > i64(0) {
        mi_print_amount(stat.view(1)[0].peak, unit, out, arg);
        mi_print_amount(stat.view(1)[0].allocated, unit, out, arg);
        mi_print_amount(stat.view(1)[0].freed, unit, out, arg);
        mi_print_amount(stat.view(1)[0].current, unit, out, arg);
        mi_print_amount(unit, i64(1), out, arg);
        mi_print_count(stat.view(1)[0].allocated, unit, out, arg);
        if stat.view(1)[0].allocated > stat.view(1)[0].freed {
            _mi_fprintf(
                out,
                arg,
                ptr[u8]("  "),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
            if not notok {
                _mi_fprintf(
                    out,
                    arg,
                    ptr[u8]("not all freed"),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0)
                );
            } else {
                _mi_fprintf(
                    out,
                    arg,
                    notok,
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0),
                    u64(0)
                );
            }
            _mi_fprintf(
                out,
                arg,
                ptr[u8]("\n"),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        } else {
            _mi_fprintf(
                out,
                arg,
                ptr[u8]("  ok\n"),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        }
    } elif unit < i64(0) {
        mi_print_amount(stat.view(1)[0].peak, i64(-1), out, arg);
        mi_print_amount(stat.view(1)[0].allocated, i64(-1), out, arg);
        mi_print_amount(stat.view(1)[0].freed, i64(-1), out, arg);
        mi_print_amount(stat.view(1)[0].current, i64(-1), out, arg);
        if unit == i64(-1) {
            _mi_fprintf(
                out,
                arg,
                ptr[u8]("%24s"),
                u64.wrap(int(ptr[u8](""))),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        } else {
            mi_print_amount(-unit, i64(1), out, arg);
            mi_print_count(
                mi_stats_div_trunc(stat.view(1)[0].allocated, -unit), i64(0), out, arg
            );
        }
        if stat.view(1)[0].allocated > stat.view(1)[0].freed {
            _mi_fprintf(
                out,
                arg,
                ptr[u8]("  not all freed!\n"),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        } else {
            _mi_fprintf(
                out,
                arg,
                ptr[u8]("  ok\n"),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        }
    } else {
        mi_print_amount(stat.view(1)[0].peak, i64(1), out, arg);
        mi_print_amount(stat.view(1)[0].allocated, i64(1), out, arg);
        _mi_fprintf(
            out,
            arg,
            ptr[u8]("%11s"),
            u64.wrap(int(ptr[u8](" "))),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        mi_print_amount(stat.view(1)[0].current, i64(1), out, arg);
        _mi_fprintf(
            out,
            arg,
            ptr[u8]("\n"),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
    }
}

impl mi_stat_print(
    stat: ptr[mi_stat_count_t], msg: ptr[u8], unit: i64, out: ptr, arg: ptr
) {
    mi_stat_print_ex(stat, msg, unit, out, arg, ptr[u8]());
}

impl mi_stat_peak_print(
    stat: ptr[mi_stat_count_t], msg: ptr[u8], unit: i64, out: ptr, arg: ptr
) {
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s:"),
        u64.wrap(int(msg)),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );
    mi_print_amount(stat.view(1)[0].peak, unit, out, arg);
    _mi_fprintf(
        out, arg, ptr[u8]("\n"), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0)
    );
}

impl mi_stat_counter_print(
    stat: ptr[mi_stat_counter_t], msg: ptr[u8], out: ptr, arg: ptr
) {
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s:"),
        u64.wrap(int(msg)),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );
    mi_print_amount(stat.view(1)[0].total, i64(-1), out, arg);
    _mi_fprintf(
        out, arg, ptr[u8]("\n"), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0)
    );
}

impl mi_stat_counter_print_avg(
    stat: ptr[mi_stat_counter_t], msg: ptr[u8], out: ptr, arg: ptr
) {
    avg_tens: i64 = 0;
    if stat.view(1)[0].count != i64(0) {
        avg_tens = mi_stats_div_trunc(
            stat.view(1)[0].total * i64(10), stat.view(1)[0].count
        );
    }
    avg_whole = mi_stats_div_trunc(avg_tens, i64(10));
    avg_frac1 = mi_stats_rem_trunc(avg_tens, i64(10));
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s: %5ld.%ld avg\n"),
        u64.wrap(int(msg)),
        u64.wrap(avg_whole),
        u64.wrap(avg_frac1),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );
}

impl mi_print_header(out: ptr, arg: ptr) {
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s: %11s %11s %11s %11s %11s %11s\n"),
        u64.wrap(int(ptr[u8]("heap stats"))),
        u64.wrap(int(ptr[u8]("peak   "))),
        u64.wrap(int(ptr[u8]("total   "))),
        u64.wrap(int(ptr[u8]("freed   "))),
        u64.wrap(int(ptr[u8]("current   "))),
        u64.wrap(int(ptr[u8]("unit   "))),
        u64.wrap(int(ptr[u8]("count   ")))
    );
}

impl mi_buffered_flush(buf: ptr[buffered_t]) {
    (buf.view(1)[0].buf + i64.wrap(buf.view(1)[0].used)).view(1)[0] = u8(0);
    _mi_fputs(
        ptr(i64.wrap(buf.view(1)[0].out)),
        ptr(i64.wrap(buf.view(1)[0].arg)),
        ptr[u8](),
        buf.view(1)[0].buf
    );
    buf.view(1)[0].used = u64(0);
}

impl mi_buffered_out(msg: ptr[u8], arg: ptr) -> None {
    buf = ptr[buffered_t](arg);
    if not msg or not buf {
        return;
    }
    src = msg;
    while src.view(1)[0] != u8(0) {
        c = src.view(1)[0];
        if buf.view(1)[0].used >= buf.view(1)[0].count {
            mi_buffered_flush(buf);
        }

        used = buf.view(1)[0].used;
        (buf.view(1)[0].buf + i64.wrap(used)).view(1)[0] = c;
        buf.view(1)[0].used = used + u64(1);
        if c == u8(10) {
            mi_buffered_flush(buf);
        }
        src = src + 1;
    }
}

impl _mi_stats_print(stats: ptr[mi_stats_t], out0: ptr, arg0: ptr) {
    slots: own MiStack = MiStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));

    buffer = ptr[buffered_t](base + 256);
    buffer.view(1)[0].out = u64.wrap(int(out0));
    buffer.view(1)[0].arg = u64.wrap(int(arg0));
    buffer.view(1)[0].buf = base;
    buffer.view(1)[0].used = u64(0);
    buffer.view(1)[0].count = u64(255);
    out = ptr(mi_buffered_out);
    arg = ptr(buffer);

    mi_print_header(out, arg);
    mi_stat_print_ex(
        mi_stat_count_at(stats, mi_stats_t_RESERVED),
        ptr[u8]("reserved"),
        i64(1),
        out,
        arg,
        ptr[u8]("")
    );
    mi_stat_print_ex(
        mi_stat_count_at(stats, mi_stats_t_COMMITTED),
        ptr[u8]("committed"),
        i64(1),
        out,
        arg,
        ptr[u8]("")
    );
    mi_stat_peak_print(
        mi_stat_count_at(stats, mi_stats_t_RESET), ptr[u8]("reset"), i64(1), out, arg
    );
    mi_stat_peak_print(
        mi_stat_count_at(stats, mi_stats_t_PURGED), ptr[u8]("purged"), i64(1), out, arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_PAGE_COMMITTED),
        ptr[u8]("touched"),
        i64(1),
        out,
        arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_SEGMENTS),
        ptr[u8]("segments"),
        i64(-1),
        out,
        arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_SEGMENTS_ABANDONED),
        ptr[u8]("-abandoned"),
        i64(-1),
        out,
        arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_SEGMENTS_CACHE),
        ptr[u8]("-cached"),
        i64(-1),
        out,
        arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_PAGES), ptr[u8]("pages"), i64(-1), out, arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_PAGES_ABANDONED),
        ptr[u8]("-abandoned"),
        i64(-1),
        out,
        arg
    );
    mi_stat_counter_print(
        mi_stat_counter_at(stats, mi_stats_t_PAGES_EXTENDED),
        ptr[u8]("-extended"),
        out,
        arg
    );
    mi_stat_counter_print(
        mi_stat_counter_at(stats, mi_stats_t_PAGE_NO_RETIRE),
        ptr[u8]("-noretire"),
        out,
        arg
    );
    mi_stat_counter_print(
        mi_stat_counter_at(stats, mi_stats_t_MMAP_CALLS), ptr[u8]("mmaps"), out, arg
    );
    mi_stat_counter_print(
        mi_stat_counter_at(stats, mi_stats_t_COMMIT_CALLS), ptr[u8]("commits"), out, arg
    );
    mi_stat_counter_print(
        mi_stat_counter_at(stats, mi_stats_t_RESET_CALLS), ptr[u8]("resets"), out, arg
    );
    mi_stat_counter_print(
        mi_stat_counter_at(stats, mi_stats_t_PURGE_CALLS), ptr[u8]("purges"), out, arg
    );
    mi_stat_print(
        mi_stat_count_at(stats, mi_stats_t_THREADS),
        ptr[u8]("threads"),
        i64(-1),
        out,
        arg
    );
    mi_stat_counter_print_avg(
        mi_stat_counter_at(stats, mi_stats_t_SEARCHES), ptr[u8]("searches"), out, arg
    );
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s: %5zu\n"),
        u64.wrap(int(ptr[u8]("numa nodes"))),
        _mi_os_numa_node_count(),
        u64(0),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );

    words = ptr[u64](base + 296);
    mi_process_info(
        words,
        words + 1,
        words + 2,
        words + 3,
        words + 4,
        words + 5,
        words + 6,
        words + 7
    );
    elapsed = words.view(8)[0];
    user_time = words.view(8)[1];
    sys_time = words.view(8)[2];
    peak_rss = words.view(8)[4];
    peak_commit = words.view(8)[6];
    page_faults = words.view(8)[7];
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s: %5ld.%03ld s\n"),
        u64.wrap(int(ptr[u8]("elapsed"))),
        elapsed // u64(1000),
        elapsed % u64(1000),
        u64(0),
        u64(0),
        u64(0),
        u64(0)
    );
    _mi_fprintf(
        out,
        arg,
        ptr[u8]("%10s: user: %ld.%03ld s, system: %ld.%03ld s, faults: %lu, rss: "),
        u64.wrap(int(ptr[u8]("process"))),
        user_time // u64(1000),
        user_time % u64(1000),
        sys_time // u64(1000),
        sys_time % u64(1000),
        page_faults,
        u64(0)
    );
    mi_printf_amount(i64.wrap(peak_rss), i64(1), out, arg, ptr[u8]("%s"));
    if peak_commit > u64(0) {
        _mi_fprintf(
            out,
            arg,
            ptr[u8](", commit: "),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0),
            u64(0)
        );
        mi_printf_amount(i64.wrap(peak_commit), i64(1), out, arg, ptr[u8]("%s"));
    }
    _mi_fprintf(
        out, arg, ptr[u8]("\n"), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0)
    );
}

impl mi_stats_get_default -> ptr[mi_stats_t] {
    heap = ptr[mi_heap_t](mi_heap_get_default());
    return mi_tld_stats(heap.view(1)[0].tld);
}

impl mi_stats_merge_from(stats: ptr[mi_stats_t]) {
    if stats != addressof(_mi_stats_main) {
        mi_stats_add(addressof(_mi_stats_main), stats);
        memset(ptr(stats), 0, mi_stats_t_SIZE);
    }
}

impl _mi_stats_done(stats: ptr[mi_stats_t]) {
    mi_stats_merge_from(stats);
}

impl _mi_clock_now -> i64 {
    return _mi_prim_clock_now();
}

impl _mi_clock_start -> i64 {
    st = addressof(mi_stats_statics);
    if st.view(1)[0].mi_clock_diff == i64(0) {
        t0 = _mi_clock_now();
        st.view(1)[0].mi_clock_diff = _mi_clock_now() - t0;
    }
    return _mi_clock_now();
}

impl _mi_clock_end(start: i64) -> i64 {
    end_ = _mi_clock_now();
    return end_ - start - addressof(mi_stats_statics).view(1)[0].mi_clock_diff;
}

impl mi_stats_msecs_clamp(t: i64) -> u64 {
    if t < i64(0) {
        return u64(0);
    }
    if t < i64(9223372036854775807) {
        return u64(t);
    }
    return u64(9223372036854775807);
}


impl mi_prim_state_word(ofs: i64) -> ptr[u64] {
    return mi_word_addr(ptr[u8](addressof(mi_prim_state)), ofs);
}

impl mi_prim_open(fpath: ptr[u8], open_flags: i32) -> i32 {
    return open(fpath, open_flags);
}

impl mi_prim_read(fd: i32, buf: ptr[u8], bufsize: u64) -> i64 {
    return read(fd, ptr(buf), bufsize);
}

impl mi_prim_close(fd: i32) -> i32 {
    return close(fd);
}

impl mi_prim_access(fpath: ptr[u8], mode: i32) -> i32 {
    return access(fpath, mode);
}

impl unix_detect_overcommit -> bool {
    os_overcommit: bool = True;
    if MI_PLATFORM_LINUX != 0 {
        fd = mi_prim_open(ptr[u8]("/proc/sys/vm/overcommit_memory"), O_RDONLY);
        if fd >= 0 {
            slots: own MiStack = MiStack();
            buf = ptr[u8](jacpy_stack_address(&mut slots));
            nread = mi_prim_read(fd, buf, u64(32));
            mi_prim_close(fd);

            if nread >= 1 {
                c = buf.view(1)[0];

                os_overcommit = c == u8(48) or c == u8(49);
            }
        }
    }

    return os_overcommit;
}

impl _mi_prim_mem_init(config: ptr[mi_os_mem_config_t]) {
    psize = sysconf(_SC_PAGESIZE);
    if psize > 0 {
        config.view(1)[0].page_size = u64.wrap(psize);
        config.view(1)[0].alloc_granularity = u64.wrap(psize);
    }

    config.view(1)[0].large_page_size = u64(2) * MI_MiB;
    config.view(1)[0].has_overcommit = unix_detect_overcommit();

    config.view(1)[0].must_free_whole = False;

    config.view(1)[0].has_virtual_reserve = True;
}

impl _mi_prim_free(addr: ptr[u8], size: u64) -> i32 {
    if munmap(ptr(addr), size) == -1 {
        return i32.wrap(jacpy_errno());
    }
    return i32(0);
}

impl unix_madvise(addr: ptr[u8], size: u64, advice: i32) -> i32 {
    return madvise(ptr(addr), size, advice);
}

impl unix_mmap_prim(
    addr: ptr[u8],
    size: u64,
    try_alignment: u64,
    protect_flags: i32,
    flags: i32,
    fd: i32
) -> ptr[u8] {
    p: ptr[u8] = ptr[u8]();

    if not addr {
        hint = _mi_os_get_aligned_hint(try_alignment, size);
        if hint {
            p = ptr[u8](mmap(ptr(hint), size, protect_flags, flags, fd, i64(0)));
            if int(p) == -1 or not _mi_is_aligned(p, try_alignment) {
                err = i32.wrap(jacpy_errno());
                _mi_verbose_message(
                    ptr[u8](
                        "unable to directly request hinted aligned OS memory (error: %d (0x%x), size: 0x%zx bytes, alignment: 0x%zx, hint address: %p)\n"
                    ),
                    u64.wrap(i64(err)),
                    u64.wrap(i64(err)),
                    size,
                    try_alignment,
                    u64.wrap(int(hint)),
                    u64(0),
                    u64(0)
                );
            }
            if int(p) != -1 {
                return p;
            }
        }
    }

    p = ptr[u8](mmap(ptr(addr), size, protect_flags, flags, fd, i64(0)));
    if int(p) != -1 {
        return p;
    }

    return ptr[u8]();
}

impl unix_mmap_fd -> i32 {
    if MI_PLATFORM_LINUX == 0 {
        os_tag = i32.wrap(mi_option_get(mi_option_os_tag));
        if os_tag < 100 or os_tag > 255 {
            os_tag = i32(100);
        }

        return i32.wrap(u64.wrap(i64(os_tag)) << u64(24));
    }
    return i32(-1);
}

impl unix_mmap(
    addr: ptr[u8],
    size: u64,
    try_alignment: u64,
    protect_flags: i32,
    large_only: bool,
    allow_large: bool,
    is_large_in: bool
) -> tuple[ptr[u8], bool] {
    is_large: bool = is_large_in;
    p: ptr[u8] = ptr[u8]();
    fd = unix_mmap_fd();
    flags: i32 = MAP_PRIVATE | MAP_ANONYMOUS;
    if _mi_os_has_overcommit() {
        flags = flags | MAP_NORESERVE;
    }

    if (large_only or _mi_os_use_large_page(size, try_alignment)) and allow_large {
        try_ok_addr = mi_prim_state_word(MiPrimState_LARGE_PAGE_TRY_OK);
        try_ok = mi_atomic_load_acquire(try_ok_addr);
        if not large_only and try_ok > u64(0) {
            (swapped, seen) = mi_atomic_cas_strong_acq_rel(
                try_ok_addr, try_ok, try_ok - u64(1)
            );
        } else {
            lflags: i32 = flags & ~MAP_NORESERVE;
            lfd: i32 = fd;
            lflags = lflags | MAP_HUGETLB;
            state = addressof(mi_prim_state);
            if (size % MI_GiB) == u64(0) and state.view(1)[0].huge_pages_available {
                lflags = lflags | MAP_HUGE_1GB;
            } else {
                lflags = lflags | MAP_HUGE_2MB;
            }
            lfd = lfd | VM_FLAGS_SUPERPAGE_SIZE_2MB;
            if large_only or lflags != flags {
                is_large = True;
                p = unix_mmap_prim(
                    addr, size, try_alignment, protect_flags, lflags, lfd
                );
                if not p and (lflags & MAP_HUGE_1GB) != 0 {
                    state.view(1)[0].huge_pages_available = False;
                    _mi_warning_message(
                        ptr[u8](
                            "unable to allocate huge (1GiB) page, trying large (2MiB) pages instead (errno: %i)\n"
                        ),
                        u64.wrap(jacpy_errno()),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0),
                        u64(0)
                    );
                    lflags = (lflags & ~MAP_HUGE_1GB) | MAP_HUGE_2MB;
                    p = unix_mmap_prim(
                        addr, size, try_alignment, protect_flags, lflags, lfd
                    );
                }
                if large_only {
                    return (p, is_large);
                }
                if not p {
                    mi_atomic_store_release(try_ok_addr, u64(8));
                }
            }
        }
    }

    if not p {
        is_large = False;
        p = unix_mmap_prim(addr, size, try_alignment, protect_flags, flags, fd);
        if p and MI_PLATFORM_LINUX != 0 {
            if allow_large and _mi_os_use_large_page(size, try_alignment) {
                if unix_madvise(p, size, MADV_HUGEPAGE) == 0 {
                    is_large = True;
                }
            }
        }
    }
    return (p, is_large);
}

impl _mi_prim_alloc(
    size: u64, try_alignment: u64, commit: bool, allow_large: bool
) -> tuple[i32, bool, bool, ptr[u8]] {
    is_zero: bool = True;
    protect_flags: i32 = PROT_NONE;
    if commit {
        protect_flags = PROT_WRITE | PROT_READ;
    }
    (addr, is_large) = unix_mmap(
        ptr[u8](), size, try_alignment, protect_flags, False, allow_large, False
    );
    if addr {
        return (i32(0), is_large, is_zero, addr);
    }
    return (i32.wrap(jacpy_errno()), is_large, is_zero, addr);
}

impl unix_mprotect_hint(err: i32) {
    return;
}

impl _mi_prim_commit(start: ptr[u8], size: u64) -> tuple[i32, bool] {
    is_zero: bool = False;
    err = mprotect(ptr(start), size, PROT_READ | PROT_WRITE);
    if err != 0 {
        err = i32.wrap(jacpy_errno());
        unix_mprotect_hint(err);
    }
    return (err, is_zero);
}

impl _mi_prim_decommit(start: ptr[u8], size: u64) -> tuple[i32, bool] {
    err = unix_madvise(start, size, MADV_DONTNEED);

    needs_recommit: bool = False;
    return (err, needs_recommit);
}

impl _mi_prim_reset(start: ptr[u8], size: u64) -> i32 {
    advice_addr = mi_prim_state_word(MiPrimState_RESET_ADVICE);
    oadvice = i32.wrap(mi_atomic_load_relaxed(advice_addr));
    if oadvice == 0 {
        oadvice = MADV_FREE;
    }
    err = unix_madvise(start, size, oadvice);
    while err != 0 and i32.wrap(jacpy_errno()) == EAGAIN {
        jacpy_set_errno(0);
        err = unix_madvise(start, size, oadvice);
    }
    if err != 0 and i32.wrap(jacpy_errno()) == EINVAL and oadvice == MADV_FREE {
        mi_atomic_store_release(advice_addr, u64.wrap(i64(MADV_DONTNEED)));
        err = unix_madvise(start, size, MADV_DONTNEED);
    }
    return err;
}

impl _mi_prim_protect(start: ptr[u8], size: u64, protect_: bool) -> i32 {
    prot: i32 = PROT_READ | PROT_WRITE;
    if protect_ {
        prot = PROT_NONE;
    }
    err = mprotect(ptr(start), size, prot);
    if err != 0 {
        err = i32.wrap(jacpy_errno());
    }
    unix_mprotect_hint(err);
    return err;
}

impl mi_prim_mbind(
    start: ptr[u8], length: u64, mode: u64, nmask: ptr[u64], maxnode: u64, flags: u32
) -> i64 {
    return i64(0);
}

impl _mi_prim_alloc_huge_os_pages(
    hint_addr: ptr[u8], size: u64, numa_node: i32
) -> tuple[i32, bool, ptr[u8]] {
    is_zero: bool = True;
    (addr, is_large) = unix_mmap(
        hint_addr, size, MI_SEGMENT_SIZE, PROT_READ | PROT_WRITE, True, True, True
    );
    if addr and numa_node >= 0 and i64(numa_node) < i64(8 * MI_INTPTR_SIZE) {
        slots: own MiStack = MiStack();
        numa_mask = ptr[u64](jacpy_stack_address(&mut slots));
        numa_mask.view(1)[0] = wrapping_shl(u64(1), u64.wrap(i64(numa_node)));

        err = mi_prim_mbind(
            addr, size, MPOL_PREFERRED, numa_mask, u64(8) * MI_INTPTR_SIZE, u32(0)
        );
        if err != 0 {
            err = jacpy_errno();
            _mi_warning_message(
                ptr[u8](
                    "failed to bind huge (1GiB) pages to numa node %d (error: %d (0x%x))\n"
                ),
                u64.wrap(i64(numa_node)),
                u64.wrap(err),
                u64.wrap(err),
                u64(0),
                u64(0),
                u64(0),
                u64(0)
            );
        }
    }
    if addr {
        return (i32(0), is_zero, addr);
    }
    return (i32.wrap(jacpy_errno()), is_zero, addr);
}

impl _mi_prim_numa_node -> u64 {
    return u64(0);
}

impl _mi_prim_numa_node_count -> u64 {
    if MI_PLATFORM_LINUX == 0 {
        return u64(1);
    }

    slots: own MiStack = MiStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    node_: u32 = 0;
    while node_ < u32(256) {
        snprintf(
            buf, u64(127), ptr[u8]("/sys/devices/system/node/node%u"), node_ + u32(1)
        );
        if mi_prim_access(buf, R_OK) != 0 {
            break;
        }
        node_ = node_ + u32(1);
    }
    return u64(node_ + u32(1));
}

impl _mi_prim_clock_now -> i64 {
    slots: own MiStack = MiStack();
    t = ptr[u8](jacpy_stack_address(&mut slots));
    clock_gettime(CLOCK_MONOTONIC, ptr(t));
    tv_sec = ptr[i64](t).view(1)[0];
    tv_nsec = ptr[i64](t + TIMESPEC_TV_NSEC).view(1)[0];
    return (tv_sec * 1000) + (tv_nsec // 1000000);
}

impl timeval_secs(tv: ptr[u8]) -> i64 {
    tv_sec = ptr[i64](tv).view(1)[0];
    tv_usec = i64(ptr[i32](tv + TIMEVAL_TV_USEC).view(1)[0]);
    return (tv_sec * 1000) + (tv_usec // 1000);
}

impl _mi_prim_process_info(pinfo: ptr[mi_process_info_t]) {
    slots: own MiStack = MiStack();
    ru = ptr[u8](jacpy_stack_address(&mut slots));
    getrusage(RUSAGE_SELF, ptr(ru));
    pinfo.view(1)[0].utime = timeval_secs(ru + RUSAGE_RU_UTIME);
    pinfo.view(1)[0].stime = timeval_secs(ru + RUSAGE_RU_STIME);
    pinfo.view(1)[0].page_faults = u64.wrap(ptr[i64](ru + RUSAGE_RU_MAJFLT).view(1)[0]);

    maxrss = u64.wrap(ptr[i64](ru + RUSAGE_RU_MAXRSS).view(1)[0]);
    pinfo.view(1)[0].peak_rss = wrapping_mul(maxrss, RU_MAXRSS_UNIT);
}

impl _mi_prim_out_stderr(msg: ptr[u8]) {
    n = strlen(msg);
    done: u64 = 0;
    while done < n {
        ret = write(MI_PRIM_STDERR_FD, ptr(msg + i64.wrap(done)), n - done);
        if ret <= 0 {
            if ret < 0 and i32.wrap(jacpy_errno()) == EINTR {
                continue;
            }
            break;
        }
        done = done + u64.wrap(ret);
    }
}

impl _mi_prim_getenv(name: ptr[u8], result: ptr[u8], result_size: u64) -> bool {
    if _mi_preloading() {
        return False;
    }

    slots: own MiStack = MiStack();
    s = getenv(name);
    if not s {
        buf = ptr[u8](jacpy_stack_address(&mut slots));
        name_len = _mi_strnlen(name, u64(64));
        i: u64 = 0;
        while i < name_len {
            (buf + i64.wrap(i)).view(1)[0] = _mi_toupper(
                (name + i64.wrap(i)).view(1)[0]
            );
            i = i + u64(1);
        }
        (buf + i64.wrap(name_len)).view(1)[0] = u8(0);
        s = getenv(buf);
    }
    if not s or _mi_strnlen(s, result_size) >= result_size {
        return False;
    }
    _mi_strlcpy(result, s, result_size);
    return True;
}

impl mi_prim_getentropy(buf: ptr[u8], buf_len: u64) -> i32 {
    done: u64 = 0;
    while done < buf_len {
        flags: i64 = 0;
        got = syscall(SYS_GETRANDOM, ptr(buf + i64.wrap(done)), buf_len - done, flags);
        if got < 0 {
            return i32(-1);
        }
        done = done + u64(got);
    }
    return i32(0);
}

impl _mi_prim_random_buf(buf: ptr[u8], buf_len: u64) -> bool {
    no_getrandom = mi_prim_state_word(MiPrimState_NO_GETRANDOM);
    if MI_PLATFORM_LINUX != 0 and mi_atomic_load_acquire(no_getrandom) == u64(0) {
        if mi_prim_getentropy(buf, buf_len) == 0 {
            return True;
        }
        if i32.wrap(jacpy_errno()) != ENOSYS {
            return False;
        }

        mi_atomic_store_release(no_getrandom, u64(1));
    }
    flags: i32 = O_RDONLY | O_CLOEXEC;
    fd = mi_prim_open(ptr[u8]("/dev/urandom"), flags);
    if fd < 0 {
        return False;
    }
    count: u64 = 0;
    while count < buf_len {
        ret = mi_prim_read(fd, buf + i64.wrap(count), buf_len - count);
        if ret <= 0 {
            e = i32.wrap(jacpy_errno());
            if e != EAGAIN and e != EINTR {
                break;
            }
        } else {
            count = count + u64.wrap(ret);
        }
    }
    mi_prim_close(fd);
    return count == buf_len;
}

impl mi_pthread_done(value: ptr) {
    if int(value) != 0 {
        _mi_thread_done(ptr[mi_heap_t](value));
    }
}

impl _mi_prim_thread_init_auto_done {
    state = addressof(mi_prim_state);
    key_addr = mi_prim_state_word(MiPrimState_HEAP_DEFAULT_KEY);
    if pthread_key_create(key_addr, ptr(mi_pthread_done)) == 0 {
        state.view(1)[0].heap_default_key_created = True;
    }
}

impl _mi_prim_thread_done_auto_done {
    return;
}

impl _mi_prim_thread_associate_default_heap(heap: ptr[mi_heap_t]) {
    state = addressof(mi_prim_state);

    if state.view(1)[0].heap_default_key_created {
        pthread_setspecific(state.view(1)[0].heap_default_key, ptr(heap));
    }
}
