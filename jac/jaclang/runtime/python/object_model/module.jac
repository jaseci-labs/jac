import from c {
    glob PyType_Type: PyTypeObject; def PySys_FormatStderr(
        format: ptr[u8], *args: any
    );  def PySys_WriteStderr(format: ptr[u8], *args: any);  def PyUnicode_AsWideChar(
        unicode: ptr[PyObject], w: ptr, size: i64
    ) -> i64;  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def _PyImport_GetNextModuleIndex -> i64;  def _PyImport_IsInitialized(
        interp: ptr
    ) -> i32;  def _PyImport_ResolveNameWithPackageContext(name: ptr[u8]) -> ptr[u8];  def _PyImport_CheckSubinterpIncompatibleExtensionAllowed(
        name: ptr[u8]
    ) -> i32;  def _PyImport_ImportlibModuleRepr(
        interp: ptr, module: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyErr_FormatFromCause(
        exception: ptr[PyObject], format: ptr[u8], *args: any
    ) -> ptr[PyObject];  def _PyType_AllocNoTrack(
        type: ptr[PyTypeObject], nitems: i64
    ) -> ptr[PyObject];  def _Py_GetConfig -> ptr[u8];  def _PySys_GetOptionalAttrString(
        name: ptr[u8], value: &mut ptr[PyObject]
    ) -> i32;  def _PyObject_GenericGetAttrWithDict(
        ob: ptr[PyObject], name: ptr[PyObject], dict: ptr[PyObject], suppress: i32
    ) -> ptr[PyObject];  def _PyUnicode_EqualToASCIIString(
        unicode: ptr[PyObject], text: ptr[u8]
    ) -> i32;  def _Py_wgetcwd(buffer: ptr[i32], size: u64) -> ptr[i32];  def wcsrchr(
        text: ptr[i32], c: i32
    ) -> ptr[i32];  def wcscmp(left: ptr[i32], right: ptr[i32]) -> i32;  def strcpy(
        target: ptr[u8], source: ptr[u8]
    ) -> ptr[u8];  def PyErr_FormatUnraisable(format: ptr[u8], *args: any);  obj ModuleCall {
        has create: Callable[[ptr[PyObject], ptr[PyModuleDef]], ptr[PyObject]] = 0,
            exec: Callable[[ptr[PyObject]], i32] = 0,
            traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0,
            clear: Callable[[ptr[PyObject]], i32] = 0,
            free: Callable[[ptr], None] = 0;
    }  glob:priv module_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__dict__"),
                 type_=_Py_T_OBJECT,
                 offset=PyModuleObject_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         module_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__dir__"),
                 ml_meth=ptr(module_dir),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__dir__() -> list\nspecialized dir() implementation")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         module_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__annotations__"),
                 get=module_get_annotations,
                 set=module_set_annotations
             ),
             PyGetSetDef(
                 name=ptr[u8]("__annotate__"),
                 get=module_get_annotate,
                 set=module_set_annotate
             ),
             PyGetSetDef()
         ]; glob PyModuleDef_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("moduledef"),
             tp_basicsize=PyModuleDef_SIZE
         ),
         PyModule_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("module"),
             tp_basicsize=PyModuleObject_SIZE,
             tp_dealloc=module_dealloc,
             tp_repr=module_repr,
             tp_getattro=_Py_module_getattro,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "module(name, doc=None)\n--\n\n"
                 "Create a module object.\n\n"
                 "The name must be a string; the optional doc argument can have any type."
             ),
             tp_traverse=module_traverse,
             tp_clear=module_clear,
             tp_weaklistoffset=PyModuleObject_WEAKLIST,
             tp_methods=addressof(module_methods),
             tp_members=addressof(module_members),
             tp_getset=addressof(module_getsets),
             tp_dictoffset=PyModuleObject_DICT,
             tp_init=module___init__,
             tp_new=new_module,
             tp_free=PyObject_GC_Del
         );
}

glob:priv PYTHON_API_VERSION: i32 = 1013,
     PYTHON_ABI_VERSION: i32 = 3,
     MAXPATHLEN: i64 = 4096,
     SEP: i32 = 47,
     UNDERSCORE: i64 = 95,
     SLOT_CREATE: i32 = 1,
     SLOT_EXEC: i32 = 2,
     SLOT_MULTIPLE_INTERPRETERS: i32 = 3,
     SLOT_GIL: i32 = 4,
     LAST_SLOT: i32 = 4,
     MULTIPLE_INTERPRETERS_NOT_SUPPORTED: i64 = 0,
     MULTIPLE_INTERPRETERS_SUPPORTED: i64 = 1,
     PER_INTERPRETER_GIL_SUPPORTED: i64 = 2;

def module_of(op: ptr[PyObject]) -> ptr[PyModuleObject];

def module_check(op: ptr[PyObject]) -> bool;

