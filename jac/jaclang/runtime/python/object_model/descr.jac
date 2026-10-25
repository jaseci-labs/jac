import from c {
    glob PyType_Type: PyTypeObject; def PyObject_Type(
        o: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_VectorcallDict(
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def PyType_GetQualName(
        type: ptr[PyTypeObject]
    ) -> ptr[PyObject];  def Py_HashPointer(p: ptr) -> i64;  def _PyType_GetTextSignatureFromInternalDoc(
        name: ptr[u8], internal_doc: ptr[u8], flags: i32
    ) -> ptr[PyObject];  def _PyType_GetDocFromInternalDoc(
        name: ptr[u8], internal_doc: ptr[u8]
    ) -> ptr[PyObject];  def _PyObject_FunctionStr(
        op: ptr[PyObject]
    ) -> ptr[PyObject];  def Py_EnterRecursiveCall(where: ptr[u8]) -> i32;  def Py_LeaveRecursiveCall;  def _PyStack_AsDict(
        values: ptr[ptr[PyObject]], kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_RealIsSubclass(
        derived: ptr[PyObject], cls: ptr[PyObject]
    ) -> i32;  def _PyObject_IsAbstract(ob: ptr[PyObject]) -> i32;  def _PyTuple_FromArray(
        src: ptr[ptr[PyObject]], n: i64
    ) -> ptr[PyObject];  obj DescrCall {
        has one: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            keywords:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            fast: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0,
            fast_keywords:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            method:
                Callable[
                    [
                        ptr[PyObject],
                        ptr[PyTypeObject],
                        ptr[ptr[PyObject]],
                        i64,
                        ptr[PyObject]
                    ],
                    ptr[PyObject]
                ] = 0,
            wrapper: Callable[[ptr[PyObject], ptr[PyObject], ptr], ptr[PyObject]] = 0,
            wrapper_kwds:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            get_fn: Callable[[ptr[PyObject], ptr], ptr[PyObject]] = 0,
            set_fn: Callable[[ptr[PyObject], ptr[PyObject], ptr], i32] = 0,
            free: Callable[[ptr], None] = 0;
    }  glob:priv qualname_key: ptr[PyObject] = ptr[PyObject](),
         name_key: ptr[PyObject] = ptr[PyObject](),
         doc_key: ptr[PyObject] = ptr[PyObject](),
         descr_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(descr_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         descr_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__objclass__"),
                 type_=_Py_T_OBJECT,
                 offset=PyDescrObject_TYPE,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__name__"),
                 type_=_Py_T_OBJECT,
                 offset=PyDescrObject_NAME,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         method_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=method_get_doc),
             PyGetSetDef(name=ptr[u8]("__qualname__"), get=descr_get_qualname),
             PyGetSetDef(
                 name=ptr[u8]("__text_signature__"), get=method_get_text_signature
             ),
             PyGetSetDef()
         ],
         member_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=member_get_doc),
             PyGetSetDef(name=ptr[u8]("__qualname__"), get=descr_get_qualname),
             PyGetSetDef()
         ],
         getset_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=getset_get_doc),
             PyGetSetDef(name=ptr[u8]("__qualname__"), get=descr_get_qualname),
             PyGetSetDef()
         ],
         wrapperdescr_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=wrapperdescr_get_doc),
             PyGetSetDef(name=ptr[u8]("__qualname__"), get=descr_get_qualname),
             PyGetSetDef(
                 name=ptr[u8]("__text_signature__"), get=wrapperdescr_get_text_signature
             ),
             PyGetSetDef()
         ],
         mappingproxy_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=mappingproxy_len, mp_subscript=mappingproxy_getitem
         ),
         mappingproxy_as_number: PyNumberMethods = PyNumberMethods(
             nb_or=mappingproxy_or, nb_inplace_or=mappingproxy_ior
         ),
         mappingproxy_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_contains=mappingproxy_contains
         ),
         mappingproxy_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(mappingproxy_get),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "get($self, key, default=None, /)\n--\n\n"
                     "Return the value for key if key is in the mapping, else default."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("keys"),
                 ml_meth=ptr(mappingproxy_keys),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "D.keys() -> a set-like object providing a view on D's keys"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("values"),
                 ml_meth=ptr(mappingproxy_values),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "D.values() -> an object providing a view on D's values"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("items"),
                 ml_meth=ptr(mappingproxy_items),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "D.items() -> a set-like object providing a view on D's items"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(mappingproxy_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("D.copy() -> a shallow copy of D")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "mappingproxy objects are generic over two types, signifying (respectively) the types of their keys and values"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(mappingproxy_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("D.__reversed__() -> reverse iterator")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         wrapper_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(wrapper_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         wrapper_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__self__"),
                 type_=_Py_T_OBJECT,
                 offset=wrapperobject_SELF,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         wrapper_getsets: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__objclass__"), get=wrapper_objclass),
             PyGetSetDef(name=ptr[u8]("__name__"), get=wrapper_name),
             PyGetSetDef(name=ptr[u8]("__qualname__"), get=wrapper_qualname),
             PyGetSetDef(name=ptr[u8]("__doc__"), get=wrapper_doc),
             PyGetSetDef(
                 name=ptr[u8]("__text_signature__"), get=wrapper_text_signature
             ),
             PyGetSetDef()
         ],
         property_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("fget"),
                 type_=_Py_T_OBJECT,
                 offset=propertyobject_GET,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("fset"),
                 type_=_Py_T_OBJECT,
                 offset=propertyobject_SET,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("fdel"),
                 type_=_Py_T_OBJECT,
                 offset=propertyobject_DEL,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__doc__"),
                 type_=_Py_T_OBJECT,
                 offset=propertyobject_DOC,
                 flags=0
             ),
             PyMemberDef()
         ],
         property_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("getter"),
                 ml_meth=ptr(property_getter),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Descriptor to obtain a copy of the property with a different getter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setter"),
                 ml_meth=ptr(property_setter),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Descriptor to obtain a copy of the property with a different setter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("deleter"),
                 ml_meth=ptr(property_deleter),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "Descriptor to obtain a copy of the property with a different deleter."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__set_name__"),
                 ml_meth=ptr(property_set_name),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "__set_name__($self, owner, name, /)\n--\n\nMethod to set name of a property."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         property_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__name__"),
                 get=property_get__name__,
                 set=property_set__name__
             ),
             PyGetSetDef(
                 name=ptr[u8]("__isabstractmethod__"),
                 get=property_get___isabstractmethod__
             ),
             PyGetSetDef()
         ]; glob PyMethodDescr_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("method_descriptor"),
             tp_basicsize=PyMethodDescrObject_SIZE,
             tp_dealloc=descr_dealloc,
             tp_vectorcall_offset=PyMethodDescrObject_VECTORCALL,
             tp_repr=method_repr,
             tp_call=PyVectorcall_Call,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_HAVE_VECTORCALL
                 | Py_TPFLAGS_METHOD_DESCRIPTOR,
             tp_traverse=descr_traverse,
             tp_methods=addressof(descr_methods),
             tp_members=addressof(descr_members),
             tp_getset=addressof(method_getset),
             tp_descr_get=method_get
         ),
         PyClassMethodDescr_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("classmethod_descriptor"),
             tp_basicsize=PyMethodDescrObject_SIZE,
             tp_dealloc=descr_dealloc,
             tp_repr=method_repr,
             tp_call=classmethoddescr_call,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=descr_traverse,
             tp_members=addressof(descr_members),
             tp_getset=addressof(method_getset),
             tp_descr_get=classmethod_get
         ),
         PyMemberDescr_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("member_descriptor"),
             tp_basicsize=PyMemberDescrObject_SIZE,
             tp_dealloc=descr_dealloc,
             tp_repr=member_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=descr_traverse,
             tp_methods=addressof(descr_methods),
             tp_members=addressof(descr_members),
             tp_getset=addressof(member_getset),
             tp_descr_get=member_get,
             tp_descr_set=member_set
         ),
         PyGetSetDescr_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("getset_descriptor"),
             tp_basicsize=PyGetSetDescrObject_SIZE,
             tp_dealloc=descr_dealloc,
             tp_repr=getset_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=descr_traverse,
             tp_members=addressof(descr_members),
             tp_getset=addressof(getset_getset),
             tp_descr_get=getset_get,
             tp_descr_set=getset_set
         ),
         PyWrapperDescr_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("wrapper_descriptor"),
             tp_basicsize=PyWrapperDescrObject_SIZE,
             tp_dealloc=descr_dealloc,
             tp_repr=wrapperdescr_repr,
             tp_call=wrapperdescr_call,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_METHOD_DESCRIPTOR,
             tp_traverse=descr_traverse,
             tp_methods=addressof(descr_methods),
             tp_members=addressof(descr_members),
             tp_getset=addressof(wrapperdescr_getset),
             tp_descr_get=wrapperdescr_get
         ),
         PyDictProxy_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("mappingproxy"),
             tp_basicsize=mappingproxyobject_SIZE,
             tp_dealloc=mappingproxy_dealloc,
             tp_repr=mappingproxy_repr,
             tp_as_number=addressof(mappingproxy_as_number),
             tp_as_sequence=addressof(mappingproxy_as_sequence),
             tp_as_mapping=addressof(mappingproxy_as_mapping),
             tp_hash=mappingproxy_hash,
             tp_str=mappingproxy_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_MAPPING,
             tp_doc=ptr[u8](
                 "mappingproxy(mapping)\n--\n\nRead-only proxy of a mapping."
             ),
             tp_traverse=mappingproxy_traverse,
             tp_richcompare=mappingproxy_richcompare,
             tp_iter=mappingproxy_getiter,
             tp_methods=addressof(mappingproxy_methods),
             tp_new=mappingproxy_new
         ),
         _PyMethodWrapper_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("method-wrapper"),
             tp_basicsize=wrapperobject_SIZE,
             tp_dealloc=wrapper_dealloc,
             tp_repr=wrapper_repr,
             tp_hash=wrapper_hash,
             tp_call=wrapper_call,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=wrapper_traverse,
             tp_richcompare=wrapper_richcompare,
             tp_methods=addressof(wrapper_methods),
             tp_members=addressof(wrapper_members),
             tp_getset=addressof(wrapper_getsets)
         ),
         PyProperty_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("property"),
             tp_basicsize=propertyobject_SIZE,
             tp_dealloc=property_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "property(fget=None, fset=None, fdel=None, doc=None)\n--\n\n"
                 "Property attribute.\n\n"
                 "  fget\n"
                 "    function to be used for getting an attribute value\n"
                 "  fset\n"
                 "    function to be used for setting an attribute value\n"
                 "  fdel\n"
                 "    function to be used for del'ing an attribute\n"
                 "  doc\n"
                 "    docstring\n\n"
                 "Typical use is to define a managed attribute x:\n\n"
                 "class C(object):\n"
                 "    def getx(self): return self._x\n"
                 "    def setx(self, value): self._x = value\n"
                 "    def delx(self): del self._x\n"
                 "    x = property(getx, setx, delx, \"I'm the 'x' property.\")\n\n"
                 "Decorators make defining new properties or modifying existing ones easy:\n\n"
                 "class C(object):\n"
                 "    @property\n"
                 "    def x(self):\n"
                 "        \"I am the 'x' property.\"\n"
                 "        return self._x\n"
                 "    @x.setter\n"
                 "    def x(self, value):\n"
                 "        self._x = value\n"
                 "    @x.deleter\n"
                 "    def x(self):\n"
                 "        del self._x"
             ),
             tp_traverse=property_traverse,
             tp_clear=property_clear,
             tp_methods=addressof(property_methods),
             tp_members=addressof(property_members),
             tp_getset=addressof(property_getsetlist),
             tp_descr_get=property_descr_get,
             tp_descr_set=property_descr_set,
             tp_init=property_init,
             tp_alloc=PyType_GenericAlloc,
             tp_new=PyType_GenericNew,
             tp_free=PyObject_GC_Del
         );
}

