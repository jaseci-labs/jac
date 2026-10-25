import from c {
    def PyUnicode_FromFormatV(format: ptr[u8], vargs: VaList) -> ptr[PyObject];  def _PyErr_FormatV(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format: ptr[u8],
        vargs: VaList
    ) -> ptr[PyObject];  def PyThreadState_GetFrame(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: &mut ptr[PyObject]
    ) -> i32;  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], format_: ptr[u8], *args: any
    ) -> i32;  def _PyTokenizer_FindEncodingFilename(
        fd: i32, filename: ptr[PyObject]
    ) -> ptr[u8];  def strerror(errnum: i32) -> ptr[u8];  def strrchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];  def fileno(stream: ptr[FILE]) -> i32;  def fclose(
        stream: ptr[FILE]
    ) -> i32;  def lseek(fd: i32, offset: i64, whence: i32) -> i64;  def PyErr_WarnExplicitObject(
        category: ptr[PyObject],
        message: ptr[PyObject],
        filename: ptr[PyObject],
        lineno: i32,
        module: ptr[PyObject],
        registry: ptr[PyObject]
    ) -> i32;  def PyTraceBack_Print(v: ptr[PyObject], f: ptr[PyObject]) -> i32;  def _PyTraceBack_FromFrame(
        tb_next: ptr[PyObject], frame: ptr[PyObject]
    ) -> ptr[PyObject];  obj ErrorsStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut ErrorsStack) -> int;  glob:priv UnraisableHookArgs_fields:
             list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("exc_type"), doc=ptr[u8]("Exception type")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("exc_value"), doc=ptr[u8]("Exception value")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("exc_traceback"), doc=ptr[u8]("Exception traceback")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("err_msg"), doc=ptr[u8]("Error message")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("object"), doc=ptr[u8]("Object causing the exception")
             ),
             PyStructSequence_Field()
         ],
         UnraisableHookArgs_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("UnraisableHookArgs"),
             doc=ptr[u8](
                 "UnraisableHookArgs\n\n"
                 "Type used to pass arguments to sys.unraisablehook."
             ),
             fields=addressof(UnraisableHookArgs_fields),
             n_in_sequence=5
         ),
         UnraisableHookArgsType: PyTypeObject = PyTypeObject();
}

glob:priv Py_NORMALIZE_RECURSION_LIMIT: Final[i64] = 32,
     ERR_PROGRAMTEXT_LINEBUF: Final[i64] = 1000;

def current_exception_slot(tstate: ptr[PyThreadState]) -> ptr[ptr[PyObject]];

def tstate_exc_info(tstate: ptr[PyThreadState]) -> ptr[u8];

def stack_item_value_slot(item: ptr[u8]) -> ptr[ptr[PyObject]];

def stack_item_previous(item: ptr[u8]) -> ptr[u8];

def recursion_headroom_slot(tstate: ptr[PyThreadState]) -> ptr[i32];

def exception_instance_class(op: ptr[PyObject]) -> ptr[PyObject];

def raised(tstate: ptr[PyThreadState]) -> bool;

def ok_status -> PyStatus;

def _PyErr_CreateException(
    exception_type: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def get_normalization_failure_note(
    tstate: ptr[PyThreadState], exception: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def normalize_exception(
    tstate: ptr[PyThreadState],
    exc_in: ptr[PyObject],
    val_in: ptr[PyObject],
    tb_in: ptr[PyObject]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]];

def fetch(
    tstate: ptr[PyThreadState]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]];

def get_exc_type(exc_value: ptr[PyObject]) -> ptr[PyObject];

def get_exc_traceback(exc_value: ptr[PyObject]) -> ptr[PyObject];

def finish_from_cause(tstate: ptr[PyThreadState], exc: ptr[PyObject]);

def new_importerror(
    tstate: ptr[PyThreadState],
    exctype: ptr[PyObject],
    msg: ptr[PyObject],
    name_in: ptr[PyObject],
    path_in: ptr[PyObject],
    from_name_in: ptr[PyObject]
) -> ptr[PyObject];

def _PyErr_SetImportErrorSubclassWithNameFrom(
    exception: ptr[PyObject],
    msg: ptr[PyObject],
    name: ptr[PyObject],
    path: ptr[PyObject],
    from_name: ptr[PyObject]
) -> ptr[PyObject];

def make_unraisable_hook_args(
    tstate: ptr[PyThreadState],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject],
    err_msg: ptr[PyObject],
    obj_: ptr[PyObject]
) -> ptr[PyObject];

def write_unraisable_exc_file(
    tstate: ptr[PyThreadState],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject],
    err_msg: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject]
) -> i32;

def write_unraisable_exc(
    tstate: ptr[PyThreadState],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject],
    err_msg: ptr[PyObject],
    obj_: ptr[PyObject]
) -> i32;

def unraisable_fetch(
    tstate: ptr[PyThreadState]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]];

def unraisable_report(
    tstate: ptr[PyThreadState],
    exc_type_in: ptr[PyObject],
    exc_value_in: ptr[PyObject],
    exc_tb_in: ptr[PyObject],
    err_msg_in: ptr[PyObject],
    obj_in: ptr[PyObject]
);

def ensure_tstate_not_null(func: ptr[u8], tstate: ptr[PyThreadState]);

def PyErr_SyntaxLocationObjectEx(
    filename: ptr[PyObject],
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
);

def set_location_attr(
    tstate: ptr[PyThreadState], exc: ptr[PyObject], name: ptr[PyObject], value: i32
);

def err_programtext(fp: ptr[FILE], lineno: i32, encoding: ptr[u8]) -> ptr[PyObject];

