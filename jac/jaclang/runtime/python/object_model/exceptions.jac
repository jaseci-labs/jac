import from c {
    def _PyStaticType_InitBuiltin(interp: ptr, type: ptr[PyTypeObject]) -> i32;  def _PyStaticType_FiniBuiltin(
        interp: ptr, type: ptr[PyTypeObject]
    );  def _PyErr_SetRaisedException(tstate: ptr, exc: ptr[PyObject]);  def _Py_NewReference(
        op: ptr[PyObject]
    );  def _PyTuple_FromArray(src: ptr[ptr[PyObject]], n: i64) -> ptr[PyObject];  def _PyArg_BadArgument(
        fname: ptr[u8], displayname: ptr[u8], expected: ptr[u8], arg: ptr[PyObject]
    );  def PyObject_GenericGetDict(ob: ptr[PyObject], context: ptr) -> ptr[PyObject];  def PyObject_GenericSetDict(
        ob: ptr[PyObject], value: ptr[PyObject], context: ptr
    ) -> i32;  obj ExcCall {
        has alloc: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            free: Callable[[ptr], None] = 0;
    }  glob:priv notes_key: ptr[PyObject] = ptr[PyObject](),
         import_error_keywords: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("path"),
             ptr[u8]("name_from"),
             ptr[u8]()
         ],
         name_error_keywords: list[ptr[u8]] = [ptr[u8]("name"), ptr[u8]()],
         attribute_error_keywords: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("obj"),
             ptr[u8]()
         ];
}


def base_of(op: ptr[PyObject]) -> ptr[PyBaseExceptionObject];

def exc_args(op: ptr[PyObject]) -> ptr[PyObject];

def base_store(op: ptr[PyObject], which: int, value: ptr[PyObject]);

def base_field(op: ptr[PyObject], which: int) -> ptr[PyObject];

def type_alloc(type: ptr[PyObject]) -> ptr[PyObject];

def type_free(op: ptr[PyObject]);

def base_init_fields(op: ptr[PyObject], args: ptr[PyObject]);

def BaseException_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def BaseException_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def BaseException_vectorcall(
    type_obj: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def BaseException_clear(op: ptr[PyObject]) -> i32;

def BaseException_dealloc(op: ptr[PyObject]);

def BaseException_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def BaseException_str(op: ptr[PyObject]) -> ptr[PyObject];

def BaseException_repr(op: ptr[PyObject]) -> ptr[PyObject];

def BaseException___reduce__(
    op: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def BaseException___setstate__(
    op: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject];

def BaseException_with_traceback(
    op: ptr[PyObject], tb: ptr[PyObject]
) -> ptr[PyObject];

def BaseException_add_note(op: ptr[PyObject], note: ptr[PyObject]) -> ptr[PyObject];

def interned_notes -> ptr[PyObject];

def BaseException_args_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def BaseException_args_set(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def BaseException___traceback___get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def traceback_set(op: ptr[PyObject], value: ptr[PyObject]) -> i32;

def BaseException___traceback___set(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def exception_instance_check(op: ptr[PyObject]) -> bool;

def BaseException___context___get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def BaseException___context___set(
    op: ptr[PyObject], value_in: ptr[PyObject], _closure: ptr
) -> i32;

def BaseException___cause___get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def BaseException___cause___set(
    op: ptr[PyObject], value_in: ptr[PyObject], _closure: ptr
) -> i32;

import from c {
    def PyException_GetTraceback(self: ptr[PyObject]) -> ptr[PyObject] {
        return object_xnew_ref(base_field(self, 3));
    }  def PyException_SetTraceback(self: ptr[PyObject], tb: ptr[PyObject]) -> i32 {
        return traceback_set(self, tb);
    }  def PyException_GetCause(self: ptr[PyObject]) -> ptr[PyObject] {
        return object_xnew_ref(base_field(self, 5));
    }  def PyException_SetCause(self: ptr[PyObject], cause: ptr[PyObject]) {
        base_of(self).view(1)[0].suppress_context = i8(1);
        base_store(self, 5, cause);
    }  def PyException_GetContext(self: ptr[PyObject]) -> ptr[PyObject] {
        return object_xnew_ref(base_field(self, 4));
    }  def PyException_SetContext(self: ptr[PyObject], context: ptr[PyObject]) {
        base_store(self, 4, context);
    }  def PyException_GetArgs(self: ptr[PyObject]) -> ptr[PyObject] {
        return object_new_ref(exc_args(self));
    }  def PyException_SetArgs(self: ptr[PyObject], args: ptr[PyObject]) {
        base_store(self, 1, object_new_ref(args));
    }  def PyExceptionClass_Name(ob: ptr[PyObject]) -> ptr[u8] {
        return ptr[PyTypeObject](ob).view(1)[0].tp_name;
    }
}

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];


def exc_field(op: ptr[PyObject], offset: i64) -> ptr[PyObject];

def set_exc_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def replace_exc_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def exc_dealloc(op: ptr[PyObject], clear: Callable[[ptr[PyObject]], i32]);

def exc_traverse(op: ptr[PyObject], offsets: list[i64], visitor: ptr, arg: ptr) -> i32;

def StopIteration_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def StopIteration_clear(op: ptr[PyObject]) -> i32;

def StopIteration_dealloc(op: ptr[PyObject]);

def StopIteration_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def SystemExit_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def SystemExit_clear(op: ptr[PyObject]) -> i32;

def SystemExit_dealloc(op: ptr[PyObject]);

def SystemExit_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

glob:priv MATCH_BY_TYPE: i32 = 0,
     MATCH_BY_PREDICATE: i32 = 1,
     MATCH_INSTANCE_IDS: i32 = 2;

def exception_group_slot -> ptr[ptr[PyObject]];

def is_base_exception_group(op: ptr[PyObject]) -> bool;

def eg_excs(op: ptr[PyObject]) -> ptr[PyObject];

def BaseExceptionGroup_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def BaseExceptionGroup_init(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def BaseExceptionGroup_clear(op: ptr[PyObject]) -> i32;

def BaseExceptionGroup_dealloc(op: ptr[PyObject]);

def BaseExceptionGroup_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def BaseExceptionGroup_str(op: ptr[PyObject]) -> ptr[PyObject];

def BaseExceptionGroup_repr(op: ptr[PyObject]) -> ptr[PyObject];

def BaseExceptionGroup_derive(
    self: ptr[PyObject], excs: ptr[PyObject]
) -> ptr[PyObject];

def exceptiongroup_subset(
    orig: ptr[PyObject], excs: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def exception_class_check(op: ptr[PyObject]) -> bool;

def get_matcher_type(value: ptr[PyObject]) -> i32;

def split_check_match(
    exc: ptr[PyObject], matcher_type: i32, matcher_value: ptr[PyObject]
) -> i32;

def split_recursive(
    exc: ptr[PyObject],
    matcher_type: i32,
    matcher_value: ptr[PyObject],
    construct_rest: bool
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def BaseExceptionGroup_split(
    self: ptr[PyObject], matcher_value: ptr[PyObject]
) -> ptr[PyObject];

def BaseExceptionGroup_subgroup(
    self: ptr[PyObject], matcher_value: ptr[PyObject]
) -> ptr[PyObject];

def collect_leaf_ids(exc: ptr[PyObject], leaf_ids: ptr[PyObject]) -> i32;

def exception_group_projection(
    eg: ptr[PyObject], keep: ptr[PyObject]
) -> ptr[PyObject];

def is_same_exception_metadata(exc1: ptr[PyObject], exc2: ptr[PyObject]) -> bool;

import from c {
    def _PyExc_CreateExceptionGroup(
        msg_str: ptr[u8], excs: ptr[PyObject]
    ) -> ptr[PyObject] {
        msg = PyUnicode_FromString(msg_str);
        if not msg {
            return NULL;
        }
        args = PyTuple_Pack(2, msg, excs);
        object_decref(msg);
        if not args {
            return NULL;
        }
        result = PyObject_CallObject(PyExc_BaseExceptionGroup, args);
        object_decref(args);
        return result;
    }  def _PyExc_PrepReraiseStar(
        orig: ptr[PyObject], excs: ptr[PyObject]
    ) -> ptr[PyObject] {
        numexcs = object_size(excs);
        if numexcs == 0 {
            return object_new_ref(Py_None);
        }
        if not is_base_exception_group(orig) {
            return object_new_ref(PyList_GetItem(excs, 0));
        }
        raised_list = PyList_New(0);
        if not raised_list {
            return NULL;
        }
        reraised_list = PyList_New(0);
        if not reraised_list {
            object_decref(raised_list);
            return NULL;
        }
        result: ptr[PyObject] = NULL;
        failed = False;
        for i in range(numexcs) {
            e = PyList_GetItem(excs, i);
            if e == Py_None {
                continue;
            }
            target = reraised_list
                if is_same_exception_metadata(e, orig)
                else raised_list;
            if PyList_Append(target, e) < 0 {
                failed = True;
                break;
            }
        }
        if not failed {
            reraised_eg = exception_group_projection(orig, reraised_list);
            if reraised_eg {
                num_raised = object_size(raised_list);
                if num_raised == 0 {
                    result = reraised_eg;
                } else {
                    res = i32(0);
                    if reraised_eg != Py_None {
                        res = PyList_Append(raised_list, reraised_eg);
                    }
                    object_decref(reraised_eg);
                    if res >= 0 {
                        if object_size(raised_list) > 1 {
                            result = _PyExc_CreateExceptionGroup(
                                ptr[u8](""), raised_list
                            );
                        } else {
                            result = object_new_ref(PyList_GetItem(raised_list, 0));
                        }
                    }
                }
            }
        }
        object_decref(raised_list);
        object_decref(reraised_list);
        return result;
    }  def PyUnstable_Exc_PrepReraiseStar(
        orig: ptr[PyObject], excs: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not orig or not exception_instance_check(orig) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("orig must be an exception instance")
            );
            return NULL;
        }
        if not excs
            or not type_has_feature(object_type(excs), Py_TPFLAGS_LIST_SUBCLASS) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("excs must be a list of exception instances")
            );
            return NULL;
        }
        for i in range(object_size(excs)) {
            exc = PyList_GetItem(excs, i);
            if not exc or not (exception_instance_check(exc) or exc == Py_None) {
                PyErr_Format(
                    PyExc_TypeError, ptr[u8]("item %zd of excs is not an exception"), i
                );
                return NULL;
            }
        }

        tb = PyException_GetTraceback(orig);
        if not tb {
            PyErr_Format(PyExc_ValueError, ptr[u8]("orig must be a raised exception"));
            return NULL;
        }
        object_decref(tb);
        return _PyExc_PrepReraiseStar(orig, excs);
    }
}

def create_exception_group_class -> ptr[PyObject];


def ImportError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def ImportError_clear(op: ptr[PyObject]) -> i32;

def ImportError_dealloc(op: ptr[PyObject]);

def ImportError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def ImportError_str(op: ptr[PyObject]) -> ptr[PyObject];

def ImportError_getstate(op: ptr[PyObject]) -> ptr[PyObject];

def ImportError_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def os_of(op: ptr[PyObject]) -> ptr[PyOSErrorObject];

def oserror_parse_args(
    args: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[PyObject], ptr[PyObject]];

def oserror_init(
    op: ptr[PyObject],
    args_in: ptr[PyObject],
    myerrno: ptr[PyObject],
    strerror: ptr[PyObject],
    filename: ptr[PyObject],
    filename2: ptr[PyObject]
) -> i32;

def oserror_use_init(type: ptr[PyTypeObject]) -> bool;

def errnomap -> ptr[PyObject];

def OSError_new(
    type_in: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def OSError_init(op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def os_field(op: ptr[PyObject], which: int) -> ptr[PyObject];

def OSError_clear(op: ptr[PyObject]) -> i32;

def OSError_dealloc(op: ptr[PyObject]);

def OSError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def or_none(op: ptr[PyObject]) -> ptr[PyObject];

def OSError_str(op: ptr[PyObject]) -> ptr[PyObject];

def OSError_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def OSError_written_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def OSError_written_set(op: ptr[PyObject], arg: ptr[PyObject], _closure: ptr) -> i32;


def NameError_init(op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def NameError_clear(op: ptr[PyObject]) -> i32;

def NameError_dealloc(op: ptr[PyObject]);

def NameError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def AttributeError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def AttributeError_clear(op: ptr[PyObject]) -> i32;

def AttributeError_dealloc(op: ptr[PyObject]);

def AttributeError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def AttributeError_getstate(
    op: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def AttributeError_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def syntax_fields -> list[i64];

def SyntaxError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def SyntaxError_clear(op: ptr[PyObject]) -> i32;

def SyntaxError_dealloc(op: ptr[PyObject]);

def SyntaxError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def my_basename(name: ptr[PyObject]) -> ptr[PyObject];

def SyntaxError_str(op: ptr[PyObject]) -> ptr[PyObject];

def KeyError_str(op: ptr[PyObject]) -> ptr[PyObject];


def uerr_of(op: ptr[PyObject]) -> ptr[PyUnicodeErrorObject];

def uerr_encoding(op: ptr[PyObject]) -> ptr[PyObject];

def uerr_object(op: ptr[PyObject]) -> ptr[PyObject];

def uerr_reason(op: ptr[PyObject]) -> ptr[PyObject];

def uerr_store(op: ptr[PyObject], which: int, value: ptr[PyObject]);

def check_unicode_error_attribute(
    attr: ptr[PyObject], name: str, as_bytes: bool
) -> i32;

def as_unicode_error_attribute(
    attr: ptr[PyObject], name: str, as_bytes: bool
) -> ptr[PyObject];

def check_unicode_error_type(op: ptr[PyObject], expect_type: str) -> i32;

def unicode_error_adjust_start(start_in: i64, objlen: i64) -> i64;

def unicode_error_adjust_end(end_in: i64, objlen: i64) -> i64;

def unicode_error_params(
    op: ptr[PyObject], as_bytes: bool
) -> tuple[i32, ptr[PyObject], i64, i64, i64, i64];

def store_i64(target: ptr[i64], value: i64);

def unicode_error_get_start(op: ptr[PyObject], start: ptr[i64], as_bytes: bool) -> i32;

def unicode_error_get_end(op: ptr[PyObject], end: ptr[i64], as_bytes: bool) -> i32;

def unicode_error_set_reason(op: ptr[PyObject], reason: ptr[u8]) -> i32;

import from c {
    def _PyUnicodeError_GetParams(
        self: ptr[PyObject],
        ob: ptr[ptr[PyObject]],
        objlen: ptr[i64],
        start: ptr[i64],
        end: ptr[i64],
        slen: ptr[i64],
        as_bytes: i32
    ) -> i32 {
        (status, r, n, s, e, length) = unicode_error_params(self, as_bytes != 0);
        if status < 0 {
            return i32(-1);
        }
        store_i64(objlen, n);
        store_i64(start, s);
        store_i64(end, e);
        store_i64(slen, length);
        if ob {
            ob.view(1)[0] = r;
        } else {
            object_decref(r);
        }
        return i32(0);
    }  def PyUnicodeEncodeError_GetEncoding(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_encoding(self), "encoding", False);
    }  def PyUnicodeDecodeError_GetEncoding(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_encoding(self), "encoding", False);
    }  def PyUnicodeEncodeError_GetObject(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_object(self), "object", False);
    }  def PyUnicodeDecodeError_GetObject(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_object(self), "object", True);
    }  def PyUnicodeTranslateError_GetObject(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_object(self), "object", False);
    }  def PyUnicodeEncodeError_GetStart(self: ptr[PyObject], start: ptr[i64]) -> i32 {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return i32(-1);
        }
        return unicode_error_get_start(self, start, False);
    }  def PyUnicodeDecodeError_GetStart(self: ptr[PyObject], start: ptr[i64]) -> i32 {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return i32(-1);
        }
        return unicode_error_get_start(self, start, True);
    }  def PyUnicodeTranslateError_GetStart(
        self: ptr[PyObject], start: ptr[i64]
    ) -> i32 {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return i32(-1);
        }
        return unicode_error_get_start(self, start, False);
    }  def PyUnicodeEncodeError_SetStart(self: ptr[PyObject], start: i64) -> i32 {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return i32(-1);
        }
        uerr_of(self).view(1)[0].start = start;
        return i32(0);
    }  def PyUnicodeDecodeError_SetStart(self: ptr[PyObject], start: i64) -> i32 {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return i32(-1);
        }
        uerr_of(self).view(1)[0].start = start;
        return i32(0);
    }  def PyUnicodeTranslateError_SetStart(self: ptr[PyObject], start: i64) -> i32 {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return i32(-1);
        }
        uerr_of(self).view(1)[0].start = start;
        return i32(0);
    }  def PyUnicodeEncodeError_GetEnd(self: ptr[PyObject], end: ptr[i64]) -> i32 {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return i32(-1);
        }
        return unicode_error_get_end(self, end, False);
    }  def PyUnicodeDecodeError_GetEnd(self: ptr[PyObject], end: ptr[i64]) -> i32 {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return i32(-1);
        }
        return unicode_error_get_end(self, end, True);
    }  def PyUnicodeTranslateError_GetEnd(self: ptr[PyObject], end: ptr[i64]) -> i32 {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return i32(-1);
        }
        return unicode_error_get_end(self, end, False);
    }  def PyUnicodeEncodeError_SetEnd(self: ptr[PyObject], end: i64) -> i32 {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return i32(-1);
        }
        uerr_of(self).view(1)[0].end = end;
        return i32(0);
    }  def PyUnicodeDecodeError_SetEnd(self: ptr[PyObject], end: i64) -> i32 {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return i32(-1);
        }
        uerr_of(self).view(1)[0].end = end;
        return i32(0);
    }  def PyUnicodeTranslateError_SetEnd(self: ptr[PyObject], end: i64) -> i32 {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return i32(-1);
        }
        uerr_of(self).view(1)[0].end = end;
        return i32(0);
    }  def PyUnicodeEncodeError_GetReason(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_reason(self), "reason", False);
    }  def PyUnicodeDecodeError_GetReason(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_reason(self), "reason", False);
    }  def PyUnicodeTranslateError_GetReason(self: ptr[PyObject]) -> ptr[PyObject] {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return NULL;
        }
        return as_unicode_error_attribute(uerr_reason(self), "reason", False);
    }  def PyUnicodeEncodeError_SetReason(self: ptr[PyObject], reason: ptr[u8]) -> i32 {
        if check_unicode_error_type(self, "UnicodeEncodeError") < 0 {
            return i32(-1);
        }
        return unicode_error_set_reason(self, reason);
    }  def PyUnicodeDecodeError_SetReason(self: ptr[PyObject], reason: ptr[u8]) -> i32 {
        if check_unicode_error_type(self, "UnicodeDecodeError") < 0 {
            return i32(-1);
        }
        return unicode_error_set_reason(self, reason);
    }  def PyUnicodeTranslateError_SetReason(
        self: ptr[PyObject], reason: ptr[u8]
    ) -> i32 {
        if check_unicode_error_type(self, "UnicodeTranslateError") < 0 {
            return i32(-1);
        }
        return unicode_error_set_reason(self, reason);
    }  def PyUnicodeDecodeError_Create(
        encoding: ptr, ob: ptr, length: i64, start: i64, end: i64, reason: ptr[u8]
    ) -> ptr[PyObject] {
        return PyObject_CallFunction(
            PyExc_UnicodeDecodeError, "sy#nns", encoding, ob, length, start, end, reason
        );
    }  def _PyUnicodeTranslateError_Create(
        ob: ptr[PyObject], start: i64, end: i64, reason: ptr[u8]
    ) -> ptr[PyObject] {
        return PyObject_CallFunction(
            PyExc_UnicodeTranslateError, "Onns", ob, start, end, reason
        );
    }
}

