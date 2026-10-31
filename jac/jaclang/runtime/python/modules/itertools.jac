import from c {
    obj itertools_state {
        has accumulate_type: ptr[PyTypeObject],
            batched_type: ptr[PyTypeObject],
            chain_type: ptr[PyTypeObject],
            combinations_type: ptr[PyTypeObject],
            compress_type: ptr[PyTypeObject],
            count_type: ptr[PyTypeObject],
            cwr_type: ptr[PyTypeObject],
            cycle_type: ptr[PyTypeObject],
            dropwhile_type: ptr[PyTypeObject],
            filterfalse_type: ptr[PyTypeObject],
            groupby_type: ptr[PyTypeObject],
            _grouper_type: ptr[PyTypeObject],
            islice_type: ptr[PyTypeObject],
            pairwise_type: ptr[PyTypeObject],
            permutations_type: ptr[PyTypeObject],
            product_type: ptr[PyTypeObject],
            repeat_type: ptr[PyTypeObject],
            starmap_type: ptr[PyTypeObject],
            takewhile_type: ptr[PyTypeObject],
            tee_type: ptr[PyTypeObject],
            teedataobject_type: ptr[PyTypeObject],
            ziplongest_type: ptr[PyTypeObject];
    }  obj batchedobject {
        has ob_base: _object,
            it: ptr[PyObject],
            batch_size: i64,
            strict: bool;
    }  obj pairwiseobject {
        has ob_base: _object,
            it: ptr[PyObject],
            old: ptr[PyObject],
            result: ptr[PyObject];
    }  obj groupbyobject {
        has ob_base: _object,
            it: ptr[PyObject],
            keyfunc: ptr[PyObject],
            tgtkey: ptr[PyObject],
            currkey: ptr[PyObject],
            currvalue: ptr[PyObject],
            currgrouper: ptr[PyObject],
            state: ptr[itertools_state];
    }  obj _grouperobject {
        has ob_base: _object,
            parent: ptr[PyObject],
            tgtkey: ptr[PyObject];
    }  obj teedataobject {
        has ob_base: _object,
            it: ptr[PyObject],
            numread: i32,
            running: i32,
            nextlink: ptr[PyObject];
    }  obj teeobject {
        has ob_base: _object,
            dataobj: ptr[PyObject],
            index: i32,
            weakreflist: ptr[PyObject],
            state: ptr[itertools_state];
    }  obj cycleobject {
        has ob_base: _object,
            it: ptr[PyObject],
            saved: ptr[PyObject],
            index: i64,
            firstpass: i32;
    }  obj dropwhileobject {
        has ob_base: _object,
            func: ptr[PyObject],
            it: ptr[PyObject],
            start: i64;
    }  obj takewhileobject {
        has ob_base: _object,
            func: ptr[PyObject],
            it: ptr[PyObject],
            stop: i64;
    }  obj isliceobject {
        has ob_base: _object,
            it: ptr[PyObject],
            next: i64,
            stop: i64,
            step: i64,
            cnt: i64;
    }  obj starmapobject {
        has ob_base: _object,
            func: ptr[PyObject],
            it: ptr[PyObject];
    }  obj chainobject {
        has ob_base: _object,
            source: ptr[PyObject],
            active: ptr[PyObject];
    }  obj productobject {
        has ob_base: _object,
            pools: ptr[PyObject],
            indices: ptr[i64],
            result: ptr[PyObject],
            stopped: i32;
    }  obj combinationsobject {
        has ob_base: _object,
            pool: ptr[PyObject],
            indices: ptr[i64],
            result: ptr[PyObject],
            r: i64,
            stopped: i32;
    }  obj cwrobject {
        has ob_base: _object,
            pool: ptr[PyObject],
            indices: ptr[i64],
            result: ptr[PyObject],
            r: i64,
            stopped: i32;
    }  obj permutationsobject {
        has ob_base: _object,
            pool: ptr[PyObject],
            indices: ptr[i64],
            cycles: ptr[i64],
            result: ptr[PyObject],
            r: i64,
            stopped: i32;
    }  obj accumulateobject {
        has ob_base: _object,
            total: ptr[PyObject],
            it: ptr[PyObject],
            binop: ptr[PyObject],
            initial: ptr[PyObject],
            state: ptr[itertools_state];
    }  obj compressobject {
        has ob_base: _object,
            data: ptr[PyObject],
            selectors: ptr[PyObject];
    }  obj filterfalseobject {
        has ob_base: _object,
            func: ptr[PyObject],
            it: ptr[PyObject];
    }  obj countobject {
        has ob_base: _object,
            cnt: i64,
            long_cnt: ptr[PyObject],
            long_step: ptr[PyObject];
    }  obj repeatobject {
        has ob_base: _object,
            element: ptr[PyObject],
            cnt: i64;
    }  obj ziplongestobject {
        has ob_base: _object,
            tuplesize: i64,
            numactive: i64,
            ittuple: ptr[PyObject],
            result: ptr[PyObject],
            fillvalue: ptr[PyObject];
    }  obj ItertoolsModuleDef {
        has m_base: PyModuleDef_Base,
            m_name: ptr[u8],
            m_doc: ptr[u8],
            m_size: i64,
            m_methods: ptr[PyMethodDef],
            m_slots: ptr[PyModuleDef_Slot],
            m_traverse: ptr,
            m_clear: ptr,
            m_free: ptr;
    }
}

glob ITERTOOLS_STATE_SIZE: Final[i64] = 176,
     ITERTOOLS_STATE_TYPES: Final[i64] = 22,
     BATCHED_SIZE: Final[i64] = 40,
     PAIRWISE_SIZE: Final[i64] = 40,
     GROUPBY_SIZE: Final[i64] = 72,
     GROUPER_SIZE: Final[i64] = 32,
     TEEDATA_SIZE: Final[i64] = 496,
     TEEDATA_VALUES: Final[i64] = 40,
     TEE_SIZE: Final[i64] = 48,
     TEE_WEAKREFLIST: Final[i64] = 32,
     CYCLE_SIZE: Final[i64] = 48,
     DROPWHILE_SIZE: Final[i64] = 40,
     TAKEWHILE_SIZE: Final[i64] = 40,
     ISLICE_SIZE: Final[i64] = 56,
     STARMAP_SIZE: Final[i64] = 32,
     CHAIN_SIZE: Final[i64] = 32,
     PRODUCT_SIZE: Final[i64] = 48,
     COMBINATIONS_SIZE: Final[i64] = 56,
     CWR_SIZE: Final[i64] = 56,
     PERMUTATIONS_SIZE: Final[i64] = 64,
     ACCUMULATE_SIZE: Final[i64] = 56,
     COMPRESS_SIZE: Final[i64] = 32,
     FILTERFALSE_SIZE: Final[i64] = 32,
     COUNT_SIZE: Final[i64] = 40,
     REPEAT_SIZE: Final[i64] = 32,
     ZIPLONGEST_SIZE: Final[i64] = 56,
     LINKCELLS: Final[i32] = 57,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807;

def get_module_state(mod: ptr[PyObject]) -> ptr[itertools_state];

def get_module_state_by_cls(cls: ptr[PyTypeObject]) -> ptr[itertools_state];

def find_state_by_type(tp: ptr[PyTypeObject]) -> ptr[itertools_state];

def gc_untrack(op: ptr[PyObject]);

def long_check(op: ptr[PyObject]) -> bool;

def pymem_new_ssize(n: i64) -> ptr[i64];

def batched_of(op: ptr[PyObject]) -> ptr[batchedobject];

def batched_new_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], n: i64, strict: bool
) -> ptr[PyObject];

def batched_dealloc(op: ptr[PyObject]);

def batched_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def batched_stop(bo: ptr[batchedobject], result: ptr[PyObject]);

def batched_next(op: ptr[PyObject]) -> ptr[PyObject];

def pairwise_of(op: ptr[PyObject]) -> ptr[pairwiseobject];

def pairwise_new_impl(type: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject];

def pairwise_dealloc(op: ptr[PyObject]);

def pairwise_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def pairwise_next(op: ptr[PyObject]) -> ptr[PyObject];

def groupby_of(op: ptr[PyObject]) -> ptr[groupbyobject];

def itertools_groupby_impl(
    type: ptr[PyObject], it: ptr[PyObject], keyfunc: ptr[PyObject]
) -> ptr[PyObject];

def groupby_dealloc(op: ptr[PyObject]);

def groupby_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def groupby_step(gbo: ptr[groupbyobject]) -> i32;

def groupby_next(op: ptr[PyObject]) -> ptr[PyObject];

def _grouper_of(op: ptr[PyObject]) -> ptr[_grouperobject];

def subclass_clinic_state_by_cls_groupby_type(
    value: ptr[PyObject], fname: str, label: str
);

def itertools__grouper_impl(
    type: ptr[PyObject], parent: ptr[PyObject], tgtkey: ptr[PyObject]
) -> ptr[PyObject];

def _grouper_create(
    parent: ptr[groupbyobject], tgtkey: ptr[PyObject]
) -> ptr[PyObject];

def _grouper_dealloc(op: ptr[PyObject]);

def _grouper_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def _grouper_next(op: ptr[PyObject]) -> ptr[PyObject];

def teedata_of(op: ptr[PyObject]) -> ptr[teedataobject];

def teedata_values(op: ptr[PyObject]) -> ptr[ptr[PyObject]];

def tee_of(op: ptr[PyObject]) -> ptr[teeobject];

def teedataobject_newinternal(
    state: ptr[itertools_state], it: ptr[PyObject]
) -> ptr[PyObject];

def teedataobject_jumplink(
    state: ptr[itertools_state], tdo: ptr[PyObject]
) -> ptr[PyObject];

def teedataobject_getitem(tdo: ptr[PyObject], i: i32) -> ptr[PyObject];

def teedataobject_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def teedataobject_safe_decref(obj_: ptr[PyObject]);

def teedataobject_clear(op: ptr[PyObject]) -> i32;

def teedataobject_dealloc(op: ptr[PyObject]);

def itertools_teedataobject_impl(
    type: ptr[PyObject], it: ptr[PyObject], values: ptr[PyObject], next: ptr[PyObject]
) -> ptr[PyObject];

def tee_next(op: ptr[PyObject]) -> ptr[PyObject];

def tee_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def tee_copy_impl(to: ptr[PyObject]) -> ptr[PyObject];

def tee_copy(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def tee_fromiterable(
    state: ptr[itertools_state], iterable: ptr[PyObject]
) -> ptr[PyObject];

def itertools__tee_impl(type: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject];

def tee_clear(op: ptr[PyObject]) -> i32;

def tee_dealloc(op: ptr[PyObject]);

def itertools_tee_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], n: i64
) -> ptr[PyObject];

def cycle_of(op: ptr[PyObject]) -> ptr[cycleobject];

def itertools_cycle_impl(
    type: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject];

def cycle_dealloc(op: ptr[PyObject]);

def cycle_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def cycle_next(op: ptr[PyObject]) -> ptr[PyObject];

def dropwhile_of(op: ptr[PyObject]) -> ptr[dropwhileobject];

def itertools_dropwhile_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject];

def dropwhile_dealloc(op: ptr[PyObject]);

def dropwhile_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def dropwhile_next(op: ptr[PyObject]) -> ptr[PyObject];

def takewhile_of(op: ptr[PyObject]) -> ptr[takewhileobject];

def itertools_takewhile_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject];

def takewhile_dealloc(op: ptr[PyObject]);

def takewhile_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def takewhile_next(op: ptr[PyObject]) -> ptr[PyObject];

def islice_of(op: ptr[PyObject]) -> ptr[isliceobject];

def islice_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def islice_dealloc(op: ptr[PyObject]);

def islice_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def islice_empty(lz: ptr[isliceobject]) -> ptr[PyObject];

def islice_next(op: ptr[PyObject]) -> ptr[PyObject];

def starmap_of(op: ptr[PyObject]) -> ptr[starmapobject];

def itertools_starmap_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject];

def starmap_dealloc(op: ptr[PyObject]);

def starmap_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def starmap_next(op: ptr[PyObject]) -> ptr[PyObject];

def chain_of(op: ptr[PyObject]) -> ptr[chainobject];

