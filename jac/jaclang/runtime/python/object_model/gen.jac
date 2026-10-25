import from c {
    glob PyType_Type: PyTypeObject,
         _Py_TrueStruct: PyObject,
         _Py_FalseStruct: PyObject,
         PyExc_GeneratorExit: ptr[PyObject]; def _PyFrame_ClearExceptCode(
        frame: ptr[u8]
    );  def _PyFrame_MakeAndSetFrameObject(frame: ptr[u8]) -> ptr[PyObject];  def _PyFrame_Traverse(
        frame: ptr[u8], visitor: ptr, arg: ptr
    ) -> i32;  def _PyGC_VisitStackRef(ref: ptr[u64], visitor: ptr, arg: ptr) -> i32;  def _PyErr_ChainStackItem;  def _PyEval_NoToolsForUnwind(
        tstate: ptr[u8]
    ) -> bool;  def _PyEval_EvalFrameDefault(
        tstate: ptr[u8], frame: ptr[u8], throwflag: i32
    ) -> ptr[PyObject];  def _PyEval_GetFrame -> ptr[u8];  def _PyErr_WarnUnawaitedCoroutine(
        coro: ptr[PyObject]
    );  def _PyErr_WarnUnawaitedAgenMethod(
        agen: ptr[PyObject], method: ptr[PyObject]
    );  def PyUnstable_InterpreterFrame_GetLine(frame: ptr[u8]) -> i32;  obj EvalFrameHook {
        has call: Callable[[ptr[u8], ptr[u8], i32], ptr[PyObject]] = 0;
    }  glob:priv close_key: ptr[PyObject] = ptr[PyObject](),
         throw_key: ptr[PyObject] = ptr[PyObject](),
         asend_key: ptr[PyObject] = ptr[PyObject](),
         athrow_key: ptr[PyObject] = ptr[PyObject](),
         aclose_key: ptr[PyObject] = ptr[PyObject](),
         genexit_args: list[ptr[PyObject]] = [ptr[PyObject]()],
         gen_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__name__"),
                 get=gen_get_name,
                 set=gen_set_name,
                 doc=ptr[u8]("name of the generator")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__qualname__"),
                 get=gen_get_qualname,
                 set=gen_set_qualname,
                 doc=ptr[u8]("qualified name of the generator")
             ),
             PyGetSetDef(
                 name=ptr[u8]("gi_yieldfrom"),
                 get=gen_getyieldfrom,
                 doc=ptr[u8]("object being iterated by yield from, or None")
             ),
             PyGetSetDef(name=ptr[u8]("gi_running"), get=gen_getrunning),
             PyGetSetDef(name=ptr[u8]("gi_frame"), get=gen_getframe),
             PyGetSetDef(name=ptr[u8]("gi_suspended"), get=gen_getsuspended),
             PyGetSetDef(name=ptr[u8]("gi_code"), get=gen_getcode),
             PyGetSetDef()
         ],
         gen_memberlist: list[PyMemberDef] = [PyMemberDef()],
         gen_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(gen_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "send(value) -> send 'value' into generator,\n"
                     "return next yielded value or raise StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(gen_throw),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "throw(value)\n"
                     "throw(type[,value[,tb]])\n\n"
                     "Raise exception in generator, return next yielded value or raise\n"
                     "StopIteration.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(gen_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("close() -> raise GeneratorExit inside generator.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(gen_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("gen.__sizeof__() -> size of gen in memory, in bytes")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "generators are generic over the types of their yield, send, and return values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         gen_as_async: PyAsyncMethods = PyAsyncMethods(am_send=PyGen_am_send),
         coro_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__name__"),
                 get=gen_get_name,
                 set=gen_set_name,
                 doc=ptr[u8]("name of the coroutine")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__qualname__"),
                 get=gen_get_qualname,
                 set=gen_set_qualname,
                 doc=ptr[u8]("qualified name of the coroutine")
             ),
             PyGetSetDef(
                 name=ptr[u8]("cr_await"),
                 get=coro_get_cr_await,
                 doc=ptr[u8]("object being awaited on, or None")
             ),
             PyGetSetDef(name=ptr[u8]("cr_running"), get=cr_getrunning),
             PyGetSetDef(name=ptr[u8]("cr_frame"), get=cr_getframe),
             PyGetSetDef(name=ptr[u8]("cr_code"), get=cr_getcode),
             PyGetSetDef(name=ptr[u8]("cr_suspended"), get=cr_getsuspended),
             PyGetSetDef()
         ],
         coro_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("cr_origin"),
                 type_=_Py_T_OBJECT,
                 offset=PyGenObject_ORIGIN_OR_FINALIZER,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         coro_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(gen_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "send(arg) -> send 'arg' into coroutine,\n"
                     "return next iterated value or raise StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(gen_throw),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "throw(value)\n"
                     "throw(type[,value[,traceback]])\n\n"
                     "Raise exception in coroutine, return next iterated value or raise\n"
                     "StopIteration.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(gen_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("close() -> raise GeneratorExit inside coroutine.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(gen_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("gen.__sizeof__() -> size of gen in memory, in bytes")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "coroutines are generic over the types of their yield, send, and return values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         coro_as_async: PyAsyncMethods = PyAsyncMethods(
             am_await=coro_await, am_send=PyGen_am_send
         ),
         coro_wrapper_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(coro_wrapper_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "send(arg) -> send 'arg' into coroutine,\n"
                     "return next iterated value or raise StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(coro_wrapper_throw),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "throw(value)\n"
                     "throw(type[,value[,traceback]])\n\n"
                     "Raise exception in coroutine, return next iterated value or raise\n"
                     "StopIteration.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(coro_wrapper_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("close() -> raise GeneratorExit inside coroutine.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         async_gen_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__name__"),
                 get=gen_get_name,
                 set=gen_set_name,
                 doc=ptr[u8]("name of the async generator")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__qualname__"),
                 get=gen_get_qualname,
                 set=gen_set_qualname,
                 doc=ptr[u8]("qualified name of the async generator")
             ),
             PyGetSetDef(
                 name=ptr[u8]("ag_await"),
                 get=coro_get_cr_await,
                 doc=ptr[u8]("object being awaited on, or None")
             ),
             PyGetSetDef(name=ptr[u8]("ag_frame"), get=ag_getframe),
             PyGetSetDef(name=ptr[u8]("ag_code"), get=ag_getcode),
             PyGetSetDef(name=ptr[u8]("ag_suspended"), get=ag_getsuspended),
             PyGetSetDef()
         ],
         async_gen_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("ag_running"),
                 type_=Py_T_BOOL,
                 offset=PyGenObject_RUNNING_ASYNC,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         async_gen_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("asend"),
                 ml_meth=ptr(async_gen_asend),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("asend(v) -> send 'v' in generator.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("athrow"),
                 ml_meth=ptr(async_gen_athrow),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "athrow(value)\n"
                     "athrow(type[,value[,tb]])\n\n"
                     "raise exception in generator.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("aclose"),
                 ml_meth=ptr(async_gen_aclose),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("aclose() -> raise GeneratorExit inside generator.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(gen_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("gen.__sizeof__() -> size of gen in memory, in bytes")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "async generators are generic over the types of their yield and send values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         async_gen_as_async: PyAsyncMethods = PyAsyncMethods(
             am_aiter=PyObject_SelfIter, am_anext=async_gen_anext, am_send=PyGen_am_send
         ),
         async_gen_asend_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(async_gen_asend_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "send(value) -> send 'value' into generator,\n"
                     "return next yielded value or raise StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(async_gen_asend_throw),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "throw(value)\n"
                     "throw(type[,value[,tb]])\n\n"
                     "Raise exception in generator, return next yielded value or raise\n"
                     "StopIteration.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(async_gen_asend_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("close() -> raise GeneratorExit inside generator.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         async_gen_asend_as_async: PyAsyncMethods = PyAsyncMethods(
             am_await=PyObject_SelfIter
         ),
         async_gen_athrow_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(async_gen_athrow_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "send(value) -> send 'value' into generator,\n"
                     "return next yielded value or raise StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(async_gen_athrow_throw),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "throw(value)\n"
                     "throw(type[,value[,tb]])\n\n"
                     "Raise exception in generator, return next yielded value or raise\n"
                     "StopIteration.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(async_gen_athrow_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("close() -> raise GeneratorExit inside generator.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         async_gen_athrow_as_async: PyAsyncMethods = PyAsyncMethods(
             am_await=PyObject_SelfIter
         ); glob PyGen_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("generator"),
             tp_basicsize=PyGenObject_SIZE,
             tp_itemsize=8,
             tp_dealloc=gen_dealloc,
             tp_as_async=addressof(gen_as_async),
             tp_repr=gen_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=gen_traverse,
             tp_weaklistoffset=PyGenObject_WEAKREFLIST,
             tp_iter=PyObject_SelfIter,
             tp_iternext=gen_iternext,
             tp_methods=addressof(gen_methods),
             tp_members=addressof(gen_memberlist),
             tp_getset=addressof(gen_getsetlist),
             tp_finalize=_PyGen_Finalize
         ),
         PyCoro_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("coroutine"),
             tp_basicsize=PyGenObject_SIZE,
             tp_itemsize=8,
             tp_dealloc=gen_dealloc,
             tp_as_async=addressof(coro_as_async),
             tp_repr=coro_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=gen_traverse,
             tp_weaklistoffset=PyGenObject_WEAKREFLIST,
             tp_methods=addressof(coro_methods),
             tp_members=addressof(coro_memberlist),
             tp_getset=addressof(coro_getsetlist),
             tp_finalize=_PyGen_Finalize
         ),
         _PyCoroWrapper_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("coroutine_wrapper"),
             tp_basicsize=PyCoroWrapper_SIZE,
             tp_dealloc=coro_wrapper_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("A wrapper object implementing __await__ for coroutines."),
             tp_traverse=coro_wrapper_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=coro_wrapper_iternext,
             tp_methods=addressof(coro_wrapper_methods)
         ),
         PyAsyncGen_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("async_generator"),
             tp_basicsize=PyGenObject_SIZE,
             tp_itemsize=8,
             tp_dealloc=gen_dealloc,
             tp_as_async=addressof(async_gen_as_async),
             tp_repr=async_gen_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=async_gen_traverse,
             tp_weaklistoffset=PyGenObject_WEAKREFLIST,
             tp_methods=addressof(async_gen_methods),
             tp_members=addressof(async_gen_memberlist),
             tp_getset=addressof(async_gen_getsetlist),
             tp_finalize=_PyGen_Finalize
         ),
         _PyAsyncGenASend_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("async_generator_asend"),
             tp_basicsize=PyAsyncGenASend_SIZE,
             tp_dealloc=async_gen_asend_dealloc,
             tp_as_async=addressof(async_gen_asend_as_async),
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=async_gen_asend_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=async_gen_asend_iternext,
             tp_methods=addressof(async_gen_asend_methods),
             tp_finalize=async_gen_asend_finalize
         ),
         _PyAsyncGenWrappedValue_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("async_generator_wrapped_value"),
             tp_basicsize=_PyAsyncGenWrappedValue_SIZE,
             tp_dealloc=async_gen_wrapped_val_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=async_gen_wrapped_val_traverse
         ),
         _PyAsyncGenAThrow_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("async_generator_athrow"),
             tp_basicsize=PyAsyncGenAThrow_SIZE,
             tp_dealloc=async_gen_athrow_dealloc,
             tp_as_async=addressof(async_gen_athrow_as_async),
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=async_gen_athrow_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=async_gen_athrow_iternext,
             tp_methods=addressof(async_gen_athrow_methods),
             tp_finalize=async_gen_athrow_finalize
         );
}