def UnicodeError_clear(op: ptr[PyObject]) -> i32;

def UnicodeError_dealloc(op: ptr[PyObject]);

def UnicodeError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def UnicodeEncodeError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def badchar_format(badchar: u32, prefix: str, suffix: str) -> str;

def UnicodeEncodeError_str(op: ptr[PyObject]) -> ptr[PyObject];

def UnicodeDecodeError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def UnicodeDecodeError_str(op: ptr[PyObject]) -> ptr[PyObject];

def UnicodeTranslateError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def UnicodeTranslateError_str(op: ptr[PyObject]) -> ptr[PyObject];


glob:priv MEMERRORS_SAVE: i64 = 16;

def memerrors_freelist_slot -> ptr[ptr[PyObject]];

def memerrors_numfree_slot -> ptr[i32];

def get_memory_error(
    allow_allocation: bool, args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def MemoryError_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def MemoryError_dealloc(op: ptr[PyObject]);

def preallocate_memerrors -> i32;

def free_preallocated_memerrors;

def static_exceptions -> list[tuple[ptr[PyTypeObject], str]];

def status_ok -> PyStatus;

def status_err(func: ptr[u8], msg: ptr[u8]) -> PyStatus;

def add_errno(mapping: ptr[PyObject], type: ptr[PyObject], code: i64) -> bool;

import from c {
    def _PyErr_NoMemory(tstate: ptr) -> ptr[PyObject] {
        if not object_type(PyExc_MemoryError) {
            Py_FatalError(ptr[u8]("Out of memory and PyExc_MemoryError is not initialized yet"));
        }
        err = get_memory_error(False, NULL, NULL);
        if err {
            _PyErr_SetRaisedException(tstate, err);
        }
        return NULL;
    }  def _PyExc_InitTypes(interp: ptr) -> i32 {
        for (exc, name) in static_exceptions() {
            if _PyStaticType_InitBuiltin(interp, exc) < 0 {
                return i32(-1);
            }
            if int(exc.view(1)[0].tp_new) == int(ptr(BaseException_new))
                and int(exc.view(1)[0].tp_init) == int(ptr(BaseException_init)) {
                exc.view(1)[0].tp_vectorcall = BaseException_vectorcall;
            }
        }
        return i32(0);
    }  def _PyExc_InitGlobalObjects(interp: ptr) -> PyStatus {
        if preallocate_memerrors() < 0 {
            return status_err(
                ptr[u8]("_PyExc_InitGlobalObjects"), ptr[u8]("memory allocation failed")
            );
        }
        return status_ok();
    }  def _PyExc_InitState(interp: ptr) -> PyStatus {
        mapping = PyDict_New();
        if not mapping {
            return status_err(
                ptr[u8]("_PyExc_InitState"), ptr[u8]("memory allocation failed")
            );
        }
        ptr[ptr[PyObject]](ptr[u8](interp) + PyInterpreterState_EXC_ERRNOMAP).view(1)[
            0
        ] = mapping;
        pairs = [
            (PyExc_BlockingIOError, EAGAIN),
            (PyExc_BlockingIOError, EALREADY),
            (PyExc_BlockingIOError, EINPROGRESS),
            (PyExc_BlockingIOError, EWOULDBLOCK),
            (PyExc_BrokenPipeError, EPIPE),
            (PyExc_BrokenPipeError, ESHUTDOWN),
            (PyExc_ChildProcessError, ECHILD),
            (PyExc_ConnectionAbortedError, ECONNABORTED),
            (PyExc_ConnectionRefusedError, ECONNREFUSED),
            (PyExc_ConnectionResetError, ECONNRESET),
            (PyExc_FileExistsError, EEXIST),
            (PyExc_FileNotFoundError, ENOENT),
            (PyExc_IsADirectoryError, EISDIR),
            (PyExc_NotADirectoryError, ENOTDIR),
            (PyExc_InterruptedError, EINTR),
            (PyExc_PermissionError, EACCES),
            (PyExc_PermissionError, EPERM),
            (PyExc_ProcessLookupError, ESRCH),
            (PyExc_TimeoutError, ETIMEDOUT)
        ];
        for (type, code) in pairs {
            if not add_errno(mapping, type, i64(code)) {
                return status_err(
                    ptr[u8]("_PyExc_InitState"), ptr[u8]("errmap insertion problem.")
                );
            }
        }
        return status_ok();
    }  def _PyBuiltins_AddExceptions(bltinmod: ptr[PyObject]) -> i32 {
        mod_dict = PyModule_GetDict(bltinmod);
        if not mod_dict {
            return i32(-1);
        }
        for (exc, name) in static_exceptions() {
            key = jacpy_unicode_intern_text(name);
            if not key {
                return i32(-1);
            }
            status = PyDict_SetItem(mod_dict, key, ptr[PyObject](exc));
            object_decref(key);
            if status != 0 {
                return i32(-1);
            }
        }
        group = create_exception_group_class();
        if not group {
            return i32(-1);
        }
        if PyDict_SetItemString(mod_dict, ptr[u8]("ExceptionGroup"), group) != 0 {
            return i32(-1);
        }
        PyExc_EnvironmentError = PyExc_OSError;
        if PyDict_SetItemString(mod_dict, ptr[u8]("EnvironmentError"), PyExc_OSError)
            != 0 {
            return i32(-1);
        }
        PyExc_IOError = PyExc_OSError;
        if PyDict_SetItemString(mod_dict, ptr[u8]("IOError"), PyExc_OSError) != 0 {
            return i32(-1);
        }
        return i32(0);
    }  def _PyExc_ClearExceptionGroupType(interp: ptr) {
        slot = ptr[ptr[PyObject]](ptr[u8](interp) + PyInterpreterState_EXC_GROUP);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
    }  def _PyExc_Fini(interp: ptr) {
        free_preallocated_memerrors();
        slot = ptr[ptr[PyObject]](ptr[u8](interp) + PyInterpreterState_EXC_ERRNOMAP);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
        exceptions = static_exceptions();
        i = len(exceptions) - 1;
        while i >= 0 {
            (exc, name) = exceptions[i];
            _PyStaticType_FiniBuiltin(interp, exc);
            i -= 1;
        }
    }  def _PyException_AddNote(exc: ptr[PyObject], note: ptr[PyObject]) -> i32 {
        if not exception_instance_check(exc) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("exc must be an exception, not '%s'"),
                object_type(exc).view(1)[0].tp_name
            );
            return i32(-1);
        }
        r = BaseException_add_note(exc, note);
        res = i32(-1) if not r else i32(0);
        object_xdecref(r);
        return res;
    }
}