import from c {
    def _PyErr_SetRaisedException(tstate: ptr[PyThreadState], exc: ptr[PyObject]) {
        slot = current_exception_slot(tstate);
        old_exc = slot.view(1)[0];
        slot.view(1)[0] = exc;
        object_xdecref(old_exc);
    }  def _PyErr_Restore(
        tstate: ptr[PyThreadState],
        type: ptr[PyObject],
        value_in: ptr[PyObject],
        traceback: ptr[PyObject]
    ) {
        if not type {
            _PyErr_SetRaisedException(tstate, NULL);
            return;
        }
        value = value_in;
        if not value or type != exception_instance_class(value) {
            exc = _PyErr_CreateException(type, value);
            object_xdecref(value);
            if not exc {
                object_decref(type);
                object_xdecref(traceback);
                return;
            }
            value = exc;
        }
        if traceback {
            if PyException_SetTraceback(value, traceback) < i32(0) {
                object_decref(traceback);
                object_decref(value);
                object_decref(type);
                return;
            }
            object_decref(traceback);
        }
        _PyErr_SetRaisedException(tstate, value);
        object_decref(type);
    }  def PyErr_Restore(
        type: ptr[PyObject], value: ptr[PyObject], traceback: ptr[PyObject]
    ) {
        _PyErr_Restore(thread_state(), type, value, traceback);
    }  def PyErr_SetRaisedException(exc: ptr[PyObject]) {
        _PyErr_SetRaisedException(thread_state(), exc);
    }  def _PyErr_GetTopmostException(tstate: ptr[PyThreadState]) -> ptr[u8] {
        exc_info = tstate_exc_info(tstate);
        while not stack_item_value_slot(exc_info).view(1)[0]
            and stack_item_previous(exc_info) {
            exc_info = stack_item_previous(exc_info);
        }
        return exc_info;
    }  def _PyErr_SetObject(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], value_in: ptr[PyObject]
    ) {
        value = value_in;
        if exception and not exception_class_check(exception) {
            _PyErr_Format(
                tstate,
                PyExc_SystemError,
                ptr[u8](
                    "_PyErr_SetObject: exception %R is not a BaseException subclass"
                ),
                exception
            );
            return;
        }

        is_subclass = i32(0);
        if value and exception_instance_check(value) {
            is_subclass = PyObject_IsSubclass(
                exception_instance_class(value), exception
            );
            if is_subclass < i32(0) {
                return;
            }
        }
        object_xincref(value);
        if is_subclass == i32(0) {
            _PyErr_Clear(tstate);
            fixed_value = _PyErr_CreateException(exception, value);
            if not fixed_value {
                exc = _PyErr_GetRaisedException(tstate);
                note = get_normalization_failure_note(tstate, exception, value);
                object_xdecref(value);
                if note {
                    _PyException_AddNote(exc, note);
                    object_decref(note);
                }
                _PyErr_SetRaisedException(tstate, exc);
                return;
            }
            old_value = value;
            value = fixed_value;
            object_xdecref(old_value);
        }
        exc_value = stack_item_value_slot(_PyErr_GetTopmostException(tstate)).view(1)[
            0
        ];
        if exc_value and exc_value != Py_None {
            object_incref(exc_value);

            if exc_value != value {
                o = exc_value;

                slow_o = o;
                slow_update_toggle = False;
                while True {
                    context = PyException_GetContext(o);
                    if not context {
                        break;
                    }
                    object_decref(context);
                    if context == value {
                        PyException_SetContext(o, NULL);
                        break;
                    }
                    o = context;
                    if o == slow_o {
                        break;
                    }
                    if slow_update_toggle {
                        slow_o = PyException_GetContext(slow_o);
                        object_decref(slow_o);
                    }
                    slow_update_toggle = not slow_update_toggle;
                }
                PyException_SetContext(value, exc_value);
            } else {
                object_decref(exc_value);
            }
        }
        tb = NULL;
        if exception_instance_check(value) {
            tb = PyException_GetTraceback(value);
        }
        _PyErr_Restore(
            tstate, object_new_ref(exception_instance_class(value)), value, tb
        );
    }  def PyErr_SetObject(exception: ptr[PyObject], value: ptr[PyObject]) {
        _PyErr_SetObject(thread_state(), exception, value);
    }  def _PyErr_SetKeyError(arg: ptr[PyObject]) {
        tstate = thread_state();

        _PyErr_Clear(tstate);
        exc = PyObject_CallOneArg(PyExc_KeyError, arg);
        if not exc {
            return;
        }
        _PyErr_SetObject(tstate, exception_instance_class(exc), exc);
        object_decref(exc);
    }  def _PyErr_SetNone(tstate: ptr[PyThreadState], exception: ptr[PyObject]) {
        _PyErr_SetObject(tstate, exception, NULL);
    }  def PyErr_SetNone(exception: ptr[PyObject]) {
        _PyErr_SetNone(thread_state(), exception);
    }  def _PyErr_SetString(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], string: ptr[u8]
    ) {
        value = PyUnicode_FromString(string);
        if value {
            _PyErr_SetObject(tstate, exception, value);
            object_decref(value);
        }
    }  def PyErr_SetString(exception: ptr[PyObject], string: ptr[u8]) {
        _PyErr_SetString(thread_state(), exception, string);
    }  def _PyErr_SetLocaleString(exception: ptr[PyObject], string: ptr[u8]) {
        value = PyUnicode_DecodeLocale(string, ptr[u8]("surrogateescape"));
        if value {
            PyErr_SetObject(exception, value);
            object_decref(value);
        }
    }  def PyErr_Occurred -> ptr[PyObject] {
        return error_occurred(thread_state());
    }  def PyErr_GivenExceptionMatches(
        err_in: ptr[PyObject], exc: ptr[PyObject]
    ) -> i32 {
        if not err_in or not exc {
            return i32(0);
        }
        if tuple_check(exc) {
            n = PyTuple_Size(exc);
            i: i64 = 0;
            while i < n {
                if PyErr_GivenExceptionMatches(err_in, tuple_get_item(exc, i))
                    != i32(0) {
                    return i32(1);
                }
                i += 1;
            }
            return i32(0);
        }

        err = err_in;
        if exception_instance_check(err) {
            err = exception_instance_class(err);
        }
        if exception_class_check(err) and exception_class_check(exc) {
            return PyType_IsSubtype(err, exc);
        }
        return i32(1) if err == exc else i32(0);
    }  def _PyErr_ExceptionMatches(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    ) -> i32 {
        return PyErr_GivenExceptionMatches(error_occurred(tstate), exc);
    }  def PyErr_ExceptionMatches(exc: ptr[PyObject]) -> i32 {
        return _PyErr_ExceptionMatches(thread_state(), exc);
    }  def _PyErr_NormalizeException(
        tstate: ptr[PyThreadState],
        exc: ptr[ptr[PyObject]],
        val: ptr[ptr[PyObject]],
        tb: ptr[ptr[PyObject]]
    ) {
        (new_exc, new_val, new_tb) = normalize_exception(
            tstate, exc.view(1)[0], val.view(1)[0], tb.view(1)[0]
        );
        exc.view(1)[0] = new_exc;
        val.view(1)[0] = new_val;
        tb.view(1)[0] = new_tb;
    }  def PyErr_NormalizeException(
        exc: ptr[ptr[PyObject]], val: ptr[ptr[PyObject]], tb: ptr[ptr[PyObject]]
    ) {
        _PyErr_NormalizeException(thread_state(), exc, val, tb);
    }  def _PyErr_GetRaisedException(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
        slot = current_exception_slot(tstate);
        exc = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        return exc;
    }  def PyErr_GetRaisedException -> ptr[PyObject] {
        return _PyErr_GetRaisedException(thread_state());
    }  def _PyErr_Fetch(
        tstate: ptr[PyThreadState],
        p_type: ptr[ptr[PyObject]],
        p_value: ptr[ptr[PyObject]],
        p_traceback: ptr[ptr[PyObject]]
    ) {
        (type, value, traceback) = fetch(tstate);
        p_value.view(1)[0] = value;
        p_type.view(1)[0] = type;
        p_traceback.view(1)[0] = traceback;
    }  def PyErr_Fetch(
        p_type: ptr[ptr[PyObject]],
        p_value: ptr[ptr[PyObject]],
        p_traceback: ptr[ptr[PyObject]]
    ) {
        _PyErr_Fetch(thread_state(), p_type, p_value, p_traceback);
    }  def _PyErr_Clear(tstate: ptr[PyThreadState]) {
        _PyErr_Restore(tstate, NULL, NULL, NULL);
    }  def PyErr_Clear {
        _PyErr_Clear(thread_state());
    }  def _PyErr_GetExcInfo(
        tstate: ptr[PyThreadState],
        p_type: ptr[ptr[PyObject]],
        p_value: ptr[ptr[PyObject]],
        p_traceback: ptr[ptr[PyObject]]
    ) {
        exc_value = stack_item_value_slot(_PyErr_GetTopmostException(tstate)).view(1)[
            0
        ];
        p_type.view(1)[0] = get_exc_type(exc_value);
        p_value.view(1)[0] = object_xnewref(exc_value);
        p_traceback.view(1)[0] = get_exc_traceback(exc_value);
    }  def _PyErr_GetHandledException(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
        exc = stack_item_value_slot(_PyErr_GetTopmostException(tstate)).view(1)[0];
        if not exc or exc == Py_None {
            return NULL;
        }
        return object_new_ref(exc);
    }  def PyErr_GetHandledException -> ptr[PyObject] {
        return _PyErr_GetHandledException(thread_state());
    }  def _PyErr_SetHandledException(tstate: ptr[PyThreadState], exc: ptr[PyObject]) {
        slot = stack_item_value_slot(tstate_exc_info(tstate));
        old = slot.view(1)[0];
        slot.view(1)[0] = object_xnewref(NULL if exc == Py_None else exc);
        object_xdecref(old);
    }  def PyErr_SetHandledException(exc: ptr[PyObject]) {
        _PyErr_SetHandledException(thread_state(), exc);
    }  def PyErr_GetExcInfo(
        p_type: ptr[ptr[PyObject]],
        p_value: ptr[ptr[PyObject]],
        p_traceback: ptr[ptr[PyObject]]
    ) {
        _PyErr_GetExcInfo(thread_state(), p_type, p_value, p_traceback);
    }  def PyErr_SetExcInfo(
        type: ptr[PyObject], value: ptr[PyObject], traceback: ptr[PyObject]
    ) {
        PyErr_SetHandledException(value);
        object_xdecref(value);

        object_xdecref(type);
        object_xdecref(traceback);
    }  def _PyErr_StackItemToExcInfoTuple(err_info: ptr[u8]) -> ptr[PyObject] {
        exc_value = stack_item_value_slot(err_info).view(1)[0];
        ret = PyTuple_New(3);
        if not ret {
            return NULL;
        }
        exc_type = get_exc_type(exc_value);
        exc_traceback = get_exc_traceback(exc_value);
        tuple_set_item(ret, 0, exc_type or Py_None);
        tuple_set_item(ret, 1, object_new_ref(exc_value) if exc_value else Py_None);
        tuple_set_item(ret, 2, exc_traceback or Py_None);
        return ret;
    }  def _PyErr_ChainExceptions(
        typ_in: ptr[PyObject], val_in: ptr[PyObject], tb_in: ptr[PyObject]
    ) {
        if not typ_in {
            return;
        }
        tstate = thread_state();
        if not exception_class_check(typ_in) {
            _PyErr_Format(
                tstate,
                PyExc_SystemError,
                ptr[u8](
                    "_PyErr_ChainExceptions: exception %R is not a BaseException subclass"
                ),
                typ_in
            );
            return;
        }
        if raised(tstate) {
            (typ, val, tb) = normalize_exception(tstate, typ_in, val_in, tb_in);
            if tb {
                PyException_SetTraceback(val, tb);
                object_decref(tb);
            }
            object_decref(typ);
            exc2 = _PyErr_GetRaisedException(tstate);
            PyException_SetContext(exc2, val);
            _PyErr_SetRaisedException(tstate, exc2);
        } else {
            _PyErr_Restore(tstate, typ_in, val_in, tb_in);
        }
    }  def _PyErr_ChainExceptions1Tstate(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    ) {
        if not exc {
            return;
        }
        if raised(tstate) {
            exc2 = _PyErr_GetRaisedException(tstate);
            PyException_SetContext(exc2, exc);
            _PyErr_SetRaisedException(tstate, exc2);
        } else {
            _PyErr_SetRaisedException(tstate, exc);
        }
    }  def _PyErr_ChainExceptions1(exc: ptr[PyObject]) {
        _PyErr_ChainExceptions1Tstate(thread_state(), exc);
    }  def _PyErr_ChainStackItem {
        tstate = thread_state();
        exc_value = stack_item_value_slot(tstate_exc_info(tstate)).view(1)[0];
        if not exc_value or exc_value == Py_None {
            return;
        }
        exc = _PyErr_GetRaisedException(tstate);

        _PyErr_SetObject(tstate, exception_instance_class(exc), exc);

        object_decref(exc);
    }  def _PyErr_FormatFromCauseTstate(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format: ptr[u8],
        *vargs: VaList
    ) -> ptr[PyObject] {
        exc = _PyErr_GetRaisedException(tstate);
        _PyErr_FormatV(tstate, exception, format, vargs);
        finish_from_cause(tstate, exc);
        return NULL;
    }  def _PyErr_FormatFromCause(
        exception: ptr[PyObject], format: ptr[u8], *vargs: VaList
    ) -> ptr[PyObject] {
        tstate = thread_state();
        exc = _PyErr_GetRaisedException(tstate);
        _PyErr_FormatV(tstate, exception, format, vargs);
        finish_from_cause(tstate, exc);
        return NULL;
    }  def PyErr_BadArgument -> i32 {
        _PyErr_SetString(
            thread_state(),
            PyExc_TypeError,
            ptr[u8]("bad argument type for built-in operation")
        );
        return i32(0);
    }  def PyErr_NoMemory -> ptr[PyObject] {
        return _PyErr_NoMemory(thread_state());
    }  def PyErr_SetFromErrnoWithFilenameObject(
        exc: ptr[PyObject], filenameObject: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyErr_SetFromErrnoWithFilenameObjects(exc, filenameObject, NULL);
    }  def PyErr_SetFromErrnoWithFilenameObjects(
        exc: ptr[PyObject],
        filenameObject: ptr[PyObject],
        filenameObject2: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();
        i = i32(jacpy_errno());
        if i == EINTR and PyErr_CheckSignals() != i32(0) {
            return NULL;
        }
        message = NULL;
        if i != i32(0) {
            s = strerror(i);
            message = PyUnicode_DecodeLocale(s, ptr[u8]("surrogateescape"));
        } else {
            message = PyUnicode_FromString(ptr[u8]("Error"));
        }
        if not message {
            return NULL;
        }
        args = NULL;
        if filenameObject {
            if filenameObject2 {
                args = Py_BuildValue(
                    ptr[u8]("(iOOiO)"),
                    i,
                    message,
                    filenameObject,
                    i32(0),
                    filenameObject2
                );
            } else {
                args = Py_BuildValue(ptr[u8]("(iOO)"), i, message, filenameObject);
            }
        } else {
            args = Py_BuildValue(ptr[u8]("(iO)"), i, message);
        }
        object_decref(message);
        if args {
            v = PyObject_Call(exc, args, NULL);
            object_decref(args);
            if v {
                _PyErr_SetObject(tstate, exception_instance_class(v), v);
                object_decref(v);
            }
        }
        return NULL;
    }  def PyErr_SetFromErrnoWithFilename(
        exc: ptr[PyObject], filename: ptr[u8]
    ) -> ptr[PyObject] {
        name = NULL;
        if filename {
            i = jacpy_errno();
            name = PyUnicode_DecodeFSDefault(filename);
            if not name {
                return NULL;
            }
            jacpy_set_errno(i);
        }
        result = PyErr_SetFromErrnoWithFilenameObjects(exc, name, NULL);
        object_xdecref(name);
        return result;
    }  def PyErr_SetFromErrno(exc: ptr[PyObject]) -> ptr[PyObject] {
        return PyErr_SetFromErrnoWithFilenameObjects(exc, NULL, NULL);
    }  def PyErr_SetImportErrorSubclass(
        exception: ptr[PyObject],
        msg: ptr[PyObject],
        name: ptr[PyObject],
        path: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _PyErr_SetImportErrorSubclassWithNameFrom(
            exception, msg, name, path, NULL
        );
    }  def _PyErr_SetImportErrorWithNameFrom(
        msg: ptr[PyObject],
        name: ptr[PyObject],
        path: ptr[PyObject],
        from_name: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _PyErr_SetImportErrorSubclassWithNameFrom(
            PyExc_ImportError, msg, name, path, from_name
        );
    }  def PyErr_SetImportError(
        msg: ptr[PyObject], name: ptr[PyObject], path: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyErr_SetImportErrorSubclass(PyExc_ImportError, msg, name, path);
    }  def _PyErr_SetModuleNotFoundError(name: ptr[PyObject]) -> i32 {
        tstate = thread_state();
        if not name {
            _PyErr_SetString(
                tstate, PyExc_TypeError, ptr[u8]("expected a name argument")
            );
            return i32(-1);
        }
        msg = PyUnicode_FromFormat("%S module not found", name);
        if not msg {
            return i32(-1);
        }
        exctype = PyExc_ModuleNotFoundError;
        exc = new_importerror(tstate, exctype, msg, name, NULL, NULL);
        object_decref(msg);
        if not exc {
            return i32(-1);
        }
        _PyErr_SetObject(tstate, exctype, exc);
        object_decref(exc);
        return i32(0);
    }  def _PyErr_BadInternalCall(filename: ptr[u8], lineno: i32) {
        _PyErr_Format(
            thread_state(),
            PyExc_SystemError,
            ptr[u8]("%s:%d: bad argument to internal function"),
            filename,
            lineno
        );
    }  def PyErr_BadInternalCall {
        _PyErr_SetString(
            thread_state(),
            PyExc_SystemError,
            ptr[u8]("bad argument to internal function")
        );
    }  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format: ptr[u8],
        *vargs: VaList
    ) -> ptr[PyObject] {
        _PyErr_FormatV(tstate, exception, format, vargs);
        return NULL;
    }  def PyErr_Format(
        exception: ptr[PyObject], format: ptr[u8], *vargs: VaList
    ) -> ptr[PyObject] {
        _PyErr_FormatV(thread_state(), exception, format, vargs);
        return NULL;
    }  def _PyErr_FormatNote(format: ptr[u8], *vargs: VaList) {
        exc = PyErr_GetRaisedException();
        if not exc {
            return;
        }
        note = PyUnicode_FromFormatV(format, vargs);
        if not note {
            _PyErr_ChainExceptions1(exc);
            return;
        }
        res = _PyException_AddNote(exc, note);
        object_decref(note);
        if res < i32(0) {
            _PyErr_ChainExceptions1(exc);
            return;
        }
        PyErr_SetRaisedException(exc);
    }  def PyErr_NewException(
        name: ptr[u8], base_in: ptr[PyObject], dict_in: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();
        modulename = NULL;
        mydict = NULL;
        bases = NULL;
        result = NULL;
        dot = strrchr(name, i32(46));
        if not dot {
            _PyErr_SetString(
                tstate,
                PyExc_SystemError,
                ptr[u8]("PyErr_NewException: name must be module.class")
            );
            return NULL;
        }
        base = base_in or PyExc_Exception;
        dct = dict_in;
        failed = False;
        if not dct {
            mydict = PyDict_New();
            dct = mydict;
            if not dct {
                failed = True;
            }
        }
        if not failed {
            r = PyDict_Contains(dct, py_id(_Py_ID___module__));
            if r < i32(0) {
                failed = True;
            } elif r == i32(0) {
                modulename = PyUnicode_FromStringAndSize(
                    name, i64(int(dot) - int(name))
                );
                if not modulename
                    or PyDict_SetItem(dct, py_id(_Py_ID___module__), modulename)
                        != i32(0) {
                    failed = True;
                }
            }
        }
        if not failed {
            if tuple_check(base) {
                bases = object_new_ref(base);
            } else {
                bases = PyTuple_Pack(i64(1), base);
                if not bases {
                    failed = True;
                }
            }
        }
        if not failed {
            result = PyObject_CallFunction(
                ptr[PyObject](addressof(PyType_Type)), "sOO", dot + 1, bases, dct
            );
        }
        object_xdecref(bases);
        object_xdecref(mydict);
        object_xdecref(modulename);
        return result;
    }  def PyErr_NewExceptionWithDoc(
        name: ptr[u8], doc: ptr[u8], base: ptr[PyObject], dict_in: ptr[PyObject]
    ) -> ptr[PyObject] {
        mydict = NULL;
        dct = dict_in;
        if not dct {
            mydict = PyDict_New();
            dct = mydict;
            if not dct {
                return NULL;
            }
        }
        if doc {
            docobj = PyUnicode_FromString(doc);
            if not docobj {
                object_xdecref(mydict);
                return NULL;
            }
            result = PyDict_SetItemString(dct, ptr[u8]("__doc__"), docobj);
            object_decref(docobj);
            if result < i32(0) {
                object_xdecref(mydict);
                return NULL;
            }
        }
        ret = PyErr_NewException(name, base, dct);
        object_xdecref(mydict);
        return ret;
    }  def _PyErr_InitTypes(interp: ptr[PyInterpreterState]) -> PyStatus {
        if _PyStructSequence_InitBuiltinWithFlags(
            interp,
            ptr[PyObject](addressof(UnraisableHookArgsType)),
            addressof(UnraisableHookArgs_desc),
            u64(0)
        )
            < i32(0) {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyErr_InitTypes"),
                err_msg=ptr[u8]("failed to initialize UnraisableHookArgs type"),
                exitcode=0
            );
        }
        return ok_status();
    }  def _PyErr_FiniTypes(interp: ptr[PyInterpreterState]) {
        _PyStructSequence_FiniBuiltin(
            interp, ptr[PyObject](addressof(UnraisableHookArgsType))
        );
    }  def _PyErr_WriteUnraisableDefaultHook(args: ptr[PyObject]) -> ptr[PyObject] {
        tstate = thread_state();
        if not object_is_type(args, addressof(UnraisableHookArgsType)) {
            _PyErr_SetString(
                tstate,
                PyExc_TypeError,
                ptr[u8]("sys.unraisablehook argument type must be UnraisableHookArgs")
            );
            return NULL;
        }

        if write_unraisable_exc(
            tstate,
            tuple_get_item(args, 0),
            tuple_get_item(args, 1),
            tuple_get_item(args, 2),
            tuple_get_item(args, 3),
            tuple_get_item(args, 4)
        )
            < i32(0) {
            return NULL;
        }
        return object_new_ref(Py_None);
    }  def PyErr_FormatUnraisable(format: ptr[u8], *va: VaList) {
        tstate = thread_state();
        ensure_tstate_not_null(ptr[u8]("format_unraisable_v"), tstate);
        (exc_type, exc_value, exc_tb) = unraisable_fetch(tstate);
        err_msg = NULL;
        if exc_type and format {
            err_msg = PyUnicode_FromFormatV(format, va);
            if not err_msg {
                PyErr_Clear();
            }
        }
        unraisable_report(tstate, exc_type, exc_value, exc_tb, err_msg, NULL);
    }  def PyErr_WriteUnraisable(obj_: ptr[PyObject]) {
        tstate = thread_state();
        ensure_tstate_not_null(ptr[u8]("format_unraisable_v"), tstate);
        (exc_type, exc_value, exc_tb) = unraisable_fetch(tstate);
        unraisable_report(tstate, exc_type, exc_value, exc_tb, NULL, obj_);
    }  def PyErr_SyntaxLocation(filename: ptr[u8], lineno: i32) {
        PyErr_SyntaxLocationEx(filename, lineno, i32(-1));
    }  def PyErr_SyntaxLocationObject(
        filename: ptr[PyObject], lineno: i32, col_offset: i32
    ) {
        PyErr_SyntaxLocationObjectEx(filename, lineno, col_offset, lineno, i32(-1));
    }  def PyErr_RangedSyntaxLocationObject(
        filename: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32
    ) {
        PyErr_SyntaxLocationObjectEx(
            filename, lineno, col_offset, end_lineno, end_col_offset
        );
    }  def PyErr_SyntaxLocationEx(filename: ptr[u8], lineno: i32, col_offset: i32) {
        tstate = thread_state();
        fileobj = NULL;
        if filename {
            fileobj = PyUnicode_DecodeFSDefault(filename);
            if not fileobj {
                _PyErr_Clear(tstate);
            }
        }
        PyErr_SyntaxLocationObject(fileobj, lineno, col_offset);
        object_xdecref(fileobj);
    }  def _PyErr_RaiseSyntaxError(
        msg: ptr[PyObject],
        filename: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32
    ) {
        text = PyErr_ProgramTextObject(filename, lineno);
        if not text {
            text = object_new_ref(Py_None);
        }
        args = Py_BuildValue(
            ptr[u8]("O(OiiOii)"),
            msg,
            filename,
            lineno,
            col_offset,
            text,
            end_lineno,
            end_col_offset
        );
        if args {
            PyErr_SetObject(PyExc_SyntaxError, args);
        }
        object_decref(text);
        object_xdecref(args);
    }  def _PyErr_EmitSyntaxWarning(
        msg: ptr[PyObject],
        filename: ptr[PyObject],
        lineno: i32,
        col_offset: i32,
        end_lineno: i32,
        end_col_offset: i32
    ) -> i32 {
        if PyErr_WarnExplicitObject(
            PyExc_SyntaxWarning, msg, filename, lineno, NULL, NULL
        )
            < i32(0) {
            if PyErr_ExceptionMatches(PyExc_SyntaxWarning) != i32(0) {
                PyErr_Clear();
                _PyErr_RaiseSyntaxError(
                    msg, filename, lineno, col_offset, end_lineno, end_col_offset
                );
            }
            return i32(-1);
        }
        return i32(0);
    }  def PyErr_ProgramText(filename: ptr[u8], lineno: i32) -> ptr[PyObject] {
        if not filename {
            return NULL;
        }
        filename_obj = PyUnicode_DecodeFSDefault(filename);
        if not filename_obj {
            PyErr_Clear();
            return NULL;
        }
        res = PyErr_ProgramTextObject(filename_obj, lineno);
        object_decref(filename_obj);
        return res;
    }  def _PyErr_ProgramDecodedTextObject(
        filename: ptr[PyObject], lineno: i32, encoding_in: ptr[u8]
    ) -> ptr[PyObject] {
        if not filename or lineno <= i32(0) {
            return NULL;
        }
        fp = ptr[FILE](Py_fopen(filename, ptr[u8]("r")));
        if not fp {
            PyErr_Clear();
            return NULL;
        }
        encoding = encoding_in;
        found_encoding = ptr[u8]();
        if not encoding {
            fd = fileno(fp);
            found_encoding = _PyTokenizer_FindEncodingFilename(fd, filename);
            encoding = found_encoding;
            if not encoding {
                PyErr_Clear();
                encoding = ptr[u8]("utf-8");
            }

            if lseek(fd, 0, SEEK_SET) == -1 {
                fclose(fp);
                PyMem_Free(ptr(found_encoding));
                return NULL;
            }
        }
        res = err_programtext(fp, lineno, encoding);
        fclose(fp);
        PyMem_Free(ptr(found_encoding));
        return res;
    }  def PyErr_ProgramTextObject(
        filename: ptr[PyObject], lineno: i32
    ) -> ptr[PyObject] {
        return _PyErr_ProgramDecodedTextObject(filename, lineno, ptr[u8]());
    }
}

