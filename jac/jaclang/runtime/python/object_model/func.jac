import from c {
    glob PyType_Type: PyTypeObject,
         PyCode_Type: PyTypeObject,
         PyCell_Type: PyTypeObject; def _PyFunction_Vectorcall(
        func: ptr[PyObject],
        stack: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyDict_LoadBuiltinsFromGlobals(
        globals: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_IsAbstract(ob: ptr[PyObject]) -> i32;  def PyObject_GenericGetDict(
        ob: ptr[PyObject], context: ptr
    ) -> ptr[PyObject];  def PyObject_GenericSetDict(
        ob: ptr[PyObject], value: ptr[PyObject], context: ptr
    ) -> i32;  def _PyCode_VerifyStateless(
        tstate: ptr,
        co: ptr[PyObject],
        globalnames: ptr[PyObject],
        globalsns: ptr[PyObject],
        builtinsns: ptr[PyObject]
    ) -> i32;  def _PyArg_BadArgument(
        fname: ptr[u8], displayname: ptr[u8], expected: ptr[u8], arg: ptr[PyObject]
    );  obj FuncCall {
        has watcher: Callable[[i32, ptr[PyObject], ptr[PyObject]], i32] = 0,
            free: Callable[[ptr], None] = 0;
    }  glob:priv name_key: ptr[PyObject] = ptr[PyObject](),
         module_key: ptr[PyObject] = ptr[PyObject](),
         qualname_key: ptr[PyObject] = ptr[PyObject](),
         doc_key: ptr[PyObject] = ptr[PyObject](),
         annotations_key: ptr[PyObject] = ptr[PyObject](),
         annotate_key: ptr[PyObject] = ptr[PyObject](),
         func_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__closure__"),
                 type_=_Py_T_OBJECT,
                 offset=PyFunctionObject_CLOSURE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__doc__"),
                 type_=_Py_T_OBJECT,
                 offset=PyFunctionObject_DOC,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__globals__"),
                 type_=_Py_T_OBJECT,
                 offset=PyFunctionObject_GLOBALS,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__module__"),
                 type_=_Py_T_OBJECT,
                 offset=PyFunctionObject_MODULE,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__builtins__"),
                 type_=_Py_T_OBJECT,
                 offset=PyFunctionObject_BUILTINS,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         func_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__code__"), get=func_get_code, set=func_set_code
             ),
             PyGetSetDef(
                 name=ptr[u8]("__defaults__"),
                 get=func_get_defaults,
                 set=func_set_defaults
             ),
             PyGetSetDef(
                 name=ptr[u8]("__kwdefaults__"),
                 get=func_get_kwdefaults,
                 set=func_set_kwdefaults
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotations__"),
                 get=func_get_annotations,
                 set=func_set_annotations,
                 doc=ptr[u8]("Dict of annotations in a function object.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotate__"),
                 get=func_get_annotate,
                 set=func_set_annotate,
                 doc=ptr[u8]("Get the code object for a function.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef(
                 name=ptr[u8]("__name__"), get=func_get_name, set=func_set_name
             ),
             PyGetSetDef(
                 name=ptr[u8]("__qualname__"),
                 get=func_get_qualname,
                 set=func_set_qualname
             ),
             PyGetSetDef(
                 name=ptr[u8]("__type_params__"),
                 get=func_get_type_params,
                 set=func_set_type_params,
                 doc=ptr[u8]("Get the declared type parameters for a function.")
             ),
             PyGetSetDef()
         ],
         cm_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__func__"),
                 type_=_Py_T_OBJECT,
                 offset=classmethod_CALLABLE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__wrapped__"),
                 type_=_Py_T_OBJECT,
                 offset=classmethod_CALLABLE,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         cm_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__isabstractmethod__"), get=cm_get___isabstractmethod__
             ),
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotations__"),
                 get=cm_get___annotations__,
                 set=cm_set___annotations__
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotate__"),
                 get=cm_get___annotate__,
                 set=cm_set___annotate__
             ),
             PyGetSetDef()
         ],
         cm_methodlist: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         sm_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__func__"),
                 type_=_Py_T_OBJECT,
                 offset=staticmethod_CALLABLE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__wrapped__"),
                 type_=_Py_T_OBJECT,
                 offset=staticmethod_CALLABLE,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         sm_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__isabstractmethod__"), get=sm_get___isabstractmethod__
             ),
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotations__"),
                 get=sm_get___annotations__,
                 set=sm_set___annotations__
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotate__"),
                 get=sm_get___annotate__,
                 set=sm_set___annotate__
             ),
             PyGetSetDef()
         ],
         sm_methodlist: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyFunction_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("function"),
             tp_basicsize=PyFunctionObject_SIZE,
             tp_dealloc=func_dealloc,
             tp_vectorcall_offset=PyFunctionObject_VECTORCALL,
             tp_repr=func_repr,
             tp_call=PyVectorcall_Call,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_HAVE_VECTORCALL
                 | Py_TPFLAGS_METHOD_DESCRIPTOR,
             tp_doc=ptr[u8](
                 "function(code, globals, name=None, argdefs=None, closure=None,\n"
                 "         kwdefaults=None)\n--\n\n"
                 "Create a function object.\n\n"
                 "  code\n"
                 "    a code object\n"
                 "  globals\n"
                 "    the globals dictionary\n"
                 "  name\n"
                 "    a string that overrides the name from the code object\n"
                 "  argdefs\n"
                 "    a tuple that specifies the default argument values\n"
                 "  closure\n"
                 "    a tuple that supplies the bindings for free variables\n"
                 "  kwdefaults\n"
                 "    a dictionary that specifies the default keyword argument values"
             ),
             tp_traverse=func_traverse,
             tp_clear=func_clear,
             tp_weaklistoffset=PyFunctionObject_WEAKREFLIST,
             tp_members=addressof(func_memberlist),
             tp_getset=addressof(func_getsetlist),
             tp_descr_get=func_descr_get,
             tp_dictoffset=PyFunctionObject_DICT,
             tp_new=func_new
         ),
         PyClassMethod_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("classmethod"),
             tp_basicsize=classmethod_SIZE,
             tp_dealloc=cm_dealloc,
             tp_repr=cm_repr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "classmethod(function, /)\n--\n\n"
                 "Convert a function to be a class method.\n\n"
                 "A class method receives the class as implicit first argument,\n"
                 "just like an instance method receives the instance.\n"
                 "To declare a class method, use this idiom:\n\n"
                 "  class C:\n"
                 "      @classmethod\n"
                 "      def f(cls, arg1, arg2, argN):\n"
                 "          ...\n\n"
                 "It can be called either on the class (e.g. C.f()) or on an instance\n"
                 "(e.g. C().f()).  The instance is ignored except for its class.\n"
                 "If a class method is called for a derived class, the derived class\n"
                 "object is passed as the implied first argument.\n\n"
                 "Class methods are different than C++ or Java static methods.\n"
                 "If you want those, see the staticmethod builtin."
             ),
             tp_traverse=cm_traverse,
             tp_clear=cm_clear,
             tp_methods=addressof(cm_methodlist),
             tp_members=addressof(cm_memberlist),
             tp_getset=addressof(cm_getsetlist),
             tp_descr_get=cm_descr_get,
             tp_dictoffset=classmethod_DICT,
             tp_init=cm_init,
             tp_alloc=PyType_GenericAlloc,
             tp_new=cm_new,
             tp_free=PyObject_GC_Del
         ),
         PyStaticMethod_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("staticmethod"),
             tp_basicsize=staticmethod_SIZE,
             tp_dealloc=sm_dealloc,
             tp_repr=sm_repr,
             tp_call=sm_call,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "staticmethod(function, /)\n--\n\n"
                 "Convert a function to be a static method.\n\n"
                 "A static method does not receive an implicit first argument.\n"
                 "To declare a static method, use this idiom:\n\n"
                 "     class C:\n"
                 "         @staticmethod\n"
                 "         def f(arg1, arg2, argN):\n"
                 "             ...\n\n"
                 "It can be called either on the class (e.g. C.f()) or on an instance\n"
                 "(e.g. C().f()). Both the class and the instance are ignored, and\n"
                 "neither is passed implicitly as the first argument to the method.\n\n"
                 "Static methods in Python are similar to those found in Java or C++.\n"
                 "For a more advanced concept, see the classmethod builtin."
             ),
             tp_traverse=sm_traverse,
             tp_clear=sm_clear,
             tp_methods=addressof(sm_methodlist),
             tp_members=addressof(sm_memberlist),
             tp_getset=addressof(sm_getsetlist),
             tp_descr_get=sm_descr_get,
             tp_dictoffset=staticmethod_DICT,
             tp_init=sm_init,
             tp_alloc=PyType_GenericAlloc,
             tp_new=sm_new,
             tp_free=PyObject_GC_Del
         );
}

