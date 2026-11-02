glob Py_LT: int = 0,
     Py_LE: int = 1,
     Py_EQ: int = 2,
     Py_NE: int = 3,
     Py_GT: int = 4,
     Py_GE: int = 5;

glob _PY_SWAPPED_OP: list[int] = [4, 5, 2, 3, 0, 1];

obj PyObj {
    has t: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def mp_subscript(index: PyObj) -> PyObj;
    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj;
    def mp_del_subscript(index: PyObj) -> PyObj;
    def tp_iter -> PyObj;
    def tp_bool -> bool;
    def tp_getattro(name: str) -> PyObj;
    def tp_setattro(name: str, value: PyObj) -> PyObj;
    def tp_del_attr(name: str) -> PyObj;
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
    def tp_hashkey -> PyObj;
    def tp_type_name -> str;
    def to_index -> PyObj;
}

def int_true_divide(av: int, bv: int) -> PyObj;

obj PyInt(PyObj) {
    has val: int;

    def to_index -> PyObj;
    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
    def tp_getattro(name: str) -> PyObj;
}

obj PyStr(PyObj) {
    has val: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def mp_subscript(index: PyObj) -> PyObj;
    def tp_iter -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
}

obj PyBytes(PyObj) {
    has val: list[int];

    def mp_subscript(index: PyObj) -> PyObj;
    def tp_iter -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
}

def _number_getattro(name: str, real: int) -> PyObj;

obj PyFloat(PyObj) {
    has val: float;

    def _coerce(other: PyObj) -> tuple[bool, float];
    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
}

obj PyBool(PyObj) {
    has val: bool;

    def tp_bool -> bool;
    def to_index -> PyObj;
    def tp_hashkey -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def tp_getattro(name: str) -> PyObj;
}

obj PyNoneType(PyObj) {
    def tp_getattro(name: str) -> PyObj;
    def tp_bool -> bool;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def tp_hashkey -> PyObj;
}

obj PyEllipsis(PyObj) {
    def tp_hashkey -> PyObj;
}

def _cx_add(ar: float, ai: float, br: float, bi: float) -> tuple[float, float];

def _cx_sub(ar: float, ai: float, br: float, bi: float) -> tuple[float, float];

def _cx_mul(ar: float, ai: float, br: float, bi: float) -> tuple[float, float];

def _cx_is_inf(v: float) -> bool;

def _cx_div(ar: float, ai: float, br: float, bi: float) -> tuple[float, float];

def _cx_pow_int(ar: float, ai: float, exp: int) -> tuple[int, float, float];

obj PyComplex(PyObj) {
    has real: float,
        imag: float;

    def _coerce(other: PyObj) -> tuple[bool, float, float];
    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def _reflected_binop(kind: int, other: PyObj) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
    def tp_getattro(name: str) -> PyObj;
}

obj PyComplexMethod(PyObj) {
    has target: PyComplex,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
}

obj PySliceIndices(PyObj) {
    has sl: PySlice;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
}

obj PySlice(PyObj) {
    has start: PyObj,
        stop: PyObj,
        step: PyObj;

    def tp_getattro(name2: str) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
}

obj PyTuple(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def mp_subscript(index: PyObj) -> PyObj;
    def tp_iter -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
}

obj PyStructTime(PyTuple) {
    def tp_getattro(name: str) -> PyObj;
    def tp_repr -> PyObj;
}

def _struct_time_field_repr(v: PyObj) -> str;

obj PyList(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def mp_subscript(index: PyObj) -> PyObj;
    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj;
    def mp_del_subscript(index: PyObj) -> PyObj;
    def tp_iter -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def tp_bool -> bool;
}

obj PyHostProxy(PyObj) {
    has val: any;
}

obj PyCode(PyObj) {
    has argcount: int,
        posonlyargcount: int,
        kwonlyargcount: int,
        stacksize: int,
        flags: int,
        co_code: list[int],
        consts: list[PyObj],
        names: list[str],
        varnames: list[str],
        cellvars: list[str],
        freevars: list[str],
        filename: str,
        name: str,
        qualname: str,
        firstlineno: int,
        linetable: list[int],
        exceptiontable: list[int];

    def tp_hashkey -> PyObj;
    def tp_getattro(name: str) -> PyObj;
}

obj PyCell(PyObj) {
    has val: PyObj,
        filled: bool = False;
}

obj PyTypeAlias(PyObj) {
    has name: str,
        type_params: PyObj,
        value_fn: PyObj,
        computed: bool = False,
        cached_value: PyObj = py_none();

    def tp_getattro(name: str) -> PyObj;
}