def chain_new_internal(
    type: ptr[PyTypeObject], source: ptr[PyObject]
) -> ptr[PyObject];

def chain_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def itertools_chain_from_iterable_impl(
    type: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def chain_dealloc(op: ptr[PyObject]);

def chain_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def chain_next(op: ptr[PyObject]) -> ptr[PyObject];

def product_of(op: ptr[PyObject]) -> ptr[productobject];

def product_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def product_dealloc(op: ptr[PyObject]);

def product_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def product_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def product_next(op: ptr[PyObject]) -> ptr[PyObject];

def combinations_of(op: ptr[PyObject]) -> ptr[combinationsobject];

def itertools_combinations_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], r: i64
) -> ptr[PyObject];

def combinations_dealloc(op: ptr[PyObject]);

def combinations_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def combinations_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def combinations_next(op: ptr[PyObject]) -> ptr[PyObject];

def cwr_of(op: ptr[PyObject]) -> ptr[cwrobject];

def itertools_combinations_with_replacement_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], r: i64
) -> ptr[PyObject];

def cwr_dealloc(op: ptr[PyObject]);

def cwr_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def cwr_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def cwr_next(op: ptr[PyObject]) -> ptr[PyObject];

def permutations_of(op: ptr[PyObject]) -> ptr[permutationsobject];

def itertools_permutations_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], robj: ptr[PyObject]
) -> ptr[PyObject];

def permutations_dealloc(op: ptr[PyObject]);

def permutations_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def permutations_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def permutations_next(op: ptr[PyObject]) -> ptr[PyObject];

def accumulate_of(op: ptr[PyObject]) -> ptr[accumulateobject];

def itertools_accumulate_impl(
    type: ptr[PyObject],
    iterable: ptr[PyObject],
    binop: ptr[PyObject],
    initial: ptr[PyObject]
) -> ptr[PyObject];

def accumulate_dealloc(op: ptr[PyObject]);

def accumulate_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def accumulate_next(op: ptr[PyObject]) -> ptr[PyObject];

def compress_of(op: ptr[PyObject]) -> ptr[compressobject];

def itertools_compress_impl(
    type: ptr[PyObject], seq1: ptr[PyObject], seq2: ptr[PyObject]
) -> ptr[PyObject];

def compress_dealloc(op: ptr[PyObject]);

def compress_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def compress_next(op: ptr[PyObject]) -> ptr[PyObject];

def filterfalse_of(op: ptr[PyObject]) -> ptr[filterfalseobject];

def itertools_filterfalse_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject];

def filterfalse_dealloc(op: ptr[PyObject]);

def filterfalse_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def filterfalse_next(op: ptr[PyObject]) -> ptr[PyObject];

def count_of(op: ptr[PyObject]) -> ptr[countobject];

def itertools_count_impl(
    type: ptr[PyObject], long_cnt: ptr[PyObject], long_step: ptr[PyObject]
) -> ptr[PyObject];

def count_dealloc(op: ptr[PyObject]);

def count_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def count_nextlong(lz: ptr[countobject]) -> ptr[PyObject];

def count_next(op: ptr[PyObject]) -> ptr[PyObject];

def count_repr(op: ptr[PyObject]) -> ptr[PyObject];

def repeat_of(op: ptr[PyObject]) -> ptr[repeatobject];

def repeat_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def repeat_dealloc(op: ptr[PyObject]);

def repeat_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def repeat_next(op: ptr[PyObject]) -> ptr[PyObject];

def repeat_repr(op: ptr[PyObject]) -> ptr[PyObject];

