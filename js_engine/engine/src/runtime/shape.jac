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

Invariants a future engineer must not break:
  - A shape is IMMUTABLE after creation except for its lazy caches
    (`transitions`, `prop_index`, `keys_cache`), which only ever grow and
    never need invalidation. Nothing may mutate parent_id/key_id/attrs/
    slot_idx/slot_count after append.
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
  - transition edge key:  key_id * 16 + attrs
  - prop_index value:     slot_idx * 16 + attrs
"""

# Attribute bits. Low three intentionally equal PROP_WRITABLE / PROP_ENUMERABLE
# / PROP_CONFIGURABLE in jsobj_type.na.jac (do not renumber independently).
glob:pub SHAPE_ATTR_WRITABLE: int = 1,
     SHAPE_ATTR_ENUMERABLE: int = 2,
     SHAPE_ATTR_CONFIGURABLE: int = 4,
     SHAPE_ATTR_ACCESSOR: int = 8,
     SHAPE_ATTR_MASK: int = 15;


# Accessor properties (Phase 4) occupy TWO consecutive slots: getter, setter.
obj:pub Shape {
    has parent_id: int = -1,
        key_id: int = 0,
        attrs: int = 0,
        slot_idx: int = -1,
        slot_count: int = 0,
        transitions: dict[int, int] = {},
        prop_index: dict[int, int] = {},
        index_built: int = 0,
        keys_cache: list[int] = [],
        keys_built: int = 0;  # -1 only for the root (empty) shape
}


# interned key id this shape added (0 for root)
# SHAPE_ATTR_* nibble for key_id
# first slot key_id's value occupies
# total slots an object of this shape carries
# key_id*16+attrs -> child shape id
# Lazy flattened lookup for the whole chain: key_id -> slot_idx*16+attrs.
# Shared by every object with this shape, so the one-time O(depth) build
# amortizes property lookup to a single dict probe.

# int flag (dict/bool codegen hazard — see docs)
# Lazy insertion-ordered key list (root→leaf) for enumeration.
glob _SHAPE_TABLE: list[Shape] = [],
     _SHAPE_GATE: int = 1;

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


"""Return the empty root shape's id (0), creating the table lazily."""
def:pub shape_root -> int {
    if len(_SHAPE_TABLE) == 0 {
        _SHAPE_TABLE.append(
            Shape(parent_id=-1, key_id=0, attrs=0, slot_idx=-1, slot_count=0)
        );
    }
    return 0;
}


def _shape_get(sid: int) -> Shape {
    return _SHAPE_TABLE[sid];
}


def _shape_valid(sid: int) -> bool {
    return sid >= 0 and sid < len(_SHAPE_TABLE);
}


# Transition cache: (shape, key*16+attrs) → child id, direct-mapped, in front
# of the parent's transitions dict (a Shape reference + dict probe). Edges are
# never removed or changed (the tree only grows), so an entry never goes
# stale. Every property add on a shape-mode object goes through here.
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
    parent: Shape = _shape_get(sid);
    tk: int = key * 16 + (attrs & SHAPE_ATTR_MASK);
    if tk in parent.transitions {
        return parent.transitions[tk];
    }
    span: int = 1;
    if (attrs & SHAPE_ATTR_ACCESSOR) != 0 {
        span = 2;
    }
    child_id: int = len(_SHAPE_TABLE);
    _SHAPE_TABLE.append(
        Shape(
            parent_id=sid,
            key_id=key,
            attrs=attrs & SHAPE_ATTR_MASK,
            slot_idx=parent.slot_count,
            slot_count=parent.slot_count + span
        )
    );
    parent.transitions[tk] = child_id;
    return child_id;
}


def _shape_build_index(s: Shape) {
    # Walk leaf→root. parent_id strictly decreases (see header invariant), so
    # this terminates without a depth guard. The chain-uniqueness invariant
    # means insertion order within the dict is irrelevant for correctness.
    cur_id: int = s.parent_id;
    if s.slot_idx >= 0 {
        s.prop_index[s.key_id] = s.slot_idx * 16 + s.attrs;
    }
    while cur_id >= 0 {
        cur: Shape = _shape_get(cur_id);
        if cur.slot_idx >= 0 {
            if cur.key_id not in s.prop_index {
                s.prop_index[cur.key_id] = cur.slot_idx * 16 + cur.attrs;
            }
        }
        cur_id = cur.parent_id;
    }
    s.index_built = 1;
}


# Lookup cache: (shape id, key) → packed result in three flat lists,
# direct-mapped. Shapes are immutable and never freed (header invariants), so
# an entry — an absent key included — never goes stale; a collision just
# overwrites. A hit is a few scalar loads instead of a Shape reference (retain
# + release) and a dict probe: shape_lookup ran ~470M times (~9.7% of the
# instructions) in a jac_client build.
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
    s: Shape = _shape_get(sid);
    if s.index_built == 0 {
        _shape_build_index(s);
    }
    # One probe (`in` + `[]` hashed the key twice; this is 6-8% of a vite
    # build). Packed values are slot*16+attrs >= 0, so -1 means absent.
    return s.prop_index.get(key, -1);
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
    return _shape_get(sid).slot_count;
}


"""Whether shape `sid` has `key` (no packing arithmetic for callers)."""
def:pub shape_has(sid: int, key: int) -> bool {
    return shape_lookup(sid, key) >= 0;
}


"""
Key ids of shape `sid` in insertion order (root→leaf). Cached on the shape.
Callers must treat the returned list as read-only (it IS the cache).
"""
def:pub shape_keys(sid: int) -> list[int] {
    if not _shape_valid(sid) {
        return [];
    }
    s: Shape = _shape_get(sid);
    if s.keys_built == 1 {
        return s.keys_cache;
    }
    rev: list[int] = [];
    cur_id: int = sid;
    while cur_id >= 0 {
        cur: Shape = _shape_get(cur_id);
        if cur.slot_idx >= 0 {
            rev.append(cur.key_id);
        }
        cur_id = cur.parent_id;
    }
    i: int = len(rev) - 1;
    while i >= 0 {
        s.keys_cache.append(rev[i]);
        i = i - 1;
    }
    s.keys_built = 1;
    return s.keys_cache;
}


"""Number of named own properties on shape `sid` (chain length, not slots)."""
def:pub shape_key_count(sid: int) -> int {
    return len(shape_keys(sid));
}


"""Parent shape id of `sid` (-1 for root). For last-key-delete reversion."""
def:pub shape_parent(sid: int) -> int {
    if not _shape_valid(sid) {
        return -1;
    }
    return _shape_get(sid).parent_id;
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
        cur_id = _shape_get(cur_id).parent_id;
    }
    nsid: int = 0;
    ci: int = len(chain) - 1;
    while ci >= 0 {
        cs: Shape = _shape_get(chain[ci]);
        ca: int = cs.attrs;
        if cs.key_id == key {
            ca = na;
        }
        nsid = shape_transition_add(nsid, cs.key_id, ca);
        if nsid < 0 {
            return -1;
        }
        ci = ci - 1;
    }
    return nsid;
}
