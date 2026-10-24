import from c {
    glob PyType_Type: PyTypeObject,
         _PyNone_Type: PyTypeObject; def PyType_FromSpec(
        spec: ptr[PyType_Spec]
    ) -> ptr[PyObject];  def _Py_SetImmortal(op: ptr[PyObject]);  def _PyUnicode_EqualToASCIIString(
        a: ptr[PyObject], b: ptr[u8]
    ) -> i32;  def _Py_union_from_tuple(args: ptr[PyObject]) -> ptr[PyObject];  def _Py_union_type_or(
        a: ptr[PyObject], b: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_ClearManagedDict(ob: ptr[PyObject]);  def PyObject_VisitManagedDict(
        ob: ptr[PyObject], visitor: ptr, arg: ptr
    ) -> i32;  def PyUnicodeWriter_WriteASCII(
        writer: ptr, s: ptr[u8], size: i64
    ) -> i32;  def PyUnicodeWriter_WriteStr(writer: ptr, ob: ptr[PyObject]) -> i32;  def PyFunction_GetModule(
        op: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyArg_BadArgument(
        fname: str, displayname: str, expected: ptr[u8], arg: ptr[PyObject]
    );  obj TypevarCall {
        has free: Callable[[ptr], None] = 0;
    }  glob:priv call_slot: TypevarCall = TypevarCall(),
         origin_key: ptr[PyObject] = ptr[PyObject](),
         args_key: ptr[PyObject] = ptr[PyObject](),
         qualname_key: ptr[PyObject] = ptr[PyObject](),
         module_key: ptr[PyObject] = ptr[PyObject](),
         nodefault_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(NoDefault_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         constevaluator_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "_ConstEvaluator()\n--\n\nInternal type for implementing evaluation functions."
                 )
             ),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(constevaluator_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(constevaluator_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(constevaluator_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(constevaluator_repr)),
             PyType_Slot(slot=Py_tp_call, pfunc=ptr(constevaluator_call)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         typevar_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__name__"),
                 type_=_Py_T_OBJECT,
                 offset=typevarobject_NAME,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__covariant__"),
                 type_=Py_T_BOOL,
                 offset=typevarobject_COVARIANT,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__contravariant__"),
                 type_=Py_T_BOOL,
                 offset=typevarobject_CONTRAVARIANT,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__infer_variance__"),
                 type_=Py_T_BOOL,
                 offset=typevarobject_INFER_VARIANCE,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         typevar_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__bound__"), get=typevar_bound),
             PyGetSetDef(name=ptr[u8]("__constraints__"), get=typevar_constraints),
             PyGetSetDef(name=ptr[u8]("__default__"), get=typevar_default),
             PyGetSetDef(name=ptr[u8]("evaluate_bound"), get=typevar_evaluate_bound),
             PyGetSetDef(
                 name=ptr[u8]("evaluate_constraints"), get=typevar_evaluate_constraints
             ),
             PyGetSetDef(
                 name=ptr[u8]("evaluate_default"), get=typevar_evaluate_default
             ),
             PyGetSetDef()
         ],
         typevar_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__typing_subst__"),
                 ml_meth=ptr(typevar_typing_subst),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("__typing_subst__($self, arg, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__typing_prepare_subst__"),
                 ml_meth=ptr(typevar_typing_prepare_subst),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "__typing_prepare_subst__($self, alias, args, /)\n--\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(typevar_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("has_default"),
                 ml_meth=ptr(typevar_has_default),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("has_default($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(typevar_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         typevar_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Type variable.\n\n"
                     "The preferred way to construct a type variable is via the dedicated\n"
                     "syntax for generic functions, classes, and type aliases::\n\n"
                     "    class Sequence[T]:  # T is a TypeVar\n"
                     "        ...\n\n"
                     "This syntax can also be used to create bound and constrained type\n"
                     "variables::\n\n"
                     "    # S is a TypeVar bound to str\n"
                     "    class StrSequence[S: str]:\n"
                     "        ...\n\n"
                     "    # A is a TypeVar constrained to str or bytes\n"
                     "    class StrOrBytesSequence[A: (str, bytes)]:\n"
                     "        ...\n\n"
                     "Type variables can also have defaults:\n\n"
                     "    class IntDefault[T = int]:\n"
                     "        ...\n\n"
                     "However, if desired, reusable type variables can also be constructed\n"
                     "manually, like so::\n\n"
                     "   T = TypeVar('T')  # Can be anything\n"
                     "   S = TypeVar('S', bound=str)  # Can be any subtype of str\n"
                     "   A = TypeVar('A', str, bytes)  # Must be exactly str or bytes\n"
                     "   D = TypeVar('D', default=int)  # Defaults to int\n\n"
                     "Type variables exist primarily for the benefit of static type\n"
                     "checkers.  They serve as the parameters for generic types as well\n"
                     "as for generic function and type alias definitions.\n\n"
                     "The variance of type variables is inferred by type checkers when they\n"
                     "are created through the type parameter syntax and when\n"
                     "``infer_variance=True`` is passed. Manually created type variables may\n"
                     "be explicitly marked covariant or contravariant by passing\n"
                     "``covariant=True`` or ``contravariant=True``. By default, manually\n"
                     "created type variables are invariant. See PEP 484 and PEP 695 for more\n"
                     "details.\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(typevar_methods))),
             PyType_Slot(slot=Py_nb_or, pfunc=ptr(make_union)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(typevar_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(typevar_dealloc)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(typevar_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(typevar_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(typevar_repr)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(typevar_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(typevar_getset))),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         paramspecattr_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__origin__"),
                 type_=_Py_T_OBJECT,
                 offset=paramspecattrobject_ORIGIN,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         paramspecargs_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(paramspecargs_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         paramspecargs_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "The args for a ParamSpec object.\n\n"
                     "Given a ParamSpec object P, P.args is an instance of ParamSpecArgs.\n\n"
                     "ParamSpecArgs objects have a reference back to their ParamSpec::\n\n"
                     "    >>> P = ParamSpec(\"P\")\n"
                     "    >>> P.args.__origin__ is P\n"
                     "    True\n\n"
                     "This type is meant for runtime introspection and has no special meaning\n"
                     "to static type checkers.\n"
                 )
             ),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(paramspecargs_methods))
             ),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(paramspecargs_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(paramspecattr_dealloc)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(paramspecattr_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(paramspecattr_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(paramspecargs_repr)),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(paramspecattr_members))
             ),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(paramspecattr_richcompare)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         paramspeckwargs_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(paramspeckwargs_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         paramspeckwargs_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "The kwargs for a ParamSpec object.\n\n"
                     "Given a ParamSpec object P, P.kwargs is an instance of ParamSpecKwargs.\n\n"
                     "ParamSpecKwargs objects have a reference back to their ParamSpec::\n\n"
                     "    >>> P = ParamSpec(\"P\")\n"
                     "    >>> P.kwargs.__origin__ is P\n"
                     "    True\n\n"
                     "This type is meant for runtime introspection and has no special meaning\n"
                     "to static type checkers.\n"
                 )
             ),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(paramspeckwargs_methods))
             ),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(paramspeckwargs_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(paramspecattr_dealloc)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(paramspecattr_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(paramspecattr_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(paramspeckwargs_repr)),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(paramspecattr_members))
             ),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(paramspecattr_richcompare)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         paramspec_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__name__"),
                 type_=_Py_T_OBJECT,
                 offset=paramspecobject_NAME,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__bound__"),
                 type_=_Py_T_OBJECT,
                 offset=paramspecobject_BOUND,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__covariant__"),
                 type_=Py_T_BOOL,
                 offset=paramspecobject_COVARIANT,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__contravariant__"),
                 type_=Py_T_BOOL,
                 offset=paramspecobject_CONTRAVARIANT,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef(
                 name=ptr[u8]("__infer_variance__"),
                 type_=Py_T_BOOL,
                 offset=paramspecobject_INFER_VARIANCE,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         paramspec_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("args"),
                 get=paramspec_args,
                 doc=ptr[u8]("Represents positional arguments.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("kwargs"),
                 get=paramspec_kwargs,
                 doc=ptr[u8]("Represents keyword arguments.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__default__"),
                 get=paramspec_default,
                 doc=ptr[u8]("The default value for this ParamSpec.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("evaluate_default"), get=paramspec_evaluate_default
             ),
             PyGetSetDef()
         ],
         paramspec_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__typing_subst__"),
                 ml_meth=ptr(paramspec_typing_subst),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("__typing_subst__($self, arg, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__typing_prepare_subst__"),
                 ml_meth=ptr(paramspec_typing_prepare_subst),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "__typing_prepare_subst__($self, alias, args, /)\n--\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("has_default"),
                 ml_meth=ptr(paramspec_has_default),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("has_default($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(paramspec_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(paramspec_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         paramspec_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Parameter specification variable.\n\n"
                     "The preferred way to construct a parameter specification is via the\n"
                     "dedicated syntax for generic functions, classes, and type aliases,\n"
                     "where the use of '**' creates a parameter specification::\n\n"
                     "    type IntFunc[**P] = Callable[P, int]\n\n"
                     "The following syntax creates a parameter specification that defaults\n"
                     "to a callable accepting two positional-only arguments of types int\n"
                     "and str:\n\n"
                     "    type IntFuncDefault[**P = [int, str]] = Callable[P, int]\n\n"
                     "For compatibility with Python 3.11 and earlier, ParamSpec objects\n"
                     "can also be created as follows::\n\n"
                     "    P = ParamSpec('P')\n"
                     "    DefaultP = ParamSpec('DefaultP', default=[int, str])\n\n"
                     "Parameter specification variables exist primarily for the benefit of\n"
                     "static type checkers.  They are used to forward the parameter types of\n"
                     "one callable to another callable, a pattern commonly found in\n"
                     "higher-order functions and decorators.  They are only valid when used\n"
                     "in ``Concatenate``, or as the first argument to ``Callable``, or as\n"
                     "parameters for user-defined Generics. See class Generic for more\n"
                     "information on generic types.\n\n"
                     "An example for annotating a decorator::\n\n"
                     "    def add_logging[**P, T](f: Callable[P, T]) -> Callable[P, T]:\n"
                     "        '''A type-safe decorator to add logging to a function.'''\n"
                     "        def inner(*args: P.args, **kwargs: P.kwargs) -> T:\n"
                     "            logging.info(f'{f.__name__} was called')\n"
                     "            return f(*args, **kwargs)\n"
                     "        return inner\n\n"
                     "    @add_logging\n"
                     "    def add_two(x: float, y: float) -> float:\n"
                     "        '''Add two numbers together.'''\n"
                     "        return x + y\n\n"
                     "Parameter specification variables can be introspected. e.g.::\n\n"
                     "    >>> P = ParamSpec(\"P\")\n"
                     "    >>> P.__name__\n"
                     "    'P'\n\n"
                     "Note that only parameter specification variables defined in the global\n"
                     "scope can be pickled.\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(paramspec_members))),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(paramspec_methods))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(paramspec_getset))),
             PyType_Slot(slot=Py_nb_or, pfunc=ptr(make_union)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(paramspec_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(paramspec_dealloc)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(paramspec_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(paramspec_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(paramspec_repr)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         typevartuple_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__name__"),
                 type_=_Py_T_OBJECT,
                 offset=typevartupleobject_NAME,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         typevartuple_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__default__"),
                 get=typevartuple_default,
                 doc=ptr[u8]("The default value for this TypeVarTuple.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("evaluate_default"), get=typevartuple_evaluate_default
             ),
             PyGetSetDef()
         ],
         typevartuple_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__typing_subst__"),
                 ml_meth=ptr(typevartuple_typing_subst),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("__typing_subst__($self, arg, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__typing_prepare_subst__"),
                 ml_meth=ptr(typevartuple_typing_prepare_subst),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "__typing_prepare_subst__($self, alias, args, /)\n--\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(typevartuple_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("has_default"),
                 ml_meth=ptr(typevartuple_has_default),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("has_default($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(typevartuple_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         typevartuple_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Type variable tuple. A specialized form of type variable that enables\n"
                     "variadic generics.\n\n"
                     "The preferred way to construct a type variable tuple is via the\n"
                     "dedicated syntax for generic functions, classes, and type aliases,\n"
                     "where a single '*' indicates a type variable tuple::\n\n"
                     "    def move_first_element_to_last[T, *Ts](tup: tuple[T, *Ts]) -> tuple[*Ts, T]:\n"
                     "        return (*tup[1:], tup[0])\n\n"
                     "Type variables tuples can have default values:\n\n"
                     "    type AliasWithDefault[*Ts = (str, int)] = tuple[*Ts]\n\n"
                     "For compatibility with Python 3.11 and earlier, TypeVarTuple objects\n"
                     "can also be created as follows::\n\n"
                     "    Ts = TypeVarTuple('Ts')  # Can be given any name\n"
                     "    DefaultTs = TypeVarTuple('Ts', default=(str, int))\n\n"
                     "Just as a TypeVar (type variable) is a placeholder for a single type,\n"
                     "a TypeVarTuple is a placeholder for an *arbitrary* number of types. For\n"
                     "example, if we define a generic class using a TypeVarTuple::\n\n"
                     "    class C[*Ts]: ...\n\n"
                     "Then we can parameterize that class with an arbitrary number of type\n"
                     "arguments::\n\n"
                     "    C[int]       # Fine\n"
                     "    C[int, str]  # Also fine\n"
                     "    C[()]        # Even this is fine\n\n"
                     "For more details, see PEP 646.\n\n"
                     "Note that only TypeVarTuples defined in the global scope can be\n"
                     "pickled.\n"
                 )
             ),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(typevartuple_members))
             ),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(typevartuple_methods))
             ),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(typevartuple_getset))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(typevartuple_new)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(unpack_iter)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(typevartuple_repr)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(typevartuple_dealloc)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(typevartuple_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(typevartuple_clear)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         typealias_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__name__"),
                 type_=_Py_T_OBJECT,
                 offset=typealiasobject_NAME,
                 flags=Py_READONLY,
                 doc=ptr[u8]()
             ),
             PyMemberDef()
         ],
         typealias_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__parameters__"), get=typealias_parameters),
             PyGetSetDef(name=ptr[u8]("__type_params__"), get=typealias_type_params),
             PyGetSetDef(name=ptr[u8]("__value__"), get=typealias_value),
             PyGetSetDef(name=ptr[u8]("evaluate_value"), get=typealias_evaluate_value),
             PyGetSetDef(name=ptr[u8]("__module__"), get=typealias_module),
             PyGetSetDef()
         ],
         typealias_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(typealias_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\n")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         typealias_as_number: PyNumberMethods = PyNumberMethods(
             nb_or=_Py_union_type_or
         ),
         typealias_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_subscript=typealias_subscript
         ),
         generic_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(generic_class_getitem),
                 ml_flags=METH_VARARGS | METH_KEYWORDS | METH_CLASS,
                 ml_doc=ptr[u8](
                     "Parameterizes a generic class.\n\n"
                     "At least, parameterizing a generic class is the *main* thing this\n"
                     "method does. For example, for some generic class `Foo`, this is called\n"
                     "when we do `Foo[int]` - there, with `cls=Foo` and `params=int`.\n\n"
                     "However, note that this method is also called when defining generic\n"
                     "classes in the first place with `class Foo[T]: ...`.\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__init_subclass__"),
                 ml_meth=ptr(generic_init_subclass),
                 ml_flags=METH_VARARGS | METH_KEYWORDS | METH_CLASS,
                 ml_doc=ptr[u8]("Function to initialize subclasses.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         generic_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Abstract base class for generic types.\n\n"
                     "On Python 3.12 and newer, generic classes implicitly inherit from\n"
                     "Generic when they declare a parameter list after the class's name::\n\n"
                     "    class Mapping[KT, VT]:\n"
                     "        def __getitem__(self, key: KT) -> VT:\n"
                     "            ...\n"
                     "        # Etc.\n\n"
                     "On older versions of Python, however, generic classes have to\n"
                     "explicitly inherit from Generic.\n\n"
                     "After a class has been declared to be generic, it can then be used as\n"
                     "follows::\n\n"
                     "    def lookup_name[KT, VT](mapping: Mapping[KT, VT], key: KT, default: VT) -> VT:\n"
                     "        try:\n"
                     "            return mapping[key]\n"
                     "        except KeyError:\n"
                     "            return default\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(generic_methods))),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(generic_dealloc)),
             PyType_Slot(slot=Py_tp_alloc, pfunc=ptr(PyType_GenericAlloc)),
             PyType_Slot(slot=Py_tp_free, pfunc=ptr(PyObject_GC_Del)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(generic_traverse)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob _PyNoDefault_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("NoDefaultType"),
             tp_dealloc=nodefault_dealloc,
             tp_repr=NoDefault_repr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8](
                 "NoDefaultType()\n--\n\nThe type of the NoDefault singleton."
             ),
             tp_methods=addressof(nodefault_methods),
             tp_new=nodefault_new
         ),
         _Py_NoDefaultStruct: _object = _object(
             ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
             ob_type=addressof(_PyNoDefault_Type)
         ),
         constevaluator_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_typing._ConstEvaluator"),
             basicsize=i32(constevaluatorobject_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(constevaluator_slots)
         ),
         typevar_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("typing.TypeVar"),
             basicsize=i32(typevarobject_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_DICT
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(typevar_slots)
         ),
         paramspecargs_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("typing.ParamSpecArgs"),
             basicsize=i32(paramspecattrobject_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(paramspecargs_slots)
         ),
         paramspeckwargs_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("typing.ParamSpecKwargs"),
             basicsize=i32(paramspecattrobject_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(paramspeckwargs_slots)
         ),
         paramspec_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("typing.ParamSpec"),
             basicsize=i32(paramspecobject_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_DICT
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(paramspec_slots)
         ),
         typevartuple_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("typing.TypeVarTuple"),
             basicsize=i32(typevartupleobject_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_DICT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(typevartuple_slots)
         ),
         generic_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("typing.Generic"),
             basicsize=i32(PyObject_HEAD_SIZE),
             itemsize=0,
             flags=u32(Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC),
             slots=addressof(generic_slots)
         ),
         _PyTypeAlias_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("typing.TypeAliasType"),
             tp_basicsize=typealiasobject_SIZE,
             tp_dealloc=typealias_dealloc,
             tp_repr=typealias_repr,
             tp_as_number=addressof(typealias_as_number),
             tp_as_mapping=addressof(typealias_as_mapping),
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_IMMUTABLETYPE
                 | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Type alias.\n\n"
                 "Type aliases are created through the type statement::\n\n"
                 "    type Alias = int\n\n"
                 "In this example, Alias and int will be treated equivalently by static\n"
                 "type checkers.\n\n"
                 "At runtime, Alias is an instance of TypeAliasType. The __name__\n"
                 "attribute holds the name of the type alias. The value of the type alias\n"
                 "is stored in the __value__ attribute. It is evaluated lazily, so the\n"
                 "value is computed only if the attribute is accessed.\n\n"
                 "Type aliases can also be generic::\n\n"
                 "    type ListOrSet[T] = list[T] | set[T]\n\n"
                 "In this case, the type parameters of the alias are stored in the\n"
                 "__type_params__ attribute.\n\n"
                 "See PEP 695 for more information.\n"
             ),
             tp_traverse=typealias_traverse,
             tp_clear=typealias_clear,
             tp_iter=unpack_iter,
             tp_methods=addressof(typealias_methods),
             tp_members=addressof(typealias_members),
             tp_getset=addressof(typealias_getset),
             tp_alloc=PyType_GenericAlloc,
             tp_new=typealias_new,
             tp_free=PyObject_GC_Del
         );
}