def repeat_len(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def ziplongest_of(op: ptr[PyObject]) -> ptr[ziplongestobject];

def zip_longest_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def zip_longest_dealloc(op: ptr[PyObject]);

def zip_longest_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def zip_longest_next(op: ptr[PyObject]) -> ptr[PyObject];

def itertoolsmodule_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def itertoolsmodule_clear(mod: ptr[PyObject]) -> i32;

def itertoolsmodule_free(mod: ptr);

def add_type(
    module: ptr[PyObject], slot: ptr[ptr[PyTypeObject]], spec: ptr[PyType_Spec]
) -> i32;

def itertoolsmodule_exec(mod: ptr[PyObject]) -> i32;

import from c {
    glob product_kwlist: list[ptr[u8]] = [ptr[u8]("repeat"), ptr[u8]()],
         repeat_kwargs: list[ptr[u8]] = [
             ptr[u8]("object"),
             ptr[u8]("times"),
             ptr[u8]()
         ],
         tee_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__copy__"),
                 ml_meth=ptr(tee_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Returns an independent iterator.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         tee_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=TEE_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         product_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(product_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Returns size in memory, in bytes.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         combinations_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(combinations_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Returns size in memory, in bytes.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         cwr_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(cwr_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Returns size in memory, in bytes.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         permuations_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(permutations_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Returns size in memory, in bytes.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         repeat_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(repeat_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         batched_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(batched_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "batched(iterable, n, *, strict=False)\n--\n\nBatch data into tuples of length n. The last batch may be shorter than n.\n\nLoops over the input iterable and accumulates data into tuples\nup to size n.  The input is consumed lazily, just enough to\nfill a batch.  The result is yielded as soon as a batch is full\nor when the input iterable is exhausted.\n\n    >>> for batch in batched('ABCDEFG', 3):\n    ...     print(batch)\n    ...\n    ('A', 'B', 'C')\n    ('D', 'E', 'F')\n    ('G',)\n\nIf \"strict\" is True, raises a ValueError if the final batch is shorter\nthan n."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(batched_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(batched_next)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(batched_new_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pairwise_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(pairwise_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "pairwise(iterable, /)\n--\n\nReturn an iterator of overlapping pairs taken from the input iterator.\n\n    s -> (s0,s1), (s1,s2), (s2, s3), ..."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(pairwise_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(pairwise_next)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(pairwise_new_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         groupby_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(groupby_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "groupby(iterable, key=None)\n--\n\nmake an iterator that returns consecutive keys and groups from the iterable\n\n  iterable\n    Elements to divide into groups according to the key function.\n  key\n    A function for computing the group category for each element.\n    If the key function is not specified or is None, the element itself\n    is used for grouping."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(groupby_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(groupby_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_groupby_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         _grouper_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(_grouper_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(_grouper_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(_grouper_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools__grouper_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         teedataobject_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(teedataobject_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "teedataobject(iterable, values, next, /)\n--\n\nData container common to multiple tee objects."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(teedataobject_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(teedataobject_clear)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_teedataobject_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         tee_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(tee_dealloc)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "_tee(iterable, /)\n--\n\nIterator wrapped to make it copyable."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(tee_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(tee_clear)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(tee_next)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(tee_methods))),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(tee_members))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools__tee_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         cycle_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(cycle_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "cycle(iterable, /)\n--\n\nReturn elements from the iterable until it is exhausted. Then repeat the sequence indefinitely."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(cycle_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(cycle_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_cycle_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         dropwhile_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(dropwhile_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "dropwhile(predicate, iterable, /)\n--\n\nDrop items from the iterable while predicate(item) is true.\n\nAfterwards, return every element until the iterable is exhausted."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(dropwhile_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(dropwhile_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_dropwhile_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         takewhile_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(takewhile_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "takewhile(predicate, iterable, /)\n--\n\nReturn successive entries from an iterable as long as the predicate evaluates to true for each entry."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(takewhile_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(takewhile_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_takewhile_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         islice_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(islice_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "islice(iterable, stop) --> islice object\nislice(iterable, start, stop[, step]) --> islice object\n\nReturn an iterator whose next() method returns selected values from an\niterable.  If start is specified, will skip all preceding elements;\notherwise, start defaults to zero.  Step defaults to one.  If\nspecified as another value, step determines how many values are\nskipped between successive calls.  Works like a slice() on a list\nbut returns an iterator."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(islice_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(islice_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(islice_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         starmap_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(starmap_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "starmap(function, iterable, /)\n--\n\nReturn an iterator whose values are returned from the function evaluated with an argument tuple taken from the given sequence."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(starmap_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(starmap_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_starmap_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         chain_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(chain_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "chain(*iterables)\n--\n\nReturn a chain object whose .__next__() method returns elements from the\nfirst iterable until it is exhausted, then elements from the next\niterable, until all of the iterables are exhausted."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(chain_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(chain_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(chain_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         product_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(product_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "product(*iterables, repeat=1)\n--\n\nCartesian product of input iterables.  Equivalent to nested for-loops.\n\nFor example, product(A, B) returns the same as:  ((x,y) for x in A for y in B).\nThe leftmost iterators are in the outermost for-loop, so the output tuples\ncycle in a manner similar to an odometer (with the rightmost element changing\non every iteration).\n\nTo compute the product of an iterable with itself, specify the number\nof repetitions with the optional repeat keyword argument. For example,\nproduct(A, repeat=4) means the same as product(A, A, A, A).\n\nproduct('ab', range(3)) --> ('a',0) ('a',1) ('a',2) ('b',0) ('b',1) ('b',2)\nproduct((0,1), (0,1), (0,1)) --> (0,0,0) (0,0,1) (0,1,0) (0,1,1) (1,0,0) ..."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(product_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(product_next)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(product_methods))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(product_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         combinations_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(combinations_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "combinations(iterable, r)\n--\n\nReturn successive r-length combinations of elements in the iterable.\n\ncombinations(range(4), 3) --> (0,1,2), (0,1,3), (0,2,3), (1,2,3)"
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(combinations_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(combinations_next)),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(combinations_methods))
             ),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_combinations_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         cwr_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(cwr_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "combinations_with_replacement(iterable, r)\n--\n\nReturn successive r-length combinations of elements in the iterable allowing individual elements to have successive repeats.\n\ncombinations_with_replacement('ABC', 2) --> ('A','A'), ('A','B'), ('A','C'), ('B','B'), ('B','C'), ('C','C')"
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(cwr_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(cwr_next)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(cwr_methods))),
             PyType_Slot(
                 slot=Py_tp_new, pfunc=ptr(itertools_combinations_with_replacement_new)
             ),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         permutations_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(permutations_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "permutations(iterable, r=None)\n--\n\nReturn successive r-length permutations of elements in the iterable.\n\npermutations(range(3), 2) --> (0,1), (0,2), (1,0), (1,2), (2,0), (2,1)"
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(permutations_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(permutations_next)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(permuations_methods))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_permutations_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         accumulate_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(accumulate_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "accumulate(iterable, func=None, *, initial=None)\n--\n\nReturn series of accumulated sums (or other binary function results)."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(accumulate_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(accumulate_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_accumulate_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         compress_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(compress_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "compress(data, selectors)\n--\n\nReturn data elements corresponding to true selector elements.\n\nForms a shorter iterator from selected data elements using the selectors\nto choose the data elements."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(compress_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(compress_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_compress_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         filterfalse_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(filterfalse_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "filterfalse(function, iterable, /)\n--\n\nReturn those items of iterable for which function(item) is false.\n\nIf function is None, return the items that are false."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(filterfalse_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(filterfalse_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_filterfalse_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         count_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(count_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(count_repr)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "count(start=0, step=1)\n--\n\nReturn a count object whose .__next__() method returns consecutive values.\n\nEquivalent to:\n    def count(firstval=0, step=1):\n        x = firstval\n        while 1:\n            yield x\n            x += step"
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(count_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(count_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(itertools_count_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         repeat_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(repeat_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(repeat_repr)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "repeat(object [,times]) -> create an iterator which returns the object\nfor the specified number of times.  If not specified, returns the object\nendlessly."
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(repeat_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(repeat_next)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(repeat_methods))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(repeat_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         ziplongest_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(zip_longest_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "zip_longest(*iterables, fillvalue=None)\n--\n\nReturn a zip_longest object whose .__next__() method returns a tuple where\nthe i-th element comes from the i-th iterable argument.  The .__next__()\nmethod continues until the longest iterable in the argument sequence\nis exhausted and then it raises StopIteration.  When the shorter iterables\nare exhausted, the fillvalue is substituted in their place.  The fillvalue\ndefaults to None or can be specified by a keyword argument.\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(zip_longest_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(zip_longest_next)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(zip_longest_new)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         itertoolsmodule_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(itertoolsmodule_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob batched_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.batched"),
             basicsize=i32(BATCHED_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(batched_slots)
         ),
         pairwise_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.pairwise"),
             basicsize=i32(PAIRWISE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pairwise_slots)
         ),
         groupby_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.groupby"),
             basicsize=i32(GROUPBY_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(groupby_slots)
         ),
         _grouper_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools._grouper"),
             basicsize=i32(GROUPER_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(_grouper_slots)
         ),
         teedataobject_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools._tee_dataobject"),
             basicsize=i32(TEEDATA_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(teedataobject_slots)
         ),
         tee_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools._tee"),
             basicsize=i32(TEE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(tee_slots)
         ),
         cycle_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.cycle"),
             basicsize=i32(CYCLE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(cycle_slots)
         ),
         dropwhile_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.dropwhile"),
             basicsize=i32(DROPWHILE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(dropwhile_slots)
         ),
         takewhile_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.takewhile"),
             basicsize=i32(TAKEWHILE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(takewhile_slots)
         ),
         islice_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.islice"),
             basicsize=i32(ISLICE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(islice_slots)
         ),
         starmap_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.starmap"),
             basicsize=i32(STARMAP_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(starmap_slots)
         ),
         chain_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.chain"),
             basicsize=i32(CHAIN_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(chain_slots)
         ),
         product_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.product"),
             basicsize=i32(PRODUCT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(product_slots)
         ),
         combinations_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.combinations"),
             basicsize=i32(COMBINATIONS_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(combinations_slots)
         ),
         cwr_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.combinations_with_replacement"),
             basicsize=i32(CWR_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(cwr_slots)
         ),
         permutations_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.permutations"),
             basicsize=i32(PERMUTATIONS_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(permutations_slots)
         ),
         accumulate_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.accumulate"),
             basicsize=i32(ACCUMULATE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(accumulate_slots)
         ),
         compress_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.compress"),
             basicsize=i32(COMPRESS_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(compress_slots)
         ),
         filterfalse_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.filterfalse"),
             basicsize=i32(FILTERFALSE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(filterfalse_slots)
         ),
         count_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.count"),
             basicsize=i32(COUNT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(count_slots)
         ),
         repeat_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.repeat"),
             basicsize=i32(REPEAT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(repeat_slots)
         ),
         ziplongest_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("itertools.zip_longest"),
             basicsize=i32(ZIPLONGEST_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(ziplongest_slots)
         ),
         itertoolsmodule: ItertoolsModuleDef = ItertoolsModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("itertools"),
             m_doc=ptr[u8](
                 "Functional tools for creating and using iterators.\n\nInfinite iterators:\ncount(start=0, step=1) --> start, start+step, start+2*step, ...\ncycle(p) --> p0, p1, ... plast, p0, p1, ...\nrepeat(elem [,n]) --> elem, elem, elem, ... endlessly or up to n times\n\nIterators terminating on the shortest input sequence:\naccumulate(p[, func]) --> p0, p0+p1, p0+p1+p2\nbatched(p, n) --> [p0, p1, ..., p_n-1], [p_n, p_n+1, ..., p_2n-1], ...\nchain(p, q, ...) --> p0, p1, ... plast, q0, q1, ...\nchain.from_iterable([p, q, ...]) --> p0, p1, ... plast, q0, q1, ...\ncompress(data, selectors) --> (d[0] if s[0]), (d[1] if s[1]), ...\ndropwhile(predicate, seq) --> seq[n], seq[n+1], starting when predicate fails\ngroupby(iterable[, keyfunc]) --> sub-iterators grouped by value of keyfunc(v)\nfilterfalse(predicate, seq) --> elements of seq where predicate(elem) is False\nislice(seq, [start,] stop [, step]) --> elements from\n       seq[start:stop:step]\npairwise(s) --> (s[0],s[1]), (s[1],s[2]), (s[2], s[3]), ...\nstarmap(fun, seq) --> fun(*seq[0]), fun(*seq[1]), ...\ntee(it, n=2) --> (it1, it2 , ... itn) splits one iterator into n\ntakewhile(predicate, seq) --> seq[0], seq[1], until predicate fails\nzip_longest(p, q, ...) --> (p[0], q[0]), (p[1], q[1]), ...\n\nCombinatoric generators:\nproduct(p, q, ... [repeat=1]) --> cartesian product\npermutations(p[, r])\ncombinations(p, r)\ncombinations_with_replacement(p, r)\n"
             ),
             m_size=ITERTOOLS_STATE_SIZE,
             m_methods=ptr[PyMethodDef](),
             m_slots=addressof(itertoolsmodule_slots),
             m_traverse=ptr(itertoolsmodule_traverse),
             m_clear=ptr(itertoolsmodule_clear),
             m_free=ptr(itertoolsmodule_free)
         );
}

glob _grouper_token = ClassToken(),
     _tee_token = ClassToken(),
     teedataobject_token = ClassToken(),
     cycle_token = ClassToken(),
     dropwhile_token = ClassToken(),
     filterfalse_token = ClassToken(),
     pairwise_token = ClassToken(),
     starmap_token = ClassToken(),
     takewhile_token = ClassToken();

impl get_module_state(mod: ptr[PyObject]) -> ptr[itertools_state] {
    return ptr[itertools_state](ptr[PyModuleObject](mod).view(1)[0].md_state);
}

impl get_module_state_by_cls(cls: ptr[PyTypeObject]) -> ptr[itertools_state] {
    return get_module_state(ptr[PyHeapTypeObject](cls).view(1)[0].ht_module);
}

impl find_state_by_type(tp: ptr[PyTypeObject]) -> ptr[itertools_state] {
    mod = PyType_GetModuleByDef(tp, ptr[PyModuleDef](addressof(itertoolsmodule)));
    return get_module_state(mod);
}

impl gc_untrack(op: ptr[PyObject]) {
    if object_gc_is_tracked(op) {
        object_gc_untrack(op);
    }
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl pymem_new_ssize(n: i64) -> ptr[i64] {
    if n > PY_SSIZE_T_MAX // 8 {
        return ptr[i64]();
    }
    return ptr[i64](PyMem_Malloc(u64(n * 8)));
}

impl batched_of(op: ptr[PyObject]) -> ptr[batchedobject] {
    return ptr[batchedobject](op);
}

impl batched_new_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], n: i64, strict: bool
) -> ptr[PyObject] {
    if n < 1 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("n must be at least one"));
        return NULL;
    }
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    bo = batched_of(op);
    bo.view(1)[0].batch_size = n;
    bo.view(1)[0].it = it;
    bo.view(1)[0].strict = strict;
    return op;
}

impl batched_dealloc(op: ptr[PyObject]) {
    bo = batched_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(bo.view(1)[0].it);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl batched_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(batched_of(op).view(1)[0].it, visitor, arg);
}

impl batched_stop(bo: ptr[batchedobject], result: ptr[PyObject]) {
    bo.view(1)[0].batch_size = -1;
    it = bo.view(1)[0].it;
    if it {
        bo.view(1)[0].it = NULL;
        object_decref(it);
    }
    object_decref(result);
}

impl batched_next(op: ptr[PyObject]) -> ptr[PyObject] {
    bo = batched_of(op);
    n: i64 = bo.view(1)[0].batch_size;
    it = bo.view(1)[0].it;
    if n < 0 {
        return NULL;
    }
    result = PyTuple_New(n);
    if not result {
        return NULL;
    }
    itp = object_type(it);
    items = tuple_items(result);
    i: i64 = 0;
    while i < n {
        item = itp.view(1)[0].tp_iternext(it);
        if not item {
            break;
        }
        (items + i).view(1)[0] = item;
        i += 1;
    }
    if i == n {
        return result;
    }
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
            batched_stop(bo, result);
            return NULL;
        }
        PyErr_Clear();
    }
    if i == 0 {
        batched_stop(bo, result);
        return NULL;
    }
    if bo.view(1)[0].strict {
        batched_stop(bo, result);
        PyErr_SetString(PyExc_ValueError, ptr[u8]("batched(): incomplete batch"));
        return NULL;
    }
    resized: ptr[PyObject] = result;
    _PyTuple_Resize(&mut resized, i);
    return resized;
}

impl pairwise_of(op: ptr[PyObject]) -> ptr[pairwiseobject] {
    return ptr[pairwiseobject](op);
}

impl pairwise_new_impl(type: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    po = pairwise_of(op);
    po.view(1)[0].it = it;
    po.view(1)[0].old = NULL;
    po.view(1)[0].result = PyTuple_Pack(2, Py_None, Py_None);
    if not po.view(1)[0].result {
        object_decref(op);
        return NULL;
    }
    return op;
}

impl pairwise_dealloc(op: ptr[PyObject]) {
    po = pairwise_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(po.view(1)[0].it);
    object_xdecref(po.view(1)[0].old);
    object_xdecref(po.view(1)[0].result);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl pairwise_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    po = pairwise_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(po.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(po.view(1)[0].old, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(po.view(1)[0].result, visitor, arg);
}

impl pairwise_next(op: ptr[PyObject]) -> ptr[PyObject] {
    po = pairwise_of(op);
    it = po.view(1)[0].it;
    old = po.view(1)[0].old;
    if not it {
        return NULL;
    }
    if not old {
        old = object_type(it).view(1)[0].tp_iternext(it);
        prev = po.view(1)[0].old;
        po.view(1)[0].old = old;
        object_xdecref(prev);
        if not old {
            cleared = po.view(1)[0].it;
            po.view(1)[0].it = NULL;
            object_xdecref(cleared);
            return NULL;
        }
        it = po.view(1)[0].it;
        if not it {
            dropped = po.view(1)[0].old;
            po.view(1)[0].old = NULL;
            object_xdecref(dropped);
            return NULL;
        }
    }
    object_incref(old);
    new_item = object_type(it).view(1)[0].tp_iternext(it);
    if not new_item {
        cleared_it = po.view(1)[0].it;
        po.view(1)[0].it = NULL;
        object_xdecref(cleared_it);
        cleared_old = po.view(1)[0].old;
        po.view(1)[0].old = NULL;
        object_xdecref(cleared_old);
        object_decref(old);
        return NULL;
    }

    result = po.view(1)[0].result;
    if object_refcount(result) == 1 {
        object_incref(result);
        last_old = tuple_get_item(result, 0);
        last_new = tuple_get_item(result, 1);
        tuple_set_item(result, 0, object_new_ref(old));
        tuple_set_item(result, 1, object_new_ref(new_item));
        object_decref(last_old);
        object_decref(last_new);

        tuple_recycle(result);
    } else {
        result = PyTuple_New(2);
        if result {
            tuple_set_item(result, 0, object_new_ref(old));
            tuple_set_item(result, 1, object_new_ref(new_item));
        }
    }

    replaced = po.view(1)[0].old;
    po.view(1)[0].old = new_item;
    object_xdecref(replaced);
    object_decref(old);
    return result;
}

impl groupby_of(op: ptr[PyObject]) -> ptr[groupbyobject] {
    return ptr[groupbyobject](op);
}

impl itertools_groupby_impl(
    type: ptr[PyObject], it: ptr[PyObject], keyfunc: ptr[PyObject]
) -> ptr[PyObject] {
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        return NULL;
    }
    gbo = groupby_of(op);
    gbo.view(1)[0].tgtkey = NULL;
    gbo.view(1)[0].currkey = NULL;
    gbo.view(1)[0].currvalue = NULL;
    gbo.view(1)[0].keyfunc = object_new_ref(keyfunc);
    gbo.view(1)[0].it = PyObject_GetIter(it);
    if not gbo.view(1)[0].it {
        object_decref(op);
        return NULL;
    }
    gbo.view(1)[0].state = find_state_by_type(tp);
    return op;
}

impl groupby_dealloc(op: ptr[PyObject]) {
    gbo = groupby_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(gbo.view(1)[0].it);
    object_xdecref(gbo.view(1)[0].keyfunc);
    object_xdecref(gbo.view(1)[0].tgtkey);
    object_xdecref(gbo.view(1)[0].currkey);
    object_xdecref(gbo.view(1)[0].currvalue);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl groupby_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    gbo = groupby_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(gbo.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(gbo.view(1)[0].keyfunc, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(gbo.view(1)[0].tgtkey, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(gbo.view(1)[0].currkey, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(gbo.view(1)[0].currvalue, visitor, arg);
}

impl groupby_step(gbo: ptr[groupbyobject]) -> i32 {
    newvalue = PyIter_Next(gbo.view(1)[0].it);
    if not newvalue {
        return -1;
    }
    newkey: ptr[PyObject] = NULL;
    if gbo.view(1)[0].keyfunc == Py_None {
        newkey = object_new_ref(newvalue);
    } else {
        newkey = PyObject_CallOneArg(gbo.view(1)[0].keyfunc, newvalue);
        if not newkey {
            object_decref(newvalue);
            return -1;
        }
    }
    oldvalue = gbo.view(1)[0].currvalue;
    gbo.view(1)[0].currvalue = newvalue;
    oldkey = gbo.view(1)[0].currkey;
    gbo.view(1)[0].currkey = newkey;
    object_xdecref(oldkey);
    object_xdecref(oldvalue);
    return 0;
}

impl groupby_next(op: ptr[PyObject]) -> ptr[PyObject] {
    gbo = groupby_of(op);
    gbo.view(1)[0].currgrouper = NULL;

    while True {
        if gbo.view(1)[0].currkey {
            if not gbo.view(1)[0].tgtkey {
                break;
            }

            tgtkey = gbo.view(1)[0].tgtkey;
            currkey = gbo.view(1)[0].currkey;
            object_incref(tgtkey);
            object_incref(currkey);
            rcmp = PyObject_RichCompareBool(tgtkey, currkey, Py_EQ);
            object_decref(tgtkey);
            object_decref(currkey);
            if rcmp == -1 {
                return NULL;
            } elif rcmp == 0 {
                break;
            }
        }
        if groupby_step(gbo) < 0 {
            return NULL;
        }
    }
    currkey_ref = gbo.view(1)[0].currkey;
    object_incref(currkey_ref);
    oldtgt = gbo.view(1)[0].tgtkey;
    gbo.view(1)[0].tgtkey = currkey_ref;
    object_xdecref(oldtgt);

    grouper = _grouper_create(gbo, gbo.view(1)[0].tgtkey);
    if not grouper {
        return NULL;
    }
    r = PyTuple_Pack(2, gbo.view(1)[0].currkey, grouper);
    object_decref(grouper);
    return r;
}

impl _grouper_of(op: ptr[PyObject]) -> ptr[_grouperobject] {
    return ptr[_grouperobject](op);
}

impl subclass_clinic_state_by_cls_groupby_type(
    value: ptr[PyObject], fname: str, label: str
) {
    mod = PyType_GetModuleByDef(
        object_type(value), ptr[PyModuleDef](addressof(itertoolsmodule))
    );
    if not mod {
        PyErr_Clear();
        bad_argument(fname, label, "itertools.groupby", value);
    }
    if not object_type_check(value, get_module_state(mod).view(1)[0].groupby_type) {
        bad_argument(fname, label, "itertools.groupby", value);
    }
}

impl itertools__grouper_impl(
    type: ptr[PyObject], parent: ptr[PyObject], tgtkey: ptr[PyObject]
) -> ptr[PyObject] {
    return _grouper_create(groupby_of(parent), tgtkey);
}

impl _grouper_create(
    parent: ptr[groupbyobject], tgtkey: ptr[PyObject]
) -> ptr[PyObject] {
    state = parent.view(1)[0].state;
    igo = _PyObject_GC_New(ptr[PyObject](state.view(1)[0]._grouper_type));
    if not igo {
        return NULL;
    }
    _grouper_of(igo).view(1)[0].parent = object_new_ref(ptr[PyObject](parent));
    _grouper_of(igo).view(1)[0].tgtkey = object_new_ref(tgtkey);

    parent.view(1)[0].currgrouper = igo;
    object_gc_track(igo);
    return igo;
}

impl _grouper_dealloc(op: ptr[PyObject]) {
    igo = _grouper_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_decref(igo.view(1)[0].parent);
    object_decref(igo.view(1)[0].tgtkey);
    PyObject_GC_Del(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl _grouper_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    igo = _grouper_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(igo.view(1)[0].parent, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(igo.view(1)[0].tgtkey, visitor, arg);
}

impl _grouper_next(op: ptr[PyObject]) -> ptr[PyObject] {
    igo = _grouper_of(op);
    gbo = groupby_of(igo.view(1)[0].parent);
    if gbo.view(1)[0].currgrouper != op {
        return NULL;
    }
    if not gbo.view(1)[0].currvalue {
        if groupby_step(gbo) < 0 {
            return NULL;
        }
    }

    tgtkey = object_new_ref(igo.view(1)[0].tgtkey);
    currkey = object_new_ref(gbo.view(1)[0].currkey);
    rcmp = PyObject_RichCompareBool(tgtkey, currkey, Py_EQ);
    object_decref(tgtkey);
    object_decref(currkey);
    if rcmp <= 0 {
        return NULL;
    }
    r = gbo.view(1)[0].currvalue;
    gbo.view(1)[0].currvalue = NULL;
    oldkey = gbo.view(1)[0].currkey;
    gbo.view(1)[0].currkey = NULL;
    object_xdecref(oldkey);
    return r;
}

impl teedata_of(op: ptr[PyObject]) -> ptr[teedataobject] {
    return ptr[teedataobject](op);
}

impl teedata_values(op: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](op) + TEEDATA_VALUES);
}

impl tee_of(op: ptr[PyObject]) -> ptr[teeobject] {
    return ptr[teeobject](op);
}

impl teedataobject_newinternal(
    state: ptr[itertools_state], it: ptr[PyObject]
) -> ptr[PyObject] {
    op = _PyObject_GC_New(ptr[PyObject](state.view(1)[0].teedataobject_type));
    if not op {
        return NULL;
    }
    tdo = teedata_of(op);
    tdo.view(1)[0].running = 0;
    tdo.view(1)[0].numread = 0;
    tdo.view(1)[0].nextlink = NULL;
    tdo.view(1)[0].it = object_new_ref(it);
    object_gc_track(op);
    return op;
}

impl teedataobject_jumplink(
    state: ptr[itertools_state], tdo: ptr[PyObject]
) -> ptr[PyObject] {
    data = teedata_of(tdo);
    if not data.view(1)[0].nextlink {
        data.view(1)[0].nextlink = teedataobject_newinternal(state, data.view(1)[0].it);
    }
    link = data.view(1)[0].nextlink;
    if link {
        object_incref(link);
    }
    return link;
}

impl teedataobject_getitem(tdo: ptr[PyObject], i: i32) -> ptr[PyObject] {
    data = teedata_of(tdo);
    values = teedata_values(tdo);
    value: ptr[PyObject] = NULL;
    if i < data.view(1)[0].numread {
        value = (values + i64(i)).view(1)[0];
    } else {
        if data.view(1)[0].running != 0 {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("cannot re-enter the tee iterator")
            );
            return NULL;
        }
        data.view(1)[0].running = 1;
        value = PyIter_Next(data.view(1)[0].it);
        data.view(1)[0].running = 0;
        if not value {
            return NULL;
        }
        data.view(1)[0].numread = data.view(1)[0].numread + 1;
        (values + i64(i)).view(1)[0] = value;
    }
    return object_new_ref(value);
}

impl teedataobject_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    tdo = teedata_of(op);
    values = teedata_values(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(tdo.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    i: i64 = 0;
    while i < i64(tdo.view(1)[0].numread) {
        status = visit_reference((values + i).view(1)[0], visitor, arg);
        if status != 0 {
            return status;
        }
        i += 1;
    }
    return visit_reference(tdo.view(1)[0].nextlink, visitor, arg);
}

impl teedataobject_safe_decref(obj_: ptr[PyObject]) {
    cur = obj_;
    while cur and object_refcount(cur) == 1 {
        tmp = teedata_of(cur);
        nextlink = tmp.view(1)[0].nextlink;
        tmp.view(1)[0].nextlink = NULL;
        old = cur;
        cur = nextlink;
        object_decref(old);
    }
    object_xdecref(cur);
}

impl teedataobject_clear(op: ptr[PyObject]) -> i32 {
    tdo = teedata_of(op);
    values = teedata_values(op);
    it = tdo.view(1)[0].it;
    if it {
        tdo.view(1)[0].it = NULL;
        object_decref(it);
    }
    i: i64 = 0;
    while i < i64(tdo.view(1)[0].numread) {
        value = (values + i).view(1)[0];
        if value {
            (values + i).view(1)[0] = NULL;
            object_decref(value);
        }
        i += 1;
    }
    tmp = tdo.view(1)[0].nextlink;
    tdo.view(1)[0].nextlink = NULL;
    teedataobject_safe_decref(tmp);
    return 0;
}

impl teedataobject_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);
    gc_untrack(op);
    teedataobject_clear(op);
    PyObject_GC_Del(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl itertools_teedataobject_impl(
    type: ptr[PyObject], it: ptr[PyObject], values: ptr[PyObject], next: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_module_state_by_cls(ptr[PyTypeObject](type));
    tdo = teedataobject_newinternal(state, it);
    if not tdo {
        return NULL;
    }
    data = teedata_of(tdo);
    cells = teedata_values(tdo);
    len = object_size(values);
    invalid = False;
    if len > i64(LINKCELLS) {
        invalid = True;
    } else {
        items = ptr[PyListObject](values).view(1)[0].ob_item;
        i: i64 = 0;
        while i < len {
            (cells + i).view(1)[0] = object_new_ref((items + i).view(1)[0]);
            i += 1;
        }
        data.view(1)[0].numread = i32(len);
        if len == i64(LINKCELLS) {
            if next != Py_None {
                if object_type(next) != state.view(1)[0].teedataobject_type {
                    invalid = True;
                } else {
                    data.view(1)[0].nextlink = object_new_ref(next);
                }
            }
        } elif next != Py_None {
            invalid = True;
        }
    }
    if invalid {
        object_xdecref(tdo);
        PyErr_SetString(PyExc_ValueError, ptr[u8]("Invalid arguments"));
        return NULL;
    }
    return tdo;
}

impl tee_next(op: ptr[PyObject]) -> ptr[PyObject] {
    to = tee_of(op);
    if to.view(1)[0].index >= LINKCELLS {
        link = teedataobject_jumplink(to.view(1)[0].state, to.view(1)[0].dataobj);
        if not link {
            return NULL;
        }
        old = to.view(1)[0].dataobj;
        to.view(1)[0].dataobj = link;
        object_decref(old);
        to.view(1)[0].index = 0;
    }
    value = teedataobject_getitem(to.view(1)[0].dataobj, to.view(1)[0].index);
    if not value {
        return NULL;
    }
    to.view(1)[0].index = to.view(1)[0].index + 1;
    return value;
}

impl tee_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(tee_of(op).view(1)[0].dataobj, visitor, arg);
}

impl tee_copy_impl(to: ptr[PyObject]) -> ptr[PyObject] {
    newto = _PyObject_GC_New(ptr[PyObject](object_type(to)));
    if not newto {
        return NULL;
    }
    source = tee_of(to);
    target = tee_of(newto);
    target.view(1)[0].dataobj = object_new_ref(source.view(1)[0].dataobj);
    target.view(1)[0].index = source.view(1)[0].index;
    target.view(1)[0].weakreflist = NULL;
    target.view(1)[0].state = source.view(1)[0].state;
    object_gc_track(newto);
    return newto;
}

impl tee_copy(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return tee_copy_impl(op);
}

impl tee_fromiterable(
    state: ptr[itertools_state], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    to: ptr[PyObject] = NULL;
    if object_type_check(it, state.view(1)[0].tee_type) {
        to = tee_copy_impl(it);
    } else {
        dataobj = teedataobject_newinternal(state, it);
        if dataobj {
            to = _PyObject_GC_New(ptr[PyObject](state.view(1)[0].tee_type));
            if not to {
                object_decref(dataobj);
            } else {
                created = tee_of(to);
                created.view(1)[0].dataobj = dataobj;
                created.view(1)[0].index = 0;
                created.view(1)[0].weakreflist = NULL;
                created.view(1)[0].state = state;
                object_gc_track(to);
            }
        }
    }
    object_decref(it);
    return to;
}

impl itertools__tee_impl(
    type: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_module_state_by_cls(ptr[PyTypeObject](type));
    return tee_fromiterable(state, iterable);
}

impl tee_clear(op: ptr[PyObject]) -> i32 {
    to = tee_of(op);
    if to.view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    dataobj = to.view(1)[0].dataobj;
    if dataobj {
        to.view(1)[0].dataobj = NULL;
        object_decref(dataobj);
    }
    return 0;
}

impl tee_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);
    gc_untrack(op);
    tee_clear(op);
    PyObject_GC_Del(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl itertools_tee_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], n: i64
) -> ptr[PyObject] {
    if n < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("n must be >= 0"));
        return NULL;
    }
    result = PyTuple_New(n);
    if not result {
        return NULL;
    }
    if n == 0 {
        return result;
    }
    it = PyObject_GetIter(iterable);
    if not it {
        object_decref(result);
        return NULL;
    }
    state = get_module_state(module);
    to = tee_fromiterable(state, it);
    object_decref(it);
    if not to {
        object_decref(result);
        return NULL;
    }
    tuple_set_item(result, 0, to);
    i: i64 = 1;
    while i < n {
        to = tee_copy(to, NULL);
        if not to {
            object_decref(result);
            return NULL;
        }
        tuple_set_item(result, i, to);
        i += 1;
    }
    return result;
}

impl cycle_of(op: ptr[PyObject]) -> ptr[cycleobject] {
    return ptr[cycleobject](op);
}

impl itertools_cycle_impl(
    type: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    saved = PyList_New(0);
    if not saved {
        object_decref(it);
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        object_decref(saved);
        return NULL;
    }
    lz = cycle_of(op);
    lz.view(1)[0].it = it;
    lz.view(1)[0].saved = saved;
    lz.view(1)[0].index = 0;
    lz.view(1)[0].firstpass = 0;
    return op;
}

impl cycle_dealloc(op: ptr[PyObject]) {
    lz = cycle_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].it);
    object_xdecref(lz.view(1)[0].saved);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl cycle_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = cycle_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].saved, visitor, arg);
}

impl cycle_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = cycle_of(op);
    it = lz.view(1)[0].it;
    if it {
        item = PyIter_Next(it);
        if item {
            if lz.view(1)[0].firstpass != 0 {
                return item;
            }
            if PyList_Append(lz.view(1)[0].saved, item) != 0 {
                object_decref(item);
                return NULL;
            }
            return item;
        }

        if PyErr_Occurred() {
            return NULL;
        }
        lz.view(1)[0].it = NULL;
        object_decref(it);
    }
    saved = lz.view(1)[0].saved;
    size = object_size(saved);
    if size == 0 {
        return NULL;
    }
    index = lz.view(1)[0].index;
    item = (ptr[PyListObject](saved).view(1)[0].ob_item + index).view(1)[0];
    index = index + 1;
    if index >= object_size(saved) {
        index = 0;
    }
    lz.view(1)[0].index = index;
    return object_new_ref(item);
}

impl dropwhile_of(op: ptr[PyObject]) -> ptr[dropwhileobject] {
    return ptr[dropwhileobject](op);
}

impl itertools_dropwhile_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(seq);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = dropwhile_of(op);
    lz.view(1)[0].func = object_new_ref(func);
    lz.view(1)[0].it = it;
    lz.view(1)[0].start = 0;
    return op;
}

impl dropwhile_dealloc(op: ptr[PyObject]) {
    lz = dropwhile_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].func);
    object_xdecref(lz.view(1)[0].it);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl dropwhile_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = dropwhile_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].func, visitor, arg);
}

impl dropwhile_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = dropwhile_of(op);
    it = lz.view(1)[0].it;
    itp = object_type(it);
    while True {
        item = itp.view(1)[0].tp_iternext(it);
        if not item {
            return NULL;
        }
        if lz.view(1)[0].start == 1 {
            return item;
        }
        good = PyObject_CallOneArg(lz.view(1)[0].func, item);
        if not good {
            object_decref(item);
            return NULL;
        }
        ok = PyObject_IsTrue(good);
        object_decref(good);
        if ok == 0 {
            lz.view(1)[0].start = 1;
            return item;
        }
        object_decref(item);
        if ok < 0 {
            return NULL;
        }
    }
    return NULL;
}

impl takewhile_of(op: ptr[PyObject]) -> ptr[takewhileobject] {
    return ptr[takewhileobject](op);
}

impl itertools_takewhile_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(seq);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = takewhile_of(op);
    lz.view(1)[0].func = object_new_ref(func);
    lz.view(1)[0].it = it;
    lz.view(1)[0].stop = 0;
    return op;
}

impl takewhile_dealloc(op: ptr[PyObject]) {
    lz = takewhile_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].func);
    object_xdecref(lz.view(1)[0].it);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl takewhile_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = takewhile_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].func, visitor, arg);
}

impl takewhile_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = takewhile_of(op);
    it = lz.view(1)[0].it;
    if lz.view(1)[0].stop == 1 {
        return NULL;
    }
    item = object_type(it).view(1)[0].tp_iternext(it);
    if not item {
        return NULL;
    }
    good = PyObject_CallOneArg(lz.view(1)[0].func, item);
    if not good {
        object_decref(item);
        return NULL;
    }
    ok = PyObject_IsTrue(good);
    object_decref(good);
    if ok > 0 {
        return item;
    }
    object_decref(item);
    if ok == 0 {
        lz.view(1)[0].stop = 1;
    }
    return NULL;
}

impl islice_of(op: ptr[PyObject]) -> ptr[isliceobject] {
    return ptr[isliceobject](op);
}

impl islice_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    seq: ptr[PyObject] = NULL;
    a1: ptr[PyObject] = NULL;
    a2: ptr[PyObject] = NULL;
    a3: ptr[PyObject] = NULL;
    start: i64 = 0;
    stop: i64 = -1;
    step: i64 = 1;

    st = find_state_by_type(type);
    islice_type = st.view(1)[0].islice_type;
    if (
        type == islice_type
        or int(type.view(1)[0].tp_init) == int(islice_type.view(1)[0].tp_init)
    )
        and kwds
        and _PyArg_NoKeywords(ptr[u8]("islice"), kwds) == 0 {
        return NULL;
    }

    if PyArg_UnpackTuple(
        args, ptr[u8]("islice"), 2, 4, &mut seq, &mut a1, &mut a2, &mut a3
    )
        == 0 {
        return NULL;
    }

    numargs = PyTuple_Size(args);
    if numargs == 2 {
        if a1 != Py_None {
            stop = PyNumber_AsSsize_t(a1, PyExc_OverflowError);
            if stop == -1 {
                if PyErr_Occurred() {
                    PyErr_Clear();
                }
                PyErr_SetString(
                    PyExc_ValueError,
                    ptr[u8](
                        "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                    )
                );
                return NULL;
            }
        }
    } else {
        if a1 != Py_None {
            start = PyNumber_AsSsize_t(a1, PyExc_OverflowError);
        }
        if start == -1 and PyErr_Occurred() {
            PyErr_Clear();
        }
        if a2 != Py_None {
            stop = PyNumber_AsSsize_t(a2, PyExc_OverflowError);
            if stop == -1 {
                if PyErr_Occurred() {
                    PyErr_Clear();
                }
                PyErr_SetString(
                    PyExc_ValueError,
                    ptr[u8](
                        "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."
                    )
                );
                return NULL;
            }
        }
    }
    if start < 0 or stop < -1 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8](
                "Indices for islice() must be None or an integer: 0 <= x <= sys.maxsize."
            )
        );
        return NULL;
    }

    if a3 {
        if a3 != Py_None {
            step = PyNumber_AsSsize_t(a3, PyExc_OverflowError);
        }
        if step == -1 and PyErr_Occurred() {
            PyErr_Clear();
        }
    }
    if step < 1 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("Step for islice() must be a positive integer or None.")
        );
        return NULL;
    }

    it = PyObject_GetIter(seq);
    if not it {
        return NULL;
    }
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = islice_of(op);
    lz.view(1)[0].it = it;
    lz.view(1)[0].next = start;
    lz.view(1)[0].stop = stop;
    lz.view(1)[0].step = step;
    lz.view(1)[0].cnt = 0;
    return op;
}

impl islice_dealloc(op: ptr[PyObject]) {
    lz = islice_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].it);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl islice_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(islice_of(op).view(1)[0].it, visitor, arg);
}

impl islice_empty(lz: ptr[isliceobject]) -> ptr[PyObject] {
    it = lz.view(1)[0].it;
    if it {
        lz.view(1)[0].it = NULL;
        object_decref(it);
    }
    return NULL;
}

impl islice_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = islice_of(op);
    it = lz.view(1)[0].it;
    stop = lz.view(1)[0].stop;
    if not it {
        return NULL;
    }
    itp = object_type(it);
    while lz.view(1)[0].cnt < lz.view(1)[0].next {
        skipped = itp.view(1)[0].tp_iternext(it);
        if not skipped {
            return islice_empty(lz);
        }
        object_decref(skipped);
        lz.view(1)[0].cnt = lz.view(1)[0].cnt + 1;
    }
    if stop != -1 and lz.view(1)[0].cnt >= stop {
        return islice_empty(lz);
    }
    item = itp.view(1)[0].tp_iternext(it);
    if not item {
        return islice_empty(lz);
    }
    lz.view(1)[0].cnt = lz.view(1)[0].cnt + 1;
    oldnext = lz.view(1)[0].next;

    nextpos = wrapping_add(oldnext, lz.view(1)[0].step);
    if nextpos < oldnext or (stop != -1 and nextpos > stop) {
        nextpos = stop;
    }
    lz.view(1)[0].next = nextpos;
    return item;
}

impl starmap_of(op: ptr[PyObject]) -> ptr[starmapobject] {
    return ptr[starmapobject](op);
}

impl itertools_starmap_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(seq);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = starmap_of(op);
    lz.view(1)[0].func = object_new_ref(func);
    lz.view(1)[0].it = it;
    return op;
}

impl starmap_dealloc(op: ptr[PyObject]) {
    lz = starmap_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].func);
    object_xdecref(lz.view(1)[0].it);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl starmap_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = starmap_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].func, visitor, arg);
}

impl starmap_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = starmap_of(op);
    it = lz.view(1)[0].it;
    args = object_type(it).view(1)[0].tp_iternext(it);
    if not args {
        return NULL;
    }
    if ptr[PyObject](object_type(args)) != addressof(PyTuple_Type) {
        newargs = PySequence_Tuple(args);
        object_decref(args);
        if not newargs {
            return NULL;
        }
        args = newargs;
    }
    result = PyObject_Call(lz.view(1)[0].func, args, NULL);
    object_decref(args);
    return result;
}

impl chain_of(op: ptr[PyObject]) -> ptr[chainobject] {
    return ptr[chainobject](op);
}

impl chain_new_internal(
    type: ptr[PyTypeObject], source: ptr[PyObject]
) -> ptr[PyObject] {
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        object_decref(source);
        return NULL;
    }
    lz = chain_of(op);
    lz.view(1)[0].source = source;
    lz.view(1)[0].active = NULL;
    return op;
}

impl chain_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    state = find_state_by_type(type);
    chain_type = state.view(1)[0].chain_type;
    if (
        type == chain_type
        or int(type.view(1)[0].tp_init) == int(chain_type.view(1)[0].tp_init)
    )
        and kwds
        and _PyArg_NoKeywords(ptr[u8]("chain"), kwds) == 0 {
        return NULL;
    }
    source = PyObject_GetIter(args);
    if not source {
        return NULL;
    }
    return chain_new_internal(type, source);
}

impl itertools_chain_from_iterable_impl(
    type: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    source = PyObject_GetIter(arg);
    if not source {
        return NULL;
    }
    return chain_new_internal(ptr[PyTypeObject](type), source);
}

impl chain_dealloc(op: ptr[PyObject]) {
    lz = chain_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].active);
    object_xdecref(lz.view(1)[0].source);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl chain_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = chain_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].source, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].active, visitor, arg);
}

impl chain_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = chain_of(op);
    while lz.view(1)[0].source {
        if not lz.view(1)[0].active {
            iterable = PyIter_Next(lz.view(1)[0].source);
            if not iterable {
                source = lz.view(1)[0].source;
                lz.view(1)[0].source = NULL;
                object_decref(source);

                return NULL;
            }
            lz.view(1)[0].active = PyObject_GetIter(iterable);
            object_decref(iterable);
            if not lz.view(1)[0].active {
                source = lz.view(1)[0].source;
                lz.view(1)[0].source = NULL;
                object_decref(source);

                return NULL;
            }
        }
        active = lz.view(1)[0].active;
        item = object_type(active).view(1)[0].tp_iternext(active);
        if item {
            return item;
        }
        if PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
                PyErr_Clear();
            } else {
                return NULL;
            }
        }

        consumed = lz.view(1)[0].active;
        if consumed {
            lz.view(1)[0].active = NULL;
            object_decref(consumed);
        }
    }

    return NULL;
}

impl product_of(op: ptr[PyObject]) -> ptr[productobject] {
    return ptr[productobject](op);
}

impl product_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    repeat: i64 = 1;
    if kwds {
        tmpargs = PyTuple_New(0);
        if not tmpargs {
            return NULL;
        }
        if PyArg_ParseTupleAndKeywords(
            tmpargs,
            kwds,
            ptr[u8]("|n:product"),
            ptr(addressof(product_kwlist)),
            &mut repeat
        )
            == 0 {
            object_decref(tmpargs);
            return NULL;
        }
        object_decref(tmpargs);
        if repeat < 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("repeat argument cannot be negative")
            );
            return NULL;
        }
    }

    nargs: i64 = 0;
    if repeat != 0 {
        nargs = object_size(args);
        if nargs > PY_SSIZE_T_MAX // 8 // repeat {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("repeat argument too large"));
            return NULL;
        }
    }
    npools = nargs * repeat;

    indices = pymem_new_ssize(npools);
    if not indices {
        PyErr_NoMemory();
        return NULL;
    }
    pools = PyTuple_New(npools);
    if not pools {
        PyMem_Free(ptr(indices));
        return NULL;
    }
    i: i64 = 0;
    while i < nargs {
        item = tuple_get_item(args, i);
        pool = PySequence_Tuple(item);
        if not pool {
            PyMem_Free(ptr(indices));
            object_decref(pools);
            return NULL;
        }
        tuple_set_item(pools, i, pool);
        (indices + i).view(1)[0] = 0;
        i += 1;
    }
    while i < npools {
        pool = tuple_get_item(pools, i - nargs);
        object_incref(pool);
        tuple_set_item(pools, i, pool);
        (indices + i).view(1)[0] = 0;
        i += 1;
    }

    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        PyMem_Free(ptr(indices));
        object_decref(pools);
        return NULL;
    }
    lz = product_of(op);
    lz.view(1)[0].pools = pools;
    lz.view(1)[0].indices = indices;
    lz.view(1)[0].result = NULL;
    lz.view(1)[0].stopped = 0;
    return op;
}

impl product_dealloc(op: ptr[PyObject]) {
    lz = product_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].pools);
    object_xdecref(lz.view(1)[0].result);
    PyMem_Free(ptr(lz.view(1)[0].indices));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl product_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    lz = product_of(op);
    res = u64(object_type(op).view(1)[0].tp_basicsize);
    res = res + u64(object_size(lz.view(1)[0].pools)) * 8;
    return PyLong_FromSize_t(res);
}

