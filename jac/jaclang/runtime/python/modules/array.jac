import from c {
    def memcpy(dest: ptr, src: ptr, n: u64) -> ptr;  def memmove(
        dest: ptr, src: ptr, n: u64
    ) -> ptr;  def PyType_GetModuleByDef(
        type: ptr[PyTypeObject], mod_def: ptr[PyModuleDef]
    ) -> ptr[PyObject];  def _PyBytes_Repeat(
        dest: ptr[u8], len_dest: i64, src: ptr[u8], len_src: i64
    );  def PyFloat_Unpack4(data: ptr[u8], le: i32) -> f64;  def PyFloat_Unpack8(
        data: ptr[u8], le: i32
    ) -> f64;  def PySlice_Unpack(
        op: ptr[PyObject], start: ptr[i64], stop: ptr[i64], step: ptr[i64]
    ) -> i32;  def PySlice_AdjustIndices(
        length: i64, start: ptr[i64], stop: ptr[i64], step: i64
    ) -> i64;  def PyUnicode_AsWideChar(
        unicode: ptr[PyObject], w: ptr[i32], size: i64
    ) -> i64;  def PyUnicode_AsUCS4(
        string: ptr[PyObject], target: ptr[u32], targetsize: i64, copy_null: i32
    ) -> ptr[u32];  def PyUnicode_AsUCS4Copy(string: ptr[PyObject]) -> ptr[u32];  def PyUnicode_DecodeUTF32(
        s: ptr[u8], size: i64, errors: ptr[u8], byteorder: ptr[i32]
    ) -> ptr[PyObject];  def PyUnicode_DecodeUTF16(
        s: ptr[u8], size: i64, errors: ptr[u8], byteorder: ptr[i32]
    ) -> ptr[PyObject];  def jacpy_stack_address(slots: &mut ArrayStack) -> int;  obj ArrayStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject](),
            s8: ptr[PyObject] = ptr[PyObject](),
            s9: ptr[PyObject] = ptr[PyObject]();
    }  obj arraydescr {
        has typecode: u8 = 0,
            itemsize: i32 = 0,
            getitem: Callable[[ptr[arrayobject], i64], ptr[PyObject]] = 0,
            setitem: Callable[[ptr[arrayobject], i64, ptr[PyObject]], i32] = 0,
            compareitems: Callable[[ptr, ptr, i64], i32] = 0,
            formats: ptr[u8] = ptr[u8](),
            is_integer_type: i32 = 0,
            is_signed: i32 = 0;
    }  obj arrayobject {
        has ob_base: PyVarObject,
            ob_item: ptr[u8],
            allocated: i64,
            ob_descr: ptr[arraydescr],
            weakreflist: ptr[PyObject],
            ob_exports: i64;
    }  obj arrayiterobject {
        has ob_base: _object,
            index: i64,
            ao: ptr[arrayobject],
            getitem: Callable[[ptr[arrayobject], i64], ptr[PyObject]];
    }  obj array_state {
        has ArrayType: ptr[PyTypeObject],
            ArrayIterType: ptr[PyTypeObject],
            array_reconstructor: ptr[PyObject],
            str_read: ptr[PyObject],
            str_write: ptr[PyObject],
            str___dict__: ptr[PyObject],
            str_iter: ptr[PyObject];
    }  obj mformatdescr {
        has size: u64 = 0,
            is_signed: i32 = 0,
            is_big_endian: i32 = 0;
    }
}

glob ARRAYOBJECT_SIZE: Final[int] = 64,
     ARRAYOBJECT_WEAKREFLIST: Final[int] = 48,
     ARRAYITEROBJECT_SIZE: Final[int] = 40,
     ARRAY_STATE_SIZE: Final[int] = 56,
     PYVAROBJECT_OB_SIZE: Final[i64] = 16,
     PY_BUFFER_ITEMSIZE: Final[i64] = 24,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     PY_BIG_ENDIAN: Final[i32] = 0,
     SIZEOF_WCHAR_T: Final[int] = 4,
     Py_sq_concat: Final[i32] = 40,
     Py_sq_contains: Final[i32] = 41,
     Py_sq_inplace_concat: Final[i32] = 42,
     Py_sq_inplace_repeat: Final[i32] = 43,
     ARRAY_SLOTS_METHODS: Final[int] = 6,
     ARRAYITER_SLOTS_METHODS: Final[int] = 5;

glob UNKNOWN_FORMAT: Final[i32] = -1,
     UNSIGNED_INT8: Final[i32] = 0,
     SIGNED_INT8: Final[i32] = 1,
     UNSIGNED_INT16_LE: Final[i32] = 2,
     UNSIGNED_INT16_BE: Final[i32] = 3,
     SIGNED_INT16_LE: Final[i32] = 4,
     SIGNED_INT16_BE: Final[i32] = 5,
     UNSIGNED_INT32_LE: Final[i32] = 6,
     UNSIGNED_INT32_BE: Final[i32] = 7,
     SIGNED_INT32_LE: Final[i32] = 8,
     SIGNED_INT32_BE: Final[i32] = 9,
     UNSIGNED_INT64_LE: Final[i32] = 10,
     UNSIGNED_INT64_BE: Final[i32] = 11,
     SIGNED_INT64_LE: Final[i32] = 12,
     SIGNED_INT64_BE: Final[i32] = 13,
     IEEE_754_FLOAT_LE: Final[i32] = 14,
     IEEE_754_FLOAT_BE: Final[i32] = 15,
     IEEE_754_DOUBLE_LE: Final[i32] = 16,
     IEEE_754_DOUBLE_BE: Final[i32] = 17,
     UTF16_LE: Final[i32] = 18,
     UTF16_BE: Final[i32] = 19,
     UTF32_LE: Final[i32] = 20,
     UTF32_BE: Final[i32] = 21,
     MACHINE_FORMAT_CODE_MIN: Final[i32] = 0,
     MACHINE_FORMAT_CODE_MAX: Final[i32] = 21;

glob array_token = ClassToken(),
     arrayiterator_token = ClassToken();

def get_array_state(module: ptr[PyObject]) -> ptr[array_state];

def find_array_state_by_type(tp: ptr[PyTypeObject]) -> ptr[array_state];

def get_array_state_by_class(cls: ptr[PyObject]) -> ptr[array_state];

def array_Check(op: ptr[PyObject], state: ptr[array_state]) -> bool;

def slice_check(op: ptr[PyObject]) -> bool;

def array_resize(self_: ptr[arrayobject], newsize: i64) -> i32;

def out_of_bounds(ap: ptr[arrayobject], i: i64) -> bool;

def b_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def b_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def BB_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def BB_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def u_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def u_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def w_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def w_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def h_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def h_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def HH_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def HH_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def i_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def i_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def II_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def II_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def l_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def l_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def LL_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def LL_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def q_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def q_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def QQ_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def QQ_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def f_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def f_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def d_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject];

def d_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32;

def b_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def BB_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def u_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def w_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def h_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def HH_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def i_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def II_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def l_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def LL_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def q_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

def QQ_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32;

import from c {
    glob:priv descriptors: list[arraydescr] = [
             arraydescr(
                 typecode=u8(98),
                 itemsize=1,
                 getitem=b_getitem,
                 setitem=b_setitem,
                 compareitems=b_compareitems,
                 formats=ptr[u8]("b"),
                 is_integer_type=1,
                 is_signed=1
             ),
             arraydescr(
                 typecode=u8(66),
                 itemsize=1,
                 getitem=BB_getitem,
                 setitem=BB_setitem,
                 compareitems=BB_compareitems,
                 formats=ptr[u8]("B"),
                 is_integer_type=1,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(117),
                 itemsize=i32(SIZEOF_WCHAR_T),
                 getitem=u_getitem,
                 setitem=u_setitem,
                 compareitems=u_compareitems,
                 formats=ptr[u8]("u"),
                 is_integer_type=0,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(119),
                 itemsize=4,
                 getitem=w_getitem,
                 setitem=w_setitem,
                 compareitems=w_compareitems,
                 formats=ptr[u8]("w"),
                 is_integer_type=0,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(104),
                 itemsize=2,
                 getitem=h_getitem,
                 setitem=h_setitem,
                 compareitems=h_compareitems,
                 formats=ptr[u8]("h"),
                 is_integer_type=1,
                 is_signed=1
             ),
             arraydescr(
                 typecode=u8(72),
                 itemsize=2,
                 getitem=HH_getitem,
                 setitem=HH_setitem,
                 compareitems=HH_compareitems,
                 formats=ptr[u8]("H"),
                 is_integer_type=1,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(105),
                 itemsize=4,
                 getitem=i_getitem,
                 setitem=i_setitem,
                 compareitems=i_compareitems,
                 formats=ptr[u8]("i"),
                 is_integer_type=1,
                 is_signed=1
             ),
             arraydescr(
                 typecode=u8(73),
                 itemsize=4,
                 getitem=II_getitem,
                 setitem=II_setitem,
                 compareitems=II_compareitems,
                 formats=ptr[u8]("I"),
                 is_integer_type=1,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(108),
                 itemsize=8,
                 getitem=l_getitem,
                 setitem=l_setitem,
                 compareitems=l_compareitems,
                 formats=ptr[u8]("l"),
                 is_integer_type=1,
                 is_signed=1
             ),
             arraydescr(
                 typecode=u8(76),
                 itemsize=8,
                 getitem=LL_getitem,
                 setitem=LL_setitem,
                 compareitems=LL_compareitems,
                 formats=ptr[u8]("L"),
                 is_integer_type=1,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(113),
                 itemsize=8,
                 getitem=q_getitem,
                 setitem=q_setitem,
                 compareitems=q_compareitems,
                 formats=ptr[u8]("q"),
                 is_integer_type=1,
                 is_signed=1
             ),
             arraydescr(
                 typecode=u8(81),
                 itemsize=8,
                 getitem=QQ_getitem,
                 setitem=QQ_setitem,
                 compareitems=QQ_compareitems,
                 formats=ptr[u8]("Q"),
                 is_integer_type=1,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(102),
                 itemsize=4,
                 getitem=f_getitem,
                 setitem=f_setitem,
                 formats=ptr[u8]("f"),
                 is_integer_type=0,
                 is_signed=0
             ),
             arraydescr(
                 typecode=u8(100),
                 itemsize=8,
                 getitem=d_getitem,
                 setitem=d_setitem,
                 formats=ptr[u8]("d"),
                 is_integer_type=0,
                 is_signed=0
             ),
             arraydescr()
         ]; glob:priv mformat_descriptors: list[mformatdescr] = [
             mformatdescr(size=u64(1), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(1), is_signed=1, is_big_endian=0),
             mformatdescr(size=u64(2), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(2), is_signed=0, is_big_endian=1),
             mformatdescr(size=u64(2), is_signed=1, is_big_endian=0),
             mformatdescr(size=u64(2), is_signed=1, is_big_endian=1),
             mformatdescr(size=u64(4), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(4), is_signed=0, is_big_endian=1),
             mformatdescr(size=u64(4), is_signed=1, is_big_endian=0),
             mformatdescr(size=u64(4), is_signed=1, is_big_endian=1),
             mformatdescr(size=u64(8), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(8), is_signed=0, is_big_endian=1),
             mformatdescr(size=u64(8), is_signed=1, is_big_endian=0),
             mformatdescr(size=u64(8), is_signed=1, is_big_endian=1),
             mformatdescr(size=u64(4), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(4), is_signed=0, is_big_endian=1),
             mformatdescr(size=u64(8), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(8), is_signed=0, is_big_endian=1),
             mformatdescr(size=u64(4), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(4), is_signed=0, is_big_endian=1),
             mformatdescr(size=u64(8), is_signed=0, is_big_endian=0),
             mformatdescr(size=u64(8), is_signed=0, is_big_endian=1)
         ];
}

def newarrayobject(
    type: ptr[PyTypeObject], size: i64, descr: ptr[arraydescr]
) -> ptr[PyObject];