import from c {
    glob:priv BaseException_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(BaseException___reduce__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(BaseException___setstate__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("__setstate__($self, state, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("with_traceback"),
                 ml_meth=ptr(BaseException_with_traceback),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "with_traceback($self, tb, /)\n--\n\nSet self.__traceback__ to tb and return self."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("add_note"),
                 ml_meth=ptr(BaseException_add_note),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "add_note($self, note, /)\n--\n\nAdd a note to the exception"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         BaseException_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__suppress_context__"),
                 type_=Py_T_BOOL,
                 offset=PyBaseExceptionObject_SUPPRESS_CONTEXT,
                 flags=0,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         BaseException_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef(
                 name=ptr[u8]("args"),
                 get=BaseException_args_get,
                 set=BaseException_args_set
             ),
             PyGetSetDef(
                 name=ptr[u8]("__traceback__"),
                 get=BaseException___traceback___get,
                 set=BaseException___traceback___set
             ),
             PyGetSetDef(
                 name=ptr[u8]("__context__"),
                 get=BaseException___context___get,
                 set=BaseException___context___set
             ),
             PyGetSetDef(
                 name=ptr[u8]("__cause__"),
                 get=BaseException___cause___get,
                 set=BaseException___cause___set
             ),
             PyGetSetDef()
         ],
         StopIteration_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("value"),
                 type_=_Py_T_OBJECT,
                 offset=PyStopIterationObject_VALUE,
                 flags=0,
                 doc=ptr[u8]("generator return value")
             ),
             PyMemberDef()
         ],
         SystemExit_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("code"),
                 type_=_Py_T_OBJECT,
                 offset=PySystemExitObject_CODE,
                 flags=0,
                 doc=ptr[u8]("exception code")
             ),
             PyMemberDef()
         ],
         BaseExceptionGroup_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("message"),
                 type_=_Py_T_OBJECT,
                 offset=PyBaseExceptionGroupObject_MSG,
                 flags=Py_READONLY,
                 doc=ptr[u8]("exception message")
             ),
             PyMemberDef(
                 name=ptr[u8]("exceptions"),
                 type_=_Py_T_OBJECT,
                 offset=PyBaseExceptionGroupObject_EXCS,
                 flags=Py_READONLY,
                 doc=ptr[u8]("nested exceptions")
             ),
             PyMemberDef()
         ],
         BaseExceptionGroup_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "Exception groups are generic over the type of their contained exceptions"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("derive"),
                 ml_meth=ptr(BaseExceptionGroup_derive),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("derive($self, excs, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("split"),
                 ml_meth=ptr(BaseExceptionGroup_split),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("split($self, matcher_value, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("subgroup"),
                 ml_meth=ptr(BaseExceptionGroup_subgroup),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("subgroup($self, matcher_value, /)\n--\n\n")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         ImportError_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("msg"),
                 type_=_Py_T_OBJECT,
                 offset=PyImportErrorObject_MSG,
                 flags=0,
                 doc=ptr[u8]("exception message")
             ),
             PyMemberDef(
                 name=ptr[u8]("name"),
                 type_=_Py_T_OBJECT,
                 offset=PyImportErrorObject_NAME,
                 flags=0,
                 doc=ptr[u8]("module name")
             ),
             PyMemberDef(
                 name=ptr[u8]("path"),
                 type_=_Py_T_OBJECT,
                 offset=PyImportErrorObject_PATH,
                 flags=0,
                 doc=ptr[u8]("module path")
             ),
             PyMemberDef(
                 name=ptr[u8]("name_from"),
                 type_=_Py_T_OBJECT,
                 offset=PyImportErrorObject_NAME_FROM,
                 flags=0,
                 doc=ptr[u8]("name imported from module")
             ),
             PyMemberDef()
         ],
         ImportError_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(ImportError_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         OSError_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("errno"),
                 type_=_Py_T_OBJECT,
                 offset=PyOSErrorObject_MYERRNO,
                 flags=0,
                 doc=ptr[u8]("POSIX exception code")
             ),
             PyMemberDef(
                 name=ptr[u8]("strerror"),
                 type_=_Py_T_OBJECT,
                 offset=PyOSErrorObject_STRERROR,
                 flags=0,
                 doc=ptr[u8]("exception strerror")
             ),
             PyMemberDef(
                 name=ptr[u8]("filename"),
                 type_=_Py_T_OBJECT,
                 offset=PyOSErrorObject_FILENAME,
                 flags=0,
                 doc=ptr[u8]("exception filename")
             ),
             PyMemberDef(
                 name=ptr[u8]("filename2"),
                 type_=_Py_T_OBJECT,
                 offset=PyOSErrorObject_FILENAME2,
                 flags=0,
                 doc=ptr[u8]("second exception filename")
             ),
             PyMemberDef()
         ],
         OSError_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(OSError_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         OSError_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("characters_written"),
                 get=OSError_written_get,
                 set=OSError_written_set
             ),
             PyGetSetDef()
         ],
         NameError_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("name"),
                 type_=_Py_T_OBJECT,
                 offset=PyNameErrorObject_NAME,
                 flags=0,
                 doc=ptr[u8]("name")
             ),
             PyMemberDef()
         ],
         NameError_methods: list[PyMethodDef] = [
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         AttributeError_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("name"),
                 type_=_Py_T_OBJECT,
                 offset=PyAttributeErrorObject_NAME,
                 flags=0,
                 doc=ptr[u8]("attribute name")
             ),
             PyMemberDef(
                 name=ptr[u8]("obj"),
                 type_=_Py_T_OBJECT,
                 offset=PyAttributeErrorObject_OBJ,
                 flags=0,
                 doc=ptr[u8]("object")
             ),
             PyMemberDef()
         ],
         AttributeError_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__getstate__"),
                 ml_meth=ptr(AttributeError_getstate),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(AttributeError_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         SyntaxError_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("msg"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_MSG,
                 flags=0,
                 doc=ptr[u8]("exception msg")
             ),
             PyMemberDef(
                 name=ptr[u8]("filename"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_FILENAME,
                 flags=0,
                 doc=ptr[u8]("exception filename")
             ),
             PyMemberDef(
                 name=ptr[u8]("lineno"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_LINENO,
                 flags=0,
                 doc=ptr[u8]("exception lineno")
             ),
             PyMemberDef(
                 name=ptr[u8]("offset"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_OFFSET,
                 flags=0,
                 doc=ptr[u8]("exception offset")
             ),
             PyMemberDef(
                 name=ptr[u8]("text"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_TEXT,
                 flags=0,
                 doc=ptr[u8]("exception text")
             ),
             PyMemberDef(
                 name=ptr[u8]("end_lineno"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_END_LINENO,
                 flags=0,
                 doc=ptr[u8]("exception end lineno")
             ),
             PyMemberDef(
                 name=ptr[u8]("end_offset"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_END_OFFSET,
                 flags=0,
                 doc=ptr[u8]("exception end offset")
             ),
             PyMemberDef(
                 name=ptr[u8]("print_file_and_line"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_PRINT_FILE_AND_LINE,
                 flags=0,
                 doc=ptr[u8]("exception print_file_and_line")
             ),
             PyMemberDef(
                 name=ptr[u8]("_metadata"),
                 type_=_Py_T_OBJECT,
                 offset=PySyntaxErrorObject_METADATA,
                 flags=0,
                 doc=ptr[u8]("exception private metadata")
             ),
             PyMemberDef()
         ],
         UnicodeError_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("encoding"),
                 type_=_Py_T_OBJECT,
                 offset=PyUnicodeErrorObject_ENCODING,
                 flags=0,
                 doc=ptr[u8]("exception encoding")
             ),
             PyMemberDef(
                 name=ptr[u8]("object"),
                 type_=_Py_T_OBJECT,
                 offset=PyUnicodeErrorObject_OBJECT,
                 flags=0,
                 doc=ptr[u8]("exception object")
             ),
             PyMemberDef(
                 name=ptr[u8]("start"),
                 type_=Py_T_PYSSIZET,
                 offset=PyUnicodeErrorObject_START,
                 flags=0,
                 doc=ptr[u8]("exception start")
             ),
             PyMemberDef(
                 name=ptr[u8]("end"),
                 type_=Py_T_PYSSIZET,
                 offset=PyUnicodeErrorObject_END,
                 flags=0,
                 doc=ptr[u8]("exception end")
             ),
             PyMemberDef(
                 name=ptr[u8]("reason"),
                 type_=_Py_T_OBJECT,
                 offset=PyUnicodeErrorObject_REASON,
                 flags=0,
                 doc=ptr[u8]("exception reason")
             ),
             PyMemberDef()
         ]; glob _PyExc_BaseException: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("BaseException"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_repr=BaseException_repr,
             tp_str=BaseException_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_BASE_EXC_SUBCLASS,
             tp_doc=ptr[u8]("Common base class for all exceptions"),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_methods=addressof(BaseException_methods),
             tp_members=addressof(BaseException_members),
             tp_getset=addressof(BaseException_getset),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new,
             tp_vectorcall=BaseException_vectorcall
         ),
         _PyExc_Exception: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("Exception"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Common base class for all non-exit exceptions."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_BaseException),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_TypeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("TypeError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Inappropriate argument type."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_StopAsyncIteration: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("StopAsyncIteration"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Signal the end from iterator.__anext__()."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_StopIteration: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("StopIteration"),
             tp_basicsize=PyStopIterationObject_SIZE,
             tp_dealloc=StopIteration_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Signal the end from iterator.__next__()."),
             tp_traverse=StopIteration_traverse,
             tp_clear=StopIteration_clear,
             tp_members=addressof(StopIteration_members),
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyStopIterationObject_DICT,
             tp_init=StopIteration_init
         ),
         _PyExc_GeneratorExit: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("GeneratorExit"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Request that a generator exit."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_BaseException),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_SystemExit: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("SystemExit"),
             tp_basicsize=PySystemExitObject_SIZE,
             tp_dealloc=SystemExit_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Request to exit from the interpreter."),
             tp_traverse=SystemExit_traverse,
             tp_clear=SystemExit_clear,
             tp_members=addressof(SystemExit_members),
             tp_base=addressof(_PyExc_BaseException),
             tp_dictoffset=PySystemExitObject_DICT,
             tp_init=SystemExit_init
         ),
         _PyExc_BaseExceptionGroup: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("BaseExceptionGroup"),
             tp_basicsize=PyBaseExceptionGroupObject_SIZE,
             tp_dealloc=BaseExceptionGroup_dealloc,
             tp_repr=BaseExceptionGroup_repr,
             tp_str=BaseExceptionGroup_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("A combination of multiple unrelated exceptions."),
             tp_traverse=BaseExceptionGroup_traverse,
             tp_clear=BaseExceptionGroup_clear,
             tp_methods=addressof(BaseExceptionGroup_methods),
             tp_members=addressof(BaseExceptionGroup_members),
             tp_base=addressof(_PyExc_BaseException),
             tp_dictoffset=PyBaseExceptionGroupObject_DICT,
             tp_init=BaseExceptionGroup_init,
             tp_new=BaseExceptionGroup_new
         ),
         _PyExc_KeyboardInterrupt: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("KeyboardInterrupt"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Program interrupted by user."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_BaseException),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_ImportError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ImportError"),
             tp_basicsize=PyImportErrorObject_SIZE,
             tp_dealloc=ImportError_dealloc,
             tp_str=ImportError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Import can't find module, or can't find name in module."),
             tp_traverse=ImportError_traverse,
             tp_clear=ImportError_clear,
             tp_methods=addressof(ImportError_methods),
             tp_members=addressof(ImportError_members),
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyImportErrorObject_DICT,
             tp_init=ImportError_init
         ),
         _PyExc_ModuleNotFoundError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ModuleNotFoundError"),
             tp_basicsize=PyImportErrorObject_SIZE,
             tp_dealloc=ImportError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Module not found."),
             tp_traverse=ImportError_traverse,
             tp_clear=ImportError_clear,
             tp_base=addressof(_PyExc_ImportError),
             tp_dictoffset=PyImportErrorObject_DICT,
             tp_init=ImportError_init
         ),
         _PyExc_OSError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("OSError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_str=OSError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for I/O related errors."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_methods=addressof(OSError_methods),
             tp_members=addressof(OSError_members),
             tp_getset=addressof(OSError_getset),
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init,
             tp_new=OSError_new
         ),
         _PyExc_BlockingIOError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("BlockingIOError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("I/O operation would block."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_ConnectionError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ConnectionError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Connection error."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_ChildProcessError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ChildProcessError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Child process error."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_BrokenPipeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("BrokenPipeError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Broken pipe."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_ConnectionError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_ConnectionAbortedError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ConnectionAbortedError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Connection aborted."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_ConnectionError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_ConnectionRefusedError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ConnectionRefusedError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Connection refused."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_ConnectionError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_ConnectionResetError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ConnectionResetError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Connection reset."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_ConnectionError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_FileExistsError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("FileExistsError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("File already exists."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_FileNotFoundError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("FileNotFoundError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("File not found."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_IsADirectoryError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("IsADirectoryError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Operation doesn't work on directories."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_NotADirectoryError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("NotADirectoryError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Operation only works on directories."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_InterruptedError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("InterruptedError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Interrupted by signal."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_PermissionError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("PermissionError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Not enough permissions."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_ProcessLookupError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ProcessLookupError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Process not found."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_TimeoutError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("TimeoutError"),
             tp_basicsize=PyOSErrorObject_SIZE,
             tp_dealloc=OSError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Timeout expired."),
             tp_traverse=OSError_traverse,
             tp_clear=OSError_clear,
             tp_base=addressof(_PyExc_OSError),
             tp_dictoffset=PyOSErrorObject_DICT,
             tp_init=OSError_init
         ),
         _PyExc_EOFError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("EOFError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Read beyond end of file."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_RuntimeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("RuntimeError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Unspecified run-time error."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_RecursionError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("RecursionError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Recursion limit exceeded."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_RuntimeError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_PythonFinalizationError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("PythonFinalizationError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Operation blocked during Python finalization."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_RuntimeError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_NotImplementedError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("NotImplementedError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Method or function hasn't been implemented yet."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_RuntimeError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_NameError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("NameError"),
             tp_basicsize=PyNameErrorObject_SIZE,
             tp_dealloc=NameError_dealloc,
             tp_str=BaseException_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Name not found globally."),
             tp_traverse=NameError_traverse,
             tp_clear=NameError_clear,
             tp_methods=addressof(NameError_methods),
             tp_members=addressof(NameError_members),
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyNameErrorObject_DICT,
             tp_init=NameError_init
         ),
         _PyExc_UnboundLocalError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UnboundLocalError"),
             tp_basicsize=PyNameErrorObject_SIZE,
             tp_dealloc=NameError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Local name referenced but not bound to a value."),
             tp_traverse=NameError_traverse,
             tp_clear=NameError_clear,
             tp_base=addressof(_PyExc_NameError),
             tp_dictoffset=PyNameErrorObject_DICT,
             tp_init=NameError_init
         ),
         _PyExc_AttributeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("AttributeError"),
             tp_basicsize=PyAttributeErrorObject_SIZE,
             tp_dealloc=AttributeError_dealloc,
             tp_str=BaseException_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Attribute not found."),
             tp_traverse=AttributeError_traverse,
             tp_clear=AttributeError_clear,
             tp_methods=addressof(AttributeError_methods),
             tp_members=addressof(AttributeError_members),
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyAttributeErrorObject_DICT,
             tp_init=AttributeError_init
         ),
         _PyExc_SyntaxError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("SyntaxError"),
             tp_basicsize=PySyntaxErrorObject_SIZE,
             tp_dealloc=SyntaxError_dealloc,
             tp_str=SyntaxError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Invalid syntax."),
             tp_traverse=SyntaxError_traverse,
             tp_clear=SyntaxError_clear,
             tp_members=addressof(SyntaxError_members),
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PySyntaxErrorObject_DICT,
             tp_init=SyntaxError_init
         ),
         _PyExc_IndentationError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("IndentationError"),
             tp_basicsize=PySyntaxErrorObject_SIZE,
             tp_dealloc=SyntaxError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Improper indentation."),
             tp_traverse=SyntaxError_traverse,
             tp_clear=SyntaxError_clear,
             tp_base=addressof(_PyExc_SyntaxError),
             tp_dictoffset=PySyntaxErrorObject_DICT,
             tp_init=SyntaxError_init
         ),
         _PyExc_TabError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("TabError"),
             tp_basicsize=PySyntaxErrorObject_SIZE,
             tp_dealloc=SyntaxError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Improper mixture of spaces and tabs."),
             tp_traverse=SyntaxError_traverse,
             tp_clear=SyntaxError_clear,
             tp_base=addressof(_PyExc_IndentationError),
             tp_dictoffset=PySyntaxErrorObject_DICT,
             tp_init=SyntaxError_init
         ),
         _PyExc_IncompleteInputError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("_IncompleteInputError"),
             tp_basicsize=PySyntaxErrorObject_SIZE,
             tp_dealloc=SyntaxError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("incomplete input."),
             tp_traverse=SyntaxError_traverse,
             tp_clear=SyntaxError_clear,
             tp_base=addressof(_PyExc_SyntaxError),
             tp_dictoffset=PySyntaxErrorObject_DICT,
             tp_init=SyntaxError_init
         ),
         _PyExc_LookupError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("LookupError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for lookup errors."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_IndexError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("IndexError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Sequence index out of range."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_LookupError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_KeyError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("KeyError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_str=KeyError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Mapping key not found."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_LookupError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init
         ),
         _PyExc_ValueError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ValueError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Inappropriate argument value (of correct type)."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_UnicodeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UnicodeError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Unicode related error."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_ValueError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_UnicodeEncodeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UnicodeEncodeError"),
             tp_basicsize=PyUnicodeErrorObject_SIZE,
             tp_dealloc=UnicodeError_dealloc,
             tp_str=UnicodeEncodeError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Unicode encoding error."),
             tp_traverse=UnicodeError_traverse,
             tp_clear=UnicodeError_clear,
             tp_members=addressof(UnicodeError_members),
             tp_base=addressof(_PyExc_UnicodeError),
             tp_dictoffset=PyUnicodeErrorObject_DICT,
             tp_init=UnicodeEncodeError_init,
             tp_new=BaseException_new
         ),
         _PyExc_UnicodeDecodeError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UnicodeDecodeError"),
             tp_basicsize=PyUnicodeErrorObject_SIZE,
             tp_dealloc=UnicodeError_dealloc,
             tp_str=UnicodeDecodeError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Unicode decoding error."),
             tp_traverse=UnicodeError_traverse,
             tp_clear=UnicodeError_clear,
             tp_members=addressof(UnicodeError_members),
             tp_base=addressof(_PyExc_UnicodeError),
             tp_dictoffset=PyUnicodeErrorObject_DICT,
             tp_init=UnicodeDecodeError_init,
             tp_new=BaseException_new
         ),
         _PyExc_UnicodeTranslateError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UnicodeTranslateError"),
             tp_basicsize=PyUnicodeErrorObject_SIZE,
             tp_dealloc=UnicodeError_dealloc,
             tp_str=UnicodeTranslateError_str,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Unicode translation error."),
             tp_traverse=UnicodeError_traverse,
             tp_clear=UnicodeError_clear,
             tp_members=addressof(UnicodeError_members),
             tp_base=addressof(_PyExc_UnicodeError),
             tp_dictoffset=PyUnicodeErrorObject_DICT,
             tp_init=UnicodeTranslateError_init,
             tp_new=BaseException_new
         ),
         _PyExc_AssertionError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("AssertionError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Assertion failed."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_ArithmeticError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ArithmeticError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for arithmetic errors."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_FloatingPointError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("FloatingPointError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Floating-point operation failed."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_ArithmeticError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_OverflowError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("OverflowError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Result too large to be represented."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_ArithmeticError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_ZeroDivisionError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ZeroDivisionError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Second argument to a division or modulo operation was zero."
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_ArithmeticError),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_SystemError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("SystemError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Internal error in the Python interpreter.\n"
                 "\n"
                 "Please report this to the Python maintainer, along with the traceback,\n"
                 "the Python version, and the hardware/OS platform and version."
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_ReferenceError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ReferenceError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Weak ref proxy used after referent went away."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_MemoryError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("MemoryError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=MemoryError_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Out of memory."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=MemoryError_new
         ),
         _PyExc_BufferError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("BufferError"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Buffer error."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_Warning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("Warning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warning categories."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Exception),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_UserWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UserWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warnings generated by user code."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_DeprecationWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("DeprecationWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warnings about deprecated features."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_PendingDeprecationWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("PendingDeprecationWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Base class for warnings about features which will be deprecated\n"
                 "in the future."
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_SyntaxWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("SyntaxWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warnings about dubious syntax."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_RuntimeWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("RuntimeWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warnings about dubious runtime behavior."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_FutureWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("FutureWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Base class for warnings about constructs that will change semantically\n"
                 "in the future."
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_ImportWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ImportWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Base class for warnings about probable mistakes in module imports"
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_UnicodeWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("UnicodeWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Base class for warnings about Unicode related problems, mostly\n"
                 "related to conversion problems."
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_BytesWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("BytesWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Base class for warnings about bytes and buffer related problems, mostly\n"
                 "related to conversion from str or comparing to str."
             ),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_EncodingWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("EncodingWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warnings about encodings."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         _PyExc_ResourceWarning: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ResourceWarning"),
             tp_basicsize=PyBaseExceptionObject_SIZE,
             tp_dealloc=BaseException_dealloc,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Base class for warnings about resource usage."),
             tp_traverse=BaseException_traverse,
             tp_clear=BaseException_clear,
             tp_base=addressof(_PyExc_Warning),
             tp_dictoffset=PyBaseExceptionObject_DICT,
             tp_init=BaseException_init,
             tp_new=BaseException_new
         ),
         PyExc_BaseException: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_BaseException)
         ),
         PyExc_Exception: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_Exception)),
         PyExc_TypeError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_TypeError)),
         PyExc_StopAsyncIteration: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_StopAsyncIteration)
         ),
         PyExc_StopIteration: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_StopIteration)
         ),
         PyExc_GeneratorExit: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_GeneratorExit)
         ),
         PyExc_SystemExit: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_SystemExit)),
         PyExc_BaseExceptionGroup: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_BaseExceptionGroup)
         ),
         PyExc_KeyboardInterrupt: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_KeyboardInterrupt)
         ),
         PyExc_ImportError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ImportError)
         ),
         PyExc_ModuleNotFoundError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ModuleNotFoundError)
         ),
         PyExc_OSError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_OSError)),
         PyExc_BlockingIOError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_BlockingIOError)
         ),
         PyExc_ConnectionError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ConnectionError)
         ),
         PyExc_ChildProcessError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ChildProcessError)
         ),
         PyExc_BrokenPipeError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_BrokenPipeError)
         ),
         PyExc_ConnectionAbortedError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ConnectionAbortedError)
         ),
         PyExc_ConnectionRefusedError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ConnectionRefusedError)
         ),
         PyExc_ConnectionResetError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ConnectionResetError)
         ),
         PyExc_FileExistsError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_FileExistsError)
         ),
         PyExc_FileNotFoundError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_FileNotFoundError)
         ),
         PyExc_IsADirectoryError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_IsADirectoryError)
         ),
         PyExc_NotADirectoryError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_NotADirectoryError)
         ),
         PyExc_InterruptedError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_InterruptedError)
         ),
         PyExc_PermissionError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_PermissionError)
         ),
         PyExc_ProcessLookupError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ProcessLookupError)
         ),
         PyExc_TimeoutError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_TimeoutError)
         ),
         PyExc_EOFError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_EOFError)),
         PyExc_RuntimeError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_RuntimeError)
         ),
         PyExc_RecursionError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_RecursionError)
         ),
         PyExc_PythonFinalizationError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_PythonFinalizationError)
         ),
         PyExc_NotImplementedError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_NotImplementedError)
         ),
         PyExc_NameError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_NameError)),
         PyExc_UnboundLocalError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UnboundLocalError)
         ),
         PyExc_AttributeError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_AttributeError)
         ),
         PyExc_SyntaxError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_SyntaxError)
         ),
         PyExc_IndentationError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_IndentationError)
         ),
         PyExc_TabError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_TabError)),
         PyExc_LookupError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_LookupError)
         ),
         PyExc_IndexError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_IndexError)),
         PyExc_KeyError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_KeyError)),
         PyExc_ValueError: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_ValueError)),
         PyExc_UnicodeError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UnicodeError)
         ),
         PyExc_UnicodeEncodeError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UnicodeEncodeError)
         ),
         PyExc_UnicodeDecodeError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UnicodeDecodeError)
         ),
         PyExc_UnicodeTranslateError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UnicodeTranslateError)
         ),
         PyExc_AssertionError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_AssertionError)
         ),
         PyExc_ArithmeticError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ArithmeticError)
         ),
         PyExc_FloatingPointError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_FloatingPointError)
         ),
         PyExc_OverflowError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_OverflowError)
         ),
         PyExc_ZeroDivisionError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ZeroDivisionError)
         ),
         PyExc_SystemError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_SystemError)
         ),
         PyExc_ReferenceError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ReferenceError)
         ),
         PyExc_MemoryError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_MemoryError)
         ),
         PyExc_BufferError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_BufferError)
         ),
         PyExc_Warning: ptr[PyObject] = ptr[PyObject](addressof(_PyExc_Warning)),
         PyExc_UserWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UserWarning)
         ),
         PyExc_DeprecationWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_DeprecationWarning)
         ),
         PyExc_PendingDeprecationWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_PendingDeprecationWarning)
         ),
         PyExc_SyntaxWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_SyntaxWarning)
         ),
         PyExc_RuntimeWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_RuntimeWarning)
         ),
         PyExc_FutureWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_FutureWarning)
         ),
         PyExc_ImportWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ImportWarning)
         ),
         PyExc_UnicodeWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_UnicodeWarning)
         ),
         PyExc_BytesWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_BytesWarning)
         ),
         PyExc_EncodingWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_EncodingWarning)
         ),
         PyExc_ResourceWarning: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_ResourceWarning)
         ),
         PyExc_EnvironmentError: ptr[PyObject] = ptr[PyObject](),
         PyExc_IOError: ptr[PyObject] = ptr[PyObject]();
}