obj PyTypeVar(PyObj) {
    has name: str,
        evaluate_bound: PyObj = py_none(),
        evaluate_constraints: PyObj = py_none(),
        evaluate_default: PyObj = py_none(),
        cached_bound: PyObj = py_none(),
        cached_constraints: PyObj = py_none(),
        cached_default: PyObj = py_none(),
        bound_resolved: bool = False,
        constraints_resolved: bool = False,
        default_resolved: bool = False,
        infer_variance: bool = True,
        covariant: bool = False,
        contravariant: bool = False;

    def tp_getattro(name: str) -> PyObj;
}

glob _DICT_SLOT_COLL: str = "\x00";

obj DictEntry {
    has key: PyObj,
        value: PyObj;
}

def _dict_ensure_order(d: PyDict) -> PyObj;

def _set_ensure_order(s: PySet) -> PyObj;

def _dict_new_slot(d: PyDict, hk: str) -> str;

def _set_new_slot(s: PySet, hk: str) -> str;

def _dict_remove_slot(d: PyDict, sk: str) -> PyObj;

def _set_remove_slot(s: PySet, sk: str) -> PyObj;

def _dict_find_entry(d: PyDict, key: PyObj) -> PyObj;

def _set_push_member(
    items: dict[str, PyObj], order: list[str], member: PyObj
) -> PyObj;

def _set_find_entry(s: PySet, member: PyObj) -> PyObj;

def _set_remove_member(
    items: dict[str, PyObj], order: list[str], member: PyObj
) -> PyObj;

obj PyDictIter(PyObj) {
    has d: PyDict,
        keys: list[str],
        index: int,
        snap_version: int,
        mode: str;

    def dictiter_stale -> bool;
}

obj PyDict(PyObj) {
    has items: dict[str, DictEntry],
        order: list[str] = [],
        version: int = 0;

    def tp_iter -> PyObj;
    def dict_iter(mode: str) -> PyDictIter;
    def mp_subscript(index: PyObj) -> PyObj;
    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj;
    def mp_del_subscript(index: PyObj) -> PyObj;
    def dict_set(keyobj: PyObj, value: PyObj) -> PyObj;
    def dict_equal(b: PyDict) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
    def dict_contains(keyobj: PyObj) -> bool;
    def dict_keys -> list[PyObj];
    def dict_values -> list[PyObj];
    def dict_str_map -> dict[str, PyObj];
    def tp_getattro(name: str) -> PyObj;
    def tp_bool -> bool;
}

obj PySet(PyObj) {
    has items: dict[str, PyObj],
        order: list[str] = [],
        frozen: bool = False;

    def set_contains(member: PyObj) -> bool;
    def set_lookup(member: PyObj) -> PyObj;
    def set_add(member: PyObj) -> PyObj;
    def set_pop -> PyObj;
    def set_discard(member: PyObj) -> PyObj;
    def set_clear -> PyObj;
    def set_copy -> PyObj;
    def set_members -> list[PyObj];
    def tp_iter -> PyObj;
    def tp_bool -> bool;
    def tp_hashkey -> PyObj;
    def nb_binop(kind: int, other: PyObj) -> PyObj;
    def tp_richcompare(kind: int, other: PyObj) -> PyObj;
}

def _richcompare_truth(res: PyObj) -> int;

def py_rich_compare(v: PyObj, w: PyObj, op: int) -> PyObj;

def _base_type_name(v: PyObj) -> str;

def py_ordering_type_error(
    op_kind: int, v: PyObj, w: PyObj, type_name_fn: Callable[[PyObj], str]
) -> PyObj;

def py_rich_compare_bool(v: PyObj, w: PyObj, op: int) -> int;

def _cmp3(a: int, b: int) -> int;

def _cmp3_str(a: str, b: str) -> int;

def _bool_from_cmp(cmp: int, op: int) -> PyObj;

def _unhashable_error(what: str, v: PyObj) -> PyObj;

def _set_contains_elem(so: PySet, key: PyObj) -> PyObj;

def _pyset_richcompare_na(op: int, v: PySet, w: PySet) -> PyObj;

obj PyTraceback(PyObj) {
    has tb_next: any = None,
        code: any = None,
        tb_lineno: int = 0,
        tb_lasti: int = 0;

    def tp_getattro(name2: str) -> PyObj;
}

obj PyTracebackFrame(PyObj) {
    has frame_code: any,
        frame_lineno: int;

    def tp_getattro(name2: str) -> PyObj;
}