impl current_exception_slot(tstate: ptr[PyThreadState]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](tstate) + PyThreadState_CURRENT_EXCEPTION);
}

impl tstate_exc_info(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_EXC_INFO).view(1)[0];
}

impl stack_item_value_slot(item: ptr[u8]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](item + _PyErr_StackItem_EXC_VALUE);
}

impl stack_item_previous(item: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](item + _PyErr_StackItem_PREVIOUS_ITEM).view(1)[0];
}

impl recursion_headroom_slot(tstate: ptr[PyThreadState]) -> ptr[i32] {
    return ptr[i32](ptr[u8](tstate) + PyThreadState_RECURSION_HEADROOM);
}

impl exception_instance_class(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](object_type(op));
}

impl raised(tstate: ptr[PyThreadState]) -> bool {
    if current_exception_slot(tstate).view(1)[0] {
        return True;
    }
    return False;
}

impl ok_status -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl _PyErr_CreateException(
    exception_type: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    exc = NULL;
    if not value or value == Py_None {
        exc = PyObject_CallNoArgs(exception_type);
    } elif tuple_check(value) {
        exc = PyObject_Call(exception_type, value, NULL);
    } else {
        exc = PyObject_CallOneArg(exception_type, value);
    }
    if exc and not exception_instance_check(exc) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "calling %R should have returned an instance of BaseException, not %s"
            ),
            exception_type,
            object_type(exc).view(1)[0].tp_name
        );
        object_decref(exc);
        exc = NULL;
    }
    return exc;
}