def unicode_check(op: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def config_int(offset: i64) -> i32;

def dict_get(dict: ptr[PyObject], name: str) -> tuple[i32, ptr[PyObject]];

def optional_attr(op: ptr[PyObject], name: str) -> tuple[i32, ptr[PyObject]];

def module_init_dict(
    m: ptr[PyObject], md_dict: ptr[PyObject], name: ptr[PyObject], doc_in: ptr[PyObject]
) -> i32;

def new_module_notrack(mt: ptr[PyTypeObject]) -> ptr[PyObject];

def new_module(
    mt: ptr[PyTypeObject], args: ptr[PyObject], kws: ptr[PyObject]
) -> ptr[PyObject];

def check_api_version(name: ptr[u8], module_api_version: i32) -> bool;

def add_methods_to_object(
    module: ptr[PyObject], name: ptr[PyObject], functions: ptr[PyMethodDef]
) -> i32;

def def_fields(mdef: ptr[PyModuleDef]) -> ptr[ModuleDef];

def def_of(op: ptr[PyObject]) -> ptr[PyModuleDef];

def hooks_ready(op: ptr[PyObject]) -> bool;

def allocate_state(op: ptr[PyObject], size: i64) -> bool;

import from c {
    def _PyModule_IsExtension(ob: ptr[PyObject]) -> i32 {
        if not module_check(ob) {
            return i32(0);
        }
        mdef = def_of(ob);
        return i32(1) if mdef and def_fields(mdef).view(1)[0].m_methods else i32(0);
    }  def PyModuleDef_Init(mdef: ptr[PyModuleDef]) -> ptr[PyObject] {
        base = ptr[PyModuleDef_Base](mdef);
        if base.view(1)[0].m_index == 0 {
            header = ptr[_object](mdef);
            header.view(1)[0].ob_refcnt_full = 1;
            header.view(1)[0].ob_type = addressof(PyModuleDef_Type);
            base.view(1)[0].m_index = _PyImport_GetNextModuleIndex();
        }
        return ptr[PyObject](mdef);
    }  def PyModule_NewObject(name: ptr[PyObject]) -> ptr[PyObject] {
        m = new_module_notrack(addressof(PyModule_Type));
        if not m {
            return NULL;
        }
        if module_init_dict(m, module_of(m).view(1)[0].md_dict, name, NULL) != 0 {
            object_decref(m);
            return NULL;
        }
        object_gc_track(m);
        return m;
    }  def PyModule_New(name: ptr[u8]) -> ptr[PyObject] {
        nameobj = PyUnicode_FromString(name);
        if not nameobj {
            return NULL;
        }
        module = PyModule_NewObject(nameobj);
        object_decref(nameobj);
        return module;
    }  def PyModule_Create2(
        module: ptr[PyModuleDef], module_api_version: i32
    ) -> ptr[PyObject] {
        if _PyImport_IsInitialized(ptr(current_interp())) == 0 {
            PyErr_SetString(
                PyExc_SystemError, ptr[u8]("Python import machinery not initialized")
            );
            return NULL;
        }
        return _PyModule_CreateInitialized(module, module_api_version);
    }  def _PyModule_CreateInitialized(
        module: ptr[PyModuleDef], module_api_version: i32
    ) -> ptr[PyObject] {
        if not PyModuleDef_Init(module) {
            return NULL;
        }
        name = def_fields(module).view(1)[0].m_name;
        if not check_api_version(name, module_api_version) {
            return NULL;
        }
        if def_fields(module).view(1)[0].m_slots {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("module %s: PyModule_Create is incompatible with m_slots"),
                name
            );
            return NULL;
        }
        name = _PyImport_ResolveNameWithPackageContext(name);
        m = PyModule_New(name);
        if not m {
            return NULL;
        }
        if def_fields(module).view(1)[0].m_size > 0
            and not allocate_state(m, def_fields(module).view(1)[0].m_size) {
            object_decref(m);
            return NULL;
        }
        if def_fields(module).view(1)[0].m_methods
            and PyModule_AddFunctions(m, def_fields(module).view(1)[0].m_methods)
                != 0 {
            object_decref(m);
            return NULL;
        }
        if def_fields(module).view(1)[0].m_doc
            and PyModule_SetDocString(m, def_fields(module).view(1)[0].m_doc) != 0 {
            object_decref(m);
            return NULL;
        }
        module_of(m).view(1)[0].md_def = ptr[ModuleDef](module);
        return m;
    }  def PyModule_FromDefAndSpec2(
        mdef: ptr[PyModuleDef], spec: ptr[PyObject], module_api_version: i32
    ) -> ptr[PyObject] {
        interp = ptr(current_interp());
        PyModuleDef_Init(mdef);
        nameobj = PyObject_GetAttrString(spec, ptr[u8]("name"));
        if not nameobj {
            return NULL;
        }
        m = from_def_and_spec(mdef, spec, module_api_version, nameobj, interp);
        object_decref(nameobj);
        return m;
    }  def PyModule_ExecDef(module: ptr[PyObject], mdef: ptr[PyModuleDef]) -> i32 {
        name = PyModule_GetName(module);
        if not name {
            return i32(-1);
        }

        if def_fields(mdef).view(1)[0].m_size >= 0
            and not module_of(module).view(1)[0].md_state {
            if not allocate_state(module, def_fields(mdef).view(1)[0].m_size) {
                return i32(-1);
            }
        }
        cur_slot = def_fields(mdef).view(1)[0].m_slots;
        if not cur_slot {
            return i32(0);
        }
        while cur_slot and cur_slot.view(1)[0].slot != i32(0) {
            slot = cur_slot.view(1)[0].slot;
            if slot == SLOT_EXEC {
                calls = ptr[ModuleCall](
                    __thread_local_block("jac_object_model_module_call_slot", 40)
                );
                calls.view(1)[0].exec = int(cur_slot.view(1)[0].value);
                ret = calls.view(1)[0].exec(module);
                if ret != i32(0) {
                    if not PyErr_Occurred() {
                        PyErr_Format(
                            PyExc_SystemError,
                            ptr[u8](
                                "execution of module %s failed without setting an exception"
                            ),
                            name
                        );
                    }
                    return i32(-1);
                }
                if PyErr_Occurred() {
                    _PyErr_FormatFromCause(
                        PyExc_SystemError,
                        ptr[u8]("execution of module %s raised unreported exception"),
                        name
                    );
                    return i32(-1);
                }
            } elif slot != SLOT_CREATE
                and slot != SLOT_MULTIPLE_INTERPRETERS
                and slot != SLOT_GIL {
                PyErr_Format(
                    PyExc_SystemError,
                    ptr[u8]("module %s initialized with unknown slot %i"),
                    name,
                    slot
                );
                return i32(-1);
            }
            cur_slot = cur_slot + 1;
        }
        return i32(0);
    }  def PyModule_AddFunctions(m: ptr[PyObject], functions: ptr[PyMethodDef]) -> i32 {
        name = PyModule_GetNameObject(m);
        if not name {
            return i32(-1);
        }
        res = add_methods_to_object(m, name, functions);
        object_decref(name);
        return res;
    }  def PyModule_SetDocString(m: ptr[PyObject], doc: ptr[u8]) -> i32 {
        v = PyUnicode_FromStringAndSize(doc, i64(strlen(doc)));
        if not v or PyObject_SetAttrString(m, ptr[u8]("__doc__"), v) != 0 {
            object_xdecref(v);
            return i32(-1);
        }
        object_decref(v);
        return i32(0);
    }  def PyModule_GetDict(m: ptr[PyObject]) -> ptr[PyObject] {
        if not module_check(m) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return module_of(m).view(1)[0].md_dict;
    }  def PyModule_GetNameObject(mod: ptr[PyObject]) -> ptr[PyObject] {
        if not module_check(mod) {
            PyErr_BadArgument();
            return NULL;
        }
        dict = module_of(mod).view(1)[0].md_dict;
        if dict and dict_check(dict) {
            (status, name) = dict_get(dict, "__name__");
            if status > 0 {
                if unicode_check(name) {
                    return name;
                }
                object_decref(name);
            }
        }
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_SystemError, ptr[u8]("nameless module"));
        }
        return NULL;
    }  def PyModule_GetName(m: ptr[PyObject]) -> ptr[u8] {
        name = PyModule_GetNameObject(m);
        if not name {
            return ptr[u8]();
        }
        object_decref(name);
        return ptr[u8](PyUnicode_AsUTF8(name));
    }  def _PyModule_GetFilenameObject(mod: ptr[PyObject]) -> ptr[PyObject] {
        if not module_check(mod) {
            PyErr_BadArgument();
            return NULL;
        }
        dict = module_of(mod).view(1)[0].md_dict;
        if not dict {
            return object_new_ref(Py_None);
        }
        (res, fileobj) = dict_get(dict, "__file__");
        if res < 0 {
            return NULL;
        }
        if res == 0 {
            return object_new_ref(Py_None);
        }
        if not unicode_check(fileobj) {
            object_decref(fileobj);
            return object_new_ref(Py_None);
        }
        return fileobj;
    }  def PyModule_GetFilenameObject(mod: ptr[PyObject]) -> ptr[PyObject] {
        fileobj = _PyModule_GetFilenameObject(mod);
        if not fileobj {
            return NULL;
        }
        if fileobj == Py_None {
            object_decref(fileobj);
            PyErr_SetString(PyExc_SystemError, ptr[u8]("module filename missing"));
            return NULL;
        }
        return fileobj;
    }  def PyModule_GetFilename(m: ptr[PyObject]) -> ptr[u8] {
        fileobj = PyModule_GetFilenameObject(m);
        if not fileobj {
            return ptr[u8]();
        }
        utf8 = ptr[u8](PyUnicode_AsUTF8(fileobj));
        object_decref(fileobj);
        return utf8;
    }  def _PyModule_GetFilenameUTF8(
        mod: ptr[PyObject], buffer: ptr[u8], maxlen: i64
    ) -> i64 {
        size: i64 = -1;
        filenameobj = _PyModule_GetFilenameObject(mod);
        if not filenameobj {
            return -1;
        }
        if filenameobj == Py_None {
            buffer.view(1)[0] = u8(0);
            size = 0;
        } else {
            filename = PyUnicode_AsUTF8AndSize(filenameobj, &mut size);
            if size > maxlen {
                size = -1;
                PyErr_SetString(PyExc_ValueError, ptr[u8]("__file__ too long"));
            } else {
                strcpy(buffer, filename);
            }
        }
        object_decref(filenameobj);
        return size;
    }  def PyModule_GetDef(m: ptr[PyObject]) -> ptr[PyModuleDef] {
        if not module_check(m) {
            PyErr_BadArgument();
            return ptr[PyModuleDef]();
        }
        return def_of(m);
    }  def PyModule_GetState(m: ptr[PyObject]) -> ptr {
        if not module_check(m) {
            PyErr_BadArgument();
            return ptr();
        }
        return module_of(m).view(1)[0].md_state;
    }  def _PyModule_Clear(m: ptr[PyObject]) {
        d = module_of(m).view(1)[0].md_dict;
        if d {
            _PyModule_ClearDict(d);
        }
    }  def _PyModule_ClearDict(d: ptr[PyObject]) {
        verbose = config_int(PyConfig_VERBOSE);
        clear_names(d, verbose, True);
        clear_names(d, verbose, False);
    }  def _PyModuleSpec_IsInitializing(spec: ptr[PyObject]) -> i32 {
        if not spec {
            return i32(0);
        }
        (rc, value) = optional_attr(spec, "_initializing");
        if rc > 0 {
            rc = PyObject_IsTrue(value);
            object_decref(value);
        }
        return rc;
    }  def _PyModuleSpec_IsUninitializedSubmodule(
        spec: ptr[PyObject], name: ptr[PyObject]
    ) -> i32 {
        if not spec {
            return i32(0);
        }
        (rc, value) = optional_attr(spec, "_uninitialized_submodules");
        if rc > 0 {
            rc = PySequence_Contains(value, name);
            object_decref(value);
        }
        return rc;
    }  def _PyModuleSpec_GetFileOrigin(
        spec: ptr[PyObject], p_origin: ptr[ptr[PyObject]]
    ) -> i32 {
        (rc, has_location) = optional_attr(spec, "has_location");
        if rc <= 0 {
            return rc;
        }
        rc = PyObject_IsTrue(has_location);
        object_decref(has_location);
        if rc <= 0 {
            return rc;
        }
        (rc2, origin) = optional_attr(spec, "origin");
        if rc2 <= 0 {
            return rc2;
        }
        if not unicode_check(origin) {
            object_decref(origin);
            return i32(0);
        }
        p_origin.view(1)[0] = origin;
        return i32(1);
    }  def _PyModule_IsPossiblyShadowing(origin: ptr[PyObject]) -> i32 {
        if not origin {
            return i32(0);
        }
        if config_int(PyConfig_SAFE_PATH) != i32(0) {
            return i32(0);
        }
        root_path = ptr[i32](PyMem_Malloc(u64((MAXPATHLEN + 1) * 4)));
        cwd = ptr[i32](PyMem_Malloc(u64(MAXPATHLEN * 4)));
        result = i32(0);
        if not root_path or not cwd {
            PyMem_Free(ptr(root_path));
            PyMem_Free(ptr(cwd));
            PyErr_NoMemory();
            return i32(-1);
        }
        result = shadowing_root(origin, root_path, cwd);
        PyMem_Free(ptr(root_path));
        PyMem_Free(ptr(cwd));
        return result;
    }  def _Py_module_getattro_impl(
        m: ptr[PyObject], name: ptr[PyObject], suppress: i32
    ) -> ptr[PyObject] {
        attr = _PyObject_GenericGetAttrWithDict(m, name, NULL, suppress);
        if attr {
            return attr;
        }
        if suppress == i32(1) {
            if PyErr_Occurred() {
                return NULL;
            }
        } else {
            if PyErr_ExceptionMatches(PyExc_AttributeError) == 0 {
                return NULL;
            }
            PyErr_Clear();
        }
        md_dict = module_of(m).view(1)[0].md_dict;
        (status, getattr) = dict_get(md_dict, "__getattr__");
        if status < 0 {
            return NULL;
        }
        if getattr {
            result = PyObject_CallOneArg(getattr, name);
            if not result
                and suppress == i32(1)
                and PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
                PyErr_Clear();
            }
            object_decref(getattr);
            return result;
        }

        if suppress == i32(1) {
            return NULL;
        }
        missing_attribute_error(md_dict, name);
        return NULL;
    }  def _Py_module_getattro(
        op: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _Py_module_getattro_impl(op, name, i32(0));
    }
}