glob:priv mappingproxy_signature = CallSignature(
         "mappingproxy", ["mapping"], 1, 1, 0, parser=PARSE_KEYWORDS
     ),
     property_signature = CallSignature(
         "property", ["fget", "fset", "fdel", "doc"], 0, 4, 0, parser=PARSE_KEYWORDS
     );

def descr_of(op: ptr[PyObject]) -> ptr[PyDescrObject];

def descr_type(op: ptr[PyObject]) -> ptr[PyTypeObject];

def descr_name_object(op: ptr[PyObject]) -> ptr[PyObject];

def descr_field(op: ptr[PyObject], offset: i64) -> ptr;

def set_descr_field(op: ptr[PyObject], offset: i64, value: ptr);

def method_of(op: ptr[PyObject]) -> ptr[PyMethodDef];

def member_of(op: ptr[PyObject]) -> ptr[PyMemberDef];

def getset_of(op: ptr[PyObject]) -> ptr[PyGetSetDef];

def wrapper_base(op: ptr[PyObject]) -> ptr[wrapperbase];

def type_name(type: ptr[PyTypeObject]) -> ptr[u8];

def unicode_check(op: ptr[PyObject]) -> bool;

def type_check(op: ptr[PyObject]) -> bool;

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def interned(slot: int, text: str) -> ptr[PyObject];

def descr_dealloc(self: ptr[PyObject]);

def descr_name(op: ptr[PyObject]) -> ptr[PyObject];

def descr_repr(op: ptr[PyObject], format: str) -> ptr[PyObject];

def method_repr(op: ptr[PyObject]) -> ptr[PyObject];

def member_repr(op: ptr[PyObject]) -> ptr[PyObject];

def getset_repr(op: ptr[PyObject]) -> ptr[PyObject];

def wrapperdescr_repr(op: ptr[PyObject]) -> ptr[PyObject];

def descr_check(op: ptr[PyObject], ob: ptr[PyObject]) -> i32;

def classmethod_get(
    self: ptr[PyObject], ob: ptr[PyObject], type_in: ptr[PyObject]
) -> ptr[PyObject];

def method_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def member_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def getset_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def wrapperdescr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def member_set(self: ptr[PyObject], ob: ptr[PyObject], value: ptr[PyObject]) -> i32;

def getset_set(self: ptr[PyObject], ob: ptr[PyObject], value: ptr[PyObject]) -> i32;

def function_error(func: ptr[PyObject], format: ptr[u8], n: i64);