glob:priv AWAITABLE_STATE_INIT: i32 = 0,
     AWAITABLE_STATE_ITER: i32 = 1,
     AWAITABLE_STATE_CLOSED: i32 = 2,
     STACKREF_NULL: u64 = u64(1),
     STACKREF_TAG_BITS: u64 = u64(3),
     STACKREF_TAG_REFCNT: u64 = u64(1),
     STACKREF_INT_TAG: u64 = u64(3),
     ID_CLOSE: i64 = 0,
     ID_THROW: i64 = 1,
     ID_ASEND: i64 = 2,
     ID_ATHROW: i64 = 3,
     ID_ACLOSE: i64 = 4;

def thread_state -> ptr[u8];

def slot_get(op: ptr[PyObject], offset: i64) -> ptr[PyObject];

def slot_set(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def slot_clear(op: ptr[PyObject], offset: i64);

def slot_u8(op: ptr[PyObject], offset: i64) -> u8;

def slot_set_u8(op: ptr[PyObject], offset: i64, value: u8);

def slot_i32(op: ptr[PyObject], offset: i64) -> i32;

def slot_set_i32(op: ptr[PyObject], offset: i64, value: i32);

def xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def bool_object(flag: bool) -> ptr[PyObject];

def unicode_check(op: ptr[PyObject]) -> bool;

def gen_id(which: i64) -> ptr[PyObject];

def gen_check_exact(op: ptr[PyObject]) -> bool;

def coro_check_exact(op: ptr[PyObject]) -> bool;

def async_gen_check_exact(op: ptr[PyObject]) -> bool;

def wrapped_value_check_exact(op: ptr[PyObject]) -> bool;

def gen_frame_state(gen: ptr[PyObject]) -> i32;

def set_gen_frame_state(gen: ptr[PyObject], state: i32);

def frame_state_suspended(state: i32) -> bool;

def frame_state_finished(state: i32) -> bool;

def gen_iframe(gen: ptr[PyObject]) -> ptr[u8];

def object_is_immortal(op: ptr[PyObject]) -> bool;

def stackref_borrow(bits: u64) -> ptr[PyObject];

def stackref_is_heap_safe(bits: u64) -> bool;

def stackref_make_heap_safe(bits: u64) -> u64;

def stackref_clear(slot: ptr[u64]);

def frame_ref(frame: ptr[u8], offset: i64) -> u64;

def set_frame_ref(frame: ptr[u8], offset: i64, bits: u64);

def frame_ptr(frame: ptr[u8], offset: i64) -> ptr[u8];

def set_frame_ptr(frame: ptr[u8], offset: i64, value: ptr[u8]);

def frame_code(frame: ptr[u8]) -> ptr[PyObject];

def frame_stack_peek(frame: ptr[u8]) -> u64;

def frame_num_slots(code: ptr[PyObject]) -> i32;

def frame_copy(src: ptr[u8], dest: ptr[u8]);

def frame_is_incomplete(frame: ptr[u8]) -> bool;

def frame_first_complete(frame: ptr[u8]) -> ptr[u8];

def frame_get_frame_object(frame: ptr[u8]) -> ptr[PyObject];

def gen_code(gen: ptr[PyObject]) -> ptr[PyObject];

def gen_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def gen_clear_frame(gen: ptr[PyObject]);

def gen_dealloc(self: ptr[PyObject]);

def gen_send_ex2(
    gen: ptr[PyObject], arg: ptr[PyObject], exc: i32, closing: i32
) -> tuple[i32, ptr[PyObject]];

def PyGen_am_send(
    self: ptr[PyObject], arg: ptr[PyObject], presult: ptr[ptr[PyObject]]
) -> i32;

def gen_send_ex(
    gen: ptr[PyObject], arg: ptr[PyObject], exc: i32, closing: i32
) -> ptr[PyObject];

def gen_send(gen: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def gen_close_iter(yf: ptr[PyObject]) -> i32;

def is_resume(instr: ptr[u8]) -> bool;

def gen_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def gen_throw_impl(
    gen: ptr[PyObject],
    close_on_genexit: i32,
    typ_in: ptr[PyObject],
    val_in: ptr[PyObject],
    tb_in: ptr[PyObject]
) -> ptr[PyObject];

def gen_throw_here(
    gen: ptr[PyObject],
    typ_in: ptr[PyObject],
    val_in: ptr[PyObject],
    tb_in: ptr[PyObject]
) -> ptr[PyObject];

def gen_throw(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def gen_iternext(self: ptr[PyObject]) -> ptr[PyObject];

def set_stop_iteration_value(value: ptr[PyObject]) -> i32;

def fetch_stop_iteration_value -> tuple[i32, ptr[PyObject]];

def gen_repr(self: ptr[PyObject]) -> ptr[PyObject];

def gen_get_name(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_set_name(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def gen_get_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_set_qualname(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def gen_getyieldfrom(gen: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_getrunning(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_getsuspended(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_getframe_named(gen: ptr[PyObject], name: str) -> ptr[PyObject];

def gen_getframe(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_getcode_named(gen: ptr[PyObject], name: str) -> ptr[PyObject];

def gen_getcode(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def gen_sizeof(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def make_gen(type: ptr[PyTypeObject], func: ptr[PyObject]) -> ptr[PyObject];

def compute_cr_origin(origin_depth: i32, current_frame: ptr[u8]) -> ptr[PyObject];

def gen_new_with_qualname(
    type: ptr[PyTypeObject],
    f: ptr[PyObject],
    name: ptr[PyObject],
    qualname: ptr[PyObject]
) -> ptr[PyObject];

def gen_is_coroutine(o: ptr[PyObject]) -> bool;

def coro_repr(self: ptr[PyObject]) -> ptr[PyObject];

def coro_await(coro: ptr[PyObject]) -> ptr[PyObject];

def coro_get_cr_await(coro: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cr_getsuspended(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cr_getrunning(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cr_getframe(coro: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cr_getcode(coro: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def coro_wrapper_dealloc(self: ptr[PyObject]);

def coro_wrapper_iternext(self: ptr[PyObject]) -> ptr[PyObject];

def coro_wrapper_send(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def coro_wrapper_throw(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def coro_wrapper_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def coro_wrapper_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def async_gen_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def async_gen_repr(self: ptr[PyObject]) -> ptr[PyObject];

def async_gen_init_hooks(o: ptr[PyObject]) -> i32;

def async_gen_anext(self: ptr[PyObject]) -> ptr[PyObject];

def async_gen_asend(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def async_gen_aclose(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def async_gen_athrow(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def ag_getframe(ag: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def ag_getcode(gen: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def ag_getsuspended(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def async_gen_unwrap_value(gen: ptr[PyObject], result: ptr[PyObject]) -> ptr[PyObject];

def async_gen_asend_dealloc(self: ptr[PyObject]);

def async_gen_asend_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def async_gen_asend_send(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def async_gen_asend_iternext(ags: ptr[PyObject]) -> ptr[PyObject];

def async_gen_asend_throw(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def async_gen_asend_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def async_gen_asend_finalize(self: ptr[PyObject]);

def async_gen_asend_new(gen: ptr[PyObject], sendval: ptr[PyObject]) -> ptr[PyObject];

def async_gen_wrapped_val_dealloc(self: ptr[PyObject]);

def async_gen_wrapped_val_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def async_gen_athrow_dealloc(self: ptr[PyObject]);

def async_gen_athrow_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def athrow_yield_close(o: ptr[PyObject]) -> ptr[PyObject];

def athrow_check_error(o: ptr[PyObject]) -> ptr[PyObject];

def async_gen_athrow_send(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def async_gen_athrow_throw(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def async_gen_athrow_iternext(agt: ptr[PyObject]) -> ptr[PyObject];

def async_gen_athrow_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def async_gen_athrow_finalize(op: ptr[PyObject]);

def async_gen_athrow_new(gen: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def genexit_arg_vector -> ptr[ptr[PyObject]];

import from c {
    def PyGen_GetCode(gen: ptr[PyObject]) -> ptr[PyObject] {
        res = gen_code(gen);
        object_incref(res);
        return res;
    }  def _PyGen_Finalize(self: ptr[PyObject]) -> None {
        if frame_state_finished(gen_frame_state(self)) {
            return;
        }

        if async_gen_check_exact(self) {
            finalizer = slot_get(self, PyGenObject_ORIGIN_OR_FINALIZER);
            if finalizer and slot_u8(self, PyGenObject_CLOSED) == u8(0) {
                saved = PyErr_GetRaisedException();
                res = PyObject_CallOneArg(finalizer, self);
                if not res {
                    PyErr_FormatUnraisable(
                        "Exception ignored while finalizing generator %R", self
                    );
                } else {
                    object_decref(res);
                }
                PyErr_SetRaisedException(saved);
                return;
            }
        }

        exc = PyErr_GetRaisedException();

        if (code_flags(gen_code(self)) & CO_COROUTINE) != 0
            and gen_frame_state(self) == FRAME_CREATED {
            _PyErr_WarnUnawaitedCoroutine(self);
        } else {
            res = gen_close(self, NULL);
            if not res {
                if PyErr_Occurred() {
                    PyErr_FormatUnraisable(
                        "Exception ignored while closing generator %R", self
                    );
                }
            } else {
                object_decref(res);
            }
        }

        PyErr_SetRaisedException(exc);
    }  def _PyGen_yf(gen: ptr[PyObject]) -> ptr[PyObject] {
        if gen_frame_state(gen) == FRAME_SUSPENDED_YIELD_FROM {
            yf = stackref_borrow(frame_stack_peek(gen_iframe(gen)));
            object_incref(yf);
            return yf;
        }
        return NULL;
    }  def _PyGen_SetStopIterationValue(value: ptr[PyObject]) -> i32 {
        return set_stop_iteration_value(value);
    }  def _PyGen_FetchStopIterationValue(pvalue: ptr[ptr[PyObject]]) -> i32 {
        (status, value) = fetch_stop_iteration_value();
        if status == i32(0) {
            pvalue.view(1)[0] = value;
        }
        return status;
    }  def _Py_MakeCoro(func: ptr[PyObject]) -> ptr[PyObject] {
        code = slot_get(func, PyFunctionObject_CODE);
        coro_flags = code_flags(code)
            & (CO_GENERATOR | CO_COROUTINE | CO_ASYNC_GENERATOR);
        if coro_flags == CO_GENERATOR {
            return make_gen(addressof(PyGen_Type), func);
        }
        if coro_flags == CO_ASYNC_GENERATOR {
            ag = make_gen(addressof(PyAsyncGen_Type), func);
            if not ag {
                return NULL;
            }
            slot_set(ag, PyGenObject_ORIGIN_OR_FINALIZER, NULL);
            slot_set_u8(ag, PyGenObject_CLOSED, u8(0));
            slot_set_u8(ag, PyGenObject_HOOKS_INITED, u8(0));
            slot_set_u8(ag, PyGenObject_RUNNING_ASYNC, u8(0));
            return ag;
        }

        coro = make_gen(addressof(PyCoro_Type), func);
        if not coro {
            return NULL;
        }
        tstate = thread_state();
        origin_depth = ptr[i32](
            tstate + PyThreadState_COROUTINE_ORIGIN_TRACKING_DEPTH
        ).view(
            1
        )[0];

        if origin_depth == i32(0) {
            slot_set(coro, PyGenObject_ORIGIN_OR_FINALIZER, NULL);
        } else {
            frame = ptr[ptr[u8]](tstate + PyThreadState_CURRENT_FRAME).view(1)[0];
            frame = frame_first_complete(
                frame_ptr(frame, _PyInterpreterFrame_PREVIOUS)
            );
            cr_origin = compute_cr_origin(origin_depth, frame);
            slot_set(coro, PyGenObject_ORIGIN_OR_FINALIZER, cr_origin);
            if not cr_origin {
                object_decref(coro);
                return NULL;
            }
        }
        return coro;
    }  def PyGen_NewWithQualName(
        f: ptr[PyObject], name: ptr[PyObject], qualname: ptr[PyObject]
    ) -> ptr[PyObject] {
        return gen_new_with_qualname(addressof(PyGen_Type), f, name, qualname);
    }  def PyGen_New(f: ptr[PyObject]) -> ptr[PyObject] {
        return gen_new_with_qualname(addressof(PyGen_Type), f, NULL, NULL);
    }  def _PyCoro_GetAwaitableIter(o: ptr[PyObject]) -> ptr[PyObject] {
        if coro_check_exact(o) or gen_is_coroutine(o) {
            object_incref(o);
            return o;
        }

        ot = object_type(o);
        am = ot.view(1)[0].tp_as_async;
        if am and int(am.view(1)[0].am_await) != 0 {
            res = am.view(1)[0].am_await(o);
            if res {
                if coro_check_exact(res) or gen_is_coroutine(res) {
                    PyErr_SetString(
                        PyExc_TypeError, "__await__() returned a coroutine"
                    );
                    object_decref(res);
                    res = NULL;
                } elif PyIter_Check(res) == 0 {
                    PyErr_Format(
                        PyExc_TypeError,
                        "__await__() returned non-iterator of type '%.100s'",
                        object_type(res).view(1)[0].tp_name
                    );
                    object_decref(res);
                    res = NULL;
                }
            }
            return res;
        }

        PyErr_Format(
            PyExc_TypeError, "'%.100s' object can't be awaited", ot.view(1)[0].tp_name
        );
        return NULL;
    }  def PyCoro_New(
        f: ptr[PyObject], name: ptr[PyObject], qualname: ptr[PyObject]
    ) -> ptr[PyObject] {
        coro = gen_new_with_qualname(addressof(PyCoro_Type), f, name, qualname);
        if not coro {
            return NULL;
        }

        tstate = thread_state();
        origin_depth = ptr[i32](
            tstate + PyThreadState_COROUTINE_ORIGIN_TRACKING_DEPTH
        ).view(
            1
        )[0];

        if origin_depth == i32(0) {
            slot_set(coro, PyGenObject_ORIGIN_OR_FINALIZER, NULL);
        } else {
            cr_origin = compute_cr_origin(origin_depth, _PyEval_GetFrame());
            slot_set(coro, PyGenObject_ORIGIN_OR_FINALIZER, cr_origin);
            if not cr_origin {
                object_decref(coro);
                return NULL;
            }
        }
        return coro;
    }  def PyAsyncGen_New(
        f: ptr[PyObject], name: ptr[PyObject], qualname: ptr[PyObject]
    ) -> ptr[PyObject] {
        ag = gen_new_with_qualname(addressof(PyAsyncGen_Type), f, name, qualname);
        if not ag {
            return NULL;
        }
        slot_set(ag, PyGenObject_ORIGIN_OR_FINALIZER, NULL);
        slot_set_u8(ag, PyGenObject_CLOSED, u8(0));
        slot_set_u8(ag, PyGenObject_HOOKS_INITED, u8(0));
        slot_set_u8(ag, PyGenObject_RUNNING_ASYNC, u8(0));
        return ag;
    }  def _PyAsyncGenValueWrapperNew(
        tstate: ptr, val: ptr[PyObject]
    ) -> ptr[PyObject] {
        o = freelist_pop(_Py_freelists_ASYNC_GENS);
        if not o {
            o = _PyObject_GC_New(
                ptr[PyObject](addressof(_PyAsyncGenWrappedValue_Type))
            );
            if not o {
                return NULL;
            }
        }
        object_incref(val);
        slot_set(o, _PyAsyncGenWrappedValue_AGW_VAL, val);
        object_gc_track(o);
        return o;
    }
}

def code_flags(code: ptr[PyObject]) -> i32;

def code_i32(code: ptr[PyObject], offset: i64) -> i32;

impl code_flags(code: ptr[PyObject]) -> i32 {
    return ptr[i32](ptr[u8](code) + PyCodeObject_FLAGS).view(1)[0];
}

impl code_i32(code: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](code) + offset).view(1)[0];
}

impl thread_state -> ptr[u8] {
    return ptr[u8](current_tstate());
}

impl slot_get(op: ptr[PyObject], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0];
}

impl slot_set(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0] = value;
}

impl slot_clear(op: ptr[PyObject], offset: i64) {
    old = slot_get(op, offset);
    if old {
        slot_set(op, offset, NULL);
        object_decref(old);
    }
}

impl slot_u8(op: ptr[PyObject], offset: i64) -> u8 {
    return (ptr[u8](op) + offset).view(1)[0];
}

impl slot_set_u8(op: ptr[PyObject], offset: i64, value: u8) {
    (ptr[u8](op) + offset).view(1)[0] = value;
}

impl slot_i32(op: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](op) + offset).view(1)[0];
}

impl slot_set_i32(op: ptr[PyObject], offset: i64, value: i32) {
    ptr[i32](ptr[u8](op) + offset).view(1)[0] = value;
}

impl xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl bool_object(flag: bool) -> ptr[PyObject] {
    if flag {
        return addressof(_Py_TrueStruct);
    }
    return addressof(_Py_FalseStruct);
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl gen_id(which: i64) -> ptr[PyObject] {
    if which == ID_CLOSE {
        if not close_key {
            close_key = PyUnicode_InternFromString(ptr[u8]("close"));
        }
        return close_key;
    }
    if which == ID_THROW {
        if not throw_key {
            throw_key = PyUnicode_InternFromString(ptr[u8]("throw"));
        }
        return throw_key;
    }
    if which == ID_ASEND {
        if not asend_key {
            asend_key = PyUnicode_InternFromString(ptr[u8]("asend"));
        }
        return asend_key;
    }
    if which == ID_ATHROW {
        if not athrow_key {
            athrow_key = PyUnicode_InternFromString(ptr[u8]("athrow"));
        }
        return athrow_key;
    }
    if not aclose_key {
        aclose_key = PyUnicode_InternFromString(ptr[u8]("aclose"));
    }
    return aclose_key;
}

impl gen_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyGen_Type));
}

impl coro_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyCoro_Type));
}

impl async_gen_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyAsyncGen_Type));
}

impl wrapped_value_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(_PyAsyncGenWrappedValue_Type));
}

impl gen_frame_state(gen: ptr[PyObject]) -> i32 {
    return i32(ptr[i8](ptr[u8](gen) + PyGenObject_FRAME_STATE).view(1)[0]);
}

impl set_gen_frame_state(gen: ptr[PyObject], state: i32) {
    ptr[i8](ptr[u8](gen) + PyGenObject_FRAME_STATE).view(1)[0] = i8(state);
}

impl frame_state_suspended(state: i32) -> bool {
    return state == FRAME_SUSPENDED or state == FRAME_SUSPENDED_YIELD_FROM;
}

impl frame_state_finished(state: i32) -> bool {
    return state >= FRAME_COMPLETED;
}

impl gen_iframe(gen: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](gen) + PyGenObject_IFRAME;
}

impl object_is_immortal(op: ptr[PyObject]) -> bool {
    return (ptr[_object](op).view(1)[0].ob_refcnt_full & 0x80000000) != 0;
}

impl stackref_borrow(bits: u64) -> ptr[PyObject] {
    return ptr[PyObject](i64.wrap(bits & u64(0xFFFFFFFFFFFFFFFE)));
}

impl stackref_is_heap_safe(bits: u64) -> bool {
    return (bits & STACKREF_TAG_BITS) != STACKREF_TAG_REFCNT
        or bits == STACKREF_NULL
        or object_is_immortal(stackref_borrow(bits));
}

impl stackref_make_heap_safe(bits: u64) -> u64 {
    if stackref_is_heap_safe(bits) {
        return bits;
    }
    op = stackref_borrow(bits);
    object_incref(op);
    return u64.wrap(int(op));
}

impl stackref_clear(slot: ptr[u64]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = STACKREF_NULL;
    if (old & STACKREF_TAG_REFCNT) == u64(0) {
        object_decref(ptr[PyObject](i64.wrap(old)));
    }
}

impl frame_ref(frame: ptr[u8], offset: i64) -> u64 {
    return ptr[u64](frame + offset).view(1)[0];
}

impl set_frame_ref(frame: ptr[u8], offset: i64, bits: u64) {
    ptr[u64](frame + offset).view(1)[0] = bits;
}

impl frame_ptr(frame: ptr[u8], offset: i64) -> ptr[u8] {
    return ptr[ptr[u8]](frame + offset).view(1)[0];
}

impl set_frame_ptr(frame: ptr[u8], offset: i64, value: ptr[u8]) {
    ptr[ptr[u8]](frame + offset).view(1)[0] = value;
}

impl frame_code(frame: ptr[u8]) -> ptr[PyObject] {
    return stackref_borrow(frame_ref(frame, _PyInterpreterFrame_F_EXECUTABLE));
}

impl frame_stack_peek(frame: ptr[u8]) -> u64 {
    sp = ptr[u64](frame_ptr(frame, _PyInterpreterFrame_STACKPOINTER));
    return (sp - 1).view(1)[0];
}

impl frame_num_slots(code: ptr[PyObject]) -> i32 {
    return code_i32(code, PyCodeObject_FRAMESIZE) - FRAME_SPECIALS_SIZE;
}

impl frame_copy(src: ptr[u8], dest: ptr[u8]) {
    set_frame_ref(
        dest,
        _PyInterpreterFrame_F_EXECUTABLE,
        stackref_make_heap_safe(frame_ref(src, _PyInterpreterFrame_F_EXECUTABLE))
    );
    set_frame_ptr(dest, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
    set_frame_ref(
        dest,
        _PyInterpreterFrame_F_FUNCOBJ,
        stackref_make_heap_safe(frame_ref(src, _PyInterpreterFrame_F_FUNCOBJ))
    );
    set_frame_ptr(
        dest,
        _PyInterpreterFrame_F_GLOBALS,
        frame_ptr(src, _PyInterpreterFrame_F_GLOBALS)
    );
    set_frame_ptr(
        dest,
        _PyInterpreterFrame_F_BUILTINS,
        frame_ptr(src, _PyInterpreterFrame_F_BUILTINS)
    );
    set_frame_ptr(
        dest, _PyInterpreterFrame_F_LOCALS, frame_ptr(src, _PyInterpreterFrame_F_LOCALS)
    );
    set_frame_ptr(
        dest,
        _PyInterpreterFrame_FRAME_OBJ,
        frame_ptr(src, _PyInterpreterFrame_FRAME_OBJ)
    );
    set_frame_ptr(
        dest,
        _PyInterpreterFrame_INSTR_PTR,
        frame_ptr(src, _PyInterpreterFrame_INSTR_PTR)
    );
    src_locals = ptr[u64](src + _PyInterpreterFrame_LOCALSPLUS);
    dest_locals = ptr[u64](dest + _PyInterpreterFrame_LOCALSPLUS);
    stacktop = i64(
        (int(frame_ptr(src, _PyInterpreterFrame_STACKPOINTER)) - int(src_locals)) // 8
    );
    set_frame_ptr(
        dest, _PyInterpreterFrame_STACKPOINTER, ptr[u8](dest_locals + stacktop)
    );
    (dest + _PyInterpreterFrame_VISITED).view(1)[0] = u8(0);
    i: i64 = 0;
    while i < stacktop {
        (dest_locals + i).view(1)[0] = stackref_make_heap_safe(
            (src_locals + i).view(1)[0]
        );
        i += 1;
    }
}

impl frame_is_incomplete(frame: ptr[u8]) -> bool {
    owner = i32((frame + _PyInterpreterFrame_OWNER).view(1)[0]);
    if owner >= FRAME_OWNED_BY_INTERPRETER {
        return True;
    }
    if owner == FRAME_OWNED_BY_GENERATOR {
        return False;
    }
    code = frame_code(frame);
    first = i64(code_i32(code, PyCodeObject_FIRSTTRACEABLE));
    bytecode = int(code) + PyCodeObject_CODE_ADAPTIVE;
    return int(frame_ptr(frame, _PyInterpreterFrame_INSTR_PTR)) < bytecode + first * 2;
}

impl frame_first_complete(frame: ptr[u8]) -> ptr[u8] {
    current = frame;
    while current and frame_is_incomplete(current) {
        current = frame_ptr(current, _PyInterpreterFrame_PREVIOUS);
    }
    return current;
}

impl frame_get_frame_object(frame: ptr[u8]) -> ptr[PyObject] {
    res = ptr[PyObject](frame_ptr(frame, _PyInterpreterFrame_FRAME_OBJ));
    if res {
        return res;
    }
    return _PyFrame_MakeAndSetFrameObject(frame);
}

impl gen_code(gen: ptr[PyObject]) -> ptr[PyObject] {
    return frame_code(gen_iframe(gen));
}

impl gen_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(slot_get(self, PyGenObject_NAME), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(slot_get(self, PyGenObject_QUALNAME), visitor, arg);
    if status != 0 {
        return status;
    }
    frame = gen_iframe(self);
    if gen_frame_state(self) != FRAME_CLEARED {
        err = _PyFrame_Traverse(frame, visitor, arg);
        if err != 0 {
            return err;
        }
    } else {
        bits = frame_ref(frame, _PyInterpreterFrame_F_EXECUTABLE);
        if bits != STACKREF_NULL and (bits & STACKREF_INT_TAG) != STACKREF_INT_TAG {
            vret = _PyGC_VisitStackRef(
                ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE), visitor, arg
            );
            if vret != 0 {
                return vret;
            }
        }
    }
    return visit_reference(slot_get(self, PyGenObject_EXC_VALUE), visitor, arg);
}

impl gen_clear_frame(gen: ptr[PyObject]) {
    if gen_frame_state(gen) == FRAME_CLEARED {
        return;
    }
    set_gen_frame_state(gen, FRAME_CLEARED);
    frame = gen_iframe(gen);
    set_frame_ptr(frame, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
    _PyFrame_ClearExceptCode(frame);
    slot_clear(gen, PyGenObject_EXC_VALUE);
}

impl gen_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    if slot_get(self, PyGenObject_WEAKREFLIST) {
        PyObject_ClearWeakRefs(self);
    }
    object_gc_track(self);
    if PyObject_CallFinalizerFromDealloc(self) != 0 {
        return;
    }
    object_gc_untrack(self);
    if async_gen_check_exact(self) {
        slot_clear(self, PyGenObject_ORIGIN_OR_FINALIZER);
    }
    if coro_check_exact(self) {
        slot_clear(self, PyGenObject_ORIGIN_OR_FINALIZER);
    }
    gen_clear_frame(self);
    stackref_clear(ptr[u64](gen_iframe(self) + _PyInterpreterFrame_F_EXECUTABLE));
    slot_clear(self, PyGenObject_NAME);
    slot_clear(self, PyGenObject_QUALNAME);
    PyObject_GC_Del(ptr(self));
}

impl gen_send_ex2(
    gen: ptr[PyObject], arg: ptr[PyObject], exc: i32, closing: i32
) -> tuple[i32, ptr[PyObject]] {
    tstate = ptr[u8](current_tstate());
    base = ptr[u8](gen);
    frame = base + PyGenObject_IFRAME;
    state_slot = ptr[i8](base + PyGenObject_FRAME_STATE);
    state = i32(state_slot.view(1)[0]);

    if state == FRAME_CREATED and arg and arg != Py_None {
        if coro_check_exact(gen) {
            PyErr_SetString(
                PyExc_TypeError, "can't send non-None value to a just-started coroutine"
            );
        } elif async_gen_check_exact(gen) {
            PyErr_SetString(
                PyExc_TypeError,
                "can't send non-None value to a just-started async generator"
            );
        } else {
            PyErr_SetString(
                PyExc_TypeError, "can't send non-None value to a just-started generator"
            );
        }
        return (PYGEN_ERROR, NULL);
    }
    if state == FRAME_EXECUTING {
        if coro_check_exact(gen) {
            PyErr_SetString(PyExc_ValueError, "coroutine already executing");
        } elif async_gen_check_exact(gen) {
            PyErr_SetString(PyExc_ValueError, "async generator already executing");
        } else {
            PyErr_SetString(PyExc_ValueError, "generator already executing");
        }
        return (PYGEN_ERROR, NULL);
    }
    if state >= FRAME_COMPLETED {
        if coro_check_exact(gen) and closing == i32(0) {
            PyErr_SetString(
                PyExc_RuntimeError, "cannot reuse already awaited coroutine"
            );
        } elif arg and exc == i32(0) {
            return (PYGEN_RETURN, object_new_ref(Py_None));
        }
        return (PYGEN_ERROR, NULL);
    }

    arg_obj = arg;
    if not arg_obj {
        arg_obj = Py_None;
    }
    header = ptr[_object](arg_obj);
    full = header.view(1)[0].ob_refcnt_full;
    bits = u64.wrap(int(arg_obj));
    if (full & 0x80000000) != 0 {
        bits = bits | STACKREF_TAG_REFCNT;
    } else {
        header.view(1)[0].ob_refcnt_full = full + 1;
    }
    sp_slot = ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER);
    sp = sp_slot.view(1)[0];
    sp.view(1)[0] = bits;
    sp_slot.view(1)[0] = sp + 1;

    exc_info = ptr[ptr[u8]](tstate + PyThreadState_EXC_INFO);
    ptr[ptr[u8]](base + PyGenObject_EXC_PREVIOUS_ITEM).view(1)[0] = exc_info.view(1)[0];
    exc_info.view(1)[0] = base + PyGenObject_EXC_STATE;

    if exc != i32(0) {
        _PyErr_ChainStackItem();
    }

    state_slot.view(1)[0] = i8(FRAME_EXECUTING);
    interp = ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
    hook = ptr[EvalFrameHook](interp + PyInterpreterState_EVAL_FRAME);
    result: ptr[PyObject] = NULL;
    if int(hook.view(1)[0].call) == 0 {
        result = _PyEval_EvalFrameDefault(tstate, frame, exc);
    } else {
        result = hook.view(1)[0].call(tstate, frame, exc);
    }

    if result {
        state = i32(state_slot.view(1)[0]);
        if state == FRAME_SUSPENDED or state == FRAME_SUSPENDED_YIELD_FROM {
            return (PYGEN_NEXT, result);
        }
        if result == Py_None
            and ptr[_object](gen).view(1)[0].ob_type != addressof(PyAsyncGen_Type)
            and not arg {
            object_decref(result);
            result = NULL;
        }
    }

    if result {
        return (PYGEN_RETURN, result);
    }
    return (PYGEN_ERROR, result);
}

impl PyGen_am_send(
    self: ptr[PyObject], arg: ptr[PyObject], presult: ptr[ptr[PyObject]]
) -> i32 {
    (status, result) = gen_send_ex2(self, arg, i32(0), i32(0));
    presult.view(1)[0] = result;
    return status;
}

impl gen_send_ex(
    gen: ptr[PyObject], arg: ptr[PyObject], exc: i32, closing: i32
) -> ptr[PyObject] {
    (status, result) = gen_send_ex2(gen, arg, exc, closing);
    if status == PYGEN_RETURN {
        if async_gen_check_exact(gen) {
            PyErr_SetNone(PyExc_StopAsyncIteration);
        } elif result == Py_None {
            PyErr_SetNone(PyExc_StopIteration);
        } else {
            set_stop_iteration_value(result);
        }
        object_decref(result);
        return NULL;
    }
    return result;
}

impl gen_send(gen: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return gen_send_ex(gen, arg, i32(0), i32(0));
}

impl gen_close_iter(yf: ptr[PyObject]) -> i32 {
    retval: ptr[PyObject] = NULL;

    if gen_check_exact(yf) or coro_check_exact(yf) {
        retval = gen_close(yf, NULL);
        if not retval {
            return i32(-1);
        }
    } else {
        meth: ptr[PyObject] = NULL;
        name = gen_id(ID_CLOSE);
        if not name or PyObject_GetOptionalAttr(yf, name, &mut meth) < 0 {
            PyErr_FormatUnraisable("Exception ignored while closing generator %R", yf);
        }
        if meth {
            retval = PyObject_CallNoArgs(meth);
            object_decref(meth);
            if not retval {
                return i32(-1);
            }
        }
    }
    object_xdecref(retval);
    return i32(0);
}

impl is_resume(instr: ptr[u8]) -> bool {
    code = i32(instr.view(1)[0]);
    return code == RESUME or code == RESUME_CHECK or code == INSTRUMENTED_RESUME;
}

impl gen_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    gen = self;

    if gen_frame_state(gen) == FRAME_CREATED {
        set_gen_frame_state(gen, FRAME_COMPLETED);
        gen_clear_frame(gen);
        return object_new_ref(Py_None);
    }
    if frame_state_finished(gen_frame_state(gen)) {
        return object_new_ref(Py_None);
    }

    yf = _PyGen_yf(gen);
    err: i32 = 0;
    if yf {
        state = gen_frame_state(gen);
        set_gen_frame_state(gen, FRAME_EXECUTING);
        err = gen_close_iter(yf);
        set_gen_frame_state(gen, state);
        object_decref(yf);
    }
    frame = gen_iframe(gen);
    instr = frame_ptr(frame, _PyInterpreterFrame_INSTR_PTR);
    if is_resume(instr) {
        no_unwind_tools = _PyEval_NoToolsForUnwind(thread_state());
        oparg = i32((instr + 1).view(1)[0]);
        if (oparg & RESUME_OPARG_DEPTH1_MASK) != 0 and no_unwind_tools {
            set_gen_frame_state(gen, FRAME_COMPLETED);
            gen_clear_frame(gen);
            return object_new_ref(Py_None);
        }
    }
    if err == i32(0) {
        PyErr_SetNone(PyExc_GeneratorExit);
    }

    retval = gen_send_ex(gen, Py_None, i32(1), i32(1));
    if retval {
        object_decref(retval);
        if coro_check_exact(gen) {
            PyErr_SetString(PyExc_RuntimeError, "coroutine ignored GeneratorExit");
        } elif async_gen_check_exact(gen) {
            PyErr_SetString(
                PyExc_RuntimeError, "async generator ignored GeneratorExit"
            );
        } else {
            PyErr_SetString(PyExc_RuntimeError, "generator ignored GeneratorExit");
        }
        return NULL;
    }

    if PyErr_ExceptionMatches(PyExc_GeneratorExit) != 0 {
        PyErr_Clear();
        return object_new_ref(Py_None);
    }

    (status, value) = fetch_stop_iteration_value();
    if status == i32(0) {
        return value;
    }
    return NULL;
}

impl gen_throw_impl(
    gen: ptr[PyObject],
    close_on_genexit: i32,
    typ_in: ptr[PyObject],
    val_in: ptr[PyObject],
    tb_in: ptr[PyObject]
) -> ptr[PyObject] {
    yf = _PyGen_yf(gen);

    if yf {
        frame = gen_iframe(gen);
        ret: ptr[PyObject] = NULL;
        if PyErr_GivenExceptionMatches(typ_in, PyExc_GeneratorExit) != 0
            and close_on_genexit != i32(0) {
            state = gen_frame_state(gen);
            set_gen_frame_state(gen, FRAME_EXECUTING);
            err = gen_close_iter(yf);
            set_gen_frame_state(gen, state);
            object_decref(yf);
            if err < 0 {
                return gen_send_ex(gen, Py_None, i32(1), i32(0));
            }
            return gen_throw_here(gen, typ_in, val_in, tb_in);
        }
        tstate = thread_state();
        current_frame = ptr[ptr[u8]](tstate + PyThreadState_CURRENT_FRAME);
        if gen_check_exact(yf) or coro_check_exact(yf) {
            prev = current_frame.view(1)[0];
            set_frame_ptr(frame, _PyInterpreterFrame_PREVIOUS, prev);
            current_frame.view(1)[0] = frame;
            state = gen_frame_state(gen);
            set_gen_frame_state(gen, FRAME_EXECUTING);
            ret = gen_throw_impl(yf, close_on_genexit, typ_in, val_in, tb_in);
            set_gen_frame_state(gen, state);
            current_frame.view(1)[0] = prev;
            set_frame_ptr(frame, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
        } else {
            meth: ptr[PyObject] = NULL;
            name = gen_id(ID_THROW);
            if not name or PyObject_GetOptionalAttr(yf, name, &mut meth) < 0 {
                object_decref(yf);
                return NULL;
            }
            if not meth {
                object_decref(yf);
                return gen_throw_here(gen, typ_in, val_in, tb_in);
            }
            prev = current_frame.view(1)[0];
            set_frame_ptr(frame, _PyInterpreterFrame_PREVIOUS, prev);
            current_frame.view(1)[0] = frame;
            state = gen_frame_state(gen);
            set_gen_frame_state(gen, FRAME_EXECUTING);
            ret = PyObject_CallFunctionObjArgs(meth, typ_in, val_in, tb_in, NULL);
            set_gen_frame_state(gen, state);
            current_frame.view(1)[0] = prev;
            set_frame_ptr(frame, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
            object_decref(meth);
        }
        object_decref(yf);
        if not ret {
            ret = gen_send_ex(gen, Py_None, i32(1), i32(0));
        }
        return ret;
    }

    return gen_throw_here(gen, typ_in, val_in, tb_in);
}

impl gen_throw_here(
    gen: ptr[PyObject],
    typ_in: ptr[PyObject],
    val_in: ptr[PyObject],
    tb_in: ptr[PyObject]
) -> ptr[PyObject] {
    typ = typ_in;
    val = val_in;
    tb = tb_in;
    if tb == Py_None {
        tb = NULL;
    } elif tb
        and not object_is_type(tb, ptr[PyTypeObject](addressof(PyTraceBack_Type))) {
        PyErr_SetString(
            PyExc_TypeError, "throw() third argument must be a traceback object"
        );
        return NULL;
    }

    object_incref(typ);
    xnew_ref(val);
    xnew_ref(tb);

    if type_has_feature(object_type(typ), Py_TPFLAGS_TYPE_SUBCLASS)
        and type_has_feature(ptr[PyTypeObject](typ), Py_TPFLAGS_BASE_EXC_SUBCLASS) {
        PyErr_NormalizeException(&mut typ, &mut val, &mut tb);
    } elif type_has_feature(object_type(typ), Py_TPFLAGS_BASE_EXC_SUBCLASS) {
        if val and val != Py_None {
            PyErr_SetString(
                PyExc_TypeError, "instance exception may not have a separate value"
            );
            object_decref(typ);
            object_xdecref(val);
            object_xdecref(tb);
            return NULL;
        }
        old_val = val;
        val = typ;
        object_xdecref(old_val);
        typ = object_new_ref(ptr[PyObject](object_type(typ)));
        if not tb {
            tb = PyException_GetTraceback(val);
        }
    } else {
        PyErr_Format(
            PyExc_TypeError,
            "exceptions must be classes or instances deriving from BaseException, not %s",
            object_type(typ).view(1)[0].tp_name
        );
        object_decref(typ);
        object_xdecref(val);
        object_xdecref(tb);
        return NULL;
    }

    PyErr_Restore(typ, val, tb);
    return gen_send_ex(gen, Py_None, i32(1), i32(0));
}

impl gen_throw(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("throw"), nargs, 1, 3) == 0 {
        return NULL;
    }
    if nargs > 1 {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "the (type, exc, tb) signature of throw() is deprecated, use the single-arg signature instead.",
            1
        )
            < 0 {
            return NULL;
        }
    }
    typ = args.view(1)[0];
    tb: ptr[PyObject] = NULL;
    val: ptr[PyObject] = NULL;
    if nargs == 3 {
        val = (args + 1).view(1)[0];
        tb = (args + 2).view(1)[0];
    } elif nargs == 2 {
        val = (args + 1).view(1)[0];
    }
    return gen_throw_impl(op, i32(1), typ, val, tb);
}

impl gen_iternext(self: ptr[PyObject]) -> ptr[PyObject] {
    (status, result) = gen_send_ex2(self, NULL, i32(0), i32(0));
    if status == PYGEN_RETURN {
        if result != Py_None {
            set_stop_iteration_value(result);
        }
        object_decref(result);
        return NULL;
    }
    return result;
}

impl set_stop_iteration_value(value: ptr[PyObject]) -> i32 {
    exc: ptr[PyObject] = NULL;
    if not value {
        exc = PyObject_CallNoArgs(PyExc_StopIteration);
    } else {
        exc = PyObject_CallOneArg(PyExc_StopIteration, value);
    }
    if not exc {
        return i32(-1);
    }
    PyErr_SetRaisedException(exc);
    return i32(0);
}

impl fetch_stop_iteration_value -> tuple[i32, ptr[PyObject]] {
    value: ptr[PyObject] = NULL;
    if PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
        exc = PyErr_GetRaisedException();
        value = xnew_ref(slot_get(exc, PyStopIterationObject_VALUE));
        object_decref(exc);
    } elif PyErr_Occurred() {
        return (i32(-1), NULL);
    }
    if not value {
        value = object_new_ref(Py_None);
    }
    return (i32(0), value);
}

impl gen_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<generator object %S at %p>", slot_get(self, PyGenObject_QUALNAME), ptr(self)
    );
}

impl gen_get_name(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return object_new_ref(slot_get(self, PyGenObject_NAME));
}

impl gen_set_name(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32 {
    if not value or not unicode_check(value) {
        PyErr_SetString(PyExc_TypeError, "__name__ must be set to a string object");
        return i32(-1);
    }
    old = slot_get(self, PyGenObject_NAME);
    slot_set(self, PyGenObject_NAME, object_new_ref(value));
    object_xdecref(old);
    return i32(0);
}

impl gen_get_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return object_new_ref(slot_get(self, PyGenObject_QUALNAME));
}

impl gen_set_qualname(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32 {
    if not value or not unicode_check(value) {
        PyErr_SetString(PyExc_TypeError, "__qualname__ must be set to a string object");
        return i32(-1);
    }
    old = slot_get(self, PyGenObject_QUALNAME);
    slot_set(self, PyGenObject_QUALNAME, object_new_ref(value));
    object_xdecref(old);
    return i32(0);
}

impl gen_getyieldfrom(gen: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    yf = _PyGen_yf(gen);
    if not yf {
        return object_new_ref(Py_None);
    }
    return yf;
}

impl gen_getrunning(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return bool_object(gen_frame_state(self) == FRAME_EXECUTING);
}

impl gen_getsuspended(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return bool_object(frame_state_suspended(gen_frame_state(self)));
}

impl gen_getframe_named(gen: ptr[PyObject], name: str) -> ptr[PyObject] {
    if PySys_Audit("object.__getattr__", "Os", gen, name) < 0 {
        return NULL;
    }
    if frame_state_finished(gen_frame_state(gen)) {
        return object_new_ref(Py_None);
    }
    return xnew_ref(frame_get_frame_object(gen_iframe(gen)));
}

impl gen_getframe(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return gen_getframe_named(self, "gi_frame");
}

impl gen_getcode_named(gen: ptr[PyObject], name: str) -> ptr[PyObject] {
    if PySys_Audit("object.__getattr__", "Os", gen, name) < 0 {
        return NULL;
    }
    return object_new_ref(gen_code(gen));
}

impl gen_getcode(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return gen_getcode_named(self, "gi_code");
}

impl gen_sizeof(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    res = PyGenObject_IFRAME + _PyInterpreterFrame_LOCALSPLUS;
    res += i64(frame_num_slots(gen_code(op))) * 8;
    return PyLong_FromSsize_t(res);
}

impl make_gen(type: ptr[PyTypeObject], func: ptr[PyObject]) -> ptr[PyObject] {
    fbase = ptr[u8](func);
    code = ptr[ptr[PyObject]](fbase + PyFunctionObject_CODE).view(1)[0];
    slots = ptr[i32](ptr[u8](code) + PyCodeObject_FRAMESIZE).view(1)[0]
        - FRAME_SPECIALS_SIZE;
    gen = _PyObject_GC_NewVar(ptr[PyObject](type), i64(slots));
    if not gen {
        return NULL;
    }
    base = ptr[u8](gen);
    ptr[i8](base + PyGenObject_FRAME_STATE).view(1)[0] = i8(FRAME_CLEARED);
    ptr[ptr[PyObject]](base + PyGenObject_WEAKREFLIST).view(1)[0] = NULL;
    ptr[ptr[PyObject]](base + PyGenObject_EXC_VALUE).view(1)[0] = NULL;
    ptr[ptr[PyObject]](base + PyGenObject_EXC_PREVIOUS_ITEM).view(1)[0] = NULL;
    ptr[u64](base + PyGenObject_IFRAME + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0] = u64.wrap(
        int(Py_None)
    )
        | STACKREF_TAG_REFCNT;
    name = ptr[ptr[PyObject]](fbase + PyFunctionObject_NAME).view(1)[0];
    object_incref(name);
    ptr[ptr[PyObject]](base + PyGenObject_NAME).view(1)[0] = name;
    qualname = ptr[ptr[PyObject]](fbase + PyFunctionObject_QUALNAME).view(1)[0];
    object_incref(qualname);
    ptr[ptr[PyObject]](base + PyGenObject_QUALNAME).view(1)[0] = qualname;
    object_gc_track(gen);
    return gen;
}

impl compute_cr_origin(origin_depth: i32, current_frame: ptr[u8]) -> ptr[PyObject] {
    frame = current_frame;
    frame_count: i32 = 0;
    while frame and frame_count < origin_depth {
        frame = frame_first_complete(frame_ptr(frame, _PyInterpreterFrame_PREVIOUS));
        frame_count += i32(1);
    }

    cr_origin = PyTuple_New(i64(frame_count));
    if not cr_origin {
        return NULL;
    }
    frame = current_frame;
    i: i64 = 0;
    while i < i64(frame_count) {
        code = frame_code(frame);
        line = PyUnstable_InterpreterFrame_GetLine(frame);
        frameinfo = Py_BuildValue(
            ptr[u8]("OiO"),
            slot_get(code, PyCodeObject_FILENAME),
            line,
            slot_get(code, PyCodeObject_NAME)
        );
        if not frameinfo {
            object_decref(cr_origin);
            return NULL;
        }
        tuple_set_item(cr_origin, i, frameinfo);
        frame = frame_first_complete(frame_ptr(frame, _PyInterpreterFrame_PREVIOUS));
        i += 1;
    }

    return cr_origin;
}

impl gen_new_with_qualname(
    type: ptr[PyTypeObject],
    f: ptr[PyObject],
    name: ptr[PyObject],
    qualname: ptr[PyObject]
) -> ptr[PyObject] {
    f_frame = ptr[ptr[u8]](ptr[u8](f) + PyFrameObject_F_FRAME);
    code = frame_code(f_frame.view(1)[0]);
    size = code_i32(code, PyCodeObject_NLOCALSPLUS)
        + code_i32(code, PyCodeObject_STACKSIZE);
    gen = _PyObject_GC_NewVar(ptr[PyObject](type), i64(size));
    if not gen {
        object_decref(f);
        return NULL;
    }
    frame = gen_iframe(gen);
    frame_copy(ptr[u8](f) + PyFrameObject_FRAME_DATA, frame);
    set_gen_frame_state(gen, FRAME_CREATED);
    f_frame.view(1)[0] = frame;
    (frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(FRAME_OWNED_BY_GENERATOR);
    object_decref(f);
    slot_set(gen, PyGenObject_WEAKREFLIST, NULL);
    slot_set(gen, PyGenObject_EXC_VALUE, NULL);
    slot_set(gen, PyGenObject_EXC_PREVIOUS_ITEM, NULL);
    if name {
        slot_set(gen, PyGenObject_NAME, object_new_ref(name));
    } else {
        slot_set(
            gen,
            PyGenObject_NAME,
            object_new_ref(slot_get(gen_code(gen), PyCodeObject_NAME))
        );
    }
    if qualname {
        slot_set(gen, PyGenObject_QUALNAME, object_new_ref(qualname));
    } else {
        slot_set(
            gen,
            PyGenObject_QUALNAME,
            object_new_ref(slot_get(gen_code(gen), PyCodeObject_QUALNAME))
        );
    }
    object_gc_track(gen);
    return gen;
}

impl gen_is_coroutine(o: ptr[PyObject]) -> bool {
    if gen_check_exact(o) {
        if (code_flags(gen_code(o)) & CO_ITERABLE_COROUTINE) != 0 {
            return True;
        }
    }
    return False;
}

impl coro_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<coroutine object %S at %p>", slot_get(self, PyGenObject_QUALNAME), ptr(self)
    );
}

impl coro_await(coro: ptr[PyObject]) -> ptr[PyObject] {
    cw = _PyObject_GC_New(ptr[PyObject](addressof(_PyCoroWrapper_Type)));
    if not cw {
        return NULL;
    }
    slot_set(cw, PyCoroWrapper_CW_COROUTINE, object_new_ref(coro));
    object_gc_track(cw);
    return cw;
}

impl coro_get_cr_await(coro: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    yf = _PyGen_yf(coro);
    if not yf {
        return object_new_ref(Py_None);
    }
    return yf;
}

impl cr_getsuspended(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return bool_object(frame_state_suspended(gen_frame_state(self)));
}

impl cr_getrunning(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return bool_object(gen_frame_state(self) == FRAME_EXECUTING);
}

impl cr_getframe(coro: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return gen_getframe_named(coro, "cr_frame");
}

impl cr_getcode(coro: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return gen_getcode_named(coro, "cr_code");
}

impl coro_wrapper_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    slot_clear(self, PyCoroWrapper_CW_COROUTINE);
    PyObject_GC_Del(ptr(self));
}

impl coro_wrapper_iternext(self: ptr[PyObject]) -> ptr[PyObject] {
    return gen_iternext(slot_get(self, PyCoroWrapper_CW_COROUTINE));
}

impl coro_wrapper_send(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return gen_send(slot_get(self, PyCoroWrapper_CW_COROUTINE), arg);
}

impl coro_wrapper_throw(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return gen_throw(slot_get(self, PyCoroWrapper_CW_COROUTINE), args, nargs);
}

impl coro_wrapper_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return gen_close(slot_get(self, PyCoroWrapper_CW_COROUTINE), args);
}

impl coro_wrapper_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(slot_get(self, PyCoroWrapper_CW_COROUTINE), visitor, arg);
}

impl async_gen_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(
        slot_get(self, PyGenObject_ORIGIN_OR_FINALIZER), visitor, arg
    );
    if status != 0 {
        return status;
    }
    return gen_traverse(self, visitor, arg);
}

impl async_gen_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<async_generator object %S at %p>",
        slot_get(self, PyGenObject_QUALNAME),
        ptr(self)
    );
}

impl async_gen_init_hooks(o: ptr[PyObject]) -> i32 {
    if slot_u8(o, PyGenObject_HOOKS_INITED) != u8(0) {
        return i32(0);
    }

    slot_set_u8(o, PyGenObject_HOOKS_INITED, u8(1));

    tstate = thread_state();

    finalizer = ptr[ptr[PyObject]](tstate + PyThreadState_ASYNC_GEN_FINALIZER).view(1)[
        0
    ];
    if finalizer {
        slot_set(o, PyGenObject_ORIGIN_OR_FINALIZER, object_new_ref(finalizer));
    }

    firstiter = ptr[ptr[PyObject]](tstate + PyThreadState_ASYNC_GEN_FIRSTITER).view(1)[
        0
    ];
    if firstiter {
        object_incref(firstiter);
        res = PyObject_CallOneArg(firstiter, o);
        object_decref(firstiter);
        if not res {
            return i32(1);
        }
        object_decref(res);
    }

    return i32(0);
}

impl async_gen_anext(self: ptr[PyObject]) -> ptr[PyObject] {
    if async_gen_init_hooks(self) != 0 {
        return NULL;
    }
    return async_gen_asend_new(self, NULL);
}

impl async_gen_asend(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if async_gen_init_hooks(op) != 0 {
        return NULL;
    }
    return async_gen_asend_new(op, arg);
}

impl async_gen_aclose(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if async_gen_init_hooks(op) != 0 {
        return NULL;
    }
    return async_gen_athrow_new(op, NULL);
}

impl async_gen_athrow(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if object_size(args) > 1 {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "the (type, exc, tb) signature of athrow() is deprecated, use the single-arg signature instead.",
            1
        )
            < 0 {
            return NULL;
        }
    }
    if async_gen_init_hooks(op) != 0 {
        return NULL;
    }
    return async_gen_athrow_new(op, args);
}

impl ag_getframe(ag: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return gen_getframe_named(ag, "ag_frame");
}

impl ag_getcode(gen: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return gen_getcode_named(gen, "ag_code");
}

impl ag_getsuspended(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return bool_object(frame_state_suspended(gen_frame_state(self)));
}

impl async_gen_unwrap_value(
    gen: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    if not result {
        if not PyErr_Occurred() {
            PyErr_SetNone(PyExc_StopAsyncIteration);
        }

        if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0
            or PyErr_ExceptionMatches(PyExc_GeneratorExit) != 0 {
            slot_set_u8(gen, PyGenObject_CLOSED, u8(1));
        }

        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(0));
        return NULL;
    }

    if wrapped_value_check_exact(result) {
        set_stop_iteration_value(slot_get(result, _PyAsyncGenWrappedValue_AGW_VAL));
        object_decref(result);
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(0));
        return NULL;
    }

    return result;
}