def from_def_and_spec(
    mdef: ptr[PyModuleDef],
    spec: ptr[PyObject],
    module_api_version: i32,
    nameobj: ptr[PyObject],
    interp: ptr
) -> ptr[PyObject];

def clear_names(d: ptr[PyObject], verbose: i32, underscored: bool);

def shadowing_root(origin: ptr[PyObject], root_path: ptr[i32], cwd: ptr[i32]) -> i32;

def wide_equals_ascii(p: ptr[i32], text: str) -> bool;

def spec_file_origin(spec: ptr[PyObject]) -> tuple[i32, ptr[PyObject]];

def missing_attribute_error(md_dict: ptr[PyObject], name: ptr[PyObject]);

def explain_missing(
    mod_name: ptr[PyObject],
    name: ptr[PyObject],
    spec: ptr[PyObject],
    origin: ptr[PyObject]
);

def module___init__(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

glob:priv module_init_signature = CallSignature(
         "module", ["name", "doc"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def module_init_bound(args: BoundArguments) -> ptr[PyObject];

def module_init_checked(
    op: ptr[PyObject], name: ptr[PyObject], doc: ptr[PyObject]
) -> i32;

def module_dealloc(op: ptr[PyObject]);

def module_repr(op: ptr[PyObject]) -> ptr[PyObject];

def module_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def module_clear(op: ptr[PyObject]) -> i32;

def module_dir(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def module_get_dict(op: ptr[PyObject]) -> ptr[PyObject];

def module_get_annotate(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def module_set_annotate(op: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32;

def dict_pop(dict: ptr[PyObject], name: str) -> i32;

def module_get_annotations(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def module_set_annotations(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

impl module_of(op: ptr[PyObject]) -> ptr[PyModuleObject] {
    return ptr[PyModuleObject](op);
}

impl module_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(PyModule_Type));
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl config_int(offset: i64) -> i32 {
    return ptr[i32](_Py_GetConfig() + offset).view(1)[0];
}

impl dict_get(dict: ptr[PyObject], name: str) -> tuple[i32, ptr[PyObject]] {
    value: ptr[PyObject] = NULL;
    key = jacpy_unicode_intern_text(name);
    if not key {
        return (i32(-1), value);
    }
    status = PyDict_GetItemRef(dict, key, &mut value);
    object_decref(key);
    return (status, value);
}

impl optional_attr(op: ptr[PyObject], name: str) -> tuple[i32, ptr[PyObject]] {
    value: ptr[PyObject] = NULL;
    status = jacpy_object_getoptionalattr_text(op, name, &mut value);
    return (status, value);
}

impl module_init_dict(
    m: ptr[PyObject], md_dict: ptr[PyObject], name: ptr[PyObject], doc_in: ptr[PyObject]
) -> i32 {
    doc = doc_in or Py_None;
    if PyDict_SetItemString(md_dict, ptr[u8]("__name__"), name) != 0
        or PyDict_SetItemString(md_dict, ptr[u8]("__doc__"), doc) != 0
        or PyDict_SetItemString(md_dict, ptr[u8]("__package__"), Py_None) != 0
        or PyDict_SetItemString(md_dict, ptr[u8]("__loader__"), Py_None) != 0
        or PyDict_SetItemString(md_dict, ptr[u8]("__spec__"), Py_None) != 0 {
        return i32(-1);
    }
    if object_is_type(name, ptr[PyTypeObject](addressof(PyUnicode_Type))) {
        old = module_of(m).view(1)[0].md_name;
        module_of(m).view(1)[0].md_name = object_new_ref(name);
        object_xdecref(old);
    }
    return i32(0);
}

impl new_module_notrack(mt: ptr[PyTypeObject]) -> ptr[PyObject] {
    m = _PyType_AllocNoTrack(mt, 0);
    if not m {
        return NULL;
    }
    md = module_of(m);
    md.view(1)[0].md_def = ptr[ModuleDef]();
    md.view(1)[0].md_state = ptr();
    md.view(1)[0].md_weaklist = NULL;
    md.view(1)[0].md_name = NULL;
    md.view(1)[0].md_dict = PyDict_New();
    if not md.view(1)[0].md_dict {
        object_decref(m);
        return NULL;
    }
    return m;
}

impl new_module(
    mt: ptr[PyTypeObject], args: ptr[PyObject], kws: ptr[PyObject]
) -> ptr[PyObject] {
    m = new_module_notrack(mt);
    if m {
        object_gc_track(m);
    }
    return m;
}

impl check_api_version(name: ptr[u8], module_api_version: i32) -> bool {
    if module_api_version != PYTHON_API_VERSION
        and module_api_version != PYTHON_ABI_VERSION {
        if PyErr_WarnFormat(
            PyExc_RuntimeWarning,
            1,
            ptr[u8](
                "Python C API version mismatch for module %.100s: This Python has API version %d, module %.100s has version %d."
            ),
            name,
            PYTHON_API_VERSION,
            name,
            module_api_version
        )
            != 0 {
            return False;
        }
    }
    return True;
}

impl add_methods_to_object(
    module: ptr[PyObject], name: ptr[PyObject], functions: ptr[PyMethodDef]
) -> i32 {
    fdef = functions;
    while fdef.view(1)[0].ml_name {
        flags = fdef.view(1)[0].ml_flags;
        if (flags & METH_CLASS) != i32(0) or (flags & METH_STATIC) != i32(0) {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("module functions cannot set METH_CLASS or METH_STATIC")
            );
            return i32(-1);
        }
        func = PyCFunction_NewEx(fdef, module, name);
        if not func {
            return i32(-1);
        }
        if PyObject_SetAttrString(module, fdef.view(1)[0].ml_name, func) != 0 {
            object_decref(func);
            return i32(-1);
        }
        object_decref(func);
        fdef = fdef + 1;
    }
    return i32(0);
}

impl def_fields(mdef: ptr[PyModuleDef]) -> ptr[ModuleDef] {
    return ptr[ModuleDef](mdef);
}

impl def_of(op: ptr[PyObject]) -> ptr[PyModuleDef] {
    return ptr[PyModuleDef](module_of(op).view(1)[0].md_def);
}

impl hooks_ready(op: ptr[PyObject]) -> bool {
    mdef = def_of(op);
    return def_fields(mdef).view(1)[0].m_size <= 0
        or bool(module_of(op).view(1)[0].md_state);
}

impl allocate_state(op: ptr[PyObject], size: i64) -> bool {
    state = PyMem_Malloc(u64(size));
    if not state {
        PyErr_NoMemory();
        return False;
    }
    jacpy_memory_zero(state, size);
    module_of(op).view(1)[0].md_state = state;
    return True;
}

impl from_def_and_spec(
    mdef: ptr[PyModuleDef],
    spec: ptr[PyObject],
    module_api_version: i32,
    nameobj: ptr[PyObject],
    interp: ptr
) -> ptr[PyObject] {
    name = ptr[u8](PyUnicode_AsUTF8(nameobj));
    if not name or not check_api_version(name, module_api_version) {
        return NULL;
    }
    if def_fields(mdef).view(1)[0].m_size < 0 {
        PyErr_Format(
            PyExc_SystemError,
            ptr[u8](
                "module %s: m_size may not be negative for multi-phase initialization"
            ),
            name
        );
        return NULL;
    }
    create = ptr();
    has_multiple_interpreters_slot = False;
    multiple_interpreters = MULTIPLE_INTERPRETERS_NOT_SUPPORTED;
    has_gil_slot = False;
    has_execution_slots = False;
    cur_slot = def_fields(mdef).view(1)[0].m_slots;
    while cur_slot and cur_slot.view(1)[0].slot != i32(0) {
        slot = cur_slot.view(1)[0].slot;
        if slot == SLOT_CREATE {
            if create {
                PyErr_Format(
                    PyExc_SystemError,
                    ptr[u8]("module %s has multiple create slots"),
                    name
                );
                return NULL;
            }
            create = cur_slot.view(1)[0].value;
        } elif slot == SLOT_EXEC {
            has_execution_slots = True;
        } elif slot == SLOT_MULTIPLE_INTERPRETERS {
            if has_multiple_interpreters_slot {
                PyErr_Format(
                    PyExc_SystemError,
                    ptr[u8](
                        "module %s has more than one 'multiple interpreters' slots"
                    ),
                    name
                );
                return NULL;
            }
            multiple_interpreters = int(cur_slot.view(1)[0].value);
            has_multiple_interpreters_slot = True;
        } elif slot == SLOT_GIL {
            if has_gil_slot {
                PyErr_Format(
                    PyExc_SystemError,
                    ptr[u8]("module %s has more than one 'gil' slot"),
                    name
                );
                return NULL;
            }
            has_gil_slot = True;
        } else {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("module %s uses unknown slot ID %i"),
                name,
                slot
            );
            return NULL;
        }
        cur_slot = cur_slot + 1;
    }

    if not has_multiple_interpreters_slot {
        multiple_interpreters = MULTIPLE_INTERPRETERS_SUPPORTED;
    }

    is_main = ptr(interp) == ptr(PyInterpreterState_Main());
    if multiple_interpreters == MULTIPLE_INTERPRETERS_NOT_SUPPORTED {
        if not is_main
            and _PyImport_CheckSubinterpIncompatibleExtensionAllowed(name) < 0 {
            return NULL;
        }
    } elif multiple_interpreters != PER_INTERPRETER_GIL_SUPPORTED
        and ptr[i32](ptr[u8](interp) + PyInterpreterState_CEVAL_OWN_GIL).view(1)[0]
            != i32(0)
        and not is_main
        and _PyImport_CheckSubinterpIncompatibleExtensionAllowed(name) < 0 {
        return NULL;
    }
    m = NULL;
    if create {
        calls = ptr[ModuleCall](
            __thread_local_block("jac_object_model_module_call_slot", 40)
        );
        calls.view(1)[0].create = int(create);
        m = calls.view(1)[0].create(spec, mdef);
        if not m {
            if not PyErr_Occurred() {
                PyErr_Format(
                    PyExc_SystemError,
                    ptr[u8](
                        "creation of module %s failed without setting an exception"
                    ),
                    name
                );
            }
            return NULL;
        }
        if PyErr_Occurred() {
            _PyErr_FormatFromCause(
                PyExc_SystemError,
                ptr[u8]("creation of module %s raised unreported exception"),
                name
            );
            object_decref(m);
            return NULL;
        }
    } else {
        m = PyModule_NewObject(nameobj);
        if not m {
            return NULL;
        }
    }
    if module_check(m) {
        module_of(m).view(1)[0].md_state = ptr();
        module_of(m).view(1)[0].md_def = ptr[ModuleDef](mdef);
    } else {
        if def_fields(mdef).view(1)[0].m_size > 0
            or int(def_fields(mdef).view(1)[0].m_traverse) != 0
            or int(def_fields(mdef).view(1)[0].m_clear) != 0
            or int(def_fields(mdef).view(1)[0].m_free) != 0 {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("module %s is not a module object, but requests module state"),
                name
            );
            object_decref(m);
            return NULL;
        }
        if has_execution_slots {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8](
                    "module %s specifies execution slots, but did not create a ModuleType instance"
                ),
                name
            );
            object_decref(m);
            return NULL;
        }
    }
    if def_fields(mdef).view(1)[0].m_methods
        and add_methods_to_object(m, nameobj, def_fields(mdef).view(1)[0].m_methods)
            != 0 {
        object_decref(m);
        return NULL;
    }
    if def_fields(mdef).view(1)[0].m_doc
        and PyModule_SetDocString(m, def_fields(mdef).view(1)[0].m_doc) != 0 {
        object_decref(m);
        return NULL;
    }
    return m;
}

impl clear_names(d: ptr[PyObject], verbose: i32, underscored: bool) {
    pos: i64 = 0;
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    while PyDict_Next(d, &mut pos, &mut key, &mut value) != 0 {
        if value == Py_None or not unicode_check(key) {
            continue;
        }
        first = PyUnicode_ReadChar(key, 0);
        clear = False;
        if underscored {
            clear = i64(first) == UNDERSCORE
                and i64(PyUnicode_ReadChar(key, 1)) != UNDERSCORE;
        } else {
            clear = i64(first) != UNDERSCORE
                or _PyUnicode_EqualToASCIIString(key, ptr[u8]("__builtins__")) == 0;
        }
        if not clear {
            continue;
        }
        if verbose > i32(1) {
            s = PyUnicode_AsUTF8(key);
            if s {
                PySys_WriteStderr(
                    ptr[u8]("#   clear[1] %s\n")
                        if underscored
                        else ptr[u8]("#   clear[2] %s\n"),
                    s
                );
            } else {
                PyErr_Clear();
            }
        }
        if PyDict_SetItem(d, key, Py_None) != 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing module dict")
            );
        }
    }
}