def method_check_args(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> i32;

def method_enter_call(func: ptr[PyObject]) -> int;

def method_vectorcall_VARARGS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def method_vectorcall_VARARGS_KEYWORDS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def method_vectorcall_FASTCALL_KEYWORDS_METHOD(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def method_vectorcall_FASTCALL(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def method_vectorcall_FASTCALL_KEYWORDS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def method_vectorcall_NOARGS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def method_vectorcall_O(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def classmethoddescr_call(
    descr: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def wrapperdescr_raw_call(
    descr: ptr[PyObject], self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def wrapperdescr_call(
    descr: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def method_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def method_get_text_signature(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def calculate_qualname(descr: ptr[PyObject]) -> ptr[PyObject];

def descr_get_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def descr_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def member_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def getset_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapperdescr_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapperdescr_get_text_signature(
    descr: ptr[PyObject], _closure: ptr
) -> ptr[PyObject];

def descr_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def descr_new(
    descrtype: ptr[PyTypeObject], type: ptr[PyTypeObject], name: ptr[u8]
) -> ptr[PyObject];

def method_vectorcall_for(flags: i32) -> ptr;

import from c {
    def PyDescr_NewMethod(
        type: ptr[PyTypeObject], method: ptr[PyMethodDef]
    ) -> ptr[PyObject] {
        vectorcall = method_vectorcall_for(method.view(1)[0].ml_flags);
        if not vectorcall {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("%s() method: bad call flags"),
                method.view(1)[0].ml_name
            );
            return NULL;
        }
        descr = descr_new(
            addressof(PyMethodDescr_Type), type, method.view(1)[0].ml_name
        );
        if descr {
            set_descr_field(descr, PyMethodDescrObject_METHOD, ptr(method));
            set_descr_field(descr, PyMethodDescrObject_VECTORCALL, vectorcall);
        }
        return descr;
    }  def PyDescr_NewClassMethod(
        type: ptr[PyTypeObject], method: ptr[PyMethodDef]
    ) -> ptr[PyObject] {
        descr = descr_new(
            addressof(PyClassMethodDescr_Type), type, method.view(1)[0].ml_name
        );
        if descr {
            set_descr_field(descr, PyMethodDescrObject_METHOD, ptr(method));
        }
        return descr;
    }  def PyDescr_NewMember(
        type: ptr[PyTypeObject], member: ptr[PyMemberDef]
    ) -> ptr[PyObject] {
        if (member.view(1)[0].flags & Py_RELATIVE_OFFSET) != 0 {
            PyErr_SetString(
                PyExc_SystemError,
                ptr[u8]("PyDescr_NewMember used with Py_RELATIVE_OFFSET")
            );
            return NULL;
        }
        descr = descr_new(addressof(PyMemberDescr_Type), type, member.view(1)[0].name);
        if descr {
            set_descr_field(descr, PyMemberDescrObject_MEMBER, ptr(member));
        }
        return descr;
    }  def PyDescr_NewGetSet(
        type: ptr[PyTypeObject], getset: ptr[PyGetSetDef]
    ) -> ptr[PyObject] {
        descr = descr_new(addressof(PyGetSetDescr_Type), type, getset.view(1)[0].name);
        if descr {
            set_descr_field(descr, PyGetSetDescrObject_GETSET, ptr(getset));
        }
        return descr;
    }  def PyDescr_NewWrapper(
        type: ptr[PyTypeObject], base: ptr[wrapperbase], wrapped: ptr
    ) -> ptr[PyObject] {
        descr = descr_new(addressof(PyWrapperDescr_Type), type, base.view(1)[0].name);
        if descr {
            set_descr_field(descr, PyWrapperDescrObject_BASE, ptr(base));
            set_descr_field(descr, PyWrapperDescrObject_WRAPPED, wrapped);
        }
        return descr;
    }  def PyDescr_IsData(ob: ptr[PyObject]) -> i32 {
        return i32(1) if int(object_type(ob).view(1)[0].tp_descr_set) != 0 else i32(0);
    }  def PyDictProxy_New(mapping: ptr[PyObject]) -> ptr[PyObject] {
        if mappingproxy_check_mapping(mapping) == -1 {
            return NULL;
        }
        pp = _PyObject_GC_New(ptr[PyObject](addressof(PyDictProxy_Type)));
        if pp {
            ptr[mappingproxyobject](pp).view(1)[0].mapping = ptr[PyObject](
                object_new_ref(mapping)
            );
            object_gc_track(pp);
        }
        return pp;
    }  def PyWrapper_New(d: ptr[PyObject], self: ptr[PyObject]) -> ptr[PyObject] {
        wp = _PyObject_GC_New(ptr[PyObject](addressof(_PyMethodWrapper_Type)));
        if wp {
            w = ptr[wrapperobject](wp);
            w.view(1)[0].descr = ptr[PyWrapperDescrObject](object_new_ref(d));
            w.view(1)[0].self = ptr[PyObject](object_new_ref(self));
            object_gc_track(wp);
        }
        return wp;
    }
}

def proxy_mapping(op: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_len(self: ptr[PyObject]) -> i64;

def mappingproxy_getitem(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_or(left_in: ptr[PyObject], right_in: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_ior(self: ptr[PyObject], _other: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_contains(self: ptr[PyObject], key: ptr[PyObject]) -> i32;

def call_mapping_method(self: ptr[PyObject], name: str) -> ptr[PyObject];

def mappingproxy_get(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def mappingproxy_keys(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_values(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_items(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_copy(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_reversed(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def mappingproxy_dealloc(self: ptr[PyObject]);

def mappingproxy_getiter(self: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_hash(self: ptr[PyObject]) -> i64;

def mappingproxy_str(self: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_repr(self: ptr[PyObject]) -> ptr[PyObject];

def mappingproxy_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def mappingproxy_richcompare(
    self: ptr[PyObject], w: ptr[PyObject], op: i32
) -> ptr[PyObject];

def mappingproxy_check_mapping(mapping: ptr[PyObject]) -> i32;

def mappingproxy_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def mappingproxy_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def wrapper_descr(op: ptr[PyObject]) -> ptr[PyObject];

def wrapper_self(op: ptr[PyObject]) -> ptr[PyObject];

def wrapper_dealloc(self: ptr[PyObject]);

def wrapper_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];

def wrapper_hash(self: ptr[PyObject]) -> i64;

def wrapper_repr(self: ptr[PyObject]) -> ptr[PyObject];

def wrapper_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def wrapper_objclass(wp: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapper_name(wp: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapper_doc(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapper_text_signature(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapper_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def wrapper_call(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def wrapper_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def prop_of(op: ptr[PyObject]) -> ptr[propertyobject];

def prop_get(op: ptr[PyObject]) -> ptr[PyObject];

def prop_set(op: ptr[PyObject]) -> ptr[PyObject];

def prop_del(op: ptr[PyObject]) -> ptr[PyObject];

def prop_doc(op: ptr[PyObject]) -> ptr[PyObject];

def prop_name(op: ptr[PyObject]) -> ptr[PyObject];

def prop_store(op: ptr[PyObject], field: int, value: ptr[PyObject]);

def property_getter(self: ptr[PyObject], getter_fn: ptr[PyObject]) -> ptr[PyObject];

def property_setter(self: ptr[PyObject], setter_fn: ptr[PyObject]) -> ptr[PyObject];

def property_deleter(self: ptr[PyObject], deleter_fn: ptr[PyObject]) -> ptr[PyObject];

def property_set_name(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def property_dealloc(self: ptr[PyObject]);

def property_name(op: ptr[PyObject]) -> tuple[i32, ptr[PyObject]];

def missing_accessor(op: ptr[PyObject], ob: ptr[PyObject], what: str);

def property_descr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def property_descr_set(
    self: ptr[PyObject], ob: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def property_copy(
    old: ptr[PyObject],
    get_in: ptr[PyObject],
    set_in: ptr[PyObject],
    del_in: ptr[PyObject]
) -> ptr[PyObject];

def property_init_impl(
    self: ptr[PyObject],
    fget_in: ptr[PyObject],
    fset_in: ptr[PyObject],
    fdel_in: ptr[PyObject],
    doc: ptr[PyObject]
) -> i32;

def property_init_values(
    self: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def property_init(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def property_get__name__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def property_set__name__(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32;

def property_get___isabstractmethod__(
    op: ptr[PyObject], _closure: ptr
) -> ptr[PyObject];

def property_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def property_clear(self: ptr[PyObject]) -> i32;

impl descr_of(op: ptr[PyObject]) -> ptr[PyDescrObject] {
    return ptr[PyDescrObject](op);
}

impl descr_type(op: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](descr_of(op).view(1)[0].d_type);
}

impl descr_name_object(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](descr_of(op).view(1)[0].d_name);
}

impl descr_field(op: ptr[PyObject], offset: i64) -> ptr {
    return ptr[ptr](ptr[u8](op) + offset).view(1)[0];
}

impl set_descr_field(op: ptr[PyObject], offset: i64, value: ptr) {
    ptr[ptr](ptr[u8](op) + offset).view(1)[0] = value;
}

impl method_of(op: ptr[PyObject]) -> ptr[PyMethodDef] {
    return ptr[PyMethodDef](descr_field(op, PyMethodDescrObject_METHOD));
}

impl member_of(op: ptr[PyObject]) -> ptr[PyMemberDef] {
    return ptr[PyMemberDef](descr_field(op, PyMemberDescrObject_MEMBER));
}

impl getset_of(op: ptr[PyObject]) -> ptr[PyGetSetDef] {
    return ptr[PyGetSetDef](descr_field(op, PyGetSetDescrObject_GETSET));
}

impl wrapper_base(op: ptr[PyObject]) -> ptr[wrapperbase] {
    return ptr[wrapperbase](descr_field(op, PyWrapperDescrObject_BASE));
}

impl type_name(type: ptr[PyTypeObject]) -> ptr[u8] {
    return type.view(1)[0].tp_name;
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl type_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl interned(slot: int, text: str) -> ptr[PyObject] {
    if slot == 0 {
        if not qualname_key {
            qualname_key = jacpy_unicode_intern_text(text);
        }
        return qualname_key;
    }
    if slot == 1 {
        if not name_key {
            name_key = jacpy_unicode_intern_text(text);
        }
        return name_key;
    }
    if not doc_key {
        doc_key = jacpy_unicode_intern_text(text);
    }
    return doc_key;
}

impl descr_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    d = descr_of(self);
    object_xdecref(ptr[PyObject](d.view(1)[0].d_type));
    object_xdecref(ptr[PyObject](d.view(1)[0].d_name));
    object_xdecref(ptr[PyObject](d.view(1)[0].d_qualname));
    PyObject_GC_Del(ptr(self));
}

impl descr_name(op: ptr[PyObject]) -> ptr[PyObject] {
    name = descr_name_object(op);
    if name and unicode_check(name) {
        return name;
    }
    return NULL;
}

impl descr_repr(op: ptr[PyObject], format: str) -> ptr[PyObject] {
    return PyUnicode_FromFormat(format, descr_name(op), "?", type_name(descr_type(op)));
}

impl method_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return descr_repr(op, "<method '%V' of '%s' objects>");
}

impl member_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return descr_repr(op, "<member '%V' of '%s' objects>");
}

impl getset_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return descr_repr(op, "<attribute '%V' of '%s' objects>");
}

impl wrapperdescr_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return descr_repr(op, "<slot wrapper '%V' of '%s' objects>");
}

impl descr_check(op: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
    if not object_type_check(ob, descr_type(op)) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "descriptor '%V' for '%.100s' objects doesn't apply to a '%.100s' object"
            ),
            descr_name(op),
            "?",
            type_name(descr_type(op)),
            type_name(object_type(ob))
        );
        return i32(-1);
    }
    return i32(0);
}

impl classmethod_get(
    self: ptr[PyObject], ob: ptr[PyObject], type_in: ptr[PyObject]
) -> ptr[PyObject] {
    type = type_in;

    if not type {
        if not ob {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "descriptor '%V' for type '%.100s' needs either an object or a type"
                ),
                descr_name(self),
                "?",
                type_name(descr_type(self))
            );
            return NULL;
        }
        type = ptr[PyObject](object_type(ob));
    }
    if not type_check(type) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "descriptor '%V' for type '%.100s' needs a type, not a '%.100s' as arg 2"
            ),
            descr_name(self),
            "?",
            type_name(descr_type(self)),
            type_name(object_type(type))
        );
        return NULL;
    }
    if PyType_IsSubtype(type, ptr[PyObject](descr_type(self))) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "descriptor '%V' requires a subtype of '%.100s' but received '%.100s'"
            ),
            descr_name(self),
            "?",
            type_name(descr_type(self)),
            type_name(ptr[PyTypeObject](type))
        );
        return NULL;
    }
    cls = ptr[PyTypeObject]();
    if (method_of(self).view(1)[0].ml_flags & METH_METHOD) != 0 {
        cls = descr_type(self);
    }
    return PyCMethod_New(method_of(self), type, NULL, cls);
}

impl method_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if not ob {
        return object_new_ref(self);
    }
    if descr_check(self, ob) < 0 {
        return NULL;
    }
    if (method_of(self).view(1)[0].ml_flags & METH_METHOD) != 0 {
        if not type or type_check(type) {
            return PyCMethod_New(method_of(self), ob, NULL, descr_type(self));
        }
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("descriptor '%V' needs a type, not '%s', as arg 2"),
            descr_name(self),
            "?",
            type_name(object_type(type))
        );
        return NULL;
    }
    return PyCFunction_NewEx(method_of(self), ob, NULL);
}

impl member_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if not ob {
        return object_new_ref(self);
    }
    if descr_check(self, ob) < 0 {
        return NULL;
    }
    member = member_of(self);
    if (member.view(1)[0].flags & Py_AUDIT_READ) != 0 {
        if PySys_Audit("object.__getattr__", "Os", ob, member.view(1)[0].name) < 0 {
            return NULL;
        }
    }
    return PyMember_GetOne(ptr[u8](ob), member);
}

impl getset_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if not ob {
        return object_new_ref(self);
    }
    if descr_check(self, ob) < 0 {
        return NULL;
    }
    getset = getset_of(self);
    if int(getset.view(1)[0].get) != 0 {
        calls = ptr[DescrCall](
            __thread_local_block("jac_object_model_descr_call_slot", 80)
        );
        calls.view(1)[0].get_fn = int(getset.view(1)[0].get);
        return calls.view(1)[0].get_fn(ob, getset.view(1)[0].closure);
    }
    PyErr_Format(
        PyExc_AttributeError,
        ptr[u8]("attribute '%V' of '%.100s' objects is not readable"),
        descr_name(self),
        "?",
        type_name(descr_type(self))
    );
    return NULL;
}

impl wrapperdescr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if not ob {
        return object_new_ref(self);
    }
    if descr_check(self, ob) < 0 {
        return NULL;
    }
    return PyWrapper_New(self, ob);
}

impl member_set(self: ptr[PyObject], ob: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if descr_check(self, ob) < 0 {
        return i32(-1);
    }
    return PyMember_SetOne(ptr[u8](ob), member_of(self), value);
}

impl getset_set(self: ptr[PyObject], ob: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if descr_check(self, ob) < 0 {
        return i32(-1);
    }
    getset = getset_of(self);
    if int(getset.view(1)[0].set) != 0 {
        calls = ptr[DescrCall](
            __thread_local_block("jac_object_model_descr_call_slot", 80)
        );
        calls.view(1)[0].set_fn = int(getset.view(1)[0].set);
        return calls.view(1)[0].set_fn(ob, value, getset.view(1)[0].closure);
    }
    PyErr_Format(
        PyExc_AttributeError,
        ptr[u8]("attribute '%V' of '%.100s' objects is not writable"),
        descr_name(self),
        "?",
        type_name(descr_type(self))
    );
    return i32(-1);
}

impl function_error(func: ptr[PyObject], format: ptr[u8], n: i64) {
    funcstr = _PyObject_FunctionStr(func);
    if funcstr {
        PyErr_Format(PyExc_TypeError, format, funcstr, n);
        object_decref(funcstr);
    }
}

impl method_check_args(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> i32 {
    if nargs < 1 {
        function_error(func, ptr[u8]("unbound method %U needs an argument"), 0);
        return i32(-1);
    }
    if descr_check(func, args.view(1)[0]) < 0 {
        return i32(-1);
    }
    if kwnames and object_size(kwnames) != 0 {
        function_error(func, ptr[u8]("%U takes no keyword arguments"), 0);
        return i32(-1);
    }
    return i32(0);
}

impl method_enter_call(func: ptr[PyObject]) -> int {
    if Py_EnterRecursiveCall(ptr[u8](" while calling a Python object")) != 0 {
        return 0;
    }
    return int(method_of(func).view(1)[0].ml_meth);
}

impl method_vectorcall_VARARGS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, kwnames) != 0 {
        return NULL;
    }
    argstuple = _PyTuple_FromArray(args + 1, nargs - 1);
    if not argstuple {
        return NULL;
    }
    meth = method_enter_call(func);
    if meth == 0 {
        object_decref(argstuple);
        return NULL;
    }
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].one = meth;
    result = calls.view(1)[0].one(args.view(1)[0], argstuple);
    object_decref(argstuple);
    Py_LeaveRecursiveCall();
    return result;
}

impl method_vectorcall_VARARGS_KEYWORDS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, NULL) != 0 {
        return NULL;
    }
    argstuple = _PyTuple_FromArray(args + 1, nargs - 1);
    if not argstuple {
        return NULL;
    }
    result: ptr[PyObject] = NULL;

    kwdict: ptr[PyObject] = NULL;
    failed = False;
    if kwnames and object_size(kwnames) > 0 {
        kwdict = _PyStack_AsDict(args + nargs, kwnames);
        failed = not kwdict;
    }
    if not failed {
        meth = method_enter_call(func);
        if meth != 0 {
            calls = ptr[DescrCall](
                __thread_local_block("jac_object_model_descr_call_slot", 80)
            );
            calls.view(1)[0].keywords = meth;
            result = calls.view(1)[0].keywords(args.view(1)[0], argstuple, kwdict);
            Py_LeaveRecursiveCall();
        }
    }
    object_decref(argstuple);
    object_xdecref(kwdict);
    return result;
}

impl method_vectorcall_FASTCALL_KEYWORDS_METHOD(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, NULL) != 0 {
        return NULL;
    }
    meth = method_enter_call(func);
    if meth == 0 {
        return NULL;
    }
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].method = meth;
    result = calls.view(1)[0].method(
        args.view(1)[0], descr_type(func), args + 1, nargs - 1, kwnames
    );
    Py_LeaveRecursiveCall();
    return result;
}