glob:priv typevar_signature = CallSignature(
         "typevar",
         ["name", "bound", "default", "covariant", "contravariant", "infer_variance"],
         1,
         1,
         0,
         parser=PARSE_KEYWORDS
     ),
     paramspec_signature = CallSignature(
         "paramspec",
         ["name", "bound", "default", "covariant", "contravariant", "infer_variance"],
         1,
         1,
         0,
         parser=PARSE_KEYWORDS
     ),
     typevartuple_signature = CallSignature(
         "typevartuple", ["name", "default"], 1, 1, 0, parser=PARSE_KEYWORDS
     ),
     typealias_signature = CallSignature(
         "typealias", ["name", "value", "type_params"], 2, 2, 0, parser=PARSE_KEYWORDS
     ),
     paramspecargs_signature = CallSignature(
         "paramspecargs", ["origin"], 1, 1, 0, parser=PARSE_KEYWORDS
     ),
     paramspeckwargs_signature = CallSignature(
         "paramspeckwargs", ["origin"], 1, 1, 0, parser=PARSE_KEYWORDS
     );

def field(op: ptr[PyObject], offset: i64) -> ptr[PyObject];

def set_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def replace_field(op: ptr[PyObject], offset: i64, value: ptr[PyObject]);

def flag(op: ptr[PyObject], offset: i64) -> bool;