glob:priv EVENT_CREATE: i32 = 0,
     EVENT_DESTROY: i32 = 1,
     EVENT_MODIFY_CODE: i32 = 2,
     EVENT_MODIFY_DEFAULTS: i32 = 3,
     EVENT_MODIFY_KWDEFAULTS: i32 = 4,
     FUNC_VERSION_UNSET: u32 = u32(0),
     FUNC_VERSION_CLEARED: u32 = u32(1),
     FUNC_VERSION_FIRST_VALID: u32 = u32(2),
     func_new_signature = CallSignature(
         "function",
         ["code", "globals", "name", "argdefs", "closure", "kwdefaults"],
         2,
         6,
         0,
         parser=PARSE_KEYWORDS
     );

def field(op: ptr[PyObject], offset: i64) -> ptr[PyObject];

def set_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def replace_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def func_version(op: ptr[PyObject]) -> u32;

def set_func_version(op: ptr[PyObject], version: u32);

def set_vectorcall(op: ptr[PyObject], vectorcall: ptr);

def code_i32(code: ptr[PyObject], offset: i64) -> i32;

def function_check(op: ptr[PyObject]) -> bool;

def tuple_check(op: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def unicode_check(op: ptr[PyObject]) -> bool;

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def interned(which: int) -> ptr[PyObject];

def func_event_name(event: i32) -> str;

def active_watchers(interp: ptr[u8]) -> ptr[u8];

def watcher_slot(interp: ptr[u8], i: i64) -> ptr[int];

def notify_func_watchers(
    interp: ptr[u8], event: i32, func: ptr[PyObject], new_value: ptr[PyObject]
);

def handle_func_event(event: i32, func: ptr[PyObject], new_value: ptr[PyObject]);

def cache_item(interp: ptr[u8], version: u32) -> ptr[ptr[PyObject]];

def func_clear_version(interp: ptr[u8], func: ptr[PyObject]);

def clear_version(func: ptr[PyObject]);

def new_function(
    globals: ptr[PyObject],
    builtins: ptr[PyObject],
    name: ptr[PyObject],
    qualname: ptr[PyObject],
    code: ptr[PyObject],
    doc: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def PyFunction_AddWatcher(callback: ptr) -> i32 {
        interp = current_interp();
        for i in range(FUNC_MAX_WATCHERS) {
            slot = watcher_slot(interp, i);
            if slot.view(1)[0] == 0 {
                slot.view(1)[0] = int(callback);
                active = active_watchers(interp);
                active.view(1)[0] = active.view(1)[0] | u8(1 << i);
                return i32(i);
            }
        }
        PyErr_SetString(PyExc_RuntimeError, "no more func watcher IDs available");
        return i32(-1);
    }  def PyFunction_ClearWatcher(watcher_id: i32) -> i32 {
        interp = current_interp();
        if watcher_id < 0 or i64(watcher_id) >= FUNC_MAX_WATCHERS {
            PyErr_Format(PyExc_ValueError, "invalid func watcher ID %d", watcher_id);
            return i32(-1);
        }
        slot = watcher_slot(interp, i64(watcher_id));
        if slot.view(1)[0] == 0 {
            PyErr_Format(PyExc_ValueError, "no func watcher set for ID %d", watcher_id);
            return i32(-1);
        }
        slot.view(1)[0] = 0;
        active = active_watchers(interp);
        active.view(1)[0] = active.view(1)[0] & ~u8(1 << i64(watcher_id));
        return i32(0);
    }  def _PyFunction_FromConstructor(constr: ptr[u8]) -> ptr[PyObject] {
        c = ptr[PyObject](constr);
        module: ptr[PyObject] = NULL;
        if PyDict_GetItemRef(
            field(c, PyFrameConstructor_GLOBALS), interned(0), &mut module
        )
            < 0 {
            return NULL;
        }
        op = new_function(
            object_new_ref(field(c, PyFrameConstructor_GLOBALS)),
            object_new_ref(field(c, PyFrameConstructor_BUILTINS)),
            object_new_ref(field(c, PyFrameConstructor_NAME)),
            object_new_ref(field(c, PyFrameConstructor_QUALNAME)),
            object_new_ref(field(c, PyFrameConstructor_CODE)),
            object_new_ref(Py_None),
            module
        );
        if not op {
            object_decref(field(c, PyFrameConstructor_GLOBALS));
            object_decref(field(c, PyFrameConstructor_BUILTINS));
            object_decref(field(c, PyFrameConstructor_NAME));
            object_decref(field(c, PyFrameConstructor_QUALNAME));
            object_decref(field(c, PyFrameConstructor_CODE));
            object_decref(Py_None);
            object_xdecref(module);
            return NULL;
        }
        set_field(
            op,
            PyFunctionObject_DEFAULTS,
            object_xnew_ref(field(c, PyFrameConstructor_DEFAULTS))
        );
        set_field(
            op,
            PyFunctionObject_KWDEFAULTS,
            object_xnew_ref(field(c, PyFrameConstructor_KWDEFAULTS))
        );
        set_field(
            op,
            PyFunctionObject_CLOSURE,
            object_xnew_ref(field(c, PyFrameConstructor_CLOSURE))
        );
        object_gc_track(op);
        handle_func_event(EVENT_CREATE, op, NULL);
        return op;
    }  def PyFunction_NewWithQualName(
        code: ptr[PyObject], globals: ptr[PyObject], qualname_in: ptr[PyObject]
    ) -> ptr[PyObject] {
        object_incref(globals);
        object_incref(code);
        name = object_new_ref(field(code, PyCodeObject_NAME));
        qualname = qualname_in or field(code, PyCodeObject_QUALNAME);
        object_incref(qualname);
        consts = field(code, PyCodeObject_CONSTS);
        doc = Py_None;
        if (code_i32(code, PyCodeObject_FLAGS) & CO_HAS_DOCSTRING) != 0 {
            doc = PyTuple_GetItem(consts, 0);
            if not unicode_check(doc) {
                doc = Py_None;
            }
        }
        object_incref(doc);

        module: ptr[PyObject] = NULL;
        builtins: ptr[PyObject] = NULL;
        op: ptr[PyObject] = NULL;
        if PyDict_GetItemRef(globals, interned(0), &mut module) >= 0 {
            builtins = _PyDict_LoadBuiltinsFromGlobals(globals);
            if builtins {
                op = new_function(globals, builtins, name, qualname, code, doc, module);
            }
        }
        if not op {
            object_decref(globals);
            object_decref(code);
            object_decref(name);
            object_decref(qualname);
            object_decref(doc);
            object_xdecref(module);
            object_xdecref(builtins);
            return NULL;
        }
        object_gc_track(op);
        handle_func_event(EVENT_CREATE, op, NULL);
        return op;
    }  def _PyFunction_SetVersion(func: ptr[PyObject], version: u32) {
        set_func_version(func, version);
        slot = cache_item(current_interp(), version);
        slot.view(1)[0] = func;
        (slot + 1).view(1)[0] = field(func, PyFunctionObject_CODE);
    }  def _PyFunction_ClearCodeByVersion(version: u32) {
        slot = cache_item(current_interp(), version);
        code = (slot + 1).view(1)[0];
        if code
            and ptr[u32](ptr[u8](code) + PyCodeObject_VERSION).view(1)[0] == version {
            (slot + 1).view(1)[0] = NULL;
            slot.view(1)[0] = NULL;
        }
    }  def _PyFunction_LookupByVersion(
        version: u32, p_code: ptr[ptr[PyObject]]
    ) -> ptr[PyObject] {
        slot = cache_item(current_interp(), version);
        code = (slot + 1).view(1)[0];
        if code {
            if ptr[u32](ptr[u8](code) + PyCodeObject_VERSION).view(1)[0] == version {
                p_code.view(1)[0] = code;
            }
        } else {
            p_code.view(1)[0] = NULL;
        }
        func = slot.view(1)[0];
        if func and func_version(func) == version {
            return func;
        }
        return NULL;
    }  def _PyFunction_GetVersionForCurrentState(func: ptr[PyObject]) -> u32 {
        return func_version(func);
    }  def PyFunction_New(
        code: ptr[PyObject], globals: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyFunction_NewWithQualName(code, globals, NULL);
    }  def PyFunction_GetCode(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return field(op, PyFunctionObject_CODE);
    }  def PyFunction_GetGlobals(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return field(op, PyFunctionObject_GLOBALS);
    }  def PyFunction_GetModule(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return field(op, PyFunctionObject_MODULE);
    }  def PyFunction_GetDefaults(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return field(op, PyFunctionObject_DEFAULTS);
    }  def PyFunction_SetDefaults(
        op: ptr[PyObject], defaults_in: ptr[PyObject]
    ) -> i32 {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        defaults = defaults_in;
        if defaults == Py_None {
            defaults = NULL;
        } elif defaults and tuple_check(defaults) {
            object_incref(defaults);
        } else {
            PyErr_SetString(PyExc_SystemError, "non-tuple default args");
            return i32(-1);
        }
        handle_func_event(EVENT_MODIFY_DEFAULTS, op, defaults);
        clear_version(op);
        replace_field(op, PyFunctionObject_DEFAULTS, defaults);
        return i32(0);
    }  def PyFunction_SetVectorcall(func: ptr[PyObject], vectorcall: ptr) {
        clear_version(func);
        set_vectorcall(func, vectorcall);
    }  def PyFunction_GetKwDefaults(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return field(op, PyFunctionObject_KWDEFAULTS);
    }  def PyFunction_SetKwDefaults(
        op: ptr[PyObject], defaults_in: ptr[PyObject]
    ) -> i32 {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        defaults = defaults_in;
        if defaults == Py_None {
            defaults = NULL;
        } elif defaults and dict_check(defaults) {
            object_incref(defaults);
        } else {
            PyErr_SetString(PyExc_SystemError, "non-dict keyword only default args");
            return i32(-1);
        }
        handle_func_event(EVENT_MODIFY_KWDEFAULTS, op, defaults);
        clear_version(op);
        replace_field(op, PyFunctionObject_KWDEFAULTS, defaults);
        return i32(0);
    }  def PyFunction_GetClosure(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return field(op, PyFunctionObject_CLOSURE);
    }  def PyFunction_SetClosure(op: ptr[PyObject], closure_in: ptr[PyObject]) -> i32 {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        closure = closure_in;
        if closure == Py_None {
            closure = NULL;
        } elif tuple_check(closure) {
            object_incref(closure);
        } else {
            PyErr_Format(
                PyExc_SystemError,
                "expected tuple for closure, got '%.100s'",
                object_type(closure).view(1)[0].tp_name
            );
            return i32(-1);
        }
        clear_version(op);
        replace_field(op, PyFunctionObject_CLOSURE, closure);
        return i32(0);
    }  def PyFunction_GetAnnotations(op: ptr[PyObject]) -> ptr[PyObject] {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return func_get_annotation_dict(op);
    }  def PyFunction_SetAnnotations(
        op: ptr[PyObject], annotations_in: ptr[PyObject]
    ) -> i32 {
        if not function_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        annotations = annotations_in;
        if annotations == Py_None {
            annotations = NULL;
        } elif annotations and dict_check(annotations) {
            object_incref(annotations);
        } else {
            PyErr_SetString(PyExc_SystemError, "non-dict annotations");
            return i32(-1);
        }
        replace_field(op, PyFunctionObject_ANNOTATIONS, annotations);
        replace_field(op, PyFunctionObject_ANNOTATE, NULL);
        return i32(0);
    }  def _Py_set_function_type_params(
        _tstate: ptr, func: ptr[PyObject], type_params: ptr[PyObject]
    ) -> ptr[PyObject] {
        replace_field(func, PyFunctionObject_TYPEPARAMS, object_new_ref(type_params));
        return object_new_ref(func);
    }  def _PyFunction_VerifyStateless(tstate: ptr, func: ptr[PyObject]) -> i32 {
        globalsns = field(func, PyFunctionObject_GLOBALS);
        if globalsns and not dict_check(globalsns) {
            PyErr_Format(PyExc_TypeError, "unsupported globals %R", globalsns);
            return i32(-1);
        }
        builtinsns = field(func, PyFunctionObject_BUILTINS);
        if builtinsns and not dict_check(builtinsns) {
            PyErr_Format(PyExc_TypeError, "unsupported builtins %R", builtinsns);
            return i32(-1);
        }

        defaults = field(func, PyFunctionObject_DEFAULTS);
        if defaults and object_size(defaults) > 0 {
            PyErr_SetString(PyExc_ValueError, "defaults not supported");
            return i32(-1);
        }
        kwdefaults = field(func, PyFunctionObject_KWDEFAULTS);
        if kwdefaults and PyDict_Size(kwdefaults) > 0 {
            PyErr_SetString(PyExc_ValueError, "keyword defaults not supported");
            return i32(-1);
        }
        closure = field(func, PyFunctionObject_CLOSURE);
        if closure and object_size(closure) > 0 {
            PyErr_SetString(PyExc_ValueError, "closures not supported");
            return i32(-1);
        }
        if _PyCode_VerifyStateless(
            tstate, field(func, PyFunctionObject_CODE), NULL, globalsns, builtinsns
        )
            < 0 {
            return i32(-1);
        }
        return i32(0);
    }  def PyClassMethod_New(callable: ptr[PyObject]) -> ptr[PyObject] {
        cm = PyType_GenericAlloc(ptr[PyObject](addressof(PyClassMethod_Type)), 0);
        if cm {
            set_field(cm, classmethod_CALLABLE, object_new_ref(callable));
        }
        return cm;
    }  def PyStaticMethod_New(callable: ptr[PyObject]) -> ptr[PyObject] {
        sm = PyType_GenericAlloc(ptr[PyObject](addressof(PyStaticMethod_Type)), 0);
        if sm {
            set_field(sm, staticmethod_CALLABLE, object_new_ref(callable));
        }
        return sm;
    }  def _PyClassMethod_GetFunc(self: ptr[PyObject]) -> ptr[PyObject] {
        return field(self, classmethod_CALLABLE);
    }  def _PyStaticMethod_GetFunc(self: ptr[PyObject]) -> ptr[PyObject] {
        return field(self, staticmethod_CALLABLE);
    }
}

def func_get_annotation_dict(op: ptr[PyObject]) -> ptr[PyObject];

def func_get_code(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_code(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def func_get_name(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_name(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def func_get_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_qualname(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def func_get_defaults(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def set_defaults_attr(
    self: ptr[PyObject], value_in: ptr[PyObject], keyword: bool
) -> i32;

def func_set_defaults(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def func_get_kwdefaults(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_kwdefaults(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def func_get_annotate(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_annotate(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def func_get_annotations(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_annotations(
    self: ptr[PyObject], value_in: ptr[PyObject], _closure: ptr
) -> i32;

def func_get_type_params(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def func_set_type_params(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def func_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def func_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def func_clear(self: ptr[PyObject]) -> i32;

def func_dealloc(self: ptr[PyObject]);

def func_repr(self: ptr[PyObject]) -> ptr[PyObject];

def func_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def func_descr_get(
    func: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def copy_attr(
    wrapper: ptr[PyObject], wrapped: ptr[PyObject], name: ptr[PyObject]
) -> i32;

def functools_wraps(wrapper: ptr[PyObject], wrapped: ptr[PyObject]) -> i32;

def descriptor_get_wrapped_attribute(
    wrapped: ptr[PyObject], ob: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def descriptor_set_wrapped_attribute(
    ob: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject], type_name: str
) -> i32;

def wrapper_dealloc(self: ptr[PyObject], callable_offset: i64, dict_offset: i64);

def wrapper_isabstract(callable: ptr[PyObject]) -> ptr[PyObject];

def wrapper_init(
    self: ptr[PyObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject],
    name: ptr[u8],
    callable_offset: i64
) -> i32;

def wrapper_new(
    type: ptr[PyObject], callable_offset: i64, dict_offset: i64
) -> ptr[PyObject];

def cm_dealloc(self: ptr[PyObject]);

def cm_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def cm_clear(self: ptr[PyObject]) -> i32;

def cm_descr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def cm_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def cm_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def cm_get___isabstractmethod__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cm_get___annotations__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cm_set___annotations__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def cm_get___annotate__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def cm_set___annotate__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def cm_repr(self: ptr[PyObject]) -> ptr[PyObject];

def sm_dealloc(self: ptr[PyObject]);

def sm_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def sm_clear(self: ptr[PyObject]) -> i32;

def sm_descr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def sm_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def sm_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def sm_call(
    callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def sm_get___isabstractmethod__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def sm_get___annotations__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def sm_set___annotations__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def sm_get___annotate__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def sm_set___annotate__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def sm_repr(self: ptr[PyObject]) -> ptr[PyObject];

impl field(op: ptr[PyObject], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0];
}

impl set_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0] = value;
}

impl replace_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    old = field(op, offset);
    set_field(op, offset, value);
    object_xdecref(old);
}

impl func_version(op: ptr[PyObject]) -> u32 {
    return ptr[u32](ptr[u8](op) + PyFunctionObject_VERSION).view(1)[0];
}

impl set_func_version(op: ptr[PyObject], version: u32) {
    ptr[u32](ptr[u8](op) + PyFunctionObject_VERSION).view(1)[0] = version;
}

impl set_vectorcall(op: ptr[PyObject], vectorcall: ptr) {
    ptr[ptr](ptr[u8](op) + PyFunctionObject_VECTORCALL).view(1)[0] = vectorcall;
}

impl code_i32(code: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](code) + offset).view(1)[0];
}

impl function_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyFunction_Type));
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl interned(which: int) -> ptr[PyObject] {
    if which == 0 {
        if not name_key {
            name_key = PyUnicode_InternFromString(ptr[u8]("__name__"));
        }
        return name_key;
    }
    if which == 1 {
        if not module_key {
            module_key = PyUnicode_InternFromString(ptr[u8]("__module__"));
        }
        return module_key;
    }
    if which == 2 {
        if not qualname_key {
            qualname_key = PyUnicode_InternFromString(ptr[u8]("__qualname__"));
        }
        return qualname_key;
    }
    if which == 3 {
        if not doc_key {
            doc_key = PyUnicode_InternFromString(ptr[u8]("__doc__"));
        }
        return doc_key;
    }
    if which == 4 {
        if not annotations_key {
            annotations_key = PyUnicode_InternFromString(ptr[u8]("__annotations__"));
        }
        return annotations_key;
    }
    if not annotate_key {
        annotate_key = PyUnicode_InternFromString(ptr[u8]("__annotate__"));
    }
    return annotate_key;
}

impl func_event_name(event: i32) -> str {
    if event == EVENT_CREATE {
        return "PyFunction_EVENT_CREATE";
    }
    if event == EVENT_DESTROY {
        return "PyFunction_EVENT_DESTROY";
    }
    if event == EVENT_MODIFY_CODE {
        return "PyFunction_EVENT_MODIFY_CODE";
    }
    if event == EVENT_MODIFY_DEFAULTS {
        return "PyFunction_EVENT_MODIFY_DEFAULTS";
    }
    return "PyFunction_EVENT_MODIFY_KWDEFAULTS";
}

impl active_watchers(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_ACTIVE_FUNC_WATCHERS;
}

impl watcher_slot(interp: ptr[u8], i: i64) -> ptr[int] {
    return ptr[int](interp + PyInterpreterState_FUNC_WATCHERS) + i;
}

impl notify_func_watchers(
    interp: ptr[u8], event: i32, func: ptr[PyObject], new_value: ptr[PyObject]
) {
    bits = active_watchers(interp).view(1)[0];
    i: i64 = 0;
    calls = ptr[FuncCall](__thread_local_block("jac_object_model_func_call_slot", 16));
    while bits != u8(0) {
        if (bits & u8(1)) != u8(0) {
            calls.view(1)[0].watcher = watcher_slot(interp, i).view(1)[0];
            if calls.view(1)[0].watcher(event, func, new_value) < 0 {
                PyErr_FormatUnraisable(
                    "Exception ignored in %s watcher callback for function %U at %p",
                    func_event_name(event),
                    field(func, PyFunctionObject_QUALNAME),
                    ptr(func)
                );
            }
        }
        i += 1;
        bits = bits >> u8(1);
    }
}

impl handle_func_event(event: i32, func: ptr[PyObject], new_value: ptr[PyObject]) {
    interp = current_interp();
    if active_watchers(interp).view(1)[0] != u8(0) {
        notify_func_watchers(interp, event, func, new_value);
    }
    if event == EVENT_MODIFY_CODE
        or event == EVENT_MODIFY_DEFAULTS
        or event == EVENT_MODIFY_KWDEFAULTS {
        counter = interp + PyInterpreterState_RARE_FUNC_MODIFICATION;
        if counter.view(1)[0] < u8(255) {
            counter.view(1)[0] = counter.view(1)[0] + u8(1);
        }
    }
}

impl cache_item(interp: ptr[u8], version: u32) -> ptr[ptr[PyObject]] {
    index = i64(version) % FUNC_VERSION_CACHE_SIZE;
    return ptr[ptr[PyObject]](
        interp + PyInterpreterState_FUNC_VERSION_CACHE + index * 16
    );
}

impl func_clear_version(interp: ptr[u8], func: ptr[PyObject]) {
    if func_version(func) < FUNC_VERSION_FIRST_VALID {
        return;
    }
    slot = cache_item(interp, func_version(func));
    if slot.view(1)[0] == func {
        slot.view(1)[0] = NULL;
    }
    set_func_version(func, FUNC_VERSION_CLEARED);
}

impl clear_version(func: ptr[PyObject]) {
    func_clear_version(current_interp(), func);
}

impl new_function(
    globals: ptr[PyObject],
    builtins: ptr[PyObject],
    name: ptr[PyObject],
    qualname: ptr[PyObject],
    code: ptr[PyObject],
    doc: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject] {
    op = _PyObject_GC_New(ptr[PyObject](addressof(PyFunction_Type)));
    if not op {
        return NULL;
    }

    set_field(op, PyFunctionObject_GLOBALS, globals);
    set_field(op, PyFunctionObject_BUILTINS, builtins);
    set_field(op, PyFunctionObject_NAME, name);
    set_field(op, PyFunctionObject_QUALNAME, qualname);
    set_field(op, PyFunctionObject_CODE, code);
    set_field(op, PyFunctionObject_DEFAULTS, NULL);
    set_field(op, PyFunctionObject_KWDEFAULTS, NULL);
    set_field(op, PyFunctionObject_CLOSURE, NULL);
    set_field(op, PyFunctionObject_DOC, doc);
    set_field(op, PyFunctionObject_DICT, NULL);
    set_field(op, PyFunctionObject_WEAKREFLIST, NULL);
    set_field(op, PyFunctionObject_MODULE, module);
    set_field(op, PyFunctionObject_ANNOTATIONS, NULL);
    set_field(op, PyFunctionObject_ANNOTATE, NULL);
    set_field(op, PyFunctionObject_TYPEPARAMS, NULL);
    set_vectorcall(op, ptr(_PyFunction_Vectorcall));
    set_func_version(op, FUNC_VERSION_UNSET);
    return op;
}

impl func_get_annotation_dict(op: ptr[PyObject]) -> ptr[PyObject] {
    annotations = field(op, PyFunctionObject_ANNOTATIONS);
    if not annotations {
        annotate = field(op, PyFunctionObject_ANNOTATE);
        if not annotate or PyCallable_Check(annotate) == 0 {
            return Py_None;
        }
        ann_dict = PyObject_CallOneArg(annotate, PyLong_FromLong(1));
        if not ann_dict {
            return NULL;
        }
        if not dict_check(ann_dict) {
            PyErr_Format(
                PyExc_TypeError,
                "__annotate__ returned non-dict of type '%.100s'",
                object_type(ann_dict).view(1)[0].tp_name
            );
            object_decref(ann_dict);
            return NULL;
        }
        replace_field(op, PyFunctionObject_ANNOTATIONS, ann_dict);
        return ann_dict;
    }
    if object_is_type(annotations, ptr[PyTypeObject](addressof(PyTuple_Type))) {
        ann_dict = PyDict_New();
        if not ann_dict {
            return NULL;
        }
        i: i64 = 0;
        while i < object_size(annotations) {
            if PyDict_SetItem(
                ann_dict,
                tuple_get_item(annotations, i),
                tuple_get_item(annotations, i + 1)
            )
                < 0 {
                object_decref(ann_dict);
                return NULL;
            }
            i += 2;
        }
        replace_field(op, PyFunctionObject_ANNOTATIONS, ann_dict);
    }
    return field(op, PyFunctionObject_ANNOTATIONS);
}

impl func_get_code(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if PySys_Audit("object.__getattr__", "Os", self, "__code__") < 0 {
        return NULL;
    }
    return object_new_ref(field(self, PyFunctionObject_CODE));
}

impl func_set_code(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32 {
    if not value
        or not object_type_check(value, ptr[PyTypeObject](addressof(PyCode_Type))) {
        PyErr_SetString(PyExc_TypeError, "__code__ must be set to a code object");
        return i32(-1);
    }
    if PySys_Audit("object.__setattr__", "OsO", self, "__code__", value) < 0 {
        return i32(-1);
    }
    nfree = code_i32(value, PyCodeObject_NFREEVARS);
    closure = field(self, PyFunctionObject_CLOSURE);
    nclosure: i64 = 0;
    if closure {
        nclosure = object_size(closure);
    }
    if nclosure != i64(nfree) {
        PyErr_Format(
            PyExc_ValueError,
            "%U() requires a code object with %zd free vars, not %d",
            field(self, PyFunctionObject_NAME),
            nclosure,
            nfree
        );
        return i32(-1);
    }
    old_flags = code_i32(field(self, PyFunctionObject_CODE), PyCodeObject_FLAGS);
    new_flags = code_i32(value, PyCodeObject_FLAGS);
    mask = CO_GENERATOR | CO_COROUTINE | CO_ASYNC_GENERATOR;
    if (old_flags & mask) != (new_flags & mask) {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "Assigning a code object of non-matching type is deprecated (e.g., from a generator to a plain function)",
            1
        )
            < 0 {
            return i32(-1);
        }
    }
    handle_func_event(EVENT_MODIFY_CODE, self, value);
    clear_version(self);
    replace_field(self, PyFunctionObject_CODE, object_new_ref(value));
    return i32(0);
}

impl func_get_name(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return object_new_ref(field(self, PyFunctionObject_NAME));
}

impl func_set_name(self: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32 {
    if not value or not unicode_check(value) {
        PyErr_SetString(PyExc_TypeError, "__name__ must be set to a string object");
        return i32(-1);
    }
    replace_field(self, PyFunctionObject_NAME, object_new_ref(value));
    return i32(0);
}

impl func_get_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return object_new_ref(field(self, PyFunctionObject_QUALNAME));
}

impl func_set_qualname(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    if not value or not unicode_check(value) {
        PyErr_SetString(PyExc_TypeError, "__qualname__ must be set to a string object");
        return i32(-1);
    }
    replace_field(self, PyFunctionObject_QUALNAME, object_new_ref(value));
    return i32(0);
}

impl func_get_defaults(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if PySys_Audit("object.__getattr__", "Os", self, "__defaults__") < 0 {
        return NULL;
    }
    defaults = field(self, PyFunctionObject_DEFAULTS);
    return object_new_ref(defaults or Py_None);
}

impl set_defaults_attr(
    self: ptr[PyObject], value_in: ptr[PyObject], keyword: bool
) -> i32 {
    value = NULL if value_in == Py_None else value_in;
    attr = "__kwdefaults__" if keyword else "__defaults__";
    if value and (dict_check(value) if keyword else tuple_check(value)) == False {
        PyErr_SetString(
            PyExc_TypeError,
            "__kwdefaults__ must be set to a dict object"
                if keyword
                else "__defaults__ must be set to a tuple object"
        );
        return i32(-1);
    }
    if value {
        if PySys_Audit("object.__setattr__", "OsO", self, attr, value) < 0 {
            return i32(-1);
        }
    } elif PySys_Audit("object.__delattr__", "Os", self, attr) < 0 {
        return i32(-1);
    }
    handle_func_event(
        EVENT_MODIFY_KWDEFAULTS if keyword else EVENT_MODIFY_DEFAULTS, self, value
    );
    clear_version(self);
    replace_field(
        self,
        PyFunctionObject_KWDEFAULTS if keyword else PyFunctionObject_DEFAULTS,
        object_xnew_ref(value)
    );
    return i32(0);
}

impl func_set_defaults(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return set_defaults_attr(self, value, False);
}

impl func_get_kwdefaults(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    if PySys_Audit("object.__getattr__", "Os", self, "__kwdefaults__") < 0 {
        return NULL;
    }
    defaults = field(self, PyFunctionObject_KWDEFAULTS);
    return object_new_ref(defaults or Py_None);
}

impl func_set_kwdefaults(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return set_defaults_attr(self, value, True);
}

impl func_get_annotate(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    annotate = field(self, PyFunctionObject_ANNOTATE);
    return object_new_ref(annotate or Py_None);
}

impl func_set_annotate(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    if not value {
        PyErr_SetString(PyExc_TypeError, "__annotate__ cannot be deleted");
        return i32(-1);
    }
    if value == Py_None {
        replace_field(self, PyFunctionObject_ANNOTATE, value);
        return i32(0);
    }
    if PyCallable_Check(value) != 0 {
        replace_field(self, PyFunctionObject_ANNOTATE, object_new_ref(value));
        replace_field(self, PyFunctionObject_ANNOTATIONS, NULL);
        return i32(0);
    }
    PyErr_SetString(PyExc_TypeError, "__annotate__ must be callable or None");
    return i32(-1);
}

impl func_get_annotations(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    annotate = field(self, PyFunctionObject_ANNOTATE);
    if not field(self, PyFunctionObject_ANNOTATIONS)
        and (not annotate or PyCallable_Check(annotate) == 0) {
        d = PyDict_New();
        if not d {
            return NULL;
        }
        set_field(self, PyFunctionObject_ANNOTATIONS, d);
    }
    return object_xnew_ref(func_get_annotation_dict(self));
}

impl func_set_annotations(
    self: ptr[PyObject], value_in: ptr[PyObject], _closure: ptr
) -> i32 {
    value = NULL if value_in == Py_None else value_in;

    if value and not dict_check(value) {
        PyErr_SetString(
            PyExc_TypeError, "__annotations__ must be set to a dict object"
        );
        return i32(-1);
    }
    replace_field(self, PyFunctionObject_ANNOTATIONS, object_xnew_ref(value));
    replace_field(self, PyFunctionObject_ANNOTATE, NULL);
    return i32(0);
}

impl func_get_type_params(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    params = field(self, PyFunctionObject_TYPEPARAMS);
    if not params {
        return PyTuple_New(0);
    }
    return object_new_ref(params);
}

impl func_set_type_params(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    if not value or not tuple_check(value) {
        PyErr_SetString(PyExc_TypeError, "__type_params__ must be set to a tuple");
        return i32(-1);
    }
    replace_field(self, PyFunctionObject_TYPEPARAMS, object_new_ref(value));
    return i32(0);
}

impl func_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    code = values.view(1)[0];
    globals = (values + 1).view(1)[0];
    name = (values + 2).view(1)[0] if (values + 2).view(1)[0] else Py_None;
    defaults = (values + 3).view(1)[0] if (values + 3).view(1)[0] else Py_None;
    closure = (values + 4).view(1)[0] if (values + 4).view(1)[0] else Py_None;
    kwdefaults = (values + 5).view(1)[0] if (values + 5).view(1)[0] else Py_None;
    if not object_type_check(code, ptr[PyTypeObject](addressof(PyCode_Type))) {
        _PyArg_BadArgument(
            ptr[u8]("function"),
            ptr[u8]("argument 'code'"),
            ptr[PyTypeObject](addressof(PyCode_Type)).view(1)[0].tp_name,
            code
        );
        return NULL;
    }
    if not dict_check(globals) {
        _PyArg_BadArgument(
            ptr[u8]("function"), ptr[u8]("argument 'globals'"), ptr[u8]("dict"), globals
        );
        return NULL;
    }
    if name != Py_None and not unicode_check(name) {
        PyErr_SetString(PyExc_TypeError, "arg 3 (name) must be None or string");
        return NULL;
    }
    if defaults != Py_None and not tuple_check(defaults) {
        PyErr_SetString(PyExc_TypeError, "arg 4 (defaults) must be None or tuple");
        return NULL;
    }
    nfree = code_i32(code, PyCodeObject_NFREEVARS);
    if not tuple_check(closure) {
        if nfree != 0 and closure == Py_None {
            PyErr_SetString(PyExc_TypeError, "arg 5 (closure) must be tuple");
            return NULL;
        }
        if closure != Py_None {
            PyErr_SetString(PyExc_TypeError, "arg 5 (closure) must be None or tuple");
            return NULL;
        }
    }
    if kwdefaults != Py_None and not dict_check(kwdefaults) {
        PyErr_SetString(PyExc_TypeError, "arg 6 (kwdefaults) must be None or dict");
        return NULL;
    }
    nclosure: i64 = 0;
    if closure != Py_None {
        nclosure = object_size(closure);
    }
    if i64(nfree) != nclosure {
        return PyErr_Format(
            PyExc_ValueError,
            "%U requires closure of length %d, not %zd",
            field(code, PyCodeObject_NAME),
            nfree,
            nclosure
        );
    }
    for i in range(nclosure) {
        o = tuple_get_item(closure, i);
        if not object_is_type(o, ptr[PyTypeObject](addressof(PyCell_Type))) {
            return PyErr_Format(
                PyExc_TypeError,
                "arg 5 (closure) expected cell, found %s",
                object_type(o).view(1)[0].tp_name
            );
        }
    }
    if PySys_Audit("function.__new__", "O", code) < 0 {
        return NULL;
    }
    newfunc = PyFunction_New(code, globals);
    if not newfunc {
        return NULL;
    }
    if name != Py_None {
        replace_field(newfunc, PyFunctionObject_NAME, object_new_ref(name));
    }
    if defaults != Py_None {
        set_field(newfunc, PyFunctionObject_DEFAULTS, object_new_ref(defaults));
    }
    if closure != Py_None {
        set_field(newfunc, PyFunctionObject_CLOSURE, object_new_ref(closure));
    }
    if kwdefaults != Py_None {
        set_field(newfunc, PyFunctionObject_KWDEFAULTS, object_new_ref(kwdefaults));
    }
    return newfunc;
}

impl func_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_tuple(func_new_signature, args, kwargs, func_new_values, type);
}

impl func_clear(self: ptr[PyObject]) -> i32 {
    func_clear_version(current_interp(), self);
    for offset in [
        PyFunctionObject_GLOBALS,
        PyFunctionObject_BUILTINS,
        PyFunctionObject_MODULE,
        PyFunctionObject_DEFAULTS,
        PyFunctionObject_KWDEFAULTS,
        PyFunctionObject_DOC,
        PyFunctionObject_DICT,
        PyFunctionObject_CLOSURE,
        PyFunctionObject_ANNOTATIONS,
        PyFunctionObject_ANNOTATE,
        PyFunctionObject_TYPEPARAMS
    ] {
        replace_field(self, offset, NULL);
    }

    replace_field(self, PyFunctionObject_NAME, PyUnicode_FromString(ptr[u8]("")));
    replace_field(self, PyFunctionObject_QUALNAME, PyUnicode_FromString(ptr[u8]("")));
    return i32(0);
}

impl func_dealloc(self: ptr[PyObject]) {
    if active_watchers(current_interp()).view(1)[0] != u8(0) {
        header = ptr[_object](self);
        full = header.view(1)[0].ob_refcnt_full;
        header.view(1)[0].ob_refcnt_full = (full & ~i64(4294967295)) | 1;
        handle_func_event(EVENT_DESTROY, self, NULL);
        refcnt = object_refcount(self) - 1;
        full = header.view(1)[0].ob_refcnt_full;
        header.view(1)[0].ob_refcnt_full = (full & ~i64(4294967295))
            | (refcnt & i64(4294967295));
        if refcnt != 0 {
            return;
        }
    }
    object_gc_untrack(self);
    if field(self, PyFunctionObject_WEAKREFLIST) {
        PyObject_ClearWeakRefs(self);
    }
    func_clear(self);

    object_decref(field(self, PyFunctionObject_CODE));
    object_decref(field(self, PyFunctionObject_NAME));
    object_decref(field(self, PyFunctionObject_QUALNAME));
    PyObject_GC_Del(ptr(self));
}

impl func_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<function %U at %p>", field(self, PyFunctionObject_QUALNAME), ptr(self)
    );
}

impl func_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    for offset in [
        PyFunctionObject_CODE,
        PyFunctionObject_GLOBALS,
        PyFunctionObject_BUILTINS,
        PyFunctionObject_MODULE,
        PyFunctionObject_DEFAULTS,
        PyFunctionObject_KWDEFAULTS,
        PyFunctionObject_DOC,
        PyFunctionObject_NAME,
        PyFunctionObject_DICT,
        PyFunctionObject_CLOSURE,
        PyFunctionObject_ANNOTATIONS,
        PyFunctionObject_ANNOTATE,
        PyFunctionObject_TYPEPARAMS,
        PyFunctionObject_QUALNAME
    ] {
        status = visit_reference(field(self, offset), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl func_descr_get(
    func: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if ob == Py_None or not ob {
        return object_new_ref(func);
    }
    return PyMethod_New(func, ob);
}

impl copy_attr(
    wrapper: ptr[PyObject], wrapped: ptr[PyObject], name: ptr[PyObject]
) -> i32 {
    value: ptr[PyObject] = NULL;
    res = PyObject_GetOptionalAttr(wrapped, name, &mut value);
    if value {
        res = PyObject_SetAttr(wrapper, name, value);
        object_decref(value);
    }
    return res;
}

impl functools_wraps(wrapper: ptr[PyObject], wrapped: ptr[PyObject]) -> i32 {
    for which in [1, 0, 2, 3] {
        if copy_attr(wrapper, wrapped, interned(which)) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

impl descriptor_get_wrapped_attribute(
    wrapped: ptr[PyObject], ob: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    dict = PyObject_GenericGetDict(ob, ptr());
    if not dict {
        return NULL;
    }
    res: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(dict, name, &mut res) < 0 {
        object_decref(dict);
        return NULL;
    }
    if res {
        object_decref(dict);
        return res;
    }
    res = PyObject_GetAttr(wrapped, name);
    if not res {
        object_decref(dict);
        return NULL;
    }
    if PyDict_SetItem(dict, name, res) < 0 {
        object_decref(dict);
        object_decref(res);
        return NULL;
    }
    object_decref(dict);
    return res;
}

impl descriptor_set_wrapped_attribute(
    ob: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject], type_name: str
) -> i32 {
    dict = PyObject_GenericGetDict(ob, ptr());
    if not dict {
        return i32(-1);
    }
    if not value {
        if PyDict_DelItem(dict, name) < 0 {
            if PyErr_ExceptionMatches(PyExc_KeyError) != 0 {
                PyErr_Clear();
                PyErr_Format(
                    PyExc_AttributeError,
                    "'%.200s' object has no attribute '%U'",
                    type_name,
                    name
                );
            }
            object_decref(dict);
            return i32(-1);
        }
        object_decref(dict);
        return i32(0);
    }

    object_decref(dict);
    return PyDict_SetItem(dict, name, value);
}

impl wrapper_dealloc(self: ptr[PyObject], callable_offset: i64, dict_offset: i64) {
    object_gc_untrack(self);
    object_xdecref(field(self, callable_offset));
    object_xdecref(field(self, dict_offset));
    calls = ptr[FuncCall](__thread_local_block("jac_object_model_func_call_slot", 16));
    calls.view(1)[0].free = int(object_type(self).view(1)[0].tp_free);
    calls.view(1)[0].free(ptr(self));
}

impl wrapper_isabstract(callable: ptr[PyObject]) -> ptr[PyObject] {
    res = _PyObject_IsAbstract(callable);
    if res == -1 {
        return NULL;
    }
    return PyBool_FromLong(1 if res != 0 else 0);
}

impl wrapper_init(
    self: ptr[PyObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject],
    name: ptr[u8],
    callable_offset: i64
) -> i32 {
    if kwds and _PyArg_NoKeywords(name, kwds) == 0 {
        return i32(-1);
    }
    if _PyArg_CheckPositional(name, object_size(args), 1, 1) == 0 {
        return i32(-1);
    }
    replace_field(self, callable_offset, object_new_ref(tuple_get_item(args, 0)));
    if functools_wraps(self, field(self, callable_offset)) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl wrapper_new(
    type: ptr[PyObject], callable_offset: i64, dict_offset: i64
) -> ptr[PyObject] {
    ob = PyType_GenericAlloc(type, 0);
    if not ob {
        return NULL;
    }
    set_field(ob, callable_offset, Py_None);
    set_field(ob, dict_offset, NULL);
    return ob;
}

impl cm_dealloc(self: ptr[PyObject]) {
    wrapper_dealloc(self, classmethod_CALLABLE, classmethod_DICT);
}

impl cm_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(field(self, classmethod_CALLABLE), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(field(self, classmethod_DICT), visitor, arg);
}

impl cm_clear(self: ptr[PyObject]) -> i32 {
    replace_field(self, classmethod_CALLABLE, NULL);
    replace_field(self, classmethod_DICT, NULL);
    return i32(0);
}

impl cm_descr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    callable = field(self, classmethod_CALLABLE);
    if not callable {
        PyErr_SetString(PyExc_RuntimeError, "uninitialized classmethod object");
        return NULL;
    }
    return PyMethod_New(callable, type or ptr[PyObject](object_type(ob)));
}

impl cm_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return wrapper_new(type, classmethod_CALLABLE, classmethod_DICT);
}

impl cm_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    return wrapper_init(self, args, kwds, ptr[u8]("classmethod"), classmethod_CALLABLE);
}

impl cm_get___isabstractmethod__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return wrapper_isabstract(field(self, classmethod_CALLABLE));
}

impl cm_get___annotations__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return descriptor_get_wrapped_attribute(
        field(self, classmethod_CALLABLE), self, interned(4)
    );
}

impl cm_set___annotations__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return descriptor_set_wrapped_attribute(self, interned(4), value, "classmethod");
}

impl cm_get___annotate__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return descriptor_get_wrapped_attribute(
        field(self, classmethod_CALLABLE), self, interned(5)
    );
}

impl cm_set___annotate__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return descriptor_set_wrapped_attribute(self, interned(5), value, "classmethod");
}

impl cm_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat("<classmethod(%R)>", field(self, classmethod_CALLABLE));
}