impl product_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = product_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].pools, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].result, visitor, arg);
}

impl product_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = product_of(op);
    pools = lz.view(1)[0].pools;
    result = lz.view(1)[0].result;
    npools = object_size(pools);

    if lz.view(1)[0].stopped != 0 {
        return NULL;
    }

    if not result {
        result = PyTuple_New(npools);
        if not result {
            lz.view(1)[0].stopped = 1;
            return NULL;
        }
        lz.view(1)[0].result = result;
        i: i64 = 0;
        while i < npools {
            pool = tuple_get_item(pools, i);
            if object_size(pool) == 0 {
                lz.view(1)[0].stopped = 1;
                return NULL;
            }
            elem = tuple_get_item(pool, 0);
            object_incref(elem);
            tuple_set_item(result, i, elem);
            i += 1;
        }
    } else {
        indices = lz.view(1)[0].indices;
        if object_refcount(result) != 1 {
            old_result = result;
            result = _PyTuple_FromArray(tuple_items(old_result), npools);
            if not result {
                lz.view(1)[0].stopped = 1;
                return NULL;
            }
            lz.view(1)[0].result = result;
            object_decref(old_result);
        } else {
            tuple_recycle(result);
        }
        j: i64 = npools - 1;
        while j >= 0 {
            pool = tuple_get_item(pools, j);
            slot = indices + j;
            index = slot.view(1)[0] + 1;
            slot.view(1)[0] = index;
            if index == object_size(pool) {
                slot.view(1)[0] = 0;
                elem = tuple_get_item(pool, 0);
                object_incref(elem);
                oldelem = tuple_get_item(result, j);
                tuple_set_item(result, j, elem);
                object_decref(oldelem);
            } else {
                elem = tuple_get_item(pool, index);
                object_incref(elem);
                oldelem = tuple_get_item(result, j);
                tuple_set_item(result, j, elem);
                object_decref(oldelem);
                break;
            }
            j -= 1;
        }
        if j < 0 {
            lz.view(1)[0].stopped = 1;
            return NULL;
        }
    }
    return object_new_ref(result);
}