def set_flag(op: ptr[PyObject], offset: i64, value: bool);

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def no_default -> ptr[PyObject];

def cached_type(offset: i64) -> ptr[PyTypeObject];

def set_cached_type(offset: i64, type: ptr[PyObject]);

def heap_free(op: ptr[PyObject]);

def interned(which: int) -> ptr[PyObject];

def bool_argument(value: ptr[PyObject], fallback: bool) -> i32;

def NoDefault_repr(op: ptr[PyObject]) -> ptr[PyObject];

def NoDefault_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def nodefault_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def nodefault_dealloc(nodefault: ptr[PyObject]);

def constevaluator_dealloc(self: ptr[PyObject]);

def constevaluator_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def constevaluator_clear(self: ptr[PyObject]) -> i32;

def constevaluator_repr(self: ptr[PyObject]) -> ptr[PyObject];

def constevaluator_call(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def constevaluator_alloc(value: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _Py_typing_type_repr(writer: ptr[PyUnicodeWriter], p: ptr[PyObject]) -> i32 {
        if p == Py_Ellipsis {
            r = PyUnicode_FromString(ptr[u8]("..."));
            if not r {
                return i32(-1);
            }
            rc = PyUnicodeWriter_WriteStr(ptr(writer), r);
            object_decref(r);
            return rc;
        }
        if p == ptr[PyObject](addressof(_PyNone_Type)) {
            return PyUnicodeWriter_WriteASCII(ptr(writer), ptr[u8]("None"), 4);
        }
        qualname: ptr[PyObject] = NULL;
        module: ptr[PyObject] = NULL;
        r: ptr[PyObject] = NULL;
        failed = False;
        use_repr = False;
        rc = PyObject_HasAttrWithError(p, interned(0));
        if rc > 0 {
            rc = PyObject_HasAttrWithError(p, interned(1));
        }
        if rc > 0 {
            use_repr = True;
        } elif rc < 0 {
            failed = True;
        } elif PyObject_GetOptionalAttr(p, interned(2), &mut qualname) < 0 {
            failed = True;
        } elif not qualname {
            use_repr = True;
        } elif PyObject_GetOptionalAttr(p, interned(3), &mut module) < 0 {
            failed = True;
        } elif not module or module == Py_None {
            use_repr = True;
        } elif type_has_feature(object_type(module), Py_TPFLAGS_UNICODE_SUBCLASS)
            and _PyUnicode_EqualToASCIIString(module, ptr[u8]("builtins")) != 0 {
            r = PyObject_Str(qualname);
        } else {
            r = PyUnicode_FromFormat("%S.%S", module, qualname);
        }
        if use_repr {
            r = PyObject_Repr(p);
        }
        object_xdecref(qualname);
        object_xdecref(module);
        if failed or not r {
            return i32(-1);
        }
        rc = PyUnicodeWriter_WriteStr(ptr(writer), r);
        object_decref(r);
        return rc;
    }
}

def call_typing_func_object(name: str, args: list[ptr[PyObject]]) -> ptr[PyObject];

def type_check(arg: ptr[PyObject], msg: str) -> ptr[PyObject];

def make_union(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def caller -> ptr[PyObject];

def unpack(self: ptr[PyObject]) -> ptr[PyObject];

def contains_typevartuple(params: ptr[PyObject]) -> bool;

def unpack_typevartuples(params: ptr[PyObject]) -> ptr[PyObject];

def lazy_attribute(
    op: ptr[PyObject], value_offset: i64, evaluate_offset: i64, fallback: ptr[PyObject]
) -> ptr[PyObject];

def evaluator_attribute(
    op: ptr[PyObject], value_offset: i64, evaluate_offset: i64
) -> ptr[PyObject];

def has_default(
    op: ptr[PyObject], default_offset: i64, evaluate_offset: i64
) -> ptr[PyObject];

def variance_repr(
    op: ptr[PyObject], name_offset: i64, covariant: i64, contravariant: i64, infer: i64
) -> ptr[PyObject];

def mro_entries_error(name: str) -> ptr[PyObject];

def with_module(op: ptr[PyObject], module: ptr[PyObject]) -> ptr[PyObject];

glob:priv TYPEVAR_FIELDS: i64 = 7;

def typevar_offsets -> list[i64];

def typevar_dealloc(self: ptr[PyObject]);

def typevar_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def typevar_clear(op: ptr[PyObject]) -> i32;

def typevar_repr(self: ptr[PyObject]) -> ptr[PyObject];

def typevar_bound(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevar_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevar_constraints(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevar_evaluate_bound(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevar_evaluate_constraints(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevar_evaluate_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevar_alloc(
    name: ptr[PyObject],
    bound: ptr[PyObject],
    evaluate_bound: ptr[PyObject],
    constraints: ptr[PyObject],
    evaluate_constraints: ptr[PyObject],
    default_value: ptr[PyObject],
    covariant: bool,
    contravariant: bool,
    infer_variance: bool,
    module: ptr[PyObject]
) -> ptr[PyObject];

def check_variance(covariant: i32, contravariant: i32, infer_variance: i32) -> bool;

def variance_flags(values: ptr[ptr[PyObject]]) -> tuple[i32, i32, i32, i32];

def check_name(name: ptr[PyObject], fname: str) -> bool;

def typevar_new_values(
    constraints: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def typevar_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def typevar_typing_subst(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def typevar_typing_prepare_subst(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def typevar_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def typevar_has_default(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def typevar_mro_entries(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def paramspecattr_dealloc(self: ptr[PyObject]);

def paramspecattr_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def paramspecattr_clear(op: ptr[PyObject]) -> i32;

def paramspecattr_richcompare(
    a: ptr[PyObject], b: ptr[PyObject], op: i32
) -> ptr[PyObject];

def paramspecattr_new(tp: ptr[PyTypeObject], origin: ptr[PyObject]) -> ptr[PyObject];

def paramspecattr_repr(self: ptr[PyObject], suffix: str) -> ptr[PyObject];

def paramspecargs_repr(self: ptr[PyObject]) -> ptr[PyObject];

def paramspeckwargs_repr(self: ptr[PyObject]) -> ptr[PyObject];

def paramspecattr_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def paramspecargs_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def paramspeckwargs_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def paramspecargs_mro_entries(
    self: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def paramspeckwargs_mro_entries(
    self: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def paramspec_offsets -> list[i64];

def paramspec_dealloc(self: ptr[PyObject]);

def paramspec_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def paramspec_clear(op: ptr[PyObject]) -> i32;

def paramspec_repr(self: ptr[PyObject]) -> ptr[PyObject];

def paramspec_args(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def paramspec_kwargs(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def paramspec_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def paramspec_evaluate_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def paramspec_alloc(
    name: ptr[PyObject],
    bound: ptr[PyObject],
    default_value: ptr[PyObject],
    covariant: bool,
    contravariant: bool,
    infer_variance: bool,
    module: ptr[PyObject]
) -> ptr[PyObject];

def paramspec_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def paramspec_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def paramspec_typing_subst(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def paramspec_typing_prepare_subst(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def paramspec_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def paramspec_has_default(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def paramspec_mro_entries(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def typevartuple_offsets -> list[i64];

def typevartuple_dealloc(self: ptr[PyObject]);

def unpack_iter(self: ptr[PyObject]) -> ptr[PyObject];

def typevartuple_repr(self: ptr[PyObject]) -> ptr[PyObject];

def typevartuple_alloc(
    name: ptr[PyObject], module: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def typevartuple_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def typevartuple_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def typevartuple_typing_subst(
    self: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def typevartuple_typing_prepare_subst(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def typevartuple_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def typevartuple_has_default(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def typevartuple_mro_entries(
    self: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def typevartuple_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def typevartuple_clear(self: ptr[PyObject]) -> i32;

def typevartuple_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typevartuple_evaluate_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def get_type_param_default(typeparam: ptr[PyObject]) -> ptr[PyObject];

def typealias_offsets -> list[i64];

def typealias_dealloc(self: ptr[PyObject]);

def typealias_get_value(ta: ptr[PyObject]) -> ptr[PyObject];

def typealias_repr(self: ptr[PyObject]) -> ptr[PyObject];

def typealias_value(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typealias_evaluate_value(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typealias_parameters(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typealias_type_params(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typealias_module(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def typealias_check_type_params(
    type_params: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def typealias_convert_type_params(type_params: ptr[PyObject]) -> ptr[PyObject];

def typealias_alloc(
    name: ptr[PyObject],
    type_params: ptr[PyObject],
    compute_value: ptr[PyObject],
    value: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject];

def typealias_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def typealias_clear(op: ptr[PyObject]) -> i32;

def typealias_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def typealias_subscript(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def typealias_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def typealias_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def call_typing_args_kwargs(
    name: str, cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def generic_init_subclass(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def generic_class_getitem(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def generic_dealloc(self: ptr[PyObject]);

def generic_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

import from c {
    def _Py_make_typevar(
        name: ptr[PyObject],
        evaluate_bound: ptr[PyObject],
        evaluate_constraints: ptr[PyObject]
    ) -> ptr[PyObject] {
        return typevar_alloc(
            name,
            NULL,
            evaluate_bound,
            NULL,
            evaluate_constraints,
            NULL,
            False,
            False,
            True,
            NULL
        );
    }  def _Py_make_paramspec(_tstate: ptr, v: ptr[PyObject]) -> ptr[PyObject] {
        return paramspec_alloc(v, NULL, NULL, False, False, True, NULL);
    }  def _Py_make_typevartuple(_tstate: ptr, v: ptr[PyObject]) -> ptr[PyObject] {
        return typevartuple_alloc(v, NULL, NULL);
    }  def _Py_make_typealias(_tstate: ptr, args: ptr[PyObject]) -> ptr[PyObject] {
        name = tuple_get_item(args, 0);
        type_params = typealias_convert_type_params(tuple_get_item(args, 1));
        compute_value = tuple_get_item(args, 2);
        return typealias_alloc(name, type_params, compute_value, NULL, NULL);
    }  def _Py_subscript_generic(
        _tstate: ptr, params_in: ptr[PyObject]
    ) -> ptr[PyObject] {
        params = unpack_typevartuples(params_in);
        generic = cached_type(PyInterpreterState_CACHED_GENERIC_TYPE);
        if not generic {
            object_xdecref(params);
            PyErr_SetString(PyExc_SystemError, "Cannot find Generic type");
            return NULL;
        }
        result = call_typing_func_object(
            "_GenericAlias", [ptr[PyObject](generic), params]
        );
        object_xdecref(params);
        return result;
    }  def _Py_initialize_generic(interp: ptr) -> i32 {
        specs = [
            (addressof(generic_spec), PyInterpreterState_CACHED_GENERIC_TYPE),
            (addressof(typevar_spec), PyInterpreterState_CACHED_TYPEVAR_TYPE),
            (addressof(typevartuple_spec), PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE),
            (addressof(paramspec_spec), PyInterpreterState_CACHED_PARAMSPEC_TYPE),
            (
                addressof(paramspecargs_spec),
                PyInterpreterState_CACHED_PARAMSPECARGS_TYPE
            ),
            (
                addressof(paramspeckwargs_spec),
                PyInterpreterState_CACHED_PARAMSPECKWARGS_TYPE
            ),
            (
                addressof(constevaluator_spec),
                PyInterpreterState_CACHED_CONSTEVALUATOR_TYPE
            )
        ];
        for (spec, offset) in specs {
            type = PyType_FromSpec(spec);
            if not type {
                return i32(-1);
            }
            ptr[ptr[PyObject]](ptr[u8](interp) + offset).view(1)[0] = type;
        }
        return i32(0);
    }  def _Py_clear_generic_types(interp: ptr) {
        for offset in [
            PyInterpreterState_CACHED_GENERIC_TYPE,
            PyInterpreterState_CACHED_TYPEVAR_TYPE,
            PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE,
            PyInterpreterState_CACHED_PARAMSPEC_TYPE,
            PyInterpreterState_CACHED_PARAMSPECARGS_TYPE,
            PyInterpreterState_CACHED_PARAMSPECKWARGS_TYPE,
            PyInterpreterState_CACHED_CONSTEVALUATOR_TYPE
        ] {
            slot = ptr[ptr[PyObject]](ptr[u8](interp) + offset);
            old = slot.view(1)[0];
            slot.view(1)[0] = NULL;
            object_xdecref(old);
        }
    }  def _Py_set_typeparam_default(
        _tstate: ptr, typeparam: ptr[PyObject], evaluate_default: ptr[PyObject]
    ) -> ptr[PyObject] {
        offset: i64 = -1;
        if object_is_type(
            typeparam, cached_type(PyInterpreterState_CACHED_TYPEVAR_TYPE)
        ) {
            offset = typevarobject_EVALUATE_DEFAULT;
        } elif object_is_type(
            typeparam, cached_type(PyInterpreterState_CACHED_PARAMSPEC_TYPE)
        ) {
            offset = paramspecobject_EVALUATE_DEFAULT;
        } elif object_is_type(
            typeparam, cached_type(PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE)
        ) {
            offset = typevartupleobject_EVALUATE_DEFAULT;
        }
        if offset < 0 {
            PyErr_Format(PyExc_TypeError, "Expected a type param, got %R", typeparam);
            return NULL;
        }
        replace_field(typeparam, offset, object_new_ref(evaluate_default));
        return object_new_ref(typeparam);
    }
}

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

impl flag(op: ptr[PyObject], offset: i64) -> bool {
    return (ptr[u8](op) + offset).view(1)[0] != u8(0);
}

impl set_flag(op: ptr[PyObject], offset: i64, value: bool) {
    (ptr[u8](op) + offset).view(1)[0] = u8(1) if value else u8(0);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl no_default -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_NoDefaultStruct));
}

impl cached_type(offset: i64) -> ptr[PyTypeObject] {
    return ptr[ptr[PyTypeObject]](current_interp() + offset).view(1)[0];
}

impl set_cached_type(offset: i64, type: ptr[PyObject]) {
    ptr[ptr[PyObject]](current_interp() + offset).view(1)[0] = type;
}

impl heap_free(op: ptr[PyObject]) {
    tp = object_type(op);
    calls = addressof(call_slot);
    calls.view(1)[0].free = int(tp.view(1)[0].tp_free);
    calls.view(1)[0].free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl interned(which: int) -> ptr[PyObject] {
    if which == 0 {
        if not origin_key {
            origin_key = PyUnicode_InternFromString(ptr[u8]("__origin__"));
        }
        return origin_key;
    }
    if which == 1 {
        if not args_key {
            args_key = PyUnicode_InternFromString(ptr[u8]("__args__"));
        }
        return args_key;
    }
    if which == 2 {
        if not qualname_key {
            qualname_key = PyUnicode_InternFromString(ptr[u8]("__qualname__"));
        }
        return qualname_key;
    }
    if not module_key {
        module_key = PyUnicode_InternFromString(ptr[u8]("__module__"));
    }
    return module_key;
}

impl bool_argument(value: ptr[PyObject], fallback: bool) -> i32 {
    if not value {
        return i32(1) if fallback else i32(0);
    }
    return PyObject_IsTrue(value);
}

impl NoDefault_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("typing.NoDefault"));
}

impl NoDefault_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("NoDefault"));
}

impl nodefault_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if object_size(args) != 0 or (kwargs and PyDict_Size(kwargs) != 0) {
        PyErr_SetString(PyExc_TypeError, "NoDefaultType takes no arguments");
        return NULL;
    }
    return no_default();
}

impl nodefault_dealloc(nodefault: ptr[PyObject]) {
    _Py_SetImmortal(nodefault);
}

impl constevaluator_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    object_xdecref(field(self, constevaluatorobject_VALUE));
    heap_free(self);
}

impl constevaluator_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(field(self, constevaluatorobject_VALUE), visitor, arg);
}

impl constevaluator_clear(self: ptr[PyObject]) -> i32 {
    replace_field(self, constevaluatorobject_VALUE, NULL);
    return i32(0);
}

impl constevaluator_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<constevaluator %R>", field(self, constevaluatorobject_VALUE)
    );
}

impl constevaluator_call(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if kwargs and _PyArg_NoKeywords("constevaluator.__call__", kwargs) == 0 {
        return NULL;
    }
    format: i32 = 0;
    if PyArg_ParseTuple(args, "i:constevaluator.__call__", &mut format) == 0 {
        return NULL;
    }
    value = field(self, constevaluatorobject_VALUE);
    if format != _Py_ANNOTATE_FORMAT_STRING {
        return object_new_ref(value);
    }

    writer = PyUnicodeWriter_Create(5);
    if not writer {
        return NULL;
    }
    ok = True;
    if type_has_feature(object_type(value), Py_TPFLAGS_TUPLE_SUBCLASS) {
        ok = PyUnicodeWriter_WriteChar(writer, 40) >= 0;
        i: i64 = 0;
        while ok and i < object_size(value) {
            if i > 0 {
                ok = PyUnicodeWriter_WriteASCII(ptr(writer), ptr[u8](", "), 2) >= 0;
            }
            ok = ok and _Py_typing_type_repr(writer, tuple_get_item(value, i)) >= 0;
            i += 1;
        }
        ok = ok and PyUnicodeWriter_WriteChar(writer, 41) >= 0;
    } else {
        ok = _Py_typing_type_repr(writer, value) >= 0;
    }
    if not ok {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

impl constevaluator_alloc(value: ptr[PyObject]) -> ptr[PyObject] {
    tp = cached_type(PyInterpreterState_CACHED_CONSTEVALUATOR_TYPE);
    ce = _PyObject_GC_New(ptr[PyObject](tp));
    if not ce {
        return NULL;
    }
    set_field(ce, constevaluatorobject_VALUE, object_new_ref(value));
    object_gc_track(ce);
    return ce;
}

impl call_typing_func_object(name: str, args: list[ptr[PyObject]]) -> ptr[PyObject] {
    typing = PyImport_ImportModule("typing");
    if not typing {
        return NULL;
    }
    func = jacpy_object_getattr_text(typing, name);
    if not func {
        object_decref(typing);
        return NULL;
    }
    pack = PyTuple_New(len(args));
    result: ptr[PyObject] = NULL;
    if pack {
        i: i64 = 0;
        for a in args {
            tuple_set_item(pack, i, object_new_ref(a));
            i += 1;
        }
        result = PyObject_Call(func, pack, NULL);
        object_decref(pack);
    }
    object_decref(func);
    object_decref(typing);
    return result;
}

impl type_check(arg: ptr[PyObject], msg: str) -> ptr[PyObject] {
    if arg == Py_None {
        return object_new_ref(ptr[PyObject](object_type(arg)));
    }
    message_str = jacpy_unicode_from_text(msg);
    if not message_str {
        return NULL;
    }
    result = call_typing_func_object("_type_check", [arg, message_str]);
    object_decref(message_str);
    return result;
}

impl make_union(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    args = PyTuple_Pack(2, self, other);
    if not args {
        return NULL;
    }
    u = _Py_union_from_tuple(args);
    object_decref(args);
    return u;
}

impl caller -> ptr[PyObject] {
    tstate = ptr[u8](current_tstate());
    f = ptr[ptr[u8]](tstate + PyThreadState_CURRENT_FRAME).view(1)[0];
    if not f {
        return object_new_ref(Py_None);
    }
    funcobj = ptr[u64](f + _PyInterpreterFrame_F_FUNCOBJ).view(1)[0];

    if funcobj == u64(1) {
        return object_new_ref(Py_None);
    }
    r = PyFunction_GetModule(ptr[PyObject](i64.wrap(funcobj & ~u64(1))));
    if not r {
        PyErr_Clear();
        return object_new_ref(Py_None);
    }
    return object_new_ref(r);
}

impl unpack(self: ptr[PyObject]) -> ptr[PyObject] {
    typing = PyImport_ImportModule("typing");
    if not typing {
        return NULL;
    }
    unpack_form = PyObject_GetAttrString(typing, ptr[u8]("Unpack"));
    if not unpack_form {
        object_decref(typing);
        return NULL;
    }
    unpacked = PyObject_GetItem(unpack_form, self);
    object_decref(typing);
    object_decref(unpack_form);
    return unpacked;
}

impl contains_typevartuple(params: ptr[PyObject]) -> bool {
    tp = cached_type(PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE);
    for i in range(object_size(params)) {
        if object_is_type(tuple_get_item(params, i), tp) {
            return True;
        }
    }
    return False;
}

impl unpack_typevartuples(params: ptr[PyObject]) -> ptr[PyObject] {
    if not contains_typevartuple(params) {
        return object_new_ref(params);
    }
    n = object_size(params);
    new_params = PyTuple_New(n);
    if not new_params {
        return NULL;
    }
    tp = cached_type(PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE);
    for i in range(n) {
        param = tuple_get_item(params, i);
        if object_is_type(param, tp) {
            unpacked = unpack(param);
            if not unpacked {
                object_decref(new_params);
                return NULL;
            }
            tuple_set_item(new_params, i, unpacked);
        } else {
            tuple_set_item(new_params, i, object_new_ref(param));
        }
    }
    return new_params;
}

impl lazy_attribute(
    op: ptr[PyObject], value_offset: i64, evaluate_offset: i64, fallback: ptr[PyObject]
) -> ptr[PyObject] {
    value = field(op, value_offset);
    if value {
        return object_new_ref(value);
    }
    evaluate = field(op, evaluate_offset);
    if not evaluate {
        return fallback;
    }
    result = PyObject_CallNoArgs(evaluate);
    set_field(op, value_offset, object_xnew_ref(result));
    return result;
}

impl evaluator_attribute(
    op: ptr[PyObject], value_offset: i64, evaluate_offset: i64
) -> ptr[PyObject] {
    evaluate = field(op, evaluate_offset);
    if evaluate {
        return object_new_ref(evaluate);
    }
    value = field(op, value_offset);
    if value {
        return constevaluator_alloc(value);
    }
    return object_new_ref(Py_None);
}

impl has_default(
    op: ptr[PyObject], default_offset: i64, evaluate_offset: i64
) -> ptr[PyObject] {
    value = field(op, default_offset);
    if field(op, evaluate_offset) or (value != no_default() and value) {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl variance_repr(
    op: ptr[PyObject], name_offset: i64, covariant: i64, contravariant: i64, infer: i64
) -> ptr[PyObject] {
    name = field(op, name_offset);
    if flag(op, infer) {
        return object_new_ref(name);
    }
    variance = i32(43)
        if flag(op, covariant)
        else (i32(45) if flag(op, contravariant) else i32(126));
    return PyUnicode_FromFormat("%c%U", variance, name);
}

impl mro_entries_error(name: str) -> ptr[PyObject] {
    PyErr_Format(PyExc_TypeError, "Cannot subclass an instance of %s", name);
    return NULL;
}

impl with_module(op: ptr[PyObject], module: ptr[PyObject]) -> ptr[PyObject] {
    if module and PyObject_SetAttrString(op, ptr[u8]("__module__"), module) < 0 {
        object_decref(op);
        return NULL;
    }
    return op;
}

impl typevar_offsets -> list[i64] {
    return [
        typevarobject_NAME,
        typevarobject_BOUND,
        typevarobject_EVALUATE_BOUND,
        typevarobject_CONSTRAINTS,
        typevarobject_EVALUATE_CONSTRAINTS,
        typevarobject_DEFAULT_VALUE,
        typevarobject_EVALUATE_DEFAULT
    ];
}

impl typevar_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    for offset in typevar_offsets() {
        object_xdecref(field(self, offset));
    }
    PyObject_ClearManagedDict(self);
    PyObject_ClearWeakRefs(self);
    heap_free(self);
}

impl typevar_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(self)), visitor, arg);
    for offset in typevar_offsets() {
        if status != 0 {
            return status;
        }
        status = visit_reference(field(self, offset), visitor, arg);
    }
    if status != 0 {
        return status;
    }
    return PyObject_VisitManagedDict(self, visitor, arg);
}

impl typevar_clear(op: ptr[PyObject]) -> i32 {
    for offset in typevar_offsets() {
        replace_field(op, offset, NULL);
    }
    PyObject_ClearManagedDict(op);
    return i32(0);
}

impl typevar_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return variance_repr(
        self,
        typevarobject_NAME,
        typevarobject_COVARIANT,
        typevarobject_CONTRAVARIANT,
        typevarobject_INFER_VARIANCE
    );
}

impl typevar_bound(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return lazy_attribute(
        op, typevarobject_BOUND, typevarobject_EVALUATE_BOUND, object_new_ref(Py_None)
    );
}

impl typevar_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return lazy_attribute(
        op, typevarobject_DEFAULT_VALUE, typevarobject_EVALUATE_DEFAULT, no_default()
    );
}

impl typevar_constraints(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    value = field(op, typevarobject_CONSTRAINTS);
    if value {
        return object_new_ref(value);
    }
    if not field(op, typevarobject_EVALUATE_CONSTRAINTS) {
        return PyTuple_New(0);
    }
    return lazy_attribute(
        op, typevarobject_CONSTRAINTS, typevarobject_EVALUATE_CONSTRAINTS, NULL
    );
}

impl typevar_evaluate_bound(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return evaluator_attribute(op, typevarobject_BOUND, typevarobject_EVALUATE_BOUND);
}

impl typevar_evaluate_constraints(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return evaluator_attribute(
        op, typevarobject_CONSTRAINTS, typevarobject_EVALUATE_CONSTRAINTS
    );
}

impl typevar_evaluate_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return evaluator_attribute(
        op, typevarobject_DEFAULT_VALUE, typevarobject_EVALUATE_DEFAULT
    );
}

impl typevar_alloc(
    name: ptr[PyObject],
    bound: ptr[PyObject],
    evaluate_bound: ptr[PyObject],
    constraints: ptr[PyObject],
    evaluate_constraints: ptr[PyObject],
    default_value: ptr[PyObject],
    covariant: bool,
    contravariant: bool,
    infer_variance: bool,
    module: ptr[PyObject]
) -> ptr[PyObject] {
    tv = _PyObject_GC_New(
        ptr[PyObject](cached_type(PyInterpreterState_CACHED_TYPEVAR_TYPE))
    );
    if not tv {
        return NULL;
    }
    set_field(tv, typevarobject_NAME, object_new_ref(name));
    set_field(tv, typevarobject_BOUND, object_xnew_ref(bound));
    set_field(tv, typevarobject_EVALUATE_BOUND, object_xnew_ref(evaluate_bound));
    set_field(tv, typevarobject_CONSTRAINTS, object_xnew_ref(constraints));
    set_field(
        tv, typevarobject_EVALUATE_CONSTRAINTS, object_xnew_ref(evaluate_constraints)
    );
    set_field(tv, typevarobject_DEFAULT_VALUE, object_xnew_ref(default_value));
    set_field(tv, typevarobject_EVALUATE_DEFAULT, NULL);
    set_flag(tv, typevarobject_COVARIANT, covariant);
    set_flag(tv, typevarobject_CONTRAVARIANT, contravariant);
    set_flag(tv, typevarobject_INFER_VARIANCE, infer_variance);
    object_gc_track(tv);
    return with_module(tv, module);
}

impl check_variance(covariant: i32, contravariant: i32, infer_variance: i32) -> bool {
    if covariant != 0 and contravariant != 0 {
        PyErr_SetString(PyExc_ValueError, "Bivariant types are not supported.");
        return False;
    }
    if infer_variance != 0 and (covariant != 0 or contravariant != 0) {
        PyErr_SetString(
            PyExc_ValueError, "Variance cannot be specified with infer_variance."
        );
        return False;
    }
    return True;
}

impl variance_flags(values: ptr[ptr[PyObject]]) -> tuple[i32, i32, i32, i32] {
    covariant = bool_argument((values + 3).view(1)[0], False);
    if covariant < 0 {
        return (i32(-1), i32(0), i32(0), i32(0));
    }
    contravariant = bool_argument((values + 4).view(1)[0], False);
    if contravariant < 0 {
        return (i32(-1), i32(0), i32(0), i32(0));
    }
    infer_variance = bool_argument((values + 5).view(1)[0], False);
    if infer_variance < 0 {
        return (i32(-1), i32(0), i32(0), i32(0));
    }
    return (i32(0), covariant, contravariant, infer_variance);
}

impl check_name(name: ptr[PyObject], fname: str) -> bool {
    if not type_has_feature(object_type(name), Py_TPFLAGS_UNICODE_SUBCLASS) {
        _PyArg_BadArgument(fname, "argument 'name'", ptr[u8]("str"), name);
        return False;
    }
    return True;
}

impl typevar_new_values(
    constraints: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    name = values.view(1)[0];
    if not check_name(name, "typevar") {
        return NULL;
    }
    bound = (values + 1).view(1)[0];
    default_value = (values + 2).view(1)[0]
        if (values + 2).view(1)[0]
        else no_default();
    (status, covariant, contravariant, infer_variance) = variance_flags(values);
    if status < 0 or not check_variance(covariant, contravariant, infer_variance) {
        return NULL;
    }
    if bound == Py_None {
        bound = NULL;
    }
    if bound {
        bound = type_check(bound, "Bound must be a type.");
        if not bound {
            return NULL;
        }
    }
    n_constraints = object_size(constraints);
    kept = constraints;
    if n_constraints == 1 {
        PyErr_SetString(PyExc_TypeError, "A single constraint is not allowed");
        object_xdecref(bound);
        return NULL;
    } elif n_constraints == 0 {
        kept = NULL;
    } elif bound {
        PyErr_SetString(
            PyExc_TypeError, "Constraints cannot be combined with bound=..."
        );
        object_xdecref(bound);
        return NULL;
    }
    module = caller();
    if not module {
        object_xdecref(bound);
        return NULL;
    }
    tv = typevar_alloc(
        name,
        bound,
        NULL,
        kept,
        NULL,
        default_value,
        covariant != 0,
        contravariant != 0,
        infer_variance != 0,
        module
    );
    object_xdecref(bound);
    object_xdecref(module);
    return tv;
}

impl typevar_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    head = PyTuple_GetSlice(args, 0, 1);
    if not head {
        return NULL;
    }
    constraints = PyTuple_GetSlice(args, 1, PY_SSIZE_T_MAX);
    if not constraints {
        object_decref(head);
        return NULL;
    }
    result = invoke_tuple(
        typevar_signature, head, kwargs, typevar_new_values, constraints
    );
    object_decref(head);
    object_decref(constraints);
    return result;
}

impl typevar_typing_subst(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return call_typing_func_object("_typevar_subst", [self, arg]);
}

impl typevar_typing_prepare_subst(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("__typing_prepare_subst__", nargs, 2, 2) == 0 {
        return NULL;
    }
    alias = args.view(1)[0];
    subst_args = (args + 1).view(1)[0];
    params = PyObject_GetAttrString(alias, ptr[u8]("__parameters__"));
    if not params {
        return NULL;
    }
    i = PySequence_Index(params, self);
    if i == -1 {
        object_decref(params);
        return NULL;
    }
    args_len = PySequence_Length(subst_args);
    if args_len == -1 {
        object_decref(params);
        return NULL;
    }
    if i < args_len {
        object_decref(params);
        return object_new_ref(subst_args);
    }
    if i == args_len {
        dflt = typevar_default(self, ptr());
        if not dflt {
            object_decref(params);
            return NULL;
        }
        if dflt != no_default() {
            new_args = PyTuple_Pack(1, dflt);
            object_decref(dflt);
            if not new_args {
                object_decref(params);
                return NULL;
            }
            result = PySequence_Concat(subst_args, new_args);
            object_decref(params);
            object_decref(new_args);
            return result;
        }
    }
    object_decref(params);
    PyErr_Format(
        PyExc_TypeError,
        "Too few arguments for %S; actual %zd, expected at least %zd",
        alias,
        args_len,
        i + 1
    );
    return NULL;
}

impl typevar_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(field(self, typevarobject_NAME));
}

impl typevar_has_default(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return has_default(
        self, typevarobject_DEFAULT_VALUE, typevarobject_EVALUATE_DEFAULT
    );
}

impl typevar_mro_entries(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return mro_entries_error("TypeVar");
}

impl paramspecattr_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    object_xdecref(field(self, paramspecattrobject_ORIGIN));
    heap_free(self);
}

impl paramspecattr_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(field(self, paramspecattrobject_ORIGIN), visitor, arg);
}

impl paramspecattr_clear(op: ptr[PyObject]) -> i32 {
    replace_field(op, paramspecattrobject_ORIGIN, NULL);
    return i32(0);
}

impl paramspecattr_richcompare(
    a: ptr[PyObject], b: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not object_is_type(a, object_type(b)) or (op != Py_EQ and op != Py_NE) {
        return object_new_ref(Py_NotImplemented);
    }
    return PyObject_RichCompare(
        field(a, paramspecattrobject_ORIGIN), field(b, paramspecattrobject_ORIGIN), op
    );
}

impl paramspecattr_new(tp: ptr[PyTypeObject], origin: ptr[PyObject]) -> ptr[PyObject] {
    psa = _PyObject_GC_New(ptr[PyObject](tp));
    if not psa {
        return NULL;
    }
    set_field(psa, paramspecattrobject_ORIGIN, object_new_ref(origin));
    object_gc_track(psa);
    return psa;
}

impl paramspecattr_repr(self: ptr[PyObject], suffix: str) -> ptr[PyObject] {
    origin = field(self, paramspecattrobject_ORIGIN);
    if object_is_type(origin, cached_type(PyInterpreterState_CACHED_PARAMSPEC_TYPE)) {
        return PyUnicode_FromFormat(
            "%U.%s", field(origin, paramspecobject_NAME), suffix
        );
    }
    return PyUnicode_FromFormat("%R.%s", origin, suffix);
}

impl paramspecargs_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return paramspecattr_repr(self, "args");
}

impl paramspeckwargs_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return paramspecattr_repr(self, "kwargs");
}

impl paramspecattr_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    return paramspecattr_new(ptr[PyTypeObject](type), values.view(1)[0]);
}

impl paramspecargs_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_tuple(
        paramspecargs_signature, args, kwargs, paramspecattr_new_values, type
    );
}

impl paramspeckwargs_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_tuple(
        paramspeckwargs_signature, args, kwargs, paramspecattr_new_values, type
    );
}

impl paramspecargs_mro_entries(
    self: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return mro_entries_error("ParamSpecArgs");
}

impl paramspeckwargs_mro_entries(
    self: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return mro_entries_error("ParamSpecKwargs");
}

impl paramspec_offsets -> list[i64] {
    return [
        paramspecobject_NAME,
        paramspecobject_BOUND,
        paramspecobject_DEFAULT_VALUE,
        paramspecobject_EVALUATE_DEFAULT
    ];
}

impl paramspec_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    for offset in paramspec_offsets() {
        object_xdecref(field(self, offset));
    }
    PyObject_ClearManagedDict(self);
    PyObject_ClearWeakRefs(self);
    heap_free(self);
}

impl paramspec_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(self)), visitor, arg);
    for offset in paramspec_offsets() {
        if status != 0 {
            return status;
        }
        status = visit_reference(field(self, offset), visitor, arg);
    }
    if status != 0 {
        return status;
    }
    return PyObject_VisitManagedDict(self, visitor, arg);
}

impl paramspec_clear(op: ptr[PyObject]) -> i32 {
    for offset in paramspec_offsets() {
        replace_field(op, offset, NULL);
    }
    PyObject_ClearManagedDict(op);
    return i32(0);
}

impl paramspec_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return variance_repr(
        self,
        paramspecobject_NAME,
        paramspecobject_COVARIANT,
        paramspecobject_CONTRAVARIANT,
        paramspecobject_INFER_VARIANCE
    );
}

impl paramspec_args(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return paramspecattr_new(
        cached_type(PyInterpreterState_CACHED_PARAMSPECARGS_TYPE), self
    );
}

impl paramspec_kwargs(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return paramspecattr_new(
        cached_type(PyInterpreterState_CACHED_PARAMSPECKWARGS_TYPE), self
    );
}

impl paramspec_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return lazy_attribute(
        op,
        paramspecobject_DEFAULT_VALUE,
        paramspecobject_EVALUATE_DEFAULT,
        no_default()
    );
}

impl paramspec_evaluate_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return evaluator_attribute(
        op, paramspecobject_DEFAULT_VALUE, paramspecobject_EVALUATE_DEFAULT
    );
}

impl paramspec_alloc(
    name: ptr[PyObject],
    bound: ptr[PyObject],
    default_value: ptr[PyObject],
    covariant: bool,
    contravariant: bool,
    infer_variance: bool,
    module: ptr[PyObject]
) -> ptr[PyObject] {
    ps = _PyObject_GC_New(
        ptr[PyObject](cached_type(PyInterpreterState_CACHED_PARAMSPEC_TYPE))
    );
    if not ps {
        return NULL;
    }
    set_field(ps, paramspecobject_NAME, object_new_ref(name));
    set_field(ps, paramspecobject_BOUND, object_xnew_ref(bound));
    set_flag(ps, paramspecobject_COVARIANT, covariant);
    set_flag(ps, paramspecobject_CONTRAVARIANT, contravariant);
    set_flag(ps, paramspecobject_INFER_VARIANCE, infer_variance);
    set_field(ps, paramspecobject_DEFAULT_VALUE, object_xnew_ref(default_value));
    set_field(ps, paramspecobject_EVALUATE_DEFAULT, NULL);
    object_gc_track(ps);
    return with_module(ps, module);
}

impl paramspec_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    name = values.view(1)[0];
    if not check_name(name, "paramspec") {
        return NULL;
    }
    bound = (values + 1).view(1)[0] if (values + 1).view(1)[0] else Py_None;
    default_value = (values + 2).view(1)[0]
        if (values + 2).view(1)[0]
        else no_default();
    (status, covariant, contravariant, infer_variance) = variance_flags(values);
    if status < 0 or not check_variance(covariant, contravariant, infer_variance) {
        return NULL;
    }

    checked = type_check(bound, "Bound must be a type.");
    if not checked {
        return NULL;
    }
    module = caller();
    if not module {
        object_decref(checked);
        return NULL;
    }
    ps = paramspec_alloc(
        name,
        checked,
        default_value,
        covariant != 0,
        contravariant != 0,
        infer_variance != 0,
        module
    );
    object_decref(checked);
    object_decref(module);
    return ps;
}

impl paramspec_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_tuple(paramspec_signature, args, kwargs, paramspec_new_values, type);
}

impl paramspec_typing_subst(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return call_typing_func_object("_paramspec_subst", [self, arg]);
}

impl paramspec_typing_prepare_subst(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("__typing_prepare_subst__", nargs, 2, 2) == 0 {
        return NULL;
    }
    return call_typing_func_object(
        "_paramspec_prepare_subst", [self, args.view(1)[0], (args + 1).view(1)[0]]
    );
}

impl paramspec_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(field(self, paramspecobject_NAME));
}

impl paramspec_has_default(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return has_default(
        self, paramspecobject_DEFAULT_VALUE, paramspecobject_EVALUATE_DEFAULT
    );
}

impl paramspec_mro_entries(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return mro_entries_error("ParamSpec");
}

impl typevartuple_offsets -> list[i64] {
    return [
        typevartupleobject_NAME,
        typevartupleobject_DEFAULT_VALUE,
        typevartupleobject_EVALUATE_DEFAULT
    ];
}

impl typevartuple_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    for offset in typevartuple_offsets() {
        object_xdecref(field(self, offset));
    }
    PyObject_ClearManagedDict(self);
    PyObject_ClearWeakRefs(self);
    heap_free(self);
}

impl unpack_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    unpacked = unpack(self);
    if not unpacked {
        return NULL;
    }
    tuple = PyTuple_Pack(1, unpacked);
    if not tuple {
        object_decref(unpacked);
        return NULL;
    }
    result = PyObject_GetIter(tuple);
    object_decref(unpacked);
    object_decref(tuple);
    return result;
}