impl async_gen_asend_dealloc(self: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(self) != 0 {
        return;
    }

    object_gc_untrack(self);
    slot_clear(self, PyAsyncGenASend_AGS_GEN);
    slot_clear(self, PyAsyncGenASend_AGS_SENDVAL);

    words = ptr[i64](gc_head(self)).view(2);
    words[1] = words[1] & ~_PyGC_PREV_MASK_FINALIZED;

    if not freelist_push(
        _Py_freelists_ASYNC_GEN_ASENDS, self, Py_async_gen_asends_MAXFREELIST
    ) {
        PyObject_GC_Del(ptr(self));
    }
}

impl async_gen_asend_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(slot_get(self, PyAsyncGenASend_AGS_GEN), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(slot_get(self, PyAsyncGenASend_AGS_SENDVAL), visitor, arg);
}

impl async_gen_asend_send(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    o = self;
    if slot_i32(o, PyAsyncGenASend_AGS_STATE) == AWAITABLE_STATE_CLOSED {
        PyErr_SetString(
            PyExc_RuntimeError, "cannot reuse already awaited __anext__()/asend()"
        );
        return NULL;
    }

    sendarg = arg;
    gen = slot_get(o, PyAsyncGenASend_AGS_GEN);
    if slot_i32(o, PyAsyncGenASend_AGS_STATE) == AWAITABLE_STATE_INIT {
        if slot_u8(gen, PyGenObject_RUNNING_ASYNC) != u8(0) {
            slot_set_i32(o, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_CLOSED);
            PyErr_SetString(
                PyExc_RuntimeError, "anext(): asynchronous generator is already running"
            );
            return NULL;
        }

        if not sendarg or sendarg == Py_None {
            sendarg = slot_get(o, PyAsyncGenASend_AGS_SENDVAL);
        }
        slot_set_i32(o, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_ITER);
    }

    slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(1));
    result = gen_send(gen, sendarg);
    result = async_gen_unwrap_value(gen, result);

    if not result {
        slot_set_i32(o, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_CLOSED);
    }

    return result;
}

