import from c {
    glob PyTuple_Type: PyTypeObject,
         _PyWeakref_RefType: PyTypeObject,
         _PyWeakref_ProxyType: PyTypeObject,
         _PyWeakref_CallableProxyType: PyTypeObject,
         PyExc_ResourceWarning: ptr[PyObject]; def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def PyObject_Realloc(p: ptr, size: u64) -> ptr;  def PySys_WriteStderr(
        format: str, *args: any
    );  def PySys_FormatStderr(format: str, *args: any);  def PyErr_WarnExplicitFormat(
        category: ptr[PyObject],
        filename: str,
        lineno: i32,
        module: str,
        registry: ptr[PyObject],
        format: str,
        *args: any
    ) -> i32;  def _PyObject_AssertFailed(
        obj_: ptr[PyObject],
        expr: ptr[u8],
        msg: ptr[u8],
        file: ptr[u8],
        line: i32,
        function: ptr[u8]
    );  def _PyObject_Dump(op: ptr[PyObject]);  def _PyObject_InitInlineValues(
        ob: ptr[PyObject], tp: ptr[PyTypeObject]
    );  def _PyObject_ClearFreeLists(freelists: ptr[u8], is_finalization: i32);  def _PyWeakref_ClearRef(
        r: ptr[PyWeakReference]
    );  def _PyTuple_MaybeUntrack(op: ptr[PyObject]);  def PyModuleDef_Init(
        mdef: ptr[PyModuleDef]
    ) -> ptr[PyObject];  obj GcStack {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut GcStack) -> int;  obj GcTraverseCall {
        has call: Callable[[ptr[PyObject], ptr, ptr], i32] = 0;
    }  obj GcVisitCall {
        has call: Callable[[ptr[PyObject], ptr], i32] = 0;
    }
}

glob:priv PREV_MASK_COLLECTING: Final[u64] = 2,
     NEXT_MASK_UNREACHABLE: Final[u64] = 1,
     PREV_MASK_FINALIZED: Final[u64] = 1,
     PREV_FLAGS: Final[u64] = 3,
     PREV_SHIFT: Final[u64] = 2,
     PREV_REFS_ONE: Final[u64] = 4,
     GENERATION_AUTO: Final[i32] = -1,
     STACKREF_TAG_REFCNT: Final[u64] = 1,
     STACKREF_INT_TAG: Final[u64] = 3,
     STACKREF_NULL_BITS: Final[u64] = 1,
     PY_SSIZE_T_MAX_SIZE: Final[u64] = 0x7FFFFFFFFFFFFFFF,
     INT_MAX_LONG: Final[i64] = 2147483647,
     INT_MIN_LONG: Final[i64] = -2147483648;

def as_gc(op: ptr[PyObject]) -> ptr[PyGC_Head];

def from_gc(g: ptr[PyGC_Head]) -> ptr[PyObject];

def gc_addr(g: ptr[PyGC_Head]) -> u64;

def gc_at(bits: u64) -> ptr[PyGC_Head];

def gc_next(g: ptr[PyGC_Head]) -> ptr[PyGC_Head];

def gc_prev(g: ptr[PyGC_Head]) -> ptr[PyGC_Head];

def gc_set_next(g: ptr[PyGC_Head], nxt: ptr[PyGC_Head]);

def gc_set_prev(g: ptr[PyGC_Head], prv: ptr[PyGC_Head]);

def gc_is_collecting(g: ptr[PyGC_Head]) -> bool;

def gc_clear_collecting(g: ptr[PyGC_Head]);

def gc_get_refs(g: ptr[PyGC_Head]) -> i64;

def gc_set_refs(g: ptr[PyGC_Head], refs: i64);

def gc_reset_refs(g: ptr[PyGC_Head], refs: i64);

def gc_decref(g: ptr[PyGC_Head]);

def gc_state_of(interp: ptr[u8]) -> ptr[u8];

def tstate_gc_state(tstate: ptr[PyThreadState]) -> ptr[u8];

def get_gc_state -> ptr[u8];

def gen_at(gcstate: ptr[u8], n: i32) -> ptr[gc_generation];

def gen_head(gcstate: ptr[u8], n: i32) -> ptr[PyGC_Head];

def permanent_head(gcstate: ptr[u8]) -> ptr[PyGC_Head];

def stats_at(gcstate: ptr[u8], n: i32) -> ptr[gc_generation_stats];

def gc_enabled_slot(gcstate: ptr[u8]) -> ptr[i32];

def gc_debug(gcstate: ptr[u8]) -> i32;

def gc_garbage_slot(gcstate: ptr[u8]) -> ptr[ptr[PyObject]];

def gc_callbacks_slot(gcstate: ptr[u8]) -> ptr[ptr[PyObject]];

def call_traverse(traverse: int, op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def call_visit(visitor: ptr, op: ptr[PyObject], arg: ptr) -> i32;

import from c {
    def _PyGC_InitState(gcstate: ptr[u8]) {
        i: i32 = 0;
        while i < NUM_GENERATIONS {
            gc_list_init(gen_head(gcstate, i));
            i += 1;
        }
        ptr[ptr[PyGC_Head]](gcstate + _gc_runtime_state_GENERATION0).view(1)[0] = gen_head(
            gcstate, i32(0)
        );
        gc_list_init(permanent_head(gcstate));
    }  def _PyGC_Init(interp: ptr[u8]) -> PyStatus {
        gcstate = gc_state_of(interp);
        garbage = gc_garbage_slot(gcstate);
        garbage.view(1)[0] = PyList_New(0);
        if not garbage.view(1)[0] {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyGC_Init"),
                err_msg=ptr[u8]("memory allocation failed"),
                exitcode=0
            );
        }
        callbacks = gc_callbacks_slot(gcstate);
        callbacks.view(1)[0] = PyList_New(0);
        if not callbacks.view(1)[0] {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyGC_Init"),
                err_msg=ptr[u8]("memory allocation failed"),
                exitcode=0
            );
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }
}

def gc_list_init(lst: ptr[PyGC_Head]);

def gc_list_is_empty(lst: ptr[PyGC_Head]) -> bool;

def gc_list_append(node_: ptr[PyGC_Head], lst: ptr[PyGC_Head]);

def gc_list_remove(node_: ptr[PyGC_Head]);

def gc_list_move(node_: ptr[PyGC_Head], lst: ptr[PyGC_Head]);

def gc_list_merge(from_: ptr[PyGC_Head], to: ptr[PyGC_Head]);

def gc_list_size(lst: ptr[PyGC_Head]) -> i64;

def gc_list_clear_collecting(collectable: ptr[PyGC_Head]);

def append_objects(py_list: ptr[PyObject], gc_list: ptr[PyGC_Head]) -> i32;

def update_refs(containers: ptr[PyGC_Head]);

def visit_decref(op: ptr[PyObject], parent: ptr) -> i32;

def visit_stackref(bits: u64, visitor: ptr, arg: ptr) -> i32;

import from c {
    def _PyGC_VisitStackRef(ref: ptr[u64], visitor: ptr, arg: ptr) -> i32 {
        return visit_stackref(ref.view(1)[0], visitor, arg);
    }  def _PyGC_VisitFrameStack(frame: ptr[u8], visitor: ptr, arg: ptr) -> i32 {
        ref = ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS);
        top = ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER).view(1)[0];

        while int(ref) < int(top) {
            bits = ref.view(1)[0];
            if (bits & STACKREF_INT_TAG) != STACKREF_INT_TAG
                and bits != STACKREF_NULL_BITS {
                vret = visit_stackref(bits, visitor, arg);
                if vret != 0 {
                    return vret;
                }
            }
            ref = ref + 1;
        }
        return 0;
    }
}

def subtract_refs(containers: ptr[PyGC_Head]);

def visit_reachable(op: ptr[PyObject], arg: ptr) -> i32;

def move_unreachable(young: ptr[PyGC_Head], unreachable: ptr[PyGC_Head]);

def untrack_tuples(head: ptr[PyGC_Head]);

def has_legacy_finalizer(op: ptr[PyObject]) -> bool;

def move_legacy_finalizers(unreachable: ptr[PyGC_Head], finalizers: ptr[PyGC_Head]);

def clear_unreachable_mask(unreachable: ptr[PyGC_Head]);

def visit_move(op: ptr[PyObject], arg: ptr) -> i32;

def move_legacy_finalizer_reachable(finalizers: ptr[PyGC_Head]);

def is_weakref(op: ptr[PyObject]) -> bool;

def handle_weakrefs(
    unreachable: ptr[PyGC_Head], old: ptr[PyGC_Head], allow_callbacks: bool
) -> i32;

def debug_cycle(msg: ptr[u8], op: ptr[PyObject]);

def handle_legacy_finalizers(
    tstate: ptr[PyThreadState],
    gcstate: ptr[u8],
    finalizers: ptr[PyGC_Head],
    old: ptr[PyGC_Head]
);

def finalize_garbage(tstate: ptr[PyThreadState], collectable: ptr[PyGC_Head]);

def delete_garbage(
    tstate: ptr[PyThreadState],
    gcstate: ptr[u8],
    collectable: ptr[PyGC_Head],
    old: ptr[PyGC_Head]
);

def show_stats_each_generations(gcstate: ptr[u8]);

def deduce_unreachable(base: ptr[PyGC_Head], unreachable: ptr[PyGC_Head]);

def handle_resurrected_objects(
    unreachable: ptr[PyGC_Head],
    still_unreachable: ptr[PyGC_Head],
    old_generation: ptr[PyGC_Head]
);