impl typevartuple_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(field(self, typevartupleobject_NAME));
}

impl typevartuple_alloc(
    name: ptr[PyObject], module: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    tvt = _PyObject_GC_New(
        ptr[PyObject](cached_type(PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE))
    );
    if not tvt {
        return NULL;
    }
    set_field(tvt, typevartupleobject_NAME, object_new_ref(name));
    set_field(tvt, typevartupleobject_DEFAULT_VALUE, object_xnew_ref(default_value));
    set_field(tvt, typevartupleobject_EVALUATE_DEFAULT, NULL);
    object_gc_track(tvt);
    return with_module(tvt, module);
}

impl typevartuple_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    name = values.view(1)[0];
    if not check_name(name, "typevartuple") {
        return NULL;
    }
    default_value = (values + 1).view(1)[0]
        if (values + 1).view(1)[0]
        else no_default();
    module = caller();
    if not module {
        return NULL;
    }
    result = typevartuple_alloc(name, module, default_value);
    object_decref(module);
    return result;
}

impl typevartuple_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_tuple(
        typevartuple_signature, args, kwargs, typevartuple_new_values, type
    );
}

impl typevartuple_typing_subst(
    self: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_TypeError, "Substitution of bare TypeVarTuple is not supported"
    );
    return NULL;
}