impl base_of(op: ptr[PyObject]) -> ptr[PyBaseExceptionObject] {
    return ptr[PyBaseExceptionObject](op);
}

impl exc_args(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](base_of(op).view(1)[0].args);
}

impl base_store(op: ptr[PyObject], which: int, value: ptr[PyObject]) {
    b = base_of(op);
    old: ptr[PyObject] = NULL;
    if which == 0 {
        old = ptr[PyObject](b.view(1)[0].dict);
        b.view(1)[0].dict = value;
    } elif which == 1 {
        old = ptr[PyObject](b.view(1)[0].args);
        b.view(1)[0].args = value;
    } elif which == 2 {
        old = ptr[PyObject](b.view(1)[0].notes);
        b.view(1)[0].notes = value;
    } elif which == 3 {
        old = ptr[PyObject](b.view(1)[0].traceback);
        b.view(1)[0].traceback = value;
    } elif which == 4 {
        old = ptr[PyObject](b.view(1)[0].context);
        b.view(1)[0].context = value;
    } else {
        old = ptr[PyObject](b.view(1)[0].cause);
        b.view(1)[0].cause = value;
    }
    object_xdecref(old);
}

impl base_field(op: ptr[PyObject], which: int) -> ptr[PyObject] {
    b = base_of(op).view(1)[0];
    if which == 0 {
        return ptr[PyObject](b.dict);
    }
    if which == 1 {
        return ptr[PyObject](b.args);
    }
    if which == 2 {
        return ptr[PyObject](b.notes);
    }
    if which == 3 {
        return ptr[PyObject](b.traceback);
    }
    if which == 4 {
        return ptr[PyObject](b.context);
    }
    return ptr[PyObject](b.cause);
}

impl type_alloc(type: ptr[PyObject]) -> ptr[PyObject] {
    calls = ptr[ExcCall](
        __thread_local_block("jac_object_model_exceptions_call_slot", 16)
    );
    calls.view(1)[0].alloc = int(ptr[PyTypeObject](type).view(1)[0].tp_alloc);
    return calls.view(1)[0].alloc(type, 0);
}

impl type_free(op: ptr[PyObject]) {
    calls = ptr[ExcCall](
        __thread_local_block("jac_object_model_exceptions_call_slot", 16)
    );
    calls.view(1)[0].free = int(object_type(op).view(1)[0].tp_free);
    calls.view(1)[0].free(ptr(op));
}

impl base_init_fields(op: ptr[PyObject], args: ptr[PyObject]) {
    b = base_of(op);

    b.view(1)[0].dict = NULL;
    b.view(1)[0].notes = NULL;
    b.view(1)[0].traceback = NULL;
    b.view(1)[0].cause = NULL;
    b.view(1)[0].context = NULL;
    b.view(1)[0].suppress_context = i8(0);
    b.view(1)[0].args = args;
}

impl BaseException_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    self = type_alloc(type);
    if not self {
        return NULL;
    }
    if args {
        base_init_fields(self, object_new_ref(args));
        return self;
    }
    base_init_fields(self, NULL);
    empty = PyTuple_New(0);
    if not empty {
        object_decref(self);
        return NULL;
    }
    base_of(self).view(1)[0].args = empty;
    return self;
}

impl BaseException_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if kwds and _PyArg_NoKeywords(object_type(op).view(1)[0].tp_name, kwds) == 0 {
        return i32(-1);
    }
    base_store(op, 1, object_new_ref(args));
    return i32(0);
}

impl BaseException_vectorcall(
    type_obj: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames
        and _PyArg_NoKwnames(ptr[PyTypeObject](type_obj).view(1)[0].tp_name, kwnames)
            == 0 {
        return NULL;
    }
    self = type_alloc(type_obj);
    if not self {
        return NULL;
    }
    base_init_fields(self, NULL);
    tuple = _PyTuple_FromArray(args, PyVectorcall_NARGS(nargsf));
    if not tuple {
        object_decref(self);
        return NULL;
    }
    base_of(self).view(1)[0].args = tuple;
    return self;
}

impl BaseException_clear(op: ptr[PyObject]) -> i32 {
    for which in [0, 1, 2, 3, 5, 4] {
        base_store(op, which, NULL);
    }
    return i32(0);
}

impl BaseException_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(op));

    BaseException_clear(op);
    type_free(op);
}

impl BaseException_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    for which in [0, 1, 2, 3, 5, 4] {
        status = visit_reference(base_field(op, which), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl BaseException_str(op: ptr[PyObject]) -> ptr[PyObject] {
    args = exc_args(op);
    n = object_size(args);
    if n == 0 {
        return PyUnicode_FromString(ptr[u8](""));
    }
    if n == 1 {
        return PyObject_Str(tuple_get_item(args, 0));
    }
    return PyObject_Str(args);
}

impl BaseException_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    name = _PyType_Name(ptr[PyObject](object_type(op)));
    args = exc_args(op);
    if object_size(args) == 1 {
        return PyUnicode_FromFormat("%s(%R)", name, tuple_get_item(args, 0));
    }
    return PyUnicode_FromFormat("%s%R", name, args);
}

impl BaseException___reduce__(
    op: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    args = exc_args(op);
    d = base_field(op, 0);
    if args and d {
        return PyTuple_Pack(3, ptr(object_type(op)), args, d);
    }
    return PyTuple_Pack(2, ptr(object_type(op)), args);
}

impl BaseException___setstate__(
    op: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    if state != Py_None {
        if not type_has_feature(object_type(state), Py_TPFLAGS_DICT_SUBCLASS) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("state is not a dictionary"));
            return NULL;
        }
        pos: i64 = 0;
        key: ptr[PyObject] = NULL;
        value: ptr[PyObject] = NULL;
        while PyDict_Next(state, &mut pos, &mut key, &mut value) != 0 {
            object_incref(key);
            object_incref(value);
            res = PyObject_SetAttr(op, key, value);
            object_decref(value);
            object_decref(key);
            if res < 0 {
                return NULL;
            }
        }
    }
    return object_new_ref(Py_None);
}

impl BaseException_with_traceback(
    op: ptr[PyObject], tb: ptr[PyObject]
) -> ptr[PyObject] {
    if traceback_set(op, tb) < 0 {
        return NULL;
    }
    return object_new_ref(op);
}

impl BaseException_add_note(op: ptr[PyObject], note: ptr[PyObject]) -> ptr[PyObject] {
    if not type_has_feature(object_type(note), Py_TPFLAGS_UNICODE_SUBCLASS) {
        _PyArg_BadArgument(
            ptr[u8]("add_note"), ptr[u8]("argument"), ptr[u8]("str"), note
        );
        return NULL;
    }
    notes: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(op, interned_notes(), &mut notes) < 0 {
        return NULL;
    }
    if not notes {
        notes = PyList_New(0);
        if not notes {
            return NULL;
        }
        if PyObject_SetAttr(op, interned_notes(), notes) < 0 {
            object_decref(notes);
            return NULL;
        }
    } elif not type_has_feature(object_type(notes), Py_TPFLAGS_LIST_SUBCLASS) {
        object_decref(notes);
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Cannot add note: __notes__ is not a list")
        );
        return NULL;
    }
    if PyList_Append(notes, note) < 0 {
        object_decref(notes);
        return NULL;
    }
    object_decref(notes);
    return object_new_ref(Py_None);
}