def invoke_gc_callback(
    tstate: ptr[PyThreadState],
    phase: ptr[u8],
    generation: i32,
    collected: i64,
    uncollectable: i64
);

def gc_select_generation(gcstate: ptr[u8]) -> i32;

def gc_collect_main(tstate: ptr[PyThreadState], generation: i32, reason: i32) -> i64;

def referrersvisit(obj_: ptr[PyObject], arg: ptr) -> i32;

def gc_referrers_for(
    objs: ptr[PyObject], lst: ptr[PyGC_Head], resultlist: ptr[PyObject]
) -> i32;

def visit_generation(callback: ptr, arg: ptr, gen: ptr[gc_generation]) -> i32;

def finalize_unlink_gc_head(gc: ptr[PyGC_Head]);

def gc_alloc(tp: ptr[PyTypeObject], basicsize: u64, presize: u64) -> ptr[PyObject];

import from c {
    def _PyGC_GetReferrers(interp: ptr[u8], objs: ptr[PyObject]) -> ptr[PyObject] {
        result = PyList_New(0);
        if not result {
            return NULL;
        }
        gcstate = gc_state_of(interp);
        i: i32 = 0;
        while i < NUM_GENERATIONS {
            if gc_referrers_for(objs, gen_head(gcstate, i), result) == 0 {
                object_decref(result);
                return NULL;
            }
            i += 1;
        }
        return result;
    }  def _PyGC_GetObjects(interp: ptr[u8], generation: i32) -> ptr[PyObject] {
        gcstate = gc_state_of(interp);
        result = PyList_New(0);
        if not result {
            return NULL;
        }
        if generation == -1 {
            i: i32 = 0;
            while i < NUM_GENERATIONS {
                if append_objects(result, gen_head(gcstate, i)) != 0 {
                    object_decref(result);
                    return NULL;
                }
                i += 1;
            }
        } else {
            if append_objects(result, gen_head(gcstate, generation)) != 0 {
                object_decref(result);
                return NULL;
            }
        }
        return result;
    }  def _PyGC_Freeze(interp: ptr[u8]) {
        gcstate = gc_state_of(interp);
        i: i32 = 0;
        while i < NUM_GENERATIONS {
            gc_list_merge(gen_head(gcstate, i), permanent_head(gcstate));
            gen_at(gcstate, i).view(1)[0].count = 0;
            i += 1;
        }
    }  def _PyGC_Unfreeze(interp: ptr[u8]) {
        gcstate = gc_state_of(interp);
        gc_list_merge(permanent_head(gcstate), gen_head(gcstate, NUM_GENERATIONS - 1));
    }  def _PyGC_GetFreezeCount(interp: ptr[u8]) -> i64 {
        return gc_list_size(permanent_head(gc_state_of(interp)));
    }  def PyGC_Enable -> i32 {
        enabled = gc_enabled_slot(get_gc_state());
        old_state = enabled.view(1)[0];
        enabled.view(1)[0] = 1;
        return old_state;
    }  def PyGC_Disable -> i32 {
        enabled = gc_enabled_slot(get_gc_state());
        old_state = enabled.view(1)[0];
        enabled.view(1)[0] = 0;
        return old_state;
    }  def PyGC_IsEnabled -> i32 {
        return gc_enabled_slot(get_gc_state()).view(1)[0];
    }  def PyGC_Collect -> i64 {
        tstate = current_tstate();
        gcstate = tstate_gc_state(tstate);
        if gc_enabled_slot(gcstate).view(1)[0] == 0 {
            return 0;
        }
        exc = PyErr_GetRaisedException();
        n = gc_collect_main(tstate, NUM_GENERATIONS - 1, _Py_GC_REASON_MANUAL);
        PyErr_SetRaisedException(exc);
        return n;
    }  def _PyGC_Collect(
        tstate: ptr[PyThreadState], generation: i32, reason: i32
    ) -> i64 {
        return gc_collect_main(tstate, generation, reason);
    }  def _PyGC_CollectNoFail(tstate: ptr[PyThreadState]) {
        gc_collect_main(tstate, NUM_GENERATIONS - 1, _Py_GC_REASON_SHUTDOWN);
    }  def _PyGC_DumpShutdownStats(interp: ptr[u8]) {
        gcstate = gc_state_of(interp);
        garbage = gc_garbage_slot(gcstate);
        if (gc_debug(gcstate) & _PyGC_DEBUG_SAVEALL) == 0
            and garbage.view(1)[0]
            and object_size(garbage.view(1)[0]) > 0 {
            warned: i32 = 0;
            if (gc_debug(gcstate) & _PyGC_DEBUG_UNCOLLECTABLE) != 0 {
                warned = PyErr_WarnExplicitFormat(
                    PyExc_ResourceWarning,
                    "gc",
                    i32(0),
                    "gc",
                    NULL,
                    "gc: %zd uncollectable objects at shutdown",
                    object_size(garbage.view(1)[0])
                );
            } else {
                warned = PyErr_WarnExplicitFormat(
                    PyExc_ResourceWarning,
                    "gc",
                    i32(0),
                    "gc",
                    NULL,
                    "gc: %zd uncollectable objects at shutdown; use gc.set_debug(gc.DEBUG_UNCOLLECTABLE) to list them",
                    object_size(garbage.view(1)[0])
                );
            }
            if warned != 0 {
                PyErr_FormatUnraisable("Exception ignored in GC shutdown");
            }
            if (gc_debug(gcstate) & _PyGC_DEBUG_UNCOLLECTABLE) != 0 {
                repr = PyObject_Repr(garbage.view(1)[0]);
                bytes_obj = NULL;
                if repr {
                    bytes_obj = PyUnicode_EncodeFSDefault(repr);
                }
                if not repr or not bytes_obj {
                    PyErr_FormatUnraisable(
                        "Exception ignored in GC shutdown while formatting garbage"
                    );
                } else {
                    PySys_WriteStderr(
                        "      %s\n", ptr[u8](bytes_obj) + PyBytesObject_OB_SVAL
                    );
                }
                object_xdecref(repr);
                object_xdecref(bytes_obj);
            }
        }
    }  def _PyGC_Fini(interp: ptr[u8]) {
        gcstate = gc_state_of(interp);
        garbage = gc_garbage_slot(gcstate);
        old_garbage = garbage.view(1)[0];
        if old_garbage {
            garbage.view(1)[0] = NULL;
            object_decref(old_garbage);
        }
        callbacks = gc_callbacks_slot(gcstate);
        old_callbacks = callbacks.view(1)[0];
        if old_callbacks {
            callbacks.view(1)[0] = NULL;
            object_decref(old_callbacks);
        }

        i: i32 = 0;
        while i < NUM_GENERATIONS {
            finalize_unlink_gc_head(gen_head(gcstate, i));
            i += 1;
        }
        finalize_unlink_gc_head(permanent_head(gcstate));
    }  def _PyGC_Dump(g: ptr[PyGC_Head]) {
        _PyObject_Dump(from_gc(g));
    }  def PyObject_GC_Track(op_raw: ptr) {
        op = ptr[PyObject](op_raw);
        if object_gc_is_tracked(op) {
            _PyObject_AssertFailed(
                op,
                ptr[u8](),
                ptr[u8]("object already tracked by the garbage collector"),
                ptr[u8]("Python/gc.c"),
                i32(1814),
                ptr[u8]("PyObject_GC_Track")
            );
        }
        object_gc_track(op);
    }  def PyObject_GC_UnTrack(op_raw: ptr) {
        object_gc_untrack(ptr[PyObject](op_raw));
    }  def PyObject_IS_GC(obj_: ptr[PyObject]) -> i32 {
        if object_is_gc(obj_) {
            return 1;
        }
        return 0;
    }  def _Py_ScheduleGC(tstate: ptr[PyThreadState]) {
        breaker = int(tstate) + PyThreadState_EVAL_BREAKER;
        bit = i64.wrap(_PY_GC_SCHEDULED_BIT);
        if (__atomic_load_i64(breaker, 0) & bit) == 0 {
            __atomic_or_i64(breaker, bit, 5);
        }
    }  def _PyObject_GC_Link(op: ptr[PyObject]) {
        gc = as_gc(op);

        tstate = current_tstate();
        gcstate = tstate_gc_state(tstate);
        gc.view(1)[0]._gc_next = u64(0);
        gc.view(1)[0]._gc_prev = u64(0);
        gen0 = gen_at(gcstate, i32(0));

        count = wrapping_add(gen0.view(1)[0].count, i32(1));
        gen0.view(1)[0].count = count;
        if count > gen0.view(1)[0].threshold
            and gc_enabled_slot(gcstate).view(1)[0] != 0
            and gen0.view(1)[0].threshold != 0
            and __atomic_load_i32(int(gcstate + _gc_runtime_state_COLLECTING), 0) == 0
            and not exception_raised(tstate) {
            _Py_ScheduleGC(tstate);
        }
    }  def _Py_RunGC(tstate: ptr[PyThreadState]) {
        if gc_enabled_slot(get_gc_state()).view(1)[0] == 0 {
            return;
        }
        gc_collect_main(tstate, GENERATION_AUTO, _Py_GC_REASON_HEAP);
    }  def _PyObject_GC_New(tp: ptr[PyTypeObject]) -> ptr[PyObject] {
        presize = type_preheader_size(tp);
        size = tp.view(1)[0].tp_basicsize;
        if type_has_feature(tp, Py_TPFLAGS_INLINE_VALUES) {
            size += inline_values_size(tp);
        }
        op = gc_alloc(tp, u64(size), u64(presize));
        if not op {
            return NULL;
        }
        object_init(op, tp);
        if (tp.view(1)[0].tp_flags & Py_TPFLAGS_INLINE_VALUES) != 0 {
            _PyObject_InitInlineValues(op, tp);
        }
        return op;
    }  def _PyObject_GC_NewVar(tp: ptr[PyTypeObject], nitems: i64) -> ptr[PyObject] {
        if nitems < 0 {
            PyErr_BadInternalCall();
            return NULL;
        }
        presize = type_preheader_size(tp);
        size = var_size(tp, nitems);
        op = gc_alloc(tp, u64(size), u64(presize));
        if not op {
            return NULL;
        }
        object_init(op, tp);
        ptr[PyVarObject](op).view(1)[0].ob_size = nitems;
        return op;
    }  def PyUnstable_Object_GC_NewWithExtraData(
        tp: ptr[PyTypeObject], extra_size: u64
    ) -> ptr[PyObject] {
        presize = type_preheader_size(tp);
        size = wrapping_add(u64(tp.view(1)[0].tp_basicsize), extra_size);
        op = gc_alloc(tp, size, u64(presize));
        if not op {
            return NULL;
        }
        memset(
            ptr(ptr[u8](op) + PyObject_HEAD_SIZE), 0, size - u64(PyObject_HEAD_SIZE)
        );
        object_init(op, tp);
        return op;
    }  def _PyObject_GC_Resize(op: ptr[PyObject], nitems: i64) -> ptr[PyObject] {
        tp = object_type(op);
        basicsize = var_size(tp, nitems);
        presize = type_preheader_size(tp);

        if u64(basicsize) > PY_SSIZE_T_MAX_SIZE - u64(presize) {
            return PyErr_NoMemory();
        }
        mem = PyObject_Realloc(ptr(ptr[u8](op) - presize), u64(presize + basicsize));
        if not mem {
            return PyErr_NoMemory();
        }
        resized = ptr[PyObject](ptr[u8](mem) + presize);
        ptr[PyVarObject](resized).view(1)[0].ob_size = nitems;
        return resized;
    }  def PyObject_GC_Del(op: ptr) {
        obj_ = ptr[PyObject](op);
        presize = type_preheader_size(object_type(obj_));
        g = as_gc(obj_);
        gcstate = get_gc_state();
        if object_gc_is_tracked(obj_) {
            gc_list_remove(g);
            heap_size = ptr[i64](gcstate + _gc_runtime_state_HEAP_SIZE);
            heap_size.view(1)[0] = wrapping_sub(heap_size.view(1)[0], i64(1));
        }
        gen0 = gen_at(gcstate, i32(0));
        if gen0.view(1)[0].count > 0 {
            gen0.view(1)[0].count = gen0.view(1)[0].count - 1;
        }
        PyObject_Free(ptr(ptr[u8](obj_) - presize));
    }  def PyObject_GC_IsTracked(obj_: ptr[PyObject]) -> i32 {
        if object_is_gc(obj_) and object_gc_is_tracked(obj_) {
            return 1;
        }
        return 0;
    }  def PyObject_GC_IsFinalized(obj_: ptr[PyObject]) -> i32 {
        if object_is_gc(obj_) and gc_finalized(obj_) {
            return 1;
        }
        return 0;
    }  def PyUnstable_GC_VisitObjects(callback: ptr, arg: ptr) {
        gcstate = get_gc_state();
        enabled = gc_enabled_slot(gcstate);
        original_state = enabled.view(1)[0];
        enabled.view(1)[0] = 0;
        stopped = False;
        i: i32 = 0;
        while i < NUM_GENERATIONS {
            if visit_generation(callback, arg, gen_at(gcstate, i)) < 0 {
                stopped = True;
                break;
            }
            i += 1;
        }
        if not stopped {
            visit_generation(
                callback,
                arg,
                ptr[gc_generation](gcstate + _gc_runtime_state_PERMANENT_GENERATION)
            );
        }
        enabled.view(1)[0] = original_state;
    }  def _PyGC_ClearAllFreeLists(interp: ptr[u8]) {
        _PyObject_ClearFreeLists(interp + PyInterpreterState_FREELISTS, i32(0));
    }
}

