glob ITER_NEXT: int = 0,
     ITER_STATE: int = 8,
     ITER_SIZE: int = 16,
     SEQ_COLL: int = 0,
     SEQ_INDEX: int = 8,
     SEQ_KIND: int = 16,
     SEQ_SIZE: int = 24,
     RANGE_START: int = 0,
     RANGE_STOP: int = 8,
     RANGE_STEP: int = 16,
     RANGE_SIZE: int = 24,
     LIST_LEN: int = 0,
     LIST_DATA: int = 16,
     SLOT: int = 8,
     KIND_STR: int = 3,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

def:pub __jac_rt_elem_share(bits: int, kind: int) -> int;

def:pub __jac_rt_iter_new(code: int, state: int) -> int;

def:pub __jac_rt_iter_list(lst: int, kind: int) -> int;

def:pub __jac_rt_iter_keys(d: int, kind: int) -> int;

def:pub __jac_rt_iter_range(start: int, stop: int, step: int) -> int;

def:pub __jac_rt_iter_str(text: ptr[u8]) -> int;

def:pub __jac_rt_gen_frame(size: int, drop: int) -> int;

def:pub __jac_rt_range_new(start: int, stop: int, step: int) -> int;

def _seq_state(coll: int, index: int, kind: int) -> int;

def _seq_drop(state: ptr[u8]);

def _iter_drop(it: ptr[u8]);

def _list_next(state: ptr[u8], out: ptr[u8]) -> bool;

def _keys_next(state: ptr[u8], out: ptr[u8]) -> bool;

def _range_next(state: ptr[u8], out: ptr[u8]) -> bool;

def _str_next(state: ptr[u8], out: ptr[u8]) -> bool;

def _utf8_width(lead: int) -> int;