impl method_vectorcall_FASTCALL(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, kwnames) != 0 {
        return NULL;
    }
    meth = method_enter_call(func);
    if meth == 0 {
        return NULL;
    }
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].fast = meth;
    result = calls.view(1)[0].fast(args.view(1)[0], args + 1, nargs - 1);
    Py_LeaveRecursiveCall();
    return result;
}

impl method_vectorcall_FASTCALL_KEYWORDS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, NULL) != 0 {
        return NULL;
    }
    meth = method_enter_call(func);
    if meth == 0 {
        return NULL;
    }
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].fast_keywords = meth;
    result = calls.view(1)[0].fast_keywords(
        args.view(1)[0], args + 1, nargs - 1, kwnames
    );
    Py_LeaveRecursiveCall();
    return result;
}

impl method_vectorcall_NOARGS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, kwnames) != 0 {
        return NULL;
    }
    if nargs != 1 {
        function_error(func, ptr[u8]("%U takes no arguments (%zd given)"), nargs - 1);
        return NULL;
    }
    meth = method_enter_call(func);
    if meth == 0 {
        return NULL;
    }
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].one = meth;
    result = calls.view(1)[0].one(args.view(1)[0], NULL);
    Py_LeaveRecursiveCall();
    return result;
}

impl method_vectorcall_O(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if method_check_args(func, args, nargs, kwnames) != 0 {
        return NULL;
    }
    if nargs != 2 {
        function_error(
            func, ptr[u8]("%U takes exactly one argument (%zd given)"), nargs - 1
        );
        return NULL;
    }
    meth = method_enter_call(func);
    if meth == 0 {
        return NULL;
    }
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].one = meth;
    result = calls.view(1)[0].one(args.view(1)[0], (args + 1).view(1)[0]);
    Py_LeaveRecursiveCall();
    return result;
}