def getarrayitem(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def ins1(self_: ptr[arrayobject], where: i64, v: ptr[PyObject]) -> i32;

def array_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def array_dealloc(op: ptr[PyObject]);

def compare_sizes(vs: i64, ws: i64, op: i32) -> ptr[PyObject];

def array_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def array_length(op: ptr[PyObject]) -> i64;

def array_item(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def array_slice(a: ptr[arrayobject], ilow: i64, ihigh: i64) -> ptr[PyObject];

def array_array_clear_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array___copy___impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array___deepcopy___impl(
    self_: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def array_concat(op: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject];

def array_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def array_del_slice(a: ptr[arrayobject], ilow: i64, ihigh: i64) -> i32;

def array_ass_item(op: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32;

def setarrayitem(a: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32;

def array_iter_extend(self_: ptr[arrayobject], bb: ptr[PyObject]) -> i32;

def array_do_extend(
    state: ptr[array_state], self_: ptr[arrayobject], bb: ptr[PyObject]
) -> i32;

def array_inplace_concat(op: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject];

def array_inplace_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def ins(self_: ptr[arrayobject], where: i64, v: ptr[PyObject]) -> ptr[PyObject];

def array_array_count_impl(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject];

def array_array_index_impl(
    self_: ptr[PyObject], v: ptr[PyObject], start: i64, stop: i64
) -> ptr[PyObject];

def array_contains(self_: ptr[PyObject], v: ptr[PyObject]) -> i32;

def array_array_remove_impl(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject];

def array_array_pop_impl(self_: ptr[PyObject], i: i64) -> ptr[PyObject];

def array_array_extend_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], bb: ptr[PyObject]
) -> ptr[PyObject];

def array_array_insert_impl(
    self_: ptr[PyObject], i: i64, v: ptr[PyObject]
) -> ptr[PyObject];

def array_array_buffer_info_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array_append_impl(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject];

def array_array_byteswap_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array_reverse_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array_fromfile_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], f: ptr[PyObject], n: i64
) -> ptr[PyObject];

def array_array_tofile_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], f: ptr[PyObject]
) -> ptr[PyObject];

def array_array_fromlist_impl(
    self_: ptr[PyObject], list_: ptr[PyObject]
) -> ptr[PyObject];

def array_array_tolist_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def frombytes(self_: ptr[arrayobject], buffer: ptr[Py_buffer]) -> ptr[PyObject];

def array_array_frombytes(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def array_array_frombytes_impl(
    self_: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def array_array_tobytes_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array_fromunicode_impl(
    self_: ptr[PyObject], ustr: ptr[PyObject]
) -> ptr[PyObject];

def array_array_tounicode_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def array_array___sizeof___impl(self_: ptr[PyObject]) -> ptr[PyObject];

def typecode_to_mformat_code(typecode: i32) -> i32;

def make_array(
    arraytype: ptr[PyTypeObject], typecode: i32, items: ptr[PyObject]
) -> ptr[PyObject];

def array__array_reconstructor_impl(
    module: ptr[PyObject],
    arraytype: ptr[PyObject],
    typecode: i32,
    mformat_code: i32,
    items: ptr[PyObject]
) -> ptr[PyObject];

def array_array___reduce_ex___impl(
    self_: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def array_get_typecode(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def array_get_itemsize(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def array_repr(op: ptr[PyObject]) -> ptr[PyObject];

def array_subscr_slice(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def array_subscr(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def array_ass_subscr(
    op: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def array_ass_subscr_range(
    op: ptr[PyObject],
    item: ptr[PyObject],
    value: ptr[PyObject],
    start: i64,
    stop: i64,
    step: i64,
    slicelength: i64
) -> i32;

def array_buffer_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def array_buffer_relbuf(op: ptr[PyObject], view: ptr[Py_buffer]);

def array_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def array_new_descr(
    state: ptr[array_state],
    type: ptr[PyTypeObject],
    descr: ptr[arraydescr],
    c: i32,
    initial: ptr[PyObject],
    it: ptr[PyObject]
) -> ptr[PyObject];

def array_iter(op: ptr[PyObject]) -> ptr[PyObject];

def arrayiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def arrayiter_dealloc(op: ptr[PyObject]);

def arrayiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def array_arrayiterator___reduce___impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def array_arrayiterator___setstate___impl(
    self_: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject];

def array_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def clear_state_slot(slot: ptr[ptr[PyObject]]);

def array_clear(module: ptr[PyObject]) -> i32;

def array_free(module: ptr);

def array_modexec(m: ptr[PyObject]) -> i32;

import from c {
    glob:priv array_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=ARRAYOBJECT_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ]; glob:priv array_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("typecode"),
                 get=array_get_typecode,
                 doc=ptr[u8]("the typecode character used to create the array")
             ),
             PyGetSetDef(
                 name=ptr[u8]("itemsize"),
                 get=array_get_itemsize,
                 doc=ptr[u8]("the size, in bytes, of one array item")
             ),
             PyGetSetDef()
         ]; glob array_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(array_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(array_repr)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "array(typecode [, initializer]) -> array\n\nReturn a new array whose items are restricted by typecode, and\ninitialized from the optional initializer value, which must be a list,\nstring or iterable over elements of the appropriate type.\n\nArrays represent basic values and behave very much like lists, except\nthe type of objects stored in them is constrained. The type is specified\nat object creation time by using a type code, which is a single character.\nThe following type codes are defined:\n\n    Type code   C Type             Minimum size in bytes\n    'b'         signed integer     1\n    'B'         unsigned integer   1\n    'u'         Unicode character  2 (see note)\n    'h'         signed integer     2\n    'H'         unsigned integer   2\n    'i'         signed integer     2\n    'I'         unsigned integer   2\n    'l'         signed integer     4\n    'L'         unsigned integer   4\n    'q'         signed integer     8 (see note)\n    'Q'         unsigned integer   8 (see note)\n    'f'         floating-point     4\n    'd'         floating-point     8\n\nNOTE: The 'u' typecode corresponds to Python's unicode character. On\nnarrow builds this is 2-bytes on wide builds this is 4-bytes.\n\nNOTE: The 'q' and 'Q' type codes are only available if the platform\nC compiler used to build Python supports 'long long', or, on Windows,\n'__int64'.\n\nMethods:\n\nappend() -- append a new item to the end of the array\nbuffer_info() -- return information giving the current memory info\nbyteswap() -- byteswap all the items of the array\ncount() -- return number of occurrences of an object\nextend() -- extend array by appending multiple elements from an iterable\nfromfile() -- read items from a file object\nfromlist() -- append items from the list\nfrombytes() -- append items from the string\nindex() -- return index of first occurrence of an object\ninsert() -- insert a new item into the array at a provided position\npop() -- remove and return item (default last)\nremove() -- remove first occurrence of an object\nreverse() -- reverse the order of the items in the array\ntofile() -- write all items to a file object\ntolist() -- return the array converted to an ordinary list\ntobytes() -- return the array converted to a string\n\nAttributes:\n\ntypecode -- the typecode character used to create the array\nitemsize -- the length in bytes of one array item\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(array_richcompare)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(array_iter)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(array_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(array_getsets))),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(array_new)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(array_tp_traverse)),
             PyType_Slot(slot=Py_sq_length, pfunc=ptr(array_length)),
             PyType_Slot(slot=Py_sq_concat, pfunc=ptr(array_concat)),
             PyType_Slot(slot=Py_sq_repeat, pfunc=ptr(array_repeat)),
             PyType_Slot(slot=Py_sq_item, pfunc=ptr(array_item)),
             PyType_Slot(slot=Py_sq_ass_item, pfunc=ptr(array_ass_item)),
             PyType_Slot(slot=Py_sq_contains, pfunc=ptr(array_contains)),
             PyType_Slot(slot=Py_sq_inplace_concat, pfunc=ptr(array_inplace_concat)),
             PyType_Slot(slot=Py_sq_inplace_repeat, pfunc=ptr(array_inplace_repeat)),
             PyType_Slot(slot=Py_mp_length, pfunc=ptr(array_length)),
             PyType_Slot(slot=Py_mp_subscript, pfunc=ptr(array_subscr)),
             PyType_Slot(slot=Py_mp_ass_subscript, pfunc=ptr(array_ass_subscr)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(array_buffer_getbuf)),
             PyType_Slot(slot=Py_bf_releasebuffer, pfunc=ptr(array_buffer_relbuf)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob array_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("array.array"),
             basicsize=i32(ARRAYOBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_SEQUENCE
             ),
             slots=addressof(array_slots)
         ); glob arrayiter_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(arrayiter_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(arrayiter_traverse)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(arrayiter_next)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob arrayiter_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("array.arrayiterator"),
             basicsize=i32(ARRAYITEROBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(arrayiter_slots)
         ); glob:priv arrayslots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(array_modexec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob arraymodule: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("array"),
             m_doc=ptr[u8](
                 "This module defines an object type which can efficiently represent\nan array of basic values: characters, integers, floating-point\nnumbers.  Arrays are sequence types and behave very much like lists,\nexcept that the type of objects stored in them is constrained.\n"
             ),
             m_size=ARRAY_STATE_SIZE,
             m_slots=addressof(arrayslots)
         );
}

impl get_array_state(module: ptr[PyObject]) -> ptr[array_state] {
    return ptr[array_state](ptr[PyModuleObject](module).view(1)[0].md_state);
}

impl find_array_state_by_type(tp: ptr[PyTypeObject]) -> ptr[array_state] {
    return get_array_state(
        PyType_GetModuleByDef(tp, ptr[PyModuleDef](addressof(arraymodule)))
    );
}

impl get_array_state_by_class(cls: ptr[PyObject]) -> ptr[array_state] {
    return get_array_state(PyType_GetModule(cls));
}

impl array_Check(op: ptr[PyObject], state: ptr[array_state]) -> bool {
    return object_type_check(op, state.view(1)[0].ArrayType);
}

impl slice_check(op: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](addressof(PySlice_Type));
}

impl array_resize(self_: ptr[arrayobject], newsize: i64) -> i32 {
    a = self_.view(1);
    size = a[0].ob_base.ob_size;
    if a[0].ob_exports > 0 and newsize != size {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("cannot resize an array that is exporting buffers")
        );
        return -1;
    }

    if a[0].allocated >= newsize and size - 16 < newsize and a[0].ob_item {
        a[0].ob_base.ob_size = newsize;
        return 0;
    }

    if newsize == 0 {
        PyMem_Free(a[0].ob_item);
        a[0].ob_item = ptr[u8]();
        a[0].ob_base.ob_size = 0;
        a[0].allocated = 0;
        return 0;
    }

    extra: u64 = u64(3);
    if size >= 8 {
        extra = u64(7);
    }
    _new_size: u64 = u64(newsize >> 4) + extra + u64(newsize);
    items = a[0].ob_item;
    itemsize = u64(a[0].ob_descr.view(1)[0].itemsize);
    if _new_size <= (~u64(0)) // itemsize {
        items = ptr[u8](PyMem_Realloc(items, _new_size * itemsize));
    } else {
        items = ptr[u8]();
    }
    if not items {
        PyErr_NoMemory();
        return -1;
    }
    a[0].ob_item = items;
    a[0].ob_base.ob_size = newsize;
    a[0].allocated = i64(_new_size);
    return 0;
}

impl out_of_bounds(ap: ptr[arrayobject], i: i64) -> bool {
    if i >= 0 and (not ap.view(1)[0].ob_item or i >= ap.view(1)[0].ob_base.ob_size) {
        PyErr_SetString(
            PyExc_IndexError, ptr[u8]("array assignment index out of range")
        );
        return True;
    }
    return False;
}

impl b_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    x = i64((ptr[i8](ap.view(1)[0].ob_item) + i).view(1)[0]);
    return PyLong_FromLong(x);
}

impl b_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    ival = PyLong_AsLong(v);
    if ival == -1 and PyErr_Occurred() {
        return -1;
    }
    if ival < -32768 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed short integer is less than minimum")
        );
        return -1;
    }
    if ival > 32767 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed short integer is greater than maximum")
        );
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if ival < -128 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed char is less than minimum")
        );
        return -1;
    } elif ival > 127 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed char is greater than maximum")
        );
        return -1;
    }
    if i >= 0 {
        (ptr[i8](ap.view(1)[0].ob_item) + i).view(1)[0] = i8(ival);
    }
    return 0;
}