impl async_gen_asend_iternext(ags: ptr[PyObject]) -> ptr[PyObject] {
    return async_gen_asend_send(ags, NULL);
}

impl async_gen_asend_throw(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    o = self;
    if slot_i32(o, PyAsyncGenASend_AGS_STATE) == AWAITABLE_STATE_CLOSED {
        PyErr_SetString(
            PyExc_RuntimeError, "cannot reuse already awaited __anext__()/asend()"
        );
        return NULL;
    }

    gen = slot_get(o, PyAsyncGenASend_AGS_GEN);
    if slot_i32(o, PyAsyncGenASend_AGS_STATE) == AWAITABLE_STATE_INIT {
        if slot_u8(gen, PyGenObject_RUNNING_ASYNC) != u8(0) {
            slot_set_i32(o, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_CLOSED);
            PyErr_SetString(
                PyExc_RuntimeError, "anext(): asynchronous generator is already running"
            );
            return NULL;
        }

        slot_set_i32(o, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_ITER);
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(1));
    }

    result = gen_throw(gen, args, nargs);
    result = async_gen_unwrap_value(gen, result);

    if not result {
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(0));
        slot_set_i32(o, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_CLOSED);
    }

    return result;
}

impl async_gen_asend_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if slot_i32(self, PyAsyncGenASend_AGS_STATE) == AWAITABLE_STATE_CLOSED {
        return object_new_ref(Py_None);
    }

    result = async_gen_asend_throw(self, genexit_arg_vector(), 1);
    if not result {
        if PyErr_ExceptionMatches(PyExc_StopIteration) != 0
            or PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0
            or PyErr_ExceptionMatches(PyExc_GeneratorExit) != 0 {
            PyErr_Clear();
            return object_new_ref(Py_None);
        }
        return result;
    }

    object_decref(result);
    PyErr_SetString(PyExc_RuntimeError, "coroutine ignored GeneratorExit");
    return NULL;
}