impl combinations_of(op: ptr[PyObject]) -> ptr[combinationsobject] {
    return ptr[combinationsobject](op);
}

impl itertools_combinations_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], r: i64
) -> ptr[PyObject] {
    pool = PySequence_Tuple(iterable);
    if not pool {
        return NULL;
    }
    n = object_size(pool);
    if r < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("r must be non-negative"));
        object_decref(pool);
        return NULL;
    }
    indices = pymem_new_ssize(r);
    if not indices {
        PyErr_NoMemory();
        object_decref(pool);
        return NULL;
    }
    i: i64 = 0;
    while i < r {
        (indices + i).view(1)[0] = i;
        i += 1;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        PyMem_Free(ptr(indices));
        object_decref(pool);
        return NULL;
    }
    co = combinations_of(op);
    co.view(1)[0].pool = pool;
    co.view(1)[0].indices = indices;
    co.view(1)[0].result = NULL;
    co.view(1)[0].r = r;
    co.view(1)[0].stopped = i32(1) if r > n else i32(0);
    return op;
}

impl combinations_dealloc(op: ptr[PyObject]) {
    co = combinations_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(co.view(1)[0].pool);
    object_xdecref(co.view(1)[0].result);
    PyMem_Free(ptr(co.view(1)[0].indices));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl combinations_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    co = combinations_of(op);
    res = u64(object_type(op).view(1)[0].tp_basicsize);
    res = res + u64(co.view(1)[0].r) * 8;
    return PyLong_FromSize_t(res);
}