glob EXC_PARENT: dict[str, str] = {
         "BaseExceptionGroup": "BaseException",
         "GeneratorExit": "BaseException",
         "KeyboardInterrupt": "BaseException",
         "SystemExit": "BaseException",
         "Exception": "BaseException",
         "ArithmeticError": "Exception",
         "FloatingPointError": "ArithmeticError",
         "OverflowError": "ArithmeticError",
         "ZeroDivisionError": "ArithmeticError",
         "AssertionError": "Exception",
         "AttributeError": "Exception",
         "BufferError": "Exception",
         "EOFError": "Exception",
         "ExceptionGroup": "Exception",
         "FrozenInstanceError": "AttributeError",
         "ImportError": "Exception",
         "ModuleNotFoundError": "ImportError",
         "LookupError": "Exception",
         "IndexError": "LookupError",
         "KeyError": "LookupError",
         "MemoryError": "Exception",
         "NameError": "Exception",
         "UnboundLocalError": "NameError",
         "OSError": "Exception",
         "BlockingIOError": "OSError",
         "ChildProcessError": "OSError",
         "ConnectionError": "OSError",
         "BrokenPipeError": "ConnectionError",
         "ConnectionAbortedError": "ConnectionError",
         "ConnectionRefusedError": "ConnectionError",
         "ConnectionResetError": "ConnectionError",
         "FileExistsError": "OSError",
         "FileNotFoundError": "OSError",
         "InterruptedError": "OSError",
         "IsADirectoryError": "OSError",
         "NotADirectoryError": "OSError",
         "PermissionError": "OSError",
         "ProcessLookupError": "OSError",
         "TimeoutError": "OSError",
         "ReferenceError": "Exception",
         "RuntimeError": "Exception",
         "NotImplementedError": "RuntimeError",
         "PythonFinalizationError": "RuntimeError",
         "RecursionError": "RuntimeError",
         "StopAsyncIteration": "Exception",
         "StopIteration": "Exception",
         "SyntaxError": "Exception",
         "IndentationError": "SyntaxError",
         "TabError": "IndentationError",
         "_IncompleteInputError": "SyntaxError",
         "SystemError": "Exception",
         "TypeError": "Exception",
         "ValueError": "Exception",
         "UnicodeError": "ValueError",
         "UnicodeDecodeError": "UnicodeError",
         "UnicodeEncodeError": "UnicodeError",
         "UnicodeTranslateError": "UnicodeError",
         "Warning": "Exception",
         "BytesWarning": "Warning",
         "DeprecationWarning": "Warning",
         "EncodingWarning": "Warning",
         "FutureWarning": "Warning",
         "ImportWarning": "Warning",
         "PendingDeprecationWarning": "Warning",
         "ResourceWarning": "Warning",
         "RuntimeWarning": "Warning",
         "SyntaxWarning": "Warning",
         "UnicodeWarning": "Warning",
         "UserWarning": "Warning",

     },
     EXC_EXTRA_PARENTS: dict[str, str] = {"ExceptionGroup": "BaseExceptionGroup",},
     OSERROR_ERRNO_MAP: dict[int, str] = {
         1: "PermissionError",
         2: "FileNotFoundError",
         3: "ProcessLookupError",
         4: "InterruptedError",
         11: "BlockingIOError",
         13: "PermissionError",
         17: "FileExistsError",
         20: "NotADirectoryError",
         21: "IsADirectoryError",
         32: "BrokenPipeError",
         103: "ConnectionAbortedError",
         104: "ConnectionResetError",
         108: "BrokenPipeError",
         110: "TimeoutError",
         111: "ConnectionRefusedError",
         114: "BlockingIOError",
         115: "BlockingIOError",

     };

def is_builtin_exception_name(name: str) -> bool;

def exc_is_subclass_of(name: str, base: str) -> bool;

def _exc_field_int(fields: dict[str, PyObj], key: str) -> int;

def _exc_field_str(fields: dict[str, PyObj], key: str) -> str;

def _exc_has_value(fields: dict[str, PyObj], key: str) -> bool;

def _oserror_parse(args: list[PyObj]) -> dict[str, PyObj];

def _construct_oserror(name: str, args: list[PyObj]) -> PyException;