impl sm_dealloc(self: ptr[PyObject]) {
    wrapper_dealloc(self, staticmethod_CALLABLE, staticmethod_DICT);
}

impl sm_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(field(self, staticmethod_CALLABLE), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(field(self, staticmethod_DICT), visitor, arg);
}

impl sm_clear(self: ptr[PyObject]) -> i32 {
    replace_field(self, staticmethod_CALLABLE, NULL);
    replace_field(self, staticmethod_DICT, NULL);
    return i32(0);
}

impl sm_descr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    callable = field(self, staticmethod_CALLABLE);
    if not callable {
        PyErr_SetString(PyExc_RuntimeError, "uninitialized staticmethod object");
        return NULL;
    }
    return object_new_ref(callable);
}

impl sm_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return wrapper_new(type, staticmethod_CALLABLE, staticmethod_DICT);
}

impl sm_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    return wrapper_init(
        self, args, kwds, ptr[u8]("staticmethod"), staticmethod_CALLABLE
    );
}

impl sm_call(
    callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return PyObject_Call(field(callable, staticmethod_CALLABLE), args, kwargs);
}

impl sm_get___isabstractmethod__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return wrapper_isabstract(field(self, staticmethod_CALLABLE));
}

impl sm_get___annotations__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return descriptor_get_wrapped_attribute(
        field(self, staticmethod_CALLABLE), self, interned(4)
    );
}

impl sm_set___annotations__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return descriptor_set_wrapped_attribute(self, interned(4), value, "staticmethod");
}

impl sm_get___annotate__(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return descriptor_get_wrapped_attribute(
        field(self, staticmethod_CALLABLE), self, interned(5)
    );
}

impl sm_set___annotate__(
    self: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return descriptor_set_wrapped_attribute(self, interned(5), value, "staticmethod");
}

impl sm_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<staticmethod(%R)>", field(self, staticmethod_CALLABLE)
    );
}
