import from c {
    def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def strncpy(
        target: ptr[u8], source: ptr[u8], size: u64
    ) -> ptr[u8];  def jacpy_stack_address(slots: &mut InterpconfigStack) -> int;  obj InterpconfigStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0;
    }  def _PyInterpreterConfig_AsDict(
        config: ptr[PyInterpreterConfig]
    ) -> ptr[PyObject] {
        dict_ = PyDict_New();
        if not dict_ {
            return NULL;
        }
        c = config.view(1);
        if add_bool(dict_, ptr[u8]("use_main_obmalloc"), c[0].use_main_obmalloc) < 0
            or add_bool(dict_, ptr[u8]("allow_fork"), c[0].allow_fork) < 0
            or add_bool(dict_, ptr[u8]("allow_exec"), c[0].allow_exec) < 0
            or add_bool(dict_, ptr[u8]("allow_threads"), c[0].allow_threads) < 0
            or add_bool(
                dict_, ptr[u8]("allow_daemon_threads"), c[0].allow_daemon_threads
            )
                < 0
            or add_bool(
                dict_,
                ptr[u8]("check_multi_interp_extensions"),
                c[0].check_multi_interp_extensions
            )
                < 0 {
            object_decref(dict_);
            return NULL;
        }

        gil = gil_flag_to_str(c[0].gil);
        if not gil {
            object_decref(dict_);
            return NULL;
        }
        obj_ = PyUnicode_FromString(gil);
        if not obj_ {
            object_decref(dict_);
            return NULL;
        }
        res = PyDict_SetItemString(dict_, ptr[u8]("gil"), obj_);
        object_decref(obj_);
        if res < 0 {
            object_decref(dict_);
            return NULL;
        }
        return dict_;
    }  def _PyInterpreterConfig_InitFromDict(
        config: ptr[PyInterpreterConfig], dict_: ptr[PyObject]
    ) -> i32 {
        if not dict_check(dict_) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("dict expected"));
            return -1;
        }
        if interp_config_from_dict(dict_, config, False) < 0 {
            return -1;
        }
        return 0;
    }  def _PyInterpreterConfig_UpdateFromDict(
        config: ptr[PyInterpreterConfig], dict_: ptr[PyObject]
    ) -> i32 {
        if not dict_check(dict_) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("dict expected"));
            return -1;
        }
        if interp_config_from_dict(dict_, config, True) < 0 {
            return -1;
        }
        return 0;
    }  def _PyInterpreterConfig_InitFromState(
        config: ptr[PyInterpreterConfig], interp: ptr[u8]
    ) -> i32 {
        flags = ptr[u64](interp + PyInterpreterState_FEATURE_FLAGS).view(1)[0];
        c = config.view(1);
        c[0].use_main_obmalloc = feature_flag(flags, Py_RTFLAGS_USE_MAIN_OBMALLOC);
        c[0].allow_fork = feature_flag(flags, Py_RTFLAGS_FORK);
        c[0].allow_exec = feature_flag(flags, Py_RTFLAGS_EXEC);
        c[0].allow_threads = feature_flag(flags, Py_RTFLAGS_THREADS);
        c[0].allow_daemon_threads = feature_flag(flags, Py_RTFLAGS_DAEMON_THREADS);
        c[0].check_multi_interp_extensions = feature_flag(
            flags, Py_RTFLAGS_MULTI_INTERP_EXTENSIONS
        );
        if ptr[i32](interp + PyInterpreterState_CEVAL_OWN_GIL).view(1)[0] != 0 {
            c[0].gil = PyInterpreterConfig_OWN_GIL;
        } else {
            c[0].gil = PyInterpreterConfig_SHARED_GIL;
        }
        return 0;
    }
}

def feature_flag(flags: u64, flag: u64) -> i32;

def gil_flag_to_str(flag: i32) -> ptr[u8];

def gil_flag_from_str(text: ptr[u8]) -> tuple[i32, i32];

