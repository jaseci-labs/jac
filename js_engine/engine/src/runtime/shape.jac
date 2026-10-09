"""
runtime/shape.na.jac — Shapes (hidden classes) for ordinary-object property
storage. B1 of JSEngineProduction.md; full plan: docs/shapes_impl_plan.md.

A Shape describes an own-property *layout*: which keys an object has, their
attributes, and which slot of the object's flat `slots: list[JSValue]` each
value occupies. Objects with the same insertion history share one shape, so
per-object property storage collapses to `shape_id + slots`.

Shapes form a tree rooted at the empty shape (id 0): each shape adds exactly
one key to its parent. Adding a property = following (or creating) a
transition edge; the edge cache makes repeat transitions O(1), which is what
makes the constructor pattern (`this.x = …; this.y = …` for thousands of
instances) allocate no per-property metadata after the first instance.

The table is struct-of-arrays: shape `sid` is row `sid` of the `_SH_*` int
lists (no per-shape object, so no refcount traffic on a lookup), and every
transition edge lives in the one `_SH_EDGES` dict.

Lookup and enumeration share one index per linear chain ("descriptor
sharing", as V8's DescriptorArray): a chain index maps key_id →
slot_idx*16+attrs for a whole root→tip chain, and every shape on that chain
uses it — a key belongs to shape `sid` iff its slot_idx < slot_count(sid),
since slots only grow along a chain. A new child joins its parent's chain
index when the parent is that index's tip; a sibling branch builds its own on
first use. Growing one object to k keys is therefore O(k) metadata. (Each
shape used to own a flattened index of its whole chain, which is O(k²): a
vite build of a large site held ~9 GB of those dicts.) Chains of at most
_SHAPE_WALK_MAX keys are looked up by walking the parent rows instead.

Invariants a future engineer must not break:
  - A shape row is IMMUTABLE after creation, except `_SH_GRP` (its chain
    index id, set once from -1). Chain indexes only ever grow at their tip.
  - `parent_id < id` for every non-root shape (children are appended after
    their parent), so parent walks strictly decrease and cannot cycle.
  - A key appears AT MOST ONCE on any root→leaf chain. Attribute changes and
    deletes never edit a chain in place — the owning object leaves shape
    mode (or, later, forks a sibling chain) instead.
  - The table is engine-global and realm-free: shapes hold interned key ids
    and ints only — no JSValues, no realm references — so sharing across
    ShadowRealm realms is safe. Under the worker-threads isolate plan this
    glob becomes thread-local like all other engine globals.
  - Shapes are never freed. Transition trees are tiny relative to the
    objects that share them; leak-tolerance is the standard trade here.

Packed encodings (attrs occupy one nibble):
  - transition edge key:  sid * 2^36 + key_id * 16 + attrs
  - chain index value:    slot_idx * 16 + attrs
"""

# Attribute bits. Low three intentionally equal PROP_WRITABLE / PROP_ENUMERABLE
# / PROP_CONFIGURABLE in jsobj_type.na.jac (do not renumber independently).
glob:pub SHAPE_ATTR_WRITABLE: int = 1,
     SHAPE_ATTR_ENUMERABLE: int = 2,
     SHAPE_ATTR_CONFIGURABLE: int = 4,
     SHAPE_ATTR_ACCESSOR: int = 8,
     SHAPE_ATTR_MASK: int = 15;


# Shape rows. Accessor properties (Phase 4) occupy TWO consecutive slots:
# getter, setter.
glob _SH_PARENT: list[int] = [],  # parent shape id (-1 for the root)
     _SH_KEY: list[int] = [],  # interned key id this shape added (0 for root)
     _SH_ATTRS: list[int] = [],  # SHAPE_ATTR_* nibble for the key
     _SH_SLOT: list[int] = [],  # first slot the key's value occupies (-1 root)
     _SH_COUNT: list[int] = [],  # total slots an object of this shape carries
     _SH_NKEYS: list[int] = [],  # keys on the chain (root 0)
     _SH_GRP: list[int] = [],  # chain index id, -1 until first needed
     _SH_EDGES: dict[int, int] = {},  # _edge_key(sid, tk) → child shape id
     _SHAPE_GATE: int = 1;

# Chain indexes, by id: key_id → slot_idx*16+attrs, the chain's keys in
# insertion order (root→tip), and the tip shape (the only one that may extend
# it in place).
glob _GRP_INDEX: list[dict[int, int]] = [],
     _GRP_KEYS: list[list[int]] = [],
     _GRP_TIP: list[int] = [],
     _NO_KEYS: list[int] = [];