impl BB_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    x = i64((ap.view(1)[0].ob_item + i).view(1)[0]);
    return PyLong_FromLong(x);
}

impl BB_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    ival = PyLong_AsLong(v);
    if ival == -1 and PyErr_Occurred() {
        return -1;
    }
    if ival < 0 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("unsigned byte integer is less than minimum")
        );
        return -1;
    }
    if ival > 255 {
        PyErr_SetString(
            PyExc_OverflowError,
            ptr[u8]("unsigned byte integer is greater than maximum")
        );
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ap.view(1)[0].ob_item + i).view(1)[0] = u8(ival);
    }
    return 0;
}

impl u_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyUnicode_FromOrdinal((ptr[i32](ap.view(1)[0].ob_item) + i).view(1)[0]);
}

impl u_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    if not unicode_check(v) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("array item must be a unicode character, not %T"),
            v
        );
        return -1;
    }

    wlen = PyUnicode_AsWideChar(v, ptr[i32](), 0);
    if wlen != 2 {
        if unicode_length(v) != 1 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "array item must be a unicode character, not a string of length %zd"
                ),
                unicode_length(v)
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("string %A cannot be converted to a single wchar_t character"),
                v
            );
        }
        return -1;
    }

    slots: own ArrayStack = ArrayStack();
    w = ptr[i32](jacpy_stack_address(&mut slots));
    PyUnicode_AsWideChar(v, w, 1);

    if i >= 0 {
        (ptr[i32](ap.view(1)[0].ob_item) + i).view(1)[0] = w.view(1)[0];
    }
    return 0;
}

impl w_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyUnicode_FromOrdinal(
        i32.wrap(i64((ptr[u32](ap.view(1)[0].ob_item) + i).view(1)[0]))
    );
}

impl w_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    if not unicode_check(v) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("array item must be a unicode character, not %T"),
            v
        );
        return -1;
    }

    if unicode_length(v) != 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "array item must be a unicode character, not a string of length %zd"
            ),
            unicode_length(v)
        );
        return -1;
    }

    if i >= 0 {
        (ptr[u32](ap.view(1)[0].ob_item) + i).view(1)[0] = PyUnicode_ReadChar(v, 0);
    }
    return 0;
}

impl h_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromLong(i64((ptr[i16](ap.view(1)[0].ob_item) + i).view(1)[0]));
}

impl h_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    ival = PyLong_AsLong(v);
    if ival == -1 and PyErr_Occurred() {
        return -1;
    }
    if ival < -32768 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed short integer is less than minimum")
        );
        return -1;
    }
    if ival > 32767 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed short integer is greater than maximum")
        );
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[i16](ap.view(1)[0].ob_item) + i).view(1)[0] = i16(ival);
    }
    return 0;
}

impl HH_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromLong(i64((ptr[u16](ap.view(1)[0].ob_item) + i).view(1)[0]));
}

impl HH_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    ival = PyLong_AsLong(v);
    if ival == -1 and PyErr_Occurred() {
        return -1;
    }
    if ival > 2147483647 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is greater than maximum")
        );
        return -1;
    }
    if ival < -2147483648 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is less than minimum")
        );
        return -1;
    }
    if ival < 0 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("unsigned short is less than minimum")
        );
        return -1;
    } elif ival > 65535 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("unsigned short is greater than maximum")
        );
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[u16](ap.view(1)[0].ob_item) + i).view(1)[0] = u16(ival);
    }
    return 0;
}

impl i_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromLong(i64((ptr[i32](ap.view(1)[0].ob_item) + i).view(1)[0]));
}

impl i_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    ival = PyLong_AsLong(v);
    if ival == -1 and PyErr_Occurred() {
        return -1;
    }
    if ival > 2147483647 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is greater than maximum")
        );
        return -1;
    }
    if ival < -2147483648 {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("signed integer is less than minimum")
        );
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[i32](ap.view(1)[0].ob_item) + i).view(1)[0] = i32(ival);
    }
    return 0;
}

impl II_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong(
        u64((ptr[u32](ap.view(1)[0].ob_item) + i).view(1)[0])
    );
}

impl II_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    do_decref = False;
    if not long_check(v) {
        v = _PyNumber_Index(v);
        if not v {
            return -1;
        }
        do_decref = True;
    }
    x = PyLong_AsUnsignedLong(v);
    if x == ~u64(0) and PyErr_Occurred() {
        if do_decref {
            object_decref(v);
        }
        return -1;
    }
    if x > u64(4294967295) {
        PyErr_SetString(
            PyExc_OverflowError, ptr[u8]("unsigned int is greater than maximum")
        );
        if do_decref {
            object_decref(v);
        }
        return -1;
    }

    if out_of_bounds(ap, i) {
        if do_decref {
            object_decref(v);
        }
        return -1;
    }

    if i >= 0 {
        (ptr[u32](ap.view(1)[0].ob_item) + i).view(1)[0] = u32(x);
    }

    if do_decref {
        object_decref(v);
    }
    return 0;
}

impl l_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromLong((ptr[i64](ap.view(1)[0].ob_item) + i).view(1)[0]);
}

impl l_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    x = PyLong_AsLong(v);
    if x == -1 and PyErr_Occurred() {
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[i64](ap.view(1)[0].ob_item) + i).view(1)[0] = x;
    }
    return 0;
}

impl LL_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong((ptr[u64](ap.view(1)[0].ob_item) + i).view(1)[0]);
}

impl LL_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    do_decref = False;
    if not long_check(v) {
        v = _PyNumber_Index(v);
        if not v {
            return -1;
        }
        do_decref = True;
    }
    x = PyLong_AsUnsignedLong(v);
    if x == ~u64(0) and PyErr_Occurred() {
        if do_decref {
            object_decref(v);
        }
        return -1;
    }

    if out_of_bounds(ap, i) {
        if do_decref {
            object_decref(v);
        }
        return -1;
    }

    if i >= 0 {
        (ptr[u64](ap.view(1)[0].ob_item) + i).view(1)[0] = x;
    }

    if do_decref {
        object_decref(v);
    }
    return 0;
}

impl q_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromLongLong((ptr[i64](ap.view(1)[0].ob_item) + i).view(1)[0]);
}

impl q_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    x = PyLong_AsLongLong(v);
    if x == -1 and PyErr_Occurred() {
        return -1;
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[i64](ap.view(1)[0].ob_item) + i).view(1)[0] = x;
    }
    return 0;
}

impl QQ_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyLong_FromUnsignedLongLong(
        (ptr[u64](ap.view(1)[0].ob_item) + i).view(1)[0]
    );
}

impl QQ_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    do_decref = False;
    if not long_check(v) {
        v = _PyNumber_Index(v);
        if not v {
            return -1;
        }
        do_decref = True;
    }
    x = PyLong_AsUnsignedLongLong(v);
    if x == ~u64(0) and PyErr_Occurred() {
        if do_decref {
            object_decref(v);
        }
        return -1;
    }

    if out_of_bounds(ap, i) {
        if do_decref {
            object_decref(v);
        }
        return -1;
    }

    if i >= 0 {
        (ptr[u64](ap.view(1)[0].ob_item) + i).view(1)[0] = x;
    }

    if do_decref {
        object_decref(v);
    }
    return 0;
}

impl f_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(f64((ptr[f32](ap.view(1)[0].ob_item) + i).view(1)[0]));
}

impl f_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    dval: f64 = 0.0;
    if ptr[_object](v).view(1)[0].ob_type
        == ptr[PyTypeObject](addressof(PyFloat_Type)) {
        dval = ptr[PyFloatObject](v).view(1)[0].ob_fval;
    } else {
        dval = PyFloat_AsDouble(v);
        if dval == -1.0 and PyErr_Occurred() {
            return -1;
        }
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[f32](ap.view(1)[0].ob_item) + i).view(1)[0] = f32(dval);
    }
    return 0;
}

impl d_getitem(ap: ptr[arrayobject], i: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble((ptr[f64](ap.view(1)[0].ob_item) + i).view(1)[0]);
}

impl d_setitem(ap: ptr[arrayobject], i: i64, v: ptr[PyObject]) -> i32 {
    x: f64 = 0.0;
    if ptr[_object](v).view(1)[0].ob_type
        == ptr[PyTypeObject](addressof(PyFloat_Type)) {
        x = ptr[PyFloatObject](v).view(1)[0].ob_fval;
    } else {
        x = PyFloat_AsDouble(v);
        if x == -1.0 and PyErr_Occurred() {
            return -1;
        }
    }

    if out_of_bounds(ap, i) {
        return -1;
    }

    if i >= 0 {
        (ptr[f64](ap.view(1)[0].ob_item) + i).view(1)[0] = x;
    }
    return 0;
}