def _construct_import_error(
    name: str, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyException;

def _construct_syntax_error(name: str, args: list[PyObj]) -> PyException;

def _construct_unicode_error(name: str, args: list[PyObj]) -> PyObj;

def _py_sequence_tuple(o: PyObj, out: list[PyObj]) -> bool;

def _construct_exc_group(
    name: str, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj;

obj PyEgroupTypeMember(PyObj) {
    has name: str;
}

obj PyExceptionType(PyObj) {
    has name: str;

    def tp_getattro(name2: str) -> PyObj;
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
}

obj ExcSetStateFn(PyObj) {
    has exc: PyException;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
}

def _exception_args_from_value(value: PyObj) -> PyObj;

obj PyException(PyObj) {
    has type_name: str,
        message: str,
        args: list[PyObj] = [],
        raw: any = None,
        cause: any = None,
        context: any = None,
        value: any = None,
        traceback: any = None,
        suppress_context: any = None,
        family: str = "",
        type_fields: dict[str, PyObj] = {};

    def tp_getattro(name: str) -> PyObj;
    def tp_setattro(name: str, value: PyObj) -> PyObj;
}

obj PyExcGroup(PyException) {
    has excs: list[PyObj] = [];

    def tp_getattro(name: str) -> PyObj;
    def tp_setattro(name: str, value: PyObj) -> PyObj;
}

obj PyError(PyObj) {
    has exception: PyException,
        lasti: int = -1;
}

obj PyNotImplementedSentinel(PyObj) {
    has _marker: bool = True;
}

glob PY_NOT_IMPLEMENTED: PyNotImplementedSentinel = PyNotImplementedSentinel(
         t="notimplemented"
     );

obj PyIter(PyObj) {
    has items: list[PyObj],
        index: int;

    def tp_iter -> PyObj;
}

obj PyCallableIter(PyObj) {
    has fn: PyObj,
        sentinel: PyObj,
        exhausted: bool = False;

    def tp_iter -> PyObj;
}

obj PySeqIter(PyObj) {
    has seq: PyObj,
        index: int = 0;

    def tp_iter -> PyObj;
    def tp_getattro(name: str) -> PyObj;
}

obj PySeqIterSetState(PyObj) {
    has it: PySeqIter;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
}

obj PyHandler(PyObj) {
    has start: int,
        end: int,
        target: int,
        depth: int,
        lasti: bool;
}

def bytes_value(o: PyObj) -> list[int];

def tuple_value(o: PyObj) -> list[PyObj];

def str_value(o: PyObj) -> str;

def str_values(o: PyObj) -> list[str];

def int_values(o: PyObj) -> list[int];

def _cmp_int_vs_float(a: int, fv: float) -> int;

def expect_int(o: PyObj) -> int;

def expect_str(o: PyObj) -> str;

def _repr_hex2(n: int) -> str;

def _repr_unicode_escape(cp: int) -> str;

def _repr_unicode_char(ch: str, quote: int) -> str;

def str_repr_text(val: str) -> str;

def dict_key_repr(index: PyObj) -> str;

def expect_float(o: PyObj) -> float;

def expect_bool(o: PyObj) -> bool;

def list_value(o: PyObj) -> list[PyObj];

def concat_items(left: list[PyObj], right: list[PyObj]) -> list[PyObj];

def find_name(names: list[str], name: str) -> int;

def py_none -> PyObj;

def py_error(type_name: str, message: str) -> PyObj;

def py_error_with_args(type_name: str, message: str, args: list[PyObj]) -> PyObj;

def py_exception_type(name: str) -> PyObj;

def hashkey_str(hk_res: PyObj) -> str;

def hashkey_equal(a: PyObj, b: PyObj) -> bool;

def is_error(value: PyObj) -> bool;

def _zero_step_error(sl: PySlice) -> PyObj;

def _adjust_index(i: int, length: int, neg: bool) -> int;

def _seq_index(index: PyObj, length: int, type_err: str, index_err: str) -> PyObj;

def slice_indices(sl: PySlice, length: int) -> list[int];

def _slice_positions(length: int, sl: PySlice) -> list[int];

def _slice_objs(items: list[PyObj], sl: PySlice) -> list[PyObj];

def _slice_ints(vals: list[int], sl: PySlice) -> list[int];

def _slice_str(s: str, sl: PySlice) -> str;

def _digit_val(c: str) -> int;

def:priv _is_digit(c: str) -> bool;

def _uint_to_str(n: int, base: int, digits: str) -> str;

glob F_MINUS: int = 1,
     F_PLUS: int = 2,
     F_SPACE: int = 4,
     F_ZERO: int = 8,
     F_HASH: int = 16;

def _fmt_int(
    val: int, base: int, digits: str, prefix: str, flags: int, prec: int, width: int
) -> str;

def _int_of(o: PyObj) -> int;

def _is_intlike(o: PyObj) -> bool;

def _pyobj_str(o: PyObj) -> str;

def _pyobj_repr(o: PyObj) -> str;

def _pad_spaces(s: str, width: int, left: bool) -> str;

def _trunc(s: str, prec: int) -> str;

def str_mod_format(fmt: str, args: PyObj) -> PyObj;

obj ShimTypeMarker(PyObj) {
    has tag: str,
        ctor: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj;
    def tp_getattro(name2: str) -> PyObj;
}