impl get_normalization_failure_note(
    tstate: ptr[PyThreadState], exception: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    args = PyObject_Repr(value);
    if not args {
        _PyErr_Clear(tstate);
        args = PyUnicode_FromFormat("<unknown>");
    }
    note = NULL;
    tpname = ptr[PyTypeObject](exception).view(1)[0].tp_name;
    if not args {
        _PyErr_Clear(tstate);
        note = PyUnicode_FromFormat("Normalization failed: type=%s", tpname);
    } else {
        note = PyUnicode_FromFormat(
            "Normalization failed: type=%s args=%S", tpname, args
        );
        object_decref(args);
    }
    return note;
}

impl normalize_exception(
    tstate: ptr[PyThreadState],
    exc_in: ptr[PyObject],
    val_in: ptr[PyObject],
    tb_in: ptr[PyObject]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]] {
    recursion_depth: i64 = 0;
    headroom = recursion_headroom_slot(tstate);
    headroom.view(1)[0] = headroom.view(1)[0] + i32(1);
    exc = exc_in;
    val = val_in;
    tb = tb_in;
    while True {
        type = exc;
        if not type {
            headroom.view(1)[0] = headroom.view(1)[0] - i32(1);
            return (exc, val, tb);
        }
        value = val;

        if not value {
            value = object_new_ref(Py_None);
        }
        failed = False;

        if exception_class_check(type) {
            inclass = NULL;
            is_subclass = i32(0);
            if exception_instance_check(value) {
                inclass = exception_instance_class(value);
                is_subclass = PyObject_IsSubclass(inclass, type);
                if is_subclass < i32(0) {
                    failed = True;
                }
            }
            if not failed {
                if is_subclass == i32(0) {
                    fixed_value = _PyErr_CreateException(type, value);
                    if not fixed_value {
                        failed = True;
                    } else {
                        old = value;
                        value = fixed_value;
                        object_decref(old);
                    }
                } elif inclass != type {
                    old_type = type;
                    type = object_new_ref(inclass);
                    object_decref(old_type);
                }
            }
        }
        if not failed {
            headroom.view(1)[0] = headroom.view(1)[0] - i32(1);
            return (type, value, tb);
        }
        object_decref(type);
        object_decref(value);
        recursion_depth += 1;
        if recursion_depth == Py_NORMALIZE_RECURSION_LIMIT {
            _PyErr_SetString(
                tstate,
                PyExc_RecursionError,
                ptr[u8](
                    "maximum recursion depth exceeded while normalizing an exception"
                )
            );
        }

        initial_tb = tb;
        (exc, val, tb) = fetch(tstate);
        if initial_tb {
            if not tb {
                tb = initial_tb;
            } else {
                object_decref(initial_tb);
            }
        }

        if recursion_depth >= Py_NORMALIZE_RECURSION_LIMIT + 2 {
            if PyErr_GivenExceptionMatches(exc, PyExc_MemoryError) != i32(0) {
                Py_FatalError(
                    "Cannot recover from MemoryErrors while normalizing exceptions."
                );
            } else {
                Py_FatalError(
                    "Cannot recover from the recursive normalization of an exception."
                );
            }
        }
    }
    return (exc, val, tb);
}