impl b_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[i8](lhs);
    b = ptr[i8](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl BB_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[u8](lhs);
    b = ptr[u8](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl u_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[i32](lhs);
    b = ptr[i32](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl w_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[u32](lhs);
    b = ptr[u32](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl h_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[i16](lhs);
    b = ptr[i16](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl HH_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[u16](lhs);
    b = ptr[u16](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl i_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[i32](lhs);
    b = ptr[i32](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl II_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[u32](lhs);
    b = ptr[u32](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl l_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[i64](lhs);
    b = ptr[i64](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl LL_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[u64](lhs);
    b = ptr[u64](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl q_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[i64](lhs);
    b = ptr[i64](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl QQ_compareitems(lhs: ptr, rhs: ptr, length: i64) -> i32 {
    a = ptr[u64](lhs);
    b = ptr[u64](rhs);
    i: i64 = 0;
    while i < length {
        x = (a + i).view(1)[0];
        y = (b + i).view(1)[0];
        if x != y {
            if x < y {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl newarrayobject(
    type: ptr[PyTypeObject], size: i64, descr: ptr[arraydescr]
) -> ptr[PyObject] {
    if size < 0 {
        PyErr_BadInternalCall();
        return NULL;
    }

    itemsize = i64(descr.view(1)[0].itemsize);
    if size > PY_SSIZE_T_MAX // itemsize {
        return PyErr_NoMemory();
    }
    nbytes = size * itemsize;
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        return NULL;
    }
    a = ptr[arrayobject](op).view(1);
    a[0].ob_descr = descr;
    a[0].allocated = size;
    a[0].weakreflist = NULL;
    a[0].ob_base.ob_size = size;
    if size <= 0 {
        a[0].ob_item = ptr[u8]();
    } else {
        a[0].ob_item = ptr[u8](PyMem_Malloc(u64(nbytes)));
        if not a[0].ob_item {
            object_decref(op);
            return PyErr_NoMemory();
        }
    }
    a[0].ob_exports = 0;
    return op;
}

impl getarrayitem(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    ap = ptr[arrayobject](op);
    return ap.view(1)[0].ob_descr.view(1)[0].getitem(ap, i);
}

impl ins1(self_: ptr[arrayobject], where: i64, v: ptr[PyObject]) -> i32 {
    n = self_.view(1)[0].ob_base.ob_size;
    if not v {
        PyErr_BadInternalCall();
        return -1;
    }
    if self_.view(1)[0].ob_descr.view(1)[0].setitem(self_, -1, v) < 0 {
        return -1;
    }

    if array_resize(self_, n + 1) == -1 {
        return -1;
    }
    items = self_.view(1)[0].ob_item;
    if where < 0 {
        where += n;
        if where < 0 {
            where = 0;
        }
    }
    if where > n {
        where = n;
    }
    if where != n {
        itemsize = i64(self_.view(1)[0].ob_descr.view(1)[0].itemsize);
        memmove(
            ptr(items + (where + 1) * itemsize),
            ptr(items + where * itemsize),
            u64((n - where) * itemsize)
        );
    }
    return self_.view(1)[0].ob_descr.view(1)[0].setitem(self_, where, v);
}

impl array_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
}

impl array_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);
    PyObject_GC_UnTrack(op);

    self_ = ptr[arrayobject](op).view(1);
    if self_[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    if self_[0].ob_item {
        PyMem_Free(self_[0].ob_item);
    }
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl compare_sizes(vs: i64, ws: i64, op: i32) -> ptr[PyObject] {
    cmp = False;
    if op == Py_LT {
        cmp = vs < ws;
    } elif op == Py_LE {
        cmp = vs <= ws;
    } elif op == Py_EQ {
        cmp = True;
    } elif op == Py_NE {
        cmp = False;
    } elif op == Py_GT {
        cmp = vs > ws;
    } elif op == Py_GE {
        cmp = vs >= ws;
    } else {
        return NULL;
    }
    if cmp {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl array_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    state = find_array_state_by_type(object_type(v));

    if not array_Check(v, state) or not array_Check(w, state) {
        return object_new_ref(Py_NotImplemented);
    }

    va = ptr[arrayobject](v);
    wa = ptr[arrayobject](w);
    vsize = object_size(v);
    wsize = object_size(w);

    if vsize != wsize and (op == Py_EQ or op == Py_NE) {
        if op == Py_EQ {
            return PyBool_FromLong(0);
        }
        return PyBool_FromLong(1);
    }

    descr = va.view(1)[0].ob_descr;
    if descr == wa.view(1)[0].ob_descr and int(descr.view(1)[0].compareitems) != 0 {
        common_length = vsize if vsize < wsize else wsize;
        result = descr.view(1)[0].compareitems(
            ptr(va.view(1)[0].ob_item), ptr(wa.view(1)[0].ob_item), common_length
        );
        if result == 0 {
            return compare_sizes(object_size(v), object_size(w), op);
        }

        cmp = False;
        if op == Py_LT {
            cmp = result < 0;
        } elif op == Py_LE {
            cmp = result <= 0;
        } elif op == Py_EQ {
            cmp = result == 0;
        } elif op == Py_NE {
            cmp = result != 0;
        } elif op == Py_GT {
            cmp = result > 0;
        } elif op == Py_GE {
            cmp = result >= 0;
        } else {
            return NULL;
        }
        if cmp {
            return PyBool_FromLong(1);
        }
        return PyBool_FromLong(0);
    }

    vi = NULL;
    wi = NULL;
    k: i32 = 1;
    i: i64 = 0;
    while i < object_size(v) and i < object_size(w) {
        vi = getarrayitem(v, i);
        if not vi {
            return NULL;
        }
        wi = getarrayitem(w, i);
        if not wi {
            object_decref(vi);
            return NULL;
        }
        k = PyObject_RichCompareBool(vi, wi, Py_EQ);
        if k == 0 {
            break;
        }
        object_decref(vi);
        object_decref(wi);
        if k < 0 {
            return NULL;
        }
        i += 1;
    }

    if k != 0 {
        return compare_sizes(object_size(v), object_size(w), op);
    }

    res = NULL;
    if op == Py_EQ {
        res = PyBool_FromLong(0);
    } elif op == Py_NE {
        res = PyBool_FromLong(1);
    } else {
        res = PyObject_RichCompare(vi, wi, op);
    }
    object_decref(vi);
    object_decref(wi);
    return res;
}

impl array_length(op: ptr[PyObject]) -> i64 {
    return object_size(op);
}

impl array_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if i < 0 or i >= ptr[PyVarObject](op).view(1)[0].ob_size {
        PyErr_SetString(PyExc_IndexError, ptr[u8]("array index out of range"));
        return NULL;
    }
    return getarrayitem(op, i);
}

impl array_slice(a: ptr[arrayobject], ilow: i64, ihigh: i64) -> ptr[PyObject] {
    state = find_array_state_by_type(object_type(ptr[PyObject](a)));
    size = a.view(1)[0].ob_base.ob_size;

    if ilow < 0 {
        ilow = 0;
    } elif ilow > size {
        ilow = size;
    }
    if ihigh < 0 {
        ihigh = 0;
    }
    if ihigh < ilow {
        ihigh = ilow;
    } elif ihigh > size {
        ihigh = size;
    }
    descr = a.view(1)[0].ob_descr;
    np = newarrayobject(state.view(1)[0].ArrayType, ihigh - ilow, descr);
    if not np {
        return NULL;
    }
    if ihigh > ilow {
        itemsize = i64(descr.view(1)[0].itemsize);
        memcpy(
            ptr(ptr[arrayobject](np).view(1)[0].ob_item),
            ptr(a.view(1)[0].ob_item + ilow * itemsize),
            u64((ihigh - ilow) * itemsize)
        );
    }
    return np;
}

impl array_array_clear_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    if array_resize(ptr[arrayobject](self_), 0) == -1 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl array_array___copy___impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return array_slice(ptr[arrayobject](self_), 0, object_size(self_));
}

impl array_array___deepcopy___impl(
    self_: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return array_array___copy___impl(self_);
}

impl array_concat(op: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](op);
    state = find_array_state_by_type(object_type(op));
    if not array_Check(bb, state) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("can only append array (not \"%.200s\") to array"),
            object_type(bb).view(1)[0].tp_name
        );
        return NULL;
    }
    b = ptr[arrayobject](bb);
    if a.view(1)[0].ob_descr != b.view(1)[0].ob_descr {
        PyErr_BadArgument();
        return NULL;
    }
    asize = object_size(op);
    bsize = object_size(bb);
    if asize > PY_SSIZE_T_MAX - bsize {
        return PyErr_NoMemory();
    }
    size = asize + bsize;
    descr = a.view(1)[0].ob_descr;
    np = newarrayobject(state.view(1)[0].ArrayType, size, descr);
    if not np {
        return NULL;
    }
    itemsize = i64(descr.view(1)[0].itemsize);
    items = ptr[arrayobject](np).view(1)[0].ob_item;
    if asize > 0 {
        memcpy(ptr(items), ptr(a.view(1)[0].ob_item), u64(asize * itemsize));
    }
    if bsize > 0 {
        memcpy(
            ptr(items + asize * itemsize),
            ptr(b.view(1)[0].ob_item),
            u64(bsize * itemsize)
        );
    }
    return np;
}

impl array_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    a = ptr[arrayobject](op);
    state = find_array_state_by_type(object_type(op));

    if n < 0 {
        n = 0;
    }
    array_length = object_size(op);
    if array_length != 0 and n > PY_SSIZE_T_MAX // array_length {
        return PyErr_NoMemory();
    }
    size = array_length * n;
    descr = a.view(1)[0].ob_descr;
    np = newarrayobject(state.view(1)[0].ArrayType, size, descr);
    if not np {
        return NULL;
    }
    if size == 0 {
        return np;
    }

    oldbytes = array_length * i64(descr.view(1)[0].itemsize);
    newbytes = oldbytes * n;
    _PyBytes_Repeat(
        ptr[arrayobject](np).view(1)[0].ob_item,
        newbytes,
        a.view(1)[0].ob_item,
        oldbytes
    );

    return np;
}

impl array_del_slice(a: ptr[arrayobject], ilow: i64, ihigh: i64) -> i32 {
    size = a.view(1)[0].ob_base.ob_size;
    if ilow < 0 {
        ilow = 0;
    } elif ilow > size {
        ilow = size;
    }
    if ihigh < 0 {
        ihigh = 0;
    }
    if ihigh < ilow {
        ihigh = ilow;
    } elif ihigh > size {
        ihigh = size;
    }
    item = a.view(1)[0].ob_item;
    d = ihigh - ilow;
    if d != 0 and a.view(1)[0].ob_exports > 0 {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("cannot resize an array that is exporting buffers")
        );
        return -1;
    }
    if d > 0 {
        itemsize = i64(a.view(1)[0].ob_descr.view(1)[0].itemsize);
        memmove(
            ptr(item + (ihigh - d) * itemsize),
            ptr(item + ihigh * itemsize),
            u64((size - ihigh) * itemsize)
        );
        if array_resize(a, size - d) == -1 {
            return -1;
        }
    }
    return 0;
}

impl array_ass_item(op: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32 {
    a = ptr[arrayobject](op);
    if i < 0 or i >= object_size(op) {
        PyErr_SetString(
            PyExc_IndexError, ptr[u8]("array assignment index out of range")
        );
        return -1;
    }
    if not v {
        return array_del_slice(a, i, i + 1);
    }
    return a.view(1)[0].ob_descr.view(1)[0].setitem(a, i, v);
}

impl setarrayitem(a: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32 {
    return array_ass_item(a, i, v);
}

impl array_iter_extend(self_: ptr[arrayobject], bb: ptr[PyObject]) -> i32 {
    it = PyObject_GetIter(bb);
    if not it {
        return -1;
    }

    v = PyIter_Next(it);
    while v {
        if ins1(self_, self_.view(1)[0].ob_base.ob_size, v) != 0 {
            object_decref(v);
            object_decref(it);
            return -1;
        }
        object_decref(v);
        v = PyIter_Next(it);
    }
    object_decref(it);
    if PyErr_Occurred() {
        return -1;
    }
    return 0;
}

impl array_do_extend(
    state: ptr[array_state], self_: ptr[arrayobject], bb: ptr[PyObject]
) -> i32 {
    if not array_Check(bb, state) {
        return array_iter_extend(self_, bb);
    }
    b = ptr[arrayobject](bb);
    descr = self_.view(1)[0].ob_descr;
    if descr != b.view(1)[0].ob_descr {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("can only extend with array of same kind")
        );
        return -1;
    }
    itemsize = i64(descr.view(1)[0].itemsize);
    selfsize = self_.view(1)[0].ob_base.ob_size;
    if selfsize > PY_SSIZE_T_MAX - b.view(1)[0].ob_base.ob_size
        or selfsize + b.view(1)[0].ob_base.ob_size > PY_SSIZE_T_MAX // itemsize {
        PyErr_NoMemory();
        return -1;
    }
    oldsize = selfsize;
    bbsize = object_size(bb);
    size = oldsize + b.view(1)[0].ob_base.ob_size;
    if array_resize(self_, size) == -1 {
        return -1;
    }
    if bbsize > 0 {
        memcpy(
            ptr(self_.view(1)[0].ob_item + oldsize * itemsize),
            ptr(b.view(1)[0].ob_item),
            u64(bbsize * i64(b.view(1)[0].ob_descr.view(1)[0].itemsize))
        );
    }

    return 0;
}

impl array_inplace_concat(op: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject] {
    self_ = ptr[arrayobject](op);
    state = find_array_state_by_type(object_type(op));

    if not array_Check(bb, state) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("can only extend array with array (not \"%.200s\")"),
            object_type(bb).view(1)[0].tp_name
        );
        return NULL;
    }
    if array_do_extend(state, self_, bb) == -1 {
        return NULL;
    }
    return object_new_ref(op);
}

impl array_inplace_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    self_ = ptr[arrayobject](op);
    array_size = object_size(op);

    if array_size > 0 and n != 1 {
        if n < 0 {
            n = 0;
        }
        itemsize = i64(self_.view(1)[0].ob_descr.view(1)[0].itemsize);
        if itemsize != 0 and array_size > PY_SSIZE_T_MAX // itemsize {
            return PyErr_NoMemory();
        }
        size = array_size * itemsize;
        if n > 0 and size > PY_SSIZE_T_MAX // n {
            return PyErr_NoMemory();
        }
        if array_resize(self_, n * array_size) == -1 {
            return NULL;
        }

        _PyBytes_Repeat(
            self_.view(1)[0].ob_item, n * size, self_.view(1)[0].ob_item, size
        );
    }
    return object_new_ref(op);
}

