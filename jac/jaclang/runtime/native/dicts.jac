"""Dict and set runtime: an insertion-ordered hash table over 8-byte slots.

Keys and values are raw 8-byte bits treated by their KIND_* number, the same
numbers lists.jac uses. A set is a dict made with val_kind -1: it has no vals
array and every value argument is ignored; popping from a set transfers the
stored key to the caller instead of a value.

A dict object is 56 bytes from `__jac_rt_alloc`, seven i64 fields:
  +0   len    the number of live entries.
  +8   cap    the entry capacity: keys, vals and order each hold cap slots. A
              power of two >= 4, or 0 for a dict that never held an entry (or
              was cleared); then keys, vals, ctrl and order are all 0.
  +16  keys   malloc'd array of cap key slots, entries in insertion order.
  +24  vals   malloc'd array of cap value slots parallel to keys; 0 for a set.
  +32  ctrl   malloc'd open-addressing index: 2 * cap i32 cells (a power of two
              >= 8, never more than half full). A cell is -1 (empty), -2 (a
              deleted entry's cell, kept so probes still pass over it) or an
              entry index into keys, vals and order.
  +40  used   entries appended so far, live or deleted; the next entry goes at
              index used. Entries [0, used) are in insertion order.
  +48  order  malloc'd array of cap i64 words, one per entry: the entry's hash
              (63 bits, never negative), or -1 once the entry is deleted.

Probing starts at hash & mask and steps i = (5 * i + 1 + (perturb & mask)) &
mask, with perturb starting at the hash and shifted right by 5 each step.
Inserting a new key when used == cap rebuilds the arrays with cap the smallest
power of two >= max(4, 2 * len), dropping deleted entries. A delete that leaves
more deleted entries than live ones compacts the same way (or just resets the
index when none are live). Deleting a key and inserting it again therefore puts
it at the end. Rebuilding renumbers entries, so an entry index is valid only
until the next insert or delete.

Hashes: a str hashes with FNV-1a 64 over its bytes, int, bool, float and ref
bits with the splitmix64 finalizer (a float's -0.0 is hashed as 0.0; a ref
hashes its address); either result is masked to 63 bits. Every int operation
here is overflow-checked, so the 64-bit products wrap by hand: FNV keeps its
state as two 32-bit halves (the prime is 2**40 + 435, so a step is a multiply by
435 plus a shift), and the splitmix multiply is done over 16-bit limbs.
Equality is by bytes for str, by float value for float (-0.0 == 0.0) and by
bits otherwise; equal bits are always equal.

Drops and traces: each key and value kind combination gets its own drop
function, chosen by `__jac_rt_dict_new`. Combinations with a KIND_REF key or
value also have a trace function, registered once, that visits those refs; the
drop skips releasing them while the collector is collecting. Strings are never
traced, so a drop always releases str keys and values."""
import from c {
    def malloc(n: int) -> int;  def free(p: int) -> None;  def memset(
        p: int, c: i32, n: int
    ) -> int;
}

glob KIND_INT: int = 0,
     KIND_FLOAT: int = 1,
     KIND_BOOL: int = 2,
     KIND_STR: int = 3,
     KIND_REF: int = 4,
     KIND_NONE: int = -1;

glob DICT_LEN: int = 0,
     DICT_CAP: int = 8,
     DICT_KEYS: int = 16,
     DICT_VALS: int = 24,
     DICT_CTRL: int = 32,
     DICT_USED: int = 40,
     DICT_ORDER: int = 48,
     DICT_SIZE: int = 56,
     DICT_MIN_CAP: int = 4,
     SLOT: int = 8,
     CELL: int = 4,
     CELL_EMPTY: int = -1,
     CELL_DELETED: int = -2,
     PERTURB_SHIFT: int = 5,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

glob HASH_MASK: int = 9223372036854775807,
     LOW32: int = 4294967295,
     LOW16: int = 65535,
     LIMB3_SCALE: int = 281474976710656,
     NEG_ZERO_BITS: int = -9223372036854775807 - 1,
     FNV_HI: int = 3421674724,
     FNV_LO: int = 2216829733,
     FNV_PRIME_LOW: int = 435,
     MIX_A: int = -4658895280553007687,
     MIX_B: int = -7723592293110705685;

def:pub __jac_rt_dict_new(key_kind: int, val_kind: int) -> int;

def:pub __jac_rt_dict_len(d: int) -> int;

def:pub __jac_rt_dict_find(d: int, key: int, key_kind: int) -> int;

def:pub __jac_rt_dict_set(d: int, key: int, val: int, key_kind: int, val_kind: int);

def:pub __jac_rt_dict_del(d: int, key: int, key_kind: int, val_kind: int) -> bool;

def:pub __jac_rt_dict_key_at(d: int, index: int) -> int;

def:pub __jac_rt_dict_val_at(d: int, index: int) -> int;

def:pub __jac_rt_dict_key_ref(d: int, index: int, key_kind: int) -> int;

def:pub __jac_rt_dict_val_ref(d: int, index: int, val_kind: int) -> int;

def:pub __jac_rt_dict_next(d: int, index: int) -> int;

def:pub __jac_rt_dict_pop(
    d: int, key: int, key_kind: int, val_kind: int, found_out: int
) -> int;

def:pub __jac_rt_dict_clear(d: int, key_kind: int, val_kind: int);

def:pub __jac_rt_dict_copy(d: int, key_kind: int, val_kind: int) -> int;

def:pub __jac_rt_dict_update(dst: int, src: int, key_kind: int, val_kind: int);

def:pub __jac_rt_dict_eq(a: int, b: int, key_kind: int, val_kind: int) -> bool;

def _collecting -> bool;

def _mul64(a: int, b: int) -> int;

def _shr(z: int, n: int) -> int;

def _mix(z: int) -> int;

def _str_hash(text: int) -> int;

def _hash(bits: int, kind: int) -> int;

def _grow_cap(n: int) -> int;

def _tables(d: int, cap: int, is_set: bool);

def _cell(d: int, i: int) -> int;

def _probe(d: int, h: int, key: int, key_kind: int) -> int;

def _empty_cell(d: int, h: int) -> int;

def _append(d: int, h: int, key: int, val: int);

def _rebuild(d: int, cap: int, is_set: bool);

def _store(d: int, h: int, key: int, val: int, key_kind: int, val_kind: int);

def _unlink(d: int, cell: int, index: int, val_kind: int);

def _drop_release(bits: int, kind: int, collecting: bool);

def _dict_drop(o: int, key_kind: int, val_kind: int);

def _dict_trace(o: int, visitor: int, key_ref: bool, val_ref: bool);

def _dict_drop_pp(o: int);

def _dict_drop_ps(o: int);

def _dict_drop_pr(o: int);

def _dict_drop_sp(o: int);

def _dict_drop_ss(o: int);

def _dict_drop_sr(o: int);

def _dict_drop_rp(o: int);

def _dict_drop_rs(o: int);

def _dict_drop_rr(o: int);

def _dict_trace_pr(o: int, visitor: int);

def _dict_trace_sr(o: int, visitor: int);

def _dict_trace_rp(o: int, visitor: int);

def _dict_trace_rs(o: int, visitor: int);

def _dict_trace_rr(o: int, visitor: int);

def _kind_class(kind: int) -> int;

def _dtor_for(key_kind: int, val_kind: int) -> int;

def _register_traces -> None;