impl fetch(
    tstate: ptr[PyThreadState]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]] {
    exc = _PyErr_GetRaisedException(tstate);
    if not exc {
        return (NULL, NULL, NULL);
    }
    return (
        object_new_ref(exception_instance_class(exc)),
        exc,
        PyException_GetTraceback(exc)
    );
}

impl get_exc_type(exc_value: ptr[PyObject]) -> ptr[PyObject] {
    if not exc_value or exc_value == Py_None {
        return Py_None;
    }
    return object_new_ref(exception_instance_class(exc_value));
}

impl get_exc_traceback(exc_value: ptr[PyObject]) -> ptr[PyObject] {
    if not exc_value or exc_value == Py_None {
        return Py_None;
    }
    tb = PyException_GetTraceback(exc_value);
    if tb {
        return tb;
    }
    return Py_None;
}

impl finish_from_cause(tstate: ptr[PyThreadState], exc: ptr[PyObject]) {
    exc2 = _PyErr_GetRaisedException(tstate);
    PyException_SetCause(exc2, object_new_ref(exc));
    PyException_SetContext(exc2, object_new_ref(exc));
    object_decref(exc);
    _PyErr_SetRaisedException(tstate, exc2);
}

impl new_importerror(
    tstate: ptr[PyThreadState],
    exctype: ptr[PyObject],
    msg: ptr[PyObject],
    name_in: ptr[PyObject],
    path_in: ptr[PyObject],
    from_name_in: ptr[PyObject]
) -> ptr[PyObject] {
    issubclass = PyObject_IsSubclass(exctype, PyExc_ImportError);
    if issubclass < i32(0) {
        return NULL;
    } elif issubclass == i32(0) {
        _PyErr_SetString(
            tstate, PyExc_TypeError, ptr[u8]("expected a subclass of ImportError")
        );
        return NULL;
    }
    if not msg {
        _PyErr_SetString(
            tstate, PyExc_TypeError, ptr[u8]("expected a message argument")
        );
        return NULL;
    }
    name = name_in or Py_None;
    path = path_in or Py_None;
    from_name = from_name_in or Py_None;
    kwargs = PyDict_New();
    if not kwargs {
        return NULL;
    }
    exc = NULL;
    if PyDict_SetItemString(kwargs, ptr[u8]("name"), name) >= i32(0)
        and PyDict_SetItemString(kwargs, ptr[u8]("path"), path) >= i32(0)
        and PyDict_SetItemString(kwargs, ptr[u8]("name_from"), from_name) >= i32(0) {
        slots: own ErrorsStack = ErrorsStack();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        stack.view(1)[0] = msg;
        exc = PyObject_VectorcallDict(exctype, stack, u64(1), kwargs);
    }
    object_decref(kwargs);
    return exc;
}

