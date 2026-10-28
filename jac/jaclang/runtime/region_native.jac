import from c { def malloc(n: int) -> int;  }
import from c { def free(p: int) -> None;  }
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
     RGN_ALLNEXT: int = 104,
     RGN_CTRL_SIZE: int = 112,
     GBL_LOCK: int = 0,
     GBL_HEAD: int = 8,
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

def _tls_block -> int;

def _stack_push(blk: int, hdl: int);

def:pub __jac_region_current -> int;

def:pub __jac_region_depth -> int;

def:pub __jac_region_enter(hdl: int);

def:pub __jac_region_unwind(depth: int);

def:pub __jac_region_leave;

def:pub __jac_region_escape -> int;

def:pub __jac_region_restore(depth: int);

def _lock(hdl: int);

def _unlock(hdl: int);

def _glock(g: int);

def _gunlock(g: int);

def _registry_add(hdl: int);

def _registry_remove(hdl: int);

def _registry_holds(ptr: int) -> int;

def:pub __jac_region_new -> int;

def _draw_page(parent: int) -> int;

def _region_grow(hdl: int, size: int);

def _region_raw(hdl: int, size: int) -> int;

def:pub __jac_region_alloc(hdl: int, size: int) -> int;

def:pub __jac_region_log_dtor(hdl: int, o: int, fn: int);

def:pub __jac_region_of(o: int) -> int;

def:pub __jac_region_partition(parent: int) -> int;

def _region_holds(hdl: int, ptr: int) -> int;

def:pub __jac_region_owns(ptr: int) -> int;

def _list_tail(head: int, link_off: int) -> int;

def _reabsorb(child: int, parent: int);

def _teardown(hdl: int);

def:pub __jac_region_drop(hdl: int);