# Chains this short are looked up by walking parent rows (no index built).
glob _SHAPE_WALK_MAX: int = 8,
     _EDGE_STRIDE: int = 68719476736;  # 2^36 > |key_id*16+attrs| for any key id

# JS_SHAPES gate (docs/shapes_impl_plan.md Phase 3): shape mode is the
# DEFAULT; JS_SHAPES=0 forces dict mode everywhere — the A/B debugging lever
# (same pattern as JSBC=0). Kept until Phase 5 has soaked.
#
# Set from init_global() (which owns getenv) rather than read here: this module
# must stay import-free. Pulling ffi.libc in transitively re-declared libc
# externs (int-typed memset) inside every runtime compile unit and collided
# with the native backend's own memset intrinsic signature in jsstring.na.jac,
# truncating its generated IR (issues/extern-decl-signature-collision-
# truncates-ir/). Objects allocated before init_global() read this default.
"""Set the shape-mode gate (called once from init_global)."""
def:pub shape_gate_set(enabled: bool) {
    _SHAPE_GATE = 1 if enabled else 0;
}

"""True unless JS_SHAPES=0 — newly allocated objects use shape mode."""
def:pub shape_gate_enabled -> bool {
    return _SHAPE_GATE == 1;
}


def _shape_append(parent: int, key: int, attrs: int, slot: int, count: int, nkeys: int) -> int {
    sid: int = len(_SH_PARENT);
    _SH_PARENT.append(parent);
    _SH_KEY.append(key);
    _SH_ATTRS.append(attrs);
    _SH_SLOT.append(slot);
    _SH_COUNT.append(count);
    _SH_NKEYS.append(nkeys);
    _SH_GRP.append(-1);
    return sid;
}


"""Return the empty root shape's id (0), creating the table lazily."""
def:pub shape_root -> int {
    if len(_SH_PARENT) == 0 {
        _shape_append(-1, 0, 0, -1, 0, 0);
    }
    return 0;
}


def _shape_valid(sid: int) -> bool {
    return sid >= 0 and sid < len(_SH_PARENT);
}


# Transition cache: (shape, key*16+attrs) → child id, direct-mapped, in front
# of the edge dict. Edges are never removed or changed (the tree only grows),
# so an entry never goes stale. Every property add on a shape-mode object
# goes through here.
glob _STC_MASK: int = 8191,
     _STC_SID: list[int] = [],
     _STC_TK: list[int] = [],
     _STC_CHILD: list[int] = [];

"""
Transition from `sid` by adding `key` with attribute nibble `attrs`.
Returns the child shape id — cached, so repeat transitions are one dict probe.
The caller guarantees `key` is not already present on the chain (a re-add with
different attrs is an attribute CHANGE and must not come through here).
"""
def:pub shape_transition_add(sid: int, key: int, attrs: int) -> int {
    stc_tk: int = key * 16 + (attrs & SHAPE_ATTR_MASK);
    stc_h: int = ((sid * 40503) ^ stc_tk) & _STC_MASK;
    if len(_STC_SID) > 0 and _STC_SID[stc_h] == sid and _STC_TK[stc_h] == stc_tk {
        return _STC_CHILD[stc_h];
    }
    stc_c: int = _shape_transition_add_uncached(sid, key, attrs);
    if stc_c >= 0 {
        if len(_STC_SID) == 0 {
            stc_i: int = 0;
            while stc_i <= _STC_MASK {
                _STC_SID.append(-2);
                _STC_TK.append(0);
                _STC_CHILD.append(-1);
                stc_i = stc_i + 1;
            }
        }
        _STC_SID[stc_h] = sid;
        _STC_TK[stc_h] = stc_tk;
        _STC_CHILD[stc_h] = stc_c;
    }
    return stc_c;
}

def _shape_transition_add_uncached(sid: int, key: int, attrs: int) -> int {
    shape_root();
    if not _shape_valid(sid) {
        return -1;
    }
    a: int = attrs & SHAPE_ATTR_MASK;
    ek: int = sid * _EDGE_STRIDE + key * 16 + a;
    known: int = _SH_EDGES.get(ek, -1);
    if known >= 0 {
        return known;
    }
    span: int = 1;
    if (a & SHAPE_ATTR_ACCESSOR) != 0 {
        span = 2;
    }
    pslots: int = _SH_COUNT[sid];
    child_id: int = _shape_append(sid, key, a, pslots, pslots + span, _SH_NKEYS[sid] + 1);
    _SH_EDGES[ek] = child_id;
    # Descriptor sharing: the first child of a chain index's tip extends that
    # index in place; any later sibling builds its own on first use.
    g: int = _SH_GRP[sid];
    if g >= 0 and _GRP_TIP[g] == sid {
        gidx: dict[int, int] = _GRP_INDEX[g];
        gidx[key] = pslots * 16 + a;
        gkeys: list[int] = _GRP_KEYS[g];
        gkeys.append(key);
        _GRP_TIP[g] = child_id;
        _SH_GRP[child_id] = g;
    }
    return child_id;
}