impl classmethoddescr_call(
    descr: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    argc = object_size(args);
    if argc < 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("descriptor '%V' of '%.100s' object needs an argument"),
            descr_name(descr),
            "?",
            type_name(descr_type(descr))
        );
        return NULL;
    }
    bound = classmethod_get(descr, NULL, tuple_get_item(args, 0));
    if not bound {
        return NULL;
    }
    res = PyObject_VectorcallDict(bound, tuple_items(args) + 1, u64(argc - 1), kwds);
    object_decref(bound);
    return res;
}

impl wrapperdescr_raw_call(
    descr: ptr[PyObject], self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    base = wrapper_base(descr);
    wrapped = descr_field(descr, PyWrapperDescrObject_WRAPPED);
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    if (base.view(1)[0].flags & PyWrapperFlag_KEYWORDS) != 0 {
        calls.view(1)[0].wrapper_kwds = int(base.view(1)[0].wrapper);
        return calls.view(1)[0].wrapper_kwds(self, args, wrapped, kwds);
    }
    if kwds
        and (
            not type_has_feature(object_type(kwds), Py_TPFLAGS_DICT_SUBCLASS)
            or PyDict_Size(kwds) != 0
        ) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("wrapper %s() takes no keyword arguments"),
            base.view(1)[0].name
        );
        return NULL;
    }
    calls.view(1)[0].wrapper = int(base.view(1)[0].wrapper);
    return calls.view(1)[0].wrapper(self, args, wrapped);
}