impl _PyErr_SetImportErrorSubclassWithNameFrom(
    exception: ptr[PyObject],
    msg: ptr[PyObject],
    name: ptr[PyObject],
    path: ptr[PyObject],
    from_name: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    error = new_importerror(tstate, exception, msg, name, path, from_name);
    if error {
        _PyErr_SetObject(tstate, exception_instance_class(error), error);
        object_decref(error);
    }
    return NULL;
}

impl make_unraisable_hook_args(
    tstate: ptr[PyThreadState],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject],
    err_msg: ptr[PyObject],
    obj_: ptr[PyObject]
) -> ptr[PyObject] {
    args = PyStructSequence_New(ptr[PyObject](addressof(UnraisableHookArgsType)));
    if not args {
        return NULL;
    }
    tuple_set_item(args, 0, object_new_ref(exc_type or Py_None));
    tuple_set_item(args, 1, object_new_ref(exc_value or Py_None));
    tuple_set_item(args, 2, object_new_ref(exc_tb or Py_None));
    tuple_set_item(args, 3, object_new_ref(err_msg or Py_None));
    tuple_set_item(args, 4, object_new_ref(obj_ or Py_None));
    if raised(tstate) {
        object_decref(args);
        return NULL;
    }
    return args;
}

impl write_unraisable_exc_file(
    tstate: ptr[PyThreadState],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject],
    err_msg: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject]
) -> i32 {
    if obj_ and obj_ != Py_None {
        if err_msg and err_msg != Py_None {
            if PyFile_WriteObject(err_msg, file, Py_PRINT_RAW) < i32(0) {
                return i32(-1);
            }
            if PyFile_WriteString(ptr[u8](": "), file) < i32(0) {
                return i32(-1);
            }
        } else {
            if PyFile_WriteString(ptr[u8]("Exception ignored in: "), file) < i32(0) {
                return i32(-1);
            }
        }
        if PyFile_WriteObject(obj_, file, i32(0)) < i32(0) {
            _PyErr_Clear(tstate);
            if PyFile_WriteString(ptr[u8]("<object repr() failed>"), file) < i32(0) {
                return i32(-1);
            }
        }
        if PyFile_WriteString(ptr[u8]("\n"), file) < i32(0) {
            return i32(-1);
        }
    } elif err_msg and err_msg != Py_None {
        if PyFile_WriteObject(err_msg, file, Py_PRINT_RAW) < i32(0) {
            return i32(-1);
        }
        if PyFile_WriteString(ptr[u8](":\n"), file) < i32(0) {
            return i32(-1);
        }
    }
    if exc_tb and exc_tb != Py_None {
        if PyTraceBack_Print(exc_tb, file) < i32(0) {
            _PyErr_Clear(tstate);
        }
    }
    if not exc_type or exc_type == Py_None {
        return i32(-1);
    }
    modulename = PyObject_GetAttr(exc_type, py_id(_Py_ID___module__));
    if not modulename or not unicode_check(modulename) {
        object_xdecref(modulename);
        _PyErr_Clear(tstate);
        if PyFile_WriteString(ptr[u8]("<unknown>"), file) < i32(0) {
            return i32(-1);
        }
    } else {
        if _PyUnicode_Equal(modulename, py_id(_Py_ID_builtins)) == i32(0)
            and _PyUnicode_Equal(modulename, py_id(_Py_ID___main__)) == i32(0) {
            if PyFile_WriteObject(modulename, file, Py_PRINT_RAW) < i32(0) {
                object_decref(modulename);
                return i32(-1);
            }
            object_decref(modulename);
            if PyFile_WriteString(ptr[u8]("."), file) < i32(0) {
                return i32(-1);
            }
        } else {
            object_decref(modulename);
        }
    }
    qualname = PyType_GetQualName(ptr[PyTypeObject](exc_type));
    if not qualname or not unicode_check(qualname) {
        object_xdecref(qualname);
        _PyErr_Clear(tstate);
        if PyFile_WriteString(ptr[u8]("<unknown>"), file) < i32(0) {
            return i32(-1);
        }
    } else {
        if PyFile_WriteObject(qualname, file, Py_PRINT_RAW) < i32(0) {
            object_decref(qualname);
            return i32(-1);
        }
        object_decref(qualname);
    }
    if exc_value and exc_value != Py_None {
        if PyFile_WriteString(ptr[u8](": "), file) < i32(0) {
            return i32(-1);
        }
        if PyFile_WriteObject(exc_value, file, Py_PRINT_RAW) < i32(0) {
            _PyErr_Clear(tstate);
            if PyFile_WriteString(ptr[u8]("<exception str() failed>"), file) < i32(0) {
                return i32(-1);
            }
        }
    }
    if PyFile_WriteString(ptr[u8]("\n"), file) < i32(0) {
        return i32(-1);
    }

    if _PyFile_Flush(file) < i32(0) {
        return i32(-1);
    }
    return i32(0);
}