"""Chain index id for `sid`, building one for its chain on first use. Every
ancestor without an index shares it (each is a prefix of the same chain)."""
def _shape_group(sid: int) -> int {
    g: int = _SH_GRP[sid];
    if g >= 0 {
        return g;
    }
    idx: dict[int, int] = {};
    rev: list[int] = [];
    cur: int = sid;
    while cur > 0 {
        idx[_SH_KEY[cur]] = _SH_SLOT[cur] * 16 + _SH_ATTRS[cur];
        rev.append(_SH_KEY[cur]);
        cur = _SH_PARENT[cur];
    }
    keys: list[int] = [];
    ri: int = len(rev) - 1;
    while ri >= 0 {
        keys.append(rev[ri]);
        ri = ri - 1;
    }
    g = len(_GRP_TIP);
    _GRP_INDEX.append(idx);
    _GRP_KEYS.append(keys);
    _GRP_TIP.append(sid);
    cur = sid;
    while cur > 0 and _SH_GRP[cur] < 0 {
        _SH_GRP[cur] = g;
        cur = _SH_PARENT[cur];
    }
    return g;
}


# Lookup cache: (shape id, key) → packed result in three flat lists,
# direct-mapped. Shapes are immutable and never freed (header invariants), so
# an entry — an absent key included — never goes stale; a collision just
# overwrites. A hit is a few scalar loads instead of a dict probe:
# shape_lookup ran ~470M times (~9.7% of the instructions) in a jac_client
# build.
glob _SLC_MASK: int = 16383,
     _SLC_SID: list[int] = [],
     _SLC_KEY: list[int] = [],
     _SLC_VAL: list[int] = [];

def _slc_init {
    sci: int = 0;
    while sci <= _SLC_MASK {
        _SLC_SID.append(-2);
        _SLC_KEY.append(0);
        _SLC_VAL.append(-1);
        sci = sci + 1;
    }
}

"""
Look up `key` on shape `sid`.
Returns packed `slot_idx * 16 + attrs`, or -1 if the shape has no such key.
"""
def:pub shape_lookup(sid: int, key: int) -> int {
    if len(_SLC_SID) == 0 {
        _slc_init();
    }
    slc_h: int = ((sid * 40503) ^ key) & _SLC_MASK;
    if _SLC_SID[slc_h] == sid and _SLC_KEY[slc_h] == key {
        return _SLC_VAL[slc_h];
    }
    slc_r: int = _shape_lookup_uncached(sid, key);
    _SLC_SID[slc_h] = sid;
    _SLC_KEY[slc_h] = key;
    _SLC_VAL[slc_h] = slc_r;
    return slc_r;
}

def _shape_lookup_uncached(sid: int, key: int) -> int {
    if not _shape_valid(sid) {
        return -1;
    }
    if _SH_NKEYS[sid] <= _SHAPE_WALK_MAX {
        cur: int = sid;
        while cur > 0 {
            if _SH_KEY[cur] == key {
                return _SH_SLOT[cur] * 16 + _SH_ATTRS[cur];
            }
            cur = _SH_PARENT[cur];
        }
        return -1;
    }
    # One probe; packed values are slot*16+attrs >= 0, so -1 means absent. A
    # hit past this shape's slots belongs to a descendant on the shared chain.
    gidx: dict[int, int] = _GRP_INDEX[_shape_group(sid)];
    packed: int = gidx.get(key, -1);
    if packed >= 0 and packed // 16 < _SH_COUNT[sid] {
        return packed;
    }
    return -1;
}


"""Attribute nibble of `key` on shape `sid`, or -1 if absent."""
def:pub shape_attrs_of(sid: int, key: int) -> int {
    packed: int = shape_lookup(sid, key);
    if packed < 0 {
        return -1;
    }
    return packed & SHAPE_ATTR_MASK;
}


"""Slot index of `key` on shape `sid`, or -1 if absent."""
def:pub shape_slot_of(sid: int, key: int) -> int {
    packed: int = shape_lookup(sid, key);
    if packed < 0 {
        return -1;
    }
    return packed // 16;
}


"""Number of value slots an object with shape `sid` carries."""
def:pub shape_slot_count(sid: int) -> int {
    if not _shape_valid(sid) {
        return 0;
    }
    return _SH_COUNT[sid];
}