impl wrapperdescr_call(
    descr: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    argc = object_size(args);
    if argc < 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("descriptor '%V' of '%.100s' object needs an argument"),
            descr_name(descr),
            "?",
            type_name(descr_type(descr))
        );
        return NULL;
    }
    self = tuple_get_item(args, 0);
    if _PyObject_RealIsSubclass(
        ptr[PyObject](object_type(self)), ptr[PyObject](descr_type(descr))
    )
        == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "descriptor '%V' requires a '%.100s' object but received a '%.100s'"
            ),
            descr_name(descr),
            "?",
            type_name(descr_type(descr)),
            type_name(object_type(self))
        );
        return NULL;
    }
    rest = PyTuple_GetSlice(args, 1, argc);
    if not rest {
        return NULL;
    }
    result = wrapperdescr_raw_call(descr, self, rest, kwds);
    object_decref(rest);
    return result;
}

impl method_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    method = method_of(descr);
    return _PyType_GetDocFromInternalDoc(
        method.view(1)[0].ml_name, method.view(1)[0].ml_doc
    );
}

impl method_get_text_signature(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    method = method_of(descr);
    return _PyType_GetTextSignatureFromInternalDoc(
        method.view(1)[0].ml_name, method.view(1)[0].ml_doc, method.view(1)[0].ml_flags
    );
}

impl calculate_qualname(descr: ptr[PyObject]) -> ptr[PyObject] {
    name = descr_name_object(descr);
    if not name or not unicode_check(name) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("<descriptor>.__name__ is not a unicode object")
        );
        return NULL;
    }
    type_qualname = PyObject_GetAttr(
        ptr[PyObject](descr_type(descr)), interned(0, "__qualname__")
    );
    if not type_qualname {
        return NULL;
    }
    if not unicode_check(type_qualname) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("<descriptor>.__objclass__.__qualname__ is not a unicode object")
        );
        object_decref(type_qualname);
        return NULL;
    }
    res = PyUnicode_FromFormat("%S.%S", type_qualname, name);
    object_decref(type_qualname);
    return res;
}

impl descr_get_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    d = descr_of(self);
    if not d.view(1)[0].d_qualname {
        d.view(1)[0].d_qualname = ptr[PyObject](calculate_qualname(self));
    }
    return object_xnew_ref(ptr[PyObject](d.view(1)[0].d_qualname));
}

impl descr_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    getattr = eval_builtin("getattr");
    if not getattr {
        return NULL;
    }
    return Py_BuildValue(
        ptr[u8]("N(OO)"), getattr, ptr(descr_type(self)), descr_name_object(self)
    );
}

impl member_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    doc = member_of(descr).view(1)[0].doc;
    if not doc {
        return object_new_ref(Py_None);
    }
    return PyUnicode_FromString(doc);
}

impl getset_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    doc = getset_of(descr).view(1)[0].doc;
    if not doc {
        return object_new_ref(Py_None);
    }
    return PyUnicode_FromString(doc);
}

impl wrapperdescr_get_doc(descr: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    base = wrapper_base(descr);
    return _PyType_GetDocFromInternalDoc(base.view(1)[0].name, base.view(1)[0].doc);
}

impl wrapperdescr_get_text_signature(
    descr: ptr[PyObject], _closure: ptr
) -> ptr[PyObject] {
    base = wrapper_base(descr);
    return _PyType_GetTextSignatureFromInternalDoc(
        base.view(1)[0].name, base.view(1)[0].doc, i32(0)
    );
}

impl descr_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](descr_type(self)), visitor, arg);
}

impl descr_new(
    descrtype: ptr[PyTypeObject], type: ptr[PyTypeObject], name: ptr[u8]
) -> ptr[PyObject] {
    descr = PyType_GenericAlloc(ptr[PyObject](descrtype), 0);
    if not descr {
        return NULL;
    }
    d = descr_of(descr);
    d.view(1)[0].d_type = ptr[PyTypeObject](object_xnew_ref(ptr[PyObject](type)));
    interned_name = PyUnicode_InternFromString(name);
    d.view(1)[0].d_name = ptr[PyObject](interned_name);
    if not interned_name {
        object_decref(descr);
        return NULL;
    }
    d.view(1)[0].d_qualname = ptr[PyObject]();
    return descr;
}

impl method_vectorcall_for(flags: i32) -> ptr {
    kind = flags
        & (
            METH_VARARGS
            | METH_FASTCALL
            | METH_NOARGS
            | METH_O
            | METH_KEYWORDS
            | METH_METHOD
        );
    if kind == METH_VARARGS {
        return ptr(method_vectorcall_VARARGS);
    }
    if kind == (METH_VARARGS | METH_KEYWORDS) {
        return ptr(method_vectorcall_VARARGS_KEYWORDS);
    }
    if kind == METH_FASTCALL {
        return ptr(method_vectorcall_FASTCALL);
    }
    if kind == (METH_FASTCALL | METH_KEYWORDS) {
        return ptr(method_vectorcall_FASTCALL_KEYWORDS);
    }
    if kind == METH_NOARGS {
        return ptr(method_vectorcall_NOARGS);
    }
    if kind == METH_O {
        return ptr(method_vectorcall_O);
    }
    if kind == (METH_METHOD | METH_FASTCALL | METH_KEYWORDS) {
        return ptr(method_vectorcall_FASTCALL_KEYWORDS_METHOD);
    }
    return ptr();
}

impl proxy_mapping(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](ptr[mappingproxyobject](op).view(1)[0].mapping);
}

impl mappingproxy_len(self: ptr[PyObject]) -> i64 {
    return PyObject_Size(proxy_mapping(self));
}

impl mappingproxy_getitem(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_GetItem(proxy_mapping(self), key);
}

impl mappingproxy_or(left_in: ptr[PyObject], right_in: ptr[PyObject]) -> ptr[PyObject] {
    left = left_in;
    right = right_in;
    if object_type_check(left, addressof(PyDictProxy_Type)) {
        left = proxy_mapping(left);
    }
    if object_type_check(right, addressof(PyDictProxy_Type)) {
        right = proxy_mapping(right);
    }
    return PyNumber_Or(left, right);
}

impl mappingproxy_ior(self: ptr[PyObject], _other: ptr[PyObject]) -> ptr[PyObject] {
    return PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'|=' is not supported by %s; use '|' instead"),
        type_name(object_type(self))
    );
}

impl mappingproxy_contains(self: ptr[PyObject], key: ptr[PyObject]) -> i32 {
    mapping = proxy_mapping(self);
    if object_is_type(mapping, ptr[PyTypeObject](addressof(PyDict_Type))) {
        return PyDict_Contains(mapping, key);
    }
    return PySequence_Contains(mapping, key);
}

impl call_mapping_method(self: ptr[PyObject], name: str) -> ptr[PyObject] {
    method = jacpy_unicode_intern_text(name);
    if not method {
        return NULL;
    }
    res = PyObject_CallMethodObjArgs(proxy_mapping(self), method, ptr());
    object_decref(method);
    return res;
}

