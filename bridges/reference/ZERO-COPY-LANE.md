# Zero-Copy Lane -- design memo (Arrow FFI + read-only lease views)

Status: **EVALUATED (2026-07-18). Verdict: REJECT the Arrow lane; DEFER the lease
view (spec-only, the soundness half is already shipped).** No ABI change, no code.

This memo answers a second architect's critique of the D3 copy-always lifetime rule
(`IMPLEMENTATION.md` D3: "borrowed data never crosses, returns are always COPIED").
The critique concedes copy-always is right forever for small values (regex / uuid /
semver) but argues it will bottleneck columnar/tensor workloads (polars, ndarray,
image buffers), and proposes two escape hatches:

* **(a) Arrow C Data Interface** for dataframes -- bridge a `DataFrame` as a resource
  whose export/import *is* Arrow FFI (`ArrowArray`/`ArrowSchema` + release callbacks),
  so no column is ever copied.
* **(b) Read-only lease view** for raw large buffers -- Rust returns
  `{ptr, len, keepalive_handle}`; the Jac object holds all three; the RC dtor releases
  the lease.

The critique claims both fit the existing machinery cheaply. That claim is **half
right in a load-bearing way**: the variant of each proposal that is cheap is the
variant that delivers no benefit, and the variant that delivers the benefit is not
cheap. The details below; verdict table at the end mirrors `FFI-LANES-PLAN.md`.

---

## Part I -- Does this overlap or conflict with the adopted py-interop tier?

### The motivating copy does not occur in the adopted architecture

The plan routes polars through **`jac add py:polars`** (Phase 3, landed; flagship
acceptance `jac/tests/runtimelib/client/test_pyinterop_flagship.jac` does a real
`group_by('g').agg(pl.col('v').sum())` on a python-free machine). Under that tier a
`DataFrame` is a **`PyObj` handle** that lives *entirely inside the embedded CPython
interpreter*. The na side never holds a column. What crosses the na<->py boundary is:

* method names (`str`),
* scalar arguments,
* whatever the user *explicitly* extracts (`out['v'].to_list()`).

The whole compute -- the part that touches every cell -- happens inside polars' Rust
engine, reached by Python method dispatch, with the buffers resident on one side the
entire time. **Copy-always never touches a polars column, because no column crosses a
boundary.** The critique's premise ("copying whole columns at every boundary
crossing") describes a boundary the adopted architecture does not have for this
workload.

This is the crux: the copy-always rule is a rule about *values that cross*. The
py-interop tier's answer to columnar cost is not "copy fast" -- it is "don't cross."
That is strictly stronger than zero-copy-on-cross for the resident-compute case, and
it is already shipped.

### Where copy-always *could* still hurt (and how narrow that is)

Copy-always bites only when large columnar/tensor data must actually **transit** a
boundary, repeatedly, and is touched less than it is copied. Enumerating the real
crossings in this codebase:

1. **`rust:` bridge return of a bulk buffer into na-native data.** A `rust:` crate
   returning `Vec<f64>` / `Vec<u8>` crosses via the wide lane (msgpack) or `TAG_BYTES`
   (a `memcpy`). The Phase-2 perf gate already measured a **10k-element `Vec<f64>` wide
   return at <=2x a memcpy floor (~0.5-1.5 ms) and accepted it** per priority 3
   (variety > peak performance). This is the only bulk copy that exists in-tree today,
   and it is already inside the accepted envelope.

2. **`py:` polars -> na-native compute.** Would require pulling a column out of the
   interpreter into na. But na has no columnar compute engine; if you are computing in
   na you want the data *in* na, i.e. you copy once and touch it many times -- the
   regime where copy cost is amortized to noise. Zero-copy only wins when you touch the
   data *less* than once (pure forwarding), and pure forwarding is exactly the case you
   keep as an **opaque handle** (no copy) instead of materializing.