impl async_gen_asend_finalize(self: ptr[PyObject]) {
    if slot_i32(self, PyAsyncGenASend_AGS_STATE) == AWAITABLE_STATE_INIT {
        method = gen_id(ID_ASEND);
        if not method {
            PyErr_Clear();
            return;
        }
        _PyErr_WarnUnawaitedAgenMethod(slot_get(self, PyAsyncGenASend_AGS_GEN), method);
    }
}

impl async_gen_asend_new(gen: ptr[PyObject], sendval: ptr[PyObject]) -> ptr[PyObject] {
    ags = freelist_pop(_Py_freelists_ASYNC_GEN_ASENDS);
    if not ags {
        ags = _PyObject_GC_New(ptr[PyObject](addressof(_PyAsyncGenASend_Type)));
        if not ags {
            return NULL;
        }
    }

    slot_set(ags, PyAsyncGenASend_AGS_GEN, object_new_ref(gen));
    slot_set(ags, PyAsyncGenASend_AGS_SENDVAL, xnew_ref(sendval));
    slot_set_i32(ags, PyAsyncGenASend_AGS_STATE, AWAITABLE_STATE_INIT);

    object_gc_track(ags);
    return ags;
}

impl async_gen_wrapped_val_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    slot_clear(self, _PyAsyncGenWrappedValue_AGW_VAL);
    if not freelist_push(_Py_freelists_ASYNC_GENS, self, Py_async_gens_MAXFREELIST) {
        PyObject_GC_Del(ptr(self));
    }
}