impl typevartuple_typing_prepare_subst(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("__typing_prepare_subst__", nargs, 2, 2) == 0 {
        return NULL;
    }
    return call_typing_func_object(
        "_typevartuple_prepare_subst", [self, args.view(1)[0], (args + 1).view(1)[0]]
    );
}

impl typevartuple_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(field(self, typevartupleobject_NAME));
}

impl typevartuple_has_default(
    self: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return has_default(
        self, typevartupleobject_DEFAULT_VALUE, typevartupleobject_EVALUATE_DEFAULT
    );
}

impl typevartuple_mro_entries(
    self: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return mro_entries_error("TypeVarTuple");
}

impl typevartuple_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(self)), visitor, arg);
    for offset in typevartuple_offsets() {
        if status != 0 {
            return status;
        }
        status = visit_reference(field(self, offset), visitor, arg);
    }
    if status != 0 {
        return status;
    }
    return PyObject_VisitManagedDict(self, visitor, arg);
}

impl typevartuple_clear(self: ptr[PyObject]) -> i32 {
    for offset in typevartuple_offsets() {
        replace_field(self, offset, NULL);
    }
    PyObject_ClearManagedDict(self);
    return i32(0);
}

impl typevartuple_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return lazy_attribute(
        op,
        typevartupleobject_DEFAULT_VALUE,
        typevartupleobject_EVALUATE_DEFAULT,
        no_default()
    );
}