"""Whether shape `sid` has `key` (no packing arithmetic for callers)."""
def:pub shape_has(sid: int, key: int) -> bool {
    return shape_lookup(sid, key) >= 0;
}


"""
Key ids of shape `sid` in insertion order (root→leaf): the FIRST
shape_key_count(sid) entries of the returned list, which is its chain's shared
key list and may run on past them (descendants' keys). Callers must bound by
shape_key_count(sid) and treat the list as read-only (it IS the cache).
"""
def:pub shape_keys(sid: int) -> list[int] {
    if not _shape_valid(sid) or _SH_NKEYS[sid] == 0 {
        return _NO_KEYS;
    }
    return _GRP_KEYS[_shape_group(sid)];
}


"""Number of named own properties on shape `sid` (chain length, not slots)."""
def:pub shape_key_count(sid: int) -> int {
    if not _shape_valid(sid) {
        return 0;
    }
    return _SH_NKEYS[sid];
}


"""Parent shape id of `sid` (-1 for root). For last-key-delete reversion."""
def:pub shape_parent(sid: int) -> int {
    if not _shape_valid(sid) {
        return -1;
    }
    return _SH_PARENT[sid];
}


"""
Attribute change on an existing key WITHOUT leaving shape mode: replay the
chain root→leaf through the (cached) transition tree with `key`'s attrs
replaced. Slot layout depends only on key order and spans — the ACCESSOR bit
(span) must not change, which is guarded — so the object's slots list remains
valid for the returned shape unchanged. Returns the new shape id, `sid` when
the attrs already match, or -1 when the change cannot stay in shape mode
(absent key / kind change) and the caller must fall back to dict mode.
Repeat changes are O(1) after the first (transition-edge cache).
"""
def:pub shape_change_attrs(sid: int, key: int, new_attrs: int) -> int {
    packed: int = shape_lookup(sid, key);
    if packed < 0 {
        return -1;
    }
    old_attrs: int = packed & SHAPE_ATTR_MASK;
    na: int = new_attrs & SHAPE_ATTR_MASK;
    if old_attrs == na {
        return sid;
    }
    if (old_attrs & SHAPE_ATTR_ACCESSOR) != (na & SHAPE_ATTR_ACCESSOR) {
        return -1;
    }
    chain: list[int] = [];  # leaf→root, root (id 0) excluded
    cur_id: int = sid;
    while cur_id > 0 {
        chain.append(cur_id);
        cur_id = _SH_PARENT[cur_id];
    }
    nsid: int = 0;
    ci: int = len(chain) - 1;
    while ci >= 0 {
        cs: int = chain[ci];
        ca: int = _SH_ATTRS[cs];
        if _SH_KEY[cs] == key {
            ca = na;
        }
        nsid = shape_transition_add(nsid, _SH_KEY[cs], ca);
        if nsid < 0 {
            return -1;
        }
        ci = ci - 1;
    }
    return nsid;
}


# TEMP diagnostic (JAC_GC_TRACE=1, gc._gc_type_breakdown): shape-table memory as
# [shapes, chain indexes, Σindex entries, Σindex keys, edges, leaves >=128 slots].
def:pub shape_mem_stats -> list[int] {
    st: list[int] = [len(_SH_PARENT), len(_GRP_TIP), 0, 0, len(_SH_EDGES), 0];
    gi: int = 0;
    while gi < len(_GRP_TIP) {
        st[2] = st[2] + len(_GRP_INDEX[gi]);
        st[3] = st[3] + len(_GRP_KEYS[gi]);
        gi = gi + 1;
    }
    for lsid in shape_deepest_leaves(1000000) {
        if _SH_COUNT[lsid] >= 128 { st[5] = st[5] + 1; }
    }
    return st;
}

# TEMP diagnostic: the n leaf shapes (no outgoing edge) with the most slots.
def:pub shape_deepest_leaves(n: int) -> list[int] {
    has_child: list[int] = [];
    si: int = 0;
    while si < len(_SH_PARENT) {
        has_child.append(0);
        si = si + 1;
    }
    si = 1;
    while si < len(_SH_PARENT) {
        has_child[_SH_PARENT[si]] = 1;
        si = si + 1;
    }
    top: list[int] = [];
    si = 0;
    while si < len(_SH_PARENT) {
        if has_child[si] == 0 and _SH_COUNT[si] >= 64 {
            pos: int = len(top);
            while pos > 0 and _SH_COUNT[top[pos - 1]] < _SH_COUNT[si] { pos = pos - 1; }
            if pos < n {
                top.insert(pos, si);
                if len(top) > n { top.pop(); }
            }
        }
        si = si + 1;
    }
    return top;
}
