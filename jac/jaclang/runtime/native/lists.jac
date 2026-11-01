"""List runtime: a growable array of 8-byte slots.

A list object is 24 bytes from `__jac_rt_alloc`: len (i64 at +0), cap (i64 at
+8) and data (at +16), a malloc'd array of cap slots, or 0 while cap is 0. A
slot holds raw bits: ints and bools as i64, floats as their f64 bits, strings
and other refcounted values as a pointer. The `kind` argument (KIND_*) says how
to treat a slot; dicts and sets use the same numbers.

Storing borrows the value and retains it when its kind is refcounted;
overwriting or removing a stored value releases it. `*_get_ref` returns a
retained value, pop transfers the list's reference to the caller.

The drop installed by `__jac_rt_list_new` depends on the kind. A KIND_REF list
also has a trace function, registered once against its drop, so the cycle
collector can see its elements; its drop does not release them while the
collector is collecting. Strings are never traced, so a KIND_STR list's drop
always releases its elements."""
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
     KIND_REF: int = 4;

glob LIST_LEN: int = 0,
     LIST_CAP: int = 8,
     LIST_DATA: int = 16,
     LIST_SIZE: int = 24,
     LIST_MIN_CAP: int = 4,
     SLOT: int = 8,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

def:pub __jac_rt_elem_retain(bits: int, kind: int);

def:pub __jac_rt_elem_release(bits: int, kind: int);

def:pub __jac_rt_elem_eq(a: int, b: int, kind: int) -> bool;

def:pub __jac_rt_list_new(cap: int, kind: int) -> int;

def:pub __jac_rt_list_reserve(lst: int, n: int);

def:pub __jac_rt_list_push(lst: int, bits: int, kind: int);

def:pub __jac_rt_list_set(lst: int, i: int, bits: int, kind: int);

def:pub __jac_rt_list_get_ref(lst: int, i: int, kind: int) -> int;

def:pub __jac_rt_list_pop(lst: int, i: int) -> int;

def:pub __jac_rt_list_insert(lst: int, i: int, bits: int, kind: int);

def:pub __jac_rt_list_clear(lst: int, kind: int);

def:pub __jac_rt_list_copy(lst: int, kind: int) -> int;

def:pub __jac_rt_list_extend(dst: int, src: int, kind: int);

def:pub __jac_rt_list_reverse(lst: int);

def:pub __jac_rt_list_index(lst: int, bits: int, kind: int) -> int;

def:pub __jac_rt_list_contains(lst: int, bits: int, kind: int) -> bool;

def:pub __jac_rt_list_eq(a: int, b: int, kind: int) -> bool;

def:pub __jac_rt_list_slice(
    lst: int, start: int, stop: int, stride: int, kind: int
) -> int;

def:pub __jac_rt_list_sort(lst: int, kind: int, reverse: bool);

def _collecting -> bool;

def _elem_cmp(a: int, b: int, kind: int) -> int;

def _list_free(o: int);

def _list_drop_plain(o: int);

def _list_drop_str(o: int);

def _list_drop_ref(o: int);

def _list_trace_ref(o: int, visitor: int);

def _merge(src: int, dst: int, lo: int, mid: int, hi: int, kind: int, reverse: bool);