impl interned_notes -> ptr[PyObject] {
    if not notes_key {
        notes_key = PyUnicode_InternFromString(ptr[u8]("__notes__"));
    }
    return notes_key;
}

impl BaseException_args_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    args = exc_args(op);
    return object_new_ref(args or Py_None);
}

impl BaseException_args_set(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("args may not be deleted"));
        return i32(-1);
    }
    seq = PySequence_Tuple(value);
    if not seq {
        return i32(-1);
    }
    base_store(op, 1, seq);
    return i32(0);
}

impl BaseException___traceback___get(
    op: ptr[PyObject], _closure: ptr
) -> ptr[PyObject] {
    tb = base_field(op, 3);
    return object_new_ref(tb or Py_None);
}

impl traceback_set(op: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("__traceback__ may not be deleted"));
        return i32(-1);
    }
    if object_type_check(value, ptr[PyTypeObject](addressof(PyTraceBack_Type))) {
        base_store(op, 3, object_new_ref(value));
    } elif value == Py_None {
        base_store(op, 3, NULL);
    } else {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("__traceback__ must be a traceback or None")
        );
        return i32(-1);
    }
    return i32(0);
}

impl BaseException___traceback___set(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    return traceback_set(op, value);
}

impl exception_instance_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}

impl BaseException___context___get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    context = base_field(op, 4);
    return object_new_ref(context or Py_None);
}

impl BaseException___context___set(
    op: ptr[PyObject], value_in: ptr[PyObject], _closure: ptr
) -> i32 {
    value = value_in;
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("__context__ may not be deleted"));
        return i32(-1);
    }
    if value == Py_None {
        value = NULL;
    } elif not exception_instance_check(value) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("exception context must be None or derive from BaseException")
        );
        return i32(-1);
    } else {
        object_incref(value);
    }
    base_store(op, 4, value);
    return i32(0);
}

impl BaseException___cause___get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    cause = base_field(op, 5);
    return object_new_ref(cause or Py_None);
}

impl BaseException___cause___set(
    op: ptr[PyObject], value_in: ptr[PyObject], _closure: ptr
) -> i32 {
    value = value_in;
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("__cause__ may not be deleted"));
        return i32(-1);
    }
    if value == Py_None {
        value = NULL;
    } elif not exception_instance_check(value) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("exception cause must be None or derive from BaseException")
        );
        return i32(-1);
    } else {
        object_incref(value);
    }
    PyException_SetCause(op, value);
    return i32(0);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}


impl exc_field(op: ptr[PyObject], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0];
}

impl set_exc_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](ptr[u8](op) + offset).view(1)[0] = value;
}

impl replace_exc_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]) {
    old = exc_field(op, offset);
    set_exc_field(op, offset, value);
    object_xdecref(old);
}

impl exc_dealloc(op: ptr[PyObject], clear: Callable[[ptr[PyObject]], i32]) {
    PyObject_GC_UnTrack(ptr(op));
    clear(op);
    type_free(op);
}

impl exc_traverse(
    op: ptr[PyObject], offsets: list[i64], visitor: ptr, arg: ptr
) -> i32 {
    for offset in offsets {
        status = visit_reference(exc_field(op, offset), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return BaseException_traverse(op, visitor, arg);
}

impl StopIteration_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, kwds) == -1 {
        return i32(-1);
    }
    replace_exc_field(op, PyStopIterationObject_VALUE, NULL);
    value = tuple_get_item(args, 0) if object_size(args) > 0 else Py_None;
    set_exc_field(op, PyStopIterationObject_VALUE, object_new_ref(value));
    return i32(0);
}

impl StopIteration_clear(op: ptr[PyObject]) -> i32 {
    replace_exc_field(op, PyStopIterationObject_VALUE, NULL);
    return BaseException_clear(op);
}

impl StopIteration_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, StopIteration_clear);
}

impl StopIteration_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(op, [PyStopIterationObject_VALUE], visitor, arg);
}

impl SystemExit_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    size = object_size(args);
    if BaseException_init(op, args, kwds) == -1 {
        return i32(-1);
    }
    if size == 0 {
        return i32(0);
    }
    code = tuple_get_item(args, 0) if size == 1 else args;
    replace_exc_field(op, PySystemExitObject_CODE, object_new_ref(code));
    return i32(0);
}

impl SystemExit_clear(op: ptr[PyObject]) -> i32 {
    replace_exc_field(op, PySystemExitObject_CODE, NULL);
    return BaseException_clear(op);
}

impl SystemExit_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, SystemExit_clear);
}

impl SystemExit_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(op, [PySystemExitObject_CODE], visitor, arg);
}

impl exception_group_slot -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](current_interp() + PyInterpreterState_EXC_GROUP);
}

impl is_base_exception_group(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(_PyExc_BaseExceptionGroup));
}

impl eg_excs(op: ptr[PyObject]) -> ptr[PyObject] {
    return exc_field(op, PyBaseExceptionGroupObject_EXCS);
}

impl BaseExceptionGroup_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    exception_group = exception_group_slot().view(1)[0];
    nargs = object_size(args);
    if nargs != 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "BaseExceptionGroup.__new__() takes exactly 2 arguments (%zd given)"
            ),
            nargs
        );
        return NULL;
    }
    message = tuple_get_item(args, 0);
    exceptions = tuple_get_item(args, 1);
    if not type_has_feature(object_type(message), Py_TPFLAGS_UNICODE_SUBCLASS) {
        _PyArg_BadArgument(
            ptr[u8]("BaseExceptionGroup.__new__"),
            ptr[u8]("argument 1"),
            ptr[u8]("str"),
            message
        );
        return NULL;
    }
    if PySequence_Check(exceptions) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("second argument (exceptions) must be a sequence")
        );
        return NULL;
    }

    exceptions_str: ptr[PyObject] = NULL;
    if not type_has_feature(object_type(exceptions), Py_TPFLAGS_LIST_SUBCLASS)
        and not type_has_feature(object_type(exceptions), Py_TPFLAGS_TUPLE_SUBCLASS) {
        exceptions_str = PyObject_Repr(exceptions);
        if not exceptions_str {
            return NULL;
        }
    }
    excs = PySequence_Tuple(exceptions);
    if not excs {
        object_xdecref(exceptions_str);
        return NULL;
    }
    numexcs = object_size(excs);
    failed = False;
    nested_base_exceptions = False;
    if numexcs == 0 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("second argument (exceptions) must be a non-empty sequence")
        );
        failed = True;
    }
    i: i64 = 0;
    while not failed and i < numexcs {
        exc = tuple_get_item(excs, i);
        if not exception_instance_check(exc) {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("Item %zd of second argument (exceptions) is not an exception"),
                i
            );
            failed = True;
        } else {
            is_nonbase_exception = PyObject_IsInstance(exc, PyExc_Exception);
            if is_nonbase_exception < 0 {
                failed = True;
            } elif is_nonbase_exception == 0 {
                nested_base_exceptions = True;
            }
        }
        i += 1;
    }
    cls = type;
    if not failed {
        if cls == exception_group {
            if nested_base_exceptions {
                PyErr_SetString(
                    PyExc_TypeError,
                    ptr[u8]("Cannot nest BaseExceptions in an ExceptionGroup")
                );
                failed = True;
            }
        } elif cls == PyExc_BaseExceptionGroup {
            if not nested_base_exceptions {
                cls = exception_group;
            }
        } elif nested_base_exceptions {
            nonbase = PyObject_IsSubclass(cls, PyExc_Exception);
            if nonbase == -1 {
                failed = True;
            } elif nonbase == 1 {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("Cannot nest BaseExceptions in '%.200s'"),
                    ptr[PyTypeObject](cls).view(1)[0].tp_name
                );
                failed = True;
            }
        }
    }
    if not failed {
        if not cls {
            cls = PyExc_BaseExceptionGroup;
        }
        self = BaseException_new(cls, args, kwds);
        if self {
            set_exc_field(
                self, PyBaseExceptionGroupObject_MSG, object_new_ref(message)
            );
            set_exc_field(self, PyBaseExceptionGroupObject_EXCS, excs);
            set_exc_field(self, PyBaseExceptionGroupObject_EXCS_STR, exceptions_str);
            return self;
        }
    }
    object_xdecref(excs);
    object_xdecref(exceptions_str);
    return NULL;
}

impl BaseExceptionGroup_init(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if kwds and _PyArg_NoKeywords(object_type(self).view(1)[0].tp_name, kwds) == 0 {
        return i32(-1);
    }
    if BaseException_init(self, args, kwds) == -1 {
        return i32(-1);
    }
    return i32(0);
}

impl BaseExceptionGroup_clear(op: ptr[PyObject]) -> i32 {
    replace_exc_field(op, PyBaseExceptionGroupObject_MSG, NULL);
    replace_exc_field(op, PyBaseExceptionGroupObject_EXCS, NULL);
    replace_exc_field(op, PyBaseExceptionGroupObject_EXCS_STR, NULL);
    return BaseException_clear(op);
}

impl BaseExceptionGroup_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, BaseExceptionGroup_clear);
}

impl BaseExceptionGroup_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(
        op,
        [
            PyBaseExceptionGroupObject_MSG,
            PyBaseExceptionGroupObject_EXCS,
            PyBaseExceptionGroupObject_EXCS_STR
        ],
        visitor,
        arg
    );
}

impl BaseExceptionGroup_str(op: ptr[PyObject]) -> ptr[PyObject] {
    num_excs = PyTuple_Size(eg_excs(op));
    return PyUnicode_FromFormat(
        "%S (%zd sub-exception%s)",
        exc_field(op, PyBaseExceptionGroupObject_MSG),
        num_excs,
        "s" if num_excs > 1 else ""
    );
}

impl BaseExceptionGroup_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    exceptions_str: ptr[PyObject] = NULL;
    saved = exc_field(op, PyBaseExceptionGroupObject_EXCS_STR);
    if saved {
        exceptions_str = object_new_ref(saved);
    } elif type_has_feature(
        object_type(tuple_get_item(exc_args(op), 1)), Py_TPFLAGS_LIST_SUBCLASS
    ) {
        exceptions_list = PySequence_List(eg_excs(op));
        if not exceptions_list {
            return NULL;
        }
        exceptions_str = PyObject_Repr(exceptions_list);
        object_decref(exceptions_list);
    } else {
        exceptions_str = PyObject_Repr(eg_excs(op));
    }
    if not exceptions_str {
        return NULL;
    }
    repr = PyUnicode_FromFormat(
        "%s(%R, %U)",
        _PyType_Name(ptr[PyObject](object_type(op))),
        exc_field(op, PyBaseExceptionGroupObject_MSG),
        exceptions_str
    );
    object_decref(exceptions_str);
    return repr;
}

impl BaseExceptionGroup_derive(
    self: ptr[PyObject], excs: ptr[PyObject]
) -> ptr[PyObject] {
    init_args = PyTuple_Pack(2, exc_field(self, PyBaseExceptionGroupObject_MSG), excs);
    if not init_args {
        return NULL;
    }
    eg = PyObject_CallObject(PyExc_BaseExceptionGroup, init_args);
    object_decref(init_args);
    return eg;
}

impl exceptiongroup_subset(
    orig: ptr[PyObject], excs: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    num_excs = PySequence_Size(excs);
    if num_excs < 0 {
        return (i32(-1), NULL);
    }
    if num_excs == 0 {
        return (i32(0), NULL);
    }
    eg = PyObject_CallMethod(orig, "derive", "(O)", excs);
    if not eg {
        return (i32(-1), NULL);
    }
    if not is_base_exception_group(eg) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("derive must return an instance of BaseExceptionGroup")
        );
        object_decref(eg);
        return (i32(-1), NULL);
    }
    tb = PyException_GetTraceback(orig);
    if tb {
        res = PyException_SetTraceback(eg, tb);
        object_decref(tb);
        if res < 0 {
            object_decref(eg);
            return (i32(-1), NULL);
        }
    }
    PyException_SetContext(eg, PyException_GetContext(orig));
    PyException_SetCause(eg, PyException_GetCause(orig));
    notes: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(orig, interned_notes(), &mut notes) < 0 {
        object_decref(eg);
        return (i32(-1), NULL);
    }
    if notes {
        if PySequence_Check(notes) != 0 {
            notes_copy = PySequence_List(notes);
            object_decref(notes);
            if not notes_copy {
                object_decref(eg);
                return (i32(-1), NULL);
            }
            res = PyObject_SetAttr(eg, interned_notes(), notes_copy);
            object_decref(notes_copy);
            if res < 0 {
                object_decref(eg);
                return (i32(-1), NULL);
            }
        } else {
            object_decref(notes);
        }
    }
    return (i32(0), eg);
}

impl exception_class_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS)
        and type_has_feature(ptr[PyTypeObject](op), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}

impl get_matcher_type(value: ptr[PyObject]) -> i32 {
    if PyCallable_Check(value) != 0
        and not type_has_feature(object_type(value), Py_TPFLAGS_TYPE_SUBCLASS) {
        return MATCH_BY_PREDICATE;
    }
    if exception_class_check(value) {
        return MATCH_BY_TYPE;
    }
    if object_is_type(value, ptr[PyTypeObject](addressof(PyTuple_Type))) {
        ok = True;
        for i in range(object_size(value)) {
            if not exception_class_check(tuple_get_item(value, i)) {
                ok = False;
                break;
            }
        }
        if ok {
            return MATCH_BY_TYPE;
        }
    }
    PyErr_SetString(
        PyExc_TypeError,
        ptr[u8](
            "expected an exception type, a tuple of exception types, or a callable (other than a class)"
        )
    );
    return i32(-1);
}

impl split_check_match(
    exc: ptr[PyObject], matcher_type: i32, matcher_value: ptr[PyObject]
) -> i32 {
    if matcher_type == MATCH_BY_TYPE {
        return PyErr_GivenExceptionMatches(exc, matcher_value);
    }
    if matcher_type == MATCH_BY_PREDICATE {
        exc_matches = PyObject_CallOneArg(matcher_value, exc);
        if not exc_matches {
            return i32(-1);
        }
        is_true = PyObject_IsTrue(exc_matches);
        object_decref(exc_matches);
        return is_true;
    }
    if not is_base_exception_group(exc) {
        exc_id = PyLong_FromVoidPtr(ptr(exc));
        if not exc_id {
            return i32(-1);
        }
        res = PySet_Contains(matcher_value, exc_id);
        object_decref(exc_id);
        return res;
    }
    return i32(0);
}

