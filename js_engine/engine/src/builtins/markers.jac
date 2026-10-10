"""Central registry of hidden sentinel property keys for builtin type markers.

All keys live in the 1_000_001+ range (above BUILTIN_BASE) to avoid collision
with ordinary interned string keys.  Import from here instead of redefining.
"""

# ── Collection / builtin type markers ───────────────────────────────────────
glob:pub _KEY_IS_ARRAY: int = 1000001,
     _KEY_IS_MAP: int = 1000002,
     _KEY_IS_SET: int = 1000003,
     _KEY_IS_WEAKMAP: int = 1000004,
     _KEY_IS_WEAKSET: int = 1000005,
     _KEY_IS_SPREAD: int = 1000006,
     _KEY_IS_DATE: int = 1000008,
     _KEY_IS_REGEXP_MARK: int = 1000026,
     _KEY_IS_GEN_MARK: int = 1000027,
     _KEY_GEN_IDX_MARK: int = 1000028,
     _KEY_ASYNC_GEN_MARK: int = 1000029,
     _KEY_IS_STRING_OBJ: int = -20,
     _KEY_IS_TEMPORAL_PLAIN_DATE: int = 1003001,
     _KEY_IS_TEMPORAL_PLAIN_TIME: int = 1003002,
     _KEY_IS_TEMPORAL_PLAIN_DATETIME: int = 1003003,
     _KEY_IS_TEMPORAL_PLAIN_YEAR_MONTH: int = 1003004,
     _KEY_IS_TEMPORAL_PLAIN_MONTH_DAY: int = 1003005,
     _KEY_IS_TEMPORAL_DURATION: int = 1003006,
     _KEY_IS_TEMPORAL_INSTANT: int = 1003007,
     _KEY_IS_TEMPORAL_ZONED_DATETIME: int = 1003008,
     _KEY_IS_PROMISE: int = 1000009,
     _KEY_PSTATE: int = 1000010,
     _KEY_PVALUE: int = 1000011,
     _KEY_IS_RESOLVE: int = 1000012,
     _KEY_IS_REJECT: int = 1000013,
     _KEY_PROMISE_REF: int = 1000014,
     _KEY_PREACTIONS: int = 1000015,
     _KEY_IS_ASYNC_RESUME: int = 1000016,
     _KEY_IS_ASYNC_REJECT: int = 1000017,
     _KEY_ASYNC_RESUME_IDX: int = 1000018,
     _KEY_IS_ASYNC_ITER_RESUME: int = 1000019,
     _KEY_IS_ASYNC_ITER_REJECT: int = 1000020,
     _KEY_IS_TDZ: int = 1000021,
     _KEY_IS_ENV_OBJ: int = 1000022,
     _KEY_IS_ARGUMENTS: int = 1000024,
     KEY_HOME_REALM_ID: int = 1000025,
     _KEY_PROMISE_ALL_ELEM: int = 1001001,
     _KEY_PROMISE_ALL_IDX: int = 1001002,
     _KEY_PROMISE_ALL_RESULT: int = 1001003,
     _KEY_PROMISE_ALL_COUNT: int = 1001004,
     _KEY_PROMISE_ALLSETTLED_ELEM: int = 1001005,
     _KEY_PROMISE_RACE_ELEM: int = 1001006,
     _KEY_PROMISE_ANY_ELEM: int = 1001007,
     _KEY_PROMISE_ANY_ERRORS: int = 1001008,
     _KEY_PROMISE_ANY_COUNT: int = 1001009,
     _KEY_PROMISE_ANY_REJECTED: int = 1001010,
     _KEY_PROMISE_ANY_AGGREGATE: int = 1001011,
     _KEY_PROMISE_ANY_DONE: int = 1001012,
     _KEY_IS_PROMISE_ALL_RESOLVE: int = 1001013,
     _KEY_IS_PROMISE_ALL_REJECT: int = 1001014,
     _KEY_IS_PROMISE_ALLSETTLED_RESOLVE: int = 1001015,
     _KEY_IS_PROMISE_ALLSETTLED_REJECT: int = 1001016,
     _KEY_IS_PROMISE_ANY_REJECT: int = 1001017,
     _KEY_AH_ASYNC_ID: int = 1001018,
     _KEY_AH_TRIGGER_ID: int = 1001019,
     _KEY_PROMISE_COMB_INDEX: int = 1001004,
     _KEY_PROMISE_COMB_RESULT: int = 1001005,
     _KEY_IS_THENABLE_JOB: int = 1004001,
     _KEY_THENABLE_VALUE: int = 1004002,
     _KEY_THENABLE_THEN: int = 1004003,
     _KEY_PRESOLVED: int = 1004004,
     _KEY_IS_VM_CONTEXT: int = 1005001,
     _KEY_FROM_ASYNC_RESULT: int = 1002001,
     _KEY_FROM_ASYNC_OUT: int = 1002002,
     _KEY_FROM_ASYNC_ITER: int = 1002003,
     _KEY_FROM_ASYNC_IDX: int = 1002004,
     _KEY_FROM_ASYNC_THIS: int = 1002005,
     _KEY_FROM_ASYNC_CONTINUE: int = 1002006,
     _KEY_FROM_ASYNC_AWAIT_ELEM: int = 1002007,
     _KEY_FROM_ASYNC_ELEM_IDX: int = 1002008,
     _KEY_FROM_ASYNC_SOURCE: int = 1002009,
     _KEY_FROM_ASYNC_MAPFN: int = 1002010,
     _KEY_FROM_ASYNC_MAP_THIS: int = 1002011,
     _KEY_FROM_ASYNC_AWAIT_MAPPED: int = 1002012,
     _KEY_FROM_ASYNC_NEXT: int = 1002013,
     _KEY_FROM_ASYNC_LEN: int = 1002014,
     _KEY_FROM_ASYNC_ASYNC_MODE: int = 1002015,
     _KEY_FROM_ASYNC_CLOSE_AWAIT: int = 1002016,
     _KEY_FROM_ASYNC_REJECT_REASON: int = 1002017;
