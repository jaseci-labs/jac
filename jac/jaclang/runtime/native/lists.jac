import from c {
    def malloc(n: int) -> int;  def realloc(p: int, n: int) -> int;  def free(
        p: int
    ) -> None;  def memmove(dst: int, src: int, n: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;
}

glob KIND_INT: int = 0,
     KIND_FLOAT: int = 1,
     KIND_BOOL: int = 2,
     KIND_STR: int = 3,
     KIND_REF: int = 4,
     KIND_TUPLE: int = 5,
     KIND_ANY: int = 6,
     KIND_UINT: int = 7,
     KIND_NULL: int = 8;

glob LIST_LEN: int = 0,
     LIST_CAP: int = 8,
     LIST_DATA: int = 16,
     LIST_KIND: int = 24,
     LIST_SIZE: int = 32,
     LIST_MIN_CAP: int = 4,
     SLOT: int = 8,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32,
     TUPLE_LEN: int = 0,
     TUPLE_KINDS: int = 8,
     BOX_TAG: int = 0,
     BOX_PAYLOAD: int = 8,
     ORDER_LT: int = 0,
     TAG_LIST: int = 3;

def:pub __jac_rt_elem_retain(bits: int, kind: int);

def:pub __jac_rt_elem_release(bits: int, kind: int);

def:pub __jac_rt_elem_eq(a: int, b: int, kind: int) -> bool;

def:pub __jac_rt_tuple_new(n: int) -> int;

def:pub __jac_rt_tuple_set(box: int, i: int, bits: int, kind: int);

def:pub __jac_rt_tuple_get_ref(box: int, i: int) -> int;

def:pub __jac_rt_tuple_eq(a: int, b: int) -> bool;

def _tuple_cmp(a: int, b: int) -> int;

def _tuple_drop(box: int);

def _tuple_trace(box: int, visit_fn: int);

def _is_ref_kind(kind: int) -> bool;

def __jac_rt_any_eq(a: int, b: int) -> bool;

def _any_cmp(a: int, b: int) -> int;

def:pub __jac_rt_list_new(cap: int, kind: int) -> int;

def:pub __jac_rt_list_rekind(lst: int, kind: int);

def:pub __jac_rt_list_reserve(lst: int, n: int);

def:pub __jac_rt_list_push(lst: int, bits: int, kind: int);

def:pub __jac_rt_list_set(lst: int, i: int, bits: int, kind: int);

def:pub __jac_rt_list_get_ref(lst: int, i: int, kind: int) -> int;

def:pub __jac_rt_list_pop(lst: int, i: int) -> int;

def:pub __jac_rt_list_insert(lst: int, i: int, bits: int, kind: int);

def:pub __jac_rt_list_clear(lst: int, kind: int);

def:pub __jac_rt_list_delete_range(lst: int, start: int, stop: int, kind: int);

def:pub __jac_rt_list_copy(lst: int, kind: int) -> int;

def:pub __jac_rt_list_box(lst: int, tag: int) -> int;

def:pub __jac_rt_list_extend(dst: int, src: int, kind: int);

def:pub __jac_rt_list_reverse(lst: int);

def:pub __jac_rt_list_index(lst: int, bits: int, kind: int) -> int;

def:pub __jac_rt_list_contains(lst: int, bits: int, kind: int) -> bool;

def:pub __jac_rt_list_eq(a: int, b: int, kind: int) -> bool;

def:pub __jac_rt_list_slice(
    lst: int, start: int, stop: int, stride: int, kind: int
) -> int;

def:pub __jac_rt_list_sort(lst: int, kind: int, reverse: bool);

def:pub __jac_rt_list_sort_keyed(lst: int, keys: int, kind: int, reverse: bool);

def _collecting -> bool;

def _elem_cmp(a: int, b: int, kind: int) -> int;

def _list_free(o: int);

def _list_drop_plain(o: int);

def _list_drop_str(o: int);

def _list_drop_ref(o: int);

def _list_trace_ref(o: int, visit_fn: int);

def _merge(src: int, dst: int, lo: int, mid: int, hi: int, kind: int, reverse: bool);

def _merge_keyed(
    src: int, dst: int, lo: int, mid: int, hi: int, keys: int, kind: int, reverse: bool
);