def add_bool(dict_: ptr[PyObject], name: ptr[u8], value: i32) -> i32;

def config_dict_lookup(dict_: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject];

def config_dict_invalid_type(name: ptr[u8]);

def config_dict_missing(dict_: ptr[PyObject], name: ptr[u8]);

def config_dict_get_bool(dict_: ptr[PyObject], name: ptr[u8]) -> tuple[i32, i32];

def config_dict_check(
    dict_: ptr[PyObject], name: ptr[u8], missing_allowed: bool
) -> i32;

def copy_bool(
    dict_: ptr[PyObject], name: ptr[u8], missing_allowed: bool
) -> tuple[i32, i32, bool];

def interp_config_from_dict(
    origdict: ptr[PyObject], config: ptr[PyInterpreterConfig], missing_allowed: bool
) -> i32;

impl feature_flag(flags: u64, flag: u64) -> i32 {
    return i32.wrap(flags & flag);
}

impl gil_flag_to_str(flag: i32) -> ptr[u8] {
    if flag == PyInterpreterConfig_DEFAULT_GIL {
        return ptr[u8]("default");
    }
    if flag == PyInterpreterConfig_SHARED_GIL {
        return ptr[u8]("shared");
    }
    if flag == PyInterpreterConfig_OWN_GIL {
        return ptr[u8]("own");
    }
    PyErr_SetString(
        PyExc_SystemError, ptr[u8]("invalid interpreter config 'gil' value")
    );
    return ptr[u8]();
}

impl gil_flag_from_str(text: ptr[u8]) -> tuple[i32, i32] {
    if not text {
        return (i32(0), PyInterpreterConfig_DEFAULT_GIL);
    }
    if strcmp(text, ptr[u8]("default")) == 0 {
        return (i32(0), PyInterpreterConfig_DEFAULT_GIL);
    }
    if strcmp(text, ptr[u8]("shared")) == 0 {
        return (i32(0), PyInterpreterConfig_SHARED_GIL);
    }
    if strcmp(text, ptr[u8]("own")) == 0 {
        return (i32(0), PyInterpreterConfig_OWN_GIL);
    }
    PyErr_Format(
        PyExc_ValueError,
        ptr[u8]("unsupported interpreter config .gil value '%s'"),
        text
    );
    return (i32(-1), i32(0));
}

impl add_bool(dict_: ptr[PyObject], name: ptr[u8], value: i32) -> i32 {
    obj_ = object_new_ref(py_true() if value != 0 else py_false());
    res = PyDict_SetItemString(dict_, name, obj_);
    object_decref(obj_);
    return res;
}

impl config_dict_lookup(dict_: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject] {
    item = NULL;
    if PyDict_GetItemStringRef(dict_, name, &mut item) < 0 {
        return NULL;
    }
    return item;
}

impl config_dict_invalid_type(name: ptr[u8]) {
    PyErr_Format(PyExc_TypeError, ptr[u8]("invalid config type: %s"), name);
}

impl config_dict_missing(dict_: ptr[PyObject], name: ptr[u8]) {
    item = NULL;
    if PyDict_GetItemStringRef(dict_, name, &mut item) < 0 or not item {
        if not PyErr_Occurred() {
            PyErr_Format(PyExc_ValueError, ptr[u8]("missing config key: %s"), name);
        }
        return;
    }
    object_decref(item);
}

impl config_dict_get_bool(dict_: ptr[PyObject], name: ptr[u8]) -> tuple[i32, i32] {
    item = config_dict_lookup(dict_, name);
    if not item {
        return (i32(-1), i32(0));
    }
    flag = item == py_true();
    if not flag and item != py_false() {
        object_decref(item);
        config_dict_invalid_type(name);
        return (i32(-1), i32(0));
    }
    object_decref(item);
    return (i32(0), i32(1 if flag else 0));
}

impl config_dict_check(
    dict_: ptr[PyObject], name: ptr[u8], missing_allowed: bool
) -> i32 {
    if PyErr_Occurred() {
        return -1;
    }
    if not missing_allowed {
        config_dict_missing(dict_, name);
        return -1;
    }
    return 0;
}