impl ins(self_: ptr[arrayobject], where: i64, v: ptr[PyObject]) -> ptr[PyObject] {
    if ins1(self_, where, v) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl array_array_count_impl(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    count: i64 = 0;
    i: i64 = 0;
    while i < object_size(self_) {
        selfi = getarrayitem(self_, i);
        if not selfi {
            return NULL;
        }
        cmp = PyObject_RichCompareBool(selfi, v, Py_EQ);
        object_decref(selfi);
        if cmp > 0 {
            count += 1;
        } elif cmp < 0 {
            return NULL;
        }
        i += 1;
    }
    return PyLong_FromSsize_t(count);
}

impl array_array_index_impl(
    self_: ptr[PyObject], v: ptr[PyObject], start: i64, stop: i64
) -> ptr[PyObject] {
    if start < 0 {
        start += object_size(self_);
        if start < 0 {
            start = 0;
        }
    }
    if stop < 0 {
        stop += object_size(self_);
    }
    i = start;
    while i < stop and i < object_size(self_) {
        selfi = getarrayitem(self_, i);
        if not selfi {
            return NULL;
        }
        cmp = PyObject_RichCompareBool(selfi, v, Py_EQ);
        object_decref(selfi);
        if cmp > 0 {
            return PyLong_FromSsize_t(i);
        } elif cmp < 0 {
            return NULL;
        }
        i += 1;
    }
    PyErr_SetString(PyExc_ValueError, ptr[u8]("array.index(x): x not in array"));
    return NULL;
}

impl array_contains(self_: ptr[PyObject], v: ptr[PyObject]) -> i32 {
    cmp: i32 = 0;
    i: i64 = 0;
    while cmp == 0 and i < object_size(self_) {
        selfi = getarrayitem(self_, i);
        if not selfi {
            return -1;
        }
        cmp = PyObject_RichCompareBool(selfi, v, Py_EQ);
        object_decref(selfi);
        i += 1;
    }
    return cmp;
}

impl array_array_remove_impl(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    i: i64 = 0;
    while i < object_size(self_) {
        selfi = getarrayitem(self_, i);
        if not selfi {
            return NULL;
        }
        cmp = PyObject_RichCompareBool(selfi, v, Py_EQ);
        object_decref(selfi);
        if cmp > 0 {
            if array_del_slice(ptr[arrayobject](self_), i, i + 1) != 0 {
                return NULL;
            }
            return object_new_ref(Py_None);
        } elif cmp < 0 {
            return NULL;
        }
        i += 1;
    }
    PyErr_SetString(PyExc_ValueError, ptr[u8]("array.remove(x): x not in array"));
    return NULL;
}

impl array_array_pop_impl(self_: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if object_size(self_) == 0 {
        PyErr_SetString(PyExc_IndexError, ptr[u8]("pop from empty array"));
        return NULL;
    }
    if i < 0 {
        i += object_size(self_);
    }
    if i < 0 or i >= object_size(self_) {
        PyErr_SetString(PyExc_IndexError, ptr[u8]("pop index out of range"));
        return NULL;
    }
    v = getarrayitem(self_, i);
    if not v {
        return NULL;
    }
    if array_del_slice(ptr[arrayobject](self_), i, i + 1) != 0 {
        object_decref(v);
        return NULL;
    }
    return v;
}

impl array_array_extend_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], bb: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_array_state_by_class(cls);

    if array_do_extend(state, ptr[arrayobject](self_), bb) == -1 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl array_array_insert_impl(
    self_: ptr[PyObject], i: i64, v: ptr[PyObject]
) -> ptr[PyObject] {
    return ins(ptr[arrayobject](self_), i, v);
}

impl array_array_buffer_info_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    retval = PyTuple_New(2);
    if not retval {
        return NULL;
    }

    v = PyLong_FromVoidPtr(ptr(ptr[arrayobject](self_).view(1)[0].ob_item));
    if not v {
        object_decref(retval);
        return NULL;
    }
    tuple_set_item(retval, 0, v);

    v = PyLong_FromSsize_t(object_size(self_));
    if not v {
        object_decref(retval);
        return NULL;
    }
    tuple_set_item(retval, 1, v);

    return retval;
}

impl array_array_append_impl(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    ap = ptr[arrayobject](self_);
    return ins(ap, ap.view(1)[0].ob_base.ob_size, v);
}

impl array_array_byteswap_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](self_).view(1);
    itemsize = a[0].ob_descr.view(1)[0].itemsize;
    p = a[0].ob_item;
    i = object_size(self_);
    if itemsize == 1 {
        return object_new_ref(Py_None);
    } elif itemsize == 2 {
        while i > 0 {
            i -= 1;
            p0 = p.view(2)[0];
            p.view(2)[0] = p.view(2)[1];
            p.view(2)[1] = p0;
            p = p + 2;
        }
    } elif itemsize == 4 {
        while i > 0 {
            i -= 1;
            q = p.view(4);
            p0 = q[0];
            p1 = q[1];
            q[0] = q[3];
            q[1] = q[2];
            q[2] = p1;
            q[3] = p0;
            p = p + 4;
        }
    } elif itemsize == 8 {
        while i > 0 {
            i -= 1;
            r = p.view(8);
            b0 = r[0];
            b1 = r[1];
            b2 = r[2];
            b3 = r[3];
            r[0] = r[7];
            r[1] = r[6];
            r[2] = r[5];
            r[3] = r[4];
            r[4] = b3;
            r[5] = b2;
            r[6] = b1;
            r[7] = b0;
            p = p + 8;
        }
    } else {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("don't know how to byteswap this array type")
        );
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl array_array_reverse_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](self_).view(1);
    itemsize = i64(a[0].ob_descr.view(1)[0].itemsize);
    slots: own ArrayStack = ArrayStack();
    tmp = ptr(jacpy_stack_address(&mut slots));

    size = object_size(self_);
    if size > 1 {
        base = a[0].ob_item;
        lo: i64 = 0;
        hi = (size - 1) * itemsize;
        while lo < hi {
            memcpy(tmp, ptr(base + lo), u64(itemsize));
            memcpy(ptr(base + lo), ptr(base + hi), u64(itemsize));
            memcpy(ptr(base + hi), tmp, u64(itemsize));
            lo += itemsize;
            hi -= itemsize;
        }
    }

    return object_new_ref(Py_None);
}

impl array_array_fromfile_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], f: ptr[PyObject], n: i64
) -> ptr[PyObject] {
    itemsize = i64(ptr[arrayobject](self_).view(1)[0].ob_descr.view(1)[0].itemsize);

    if n < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("negative count"));
        return NULL;
    }
    if n > PY_SSIZE_T_MAX // itemsize {
        PyErr_NoMemory();
        return NULL;
    }

    state = get_array_state_by_class(cls);

    nbytes = n * itemsize;

    count = PyLong_FromSsize_t(nbytes);
    if not count {
        return NULL;
    }
    slots: own ArrayStack = ArrayStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = f;
    stack.view(2)[1] = count;
    b = PyObject_VectorcallMethod(state.view(1)[0].str_read, stack, u64(2), NULL);
    object_decref(count);
    if not b {
        return NULL;
    }

    if not bytes_check(b) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("read() didn't return bytes"));
        object_decref(b);
        return NULL;
    }

    not_enough_bytes = object_size(b) != nbytes;

    res = array_array_frombytes(self_, b);
    object_decref(b);
    if not res {
        return NULL;
    }

    if not_enough_bytes {
        PyErr_SetString(PyExc_EOFError, ptr[u8]("read() didn't return enough bytes"));
        object_decref(res);
        return NULL;
    }

    return res;
}

impl array_array_tofile_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], f: ptr[PyObject]
) -> ptr[PyObject] {
    a = ptr[arrayobject](self_).view(1);
    nbytes = object_size(self_) * i64(a[0].ob_descr.view(1)[0].itemsize);
    BLOCKSIZE: i64 = 64 * 1024;
    nblocks = (nbytes + BLOCKSIZE - 1) // BLOCKSIZE;

    if object_size(self_) == 0 {
        return object_new_ref(Py_None);
    }

    state = get_array_state_by_class(cls);

    slots: own ArrayStack = ArrayStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    i: i64 = 0;
    while i < nblocks {
        block = a[0].ob_item + i * BLOCKSIZE;
        size = BLOCKSIZE;

        if i * BLOCKSIZE + size > nbytes {
            size = nbytes - i * BLOCKSIZE;
        }
        bytes_obj = PyBytes_FromStringAndSize(block, size);
        if not bytes_obj {
            return NULL;
        }
        stack.view(2)[0] = f;
        stack.view(2)[1] = bytes_obj;
        res = PyObject_VectorcallMethod(
            state.view(1)[0].str_write, stack, u64(2), NULL
        );
        object_decref(bytes_obj);
        if not res {
            return NULL;
        }
        object_decref(res);
        i += 1;
    }

    return object_new_ref(Py_None);
}

impl array_array_fromlist_impl(
    self_: ptr[PyObject], list_: ptr[PyObject]
) -> ptr[PyObject] {
    if not list_check(list_) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("arg must be list"));
        return NULL;
    }
    n = PyList_Size(list_);
    if n > 0 {
        a = ptr[arrayobject](self_);
        old_size = object_size(self_);
        if array_resize(a, old_size + n) == -1 {
            return NULL;
        }
        i: i64 = 0;
        while i < n {
            v = (ptr[PyListObject](list_).view(1)[0].ob_item + i).view(1)[0];
            if a.view(1)[0].ob_descr.view(1)[0].setitem(
                a, object_size(self_) - n + i, v
            )
                != 0 {
                array_resize(a, old_size);
                return NULL;
            }
            if n != object_size(list_) {
                PyErr_SetString(
                    PyExc_RuntimeError, ptr[u8]("list changed size during iteration")
                );
                array_resize(a, old_size);
                return NULL;
            }
            i += 1;
        }
    }
    return object_new_ref(Py_None);
}

impl array_array_tolist_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    lst = PyList_New(object_size(self_));

    if not lst {
        return NULL;
    }
    i: i64 = 0;
    while i < object_size(self_) {
        v = getarrayitem(self_, i);
        if not v {
            object_decref(lst);
            return NULL;
        }
        (ptr[PyListObject](lst).view(1)[0].ob_item + i).view(1)[0] = v;
        i += 1;
    }
    return lst;
}

impl frombytes(self_: ptr[arrayobject], buffer: ptr[Py_buffer]) -> ptr[PyObject] {
    itemsize = i64(self_.view(1)[0].ob_descr.view(1)[0].itemsize);
    if buffer.view(1)[0].itemsize != 1 {
        PyBuffer_Release(buffer);
        PyErr_SetString(PyExc_TypeError, ptr[u8]("a bytes-like object is required"));
        return NULL;
    }
    n = buffer.view(1)[0].length;
    if n % itemsize != 0 {
        PyBuffer_Release(buffer);
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("bytes length not a multiple of item size")
        );
        return NULL;
    }
    n = n // itemsize;
    if n > 0 {
        old_size = self_.view(1)[0].ob_base.ob_size;
        if n > PY_SSIZE_T_MAX - old_size or old_size + n > PY_SSIZE_T_MAX // itemsize {
            PyBuffer_Release(buffer);
            return PyErr_NoMemory();
        }
        if array_resize(self_, old_size + n) == -1 {
            PyBuffer_Release(buffer);
            return NULL;
        }
        memcpy(
            ptr(self_.view(1)[0].ob_item + old_size * itemsize),
            buffer.view(1)[0].buf,
            u64(n * itemsize)
        );
    }
    PyBuffer_Release(buffer);
    return object_new_ref(Py_None);
}