impl shadowing_root(origin: ptr[PyObject], root_path: ptr[i32], cwd: ptr[i32]) -> i32 {
    size = PyUnicode_AsWideChar(origin, ptr(root_path), MAXPATHLEN);
    if size < 0 {
        return i32(-1);
    }
    (root_path + size).view(1)[0] = i32(0);
    sep = wcsrchr(root_path, SEP);
    if not sep {
        return i32(0);
    }

    if wide_equals_ascii(sep + 1, "__init__.py") {
        sep.view(1)[0] = i32(0);
        sep = wcsrchr(root_path, SEP);
        if not sep {
            return i32(0);
        }
    }
    sep.view(1)[0] = i32(0);

    sys_path_0 = ptr[ptr[i32]](_Py_GetConfig() + PyConfig_SYS_PATH_0).view(1)[0];
    if not sys_path_0 {
        return i32(0);
    }
    if sys_path_0.view(1)[0] == i32(0) {
        if not _Py_wgetcwd(cwd, u64(MAXPATHLEN)) {
            return i32(0);
        }
        sys_path_0 = cwd;
    }
    return i32(1) if wcscmp(sys_path_0, root_path) == 0 else i32(0);
}

impl wide_equals_ascii(p: ptr[i32], text: str) -> bool {
    expected = jacpy_unicode_from_text(text);
    if not expected {
        PyErr_Clear();
        return False;
    }
    actual = PyUnicode_FromWideChar(p, -1);
    if not actual {
        PyErr_Clear();
        object_decref(expected);
        return False;
    }
    same = PyUnicode_Compare(expected, actual) == 0;
    object_decref(expected);
    object_decref(actual);
    return same;
}