impl mappingproxy_get(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("get"), nargs, 1, 2) == 0 {
        return NULL;
    }
    default_value = (args + 1).view(1)[0] if nargs > 1 else Py_None;
    method = PyUnicode_InternFromString(ptr[u8]("get"));
    if not method {
        return NULL;
    }
    res = PyObject_CallMethodObjArgs(
        proxy_mapping(self), method, args.view(1)[0], default_value, ptr()
    );
    object_decref(method);
    return res;
}

impl mappingproxy_keys(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return call_mapping_method(self, "keys");
}

impl mappingproxy_values(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return call_mapping_method(self, "values");
}

impl mappingproxy_items(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return call_mapping_method(self, "items");
}

impl mappingproxy_copy(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return call_mapping_method(self, "copy");
}

impl mappingproxy_reversed(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return call_mapping_method(self, "__reversed__");
}

impl mappingproxy_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    object_decref(proxy_mapping(self));
    PyObject_GC_Del(ptr(self));
}

impl mappingproxy_getiter(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_GetIter(proxy_mapping(self));
}

impl mappingproxy_hash(self: ptr[PyObject]) -> i64 {
    return PyObject_Hash(proxy_mapping(self));
}

impl mappingproxy_str(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_Str(proxy_mapping(self));
}

impl mappingproxy_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat("mappingproxy(%R)", proxy_mapping(self));
}

impl mappingproxy_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(proxy_mapping(self), visitor, arg);
}

impl mappingproxy_richcompare(
    self: ptr[PyObject], w: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    return PyObject_RichCompare(proxy_mapping(self), w, op);
}

impl mappingproxy_check_mapping(mapping: ptr[PyObject]) -> i32 {
    if PyMapping_Check(mapping) == 0
        or type_has_feature(object_type(mapping), Py_TPFLAGS_LIST_SUBCLASS)
        or type_has_feature(object_type(mapping), Py_TPFLAGS_TUPLE_SUBCLASS) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("mappingproxy() argument must be a mapping, not %s"),
            type_name(object_type(mapping))
        );
        return i32(-1);
    }
    return i32(0);
}

impl mappingproxy_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    return PyDictProxy_New(values.view(1)[0]);
}

impl mappingproxy_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwargs and object_size(args) == 1 {
        return PyDictProxy_New(tuple_get_item(args, 0));
    }
    return invoke_tuple(
        mappingproxy_signature, args, kwargs, mappingproxy_new_values, type
    );
}

impl wrapper_descr(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](ptr[wrapperobject](op).view(1)[0].descr);
}

impl wrapper_self(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](ptr[wrapperobject](op).view(1)[0].self);
}

impl wrapper_dealloc(self: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(self));
    object_xdecref(wrapper_descr(self));
    object_xdecref(wrapper_self(self));
    PyObject_GC_Del(ptr(self));
}

impl wrapper_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    wrapper_type = addressof(_PyMethodWrapper_Type);
    if (op != Py_EQ and op != Py_NE)
        or not object_is_type(a, wrapper_type)
        or not object_is_type(b, wrapper_type) {
        return object_new_ref(Py_NotImplemented);
    }
    eq = wrapper_descr(a) == wrapper_descr(b) and wrapper_self(a) == wrapper_self(b);
    return PyBool_FromLong(1 if eq == (op == Py_EQ) else 0);
}

impl wrapper_hash(self: ptr[PyObject]) -> i64 {
    x = PyObject_GenericHash(wrapper_self(self))
        ^ Py_HashPointer(ptr(wrapper_descr(self)));
    return -2 if x == -1 else x;
}

impl wrapper_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<method-wrapper '%s' of %s object at %p>",
        wrapper_base(wrapper_descr(self)).view(1)[0].name,
        type_name(object_type(wrapper_self(self))),
        ptr(wrapper_self(self))
    );
}

impl wrapper_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    getattr = eval_builtin("getattr");
    if not getattr {
        return NULL;
    }
    return Py_BuildValue(
        ptr[u8]("N(OO)"),
        getattr,
        wrapper_self(self),
        descr_name_object(wrapper_descr(self))
    );
}

impl wrapper_objclass(wp: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return object_new_ref(ptr[PyObject](descr_type(wrapper_descr(wp))));
}

impl wrapper_name(wp: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyUnicode_FromString(wrapper_base(wrapper_descr(wp)).view(1)[0].name);
}

impl wrapper_doc(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    base = wrapper_base(wrapper_descr(self));
    return _PyType_GetDocFromInternalDoc(base.view(1)[0].name, base.view(1)[0].doc);
}

impl wrapper_text_signature(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    base = wrapper_base(wrapper_descr(self));
    return _PyType_GetTextSignatureFromInternalDoc(
        base.view(1)[0].name, base.view(1)[0].doc, i32(0)
    );
}

impl wrapper_qualname(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return descr_get_qualname(wrapper_descr(self), ptr());
}

impl wrapper_call(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return wrapperdescr_raw_call(wrapper_descr(self), wrapper_self(self), args, kwds);
}

impl wrapper_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(wrapper_descr(self), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(wrapper_self(self), visitor, arg);
}

impl prop_of(op: ptr[PyObject]) -> ptr[propertyobject] {
    return ptr[propertyobject](op);
}

impl prop_get(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](prop_of(op).view(1)[0].prop_get);
}

impl prop_set(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](prop_of(op).view(1)[0].prop_set);
}

impl prop_del(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](prop_of(op).view(1)[0].prop_del);
}

impl prop_doc(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](prop_of(op).view(1)[0].prop_doc);
}

impl prop_name(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](prop_of(op).view(1)[0].prop_name);
}

impl prop_store(op: ptr[PyObject], field: int, value: ptr[PyObject]) {
    p = prop_of(op);
    old: ptr[PyObject] = NULL;
    if field == 0 {
        old = prop_get(op);
        p.view(1)[0].prop_get = ptr[PyObject](value);
    } elif field == 1 {
        old = prop_set(op);
        p.view(1)[0].prop_set = ptr[PyObject](value);
    } elif field == 2 {
        old = prop_del(op);
        p.view(1)[0].prop_del = ptr[PyObject](value);
    } elif field == 3 {
        old = prop_doc(op);
        p.view(1)[0].prop_doc = ptr[PyObject](value);
    } else {
        old = prop_name(op);
        p.view(1)[0].prop_name = ptr[PyObject](value);
    }
    object_xdecref(old);
}

impl property_getter(self: ptr[PyObject], getter_fn: ptr[PyObject]) -> ptr[PyObject] {
    return property_copy(self, getter_fn, NULL, NULL);
}

impl property_setter(self: ptr[PyObject], setter_fn: ptr[PyObject]) -> ptr[PyObject] {
    return property_copy(self, NULL, setter_fn, NULL);
}

impl property_deleter(self: ptr[PyObject], deleter_fn: ptr[PyObject]) -> ptr[PyObject] {
    return property_copy(self, NULL, NULL, deleter_fn);
}

impl property_set_name(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if object_size(args) != 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("__set_name__() takes 2 positional arguments but %zd were given"),
            object_size(args)
        );
        return NULL;
    }
    prop_store(self, 4, object_xnew_ref(tuple_get_item(args, 1)));
    return object_new_ref(Py_None);
}