impl typevartuple_evaluate_default(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return evaluator_attribute(
        op, typevartupleobject_DEFAULT_VALUE, typevartupleobject_EVALUATE_DEFAULT
    );
}

impl get_type_param_default(typeparam: ptr[PyObject]) -> ptr[PyObject] {
    if object_is_type(typeparam, cached_type(PyInterpreterState_CACHED_TYPEVAR_TYPE)) {
        return typevar_default(typeparam, ptr());
    }
    if object_is_type(
        typeparam, cached_type(PyInterpreterState_CACHED_PARAMSPEC_TYPE)
    ) {
        return paramspec_default(typeparam, ptr());
    }
    if object_is_type(
        typeparam, cached_type(PyInterpreterState_CACHED_TYPEVARTUPLE_TYPE)
    ) {
        return typevartuple_default(typeparam, ptr());
    }
    PyErr_Format(PyExc_TypeError, "Expected a type param, got %R", typeparam);
    return NULL;
}

impl typealias_offsets -> list[i64] {
    return [
        typealiasobject_NAME,
        typealiasobject_TYPE_PARAMS,
        typealiasobject_COMPUTE_VALUE,
        typealiasobject_VALUE,
        typealiasobject_MODULE
    ];
}

impl typealias_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    for offset in typealias_offsets() {
        object_xdecref(field(self, offset));
    }
    heap_free(self);
}