impl split_recursive(
    exc: ptr[PyObject],
    matcher_type: i32,
    matcher_value: ptr[PyObject],
    construct_rest: bool
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    is_match = split_check_match(exc, matcher_type, matcher_value);
    if is_match < 0 {
        return (i32(-1), NULL, NULL);
    }
    if is_match != 0 {
        return (i32(0), object_new_ref(exc), NULL);
    }
    if not is_base_exception_group(exc) {
        return (i32(0), NULL, object_new_ref(exc) if construct_rest else NULL);
    }

    excs = eg_excs(exc);
    num_excs = PyTuple_Size(excs);
    if num_excs < 0 {
        return (i32(-1), NULL, NULL);
    }
    match_list = PyList_New(0);
    if not match_list {
        return (i32(-1), NULL, NULL);
    }
    rest_list: ptr[PyObject] = NULL;
    failed = False;
    if construct_rest {
        rest_list = PyList_New(0);
        failed = not rest_list;
    }
    i: i64 = 0;
    while not failed and i < num_excs {
        e = tuple_get_item(excs, i);
        if Py_EnterRecursiveCall(ptr[u8](" in exceptiongroup_split_recursive")) != 0 {
            failed = True;
            break;
        }
        (status, rec_match, rec_rest) = split_recursive(
            e, matcher_type, matcher_value, construct_rest
        );
        Py_LeaveRecursiveCall();
        if status < 0 {
            failed = True;
            break;
        }
        if rec_match {
            if PyList_Append(match_list, rec_match) < 0 {
                object_decref(rec_match);
                object_xdecref(rec_rest);
                failed = True;
                break;
            }
            object_decref(rec_match);
        }
        if rec_rest {
            if PyList_Append(rest_list, rec_rest) < 0 {
                object_decref(rec_rest);
                failed = True;
                break;
            }
            object_decref(rec_rest);
        }
        i += 1;
    }
    matched: ptr[PyObject] = NULL;
    rest: ptr[PyObject] = NULL;
    if not failed {
        (status, matched) = exceptiongroup_subset(exc, match_list);
        failed = status < 0;
    }
    if not failed and construct_rest {
        (status, rest) = exceptiongroup_subset(exc, rest_list);
        if status < 0 {
            object_xdecref(matched);
            matched = NULL;
            failed = True;
        }
    }
    object_decref(match_list);
    object_xdecref(rest_list);
    if failed {
        object_xdecref(matched);
        object_xdecref(rest);
        return (i32(-1), NULL, NULL);
    }
    return (i32(0), matched, rest);
}

impl BaseExceptionGroup_split(
    self: ptr[PyObject], matcher_value: ptr[PyObject]
) -> ptr[PyObject] {
    matcher_type = get_matcher_type(matcher_value);
    if matcher_type < 0 {
        return NULL;
    }
    (status, matched, rest) = split_recursive(self, matcher_type, matcher_value, True);
    if status < 0 {
        return NULL;
    }
    result = PyTuple_Pack(2, matched or Py_None, rest or Py_None);
    object_xdecref(matched);
    object_xdecref(rest);
    return result;
}

impl BaseExceptionGroup_subgroup(
    self: ptr[PyObject], matcher_value: ptr[PyObject]
) -> ptr[PyObject] {
    matcher_type = get_matcher_type(matcher_value);
    if matcher_type < 0 {
        return NULL;
    }
    (status, matched, rest) = split_recursive(self, matcher_type, matcher_value, False);
    if status < 0 {
        return NULL;
    }
    return matched or object_new_ref(Py_None);
}

impl collect_leaf_ids(exc: ptr[PyObject], leaf_ids: ptr[PyObject]) -> i32 {
    if exc == Py_None {
        return i32(0);
    }
    if not is_base_exception_group(exc) {
        exc_id = PyLong_FromVoidPtr(ptr(exc));
        if not exc_id {
            return i32(-1);
        }
        res = PySet_Add(leaf_ids, exc_id);
        object_decref(exc_id);
        return res;
    }
    excs = eg_excs(exc);
    for i in range(object_size(excs)) {
        if Py_EnterRecursiveCall(ptr[u8](" in collect_exception_group_leaf_ids"))
            != 0 {
            return i32(-1);
        }
        res = collect_leaf_ids(tuple_get_item(excs, i), leaf_ids);
        Py_LeaveRecursiveCall();
        if res < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

impl exception_group_projection(
    eg: ptr[PyObject], keep: ptr[PyObject]
) -> ptr[PyObject] {
    leaf_ids = PySet_New(NULL);
    if not leaf_ids {
        return NULL;
    }
    for i in range(object_size(keep)) {
        if collect_leaf_ids(PyList_GetItem(keep, i), leaf_ids) < 0 {
            object_decref(leaf_ids);
            return NULL;
        }
    }
    (status, matched, rest) = split_recursive(eg, MATCH_INSTANCE_IDS, leaf_ids, False);
    object_decref(leaf_ids);
    if status < 0 {
        return NULL;
    }
    return matched or object_new_ref(Py_None);
}

impl is_same_exception_metadata(exc1: ptr[PyObject], exc2: ptr[PyObject]) -> bool {
    for which in [2, 3, 5, 4] {
        if base_field(exc1, which) != base_field(exc2, which) {
            return False;
        }
    }
    return True;
}

impl create_exception_group_class -> ptr[PyObject] {
    bases = PyTuple_Pack(2, PyExc_BaseExceptionGroup, PyExc_Exception);
    if not bases {
        return NULL;
    }
    group = PyErr_NewException(ptr[u8]("builtins.ExceptionGroup"), bases, NULL);
    exception_group_slot().view(1)[0] = group;
    object_decref(bases);
    return group;
}


impl ImportError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, NULL) == -1 {
        return i32(-1);
    }
    empty_tuple = PyTuple_New(0);
    if not empty_tuple {
        return i32(-1);
    }
    name: ptr[PyObject] = NULL;
    path: ptr[PyObject] = NULL;
    name_from: ptr[PyObject] = NULL;
    if PyArg_ParseTupleAndKeywords(
        empty_tuple,
        kwds,
        ptr[u8]("|$OOO:ImportError"),
        ptr(addressof(import_error_keywords)),
        &mut name,
        &mut path,
        &mut name_from
    )
        == 0 {
        object_decref(empty_tuple);
        return i32(-1);
    }
    object_decref(empty_tuple);
    replace_exc_field(op, PyImportErrorObject_NAME, object_xnew_ref(name));
    replace_exc_field(op, PyImportErrorObject_PATH, object_xnew_ref(path));
    replace_exc_field(op, PyImportErrorObject_NAME_FROM, object_xnew_ref(name_from));
    msg = object_new_ref(tuple_get_item(args, 0)) if object_size(args) == 1 else NULL;
    replace_exc_field(op, PyImportErrorObject_MSG, msg);
    return i32(0);
}

impl ImportError_clear(op: ptr[PyObject]) -> i32 {
    for offset in [
        PyImportErrorObject_MSG,
        PyImportErrorObject_NAME,
        PyImportErrorObject_PATH,
        PyImportErrorObject_NAME_FROM
    ] {
        replace_exc_field(op, offset, NULL);
    }
    return BaseException_clear(op);
}

impl ImportError_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, ImportError_clear);
}

impl ImportError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(
        op,
        [
            PyImportErrorObject_MSG,
            PyImportErrorObject_NAME,
            PyImportErrorObject_PATH,
            PyImportErrorObject_NAME_FROM
        ],
        visitor,
        arg
    );
}

impl ImportError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    msg = exc_field(op, PyImportErrorObject_MSG);
    if msg and object_is_type(msg, ptr[PyTypeObject](addressof(PyUnicode_Type))) {
        return object_new_ref(msg);
    }
    return BaseException_str(op);
}

impl ImportError_getstate(op: ptr[PyObject]) -> ptr[PyObject] {
    d = base_field(op, 0);
    name = exc_field(op, PyImportErrorObject_NAME);
    path = exc_field(op, PyImportErrorObject_PATH);
    name_from = exc_field(op, PyImportErrorObject_NAME_FROM);
    if name or path or name_from {
        state = PyDict_Copy(d) if d else PyDict_New();
        if not state {
            return NULL;
        }
        if (name and PyDict_SetItemString(state, ptr[u8]("name"), name) < 0)
            or (path and PyDict_SetItemString(state, ptr[u8]("path"), path) < 0)
            or (
                name_from
                and PyDict_SetItemString(state, ptr[u8]("name_from"), name_from) < 0
            ) {
            object_decref(state);
            return NULL;
        }
        return state;
    }
    return object_new_ref(d or Py_None);
}

impl ImportError_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    state = ImportError_getstate(op);
    if not state {
        return NULL;
    }
    res: ptr[PyObject] = NULL;
    if state == Py_None {
        res = PyTuple_Pack(2, ptr(object_type(op)), exc_args(op));
    } else {
        res = PyTuple_Pack(3, ptr(object_type(op)), exc_args(op), state);
    }
    object_decref(state);
    return res;
}

impl os_of(op: ptr[PyObject]) -> ptr[PyOSErrorObject] {
    return ptr[PyOSErrorObject](op);
}

impl oserror_parse_args(
    args: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[PyObject], ptr[PyObject]] {
    nargs = object_size(args);
    if nargs >= 2 and nargs <= 5 {
        items = tuple_items(args);
        return (
            i32(0),
            items.view(1)[0],
            (items + 1).view(1)[0],
            (items + 2).view(1)[0] if nargs > 2 else NULL,
            (items + 4).view(1)[0] if nargs > 4 else NULL
        );
    }
    return (i32(0), NULL, NULL, NULL, NULL);
}

impl oserror_init(
    op: ptr[PyObject],
    args_in: ptr[PyObject],
    myerrno: ptr[PyObject],
    strerror: ptr[PyObject],
    filename: ptr[PyObject],
    filename2: ptr[PyObject]
) -> i32 {
    args = args_in;
    nargs = object_size(args);
    o = os_of(op);

    if filename and filename != Py_None {
        if object_is_type(op, ptr[PyTypeObject](PyExc_BlockingIOError))
            and PyNumber_Check(filename) != 0 {
            written = PyNumber_AsSsize_t(filename, PyExc_ValueError);
            o.view(1)[0].written = written;
            if written == -1 and PyErr_Occurred() {
                object_decref(args);
                return i32(-1);
            }
        } else {
            o.view(1)[0].filename = object_new_ref(filename);
            if filename2 and filename2 != Py_None {
                o.view(1)[0].filename2 = object_new_ref(filename2);
            }
            if nargs >= 2 and nargs <= 5 {
                subslice = PyTuple_GetSlice(args, 0, 2);
                if not subslice {
                    object_decref(args);
                    return i32(-1);
                }
                object_decref(args);
                args = subslice;
            }
        }
    }
    o.view(1)[0].myerrno = object_xnew_ref(myerrno);
    o.view(1)[0].strerror = object_xnew_ref(strerror);
    base_store(op, 1, args);
    return i32(0);
}

impl oserror_use_init(type: ptr[PyTypeObject]) -> bool {
    return int(type.view(1)[0].tp_init) != int(ptr(OSError_init))
        and int(type.view(1)[0].tp_new) == int(ptr(OSError_new));
}

impl errnomap -> ptr[PyObject] {
    return ptr[ptr[PyObject]](current_interp() + PyInterpreterState_EXC_ERRNOMAP).view(
        1
    )[0];
}

impl OSError_new(
    type_in: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    type = type_in;
    myerrno: ptr[PyObject] = NULL;
    strerror: ptr[PyObject] = NULL;
    filename: ptr[PyObject] = NULL;
    filename2: ptr[PyObject] = NULL;
    use_init = oserror_use_init(ptr[PyTypeObject](type));
    if not use_init {
        if kwds
            and _PyArg_NoKeywords(ptr[PyTypeObject](type).view(1)[0].tp_name, kwds)
                == 0 {
            return NULL;
        }
        (status, myerrno, strerror, filename, filename2) = oserror_parse_args(args);
        mapping = errnomap();
        if myerrno
            and type_has_feature(object_type(myerrno), Py_TPFLAGS_LONG_SUBCLASS)
            and mapping
            and type == PyExc_OSError {
            newtype = PyDict_GetItemWithError(mapping, myerrno);
            if newtype {
                type = newtype;
            } elif PyErr_Occurred() {
                return NULL;
            }
        }
    }
    self = type_alloc(type);
    if not self {
        return NULL;
    }
    b = base_of(self);
    b.view(1)[0].dict = NULL;
    b.view(1)[0].traceback = NULL;
    b.view(1)[0].cause = NULL;
    b.view(1)[0].context = NULL;
    os_of(self).view(1)[0].written = -1;
    if not oserror_use_init(ptr[PyTypeObject](type)) {
        if oserror_init(
            self, object_new_ref(args), myerrno, strerror, filename, filename2
        )
            != 0 {
            object_decref(self);
            return NULL;
        }
    } else {
        empty = PyTuple_New(0);
        if not empty {
            object_decref(self);
            return NULL;
        }
        b.view(1)[0].args = empty;
    }
    return self;
}

impl OSError_init(op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    if not oserror_use_init(object_type(op)) {
        return i32(0);
    }
    if kwds and _PyArg_NoKeywords(object_type(op).view(1)[0].tp_name, kwds) == 0 {
        return i32(-1);
    }
    (status, myerrno, strerror, filename, filename2) = oserror_parse_args(args);
    return oserror_init(
        op, object_new_ref(args), myerrno, strerror, filename, filename2
    );
}

impl os_field(op: ptr[PyObject], which: int) -> ptr[PyObject] {
    o = os_of(op).view(1)[0];
    if which == 0 {
        return ptr[PyObject](o.myerrno);
    }
    if which == 1 {
        return ptr[PyObject](o.strerror);
    }
    if which == 2 {
        return ptr[PyObject](o.filename);
    }
    return ptr[PyObject](o.filename2);
}

impl OSError_clear(op: ptr[PyObject]) -> i32 {
    o = os_of(op);
    fields = [os_field(op, 0), os_field(op, 1), os_field(op, 2), os_field(op, 3)];
    o.view(1)[0].myerrno = NULL;
    o.view(1)[0].strerror = NULL;
    o.view(1)[0].filename = NULL;
    o.view(1)[0].filename2 = NULL;
    for value in fields {
        object_xdecref(value);
    }
    return BaseException_clear(op);
}

impl OSError_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, OSError_clear);
}

impl OSError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    for which in [0, 1, 2, 3] {
        status = visit_reference(os_field(op, which), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return BaseException_traverse(op, visitor, arg);
}

impl or_none(op: ptr[PyObject]) -> ptr[PyObject] {
    return op or Py_None;
}

impl OSError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    myerrno = os_field(op, 0);
    strerror = os_field(op, 1);
    filename = os_field(op, 2);
    filename2 = os_field(op, 3);
    if filename {
        if filename2 {
            return PyUnicode_FromFormat(
                "[Errno %S] %S: %R -> %R",
                or_none(myerrno),
                or_none(strerror),
                filename,
                filename2
            );
        }
        return PyUnicode_FromFormat(
            "[Errno %S] %S: %R", or_none(myerrno), or_none(strerror), filename
        );
    }
    if myerrno and strerror {
        return PyUnicode_FromFormat("[Errno %S] %S", myerrno, strerror);
    }
    return BaseException_str(op);
}