impl copy_bool(
    dict_: ptr[PyObject], name: ptr[u8], missing_allowed: bool
) -> tuple[i32, i32, bool] {
    (res, flag) = config_dict_get_bool(dict_, name);
    if res < 0 {
        return (config_dict_check(dict_, name, missing_allowed), i32(0), False);
    }
    popped = NULL;
    PyDict_PopString(dict_, name, &mut popped);
    object_xdecref(popped);
    return (i32(0), flag, True);
}

impl interp_config_from_dict(
    origdict: ptr[PyObject], config: ptr[PyInterpreterConfig], missing_allowed: bool
) -> i32 {
    dict_ = PyDict_New();
    if not dict_ {
        return -1;
    }
    if PyDict_Update(dict_, origdict) < 0 {
        object_decref(dict_);
        return -1;
    }

    c = config.view(1);
    (res, flag, found) = copy_bool(
        dict_, ptr[u8]("use_main_obmalloc"), missing_allowed
    );
    if res < 0 {
        object_decref(dict_);
        return -1;
    }
    if found {
        c[0].use_main_obmalloc = flag;
    }
    (res, flag, found) = copy_bool(dict_, ptr[u8]("allow_fork"), missing_allowed);
    if res < 0 {
        object_decref(dict_);
        return -1;
    }
    if found {
        c[0].allow_fork = flag;
    }
    (res, flag, found) = copy_bool(dict_, ptr[u8]("allow_exec"), missing_allowed);
    if res < 0 {
        object_decref(dict_);
        return -1;
    }
    if found {
        c[0].allow_exec = flag;
    }
    (res, flag, found) = copy_bool(dict_, ptr[u8]("allow_threads"), missing_allowed);
    if res < 0 {
        object_decref(dict_);
        return -1;
    }
    if found {
        c[0].allow_threads = flag;
    }
    (res, flag, found) = copy_bool(
        dict_, ptr[u8]("allow_daemon_threads"), missing_allowed
    );
    if res < 0 {
        object_decref(dict_);
        return -1;
    }
    if found {
        c[0].allow_daemon_threads = flag;
    }
    (res, flag, found) = copy_bool(
        dict_, ptr[u8]("check_multi_interp_extensions"), missing_allowed
    );
    if res < 0 {
        object_decref(dict_);
        return -1;
    }
    if found {
        c[0].check_multi_interp_extensions = flag;
    }

    item = config_dict_lookup(dict_, ptr[u8]("gil"));
    if not item {
        if config_dict_check(dict_, ptr[u8]("gil"), missing_allowed) < 0 {
            object_decref(dict_);
            return -1;
        }
    } elif not unicode_check(item) {
        object_decref(item);
        config_dict_invalid_type(ptr[u8]("gil"));
        if config_dict_check(dict_, ptr[u8]("gil"), missing_allowed) < 0 {
            object_decref(dict_);
            return -1;
        }
    } else {
        slots: own InterpconfigStack = InterpconfigStack();
        buf = ptr[u8](jacpy_stack_address(&mut slots));
        strncpy(buf, PyUnicode_AsUTF8(item), u64(19));
        (buf + 19).view(1)[0] = u8(0);
        object_decref(item);
        (gres, gil) = gil_flag_from_str(buf);
        if gres < 0 {
            object_decref(dict_);
            return -1;
        }
        c[0].gil = gil;
        popped = NULL;
        PyDict_PopString(dict_, ptr[u8]("gil"), &mut popped);
        object_xdecref(popped);
    }

    unused = dict_used(dict_);
    if unused == 1 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("config dict has 1 extra item (%R)"), dict_
        );
        object_decref(dict_);
        return -1;
    } elif unused > 0 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("config dict has %zd extra items (%R)"),
            unused,
            dict_
        );
        object_decref(dict_);
        return -1;
    }

    object_decref(dict_);
    return 0;
}