def gc_enable_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_enable(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_disable_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_disable(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_isenabled_impl(module: ptr[PyObject]) -> i32;

def gc_isenabled(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def unpack_generation(
    args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject], fname: ptr[u8]
) -> tuple[i32, ptr[PyObject]];

def unexpected_keyword_arg(kwnames: ptr[PyObject], fname: ptr[u8]);

def gc_collect_impl(module: ptr[PyObject], generation: i32) -> i64;

def gc_collect(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def gc_set_debug_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject];

def gc_set_debug(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def gc_get_debug_impl(module: ptr[PyObject]) -> i32;

def gc_get_debug(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_set_threshold_impl(
    module: ptr[PyObject],
    threshold0: i32,
    group_right_1: i32,
    threshold1: i32,
    group_right_2: i32,
    threshold2: i32
) -> ptr[PyObject];

def convert_int_arg(arg: ptr[PyObject]) -> tuple[i32, i32];

def gc_set_threshold(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def gc_get_threshold_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_get_threshold(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_get_count_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_get_count(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_get_referrers_impl(module: ptr[PyObject], objs: ptr[PyObject]) -> ptr[PyObject];

def gc_get_referrers(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def referentsvisit(obj_: ptr[PyObject], arg: ptr) -> i32;

def append_referrents(result: ptr[PyObject], args: ptr[PyObject]) -> i32;

def gc_get_referents_impl(module: ptr[PyObject], objs: ptr[PyObject]) -> ptr[PyObject];

def gc_get_referents(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def gc_get_objects_impl(module: ptr[PyObject], generation: i64) -> ptr[PyObject];

def gc_get_objects(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def gc_get_stats_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_get_stats(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_is_tracked_impl(module: ptr[PyObject], obj_: ptr[PyObject]) -> i32;

def gc_is_tracked(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def gc_is_finalized_impl(module: ptr[PyObject], obj_: ptr[PyObject]) -> i32;

def gc_is_finalized(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def gc_freeze_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_freeze(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_unfreeze_impl(module: ptr[PyObject]) -> ptr[PyObject];

def gc_unfreeze(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def gc_get_freeze_count_impl(module: ptr[PyObject]) -> i64;

def gc_get_freeze_count(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def gcmodule_exec(module: ptr[PyObject]) -> i32;

import from c {
    glob:priv GcMethods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("enable"),
                 ml_meth=ptr(gc_enable),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "enable($module, /)\n--\n\nEnable automatic garbage collection."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("disable"),
                 ml_meth=ptr(gc_disable),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "disable($module, /)\n--\n\nDisable automatic garbage collection."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isenabled"),
                 ml_meth=ptr(gc_isenabled),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "isenabled($module, /)\n--\n\n"
                     "Returns true if automatic garbage collection is enabled."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_debug"),
                 ml_meth=ptr(gc_set_debug),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "set_debug($module, flags, /)\n--\n\n"
                     "Set the garbage collection debugging flags.\n\n"
                     "  flags\n"
                     "    An integer that can have the following bits turned on:\n"
                     "      DEBUG_STATS - Print statistics during collection.\n"
                     "      DEBUG_COLLECTABLE - Print collectable objects found.\n"
                     "      DEBUG_UNCOLLECTABLE - Print unreachable but uncollectable objects\n"
                     "        found.\n"
                     "      DEBUG_SAVEALL - Save objects to gc.garbage rather than freeing them.\n"
                     "      DEBUG_LEAK - Debug leaking programs (everything but STATS).\n\n"
                     "Debugging information is written to sys.stderr."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_debug"),
                 ml_meth=ptr(gc_get_debug),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_debug($module, /)\n--\n\nGet the garbage collection debugging flags."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_count"),
                 ml_meth=ptr(gc_get_count),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_count($module, /)\n--\n\n"
                     "Return a three-tuple of the current collection counts."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_threshold"),
                 ml_meth=ptr(gc_set_threshold),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "set_threshold(threshold0, [threshold1, [threshold2]])\n"
                     "Set the collection thresholds (the collection frequency).\n\n"
                     "Setting 'threshold0' to zero disables collection."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_threshold"),
                 ml_meth=ptr(gc_get_threshold),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_threshold($module, /)\n--\n\n"
                     "Return the current collection thresholds."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("collect"),
                 ml_meth=ptr(gc_collect),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "collect($module, /, generation=2)\n--\n\n"
                     "Run the garbage collector.\n\n"
                     "With no arguments, run a full collection.  The optional argument\n"
                     "may be an integer specifying which generation to collect.  A ValueError\n"
                     "is raised if the generation number is invalid.\n\n"
                     "The number of unreachable objects is returned."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_objects"),
                 ml_meth=ptr(gc_get_objects),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_objects($module, /, generation=None)\n--\n\n"
                     "Return a list of objects tracked by the collector (excluding the list returned).\n\n"
                     "  generation\n"
                     "    Generation to extract the objects from.\n\n"
                     "If generation is not None, return only the objects tracked by the\n"
                     "collector that are in that generation."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_stats"),
                 ml_meth=ptr(gc_get_stats),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_stats($module, /)\n--\n\n"
                     "Return a list of dictionaries containing per-generation statistics."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_tracked"),
                 ml_meth=ptr(gc_is_tracked),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_tracked($module, obj, /)\n--\n\n"
                     "Returns true if the object is tracked by the garbage collector.\n\n"
                     "Simple atomic objects will return false."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_finalized"),
                 ml_meth=ptr(gc_is_finalized),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_finalized($module, obj, /)\n--\n\n"
                     "Returns true if the object has been already finalized by the GC."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_referrers"),
                 ml_meth=ptr(gc_get_referrers),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "get_referrers($module, /, *objs)\n--\n\n"
                     "Return the list of objects that directly refer to any of 'objs'."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_referents"),
                 ml_meth=ptr(gc_get_referents),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "get_referents($module, /, *objs)\n--\n\n"
                     "Return the list of objects that are directly referred to by 'objs'."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("freeze"),
                 ml_meth=ptr(gc_freeze),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "freeze($module, /)\n--\n\n"
                     "Freeze all current tracked objects and ignore them for future collections.\n\n"
                     "This can be used before a POSIX fork() call to make the gc copy-on-write\n"
                     "friendly.\n"
                     "Note: collection before a POSIX fork() call may free pages for future\n"
                     "allocation which can cause copy-on-write."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("unfreeze"),
                 ml_meth=ptr(gc_unfreeze),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "unfreeze($module, /)\n--\n\n"
                     "Unfreeze all objects in the permanent generation.\n\n"
                     "Put all objects in the permanent generation back into oldest generation."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_freeze_count"),
                 ml_meth=ptr(gc_get_freeze_count),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_freeze_count($module, /)\n--\n\n"
                     "Return the number of objects in the permanent generation."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         gcmodule_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(gcmodule_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         gcmodule: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("gc"),
             m_doc=ptr[u8](
                 "This module provides access to the garbage collector for reference cycles.\n"
                 "\n"
                 "enable() -- Enable automatic garbage collection.\n"
                 "disable() -- Disable automatic garbage collection.\n"
                 "isenabled() -- Returns true if automatic collection is enabled.\n"
                 "collect() -- Do a full collection right now.\n"
                 "get_count() -- Return the current collection counts.\n"
                 "get_stats() -- Return list of dictionaries containing per-generation stats.\n"
                 "set_debug() -- Set debugging flags.\n"
                 "get_debug() -- Get debugging flags.\n"
                 "set_threshold() -- Set the collection thresholds.\n"
                 "get_threshold() -- Return the current collection thresholds.\n"
                 "get_objects() -- Return a list of all objects tracked by the collector.\n"
                 "is_tracked() -- Returns true if a given object is tracked.\n"
                 "is_finalized() -- Returns true if a given object has been already finalized.\n"
                 "get_referrers() -- Return the list of objects that refer to an object.\n"
                 "get_referents() -- Return the list of objects that an object refers to.\n"
                 "freeze() -- Freeze all tracked objects and ignore them for future collections.\n"
                 "unfreeze() -- Unfreeze all objects in the permanent generation.\n"
                 "get_freeze_count() -- Return the number of objects in the permanent generation.\n"
             ),
             m_size=0,
             m_methods=addressof(GcMethods),
             m_slots=addressof(gcmodule_slots)
         );
}

import from c {
    def PyInit_gc -> ptr[PyObject] {
        return PyModuleDef_Init(ptr[PyModuleDef](addressof(gcmodule)));
    }
}

impl as_gc(op: ptr[PyObject]) -> ptr[PyGC_Head] {
    return ptr[PyGC_Head](ptr[u8](op) - PyGC_Head_SIZE);
}

impl from_gc(g: ptr[PyGC_Head]) -> ptr[PyObject] {
    return ptr[PyObject](ptr[u8](g) + PyGC_Head_SIZE);
}

impl gc_addr(g: ptr[PyGC_Head]) -> u64 {
    return u64.wrap(int(g));
}

impl gc_at(bits: u64) -> ptr[PyGC_Head] {
    return ptr[PyGC_Head](i64.wrap(bits));
}

impl gc_next(g: ptr[PyGC_Head]) -> ptr[PyGC_Head] {
    return gc_at(g.view(1)[0]._gc_next);
}

impl gc_prev(g: ptr[PyGC_Head]) -> ptr[PyGC_Head] {
    return gc_at(g.view(1)[0]._gc_prev & ~PREV_FLAGS);
}

impl gc_set_next(g: ptr[PyGC_Head], nxt: ptr[PyGC_Head]) {
    g.view(1)[0]._gc_next = gc_addr(nxt);
}

impl gc_set_prev(g: ptr[PyGC_Head], prv: ptr[PyGC_Head]) {
    g.view(1)[0]._gc_prev = (g.view(1)[0]._gc_prev & PREV_FLAGS) | gc_addr(prv);
}

impl gc_is_collecting(g: ptr[PyGC_Head]) -> bool {
    return (g.view(1)[0]._gc_prev & PREV_MASK_COLLECTING) != 0;
}

impl gc_clear_collecting(g: ptr[PyGC_Head]) {
    g.view(1)[0]._gc_prev = g.view(1)[0]._gc_prev & ~PREV_MASK_COLLECTING;
}

impl gc_get_refs(g: ptr[PyGC_Head]) -> i64 {
    return i64.wrap(g.view(1)[0]._gc_prev >> PREV_SHIFT);
}

impl gc_set_refs(g: ptr[PyGC_Head], refs: i64) {
    g.view(1)[0]._gc_prev = (g.view(1)[0]._gc_prev & PREV_FLAGS)
        | wrapping_shl(u64.wrap(refs), PREV_SHIFT);
}

impl gc_reset_refs(g: ptr[PyGC_Head], refs: i64) {
    g.view(1)[0]._gc_prev = (g.view(1)[0]._gc_prev & PREV_MASK_FINALIZED)
        | PREV_MASK_COLLECTING
        | wrapping_shl(u64.wrap(refs), PREV_SHIFT);
}

impl gc_decref(g: ptr[PyGC_Head]) {
    g.view(1)[0]._gc_prev = wrapping_sub(g.view(1)[0]._gc_prev, PREV_REFS_ONE);
}

impl gc_state_of(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_GC;
}

impl tstate_gc_state(tstate: ptr[PyThreadState]) -> ptr[u8] {
    interp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
    return interp + PyInterpreterState_GC;
}

impl get_gc_state -> ptr[u8] {
    return current_interp() + PyInterpreterState_GC;
}

impl gen_at(gcstate: ptr[u8], n: i32) -> ptr[gc_generation] {
    return ptr[gc_generation](gcstate + _gc_runtime_state_GENERATIONS) + i64(n);
}

impl gen_head(gcstate: ptr[u8], n: i32) -> ptr[PyGC_Head] {
    return ptr[PyGC_Head](gen_at(gcstate, n));
}

impl permanent_head(gcstate: ptr[u8]) -> ptr[PyGC_Head] {
    return ptr[PyGC_Head](gcstate + _gc_runtime_state_PERMANENT_GENERATION);
}

impl stats_at(gcstate: ptr[u8], n: i32) -> ptr[gc_generation_stats] {
    return ptr[gc_generation_stats](gcstate + _gc_runtime_state_GENERATION_STATS)
        + i64(n);
}

impl gc_enabled_slot(gcstate: ptr[u8]) -> ptr[i32] {
    return ptr[i32](gcstate + _gc_runtime_state_ENABLED);
}

impl gc_debug(gcstate: ptr[u8]) -> i32 {
    return ptr[i32](gcstate + _gc_runtime_state_DEBUG).view(1)[0];
}

impl gc_garbage_slot(gcstate: ptr[u8]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](gcstate + _gc_runtime_state_GARBAGE);
}

impl gc_callbacks_slot(gcstate: ptr[u8]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](gcstate + _gc_runtime_state_CALLBACKS);
}

impl call_traverse(traverse: int, op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    slot = ptr[GcTraverseCall](__thread_local("jac_gc_call_traverse"));
    slot.view(1)[0].call = traverse;
    return slot.view(1)[0].call(op, visitor, arg);
}

impl call_visit(visitor: ptr, op: ptr[PyObject], arg: ptr) -> i32 {
    if not op {
        return 0;
    }
    slot = ptr[GcVisitCall](__thread_local("jac_gc_call_visit"));
    slot.view(1)[0].call = int(visitor);
    return slot.view(1)[0].call(op, arg);
}

impl gc_list_init(lst: ptr[PyGC_Head]) {
    lst.view(1)[0]._gc_prev = gc_addr(lst);
    lst.view(1)[0]._gc_next = gc_addr(lst);
}

impl gc_list_is_empty(lst: ptr[PyGC_Head]) -> bool {
    return lst.view(1)[0]._gc_next == gc_addr(lst);
}

impl gc_list_append(node_: ptr[PyGC_Head], lst: ptr[PyGC_Head]) {
    last = gc_at(lst.view(1)[0]._gc_prev);

    gc_set_prev(node_, last);
    gc_set_next(last, node_);

    gc_set_next(node_, lst);
    lst.view(1)[0]._gc_prev = gc_addr(node_);
}

impl gc_list_remove(node_: ptr[PyGC_Head]) {
    prv = gc_prev(node_);
    nxt = gc_next(node_);
    gc_set_next(prv, nxt);
    gc_set_prev(nxt, prv);

    node_.view(1)[0]._gc_next = u64(0);
}

impl gc_list_move(node_: ptr[PyGC_Head], lst: ptr[PyGC_Head]) {
    from_prev = gc_prev(node_);
    from_next = gc_next(node_);
    gc_set_next(from_prev, from_next);
    gc_set_prev(from_next, from_prev);

    to_prev = gc_at(lst.view(1)[0]._gc_prev);
    gc_set_prev(node_, to_prev);
    gc_set_next(to_prev, node_);
    lst.view(1)[0]._gc_prev = gc_addr(node_);
    gc_set_next(node_, lst);
}

impl gc_list_merge(from_: ptr[PyGC_Head], to: ptr[PyGC_Head]) {
    if not gc_list_is_empty(from_) {
        to_tail = gc_prev(to);
        from_head = gc_next(from_);
        from_tail = gc_prev(from_);
        gc_set_next(to_tail, from_head);
        gc_set_prev(from_head, to_tail);
        gc_set_next(from_tail, to);
        gc_set_prev(to, from_tail);
    }
    gc_list_init(from_);
}

impl gc_list_size(lst: ptr[PyGC_Head]) -> i64 {
    n: i64 = 0;
    gc = gc_next(lst);
    while gc != lst {
        n += 1;
        gc = gc_next(gc);
    }
    return n;
}

impl gc_list_clear_collecting(collectable: ptr[PyGC_Head]) {
    gc = gc_next(collectable);
    while gc != collectable {
        gc_clear_collecting(gc);
        gc = gc_next(gc);
    }
}

impl append_objects(py_list: ptr[PyObject], gc_list: ptr[PyGC_Head]) -> i32 {
    gc = gc_next(gc_list);
    while gc != gc_list {
        op = from_gc(gc);
        if op != py_list {
            if PyList_Append(py_list, op) != 0 {
                return -1;
            }
        }
        gc = gc_next(gc);
    }
    return 0;
}

impl update_refs(containers: ptr[PyGC_Head]) {
    gc = gc_next(containers);
    while gc != containers {
        nxt = gc_next(gc);
        op = from_gc(gc);
        if object_is_immortal(op) {
            object_gc_untrack(op);
        } else {
            gc_reset_refs(gc, object_refcount(op));
        }
        gc = nxt;
    }
}

impl visit_decref(op: ptr[PyObject], parent: ptr) -> i32 {
    if object_is_gc(op) {
        gc = as_gc(op);
        prev = gc.view(1)[0]._gc_prev;
        if (prev & PREV_MASK_COLLECTING) != 0 {
            gc.view(1)[0]._gc_prev = wrapping_sub(prev, PREV_REFS_ONE);
        }
    }
    return 0;
}

impl visit_stackref(bits: u64, visitor: ptr, arg: ptr) -> i32 {
    if (bits & STACKREF_TAG_REFCNT) != 0 and int(visitor) == int(ptr(visit_decref)) {
        return 0;
    }
    return call_visit(
        visitor, ptr[PyObject](i64.wrap(bits & ~STACKREF_TAG_REFCNT)), arg
    );
}

impl subtract_refs(containers: ptr[PyGC_Head]) {
    visitor = ptr(visit_decref);
    gc = gc_next(containers);
    while gc != containers {
        op = from_gc(gc);
        call_traverse(
            int(object_type(op).view(1)[0].tp_traverse), op, visitor, ptr(op)
        );
        gc = gc_next(gc);
    }
}

impl visit_reachable(op: ptr[PyObject], arg: ptr) -> i32 {
    if not object_is_gc(op) {
        return 0;
    }
    gc = as_gc(op);
    prevbits = gc.view(1)[0]._gc_prev;

    if (prevbits & PREV_MASK_COLLECTING) == 0 {
        return 0;
    }
    nextbits = gc.view(1)[0]._gc_next;
    if (nextbits & NEXT_MASK_UNREACHABLE) != 0 {
        prv = gc_at(prevbits & ~PREV_FLAGS);
        nxt = gc_at(nextbits & ~NEXT_MASK_UNREACHABLE);

        prv.view(1)[0]._gc_next = nextbits;
        gc_set_prev(nxt, prv);
        gc_list_append(gc, ptr[PyGC_Head](arg));
        gc_set_refs(gc, 1);
    } elif (prevbits >> PREV_SHIFT) == 0 {
        gc_set_refs(gc, 1);
    }

    return 0;
}

impl move_unreachable(young: ptr[PyGC_Head], unreachable: ptr[PyGC_Head]) {
    visitor = ptr(visit_reachable);

    prev = young;
    gc = gc_next(young);

    while gc != young {
        if (gc.view(1)[0]._gc_prev >> PREV_SHIFT) != 0 {
            op = from_gc(gc);
            call_traverse(
                int(object_type(op).view(1)[0].tp_traverse), op, visitor, ptr(young)
            );

            gc_set_prev(gc, prev);

            gc_clear_collecting(gc);
            prev = gc;
        } else {
            prev.view(1)[0]._gc_next = gc.view(1)[0]._gc_next;
            last = gc_prev(unreachable);
            last.view(1)[0]._gc_next = NEXT_MASK_UNREACHABLE | gc_addr(gc);
            gc_set_prev(gc, last);
            gc.view(1)[0]._gc_next = NEXT_MASK_UNREACHABLE | gc_addr(unreachable);
            unreachable.view(1)[0]._gc_prev = gc_addr(gc);
        }
        gc = gc_at(prev.view(1)[0]._gc_next);
    }

    young.view(1)[0]._gc_prev = gc_addr(prev);

    unreachable.view(1)[0]._gc_next = unreachable.view(1)[0]._gc_next
        & ~NEXT_MASK_UNREACHABLE;
}

impl untrack_tuples(head: ptr[PyGC_Head]) {
    gc = gc_next(head);
    while gc != head {
        op = from_gc(gc);
        nxt = gc_next(gc);
        if object_type(op) == addressof(PyTuple_Type) {
            _PyTuple_MaybeUntrack(op);
        }
        gc = nxt;
    }
}

impl has_legacy_finalizer(op: ptr[PyObject]) -> bool {
    return int(object_type(op).view(1)[0].tp_del) != 0;
}

impl move_legacy_finalizers(unreachable: ptr[PyGC_Head], finalizers: ptr[PyGC_Head]) {
    gc = gc_next(unreachable);
    while gc != unreachable {
        op = from_gc(gc);
        gc.view(1)[0]._gc_next = gc.view(1)[0]._gc_next & ~NEXT_MASK_UNREACHABLE;
        nxt = gc_next(gc);
        if has_legacy_finalizer(op) {
            gc_clear_collecting(gc);
            gc_list_move(gc, finalizers);
        }
        gc = nxt;
    }
}

impl clear_unreachable_mask(unreachable: ptr[PyGC_Head]) {
    gc = gc_next(unreachable);
    while gc != unreachable {
        gc.view(1)[0]._gc_next = gc.view(1)[0]._gc_next & ~NEXT_MASK_UNREACHABLE;
        gc = gc_next(gc);
    }
}

impl visit_move(op: ptr[PyObject], arg: ptr) -> i32 {
    if object_is_gc(op) {
        gc = as_gc(op);
        if gc_is_collecting(gc) {
            gc_list_move(gc, ptr[PyGC_Head](arg));
            gc_clear_collecting(gc);
        }
    }
    return 0;
}

impl move_legacy_finalizer_reachable(finalizers: ptr[PyGC_Head]) {
    visitor = ptr(visit_move);
    gc = gc_next(finalizers);
    while gc != finalizers {
        op = from_gc(gc);
        call_traverse(
            int(object_type(op).view(1)[0].tp_traverse), op, visitor, ptr(finalizers)
        );
        gc = gc_next(gc);
    }
}

impl is_weakref(op: ptr[PyObject]) -> bool {
    tp = object_type(op);
    return object_type_check(op, addressof(_PyWeakref_RefType))
        or tp == addressof(_PyWeakref_ProxyType)
        or tp == addressof(_PyWeakref_CallableProxyType);
}

impl handle_weakrefs(
    unreachable: ptr[PyGC_Head], old: ptr[PyGC_Head], allow_callbacks: bool
) -> i32 {
    num_freed: i32 = 0;
    slots: own GcStack = GcStack();

    wrcb_to_call = ptr[PyGC_Head](jacpy_stack_address(&mut slots));
    if allow_callbacks {
        gc_list_init(wrcb_to_call);
    }
    gc = gc_next(unreachable);
    while gc != unreachable {
        op = from_gc(gc);
        nxt = gc_next(gc);
        if is_weakref(op) {
            _PyWeakref_ClearRef(ptr[PyWeakReference](op));
        }
        offset = object_type(op).view(1)[0].tp_weaklistoffset;
        if offset != 0 {
            wrlist = ptr[ptr[PyWeakReference]](ptr[u8](op) + offset);
            wr = wrlist.view(1)[0];
            while wr {
                _PyWeakref_ClearRef(wr);
                if allow_callbacks
                    and wr.view(1)[0].wr_callback
                    and not gc_is_collecting(as_gc(ptr[PyObject](wr))) {
                    object_incref(ptr[PyObject](wr));
                    gc_list_move(as_gc(ptr[PyObject](wr)), wrcb_to_call);
                }
                wr = wrlist.view(1)[0];
            }
        }
        gc = nxt;
    }
    if not allow_callbacks {
        return 0;
    }

    while not gc_list_is_empty(wrcb_to_call) {
        gc = gc_at(wrcb_to_call.view(1)[0]._gc_next);
        op = from_gc(gc);
        callback = ptr[PyWeakReference](op).view(1)[0].wr_callback;

        temp = PyObject_CallOneArg(callback, op);
        if not temp {
            PyErr_FormatUnraisable(
                "Exception ignored on calling weakref callback %R", callback
            );
        } else {
            object_decref(temp);
        }

        object_decref(op);
        if wrcb_to_call.view(1)[0]._gc_next == gc_addr(gc) {
            gc_list_move(gc, old);
        } else {
            num_freed += 1;
        }
    }
    return num_freed;
}

impl debug_cycle(msg: ptr[u8], op: ptr[PyObject]) {
    PySys_FormatStderr("gc: %s <%s %p>\n", msg, object_type(op).view(1)[0].tp_name, op);
}

impl handle_legacy_finalizers(
    tstate: ptr[PyThreadState],
    gcstate: ptr[u8],
    finalizers: ptr[PyGC_Head],
    old: ptr[PyGC_Head]
) {
    gc = gc_next(finalizers);
    while gc != finalizers {
        op = from_gc(gc);
        if (gc_debug(gcstate) & _PyGC_DEBUG_SAVEALL) != 0 or has_legacy_finalizer(op) {
            if PyList_Append(gc_garbage_slot(gcstate).view(1)[0], op) < 0 {
                PyErr_Clear();
                break;
            }
        }
        gc = gc_next(gc);
    }
    gc_list_merge(finalizers, old);
}

impl finalize_garbage(tstate: ptr[PyThreadState], collectable: ptr[PyGC_Head]) {
    slots: own GcStack = GcStack();
    seen = ptr[PyGC_Head](jacpy_stack_address(&mut slots));
    gc_list_init(seen);
    while not gc_list_is_empty(collectable) {
        gc = gc_next(collectable);
        op = from_gc(gc);
        gc_list_move(gc, seen);
        if not gc_finalized(op) {
            tp = object_type(op);
            if int(tp.view(1)[0].tp_finalize) != 0 {
                gc_set_finalized(op);
                object_incref(op);
                tp.view(1)[0].tp_finalize(op);
                object_decref(op);
            }
        }
    }
    gc_list_merge(seen, collectable);
}

impl delete_garbage(
    tstate: ptr[PyThreadState],
    gcstate: ptr[u8],
    collectable: ptr[PyGC_Head],
    old: ptr[PyGC_Head]
) {
    while not gc_list_is_empty(collectable) {
        gc = gc_next(collectable);
        op = from_gc(gc);

        if (gc_debug(gcstate) & _PyGC_DEBUG_SAVEALL) != 0 {
            if PyList_Append(gc_garbage_slot(gcstate).view(1)[0], op) < 0 {
                PyErr_Clear();
            }
        } else {
            tp = object_type(op);
            if int(tp.view(1)[0].tp_clear) != 0 {
                object_incref(op);
                tp.view(1)[0].tp_clear(op);
                if exception_raised(tstate) {
                    PyErr_FormatUnraisable(
                        "Exception ignored in tp_clear of %s",
                        object_type(op).view(1)[0].tp_name
                    );
                }
                object_decref(op);
            }
        }
        if gc_next(collectable) == gc {
            gc_clear_collecting(gc);
            gc_list_move(gc, old);
        }
    }
}

impl show_stats_each_generations(gcstate: ptr[u8]) {
    PySys_FormatStderr(
        "gc: objects in each generation: %zd %zd %zd\ngc: objects in permanent generation: %zd\n",
        gc_list_size(gen_head(gcstate, i32(0))),
        gc_list_size(gen_head(gcstate, i32(1))),
        gc_list_size(gen_head(gcstate, i32(2))),
        gc_list_size(permanent_head(gcstate))
    );
}

impl deduce_unreachable(base: ptr[PyGC_Head], unreachable: ptr[PyGC_Head]) {
    update_refs(base);
    subtract_refs(base);
    gc_list_init(unreachable);

    move_unreachable(base, unreachable);
}

impl handle_resurrected_objects(
    unreachable: ptr[PyGC_Head],
    still_unreachable: ptr[PyGC_Head],
    old_generation: ptr[PyGC_Head]
) {
    gc_list_clear_collecting(unreachable);
    resurrected = unreachable;
    deduce_unreachable(resurrected, still_unreachable);
    clear_unreachable_mask(still_unreachable);

    gc_list_merge(resurrected, old_generation);
}

impl invoke_gc_callback(
    tstate: ptr[PyThreadState],
    phase: ptr[u8],
    generation: i32,
    collected: i64,
    uncollectable: i64
) {
    gcstate = tstate_gc_state(tstate);
    callbacks_slot = gc_callbacks_slot(gcstate);
    if not callbacks_slot.view(1)[0] {
        return;
    }
    info = NULL;
    if object_size(callbacks_slot.view(1)[0]) != 0 {
        info = Py_BuildValue(
            "{sisnsn}",
            ptr[u8]("generation"),
            generation,
            ptr[u8]("collected"),
            collected,
            ptr[u8]("uncollectable"),
            uncollectable
        );
        if not info {
            PyErr_FormatUnraisable("Exception ignored on invoking gc callbacks");
            return;
        }
    }
    phase_obj = PyUnicode_FromString(phase);
    if not phase_obj {
        object_xdecref(info);
        PyErr_FormatUnraisable("Exception ignored on invoking gc callbacks");
        return;
    }
    slots: own GcStack = GcStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = phase_obj;
    stack.view(2)[1] = info;
    i: i64 = 0;
    while i < object_size(callbacks_slot.view(1)[0]) {
        cb = (ptr[PyListObject](callbacks_slot.view(1)[0]).view(1)[0].ob_item + i).view(
            1
        )[0];

        object_incref(cb);
        r = PyObject_Vectorcall(cb, stack, u64(2), NULL);
        if not r {
            PyErr_FormatUnraisable(
                "Exception ignored while calling GC callback %R", cb
            );
        } else {
            object_decref(r);
        }
        object_decref(cb);
        i += 1;
    }
    object_decref(phase_obj);
    object_xdecref(info);
}

impl gc_select_generation(gcstate: ptr[u8]) -> i32 {
    i: i32 = NUM_GENERATIONS - 1;
    while i >= 0 {
        gen = gen_at(gcstate, i);
        if gen.view(1)[0].count > gen.view(1)[0].threshold {
            pending = ptr[i64](gcstate + _gc_runtime_state_LONG_LIVED_PENDING).view(1)[
                0
            ];
            total = ptr[i64](gcstate + _gc_runtime_state_LONG_LIVED_TOTAL).view(1)[0];
            if not (i == NUM_GENERATIONS - 1 and pending < total // 4) {
                return i;
            }
        }
        i -= 1;
    }
    return -1;
}

impl gc_collect_main(tstate: ptr[PyThreadState], generation: i32, reason: i32) -> i64 {
    m: i64 = 0;
    n: i64 = 0;
    t1: i64 = 0;
    gen: i32 = generation;
    gcstate = tstate_gc_state(tstate);

    collecting = int(gcstate + _gc_runtime_state_COLLECTING);
    if __atomic_cas_i32(collecting, i32(0), i32(1), 5) != i32(0) {
        return 0;
    }
    if gen == GENERATION_AUTO {
        gen = gc_select_generation(gcstate);
        if gen < 0 {
            __atomic_store_i32(collecting, i32(0), 5);
            return 0;
        }
    }
    if reason != _Py_GC_REASON_SHUTDOWN {
        invoke_gc_callback(tstate, ptr[u8]("start"), gen, 0, 0);
    }
    if (gc_debug(gcstate) & _PyGC_DEBUG_STATS) != 0 {
        PySys_WriteStderr("gc: collecting generation %d...\n", gen);
        show_stats_each_generations(gcstate);

        PyTime_PerfCounterRaw(&mut t1);
    }

    if gen + 1 < NUM_GENERATIONS {
        older = gen_at(gcstate, gen + 1);
        older.view(1)[0].count = older.view(1)[0].count + 1;
    }
    i: i32 = 0;
    while i <= gen {
        gen_at(gcstate, i).view(1)[0].count = 0;
        i += 1;
    }

    i = 0;
    while i < gen {
        gc_list_merge(gen_head(gcstate, i), gen_head(gcstate, gen));
        i += 1;
    }

    young = gen_head(gcstate, gen);
    old = young;
    if gen < NUM_GENERATIONS - 1 {
        old = gen_head(gcstate, gen + 1);
    }
    slots: own GcStack = GcStack();
    heads = jacpy_stack_address(&mut slots);

    unreachable = ptr[PyGC_Head](heads);

    finalizers = ptr[PyGC_Head](heads + 16);
    final_unreachable = ptr[PyGC_Head](heads + 32);
    deduce_unreachable(young, unreachable);
    untrack_tuples(young);

    if young != old {
        if gen == NUM_GENERATIONS - 2 {
            pending = ptr[i64](gcstate + _gc_runtime_state_LONG_LIVED_PENDING);
            pending.view(1)[0] = pending.view(1)[0] + gc_list_size(young);
        }
        gc_list_merge(young, old);
    } else {
        ptr[i64](gcstate + _gc_runtime_state_LONG_LIVED_PENDING).view(1)[0] = 0;
        ptr[i64](gcstate + _gc_runtime_state_LONG_LIVED_TOTAL).view(1)[0] = gc_list_size(
            young
        );
    }

    gc_list_init(finalizers);

    move_legacy_finalizers(unreachable, finalizers);

    move_legacy_finalizer_reachable(finalizers);

    if (gc_debug(gcstate) & _PyGC_DEBUG_COLLECTABLE) != 0 {
        gc = gc_next(unreachable);
        while gc != unreachable {
            debug_cycle(ptr[u8]("collectable"), from_gc(gc));
            gc = gc_next(gc);
        }
    }

    m += i64(handle_weakrefs(unreachable, old, True));

    finalize_garbage(tstate, unreachable);

    handle_resurrected_objects(unreachable, final_unreachable, old);

    handle_weakrefs(final_unreachable, ptr[PyGC_Head](), False);

    m += gc_list_size(final_unreachable);
    delete_garbage(tstate, gcstate, final_unreachable, old);

    gc = gc_next(finalizers);
    while gc != finalizers {
        n += 1;
        if (gc_debug(gcstate) & _PyGC_DEBUG_UNCOLLECTABLE) != 0 {
            debug_cycle(ptr[u8]("uncollectable"), from_gc(gc));
        }
        gc = gc_next(gc);
    }
    if (gc_debug(gcstate) & _PyGC_DEBUG_STATS) != 0 {
        t2: i64 = 0;
        PyTime_PerfCounterRaw(&mut t2);
        d = PyTime_AsSecondsDouble(t2 - t1);
        PySys_WriteStderr(
            "gc: done, %zd unreachable, %zd uncollectable, %.4fs elapsed\n", n + m, n, d
        );
    }

    handle_legacy_finalizers(tstate, gcstate, finalizers, old);

    if gen == NUM_GENERATIONS - 1 {
        _PyGC_ClearAllFreeLists(
            ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0]
        );
    }
    if exception_raised(tstate) {
        if reason == _Py_GC_REASON_SHUTDOWN {
            PyErr_Clear();
        } else {
            PyErr_FormatUnraisable("Exception ignored in garbage collection");
        }
    }

    stats = stats_at(gcstate, gen);
    stats.view(1)[0].collections = stats.view(1)[0].collections + 1;
    stats.view(1)[0].collected = stats.view(1)[0].collected + m;
    stats.view(1)[0].uncollectable = stats.view(1)[0].uncollectable + n;
    if reason != _Py_GC_REASON_SHUTDOWN {
        invoke_gc_callback(tstate, ptr[u8]("stop"), gen, m, n);
    }
    __atomic_store_i32(collecting, i32(0), 5);
    return n + m;
}

impl referrersvisit(obj_: ptr[PyObject], arg: ptr) -> i32 {
    objs = ptr[PyObject](arg);
    i: i64 = 0;
    while i < object_size(objs) {
        if tuple_get_item(objs, i) == obj_ {
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl gc_referrers_for(
    objs: ptr[PyObject], lst: ptr[PyGC_Head], resultlist: ptr[PyObject]
) -> i32 {
    visitor = ptr(referrersvisit);
    gc = gc_next(lst);
    while gc != lst {
        obj_ = from_gc(gc);
        traverse = int(object_type(obj_).view(1)[0].tp_traverse);
        if obj_ != objs and obj_ != resultlist {
            if call_traverse(traverse, obj_, visitor, ptr(objs)) != 0 {
                if PyList_Append(resultlist, obj_) < 0 {
                    return 0;
                }
            }
        }
        gc = gc_next(gc);
    }

    return 1;
}

impl visit_generation(callback: ptr, arg: ptr, gen: ptr[gc_generation]) -> i32 {
    gc_list = ptr[PyGC_Head](gen);
    slot = ptr[GcVisitCall](__thread_local("jac_gc_call_visit"));
    gc = gc_next(gc_list);
    while gc != gc_list {
        op = from_gc(gc);
        object_incref(op);
        slot.view(1)[0].call = int(callback);
        res = slot.view(1)[0].call(op, arg);
        object_decref(op);
        if res == 0 {
            return -1;
        }
        gc = gc_next(gc);
    }
    return 0;
}

impl finalize_unlink_gc_head(gc: ptr[PyGC_Head]) {
    prv = gc_prev(gc);
    nxt = gc_next(gc);
    gc_set_next(prv, nxt);
    gc_set_prev(nxt, prv);
}

impl gc_alloc(tp: ptr[PyTypeObject], basicsize: u64, presize: u64) -> ptr[PyObject] {
    if basicsize > PY_SSIZE_T_MAX_SIZE - presize {
        return PyErr_NoMemory();
    }
    size = presize + basicsize;
    mem = ptr[u8](PyObject_Malloc(size));
    if not mem {
        return PyErr_NoMemory();
    }
    words = ptr[ptr[PyObject]](mem).view(2);
    words[0] = NULL;
    words[1] = NULL;
    op = ptr[PyObject](mem + i64.wrap(presize));
    _PyObject_GC_Link(op);
    return op;
}

impl gc_enable_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    PyGC_Enable();
    return object_new_ref(Py_None);
}

impl gc_enable(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_enable_impl(module);
}

impl gc_disable_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    PyGC_Disable();
    return object_new_ref(Py_None);
}

impl gc_disable(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_disable_impl(module);
}

impl gc_isenabled_impl(module: ptr[PyObject]) -> i32 {
    return PyGC_IsEnabled();
}

impl gc_isenabled(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return_value = gc_isenabled_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl unpack_generation(
    args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject], fname: ptr[u8]
) -> tuple[i32, ptr[PyObject]] {
    nkwargs: i64 = 0;
    if kwnames {
        nkwargs = object_size(kwnames);
    }
    if nkwargs == 0 and nargs <= 1 {
        if nargs == 1 {
            return (i32(0), args.view(1)[0]);
        }
        return (i32(0), NULL);
    }
    given = nargs + nkwargs;
    if given > 1 {
        if nargs == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes at most %d %sargument%s (%zd given)",
                fname,
                ptr[u8]("()"),
                i32(1),
                ptr[u8]("keyword "),
                ptr[u8](""),
                given
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s%s takes at most %d %sargument%s (%zd given)",
                fname,
                ptr[u8]("()"),
                i32(1),
                ptr[u8](""),
                ptr[u8](""),
                given
            );
        }
        return (i32(-1), NULL);
    }

    kwstack = args + nargs;
    i: i64 = 0;
    while i < nkwargs {
        if _PyUnicode_EqualToASCIIString(
            tuple_get_item(kwnames, i), ptr[u8]("generation")
        )
            != 0 {
            return (i32(0), (kwstack + i).view(1)[0]);
        }
        i += 1;
    }
    unexpected_keyword_arg(kwnames, fname);
    return (i32(-1), NULL);
}

impl unexpected_keyword_arg(kwnames: ptr[PyObject], fname: ptr[u8]) {
    j: i64 = 0;
    while j < object_size(kwnames) {
        keyword = tuple_get_item(kwnames, j);
        j += 1;
        if not type_has_feature(object_type(keyword), Py_TPFLAGS_UNICODE_SUBCLASS) {
            PyErr_SetString(PyExc_TypeError, "keywords must be strings");
            return;
        }
        if _PyUnicode_EqualToASCIIString(keyword, ptr[u8]("generation")) == 0 {
            kwlist = Py_BuildValue("[s]", ptr[u8]("generation"));
            if not kwlist {
                return;
            }
            suggestion_keyword = _Py_CalculateSuggestions(kwlist, keyword);
            object_decref(kwlist);
            if suggestion_keyword {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s got an unexpected keyword argument '%S'. Did you mean '%S'?",
                    fname,
                    ptr[u8]("()"),
                    keyword,
                    suggestion_keyword
                );
                object_decref(suggestion_keyword);
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.200s%s got an unexpected keyword argument '%S'",
                    fname,
                    ptr[u8]("()"),
                    keyword
                );
            }
            return;
        }
    }

    PyErr_Format(
        PyExc_TypeError, "invalid keyword argument for %.200s%s", fname, ptr[u8]("()")
    );
}

impl gc_collect_impl(module: ptr[PyObject], generation: i32) -> i64 {
    tstate = current_tstate();
    if generation < 0 or generation >= NUM_GENERATIONS {
        PyErr_SetString(PyExc_ValueError, "invalid generation");
        return -1;
    }
    return _PyGC_Collect(tstate, generation, _Py_GC_REASON_MANUAL);
}

impl gc_collect(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    generation: i32 = NUM_GENERATIONS - 1;
    (status, arg) = unpack_generation(args, nargs, kwnames, ptr[u8]("collect"));
    if status < 0 {
        return NULL;
    }
    if arg {
        generation = PyLong_AsInt(arg);
        if generation == -1 and PyErr_Occurred() {
            return NULL;
        }
    }
    return_value = gc_collect_impl(module, generation);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(return_value);
}

impl gc_set_debug_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject] {
    ptr[i32](get_gc_state() + _gc_runtime_state_DEBUG).view(1)[0] = flags;
    return object_new_ref(Py_None);
}

impl gc_set_debug(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    flags = PyLong_AsInt(arg);
    if flags == -1 and PyErr_Occurred() {
        return NULL;
    }
    return gc_set_debug_impl(module, flags);
}

impl gc_get_debug_impl(module: ptr[PyObject]) -> i32 {
    return gc_debug(get_gc_state());
}

impl gc_get_debug(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return_value = gc_get_debug_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromLong(i64(return_value));
}

impl gc_set_threshold_impl(
    module: ptr[PyObject],
    threshold0: i32,
    group_right_1: i32,
    threshold1: i32,
    group_right_2: i32,
    threshold2: i32
) -> ptr[PyObject] {
    gcstate = get_gc_state();
    gen_at(gcstate, i32(0)).view(1)[0].threshold = threshold0;
    if group_right_1 != 0 {
        gen_at(gcstate, i32(1)).view(1)[0].threshold = threshold1;
    }
    if group_right_2 != 0 {
        gen_at(gcstate, i32(2)).view(1)[0].threshold = threshold2;
    }
    return object_new_ref(Py_None);
}

impl convert_int_arg(arg: ptr[PyObject]) -> tuple[i32, i32] {
    ival = PyLong_AsLong(arg);
    if ival == -1 and PyErr_Occurred() {
        return (i32(-1), i32(0));
    }
    if ival > INT_MAX_LONG {
        PyErr_SetString(PyExc_OverflowError, "signed integer is greater than maximum");
        return (i32(-1), i32(0));
    }
    if ival < INT_MIN_LONG {
        PyErr_SetString(PyExc_OverflowError, "signed integer is less than minimum");
        return (i32(-1), i32(0));
    }
    return (i32(0), i32(ival));
}

impl gc_set_threshold(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    threshold0: i32 = 0;
    group_right_1: i32 = 0;
    threshold1: i32 = 0;
    group_right_2: i32 = 0;
    threshold2: i32 = 0;
    nargs = object_size(args);
    if nargs >= 1 and nargs <= 3 {
        (status0, value0) = convert_int_arg(tuple_get_item(args, 0));
        if status0 < 0 {
            return NULL;
        }
        threshold0 = value0;
        if nargs >= 2 {
            (status1, value1) = convert_int_arg(tuple_get_item(args, 1));
            if status1 < 0 {
                return NULL;
            }
            threshold1 = value1;
            group_right_1 = 1;
        }
        if nargs == 3 {
            (status2, value2) = convert_int_arg(tuple_get_item(args, 2));
            if status2 < 0 {
                return NULL;
            }
            threshold2 = value2;
            group_right_2 = 1;
        }
    } else {
        PyErr_SetString(PyExc_TypeError, "gc.set_threshold requires 1 to 3 arguments");
        return NULL;
    }
    return gc_set_threshold_impl(
        module, threshold0, group_right_1, threshold1, group_right_2, threshold2
    );
}

impl gc_get_threshold_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    gcstate = get_gc_state();
    return Py_BuildValue(
        "(iii)",
        gen_at(gcstate, i32(0)).view(1)[0].threshold,
        gen_at(gcstate, i32(1)).view(1)[0].threshold,
        gen_at(gcstate, i32(2)).view(1)[0].threshold
    );
}

impl gc_get_threshold(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_get_threshold_impl(module);
}

impl gc_get_count_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    gcstate = get_gc_state();
    return Py_BuildValue(
        "(iii)",
        gen_at(gcstate, i32(0)).view(1)[0].count,
        gen_at(gcstate, i32(1)).view(1)[0].count,
        gen_at(gcstate, i32(2)).view(1)[0].count
    );
}

impl gc_get_count(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_get_count_impl(module);
}

impl gc_get_referrers_impl(
    module: ptr[PyObject], objs: ptr[PyObject]
) -> ptr[PyObject] {
    if PySys_Audit("gc.get_referrers", "(O)", objs) < 0 {
        return NULL;
    }
    return _PyGC_GetReferrers(current_interp(), objs);
}

impl gc_get_referrers(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    objs = _PyTuple_FromArray(args, nargs);
    if not objs {
        return NULL;
    }
    return_value = gc_get_referrers_impl(module, objs);
    object_decref(objs);
    return return_value;
}

impl referentsvisit(obj_: ptr[PyObject], arg: ptr) -> i32 {
    if PyList_Append(ptr[PyObject](arg), obj_) < 0 {
        return 1;
    }
    return 0;
}

impl append_referrents(result: ptr[PyObject], args: ptr[PyObject]) -> i32 {
    visitor = ptr(referentsvisit);
    i: i64 = 0;
    while i < object_size(args) {
        obj_ = tuple_get_item(args, i);
        if object_is_gc(obj_) {
            traverse = int(object_type(obj_).view(1)[0].tp_traverse);
            if traverse != 0 {
                if call_traverse(traverse, obj_, visitor, ptr(result)) != 0 {
                    return -1;
                }
            }
        }
        i += 1;
    }
    return 0;
}

impl gc_get_referents_impl(
    module: ptr[PyObject], objs: ptr[PyObject]
) -> ptr[PyObject] {
    if PySys_Audit("gc.get_referents", "(O)", objs) < 0 {
        return NULL;
    }
    result = PyList_New(0);
    if not result {
        return NULL;
    }

    err = append_referrents(result, objs);
    if err < 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl gc_get_referents(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    objs = _PyTuple_FromArray(args, nargs);
    if not objs {
        return NULL;
    }
    return_value = gc_get_referents_impl(module, objs);
    object_decref(objs);
    return return_value;
}

impl gc_get_objects_impl(module: ptr[PyObject], generation: i64) -> ptr[PyObject] {
    if PySys_Audit("gc.get_objects", "n", generation) < 0 {
        return NULL;
    }
    if generation >= i64(NUM_GENERATIONS) {
        return PyErr_Format(
            PyExc_ValueError,
            "generation parameter must be less than the number of available generations (%i)",
            NUM_GENERATIONS
        );
    }
    if generation < -1 {
        PyErr_SetString(PyExc_ValueError, "generation parameter cannot be negative");
        return NULL;
    }
    return _PyGC_GetObjects(current_interp(), i32(generation));
}

impl gc_get_objects(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    generation: i64 = -1;
    (status, arg) = unpack_generation(args, nargs, kwnames, ptr[u8]("get_objects"));
    if status < 0 {
        return NULL;
    }
    if arg {
        if arg != Py_None {
            if PyIndex_Check(arg) != 0 {
                limit = PyNumber_AsSsize_t(arg, PyExc_OverflowError);
                if limit == -1 and PyErr_Occurred() {
                    return NULL;
                }
                generation = limit;
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    "argument should be integer or None, not '%.200s'",
                    object_type(arg).view(1)[0].tp_name
                );
                return NULL;
            }
        }
    }
    return gc_get_objects_impl(module, generation);
}

impl gc_get_stats_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    slots: own GcStack = GcStack();
    snapshot = ptr[gc_generation_stats](jacpy_stack_address(&mut slots));
    gcstate = get_gc_state();
    i: i32 = 0;
    while i < NUM_GENERATIONS {
        src = stats_at(gcstate, i);
        dst = snapshot + i64(i);
        dst.view(1)[0].collections = src.view(1)[0].collections;
        dst.view(1)[0].collected = src.view(1)[0].collected;
        dst.view(1)[0].uncollectable = src.view(1)[0].uncollectable;
        i += 1;
    }
    result = PyList_New(0);
    if not result {
        return NULL;
    }
    i = 0;
    while i < NUM_GENERATIONS {
        st = snapshot + i64(i);
        dct = Py_BuildValue(
            "{snsnsn}",
            ptr[u8]("collections"),
            st.view(1)[0].collections,
            ptr[u8]("collected"),
            st.view(1)[0].collected,
            ptr[u8]("uncollectable"),
            st.view(1)[0].uncollectable
        );
        if not dct {
            object_decref(result);
            return NULL;
        }
        if PyList_Append(result, dct) != 0 {
            object_decref(dct);
            object_decref(result);
            return NULL;
        }
        object_decref(dct);
        i += 1;
    }
    return result;
}

impl gc_get_stats(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_get_stats_impl(module);
}

impl gc_is_tracked_impl(module: ptr[PyObject], obj_: ptr[PyObject]) -> i32 {
    return PyObject_GC_IsTracked(obj_);
}

impl gc_is_tracked(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return_value = gc_is_tracked_impl(module, obj_);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl gc_is_finalized_impl(module: ptr[PyObject], obj_: ptr[PyObject]) -> i32 {
    return PyObject_GC_IsFinalized(obj_);
}

impl gc_is_finalized(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return_value = gc_is_finalized_impl(module, obj_);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl gc_freeze_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    _PyGC_Freeze(current_interp());
    return object_new_ref(Py_None);
}

impl gc_freeze(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_freeze_impl(module);
}

impl gc_unfreeze_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    _PyGC_Unfreeze(current_interp());
    return object_new_ref(Py_None);
}

impl gc_unfreeze(module: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return gc_unfreeze_impl(module);
}

impl gc_get_freeze_count_impl(module: ptr[PyObject]) -> i64 {
    return _PyGC_GetFreezeCount(current_interp());
}

impl gc_get_freeze_count(
    module: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return_value = gc_get_freeze_count_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(return_value);
}

impl gcmodule_exec(module: ptr[PyObject]) -> i32 {
    gcstate = get_gc_state();
    if PyModule_AddObjectRef(module, "garbage", gc_garbage_slot(gcstate).view(1)[0])
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(module, "callbacks", gc_callbacks_slot(gcstate).view(1)[0])
        < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(module, "DEBUG_STATS", i64(_PyGC_DEBUG_STATS)) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(
        module, "DEBUG_COLLECTABLE", i64(_PyGC_DEBUG_COLLECTABLE)
    )
        < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(
        module, "DEBUG_UNCOLLECTABLE", i64(_PyGC_DEBUG_UNCOLLECTABLE)
    )
        < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(module, "DEBUG_SAVEALL", i64(_PyGC_DEBUG_SAVEALL)) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(module, "DEBUG_LEAK", i64(_PyGC_DEBUG_LEAK)) < 0 {
        return -1;
    }
    return 0;
}