impl OSError_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    args = exc_args(op);
    filename = os_field(op, 2);
    filename2 = os_field(op, 3);

    if object_size(args) == 2 and filename {
        size = 5 if filename2 else 3;
        rebuilt = PyTuple_New(size);
        if not rebuilt {
            return NULL;
        }
        tuple_set_item(rebuilt, 0, object_new_ref(tuple_get_item(args, 0)));
        tuple_set_item(rebuilt, 1, object_new_ref(tuple_get_item(args, 1)));
        tuple_set_item(rebuilt, 2, object_new_ref(filename));
        if filename2 {
            tuple_set_item(rebuilt, 3, object_new_ref(Py_None));
            tuple_set_item(rebuilt, 4, object_new_ref(filename2));
        }
        args = rebuilt;
    } else {
        object_incref(args);
    }
    d = base_field(op, 0);
    res: ptr[PyObject] = NULL;
    if d {
        res = PyTuple_Pack(3, ptr(object_type(op)), args, d);
    } else {
        res = PyTuple_Pack(2, ptr(object_type(op)), args);
    }
    object_decref(args);
    return res;
}

impl OSError_written_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    written = os_of(op).view(1)[0].written;
    if written == -1 {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("characters_written"));
        return NULL;
    }
    return PyLong_FromSsize_t(written);
}

impl OSError_written_set(op: ptr[PyObject], arg: ptr[PyObject], _closure: ptr) -> i32 {
    o = os_of(op);
    if not arg {
        if o.view(1)[0].written == -1 {
            PyErr_SetString(PyExc_AttributeError, ptr[u8]("characters_written"));
            return i32(-1);
        }
        o.view(1)[0].written = -1;
        return i32(0);
    }
    n = PyNumber_AsSsize_t(arg, PyExc_ValueError);
    if n == -1 and PyErr_Occurred() {
        return i32(-1);
    }
    o.view(1)[0].written = n;
    return i32(0);
}


impl NameError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, NULL) == -1 {
        return i32(-1);
    }
    empty_tuple = PyTuple_New(0);
    if not empty_tuple {
        return i32(-1);
    }
    name: ptr[PyObject] = NULL;
    if PyArg_ParseTupleAndKeywords(
        empty_tuple,
        kwds,
        ptr[u8]("|$O:NameError"),
        ptr(addressof(name_error_keywords)),
        &mut name
    )
        == 0 {
        object_decref(empty_tuple);
        return i32(-1);
    }
    object_decref(empty_tuple);
    replace_exc_field(op, PyNameErrorObject_NAME, object_xnew_ref(name));
    return i32(0);
}

impl NameError_clear(op: ptr[PyObject]) -> i32 {
    replace_exc_field(op, PyNameErrorObject_NAME, NULL);
    return BaseException_clear(op);
}

impl NameError_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, NameError_clear);
}

impl NameError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(op, [PyNameErrorObject_NAME], visitor, arg);
}

impl AttributeError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, NULL) == -1 {
        return i32(-1);
    }
    empty_tuple = PyTuple_New(0);
    if not empty_tuple {
        return i32(-1);
    }
    name: ptr[PyObject] = NULL;
    ob: ptr[PyObject] = NULL;
    if PyArg_ParseTupleAndKeywords(
        empty_tuple,
        kwds,
        ptr[u8]("|$OO:AttributeError"),
        ptr(addressof(attribute_error_keywords)),
        &mut name,
        &mut ob
    )
        == 0 {
        object_decref(empty_tuple);
        return i32(-1);
    }
    object_decref(empty_tuple);
    replace_exc_field(op, PyAttributeErrorObject_NAME, object_xnew_ref(name));
    replace_exc_field(op, PyAttributeErrorObject_OBJ, object_xnew_ref(ob));
    return i32(0);
}

impl AttributeError_clear(op: ptr[PyObject]) -> i32 {
    replace_exc_field(op, PyAttributeErrorObject_OBJ, NULL);
    replace_exc_field(op, PyAttributeErrorObject_NAME, NULL);
    return BaseException_clear(op);
}

impl AttributeError_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, AttributeError_clear);
}

impl AttributeError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(
        op, [PyAttributeErrorObject_OBJ, PyAttributeErrorObject_NAME], visitor, arg
    );
}

impl AttributeError_getstate(
    op: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    d = base_field(op, 0);
    name = exc_field(op, PyAttributeErrorObject_NAME);
    args = exc_args(op);
    if name or args {
        state = PyDict_Copy(d) if d else PyDict_New();
        if not state {
            return NULL;
        }
        if (name and PyDict_SetItemString(state, ptr[u8]("name"), name) < 0)
            or (args and PyDict_SetItemString(state, ptr[u8]("args"), args) < 0) {
            object_decref(state);
            return NULL;
        }
        return state;
    }
    return object_new_ref(d or Py_None);
}

impl AttributeError_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    state = AttributeError_getstate(op, NULL);
    if not state {
        return NULL;
    }
    result = PyTuple_Pack(3, ptr(object_type(op)), exc_args(op), state);
    object_decref(state);
    return result;
}

impl syntax_fields -> list[i64] {
    return [
        PySyntaxErrorObject_MSG,
        PySyntaxErrorObject_FILENAME,
        PySyntaxErrorObject_LINENO,
        PySyntaxErrorObject_OFFSET,
        PySyntaxErrorObject_END_LINENO,
        PySyntaxErrorObject_END_OFFSET,
        PySyntaxErrorObject_TEXT,
        PySyntaxErrorObject_PRINT_FILE_AND_LINE,
        PySyntaxErrorObject_METADATA
    ];
}

impl SyntaxError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    lenargs = object_size(args);
    if BaseException_init(op, args, kwds) == -1 {
        return i32(-1);
    }
    if lenargs >= 1 {
        replace_exc_field(
            op, PySyntaxErrorObject_MSG, object_new_ref(tuple_get_item(args, 0))
        );
    }
    if lenargs == 2 {
        info = PySequence_Tuple(tuple_get_item(args, 1));
        if not info {
            return i32(-1);
        }
        filename: ptr[PyObject] = NULL;
        lineno: ptr[PyObject] = NULL;
        offset: ptr[PyObject] = NULL;
        text: ptr[PyObject] = NULL;
        end_lineno: ptr[PyObject] = NULL;
        end_offset: ptr[PyObject] = NULL;
        metadata: ptr[PyObject] = NULL;
        if PyArg_ParseTuple(
            info,
            ptr[u8]("OOOO|OOO"),
            &mut filename,
            &mut lineno,
            &mut offset,
            &mut text,
            &mut end_lineno,
            &mut end_offset,
            &mut metadata
        )
            == 0 {
            object_decref(info);
            return i32(-1);
        }
        replace_exc_field(op, PySyntaxErrorObject_FILENAME, object_new_ref(filename));
        replace_exc_field(op, PySyntaxErrorObject_LINENO, object_new_ref(lineno));
        replace_exc_field(op, PySyntaxErrorObject_OFFSET, object_new_ref(offset));
        replace_exc_field(op, PySyntaxErrorObject_TEXT, object_new_ref(text));
        replace_exc_field(
            op, PySyntaxErrorObject_END_LINENO, object_xnew_ref(end_lineno)
        );
        replace_exc_field(
            op, PySyntaxErrorObject_END_OFFSET, object_xnew_ref(end_offset)
        );
        replace_exc_field(op, PySyntaxErrorObject_METADATA, object_xnew_ref(metadata));
        object_decref(info);
        if exc_field(op, PySyntaxErrorObject_END_LINENO)
            and not exc_field(op, PySyntaxErrorObject_END_OFFSET) {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("end_offset must be provided when end_lineno is provided")
            );
            return i32(-1);
        }
    }
    return i32(0);
}

impl SyntaxError_clear(op: ptr[PyObject]) -> i32 {
    for offset in syntax_fields() {
        replace_exc_field(op, offset, NULL);
    }
    return BaseException_clear(op);
}

impl SyntaxError_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, SyntaxError_clear);
}

impl SyntaxError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return exc_traverse(op, syntax_fields(), visitor, arg);
}

impl my_basename(name: ptr[PyObject]) -> ptr[PyObject] {
    size = PyUnicode_GetLength(name);
    offset: i64 = 0;
    for i in range(size) {
        if PyUnicode_ReadChar(name, i) == u32(47) {
            offset = i + 1;
        }
    }
    if offset != 0 {
        return PyUnicode_Substring(name, offset, size);
    }
    return object_new_ref(name);
}

impl SyntaxError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    msg = or_none(exc_field(op, PySyntaxErrorObject_MSG));
    filename_field = exc_field(op, PySyntaxErrorObject_FILENAME);
    filename: ptr[PyObject] = NULL;
    if filename_field
        and type_has_feature(
            object_type(filename_field), Py_TPFLAGS_UNICODE_SUBCLASS
        ) {
        filename = my_basename(filename_field);
        if not filename {
            return NULL;
        }
    }
    lineno = exc_field(op, PySyntaxErrorObject_LINENO);
    have_lineno = lineno
        and object_is_type(lineno, ptr[PyTypeObject](addressof(PyLong_Type)));
    if not filename and not have_lineno {
        return PyObject_Str(msg);
    }

    overflow: i32 = 0;
    result: ptr[PyObject] = NULL;

    if filename and have_lineno {
        result = PyUnicode_FromFormat(
            "%S (%U, line %ld)",
            msg,
            filename,
            PyLong_AsLongAndOverflow(lineno, &mut overflow)
        );
    } elif filename {
        result = PyUnicode_FromFormat("%S (%U)", msg, filename);
    } else {
        result = PyUnicode_FromFormat(
            "%S (line %ld)", msg, PyLong_AsLongAndOverflow(lineno, &mut overflow)
        );
    }
    object_xdecref(filename);
    return result;
}

impl KeyError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    args = exc_args(op);
    if object_size(args) == 1 {
        return PyObject_Repr(tuple_get_item(args, 0));
    }
    return BaseException_str(op);
}


impl uerr_of(op: ptr[PyObject]) -> ptr[PyUnicodeErrorObject] {
    return ptr[PyUnicodeErrorObject](op);
}

impl uerr_encoding(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](uerr_of(op).view(1)[0].encoding);
}

impl uerr_object(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](uerr_of(op).view(1)[0].object);
}

impl uerr_reason(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](uerr_of(op).view(1)[0].reason);
}

impl uerr_store(op: ptr[PyObject], which: int, value: ptr[PyObject]) {
    u = uerr_of(op);
    old: ptr[PyObject] = NULL;
    if which == 0 {
        old = uerr_encoding(op);
        u.view(1)[0].encoding = value;
    } elif which == 1 {
        old = uerr_object(op);
        u.view(1)[0].object = value;
    } else {
        old = uerr_reason(op);
        u.view(1)[0].reason = value;
    }
    object_xdecref(old);
}

impl check_unicode_error_attribute(
    attr: ptr[PyObject], name: str, as_bytes: bool
) -> i32 {
    if not attr {
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("UnicodeError '%s' attribute is not set"), name
        );
        return i32(-1);
    }
    flag = Py_TPFLAGS_BYTES_SUBCLASS if as_bytes else Py_TPFLAGS_UNICODE_SUBCLASS;
    if not type_has_feature(object_type(attr), flag) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("UnicodeError '%s' attribute must be a %s"),
            name,
            "bytes" if as_bytes else "string"
        );
        return i32(-1);
    }
    return i32(0);
}

impl as_unicode_error_attribute(
    attr: ptr[PyObject], name: str, as_bytes: bool
) -> ptr[PyObject] {
    if check_unicode_error_attribute(attr, name, as_bytes) < 0 {
        return NULL;
    }
    return object_new_ref(attr);
}

impl check_unicode_error_type(op: ptr[PyObject], expect_type: str) -> i32 {
    if not object_type_check(op, addressof(_PyExc_UnicodeError)) {
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("expecting a %s object, got %T"), expect_type, op
        );
        return i32(-1);
    }
    return i32(0);
}

impl unicode_error_adjust_start(start_in: i64, objlen: i64) -> i64 {
    start = max(start_in, 0);
    if start >= objlen {
        start = 0 if objlen == 0 else objlen - 1;
    }
    return start;
}

impl unicode_error_adjust_end(end_in: i64, objlen: i64) -> i64 {
    return min(max(end_in, 1), objlen);
}

impl unicode_error_params(
    op: ptr[PyObject], as_bytes: bool
) -> tuple[i32, ptr[PyObject], i64, i64, i64, i64] {
    r = as_unicode_error_attribute(uerr_object(op), "object", as_bytes);
    if not r {
        return (i32(-1), NULL, 0, 0, 0, 0);
    }
    n = object_size(r) if as_bytes else PyUnicode_GetLength(r);
    start = unicode_error_adjust_start(uerr_of(op).view(1)[0].start, n);
    end = unicode_error_adjust_end(uerr_of(op).view(1)[0].end, n);
    return (i32(0), r, n, start, end, max(end - start, 0));
}

impl store_i64(target: ptr[i64], value: i64) {
    if target {
        target.view(1)[0] = value;
    }
}

impl unicode_error_get_start(
    op: ptr[PyObject], start: ptr[i64], as_bytes: bool
) -> i32 {
    (status, r, n, s, e, slen) = unicode_error_params(op, as_bytes);
    if status < 0 {
        return i32(-1);
    }
    object_decref(r);
    store_i64(start, s);
    return i32(0);
}

impl unicode_error_get_end(op: ptr[PyObject], end: ptr[i64], as_bytes: bool) -> i32 {
    (status, r, n, s, e, slen) = unicode_error_params(op, as_bytes);
    if status < 0 {
        return i32(-1);
    }
    object_decref(r);
    store_i64(end, e);
    return i32(0);
}

impl unicode_error_set_reason(op: ptr[PyObject], reason: ptr[u8]) -> i32 {
    value = PyUnicode_FromString(reason);
    if not value {
        return i32(-1);
    }
    uerr_store(op, 2, value);
    return i32(0);
}

impl UnicodeError_clear(op: ptr[PyObject]) -> i32 {
    uerr_store(op, 0, NULL);
    uerr_store(op, 1, NULL);
    uerr_store(op, 2, NULL);
    return BaseException_clear(op);
}

impl UnicodeError_dealloc(op: ptr[PyObject]) {
    exc_dealloc(op, UnicodeError_clear);
}