impl combinations_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    co = combinations_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(co.view(1)[0].pool, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(co.view(1)[0].result, visitor, arg);
}

impl combinations_next(op: ptr[PyObject]) -> ptr[PyObject] {
    co = combinations_of(op);
    pool = co.view(1)[0].pool;
    indices = co.view(1)[0].indices;
    result = co.view(1)[0].result;
    n = object_size(pool);
    r = co.view(1)[0].r;

    if co.view(1)[0].stopped != 0 {
        return NULL;
    }

    if not result {
        result = PyTuple_New(r);
        if not result {
            co.view(1)[0].stopped = 1;
            return NULL;
        }
        co.view(1)[0].result = result;
        k: i64 = 0;
        while k < r {
            elem = tuple_get_item(pool, (indices + k).view(1)[0]);
            object_incref(elem);
            tuple_set_item(result, k, elem);
            k += 1;
        }
    } else {
        if object_refcount(result) != 1 {
            old_result = result;
            result = _PyTuple_FromArray(tuple_items(old_result), r);
            if not result {
                co.view(1)[0].stopped = 1;
                return NULL;
            }
            co.view(1)[0].result = result;
            object_decref(old_result);
        } else {
            tuple_recycle(result);
        }
        i: i64 = r - 1;
        while i >= 0 and (indices + i).view(1)[0] == i + n - r {
            i -= 1;
        }
        if i < 0 {
            co.view(1)[0].stopped = 1;
            return NULL;
        }
        (indices + i).view(1)[0] = (indices + i).view(1)[0] + 1;
        j: i64 = i + 1;
        while j < r {
            (indices + j).view(1)[0] = (indices + (j - 1)).view(1)[0] + 1;
            j += 1;
        }
        while i < r {
            elem = tuple_get_item(pool, (indices + i).view(1)[0]);
            object_incref(elem);
            oldelem = tuple_get_item(result, i);
            tuple_set_item(result, i, elem);
            object_decref(oldelem);
            i += 1;
        }
    }
    return object_new_ref(result);
}

impl cwr_of(op: ptr[PyObject]) -> ptr[cwrobject] {
    return ptr[cwrobject](op);
}

impl itertools_combinations_with_replacement_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], r: i64
) -> ptr[PyObject] {
    pool = PySequence_Tuple(iterable);
    if not pool {
        return NULL;
    }
    n = object_size(pool);
    if r < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("r must be non-negative"));
        object_decref(pool);
        return NULL;
    }
    indices = pymem_new_ssize(r);
    if not indices {
        PyErr_NoMemory();
        object_decref(pool);
        return NULL;
    }
    i: i64 = 0;
    while i < r {
        (indices + i).view(1)[0] = 0;
        i += 1;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        PyMem_Free(ptr(indices));
        object_decref(pool);
        return NULL;
    }
    co = cwr_of(op);
    co.view(1)[0].pool = pool;
    co.view(1)[0].indices = indices;
    co.view(1)[0].result = NULL;
    co.view(1)[0].r = r;
    co.view(1)[0].stopped = i32(1) if n == 0 and r != 0 else i32(0);
    return op;
}

impl cwr_dealloc(op: ptr[PyObject]) {
    co = cwr_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(co.view(1)[0].pool);
    object_xdecref(co.view(1)[0].result);
    PyMem_Free(ptr(co.view(1)[0].indices));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl cwr_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    co = cwr_of(op);
    res = u64(object_type(op).view(1)[0].tp_basicsize);
    res = res + u64(co.view(1)[0].r) * 8;
    return PyLong_FromSize_t(res);
}

impl cwr_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    co = cwr_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(co.view(1)[0].pool, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(co.view(1)[0].result, visitor, arg);
}

impl cwr_next(op: ptr[PyObject]) -> ptr[PyObject] {
    co = cwr_of(op);
    pool = co.view(1)[0].pool;
    indices = co.view(1)[0].indices;
    result = co.view(1)[0].result;
    n = object_size(pool);
    r = co.view(1)[0].r;

    if co.view(1)[0].stopped != 0 {
        return NULL;
    }

    if not result {
        result = PyTuple_New(r);
        if not result {
            co.view(1)[0].stopped = 1;
            return NULL;
        }
        co.view(1)[0].result = result;
        if n > 0 {
            first = tuple_get_item(pool, 0);
            k: i64 = 0;
            while k < r {
                object_incref(first);
                tuple_set_item(result, k, first);
                k += 1;
            }
        }
    } else {
        if object_refcount(result) != 1 {
            old_result = result;
            result = _PyTuple_FromArray(tuple_items(old_result), r);
            if not result {
                co.view(1)[0].stopped = 1;
                return NULL;
            }
            co.view(1)[0].result = result;
            object_decref(old_result);
        } else {
            tuple_recycle(result);
        }
        i: i64 = r - 1;
        while i >= 0 and (indices + i).view(1)[0] == n - 1 {
            i -= 1;
        }
        if i < 0 {
            co.view(1)[0].stopped = 1;
            return NULL;
        }
        index = (indices + i).view(1)[0] + 1;
        elem = tuple_get_item(pool, index);
        while i < r {
            (indices + i).view(1)[0] = index;
            object_incref(elem);
            oldelem = tuple_get_item(result, i);
            tuple_set_item(result, i, elem);
            object_decref(oldelem);
            i += 1;
        }
    }
    return object_new_ref(result);
}