impl write_unraisable_exc(
    tstate: ptr[PyThreadState],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject],
    err_msg: ptr[PyObject],
    obj_: ptr[PyObject]
) -> i32 {
    file = NULL;
    if _PySys_GetOptionalAttr(py_id(_Py_ID_stderr), &mut file) < i32(0) {
        return i32(-1);
    }
    if not file or file == Py_None {
        object_xdecref(file);
        return i32(0);
    }
    res = write_unraisable_exc_file(
        tstate, exc_type, exc_value, exc_tb, err_msg, obj_, file
    );
    object_decref(file);
    return res;
}

impl unraisable_fetch(
    tstate: ptr[PyThreadState]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]] {
    (exc_type, exc_value, exc_tb) = fetch(tstate);
    if not exc_type {
        return (exc_type, exc_value, exc_tb);
    }
    if not exc_tb {
        frame = PyThreadState_GetFrame(tstate);
        if frame {
            exc_tb = _PyTraceBack_FromFrame(NULL, frame);
            if not exc_tb {
                _PyErr_Clear(tstate);
            }
            object_decref(frame);
        }
    }
    (exc_type, exc_value, exc_tb) = normalize_exception(
        tstate, exc_type, exc_value, exc_tb
    );
    if exc_tb
        and exc_tb != Py_None
        and object_is_type(exc_tb, ptr[PyTypeObject](addressof(PyTraceBack_Type))) {
        if PyException_SetTraceback(exc_value, exc_tb) < i32(0) {
            _PyErr_Clear(tstate);
        }
    }
    return (exc_type, exc_value, exc_tb);
}