impl array_array_frombytes(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    slots: own ArrayStack = ArrayStack();
    buffer = ptr[Py_buffer](jacpy_stack_address(&mut slots));

    if PyObject_GetBuffer(arg, buffer, PyBUF_SIMPLE) != 0 {
        return NULL;
    }
    return_value = frombytes(ptr[arrayobject](self_), buffer);

    if buffer.view(1)[0].owner {
        PyBuffer_Release(buffer);
    }
    return return_value;
}

impl array_array_frombytes_impl(
    self_: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return frombytes(ptr[arrayobject](self_), buffer.view);
}

impl array_array_tobytes_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](self_).view(1);
    itemsize = i64(a[0].ob_descr.view(1)[0].itemsize);
    if object_size(self_) <= PY_SSIZE_T_MAX // itemsize {
        return PyBytes_FromStringAndSize(a[0].ob_item, object_size(self_) * itemsize);
    }
    return PyErr_NoMemory();
}

impl array_array_fromunicode_impl(
    self_: ptr[PyObject], ustr: ptr[PyObject]
) -> ptr[PyObject] {
    a = ptr[arrayobject](self_);
    typecode = i32(a.view(1)[0].ob_descr.view(1)[0].typecode);
    if typecode != 117 and typecode != 119 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8](
                "fromunicode() may only be called on unicode type arrays ('u' or 'w')"
            )
        );
        return NULL;
    }

    if typecode == 117 {
        ustr_length = PyUnicode_AsWideChar(ustr, ptr[i32](), 0);
        if ustr_length > 1 {
            ustr_length -= 1;
            old_size = object_size(self_);
            if array_resize(a, old_size + ustr_length) == -1 {
                return NULL;
            }

            PyUnicode_AsWideChar(
                ustr, ptr[i32](a.view(1)[0].ob_item) + old_size, ustr_length
            );
        }
    } else {
        ucs_length = PyUnicode_GetLength(ustr);
        old_ucs_size = object_size(self_);
        new_size = old_ucs_size + ucs_length;
        if new_size < 0 or new_size > PY_SSIZE_T_MAX // 4 {
            return PyErr_NoMemory();
        }
        if array_resize(a, new_size) == -1 {
            return NULL;
        }
        PyUnicode_AsUCS4(
            ustr, ptr[u32](a.view(1)[0].ob_item) + old_ucs_size, ucs_length, 0
        );
    }

    return object_new_ref(Py_None);
}

impl array_array_tounicode_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](self_).view(1);
    typecode = i32(a[0].ob_descr.view(1)[0].typecode);
    if typecode != 117 and typecode != 119 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8](
                "tounicode() may only be called on unicode type arrays ('u' or 'w')"
            )
        );
        return NULL;
    }
    if typecode == 117 {
        return PyUnicode_FromWideChar(ptr[i32](a[0].ob_item), object_size(self_));
    }
    slots: own ArrayStack = ArrayStack();
    byteorder = ptr[i32](jacpy_stack_address(&mut slots));
    byteorder.view(1)[0] = 0;
    return PyUnicode_DecodeUTF32(
        a[0].ob_item, object_size(self_) * 4, ptr[u8](), byteorder
    );
}

impl array_array___sizeof___impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](self_).view(1);
    res = u64(object_type(self_).view(1)[0].tp_basicsize);
    res += u64(a[0].allocated) * u64(a[0].ob_descr.view(1)[0].itemsize);
    return PyLong_FromSize_t(res);
}

impl typecode_to_mformat_code(typecode: i32) -> i32 {
    is_big_endian = PY_BIG_ENDIAN;

    intsize: i32 = 0;
    is_signed: i32 = 0;

    if typecode == 98 {
        return SIGNED_INT8;
    } elif typecode == 66 {
        return UNSIGNED_INT8;
    } elif typecode == 117 {
        if SIZEOF_WCHAR_T == 2 {
            return UTF16_LE + is_big_endian;
        }
        if SIZEOF_WCHAR_T == 4 {
            return UTF32_LE + is_big_endian;
        }
        return UNKNOWN_FORMAT;
    } elif typecode == 119 {
        return UTF32_LE + is_big_endian;
    } elif typecode == 102 {
        return IEEE_754_FLOAT_LE + is_big_endian;
    } elif typecode == 100 {
        return IEEE_754_DOUBLE_LE + is_big_endian;
    } elif typecode == 104 {
        intsize = 2;
        is_signed = 1;
    } elif typecode == 72 {
        intsize = 2;
        is_signed = 0;
    } elif typecode == 105 {
        intsize = 4;
        is_signed = 1;
    } elif typecode == 73 {
        intsize = 4;
        is_signed = 0;
    } elif typecode == 108 {
        intsize = 8;
        is_signed = 1;
    } elif typecode == 76 {
        intsize = 8;
        is_signed = 0;
    } elif typecode == 113 {
        intsize = 8;
        is_signed = 1;
    } elif typecode == 81 {
        intsize = 8;
        is_signed = 0;
    } else {
        return UNKNOWN_FORMAT;
    }
    if intsize == 2 {
        return UNSIGNED_INT16_LE + is_big_endian + 2 * is_signed;
    } elif intsize == 4 {
        return UNSIGNED_INT32_LE + is_big_endian + 2 * is_signed;
    } elif intsize == 8 {
        return UNSIGNED_INT64_LE + is_big_endian + 2 * is_signed;
    }
    return UNKNOWN_FORMAT;
}

impl make_array(
    arraytype: ptr[PyTypeObject], typecode: i32, items: ptr[PyObject]
) -> ptr[PyObject] {
    typecode_obj = PyUnicode_FromOrdinal(typecode);
    if not typecode_obj {
        return NULL;
    }

    new_args = PyTuple_New(2);
    if not new_args {
        object_decref(typecode_obj);
        return NULL;
    }
    tuple_set_item(new_args, 0, typecode_obj);
    tuple_set_item(new_args, 1, object_new_ref(items));

    array_obj = array_new(arraytype, new_args, NULL);
    object_decref(new_args);
    if not array_obj {
        return NULL;
    }

    return array_obj;
}

impl array__array_reconstructor_impl(
    module: ptr[PyObject],
    arraytype: ptr[PyObject],
    typecode: i32,
    mformat_code: i32,
    items: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_array_state(module);
    converted_items = NULL;

    if not type_check(arraytype) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("first argument must be a type object, not %.200s"),
            object_type(arraytype).view(1)[0].tp_name
        );
        return NULL;
    }
    array_type = state.view(1)[0].ArrayType;
    if PyType_IsSubtype(arraytype, ptr[PyObject](array_type)) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.200s is not a subtype of %.200s"),
            ptr[PyTypeObject](arraytype).view(1)[0].tp_name,
            array_type.view(1)[0].tp_name
        );
        return NULL;
    }
    descr = ptr[arraydescr](addressof(descriptors));
    while descr.view(1)[0].typecode != u8(0) {
        if i32(descr.view(1)[0].typecode) == typecode {
            break;
        }
        descr = descr + 1;
    }
    if descr.view(1)[0].typecode == u8(0) {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("second argument must be a valid type code")
        );
        return NULL;
    }
    if mformat_code < MACHINE_FORMAT_CODE_MIN
        or mformat_code > MACHINE_FORMAT_CODE_MAX {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("third argument must be a valid machine format code.")
        );
        return NULL;
    }
    if not bytes_check(items) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("fourth argument should be bytes, not %.200s"),
            object_type(items).view(1)[0].tp_name
        );
        return NULL;
    }

    if mformat_code == typecode_to_mformat_code(typecode)
        or mformat_code == UNKNOWN_FORMAT {
        return make_array(ptr[PyTypeObject](arraytype), typecode, items);
    }

    mf_descr = (
        ptr[mformatdescr](addressof(mformat_descriptors)) + i64(mformat_code)
    ).view(
        1
    );
    mf_size = i64(mf_descr[0].size);
    nitems = object_size(items);
    if nitems % mf_size != 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("string length not a multiple of item size")
        );
        return NULL;
    }
    memstr = bytes_data(items);
    if mformat_code == IEEE_754_FLOAT_LE or mformat_code == IEEE_754_FLOAT_BE {
        le: i32 = 0;
        if mformat_code == IEEE_754_FLOAT_LE {
            le = 1;
        }
        itemcount = nitems // 4;

        converted_items = PyList_New(itemcount);
        if not converted_items {
            return NULL;
        }
        i: i64 = 0;
        while i < itemcount {
            pyfloat = PyFloat_FromDouble(PyFloat_Unpack4(memstr + i * 4, le));
            if not pyfloat {
                object_decref(converted_items);
                return NULL;
            }
            (ptr[PyListObject](converted_items).view(1)[0].ob_item + i).view(1)[0] = pyfloat;
            i += 1;
        }
    } elif mformat_code == IEEE_754_DOUBLE_LE or mformat_code == IEEE_754_DOUBLE_BE {
        dle: i32 = 0;
        if mformat_code == IEEE_754_DOUBLE_LE {
            dle = 1;
        }
        ditemcount = nitems // 8;
        converted_items = PyList_New(ditemcount);
        if not converted_items {
            return NULL;
        }
        j: i64 = 0;
        while j < ditemcount {
            pydouble = PyFloat_FromDouble(PyFloat_Unpack8(memstr + j * 8, dle));
            if not pydouble {
                object_decref(converted_items);
                return NULL;
            }
            (ptr[PyListObject](converted_items).view(1)[0].ob_item + j).view(1)[0] = pydouble;
            j += 1;
        }
    } elif mformat_code == UTF16_LE or mformat_code == UTF16_BE {
        slots: own ArrayStack = ArrayStack();
        byteorder = ptr[i32](jacpy_stack_address(&mut slots));
        byteorder.view(1)[0] = 1;
        if mformat_code == UTF16_LE {
            byteorder.view(1)[0] = -1;
        }
        converted_items = PyUnicode_DecodeUTF16(
            memstr, nitems, ptr[u8]("strict"), byteorder
        );
        if not converted_items {
            return NULL;
        }
    } elif mformat_code == UTF32_LE or mformat_code == UTF32_BE {
        slots32: own ArrayStack = ArrayStack();
        byteorder32 = ptr[i32](jacpy_stack_address(&mut slots32));
        byteorder32.view(1)[0] = 1;
        if mformat_code == UTF32_LE {
            byteorder32.view(1)[0] = -1;
        }
        converted_items = PyUnicode_DecodeUTF32(
            memstr, nitems, ptr[u8]("strict"), byteorder32
        );
        if not converted_items {
            return NULL;
        }
    } elif mformat_code >= UNSIGNED_INT8 and mformat_code <= SIGNED_INT64_BE {
        itemcount_int = nitems // mf_size;
        idescr = ptr[arraydescr](addressof(descriptors));
        while idescr.view(1)[0].typecode != u8(0) {
            if idescr.view(1)[0].is_integer_type != 0
                and u64(idescr.view(1)[0].itemsize) == mf_descr[0].size
                and idescr.view(1)[0].is_signed == mf_descr[0].is_signed {
                typecode = i32(idescr.view(1)[0].typecode);
            }
            idescr = idescr + 1;
        }
        converted_items = PyList_New(itemcount_int);
        if not converted_items {
            return NULL;
        }
        little_endian: i32 = 0;
        if mf_descr[0].is_big_endian == 0 {
            little_endian = 1;
        }
        k: i64 = 0;
        while k < itemcount_int {
            pylong = _PyLong_FromByteArray(
                memstr + k * mf_size,
                mf_descr[0].size,
                little_endian,
                mf_descr[0].is_signed
            );
            if not pylong {
                object_decref(converted_items);
                return NULL;
            }
            (ptr[PyListObject](converted_items).view(1)[0].ob_item + k).view(1)[0] = pylong;
            k += 1;
        }
    } else {
        PyErr_BadArgument();
        return NULL;
    }

    result = make_array(ptr[PyTypeObject](arraytype), typecode, converted_items);
    object_decref(converted_items);
    return result;
}