impl spec_file_origin(spec: ptr[PyObject]) -> tuple[i32, ptr[PyObject]] {
    slot = ptr[ptr[PyObject]](PyMem_Calloc(1, 8));
    if not slot {
        PyErr_NoMemory();
        return (i32(-1), NULL);
    }
    status = _PyModuleSpec_GetFileOrigin(spec, slot);
    origin = slot.view(1)[0] if status > 0 else NULL;
    PyMem_Free(ptr(slot));
    return (status, origin);
}

impl missing_attribute_error(md_dict: ptr[PyObject], name: ptr[PyObject]) {
    (status, mod_name) = dict_get(md_dict, "__name__");
    if status < 0 {
        return;
    }
    if not mod_name or not unicode_check(mod_name) {
        object_xdecref(mod_name);
        PyErr_Format(
            PyExc_AttributeError, ptr[u8]("module has no attribute '%U'"), name
        );
        return;
    }
    (status2, spec) = dict_get(md_dict, "__spec__");
    if status2 < 0 {
        object_decref(mod_name);
        return;
    }
    if not spec {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8]("module '%U' has no attribute '%U'"),
            mod_name,
            name
        );
        object_decref(mod_name);
        return;
    }
    (status3, origin) = spec_file_origin(spec);
    if status3 >= 0 {
        explain_missing(mod_name, name, spec, origin);
    }
    object_xdecref(origin);
    object_decref(spec);
    object_decref(mod_name);
}