3. **native engine <-> native engine (the Arrow dream).** `rust:polars` handing a
   column to `rust:ndarray` without copy. **This does not exist:** polars is a `py:`
   crate, not `rust:`; there is no ndarray/image bridge in the corpus; and priority 3
   says variety beats peak performance when they conflict.

Quantifying the workload class that would actually justify a zero-copy lane: a Float64
column of N rows is 8N bytes; at ~10 GB/s memcpy, 1M rows = 8 MB ~= 0.8 ms. A groupby
over those rows is O(N) at ~1e8 rows/s ~= 10 ms. **Copy is <10% of compute.** Copy only
*dominates* when the per-crossing work is smaller than the copy itself -- a single
trivial pass, or re-reading the same buffer every frame in a tight loop -- *and* the
buffer is large *and* it genuinely transits a boundary each time. That is a real class
(interactive viz over a resident tensor; a native decode->native filter->native encode
image pipeline with all three sides native), but **no crate in the corpus is in it**,
and the one library that would be (polars) is deliberately py-resident.

### Verdict on overlap

For the DataFrame workload the Arrow lane is **redundant**: py-interop already keeps
the frame resident and crosses only handles + extracted scalars. It is **not a better
path for the na side** either -- the only na-specific win would be moving a py-resident
column into *native* compute without copy, but native columnar compute is not a thing
that exists here, and if it did you would copy-once-into-na and be done. Arrow becomes
*complementary* only in the native-engine<->native-engine case (workload class 3),
which has zero corpus demand -- the same evidentiary basis on which
`FFI-LANES-PLAN.md` already **DEFERs** dyn-trait resources ("Measured zero ... No
corpus demand").

---

## Part II -- Arrow's release-callback protocol vs the D3 RC-dtor contract

Arrow's C Data Interface gives each `ArrowArray`/`ArrowSchema` a
`void (*release)(struct ArrowArray*)` callback with `private_data`. The **consumer**
calls `release` exactly once when done; `release` nulls itself as a released-marker;
child arrays form a tree released **only through the root** (recursive, single call).

### Where it fits the na object header dtor slot

The na RC machinery calls a `void(i8*)` dtor at rc==0 (`refcount.impl.jac:331-356`),
already the mechanism behind every opaque handle's `jac_<mod>_<T>_drop`. An
Arrow-backed resource stores the `ArrowArray` (or a pointer to it) in a field and its
synthesized dtor calls `array.release(&array)`. This is **structurally identical to
the existing handle-lane dtor**. Idempotence is doubly covered: na's atomic
decrement + double-free + magic-word checks, *plus* Arrow's own `release == NULL`
marker -- the same belt-and-suspenders as the existing `__handle = 0` guard (D3).
"Drop exactly once" holds.

The **only sound mapping** onto the na object model is **one na resource owning the
whole Arrow tree, releasing the root only.** na's model is one dtor per object; Arrow
forbids releasing children independently. So na must treat the entire array as one
opaque root handle. But that mapping is *exactly the existing HANDLE lane with a
different drop symbol* -- it buys nothing over "opaque `DataFrame` handle" **unless a
native consumer reads the underlying buffers**, which returns us to the absent
workload class 3.

### Where it fights

1. **Ownership direction.** Arrow's protocol is *consumer releases*. Import (Rust
   produces, na consumes) maps cleanly -> na dtor calls `release`. **Export** (na
   produces an Arrow array Rust consumes -- e.g. a Jac list -> Arrow -> `rust:polars`)
   inverts it: **Rust** must call **na's** release at an arbitrary later time, on an
   arbitrary thread, after the call returns. That is precisely the `JacCallback`
   `retain`/`release` "Rust stores a callback past the call" case that D4 v1
   **explicitly defers** (M6 "Callback `retain`/`release` when Rust stores a callback
   past the call (deferred)"), and it violates the D4 v1 rule that callbacks fire
   "on the calling thread, synchronously." Bidirectional zero-copy is blocked on
   already-deferred work.

2. **"Any thread" vs the v1 threading story.** D3 requires every opaque type be `Send`
   and drops on any thread via atomic RC -- compatible with Arrow release *if the
   release body is thread-safe*. A Rust-produced polars release is fine. An
   na-produced release running na dtor logic on a foreign thread is unproven -- the
   same "na-thread callbacks unproven, main-thread only" caveat the py tier accepted
   (`py-interop.md`). So even the release-callback direction that *could* be built
   inherits an open threading question.

3. **Two-struct / recursive-tree coupling** pushes you to the opaque-root mapping
   (above), which is the mapping that delivers no copy saving without a native buffer
   reader.

**Net:** import-only Arrow maps onto the RC dtor slot cleanly *and cheaply* -- but it
is a HANDLE-lane rename that saves no copies. The copy-saving directions (export,
native buffer read) fight D4 v1 (cross-thread stored callbacks, deferred) and the na
threading story. The cheap version is the useless one.

---

## Part III -- The lease-view primitive

### It is already built (the soundness half)

The critique's lease view -- `{ptr, len, keepalive_handle}`, Jac holds all three, RC
dtor releases the lease -- is **the borrowed-handle lane that already landed** (Phase
S / `HANDLE-SOUNDNESS-LANE.md`, `TAG_BORROW_BIT`):

* `#[jac(borrowed)]` on a method ORs **`TAG_BORROW_BIT` (0x0400_0000)** into the `Ref`
  return tag -- **already a constant in `_blob.jac` and the Rust schema**, pinned by
  `test_abi_drift.jac`.
* the na loader (`_synth.jac`) mints a borrowed view via a two-arg `init(raw, owner)`
  ctor that **`retain`s the owner and stores its handle**; `close()` releases the
  owner's RC-pin. Mirrored slot-for-slot in the ctypes loader.
* fixture `jac-bridge-view`: `Doc` + `Peek` where `Doc::peek` holds a **raw interior
  pointer** and owner-retain is load-bearing (a de-retained build reads garbage).
* conformance `borrowed_conformance.jac`: close the owner while a view is live (view
  still reads correctly; freed exactly once), view-first close, idempotent
  double-close.

So the keepalive machinery, the ordering guarantee, and the "owner closed while view
live" soundness are **done and shipped.** The `keepalive_handle` is just the retained
owner handle; the RC-dtor-releases-lease is `close()`/`__del__` calling the owner's
decref.

### The exact ABI shape, and why it needs no new tag

A lease is `TAG_REF | idx | TAG_BORROW_BIT`:

* `tag_ref_index(tag)` -> the **owner** type index (the keepalive).
* `TAG_BORROW_BIT` -> "this is a borrowed interior view; retain the owner, release on
  close."
* the `{ptr, len}` live in the wrapper object's fields alongside `__handle` (owner)
  -- the na wrapper already carries a handle field; a lease adds `__ptr`/`__len`.

ABI v1 is **frozen** (Phase 2.12), and this rides the frozen algebra with **zero new
wire tags** -- `TAG_BORROW_BIT` was reserved for exactly "binder-generated
identity/interior-view returns." The critique's "new metadata tag (if any)" question
resolves to: **none.** The bit exists.

### Aliasing / soundness rules

* **Read-only.** The view is `&[u8]`, never `&mut` -- multiple readers, no writer,
  no aliasing UB. This *relaxes* D3's "borrowed data never crosses" in a controlled
  way: borrowed data crosses, but the keepalive is the owner and outlives the view by
  RC construction.
* **Keepalive ordering.** One object owns both `{ptr,len}` and the owner handle, so
  they die together; the dtor stops exposing `ptr` before releasing the owner. This is
  the D3 child-borrows-parent rule (cursor holds a strong ref to its parent), already
  proven by `borrowed_conformance.jac`.
* **Immutable source (the real new constraint).** Rust's `&[u8]` requires the *source*
  not be mutated for the lease's lifetime. If na holds a lease while Rust mutates the
  source through another handle, that is a shared-XOR-mutable violation the reentrancy
  latch does **not** cover. **Rule:** lease views are sound **only over immutable /
  `Arc`-shared backing** (polars columns are `Arc<[T]>`, immutable -- a clean fit); a
  lease over a `&mut`-reachable buffer is **skip-with-reason**. This matches the
  existing "mutable interior views -> skip-with-reason" note already in
  `rust-bridges.md`.

### What is genuinely missing

Only one thing, and it is not the lifetime protocol: **na has no borrowed-bytes-view
type.** na bytes are owned/`calloc`'d (`__jac_bytes_from_raw` *copies*; per the na
memos, `len()` on a na buffer is `strlen`, binary buffers need an explicit length
flag). The existing borrowed lane exposes the owner through **method calls** on the
`Peek` object, not as a directly-readable buffer. A true zero-copy bulk **read** needs
na to expose a `bytes`-shaped view over foreign memory without copying -- a new na
runtime type that fights na's owned-buffer model. **Without it the lease degenerates to
copy-on-read, i.e. no better than `TAG_BYTES`.** That na capability is the entire
unbuilt cost of proposal (b), and it is unmotivated until a corpus crate returns a
large read-only buffer that na code reads element-wise.