impl typealias_get_value(ta: ptr[PyObject]) -> ptr[PyObject] {
    value = field(ta, typealiasobject_VALUE);
    if value {
        return object_new_ref(value);
    }
    result = PyObject_CallNoArgs(field(ta, typealiasobject_COMPUTE_VALUE));
    if not result {
        return NULL;
    }
    set_field(ta, typealiasobject_VALUE, object_new_ref(result));
    return result;
}

impl typealias_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(field(self, typealiasobject_NAME));
}

impl typealias_value(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return typealias_get_value(self);
}

impl typealias_evaluate_value(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    compute = field(self, typealiasobject_COMPUTE_VALUE);
    if compute {
        return object_new_ref(compute);
    }
    return constevaluator_alloc(field(self, typealiasobject_VALUE));
}

impl typealias_parameters(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    params = field(self, typealiasobject_TYPE_PARAMS);
    if not params {
        return PyTuple_New(0);
    }
    return unpack_typevartuples(params);
}

impl typealias_type_params(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    params = field(self, typealiasobject_TYPE_PARAMS);
    if not params {
        return PyTuple_New(0);
    }
    return object_new_ref(params);
}

impl typealias_module(self: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    module = field(self, typealiasobject_MODULE);
    if module {
        return object_new_ref(module);
    }
    compute = field(self, typealiasobject_COMPUTE_VALUE);
    if compute {
        mod = PyFunction_GetModule(compute);
        if mod {
            return object_new_ref(mod);
        }
    }
    return object_new_ref(Py_None);
}