impl explain_missing(
    mod_name: ptr[PyObject],
    name: ptr[PyObject],
    spec: ptr[PyObject],
    origin: ptr[PyObject]
) {
    is_possibly_shadowing = _PyModule_IsPossiblyShadowing(origin);
    if is_possibly_shadowing < 0 {
        return;
    }
    is_possibly_shadowing_stdlib = i32(0);
    if is_possibly_shadowing != 0 {
        stdlib_modules: ptr[PyObject] = NULL;
        if _PySys_GetOptionalAttrString(
            ptr[u8]("stdlib_module_names"), &mut stdlib_modules
        )
            < 0 {
            return;
        }
        if stdlib_modules and PySet_Size(stdlib_modules) >= 0 {
            is_possibly_shadowing_stdlib = PySet_Contains(stdlib_modules, mod_name);
            if is_possibly_shadowing_stdlib < 0 {
                object_decref(stdlib_modules);
                return;
            }
        } else {
            PyErr_Clear();
        }
        object_xdecref(stdlib_modules);
    }
    if is_possibly_shadowing_stdlib != 0 {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8](
                "module '%U' has no attribute '%U' (consider renaming '%U' since it has the same name as the standard library module named '%U' and prevents importing that standard library module)"
            ),
            mod_name,
            name,
            origin,
            mod_name
        );
        return;
    }
    rc = _PyModuleSpec_IsInitializing(spec);
    if rc < 0 {
        return;
    }
    if rc > 0 {
        if is_possibly_shadowing != 0 {
            PyErr_Format(
                PyExc_AttributeError,
                ptr[u8](
                    "module '%U' has no attribute '%U' (consider renaming '%U' if it has the same name as a library you intended to import)"
                ),
                mod_name,
                name,
                origin
            );
        } elif origin {
            PyErr_Format(
                PyExc_AttributeError,
                ptr[u8](
                    "partially initialized module '%U' from '%U' has no attribute '%U' (most likely due to a circular import)"
                ),
                mod_name,
                origin,
                name
            );
        } else {
            PyErr_Format(
                PyExc_AttributeError,
                ptr[u8](
                    "partially initialized module '%U' has no attribute '%U' (most likely due to a circular import)"
                ),
                mod_name,
                name
            );
        }
        return;
    }
    rc = _PyModuleSpec_IsUninitializedSubmodule(spec, name);
    if rc > 0 {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8](
                "cannot access submodule '%U' of module '%U' (most likely due to a circular import)"
            ),
            name,
            mod_name
        );
    } elif rc == 0 {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8]("module '%U' has no attribute '%U'"),
            mod_name,
            name
        );
    }
}