# 1000007 reserved

# RegExp instance marker. Formerly str_intern("__regexp__"), which made it a real
# string key that leaked into Object.getOwnPropertyNames(re) (ES §22.2.7.2: a
# RegExp instance has exactly one own property, `lastIndex`).

# Generator object marker. Formerly str_intern("__gen__"): a real string key, so
# any object given an own `__gen__` property passed js_is_generator.

# Generator bookkeeping, formerly the string keys "__gen_idx__" / "__async_gen__",
# which showed up in Object.getOwnPropertyNames / Object.keys of every generator.
# index into realm.generators
# present on async generators
# String wrapper marker (holds the wrapped primitive). Negative: never collides
# with str_intern() ids. Must equal builtins.string.KEY_IS_STRING_OBJ.

# ── Temporal type markers ─────────────────────────────────────────────────────

# ── Promise / async markers ───────────────────────────────────────────────────

# Marks an `arguments` exotic object: an ordinary object (Object.prototype) that
# iterates array-style (0..length-1) and reports [object Arguments].  (1000023 is
# taken by KEY_CTOR_KIND in jsobject.na.jac — must not collide.)

# Records the id of the realm a cross-realm construct belongs to (merge: adel_fixes
# used 1000024 which now collides with _KEY_IS_ARGUMENTS above → moved to 1000025).

# ── Promise combinator reaction sentinels (dispatch-internal) ─────────────────

# Wave 20 — native PromiseHook async id slot on promise objects

# ── NewPromiseResolveThenableJob (§27.2.2.2) ─────────────────────────────────
# Resolving a promise with a thenable must not fulfil with the thenable itself:
# a job is queued that calls thenable.then(resolveFn, rejectFn) so the outer
# promise adopts the thenable's eventual state. These keys carry that job's
# payload on a marker object dispatched by vm_exec_reaction.

# Set on a promise once its resolving function has run (§27.2.1.3
# [[AlreadyResolved]]). Resolution with a thenable leaves the promise PENDING
# while the job is queued, so "already settled" is not enough to tell that a
# later reject must be ignored.

# ── vm.createContext contextified sandbox marker ──────────────────────────────
# Set on a sandbox by vm.createContext(); read back by vm.isContext().  Lives
# above BUILTIN_BASE so it stays invisible to Object.keys /
# getOwnPropertyNames — Node's contextified sandboxes expose no extra own key.

# ── Array.fromAsync async-iterator driver (vm-internal) ───────────────────────

# Array.fromAsync(items, mapfn, thisArg): the mapping function and its receiver,
# stashed on the result promise so the per-element walk can apply them.
# Merge note: the more spec-complete async-from-sync / array-like / iterator-close
# fromAsync driver from adel_fixes is the one that survived the merge, so its
# key names (_MAP_THIS / _AWAIT_MAPPED) are the canonical ones.

# Set while awaiting a mapfn's *result*, so the awaited value is stored rather
# than fed back through the mapping a second time.

# IteratorRecord [[NextMethod]] cache
# array-like LengthOfArrayLike snapshot
# true → @@asyncIterator (skip input Await)
# AsyncIteratorClose await return()
# pending reject reason during close