impl permutations_of(op: ptr[PyObject]) -> ptr[permutationsobject] {
    return ptr[permutationsobject](op);
}

impl itertools_permutations_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], robj: ptr[PyObject]
) -> ptr[PyObject] {
    pool = PySequence_Tuple(iterable);
    if not pool {
        return NULL;
    }
    n = object_size(pool);
    r: i64 = n;
    if robj != Py_None {
        if not long_check(robj) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("Expected int as r"));
            object_decref(pool);
            return NULL;
        }
        r = PyLong_AsSsize_t(robj);
        if r == -1 and PyErr_Occurred() {
            object_decref(pool);
            return NULL;
        }
    }
    if r < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("r must be non-negative"));
        object_decref(pool);
        return NULL;
    }

    indices = pymem_new_ssize(n);
    cycles = pymem_new_ssize(r);
    if not indices or not cycles {
        PyErr_NoMemory();
        if indices {
            PyMem_Free(ptr(indices));
        }
        if cycles {
            PyMem_Free(ptr(cycles));
        }
        object_decref(pool);
        return NULL;
    }
    i: i64 = 0;
    while i < n {
        (indices + i).view(1)[0] = i;
        i += 1;
    }
    i = 0;
    while i < r {
        (cycles + i).view(1)[0] = n - i;
        i += 1;
    }

    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        PyMem_Free(ptr(indices));
        PyMem_Free(ptr(cycles));
        object_decref(pool);
        return NULL;
    }
    po = permutations_of(op);
    po.view(1)[0].pool = pool;
    po.view(1)[0].indices = indices;
    po.view(1)[0].cycles = cycles;
    po.view(1)[0].result = NULL;
    po.view(1)[0].r = r;
    po.view(1)[0].stopped = i32(1) if r > n else i32(0);
    return op;
}

impl permutations_dealloc(op: ptr[PyObject]) {
    po = permutations_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(po.view(1)[0].pool);
    object_xdecref(po.view(1)[0].result);
    PyMem_Free(ptr(po.view(1)[0].indices));
    PyMem_Free(ptr(po.view(1)[0].cycles));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl permutations_sizeof(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    po = permutations_of(op);
    res = u64(object_type(op).view(1)[0].tp_basicsize);
    res = res + u64(object_size(po.view(1)[0].pool)) * 8;
    res = res + u64(po.view(1)[0].r) * 8;
    return PyLong_FromSize_t(res);
}

impl permutations_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    po = permutations_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(po.view(1)[0].pool, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(po.view(1)[0].result, visitor, arg);
}

impl permutations_next(op: ptr[PyObject]) -> ptr[PyObject] {
    po = permutations_of(op);
    pool = po.view(1)[0].pool;
    indices = po.view(1)[0].indices;
    cycles = po.view(1)[0].cycles;
    result = po.view(1)[0].result;
    n = object_size(pool);
    r = po.view(1)[0].r;

    if po.view(1)[0].stopped != 0 {
        return NULL;
    }

    if not result {
        result = PyTuple_New(r);
        if not result {
            po.view(1)[0].stopped = 1;
            return NULL;
        }
        po.view(1)[0].result = result;
        k: i64 = 0;
        while k < r {
            elem = tuple_get_item(pool, (indices + k).view(1)[0]);
            object_incref(elem);
            tuple_set_item(result, k, elem);
            k += 1;
        }
    } else {
        if n == 0 {
            po.view(1)[0].stopped = 1;
            return NULL;
        }
        if object_refcount(result) != 1 {
            old_result = result;
            result = _PyTuple_FromArray(tuple_items(old_result), r);
            if not result {
                po.view(1)[0].stopped = 1;
                return NULL;
            }
            po.view(1)[0].result = result;
            object_decref(old_result);
        } else {
            tuple_recycle(result);
        }
        i: i64 = r - 1;
        while i >= 0 {
            cycle = (cycles + i).view(1)[0] - 1;
            (cycles + i).view(1)[0] = cycle;
            if cycle == 0 {
                index = (indices + i).view(1)[0];
                j: i64 = i;
                while j < n - 1 {
                    (indices + j).view(1)[0] = (indices + (j + 1)).view(1)[0];
                    j += 1;
                }
                (indices + (n - 1)).view(1)[0] = index;
                (cycles + i).view(1)[0] = n - i;
            } else {
                swap = cycle;
                index = (indices + i).view(1)[0];
                (indices + i).view(1)[0] = (indices + (n - swap)).view(1)[0];
                (indices + (n - swap)).view(1)[0] = index;
                k: i64 = i;
                while k < r {
                    elem = tuple_get_item(pool, (indices + k).view(1)[0]);
                    object_incref(elem);
                    oldelem = tuple_get_item(result, k);
                    tuple_set_item(result, k, elem);
                    object_decref(oldelem);
                    k += 1;
                }
                break;
            }
            i -= 1;
        }
        if i < 0 {
            po.view(1)[0].stopped = 1;
            return NULL;
        }
    }
    return object_new_ref(result);
}

impl accumulate_of(op: ptr[PyObject]) -> ptr[accumulateobject] {
    return ptr[accumulateobject](op);
}

impl itertools_accumulate_impl(
    type: ptr[PyObject],
    iterable: ptr[PyObject],
    binop: ptr[PyObject],
    initial: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = accumulate_of(op);
    if binop != Py_None {
        if binop {
            object_incref(binop);
        }
        lz.view(1)[0].binop = binop;
    }
    lz.view(1)[0].total = NULL;
    lz.view(1)[0].it = it;
    if initial {
        object_incref(initial);
    }
    lz.view(1)[0].initial = initial;
    lz.view(1)[0].state = find_state_by_type(tp);
    return op;
}

impl accumulate_dealloc(op: ptr[PyObject]) {
    lz = accumulate_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].binop);
    object_xdecref(lz.view(1)[0].total);
    object_xdecref(lz.view(1)[0].it);
    object_xdecref(lz.view(1)[0].initial);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl accumulate_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = accumulate_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].binop, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].total, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].initial, visitor, arg);
}

impl accumulate_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = accumulate_of(op);
    if lz.view(1)[0].initial != Py_None {
        lz.view(1)[0].total = lz.view(1)[0].initial;
        lz.view(1)[0].initial = object_new_ref(Py_None);
        return object_new_ref(lz.view(1)[0].total);
    }
    it = lz.view(1)[0].it;
    val: ptr[PyObject] = object_type(it).view(1)[0].tp_iternext(it);
    if not val {
        return NULL;
    }
    total: ptr[PyObject] = lz.view(1)[0].total;
    if not total {
        lz.view(1)[0].total = object_new_ref(val);
        return val;
    }
    newtotal: ptr[PyObject] = NULL;
    if not lz.view(1)[0].binop {
        newtotal = PyNumber_Add(total, val);
    } else {
        newtotal = PyObject_CallFunctionObjArgs(lz.view(1)[0].binop, total, val, NULL);
    }
    object_decref(val);
    if not newtotal {
        return NULL;
    }
    object_incref(newtotal);
    old = lz.view(1)[0].total;
    lz.view(1)[0].total = newtotal;
    object_decref(old);
    return newtotal;
}

impl compress_of(op: ptr[PyObject]) -> ptr[compressobject] {
    return ptr[compressobject](op);
}

impl itertools_compress_impl(
    type: ptr[PyObject], seq1: ptr[PyObject], seq2: ptr[PyObject]
) -> ptr[PyObject] {
    data = PyObject_GetIter(seq1);
    if not data {
        return NULL;
    }
    selectors = PyObject_GetIter(seq2);
    if not selectors {
        object_decref(data);
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(data);
        object_decref(selectors);
        return NULL;
    }
    lz = compress_of(op);
    lz.view(1)[0].data = data;
    lz.view(1)[0].selectors = selectors;
    return op;
}

impl compress_dealloc(op: ptr[PyObject]) {
    lz = compress_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].data);
    object_xdecref(lz.view(1)[0].selectors);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl compress_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = compress_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].data, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].selectors, visitor, arg);
}

impl compress_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = compress_of(op);
    data = lz.view(1)[0].data;
    selectors = lz.view(1)[0].selectors;
    datatp = object_type(data);
    selectortp = object_type(selectors);
    while True {
        datum = datatp.view(1)[0].tp_iternext(data);
        if not datum {
            return NULL;
        }
        selector = selectortp.view(1)[0].tp_iternext(selectors);
        if not selector {
            object_decref(datum);
            return NULL;
        }
        ok = PyObject_IsTrue(selector);
        object_decref(selector);
        if ok > 0 {
            return datum;
        }
        object_decref(datum);
        if ok < 0 {
            return NULL;
        }
    }
    return NULL;
}

impl filterfalse_of(op: ptr[PyObject]) -> ptr[filterfalseobject] {
    return ptr[filterfalseobject](op);
}

impl itertools_filterfalse_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    it = PyObject_GetIter(seq);
    if not it {
        return NULL;
    }
    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = filterfalse_of(op);
    lz.view(1)[0].func = object_new_ref(func);
    lz.view(1)[0].it = it;
    return op;
}

impl filterfalse_dealloc(op: ptr[PyObject]) {
    lz = filterfalse_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].func);
    object_xdecref(lz.view(1)[0].it);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl filterfalse_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = filterfalse_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].func, visitor, arg);
}

impl filterfalse_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = filterfalse_of(op);
    it = lz.view(1)[0].it;
    itp = object_type(it);
    while True {
        item = itp.view(1)[0].tp_iternext(it);
        if not item {
            return NULL;
        }
        func = lz.view(1)[0].func;
        ok: i32 = 0;
        if func == Py_None or func == addressof(PyBool_Type) {
            ok = PyObject_IsTrue(item);
        } else {
            good = PyObject_CallOneArg(func, item);
            if not good {
                object_decref(item);
                return NULL;
            }
            ok = PyObject_IsTrue(good);
            object_decref(good);
        }
        if ok == 0 {
            return item;
        }
        object_decref(item);
        if ok < 0 {
            return NULL;
        }
    }
    return NULL;
}

impl count_of(op: ptr[PyObject]) -> ptr[countobject] {
    return ptr[countobject](op);
}

impl itertools_count_impl(
    type: ptr[PyObject], long_cnt: ptr[PyObject], long_step: ptr[PyObject]
) -> ptr[PyObject] {
    cnt: i64 = 0;
    start = long_cnt;
    stepobj = long_step;

    if (start and PyNumber_Check(start) == 0)
        or (stepobj and PyNumber_Check(stepobj) == 0) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("a number is required"));
        return NULL;
    }

    fast_mode = (not start or long_check(start))
        and (not stepobj or long_check(stepobj));

    if start {
        if fast_mode {
            cnt = PyLong_AsSsize_t(start);
            if cnt == -1 and PyErr_Occurred() {
                PyErr_Clear();
                fast_mode = False;
            }
        }
    } else {
        cnt = 0;
        start = long_zero();
    }
    object_incref(start);

    if not stepobj {
        stepobj = long_one();
    }
    object_incref(stepobj);

    if fast_mode {
        step = PyLong_AsLong(stepobj);
        if step != 1 {
            fast_mode = False;
            if step == -1 and PyErr_Occurred() {
                PyErr_Clear();
            }
        }
    }

    if fast_mode {
        cleared = start;
        start = NULL;
        object_decref(cleared);
    } else {
        cnt = PY_SSIZE_T_MAX;
    }

    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_xdecref(start);
        object_decref(stepobj);
        return NULL;
    }
    lz = count_of(op);
    lz.view(1)[0].cnt = cnt;
    lz.view(1)[0].long_cnt = start;
    lz.view(1)[0].long_step = stepobj;
    return op;
}

impl count_dealloc(op: ptr[PyObject]) {
    lz = count_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].long_cnt);
    object_xdecref(lz.view(1)[0].long_step);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl count_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = count_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].long_cnt, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].long_step, visitor, arg);
}