impl property_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    object_xdecref(prop_get(self));
    object_xdecref(prop_set(self));
    object_xdecref(prop_del(self));
    object_xdecref(prop_doc(self));
    object_xdecref(prop_name(self));
    calls = ptr[DescrCall](
        __thread_local_block("jac_object_model_descr_call_slot", 80)
    );
    calls.view(1)[0].free = int(object_type(self).view(1)[0].tp_free);
    calls.view(1)[0].free(ptr(self));
}

impl property_name(op: ptr[PyObject]) -> tuple[i32, ptr[PyObject]] {
    if prop_name(op) {
        return (i32(1), object_new_ref(prop_name(op)));
    }
    if not prop_get(op) {
        return (i32(0), NULL);
    }
    name: ptr[PyObject] = NULL;
    rc = PyObject_GetOptionalAttr(prop_get(op), interned(1, "__name__"), &mut name);
    return (rc, name);
}

impl missing_accessor(op: ptr[PyObject], ob: ptr[PyObject], what: str) {
    (rc, propname) = property_name(op);
    if rc < 0 {
        return;
    }
    qualname: ptr[PyObject] = NULL;
    if ob {
        qualname = PyType_GetQualName(object_type(ob));
    }
    if propname and qualname {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8]("property %R of %R object has no %s"),
            propname,
            qualname,
            what
        );
    } elif qualname {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8]("property of %R object has no %s"),
            qualname,
            what
        );
    } else {
        PyErr_Format(PyExc_AttributeError, ptr[u8]("property has no %s"), what);
    }
    object_xdecref(propname);
    object_xdecref(qualname);
}

impl property_descr_get(
    self: ptr[PyObject], ob: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if not ob or ob == Py_None {
        return object_new_ref(self);
    }
    if not prop_get(self) {
        missing_accessor(self, ob, "getter");
        return NULL;
    }
    return PyObject_CallOneArg(prop_get(self), ob);
}

impl property_descr_set(
    self: ptr[PyObject], ob: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    func = prop_del(self) if not value else prop_set(self);
    if not func {
        missing_accessor(self, ob, "deleter" if not value else "setter");
        return i32(-1);
    }
    res: ptr[PyObject] = NULL;
    if not value {
        res = PyObject_CallOneArg(func, ob);
    } else {
        res = PyObject_CallFunctionObjArgs(func, ob, value, ptr());
    }
    if not res {
        return i32(-1);
    }
    object_decref(res);
    return i32(0);
}

impl property_copy(
    old: ptr[PyObject],
    get_in: ptr[PyObject],
    set_in: ptr[PyObject],
    del_in: ptr[PyObject]
) -> ptr[PyObject] {
    type = PyObject_Type(old);
    if not type {
        return NULL;
    }
    get = get_in;
    set = set_in;
    del_ = del_in;
    if not get or get == Py_None {
        get = prop_get(old) if prop_get(old) else Py_None;
    }
    if not set or set == Py_None {
        set = prop_set(old) if prop_set(old) else Py_None;
    }
    if not del_ or del_ == Py_None {
        del_ = prop_del(old) if prop_del(old) else Py_None;
    }
    doc = Py_None;

    if prop_of(old).view(1)[0].getter_doc == 0 or get == Py_None {
        doc = prop_doc(old) if prop_doc(old) else Py_None;
    }
    result = PyObject_CallFunctionObjArgs(type, get, set, del_, doc, ptr());
    object_decref(type);
    if not result {
        return NULL;
    }
    if object_type_check(result, addressof(PyProperty_Type)) {
        prop_store(result, 4, object_xnew_ref(prop_name(old)));
    }
    return result;
}

impl property_init_impl(
    self: ptr[PyObject],
    fget_in: ptr[PyObject],
    fset_in: ptr[PyObject],
    fdel_in: ptr[PyObject],
    doc: ptr[PyObject]
) -> i32 {
    fget = NULL if fget_in == Py_None else fget_in;
    fset = NULL if fset_in == Py_None else fset_in;
    fdel = NULL if fdel_in == Py_None else fdel_in;
    prop_store(self, 0, object_xnew_ref(fget));
    prop_store(self, 1, object_xnew_ref(fset));
    prop_store(self, 2, object_xnew_ref(fdel));
    prop_store(self, 3, NULL);
    prop_store(self, 4, NULL);
    prop_of(self).view(1)[0].getter_doc = i32(0);
    doc_value: ptr[PyObject] = NULL;
    if doc and doc != Py_None {
        doc_value = object_xnew_ref(doc);
    } elif fget {
        rc = PyObject_GetOptionalAttr(fget, interned(2, "__doc__"), &mut doc_value);
        if rc < 0 {
            return rc;
        }
        if doc_value == Py_None {
            doc_value = NULL;
            object_decref(Py_None);
        }
        if doc_value {
            prop_of(self).view(1)[0].getter_doc = i32(1);
        }
    }

    if object_is_type(self, addressof(PyProperty_Type)) {
        prop_store(self, 3, doc_value);
        return i32(0);
    }

    if not doc_value {
        doc_value = object_new_ref(Py_None);
    }
    err = PyObject_SetAttr(self, interned(2, "__doc__"), doc_value);
    object_decref(doc_value);
    if err < 0 {
        if prop_of(self).view(1)[0].getter_doc == 0
            and PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
            PyErr_Clear();
            return i32(0);
        }
        return i32(-1);
    }
    return i32(0);
}

impl property_init_values(
    self: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    if property_init_impl(
        self,
        values.view(1)[0],
        (values + 1).view(1)[0],
        (values + 2).view(1)[0],
        (values + 3).view(1)[0]
    )
        != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl property_init(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    if not kwargs and object_size(args) <= 4 {
        items = tuple_items(args);
        n = object_size(args);
        return property_init_impl(
            self,
            items.view(1)[0] if n > 0 else NULL,
            (items + 1).view(1)[0] if n > 1 else NULL,
            (items + 2).view(1)[0] if n > 2 else NULL,
            (items + 3).view(1)[0] if n > 3 else NULL
        );
    }
    res = invoke_tuple(property_signature, args, kwargs, property_init_values, self);
    if not res {
        return i32(-1);
    }
    object_decref(res);
    return i32(0);
}

impl property_get__name__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    (rc, name) = property_name(op);
    if rc < 0 {
        return NULL;
    }
    if not name {
        PyErr_SetString(
            PyExc_AttributeError,
            ptr[u8]("'property' object has no attribute '__name__'")
        );
    }
    return name;
}

impl property_set__name__(
    op: ptr[PyObject], value: ptr[PyObject], _closure: ptr
) -> i32 {
    prop_store(op, 4, object_xnew_ref(value));
    return i32(0);
}

impl property_get___isabstractmethod__(
    op: ptr[PyObject], _closure: ptr
) -> ptr[PyObject] {
    for accessor in [prop_get(op), prop_set(op), prop_del(op)] {
        res = _PyObject_IsAbstract(accessor);
        if res == -1 {
            return NULL;
        }
        if res != 0 {
            return PyBool_FromLong(1);
        }
    }
    return PyBool_FromLong(0);
}

impl property_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    for field in [
        prop_get(self),
        prop_set(self),
        prop_del(self),
        prop_doc(self),
        prop_name(self)
    ] {
        status = visit_reference(field, visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl property_clear(self: ptr[PyObject]) -> i32 {
    prop_store(self, 3, NULL);
    return i32(0);
}