impl async_gen_wrapped_val_traverse(
    self: ptr[PyObject], visitor: ptr, arg: ptr
) -> i32 {
    return visit_reference(
        slot_get(self, _PyAsyncGenWrappedValue_AGW_VAL), visitor, arg
    );
}

impl async_gen_athrow_dealloc(self: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(self) != 0 {
        return;
    }

    object_gc_untrack(self);
    slot_clear(self, PyAsyncGenAThrow_AGT_GEN);
    slot_clear(self, PyAsyncGenAThrow_AGT_ARGS);
    PyObject_GC_Del(ptr(self));
}

impl async_gen_athrow_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(slot_get(self, PyAsyncGenAThrow_AGT_GEN), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(slot_get(self, PyAsyncGenAThrow_AGT_ARGS), visitor, arg);
}

impl athrow_yield_close(o: ptr[PyObject]) -> ptr[PyObject] {
    slot_set_u8(
        slot_get(o, PyAsyncGenAThrow_AGT_GEN), PyGenObject_RUNNING_ASYNC, u8(0)
    );
    slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
    PyErr_SetString(PyExc_RuntimeError, "async generator ignored GeneratorExit");
    return NULL;
}

impl athrow_check_error(o: ptr[PyObject]) -> ptr[PyObject] {
    slot_set_u8(
        slot_get(o, PyAsyncGenAThrow_AGT_GEN), PyGenObject_RUNNING_ASYNC, u8(0)
    );
    slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
    if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0
        or PyErr_ExceptionMatches(PyExc_GeneratorExit) != 0 {
        if not slot_get(o, PyAsyncGenAThrow_AGT_ARGS) {
            PyErr_Clear();
            PyErr_SetNone(PyExc_StopIteration);
        }
    }
    return NULL;
}