impl module___init__(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    if not kwargs and object_size(args) >= 1 and object_size(args) <= 2 {
        name = tuple_get_item(args, 0);
        doc = tuple_get_item(args, 1) if object_size(args) == 2 else Py_None;
        return module_init_checked(op, name, doc);
    }
    result = invoke(module_init_signature, args, kwargs, module_init_bound, op);
    if not result {
        return i32(-1);
    }
    object_decref(result);
    return i32(0);
}

impl module_init_bound(args: BoundArguments) -> ptr[PyObject] {
    doc = args.values[1] if args.values[1] else Py_None;
    if module_init_checked(args.context, args.values[0], doc) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl module_init_checked(
    op: ptr[PyObject], name: ptr[PyObject], doc: ptr[PyObject]
) -> i32 {
    if not unicode_check(name) {
        _PyArg_BadArgument(
            ptr[u8]("module"), ptr[u8]("argument 'name'"), ptr[u8]("str"), name
        );
        return i32(-1);
    }
    return module_init_dict(op, module_of(op).view(1)[0].md_dict, name, doc);
}

impl module_dealloc(op: ptr[PyObject]) {
    md = module_of(op);
    object_gc_untrack(op);
    if config_int(PyConfig_VERBOSE) != i32(0) and md.view(1)[0].md_name {
        PySys_FormatStderr(ptr[u8]("# destroy %U\n"), md.view(1)[0].md_name);
    }
    if md.view(1)[0].md_weaklist {
        PyObject_ClearWeakRefs(op);
    }
    mdef = ptr[PyModuleDef](md.view(1)[0].md_def);

    if mdef and int(def_fields(mdef).view(1)[0].m_free) != 0 and hooks_ready(op) {
        calls = ptr[ModuleCall](
            __thread_local_block("jac_object_model_module_call_slot", 40)
        );
        calls.view(1)[0].free = int(def_fields(mdef).view(1)[0].m_free);
        calls.view(1)[0].free(ptr(op));
    }
    object_xdecref(md.view(1)[0].md_dict);
    object_xdecref(md.view(1)[0].md_name);
    if md.view(1)[0].md_state {
        PyMem_Free(md.view(1)[0].md_state);
    }
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl module_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return _PyImport_ImportlibModuleRepr(ptr(current_interp()), op);
}

impl module_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    mdef = def_of(op);

    if mdef and int(def_fields(mdef).view(1)[0].m_traverse) != 0 and hooks_ready(op) {
        calls = ptr[ModuleCall](
            __thread_local_block("jac_object_model_module_call_slot", 40)
        );
        calls.view(1)[0].traverse = int(def_fields(mdef).view(1)[0].m_traverse);
        res = calls.view(1)[0].traverse(op, visitor, arg);
        if res != 0 {
            return res;
        }
    }
    return visit_reference(module_of(op).view(1)[0].md_dict, visitor, arg);
}