---

## Part IV -- Recommendation

| Proposal | Verdict | One-line reason |
|---|---|---|
| **(a) Arrow C Data Interface lane** | **REJECT** | polars is a `py:` crate: the frame stays resident in the interpreter and only handles + extracted scalars cross, so copy-always never touches a column. The sound na mapping is import-only opaque-root = the existing HANDLE lane with a renamed drop symbol (no copy saved); the copy-saving directions (export, native buffer read) fight the deferred cross-thread `retain`/`release` callback and need a native Arrow-consuming bridge -- zero corpus demand, same basis as the dyn-trait DEFER. |
| **(b) Read-only lease view** | **DEFER (spec-only; soundness half already shipped)** | The lifetime protocol *is* the landed `TAG_BORROW_BIT` borrowed-handle lane (`jac-bridge-view`, owner-retain keepalive, `borrowed_conformance.jac`): zero new wire tags, ABI stays frozen. The one unbuilt piece is an na borrowed-bytes-**view** (na bytes are always owned/copied today); building it now is speculative with no corpus crate returning a large immutable buffer into native code. |

### Why not "build now"

Both proposals are answers to a cost the adopted architecture largely does not pay.
The py-interop tier already dissolves the DataFrame case by keeping data resident;
the wide-lane perf gate already accepts the one bulk copy that exists (10k `Vec<f64>`
at ~2x memcpy). Priority 3 is explicit: **variety beats peak performance when they
conflict.** Manufacturing a zero-copy lane for a workload class with no corpus member
would be the "scope creep back toward implementing Rust semantics" the plan's risk
register warns against.

### Trigger conditions that flip the verdict

* **Arrow lane -> BUILD** when a shipped workload chains **two native** (`rust:` or
  na) columnar/tensor engines that must share the *same* buffers -- e.g. a
  `rust:arrow2` + `rust:polars` pipeline, or na code iterating a >=1e7-row column
  element-wise **per frame** -- and profiling shows per-boundary column copies as the
  dominant cost. At that point build the **import-only, opaque-root** mapping first
  (it is the cheap HANDLE-lane special case) and only take on the export /
  cross-thread-release half if a bidirectional pipeline demands it.

* **Lease view -> BUILD** when a bridged crate returns a large (>~1 MB) **immutable**
  buffer -- image decode, `mmap`, `Arc<[u8]>` -- that na code reads element-wise or
  re-exports, and the `TAG_BYTES` copy shows up in a profile. The lifetime plumbing is
  done; the work is the na borrowed-bytes-view type plus the immutable-source gate
  (skip-with-reason otherwise). Keep the `TAG_BORROW_BIT` reservation as the
  placeholder in the meantime.

Until one of those triggers is a real, in-corpus workload, the correct amount of
zero-copy machinery to build is **none** -- and the borrowed-handle lane already
covers the interior-view soundness case that motivated the reservation.