impl async_gen_athrow_send(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    o = self;
    gen = slot_get(o, PyAsyncGenAThrow_AGT_GEN);
    retval: ptr[PyObject] = NULL;

    if slot_i32(o, PyAsyncGenAThrow_AGT_STATE) == AWAITABLE_STATE_CLOSED {
        PyErr_SetString(
            PyExc_RuntimeError, "cannot reuse already awaited aclose()/athrow()"
        );
        return NULL;
    }

    if frame_state_finished(gen_frame_state(gen)) {
        slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }

    if slot_i32(o, PyAsyncGenAThrow_AGT_STATE) == AWAITABLE_STATE_INIT {
        if slot_u8(gen, PyGenObject_RUNNING_ASYNC) != u8(0) {
            slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
            if not slot_get(o, PyAsyncGenAThrow_AGT_ARGS) {
                PyErr_SetString(
                    PyExc_RuntimeError,
                    "aclose(): asynchronous generator is already running"
                );
            } else {
                PyErr_SetString(
                    PyExc_RuntimeError,
                    "athrow(): asynchronous generator is already running"
                );
            }
            return NULL;
        }

        if slot_u8(gen, PyGenObject_CLOSED) != u8(0) {
            slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
            PyErr_SetNone(PyExc_StopAsyncIteration);
            return NULL;
        }

        if arg != Py_None {
            PyErr_SetString(
                PyExc_RuntimeError,
                "can't send non-None value to a just-started coroutine"
            );
            return NULL;
        }

        slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_ITER);
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(1));

        agt_args = slot_get(o, PyAsyncGenAThrow_AGT_ARGS);
        if not agt_args {
            slot_set_u8(gen, PyGenObject_CLOSED, u8(1));

            retval = gen_throw_impl(gen, i32(0), PyExc_GeneratorExit, NULL, NULL);

            if retval and wrapped_value_check_exact(retval) {
                object_decref(retval);
                return athrow_yield_close(o);
            }
        } else {
            typ: ptr[PyObject] = NULL;
            tb: ptr[PyObject] = NULL;
            val: ptr[PyObject] = NULL;
            if PyArg_UnpackTuple(
                agt_args, ptr[u8]("athrow"), 1, 3, &mut typ, &mut val, &mut tb
            )
                == 0 {
                return NULL;
            }
            retval = gen_throw_impl(gen, i32(0), typ, val, tb);
            retval = async_gen_unwrap_value(gen, retval);
        }
        if not retval {
            return athrow_check_error(o);
        }
        return retval;
    }

    retval = gen_send(gen, arg);
    if slot_get(o, PyAsyncGenAThrow_AGT_ARGS) {
        return async_gen_unwrap_value(gen, retval);
    }
    if retval {
        if wrapped_value_check_exact(retval) {
            object_decref(retval);
            return athrow_yield_close(o);
        }
        return retval;
    }
    return athrow_check_error(o);
}