impl array_array___reduce_ex___impl(
    self_: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    typecode = i32(ptr[arrayobject](self_).view(1)[0].ob_descr.view(1)[0].typecode);

    state = get_array_state_by_class(cls);
    st = state.view(1);

    if not st[0].array_reconstructor {
        st[0].array_reconstructor = PyImport_ImportModuleAttrString(
            ptr[u8]("array"), ptr[u8]("_array_reconstructor")
        );
        if not st[0].array_reconstructor {
            return NULL;
        }
    }

    if not long_check(value) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("__reduce_ex__ argument should be an integer")
        );
        return NULL;
    }
    protocol = PyLong_AsLong(value);
    if protocol == -1 and PyErr_Occurred() {
        return NULL;
    }

    dct = NULL;
    if PyObject_GetOptionalAttr(self_, st[0].str___dict__, &mut dct) < 0 {
        return NULL;
    }
    if not dct {
        dct = object_new_ref(Py_None);
    }

    mformat_code = typecode_to_mformat_code(typecode);
    if mformat_code == UNKNOWN_FORMAT or protocol < 3 {
        lst = array_array_tolist_impl(self_);
        if not lst {
            object_decref(dct);
            return NULL;
        }
        result = Py_BuildValue(
            ptr[u8]("O(CO)O"), ptr[PyObject](object_type(self_)), typecode, lst, dct
        );
        object_decref(lst);
        object_decref(dct);
        return result;
    }

    array_str = array_array_tobytes_impl(self_);
    if not array_str {
        object_decref(dct);
        return NULL;
    }

    reduced = Py_BuildValue(
        ptr[u8]("O(OCiN)O"),
        st[0].array_reconstructor,
        ptr[PyObject](object_type(self_)),
        typecode,
        mformat_code,
        array_str,
        dct
    );
    object_decref(dct);
    return reduced;
}

impl array_get_typecode(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    typecode = i32(ptr[arrayobject](op).view(1)[0].ob_descr.view(1)[0].typecode);
    return PyUnicode_FromOrdinal(typecode);
}

impl array_get_itemsize(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(
        i64(ptr[arrayobject](op).view(1)[0].ob_descr.view(1)[0].itemsize)
    );
}

impl array_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    a = ptr[arrayobject](op);

    size = object_size(op);
    typecode = i32(a.view(1)[0].ob_descr.view(1)[0].typecode);
    if size == 0 {
        return PyUnicode_FromFormat(
            "%s('%c')", _PyType_Name(ptr[PyObject](object_type(op))), typecode
        );
    }
    v = NULL;
    if typecode == 117 or typecode == 119 {
        v = array_array_tounicode_impl(op);
    } else {
        v = array_array_tolist_impl(op);
    }
    if not v {
        return NULL;
    }

    s = PyUnicode_FromFormat(
        "%s('%c', %R)", _PyType_Name(ptr[PyObject](object_type(op))), typecode, v
    );
    object_decref(v);
    return s;
}

impl array_subscr_slice(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    self_ = ptr[arrayobject](op);
    descr = self_.view(1)[0].ob_descr;
    itemsize = i64(descr.view(1)[0].itemsize);

    slots: own ArrayStack = ArrayStack();
    bounds = ptr[i64](jacpy_stack_address(&mut slots));
    if PySlice_Unpack(item, bounds, bounds + 1, bounds + 2) < 0 {
        return NULL;
    }
    step = (bounds + 2).view(1)[0];
    slicelength = PySlice_AdjustIndices(object_size(op), bounds, bounds + 1, step);
    start = bounds.view(1)[0];

    state = find_array_state_by_type(object_type(op));
    if slicelength <= 0 {
        return newarrayobject(state.view(1)[0].ArrayType, 0, descr);
    } elif step == 1 {
        result = newarrayobject(state.view(1)[0].ArrayType, slicelength, descr);
        if not result {
            return NULL;
        }
        memcpy(
            ptr(ptr[arrayobject](result).view(1)[0].ob_item),
            ptr(self_.view(1)[0].ob_item + start * itemsize),
            u64(slicelength * itemsize)
        );
        return result;
    }
    stepped = newarrayobject(state.view(1)[0].ArrayType, slicelength, descr);
    if not stepped {
        return NULL;
    }

    dest = ptr[arrayobject](stepped).view(1)[0].ob_item;
    src = self_.view(1)[0].ob_item;
    cur = start;
    i: i64 = 0;
    while i < slicelength {
        memcpy(ptr(dest + i * itemsize), ptr(src + cur * itemsize), u64(itemsize));
        i += 1;
        if i < slicelength {
            cur += step;
        }
    }

    return stepped;
}

impl array_subscr(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        if i < 0 {
            i += object_size(op);
        }
        return array_item(op, i);
    } elif slice_check(item) {
        return array_subscr_slice(op, item);
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("array indices must be integers"));
    return NULL;
}

impl array_ass_subscr(
    op: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    self_ = ptr[arrayobject](op);

    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);

        if i == -1 and PyErr_Occurred() {
            return -1;
        }
        if i < 0 {
            i += object_size(op);
        }
        if i < 0 or i >= object_size(op) {
            PyErr_SetString(
                PyExc_IndexError, ptr[u8]("array assignment index out of range")
            );
            return -1;
        }
        if not value {
            return array_ass_subscr_range(op, item, value, i, i + 1, 1, 1);
        }
        return self_.view(1)[0].ob_descr.view(1)[0].setitem(self_, i, value);
    } elif slice_check(item) {
        slots: own ArrayStack = ArrayStack();
        bounds = ptr[i64](jacpy_stack_address(&mut slots));
        if PySlice_Unpack(item, bounds, bounds + 1, bounds + 2) < 0 {
            return -1;
        }
        step = (bounds + 2).view(1)[0];
        slicelength = PySlice_AdjustIndices(object_size(op), bounds, bounds + 1, step);
        return array_ass_subscr_range(
            op,
            item,
            value,
            bounds.view(1)[0],
            (bounds + 1).view(1)[0],
            step,
            slicelength
        );
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("array indices must be integers"));
    return -1;
}

impl array_ass_subscr_range(
    op: ptr[PyObject],
    item: ptr[PyObject],
    value: ptr[PyObject],
    start: i64,
    stop: i64,
    step: i64,
    slicelength: i64
) -> i32 {
    self_ = ptr[arrayobject](op);
    other = ptr[arrayobject]();
    needed: i64 = 0;

    if not value {
        needed = 0;
    } else {
        state = find_array_state_by_type(object_type(op));
        if array_Check(value, state) {
            other = ptr[arrayobject](value);
            needed = object_size(value);
            if op == value {
                copied = array_slice(other, 0, needed);
                if not copied {
                    return -1;
                }
                ret = array_ass_subscr(op, item, copied);
                object_decref(copied);
                return ret;
            }
            if other.view(1)[0].ob_descr != self_.view(1)[0].ob_descr {
                PyErr_BadArgument();
                return -1;
            }
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("can only assign array (not \"%.200s\") to array slice"),
                object_type(value).view(1)[0].tp_name
            );
            return -1;
        }
    }
    itemsize = i64(self_.view(1)[0].ob_descr.view(1)[0].itemsize);
    if (step > 0 and stop < start) or (step < 0 and stop > start) {
        stop = start;
    }

    if (needed == 0 or slicelength != needed) and self_.view(1)[0].ob_exports > 0 {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("cannot resize an array that is exporting buffers")
        );
        return -1;
    }

    if step == 1 {
        if slicelength > needed {
            memmove(
                ptr(self_.view(1)[0].ob_item + (start + needed) * itemsize),
                ptr(self_.view(1)[0].ob_item + stop * itemsize),
                u64((object_size(op) - stop) * itemsize)
            );
            if array_resize(self_, object_size(op) + needed - slicelength) < 0 {
                return -1;
            }
        } elif slicelength < needed {
            if array_resize(self_, object_size(op) + needed - slicelength) < 0 {
                return -1;
            }
            memmove(
                ptr(self_.view(1)[0].ob_item + (start + needed) * itemsize),
                ptr(self_.view(1)[0].ob_item + stop * itemsize),
                u64((object_size(op) - start - needed) * itemsize)
            );
        }
        if needed > 0 {
            memcpy(
                ptr(self_.view(1)[0].ob_item + start * itemsize),
                ptr(other.view(1)[0].ob_item),
                u64(needed * itemsize)
            );
        }
        return 0;
    } elif needed == 0 {
        if step < 0 {
            stop = start + 1;
            start = stop + step * (slicelength - 1) - 1;
            step = -step;
        }
        items = self_.view(1)[0].ob_item;
        size = object_size(op);
        cur = start;
        i: i64 = 0;
        while i < slicelength {
            lim = step - 1;

            if u64(cur) + u64(step) >= u64(size) {
                lim = size - cur - 1;
            }
            memmove(
                ptr(items + (cur - i) * itemsize),
                ptr(items + (cur + 1) * itemsize),
                u64(lim * itemsize)
            );
            i += 1;
            if i < slicelength {
                cur += step;
            }
        }
        tail = u64(start) + u64(slicelength) * u64(step);
        if tail < u64(size) {
            tail_index = i64(tail);
            memmove(
                ptr(items + (tail_index - slicelength) * itemsize),
                ptr(items + tail_index * itemsize),
                u64((size - tail_index) * itemsize)
            );
        }
        if array_resize(self_, object_size(op) - slicelength) < 0 {
            return -1;
        }
        return 0;
    }
    if needed != slicelength {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8](
                "attempt to assign array of size %zd to extended slice of size %zd"
            ),
            needed,
            slicelength
        );
        return -1;
    }
    dest = self_.view(1)[0].ob_item;
    src = other.view(1)[0].ob_item;
    pos = start;
    j: i64 = 0;
    while j < slicelength {
        memcpy(ptr(dest + pos * itemsize), ptr(src + j * itemsize), u64(itemsize));
        j += 1;
        if j < slicelength {
            pos += step;
        }
    }
    return 0;
}

impl array_buffer_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
    if not view {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("array_buffer_getbuf: view==NULL argument is obsolete")
        );
        return -1;
    }

    self_ = ptr[arrayobject](op).view(1);
    descr = self_[0].ob_descr;
    v = view.view(1);
    v[0].buf = ptr(self_[0].ob_item);
    v[0].owner = object_new_ref(op);
    if not v[0].buf {
        v[0].buf = ptr(ptr[u8](""));
    }
    v[0].length = object_size(op) * i64(descr.view(1)[0].itemsize);
    v[0].readonly = 0;
    v[0].ndim = 1;
    v[0].itemsize = i64(descr.view(1)[0].itemsize);
    v[0].suboffsets = ptr[i64]();
    v[0].shape = ptr[i64]();
    if (flags & PyBUF_ND) == PyBUF_ND {
        v[0].shape = ptr[i64](ptr[u8](op) + PYVAROBJECT_OB_SIZE);
    }
    v[0].strides = ptr[i64]();
    if (flags & PyBUF_STRIDES) == PyBUF_STRIDES {
        v[0].strides = ptr[i64](ptr[u8](view) + PY_BUFFER_ITEMSIZE);
    }
    v[0].format_ = ptr[u8]();
    v[0].internal = ptr();
    if (flags & PyBUF_FORMAT) == PyBUF_FORMAT {
        v[0].format_ = descr.view(1)[0].formats;
        if descr.view(1)[0].typecode == u8(117) {
            v[0].format_ = ptr[u8]("w");
        }
    }

    self_[0].ob_exports += 1;
    return 0;
}

impl array_buffer_relbuf(op: ptr[PyObject], view: ptr[Py_buffer]) {
    ptr[arrayobject](op).view(1)[0].ob_exports -= 1;
}

