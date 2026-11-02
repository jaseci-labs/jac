"""Iterator runtime: the `JacIter` object, the iterator states over lists,
dicts, sets, strings and ranges, generator frames and range values.

A JacIter is 16 bytes from `__jac_rt_alloc`: the address of its next function
at +0 and its state at +8, a refcounted object the iterator holds. A next
function takes the state and the address of an 8-byte cell and returns whether
it produced an element; it writes the element's bits into the cell (as in a
container slot), retained when its kind is refcounted, so the caller owns what
it receives.

A list, dict-key or string iterator's state is 24 bytes: the collection, the
position and the element kind. A range iterator's state and a range value are
24 bytes: start (the next value, for an iterator), stop and step.

A generator's state is its frame: `__jac_rt_gen_frame` allocates it zeroed,
with the resume point at +0 and the pending-exception header after it, and
installs the drop function the generator pass emitted for it."""
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