impl async_gen_athrow_throw(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    o = self;
    gen = slot_get(o, PyAsyncGenAThrow_AGT_GEN);

    if slot_i32(o, PyAsyncGenAThrow_AGT_STATE) == AWAITABLE_STATE_CLOSED {
        PyErr_SetString(
            PyExc_RuntimeError, "cannot reuse already awaited aclose()/athrow()"
        );
        return NULL;
    }

    if slot_i32(o, PyAsyncGenAThrow_AGT_STATE) == AWAITABLE_STATE_INIT {
        if slot_u8(gen, PyGenObject_RUNNING_ASYNC) != u8(0) {
            slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
            if not slot_get(o, PyAsyncGenAThrow_AGT_ARGS) {
                PyErr_SetString(
                    PyExc_RuntimeError,
                    "aclose(): asynchronous generator is already running"
                );
            } else {
                PyErr_SetString(
                    PyExc_RuntimeError,
                    "athrow(): asynchronous generator is already running"
                );
            }
            return NULL;
        }

        slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_ITER);
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(1));
    }

    retval = gen_throw(gen, args, nargs);
    if slot_get(o, PyAsyncGenAThrow_AGT_ARGS) {
        retval = async_gen_unwrap_value(gen, retval);
        if not retval {
            slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(0));
            slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
        }
        return retval;
    }

    if retval and wrapped_value_check_exact(retval) {
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(0));
        slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
        object_decref(retval);
        PyErr_SetString(PyExc_RuntimeError, "async generator ignored GeneratorExit");
        return NULL;
    }
    if not retval {
        slot_set_u8(gen, PyGenObject_RUNNING_ASYNC, u8(0));
        slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_CLOSED);
    }
    if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0
        or PyErr_ExceptionMatches(PyExc_GeneratorExit) != 0 {
        PyErr_Clear();
        PyErr_SetNone(PyExc_StopIteration);
    }
    return retval;
}

impl async_gen_athrow_iternext(agt: ptr[PyObject]) -> ptr[PyObject] {
    return async_gen_athrow_send(agt, Py_None);
}

impl async_gen_athrow_close(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if slot_i32(self, PyAsyncGenAThrow_AGT_STATE) == AWAITABLE_STATE_CLOSED {
        return object_new_ref(Py_None);
    }
    result = async_gen_athrow_throw(self, genexit_arg_vector(), 1);
    if not result {
        if PyErr_ExceptionMatches(PyExc_StopIteration) != 0
            or PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0
            or PyErr_ExceptionMatches(PyExc_GeneratorExit) != 0 {
            PyErr_Clear();
            return object_new_ref(Py_None);
        }
        return result;
    }
    object_decref(result);
    PyErr_SetString(PyExc_RuntimeError, "coroutine ignored GeneratorExit");
    return NULL;
}

impl async_gen_athrow_finalize(op: ptr[PyObject]) {
    if slot_i32(op, PyAsyncGenAThrow_AGT_STATE) == AWAITABLE_STATE_INIT {
        method: ptr[PyObject] = NULL;
        if slot_get(op, PyAsyncGenAThrow_AGT_ARGS) {
            method = gen_id(ID_ATHROW);
        } else {
            method = gen_id(ID_ACLOSE);
        }
        if not method {
            PyErr_Clear();
            return;
        }
        _PyErr_WarnUnawaitedAgenMethod(slot_get(op, PyAsyncGenAThrow_AGT_GEN), method);
    }
}

impl async_gen_athrow_new(gen: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    o = _PyObject_GC_New(ptr[PyObject](addressof(_PyAsyncGenAThrow_Type)));
    if not o {
        return NULL;
    }
    slot_set(o, PyAsyncGenAThrow_AGT_GEN, object_new_ref(gen));
    slot_set(o, PyAsyncGenAThrow_AGT_ARGS, xnew_ref(args));
    slot_set_i32(o, PyAsyncGenAThrow_AGT_STATE, AWAITABLE_STATE_INIT);
    object_gc_track(o);
    return o;
}

impl genexit_arg_vector -> ptr[ptr[PyObject]] {
    slot = ptr[ptr[PyObject]](addressof(genexit_args));
    slot.view(1)[0] = PyExc_GeneratorExit;
    return slot;
}