impl array_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    state = find_array_state_by_type(type);
    array_type = state.view(1)[0].ArrayType;

    if (
        type == array_type
        or int(type.view(1)[0].tp_init) == int(array_type.view(1)[0].tp_init)
    )
        and kwds
        and _PyArg_NoKeywords(ptr[u8]("array.array"), kwds) == 0 {
        return NULL;
    }

    nargs = object_size(args);
    if nargs < 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("array() takes at least 1 argument (%zd given)"),
            nargs
        );
        return NULL;
    }
    if nargs > 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("array() takes at most 2 arguments (%zd given)"),
            nargs
        );
        return NULL;
    }
    arg = tuple_get_item(args, 0);
    if not unicode_check(arg) {
        tname = object_type(arg).view(1)[0].tp_name;
        if arg == Py_None {
            tname = ptr[u8]("None");
        }
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("array() argument 1 must be a unicode character, not %.50s"),
            tname
        );
        return NULL;
    }
    if unicode_length(arg) != 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "array() argument 1 must be a unicode character, not a string of length %zd"
            ),
            unicode_length(arg)
        );
        return NULL;
    }
    c = i32(PyUnicode_ReadChar(arg, 0));
    initial = NULL;
    if nargs == 2 {
        initial = tuple_get_item(args, 1);
    }

    audit_initial = initial;
    if not audit_initial {
        audit_initial = Py_None;
    }
    if PySys_Audit(ptr[u8]("array.__new__"), ptr[u8]("CO"), c, audit_initial) < 0 {
        return NULL;
    }

    if c == 117 {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            ptr[u8](
                "The 'u' type code is deprecated and will be removed in Python 3.16"
            ),
            1
        )
            != 0 {
            return NULL;
        }
    }

    is_unicode = c == 117 or c == 119;

    if initial and not is_unicode {
        if unicode_check(initial) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("cannot use a str to initialize an array with typecode '%c'"),
                c
            );
            return NULL;
        } elif array_Check(initial, state) {
            ic = i32(ptr[arrayobject](initial).view(1)[0].ob_descr.view(1)[0].typecode);
            if ic == 117 or ic == 119 {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8](
                        "cannot use a unicode array to initialize an array with typecode '%c'"
                    ),
                    c
                );
                return NULL;
            }
        }
    }

    it = NULL;
    if initial
        and not list_check(initial)
        and not bytearray_check(initial)
        and not bytes_check(initial)
        and not tuple_check(initial)
        and not (is_unicode and unicode_check(initial))
        and not (
            array_Check(initial, state)
            and c
                == i32(
                    ptr[arrayobject](initial).view(1)[0].ob_descr.view(1)[0].typecode
                )
        ) {
        it = PyObject_GetIter(initial);
        if not it {
            return NULL;
        }
        initial = NULL;
    }
    descr = ptr[arraydescr](addressof(descriptors));
    while descr.view(1)[0].typecode != u8(0) {
        if i32(descr.view(1)[0].typecode) == c {
            return array_new_descr(state, type, descr, c, initial, it);
        }
        descr = descr + 1;
    }
    object_xdecref(it);
    PyErr_SetString(
        PyExc_ValueError,
        ptr[u8]("bad typecode (must be b, B, u, w, h, H, i, I, l, L, q, Q, f or d)")
    );
    return NULL;
}

impl array_new_descr(
    state: ptr[array_state],
    type: ptr[PyTypeObject],
    descr: ptr[arraydescr],
    c: i32,
    initial: ptr[PyObject],
    it: ptr[PyObject]
) -> ptr[PyObject] {
    count: i64 = 0;
    if not initial {
        count = 0;
    } elif list_check(initial) {
        count = object_size(initial);
    } elif tuple_check(initial) or array_Check(initial, state) {
        count = object_size(initial);
    } else {
        count = 0;
    }

    a = newarrayobject(type, count, descr);
    if not a {
        object_xdecref(it);
        return NULL;
    }

    if count > 0 and not array_Check(initial, state) {
        i: i64 = 0;
        while i < count {
            v = PySequence_GetItem(initial, i);
            if not v {
                object_decref(a);
                object_xdecref(it);
                return NULL;
            }
            if setarrayitem(a, i, v) != 0 {
                object_decref(v);
                object_decref(a);
                object_xdecref(it);
                return NULL;
            }
            object_decref(v);
            i += 1;
        }
    } elif initial and (bytearray_check(initial) or bytes_check(initial)) {
        filled = array_array_frombytes(a, initial);
        if not filled {
            object_decref(a);
            object_xdecref(it);
            return NULL;
        }
        object_decref(filled);
    } elif initial and unicode_check(initial) {
        self_ = ptr[arrayobject](a).view(1);
        if c == 117 {
            wn: i64 = 0;
            wstr = PyUnicode_AsWideCharString(initial, &mut wn);
            if not wstr {
                object_decref(a);
                object_xdecref(it);
                return NULL;
            }

            if wn > 0 {
                PyMem_Free(self_[0].ob_item);
                self_[0].ob_item = ptr[u8](wstr);
                self_[0].ob_base.ob_size = wn;
                self_[0].allocated = wn;
            } else {
                PyMem_Free(wstr);
            }
        } else {
            un = unicode_length(initial);
            ustr = PyUnicode_AsUCS4Copy(initial);
            if not ustr {
                object_decref(a);
                object_xdecref(it);
                return NULL;
            }
            PyMem_Free(self_[0].ob_item);
            self_[0].ob_item = ptr[u8](ustr);
            self_[0].ob_base.ob_size = un;
            self_[0].allocated = un;
        }
    } elif initial and array_Check(initial, state) and count > 0 {
        other = ptr[arrayobject](initial);
        memcpy(
            ptr(ptr[arrayobject](a).view(1)[0].ob_item),
            ptr(other.view(1)[0].ob_item),
            u64(count * i64(other.view(1)[0].ob_descr.view(1)[0].itemsize))
        );
    }
    if it {
        if array_iter_extend(ptr[arrayobject](a), it) == -1 {
            object_decref(it);
            object_decref(a);
            return NULL;
        }
        object_decref(it);
    }
    return a;
}

impl array_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    ao = ptr[arrayobject](op);
    state = find_array_state_by_type(object_type(op));

    if not array_Check(op, state) {
        PyErr_BadInternalCall();
        return NULL;
    }

    it_obj = _PyObject_GC_New(ptr[PyObject](state.view(1)[0].ArrayIterType));
    if not it_obj {
        return NULL;
    }

    it = ptr[arrayiterobject](it_obj).view(1);
    it[0].ao = ptr[arrayobject](object_new_ref(op));
    it[0].index = 0;
    it[0].getitem = ao.view(1)[0].ob_descr.view(1)[0].getitem;
    PyObject_GC_Track(it_obj);
    return it_obj;
}

impl arrayiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[arrayiterobject](op).view(1);
    ao = it[0].ao;
    if not ao {
        return NULL;
    }
    index = it[0].index;
    if index < ao.view(1)[0].ob_base.ob_size {
        it[0].index = index + 1;
        return it[0].getitem(ao, index);
    }
    it[0].ao = ptr[arrayobject]();
    object_decref(ptr[PyObject](ao));
    return NULL;
}

impl arrayiter_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);
    PyObject_GC_UnTrack(op);
    object_xdecref(ptr[PyObject](ptr[arrayiterobject](op).view(1)[0].ao));
    PyObject_GC_Del(op);
    object_decref(ptr[PyObject](tp));
}

impl arrayiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(
        ptr[PyObject](ptr[arrayiterobject](op).view(1)[0].ao), visitor, arg
    );
}

impl array_arrayiterator___reduce___impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_array_state_by_class(cls);
    func = _PyEval_GetBuiltin(state.view(1)[0].str_iter);
    it = ptr[arrayiterobject](self_).view(1);
    if not it[0].ao {
        return Py_BuildValue(ptr[u8]("N(())"), func);
    }
    return Py_BuildValue(ptr[u8]("N(O)n"), func, ptr[PyObject](it[0].ao), it[0].index);
}

impl array_arrayiterator___setstate___impl(
    self_: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    it = ptr[arrayiterobject](self_).view(1);
    ao = it[0].ao;
    if ao {
        if index < 0 {
            index = 0;
        } elif index > ao.view(1)[0].ob_base.ob_size {
            index = ao.view(1)[0].ob_base.ob_size;
        }
        it[0].index = index;
    }
    return object_new_ref(Py_None);
}

impl array_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    st = get_array_state(module).view(1);
    status = visit_reference(ptr[PyObject](st[0].ArrayType), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyObject](st[0].ArrayIterType), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(st[0].array_reconstructor, visitor, arg);
}

impl clear_state_slot(slot: ptr[ptr[PyObject]]) {
    value = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(value);
}

impl array_clear(module: ptr[PyObject]) -> i32 {
    slots = ptr[ptr[PyObject]](get_array_state(module));
    clear_state_slot(slots);
    clear_state_slot(slots + 1);
    clear_state_slot(slots + 2);
    clear_state_slot(slots + 3);
    clear_state_slot(slots + 4);
    clear_state_slot(slots + 5);
    clear_state_slot(slots + 6);
    return 0;
}

impl array_free(module: ptr) {
    array_clear(ptr[PyObject](module));
}

impl array_modexec(m: ptr[PyObject]) -> i32 {
    st = get_array_state(m).view(1);

    st[0].array_reconstructor = NULL;
    tmp = PyUnicode_InternFromString(ptr[u8]("read"));
    if not tmp {
        return -1;
    }
    st[0].str_read = tmp;
    tmp = PyUnicode_InternFromString(ptr[u8]("write"));
    if not tmp {
        return -1;
    }
    st[0].str_write = tmp;
    tmp = PyUnicode_InternFromString(ptr[u8]("__dict__"));
    if not tmp {
        return -1;
    }
    st[0].str___dict__ = tmp;
    tmp = PyUnicode_InternFromString(ptr[u8]("iter"));
    if not tmp {
        return -1;
    }
    st[0].str_iter = tmp;

    tmp = PyType_FromModuleAndSpec(m, addressof(array_spec), NULL);
    if not tmp {
        return -1;
    }
    st[0].ArrayType = ptr[PyTypeObject](tmp);
    tmp = PyType_FromModuleAndSpec(m, addressof(arrayiter_spec), NULL);
    if not tmp {
        return -1;
    }
    st[0].ArrayIterType = ptr[PyTypeObject](tmp);
    ptr[_object](st[0].ArrayIterType).view(1)[0].ob_type = ptr[PyTypeObject](
        addressof(PyType_Type)
    );
    array_token.handle = ptr(addressof(array_spec));
    arrayiterator_token.handle = ptr(addressof(arrayiter_spec));

    array_type = ptr[PyObject](st[0].ArrayType);
    if PyModule_AddObjectRef(m, ptr[u8]("ArrayType"), array_type) < 0 {
        return -1;
    }

    mutablesequence = PyImport_ImportModuleAttrString(
        ptr[u8]("collections.abc"), ptr[u8]("MutableSequence")
    );
    if not mutablesequence {
        object_decref(array_type);
        return -1;
    }
    res = NULL;
    register = PyObject_GetAttrString(mutablesequence, ptr[u8]("register"));
    if register {
        res = PyObject_CallOneArg(register, array_type);
        object_decref(register);
    }
    object_decref(mutablesequence);
    if not res {
        object_decref(array_type);
        return -1;
    }
    object_decref(res);

    if PyModule_AddType(m, array_type) < 0 {
        return -1;
    }

    slots: own ArrayStack = ArrayStack();
    buffer = ptr[u8](jacpy_stack_address(&mut slots));
    p: i64 = 0;
    descr = ptr[arraydescr](addressof(descriptors));
    while descr.view(1)[0].typecode != u8(0) {
        (buffer + p).view(1)[0] = descr.view(1)[0].typecode;
        p += 1;
        descr = descr + 1;
    }
    typecodes = PyUnicode_DecodeASCII(ptr(buffer), p, ptr[u8]());
    if PyModule_Add(m, ptr[u8]("typecodes"), typecodes) < 0 {
        return -1;
    }

    return 0;
}