impl typealias_check_type_params(
    type_params: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    if not type_params {
        return (i32(0), NULL);
    }
    length = object_size(type_params);
    if length == 0 {
        return (i32(0), NULL);
    }
    default_seen = False;
    for index in range(length) {
        type_param = tuple_get_item(type_params, index);
        dflt = get_type_param_default(type_param);
        if not dflt {
            return (i32(-1), NULL);
        }
        if dflt == no_default() {
            if default_seen {
                PyErr_Format(
                    PyExc_TypeError,
                    "non-default type parameter '%R' follows default type parameter",
                    type_param
                );
                return (i32(-1), NULL);
            }
        } else {
            default_seen = True;
            object_decref(dflt);
        }
    }
    return (i32(0), type_params);
}

impl typealias_convert_type_params(type_params: ptr[PyObject]) -> ptr[PyObject] {
    if not type_params
        or type_params == Py_None
        or (
            type_has_feature(object_type(type_params), Py_TPFLAGS_TUPLE_SUBCLASS)
            and object_size(type_params) == 0
        ) {
        return NULL;
    }
    return type_params;
}

impl typealias_alloc(
    name: ptr[PyObject],
    type_params: ptr[PyObject],
    compute_value: ptr[PyObject],
    value: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject] {
    ta = _PyObject_GC_New(ptr[PyObject](addressof(_PyTypeAlias_Type)));
    if not ta {
        return NULL;
    }
    set_field(ta, typealiasobject_NAME, object_new_ref(name));
    set_field(ta, typealiasobject_TYPE_PARAMS, object_xnew_ref(type_params));
    set_field(ta, typealiasobject_COMPUTE_VALUE, object_xnew_ref(compute_value));
    set_field(ta, typealiasobject_VALUE, object_xnew_ref(value));
    set_field(ta, typealiasobject_MODULE, object_xnew_ref(module));
    object_gc_track(ta);
    return ta;
}

impl typealias_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    for offset in typealias_offsets() {
        status = visit_reference(field(op, offset), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl typealias_clear(op: ptr[PyObject]) -> i32 {
    for offset in typealias_offsets() {
        replace_field(op, offset, NULL);
    }
    return i32(0);
}

impl typealias_reduce(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(field(self, typealiasobject_NAME));
}

impl typealias_subscript(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if not field(op, typealiasobject_TYPE_PARAMS) {
        PyErr_SetString(PyExc_TypeError, "Only generic type aliases are subscriptable");
        return NULL;
    }
    return Py_GenericAlias(op, args);
}

impl typealias_new_values(
    type: ptr[PyObject], values: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    name = values.view(1)[0];
    if not check_name(name, "typealias") {
        return NULL;
    }
    value = (values + 1).view(1)[0];
    type_params = (values + 2).view(1)[0];
    if type_params
        and not type_has_feature(object_type(type_params), Py_TPFLAGS_TUPLE_SUBCLASS) {
        PyErr_SetString(PyExc_TypeError, "type_params must be a tuple");
        return NULL;
    }
    (status, checked_params) = typealias_check_type_params(type_params);
    if status < 0 {
        return NULL;
    }
    module = caller();
    if not module {
        return NULL;
    }
    ta = typealias_alloc(name, checked_params, NULL, value, module);
    object_decref(module);
    return ta;
}

impl typealias_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_tuple(typealias_signature, args, kwargs, typealias_new_values, type);
}

impl call_typing_args_kwargs(
    name: str, cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    typing = PyImport_ImportModule("typing");
    if not typing {
        return NULL;
    }
    func = jacpy_object_getattr_text(typing, name);
    if not func {
        object_decref(typing);
        return NULL;
    }
    nargs = object_size(args);
    new_args = PyTuple_New(nargs + 1);
    if not new_args {
        object_decref(typing);
        object_decref(func);
        return NULL;
    }
    tuple_set_item(new_args, 0, object_new_ref(cls));
    for i in range(nargs) {
        tuple_set_item(new_args, i + 1, object_new_ref(tuple_get_item(args, i)));
    }
    result = PyObject_Call(func, new_args, kwargs);
    object_decref(typing);
    object_decref(func);
    object_decref(new_args);
    return result;
}

impl generic_init_subclass(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return call_typing_args_kwargs("_generic_init_subclass", cls, args, kwargs);
}

impl generic_class_getitem(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return call_typing_args_kwargs("_generic_class_getitem", cls, args, kwargs);
}

impl generic_dealloc(self: ptr[PyObject]) {
    object_gc_untrack(self);
    heap_free(self);
}

impl generic_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(self)), visitor, arg);
}