impl UnicodeError_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    for value in [uerr_encoding(op), uerr_object(op), uerr_reason(op)] {
        status = visit_reference(value, visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return BaseException_traverse(op, visitor, arg);
}

impl UnicodeEncodeError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, kwds) == -1 {
        return i32(-1);
    }

    encoding: ptr[PyObject] = NULL;
    ob: ptr[PyObject] = NULL;
    reason: ptr[PyObject] = NULL;
    start: i64 = -1;
    end: i64 = -1;
    if PyArg_ParseTuple(
        args,
        ptr[u8]("UUnnU"),
        &mut encoding,
        &mut ob,
        &mut start,
        &mut end,
        &mut reason
    )
        == 0 {
        return i32(-1);
    }
    uerr_store(op, 0, object_new_ref(encoding));
    uerr_store(op, 1, object_new_ref(ob));
    uerr_of(op).view(1)[0].start = start;
    uerr_of(op).view(1)[0].end = end;
    uerr_store(op, 2, object_new_ref(reason));
    return i32(0);
}

impl badchar_format(badchar: u32, prefix: str, suffix: str) -> str {
    if badchar <= u32(0xff) {
        return prefix + "'\\x%02x'" + suffix;
    }
    if badchar <= u32(0xffff) {
        return prefix + "'\\u%04x'" + suffix;
    }
    return prefix + "'\\U%08x'" + suffix;
}

impl UnicodeEncodeError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    if not uerr_object(op) {
        return PyUnicode_FromString(ptr[u8](""));
    }

    reason_str = PyObject_Str(uerr_reason(op));
    if not reason_str {
        return NULL;
    }
    encoding_str = PyObject_Str(uerr_encoding(op));
    result: ptr[PyObject] = NULL;

    if encoding_str
        and check_unicode_error_attribute(uerr_object(op), "object", False) == 0 {
        length = PyUnicode_GetLength(uerr_object(op));
        start = uerr_of(op).view(1)[0].start;
        end = uerr_of(op).view(1)[0].end;
        if start >= 0
            and start < length
            and end >= 0
            and end <= length
            and end == start + 1 {
            badchar = PyUnicode_ReadChar(uerr_object(op), start);
            result = PyUnicode_FromFormat(
                badchar_format(
                    badchar,
                    "'%U' codec can't encode character ",
                    " in position %zd: %U"
                ),
                encoding_str,
                i32(badchar),
                start,
                reason_str
            );
        } else {
            result = PyUnicode_FromFormat(
                "'%U' codec can't encode characters in position %zd-%zd: %U",
                encoding_str,
                start,
                end - 1,
                reason_str
            );
        }
    }
    object_decref(reason_str);
    object_xdecref(encoding_str);
    return result;
}

impl UnicodeDecodeError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, kwds) == -1 {
        return i32(-1);
    }
    encoding: ptr[PyObject] = NULL;
    ob: ptr[PyObject] = NULL;
    reason: ptr[PyObject] = NULL;
    start: i64 = -1;
    end: i64 = -1;
    if PyArg_ParseTuple(
        args,
        ptr[u8]("UOnnU"),
        &mut encoding,
        &mut ob,
        &mut start,
        &mut end,
        &mut reason
    )
        == 0 {
        return i32(-1);
    }
    if type_has_feature(object_type(ob), Py_TPFLAGS_BYTES_SUBCLASS) {
        object_incref(ob);
    } else {
        view = ptr[Py_buffer](PyMem_Calloc(1, 80));
        if not view {
            PyErr_NoMemory();
            return i32(-1);
        }
        if PyObject_GetBuffer(ob, view, PyBUF_SIMPLE) != 0 {
            PyMem_Free(ptr(view));
            return i32(-1);
        }
        ob = PyBytes_FromStringAndSize(
            ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
        );
        PyBuffer_Release(view);
        PyMem_Free(ptr(view));
        if not ob {
            return i32(-1);
        }
    }
    uerr_store(op, 0, object_new_ref(encoding));

    uerr_store(op, 1, ob);
    uerr_of(op).view(1)[0].start = start;
    uerr_of(op).view(1)[0].end = end;
    uerr_store(op, 2, object_new_ref(reason));
    return i32(0);
}

impl UnicodeDecodeError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    if not uerr_object(op) {
        return PyUnicode_FromString(ptr[u8](""));
    }
    reason_str = PyObject_Str(uerr_reason(op));
    if not reason_str {
        return NULL;
    }
    encoding_str = PyObject_Str(uerr_encoding(op));
    result: ptr[PyObject] = NULL;
    if encoding_str
        and check_unicode_error_attribute(uerr_object(op), "object", True) == 0 {
        ob = uerr_object(op);
        length = object_size(ob);
        start = uerr_of(op).view(1)[0].start;
        end = uerr_of(op).view(1)[0].end;
        if start >= 0
            and start < length
            and end >= 0
            and end <= length
            and end == start + 1 {
            badbyte = i32((ptr[u8](PyBytes_AsString(ob)) + start).view(1)[0]);
            result = PyUnicode_FromFormat(
                "'%U' codec can't decode byte 0x%02x in position %zd: %U",
                encoding_str,
                badbyte,
                start,
                reason_str
            );
        } else {
            result = PyUnicode_FromFormat(
                "'%U' codec can't decode bytes in position %zd-%zd: %U",
                encoding_str,
                start,
                end - 1,
                reason_str
            );
        }
    }
    object_decref(reason_str);
    object_xdecref(encoding_str);
    return result;
}

impl UnicodeTranslateError_init(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if BaseException_init(op, args, kwds) == -1 {
        return i32(-1);
    }
    ob: ptr[PyObject] = NULL;
    reason: ptr[PyObject] = NULL;
    start: i64 = -1;
    end: i64 = -1;
    if PyArg_ParseTuple(
        args, ptr[u8]("UnnU"), &mut ob, &mut start, &mut end, &mut reason
    )
        == 0 {
        return i32(-1);
    }
    uerr_store(op, 1, object_new_ref(ob));
    uerr_of(op).view(1)[0].start = start;
    uerr_of(op).view(1)[0].end = end;
    uerr_store(op, 2, object_new_ref(reason));
    return i32(0);
}

impl UnicodeTranslateError_str(op: ptr[PyObject]) -> ptr[PyObject] {
    if not uerr_object(op) {
        return PyUnicode_FromString(ptr[u8](""));
    }
    reason_str = PyObject_Str(uerr_reason(op));
    if not reason_str {
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    if check_unicode_error_attribute(uerr_object(op), "object", False) == 0 {
        length = PyUnicode_GetLength(uerr_object(op));
        start = uerr_of(op).view(1)[0].start;
        end = uerr_of(op).view(1)[0].end;
        if start >= 0
            and start < length
            and end >= 0
            and end <= length
            and end == start + 1 {
            badchar = PyUnicode_ReadChar(uerr_object(op), start);
            result = PyUnicode_FromFormat(
                badchar_format(
                    badchar, "can't translate character ", " in position %zd: %U"
                ),
                i32(badchar),
                start,
                reason_str
            );
        } else {
            result = PyUnicode_FromFormat(
                "can't translate characters in position %zd-%zd: %U",
                start,
                end - 1,
                reason_str
            );
        }
    }
    object_decref(reason_str);
    return result;
}


impl memerrors_freelist_slot -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](
        current_interp() + PyInterpreterState_EXC_MEMERRORS_FREELIST
    );
}

impl memerrors_numfree_slot -> ptr[i32] {
    return ptr[i32](current_interp() + PyInterpreterState_EXC_MEMERRORS_NUMFREE);
}

impl get_memory_error(
    allow_allocation: bool, args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    freelist = memerrors_freelist_slot();
    self = freelist.view(1)[0];
    if self {
        freelist.view(1)[0] = base_field(self, 0);
        numfree = memerrors_numfree_slot();
        numfree.view(1)[0] = numfree.view(1)[0] - i32(1);
        base_of(self).view(1)[0].dict = NULL;

        base_of(self).view(1)[0].args = PyTuple_New(0);
        _Py_NewReference(self);
        object_gc_track(self);
        return self;
    }
    if not allow_allocation {
        return object_new_ref(
            ptr[PyObject](
                current_interp() + PyInterpreterState_LAST_RESORT_MEMORY_ERROR
            )
        );
    }
    return BaseException_new(PyExc_MemoryError, args, kwds);
}

impl MemoryError_new(
    type: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if type != PyExc_MemoryError {
        return BaseException_new(type, args, kwds);
    }
    return get_memory_error(True, args, kwds);
}

impl MemoryError_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    BaseException_clear(op);
    if not object_is_type(op, addressof(_PyExc_MemoryError)) {
        type_free(op);
        return;
    }
    numfree = memerrors_numfree_slot();
    if i64(numfree.view(1)[0]) < MEMERRORS_SAVE {
        freelist = memerrors_freelist_slot();
        base_of(op).view(1)[0].dict = freelist.view(1)[0];
        freelist.view(1)[0] = op;
        numfree.view(1)[0] = numfree.view(1)[0] + i32(1);
        return;
    }
    type_free(op);
}

impl preallocate_memerrors -> i32 {
    errors: list[ptr[PyObject]] = [];
    for i in range(MEMERRORS_SAVE) {
        error = MemoryError_new(PyExc_MemoryError, NULL, NULL);
        if not error {
            for made in errors {
                object_decref(made);
            }
            return i32(-1);
        }
        errors.append(error);
    }
    for error in errors {
        object_decref(error);
    }
    return i32(0);
}

impl free_preallocated_memerrors {
    freelist = memerrors_freelist_slot();
    while freelist.view(1)[0] {
        self = freelist.view(1)[0];
        freelist.view(1)[0] = base_field(self, 0);
        type_free(self);
    }
}

impl static_exceptions -> list[tuple[ptr[PyTypeObject], str]] {
    return [
        (addressof(_PyExc_BaseException), "BaseException"),
        (addressof(_PyExc_BaseExceptionGroup), "BaseExceptionGroup"),
        (addressof(_PyExc_Exception), "Exception"),
        (addressof(_PyExc_GeneratorExit), "GeneratorExit"),
        (addressof(_PyExc_KeyboardInterrupt), "KeyboardInterrupt"),
        (addressof(_PyExc_SystemExit), "SystemExit"),
        (addressof(_PyExc_ArithmeticError), "ArithmeticError"),
        (addressof(_PyExc_AssertionError), "AssertionError"),
        (addressof(_PyExc_AttributeError), "AttributeError"),
        (addressof(_PyExc_BufferError), "BufferError"),
        (addressof(_PyExc_EOFError), "EOFError"),
        (addressof(_PyExc_ImportError), "ImportError"),
        (addressof(_PyExc_LookupError), "LookupError"),
        (addressof(_PyExc_MemoryError), "MemoryError"),
        (addressof(_PyExc_NameError), "NameError"),
        (addressof(_PyExc_OSError), "OSError"),
        (addressof(_PyExc_ReferenceError), "ReferenceError"),
        (addressof(_PyExc_RuntimeError), "RuntimeError"),
        (addressof(_PyExc_StopAsyncIteration), "StopAsyncIteration"),
        (addressof(_PyExc_StopIteration), "StopIteration"),
        (addressof(_PyExc_SyntaxError), "SyntaxError"),
        (addressof(_PyExc_SystemError), "SystemError"),
        (addressof(_PyExc_TypeError), "TypeError"),
        (addressof(_PyExc_ValueError), "ValueError"),
        (addressof(_PyExc_Warning), "Warning"),
        (addressof(_PyExc_FloatingPointError), "FloatingPointError"),
        (addressof(_PyExc_OverflowError), "OverflowError"),
        (addressof(_PyExc_ZeroDivisionError), "ZeroDivisionError"),
        (addressof(_PyExc_BytesWarning), "BytesWarning"),
        (addressof(_PyExc_DeprecationWarning), "DeprecationWarning"),
        (addressof(_PyExc_EncodingWarning), "EncodingWarning"),
        (addressof(_PyExc_FutureWarning), "FutureWarning"),
        (addressof(_PyExc_ImportWarning), "ImportWarning"),
        (addressof(_PyExc_PendingDeprecationWarning), "PendingDeprecationWarning"),
        (addressof(_PyExc_ResourceWarning), "ResourceWarning"),
        (addressof(_PyExc_RuntimeWarning), "RuntimeWarning"),
        (addressof(_PyExc_SyntaxWarning), "SyntaxWarning"),
        (addressof(_PyExc_UnicodeWarning), "UnicodeWarning"),
        (addressof(_PyExc_UserWarning), "UserWarning"),
        (addressof(_PyExc_BlockingIOError), "BlockingIOError"),
        (addressof(_PyExc_ChildProcessError), "ChildProcessError"),
        (addressof(_PyExc_ConnectionError), "ConnectionError"),
        (addressof(_PyExc_FileExistsError), "FileExistsError"),
        (addressof(_PyExc_FileNotFoundError), "FileNotFoundError"),
        (addressof(_PyExc_InterruptedError), "InterruptedError"),
        (addressof(_PyExc_IsADirectoryError), "IsADirectoryError"),
        (addressof(_PyExc_NotADirectoryError), "NotADirectoryError"),
        (addressof(_PyExc_PermissionError), "PermissionError"),
        (addressof(_PyExc_ProcessLookupError), "ProcessLookupError"),
        (addressof(_PyExc_TimeoutError), "TimeoutError"),
        (addressof(_PyExc_IndentationError), "IndentationError"),
        (addressof(_PyExc_IncompleteInputError), "_IncompleteInputError"),
        (addressof(_PyExc_IndexError), "IndexError"),
        (addressof(_PyExc_KeyError), "KeyError"),
        (addressof(_PyExc_ModuleNotFoundError), "ModuleNotFoundError"),
        (addressof(_PyExc_NotImplementedError), "NotImplementedError"),
        (addressof(_PyExc_PythonFinalizationError), "PythonFinalizationError"),
        (addressof(_PyExc_RecursionError), "RecursionError"),
        (addressof(_PyExc_UnboundLocalError), "UnboundLocalError"),
        (addressof(_PyExc_UnicodeError), "UnicodeError"),
        (addressof(_PyExc_BrokenPipeError), "BrokenPipeError"),
        (addressof(_PyExc_ConnectionAbortedError), "ConnectionAbortedError"),
        (addressof(_PyExc_ConnectionRefusedError), "ConnectionRefusedError"),
        (addressof(_PyExc_ConnectionResetError), "ConnectionResetError"),
        (addressof(_PyExc_TabError), "TabError"),
        (addressof(_PyExc_UnicodeDecodeError), "UnicodeDecodeError"),
        (addressof(_PyExc_UnicodeEncodeError), "UnicodeEncodeError"),
        (addressof(_PyExc_UnicodeTranslateError), "UnicodeTranslateError")
    ];
}

impl status_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl status_err(func: ptr[u8], msg: ptr[u8]) -> PyStatus {
    return PyStatus(_type=_PyStatus_TYPE_ERROR, func=func, err_msg=msg, exitcode=0);
}

impl add_errno(mapping: ptr[PyObject], type: ptr[PyObject], code: i64) -> bool {
    code_obj = PyLong_FromLong(code);
    if not code_obj or PyDict_SetItem(mapping, code_obj, type) != 0 {
        object_xdecref(code_obj);
        return False;
    }
    object_decref(code_obj);
    return True;
}