impl count_nextlong(lz: ptr[countobject]) -> ptr[PyObject] {
    long_cnt = lz.view(1)[0].long_cnt;
    if not long_cnt {
        long_cnt = PyLong_FromSsize_t(PY_SSIZE_T_MAX);
        if not long_cnt {
            return NULL;
        }
    }
    stepped_up = PyNumber_Add(long_cnt, lz.view(1)[0].long_step);
    if not stepped_up {
        return NULL;
    }
    lz.view(1)[0].long_cnt = stepped_up;
    return long_cnt;
}

impl count_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = count_of(op);
    cnt = lz.view(1)[0].cnt;
    if cnt == PY_SSIZE_T_MAX {
        return count_nextlong(lz);
    }
    lz.view(1)[0].cnt = cnt + 1;
    return PyLong_FromSsize_t(cnt);
}

impl count_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = count_of(op);
    name: ptr[u8] = _PyType_Name(ptr[PyObject](object_type(op)));
    long_cnt: ptr[PyObject] = lz.view(1)[0].long_cnt;
    long_step: ptr[PyObject] = lz.view(1)[0].long_step;
    if not long_cnt {
        cnt: i64 = lz.view(1)[0].cnt;
        return PyUnicode_FromFormat("%s(%zd)", name, cnt);
    }
    if long_check(long_step) {
        step = PyLong_AsLong(long_step);
        if step == -1 and PyErr_Occurred() {
            PyErr_Clear();
        }
        if step == 1 {
            return PyUnicode_FromFormat("%s(%R)", name, long_cnt);
        }
    }
    return PyUnicode_FromFormat("%s(%R, %R)", name, long_cnt, long_step);
}

impl repeat_of(op: ptr[PyObject]) -> ptr[repeatobject] {
    return ptr[repeatobject](op);
}

impl repeat_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    element: ptr[PyObject] = NULL;
    cnt: i64 = -1;
    n_args = object_size(args);
    if kwds {
        n_args = n_args + ptr[PyDictObject](kwds).view(1)[0].ma_used;
    }
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|n:repeat"),
        ptr(addressof(repeat_kwargs)),
        &mut element,
        &mut cnt
    )
        == 0 {
        return NULL;
    }

    if n_args == 2 and cnt < 0 {
        cnt = 0;
    }
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        return NULL;
    }
    ro = repeat_of(op);
    ro.view(1)[0].element = object_new_ref(element);
    ro.view(1)[0].cnt = cnt;
    return op;
}

impl repeat_dealloc(op: ptr[PyObject]) {
    ro = repeat_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(ro.view(1)[0].element);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl repeat_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(repeat_of(op).view(1)[0].element, visitor, arg);
}

impl repeat_next(op: ptr[PyObject]) -> ptr[PyObject] {
    ro = repeat_of(op);
    cnt = ro.view(1)[0].cnt;
    if cnt == 0 {
        return NULL;
    }
    if cnt > 0 {
        ro.view(1)[0].cnt = cnt - 1;
    }
    return object_new_ref(ro.view(1)[0].element);
}

impl repeat_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    ro = repeat_of(op);
    name: ptr[u8] = _PyType_Name(ptr[PyObject](object_type(op)));
    element: ptr[PyObject] = ro.view(1)[0].element;
    cnt: i64 = ro.view(1)[0].cnt;
    if cnt == -1 {
        return PyUnicode_FromFormat("%s(%R)", name, element);
    }
    return PyUnicode_FromFormat("%s(%R, %zd)", name, element, cnt);
}

impl repeat_len(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    ro = repeat_of(op);
    cnt = ro.view(1)[0].cnt;
    if cnt == -1 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("len() of unsized object"));
        return NULL;
    }
    return PyLong_FromSize_t(u64.wrap(cnt));
}

impl ziplongest_of(op: ptr[PyObject]) -> ptr[ziplongestobject] {
    return ptr[ziplongestobject](op);
}

impl zip_longest_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    fillvalue: ptr[PyObject] = Py_None;
    if kwds
        and ptr[PyObject](object_type(kwds)) == addressof(PyDict_Type)
        and ptr[PyDictObject](kwds).view(1)[0].ma_used > 0 {
        fillvalue = NULL;
        if ptr[PyDictObject](kwds).view(1)[0].ma_used == 1 {
            key = PyUnicode_InternFromString(ptr[u8]("fillvalue"));
            if not key {
                return NULL;
            }
            fillvalue = PyDict_GetItemWithError(kwds, key);
            object_decref(key);
        }
        if not fillvalue {
            if not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_TypeError,
                    ptr[u8]("zip_longest() got an unexpected keyword argument")
                );
            }
            return NULL;
        }
    }

    tuplesize = object_size(args);

    ittuple = PyTuple_New(tuplesize);
    if not ittuple {
        return NULL;
    }
    i: i64 = 0;
    while i < tuplesize {
        item = tuple_get_item(args, i);
        it = PyObject_GetIter(item);
        if not it {
            object_decref(ittuple);
            return NULL;
        }
        tuple_set_item(ittuple, i, it);
        i += 1;
    }

    result = PyTuple_New(tuplesize);
    if not result {
        object_decref(ittuple);
        return NULL;
    }
    i = 0;
    while i < tuplesize {
        tuple_set_item(result, i, object_new_ref(Py_None));
        i += 1;
    }

    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        object_decref(ittuple);
        object_decref(result);
        return NULL;
    }
    lz = ziplongest_of(op);
    lz.view(1)[0].ittuple = ittuple;
    lz.view(1)[0].tuplesize = tuplesize;
    lz.view(1)[0].numactive = tuplesize;
    lz.view(1)[0].result = result;
    lz.view(1)[0].fillvalue = object_new_ref(fillvalue);
    return op;
}

impl zip_longest_dealloc(op: ptr[PyObject]) {
    lz = ziplongest_of(op);
    tp = object_type(op);
    gc_untrack(op);
    object_xdecref(lz.view(1)[0].ittuple);
    object_xdecref(lz.view(1)[0].result);
    object_xdecref(lz.view(1)[0].fillvalue);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl zip_longest_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = ziplongest_of(op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].ittuple, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(lz.view(1)[0].result, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].fillvalue, visitor, arg);
}

impl zip_longest_next(op: ptr[PyObject]) -> ptr[PyObject] {
    lz = ziplongest_of(op);
    tuplesize = lz.view(1)[0].tuplesize;
    result = lz.view(1)[0].result;
    ittuple = lz.view(1)[0].ittuple;

    if tuplesize == 0 {
        return NULL;
    }
    if lz.view(1)[0].numactive == 0 {
        return NULL;
    }
    if object_refcount(result) == 1 {
        object_incref(result);
        i: i64 = 0;
        while i < tuplesize {
            it = tuple_get_item(ittuple, i);
            item: ptr[PyObject] = NULL;
            if not it {
                item = object_new_ref(lz.view(1)[0].fillvalue);
            } else {
                item = PyIter_Next(it);
                if not item {
                    lz.view(1)[0].numactive = lz.view(1)[0].numactive - 1;
                    if lz.view(1)[0].numactive == 0 or PyErr_Occurred() {
                        lz.view(1)[0].numactive = 0;
                        object_decref(result);
                        return NULL;
                    }
                    item = object_new_ref(lz.view(1)[0].fillvalue);
                    tuple_set_item(ittuple, i, NULL);
                    object_decref(it);
                }
            }
            olditem = tuple_get_item(result, i);
            tuple_set_item(result, i, item);
            object_decref(olditem);
            i += 1;
        }

        tuple_recycle(result);
    } else {
        result = PyTuple_New(tuplesize);
        if not result {
            return NULL;
        }
        i: i64 = 0;
        while i < tuplesize {
            it = tuple_get_item(ittuple, i);
            item: ptr[PyObject] = NULL;
            if not it {
                item = object_new_ref(lz.view(1)[0].fillvalue);
            } else {
                item = PyIter_Next(it);
                if not item {
                    lz.view(1)[0].numactive = lz.view(1)[0].numactive - 1;
                    if lz.view(1)[0].numactive == 0 or PyErr_Occurred() {
                        lz.view(1)[0].numactive = 0;
                        object_decref(result);
                        return NULL;
                    }
                    item = object_new_ref(lz.view(1)[0].fillvalue);
                    tuple_set_item(ittuple, i, NULL);
                    object_decref(it);
                }
            }
            tuple_set_item(result, i, item);
            i += 1;
        }
    }
    return result;
}

impl itertoolsmodule_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    types = ptr[ptr[PyObject]](get_module_state(mod));
    i: i64 = 0;
    while i < ITERTOOLS_STATE_TYPES {
        status = visit_reference((types + i).view(1)[0], visitor, arg);
        if status != 0 {
            return status;
        }
        i += 1;
    }
    return 0;
}

impl itertoolsmodule_clear(mod: ptr[PyObject]) -> i32 {
    types = ptr[ptr[PyObject]](get_module_state(mod));
    i: i64 = 0;
    while i < ITERTOOLS_STATE_TYPES {
        type = (types + i).view(1)[0];
        if type {
            (types + i).view(1)[0] = NULL;
            object_decref(type);
        }
        i += 1;
    }
    return 0;
}

impl itertoolsmodule_free(mod: ptr) {
    itertoolsmodule_clear(ptr[PyObject](mod));
}

impl add_type(
    module: ptr[PyObject], slot: ptr[ptr[PyTypeObject]], spec: ptr[PyType_Spec]
) -> i32 {
    type = ptr[PyTypeObject](PyType_FromModuleAndSpec(module, spec, NULL));
    slot.view(1)[0] = type;
    if not type {
        return -1;
    }
    if PyModule_AddType(module, ptr[PyObject](type)) < 0 {
        return -1;
    }
    return 0;
}

impl itertoolsmodule_exec(mod: ptr[PyObject]) -> i32 {
    state = get_module_state(mod);
    slots = ptr[ptr[PyTypeObject]](state);
    if add_type(mod, slots + 0, addressof(accumulate_spec)) < 0
        or add_type(mod, slots + 1, addressof(batched_spec)) < 0
        or add_type(mod, slots + 2, addressof(chain_spec)) < 0
        or add_type(mod, slots + 3, addressof(combinations_spec)) < 0
        or add_type(mod, slots + 4, addressof(compress_spec)) < 0
        or add_type(mod, slots + 5, addressof(count_spec)) < 0
        or add_type(mod, slots + 6, addressof(cwr_spec)) < 0
        or add_type(mod, slots + 7, addressof(cycle_spec)) < 0
        or add_type(mod, slots + 8, addressof(dropwhile_spec)) < 0
        or add_type(mod, slots + 9, addressof(filterfalse_spec)) < 0
        or add_type(mod, slots + 10, addressof(groupby_spec)) < 0
        or add_type(mod, slots + 11, addressof(_grouper_spec)) < 0
        or add_type(mod, slots + 12, addressof(islice_spec)) < 0
        or add_type(mod, slots + 13, addressof(pairwise_spec)) < 0
        or add_type(mod, slots + 14, addressof(permutations_spec)) < 0
        or add_type(mod, slots + 15, addressof(product_spec)) < 0
        or add_type(mod, slots + 16, addressof(repeat_spec)) < 0
        or add_type(mod, slots + 17, addressof(starmap_spec)) < 0
        or add_type(mod, slots + 18, addressof(takewhile_spec)) < 0
        or add_type(mod, slots + 19, addressof(tee_spec)) < 0
        or add_type(mod, slots + 20, addressof(teedataobject_spec)) < 0
        or add_type(mod, slots + 21, addressof(ziplongest_spec)) < 0 {
        return -1;
    }
    teedata_type = state.view(1)[0].teedataobject_type;
    ptr[_object](teedata_type).view(1)[0].ob_type = ptr[PyTypeObject](
        addressof(PyType_Type)
    );

    _grouper_token.handle = ptr(addressof(_grouper_spec));
    _tee_token.handle = ptr(addressof(tee_spec));
    teedataobject_token.handle = ptr(addressof(teedataobject_spec));
    cycle_token.handle = ptr(addressof(cycle_spec));
    dropwhile_token.handle = ptr(addressof(dropwhile_spec));
    filterfalse_token.handle = ptr(addressof(filterfalse_spec));
    pairwise_token.handle = ptr(addressof(pairwise_spec));
    starmap_token.handle = ptr(addressof(starmap_spec));
    takewhile_token.handle = ptr(addressof(takewhile_spec));
    return 0;
}