impl unraisable_report(
    tstate: ptr[PyThreadState],
    exc_type_in: ptr[PyObject],
    exc_value_in: ptr[PyObject],
    exc_tb_in: ptr[PyObject],
    err_msg_in: ptr[PyObject],
    obj_in: ptr[PyObject]
) {
    exc_type = exc_type_in;
    exc_value = exc_value_in;
    exc_tb = exc_tb_in;
    err_msg = err_msg_in;
    obj_ = obj_in;
    hook = NULL;

    target = 0;
    err_msg_str = ptr[u8]();
    if not exc_type {
        target = 1;
    } else {
        hook_args = make_unraisable_hook_args(
            tstate, exc_type, exc_value, exc_tb, err_msg, obj_
        );
        if not hook_args {
            err_msg_str = ptr[u8](
                "Exception ignored while building sys.unraisablehook arguments"
            );
            target = 2;
        } elif _PySys_GetOptionalAttr(py_id(_Py_ID_unraisablehook), &mut hook)
            < i32(0) {
            object_decref(hook_args);
            err_msg_str = ptr[u8]();
            obj_ = NULL;
            target = 2;
        } elif not hook {
            object_decref(hook_args);
            target = 1;
        } elif _PySys_Audit(
            tstate, ptr[u8]("sys.unraisablehook"), ptr[u8]("OO"), hook, hook_args
        )
            < i32(0) {
            object_decref(hook_args);
            err_msg_str = ptr[u8]("Exception ignored in audit hook");
            obj_ = NULL;
            target = 2;
        } elif hook == Py_None {
            object_decref(hook_args);
            target = 1;
        } else {
            res = PyObject_CallOneArg(hook, hook_args);
            object_decref(hook_args);
            if res {
                object_decref(res);
                target = 0;
            } else {
                obj_ = hook;
                err_msg_str = ptr[u8]();
                target = 2;
            }
        }
    }
    if target == 2 {
        old_msg = err_msg;
        if err_msg_str {
            err_msg = PyUnicode_FromString(err_msg_str);
        } else {
            err_msg = PyUnicode_FromString(
                ptr[u8]("Exception ignored in sys.unraisablehook")
            );
        }
        object_xdecref(old_msg);
        object_xdecref(exc_type);
        object_xdecref(exc_value);
        object_xdecref(exc_tb);
        (exc_type, exc_value, exc_tb) = fetch(tstate);
        target = 1;
    }
    if target == 1 {
        write_unraisable_exc(tstate, exc_type, exc_value, exc_tb, err_msg, obj_);
    }
    object_xdecref(exc_type);
    object_xdecref(exc_value);
    object_xdecref(exc_tb);
    object_xdecref(err_msg);
    object_xdecref(hook);

    _PyErr_Clear(tstate);
}

impl ensure_tstate_not_null(func: ptr[u8], tstate: ptr[PyThreadState]) {
    if not tstate {
        _Py_FatalErrorFunc(
            func,
            ptr[u8](
                "the function must be called with the GIL held, after Python initialization and before Python finalization, but the GIL is released (the current Python thread state is NULL)"
            )
        );
    }
}

impl PyErr_SyntaxLocationObjectEx(
    filename: ptr[PyObject],
    lineno: i32,
    col_offset: i32,
    end_lineno: i32,
    end_col_offset: i32
) {
    tstate = thread_state();

    exc = _PyErr_GetRaisedException(tstate);
    tmp = PyLong_FromLong(i64(lineno));
    if not tmp {
        _PyErr_Clear(tstate);
    } else {
        if PyObject_SetAttr(exc, py_id(_Py_ID_lineno), tmp) != i32(0) {
            _PyErr_Clear(tstate);
        }
        object_decref(tmp);
    }
    set_location_attr(tstate, exc, py_id(_Py_ID_offset), col_offset);
    set_location_attr(tstate, exc, py_id(_Py_ID_end_lineno), end_lineno);
    set_location_attr(tstate, exc, py_id(_Py_ID_end_offset), end_col_offset);
    if filename {
        if PyObject_SetAttr(exc, py_id(_Py_ID_filename), filename) != i32(0) {
            _PyErr_Clear(tstate);
        }
        text = PyErr_ProgramTextObject(filename, lineno);
        if text {
            if PyObject_SetAttr(exc, py_id(_Py_ID_text), text) != i32(0) {
                _PyErr_Clear(tstate);
            }
            object_decref(text);
        } else {
            _PyErr_Clear(tstate);
        }
    }
    if exception_instance_class(exc) != PyExc_SyntaxError {
        rc = PyObject_HasAttrWithError(exc, py_id(_Py_ID_msg));
        if rc < i32(0) {
            _PyErr_Clear(tstate);
        } elif rc == i32(0) {
            text = PyObject_Str(exc);
            if text {
                if PyObject_SetAttr(exc, py_id(_Py_ID_msg), text) != i32(0) {
                    _PyErr_Clear(tstate);
                }
                object_decref(text);
            } else {
                _PyErr_Clear(tstate);
            }
        }
        rc = PyObject_HasAttrWithError(exc, py_id(_Py_ID_print_file_and_line));
        if rc < i32(0) {
            _PyErr_Clear(tstate);
        } elif rc == i32(0) {
            if PyObject_SetAttr(exc, py_id(_Py_ID_print_file_and_line), Py_None)
                != i32(0) {
                _PyErr_Clear(tstate);
            }
        }
    }
    _PyErr_SetRaisedException(tstate, exc);
}

impl set_location_attr(
    tstate: ptr[PyThreadState], exc: ptr[PyObject], name: ptr[PyObject], value: i32
) {
    tmp = NULL;
    if value >= i32(0) {
        tmp = PyLong_FromLong(i64(value));
        if not tmp {
            _PyErr_Clear(tstate);
        }
    }
    if PyObject_SetAttr(exc, name, tmp or Py_None) != i32(0) {
        _PyErr_Clear(tstate);
    }
    object_xdecref(tmp);
}

impl err_programtext(fp: ptr[FILE], lineno: i32, encoding: ptr[u8]) -> ptr[PyObject] {
    block = ptr[u8](PyMem_Malloc(u64(ERR_PROGRAMTEXT_LINEBUF + 8)));
    if not block {
        return NULL;
    }
    linebuf = block;
    line_size_slot = ptr[u64](block + ERR_PROGRAMTEXT_LINEBUF);
    line_size_slot.view(1)[0] = u64(0);
    i = i32(0);
    while i < lineno {
        line_size_slot.view(1)[0] = u64(0);
        if not _Py_UniversalNewlineFgetsWithSize(
            linebuf, i32(ERR_PROGRAMTEXT_LINEBUF), fp, NULL, line_size_slot
        ) {
            PyMem_Free(ptr(block));
            return NULL;
        }

        if i + i32(1) < lineno
            and line_size_slot.view(1)[0] == u64(ERR_PROGRAMTEXT_LINEBUF - 1)
            and linebuf.view(ERR_PROGRAMTEXT_LINEBUF)[ERR_PROGRAMTEXT_LINEBUF - 2]
                != u8(10) {
            continue;
        }
        i += i32(1);
    }
    line = linebuf;
    line_size = line_size_slot.view(1)[0];

    if lineno == i32(1)
        and line_size >= u64(3)
        and line.view(3)[0] == u8(0xEF)
        and line.view(3)[1] == u8(0xBB)
        and line.view(3)[2] == u8(0xBF) {
        line = line + 3;
        line_size = line_size - u64(3);
    }
    res = PyUnicode_Decode(line, i64(line_size), encoding, ptr[u8]("replace"));
    if not res {
        PyErr_Clear();
    }
    PyMem_Free(ptr(block));
    return res;
}