impl module_clear(op: ptr[PyObject]) -> i32 {
    md = module_of(op);
    mdef = ptr[PyModuleDef](md.view(1)[0].md_def);
    if mdef and int(def_fields(mdef).view(1)[0].m_clear) != 0 and hooks_ready(op) {
        calls = ptr[ModuleCall](
            __thread_local_block("jac_object_model_module_call_slot", 40)
        );
        calls.view(1)[0].clear = int(def_fields(mdef).view(1)[0].m_clear);
        res = calls.view(1)[0].clear(op);
        if PyErr_Occurred() {
            md_name = md.view(1)[0].md_name;
            if md_name {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored in m_clear of module %U"), md_name
                );
            } else {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored in m_clear of module")
                );
            }
        }
        if res != 0 {
            return res;
        }
    }
    old = md.view(1)[0].md_dict;
    md.view(1)[0].md_dict = NULL;
    object_xdecref(old);
    return i32(0);
}

impl module_dir(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    result = NULL;
    dict = PyObject_GetAttrString(op, ptr[u8]("__dict__"));
    if dict {
        if dict_check(dict) {
            key = PyUnicode_InternFromString(ptr[u8]("__dir__"));
            dirfunc = PyDict_GetItemWithError(dict, key) if key else NULL;
            object_xdecref(key);
            if dirfunc {
                result = PyObject_CallNoArgs(dirfunc);
            } elif not PyErr_Occurred() {
                result = PyDict_Keys(dict);
            }
        } else {
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("<module>.__dict__ is not a dictionary")
            );
        }
    }
    object_xdecref(dict);
    return result;
}

impl module_get_dict(op: ptr[PyObject]) -> ptr[PyObject] {
    dict = PyObject_GetAttrString(op, ptr[u8]("__dict__"));
    if not dict {
        return NULL;
    }
    if not dict_check(dict) {
        PyErr_Format(PyExc_TypeError, ptr[u8]("<module>.__dict__ is not a dictionary"));
        object_decref(dict);
        return NULL;
    }
    return dict;
}

impl module_get_annotate(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    dict = module_get_dict(op);
    if not dict {
        return NULL;
    }
    (status, annotate) = dict_get(dict, "__annotate__");
    if status == 0 {
        annotate = object_new_ref(Py_None);
        if PyDict_SetItemString(dict, ptr[u8]("__annotate__"), annotate) == -1 {
            object_decref(annotate);
            annotate = NULL;
        }
    }
    object_decref(dict);
    return annotate;
}

impl module_set_annotate(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    if not value {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("cannot delete __annotate__ attribute")
        );
        return i32(-1);
    }
    dict = module_get_dict(op);
    if not dict {
        return i32(-1);
    }
    if value != Py_None and PyCallable_Check(value) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("__annotate__ must be callable or None")
        );
        object_decref(dict);
        return i32(-1);
    }
    if PyDict_SetItemString(dict, ptr[u8]("__annotate__"), value) == -1 {
        object_decref(dict);
        return i32(-1);
    }
    if value != Py_None and dict_pop(dict, "__annotations__") == -1 {
        object_decref(dict);
        return i32(-1);
    }
    object_decref(dict);
    return i32(0);
}

impl dict_pop(dict: ptr[PyObject], name: str) -> i32 {
    key = jacpy_unicode_intern_text(name);
    if not key {
        return i32(-1);
    }
    result = PyDict_Pop(dict, key, None);
    object_decref(key);
    return result;
}

impl module_get_annotations(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    dict = module_get_dict(op);
    if not dict {
        return NULL;
    }
    (found, annotations) = dict_get(dict, "__annotations__");
    if found == 0 {
        (status, spec) = dict_get(module_of(op).view(1)[0].md_dict, "__spec__");
        if status < 0 {
            object_decref(dict);
            return NULL;
        }
        is_initializing = False;
        if spec {
            rc = _PyModuleSpec_IsInitializing(spec);
            object_decref(spec);
            if rc < 0 {
                object_decref(dict);
                return NULL;
            }
            is_initializing = rc != 0;
        }
        (annotate_result, annotate) = dict_get(dict, "__annotate__");
        if annotate_result < 0 {
            object_decref(dict);
            return NULL;
        }
        if annotate_result == 1 and PyCallable_Check(annotate) != 0 {
            one = PyLong_FromLong(1);
            annotations = PyObject_CallOneArg(annotate, one);
            object_decref(one);
            if not annotations {
                object_decref(annotate);
                object_decref(dict);
                return NULL;
            }
            if not dict_check(annotations) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("__annotate__ returned non-dict of type '%.100s'"),
                    object_type(annotations).view(1)[0].tp_name
                );
                object_decref(annotate);
                object_decref(annotations);
                object_decref(dict);
                return NULL;
            }
        } else {
            annotations = PyDict_New();
        }
        object_xdecref(annotate);

        if annotations and not is_initializing {
            if PyDict_SetItemString(dict, ptr[u8]("__annotations__"), annotations)
                != 0 {
                object_decref(annotations);
                annotations = NULL;
            }
        }
    }
    object_decref(dict);
    return annotations;
}

impl module_set_annotations(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    dict = module_get_dict(op);
    if not dict {
        return i32(-1);
    }
    ret = i32(-1);
    if value {
        ret = PyDict_SetItemString(dict, ptr[u8]("__annotations__"), value);
    } else {
        ret = dict_pop(dict, "__annotations__");
        if ret == 0 {
            PyErr_SetString(PyExc_AttributeError, ptr[u8]("__annotations__"));
            ret = i32(-1);
        } elif ret > 0 {
            ret = i32(0);
        }
    }
    if ret == 0 and dict_pop(dict, "__annotate__") < 0 {
        ret = i32(-1);
    }
    object_decref(dict);
    return ret;
}
