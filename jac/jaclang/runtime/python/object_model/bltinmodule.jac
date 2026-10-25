import from c {
    obj BuiltinStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut BuiltinStack) -> int;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def strlen(text: ptr[u8]) -> u64;  def strcmp(
        a: ptr[u8], b: ptr[u8]
    ) -> i32;  def isatty(fd: i32) -> i32;  def fabs(value: f64) -> f64;  def _PyArg_UnpackKeywords(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwargs: ptr[PyObject],
        kwnames: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        minpos: i32,
        maxpos: i32,
        minkw: i32,
        varpos: i32,
        buf: ptr[ptr[PyObject]]
    ) -> ptr[ptr[PyObject]];  def _PyArg_ParseStackAndKeywords(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[PyObject],
        parser: ptr[_PyArg_Parser],
        *rest: any
    ) -> i32;  def _PyArg_UnpackStack(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        name: ptr[u8],
        min: i64,
        max: i64,
        *rest: any
    ) -> i32;  def _Py_SourceAsString(
        cmd: ptr[PyObject],
        funcname: ptr[u8],
        what: ptr[u8],
        cf: ptr[PyCompilerFlags],
        cmd_copy: &mut ptr[PyObject]
    ) -> ptr[u8];  def Py_CompileStringObject(
        text: ptr[u8],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[PyCompilerFlags],
        optimize: i32
    ) -> ptr[PyObject];  def _PyJac_CompileObject(
        source: ptr[PyObject],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[PyCompilerFlags],
        optimize: i32
    ) -> ptr[PyObject];  def PyAST_Check(obj_: ptr[PyObject]) -> i32;  def PyRun_StringFlags(
        text: ptr[u8],
        start: i32,
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        flags: ptr[PyCompilerFlags]
    ) -> ptr[PyObject];  def PyOS_Readline(
        sys_stdin: ptr, sys_stdout: ptr, prompt: ptr[u8]
    ) -> ptr[u8];  def _PySys_GetRequiredAttrString(name: ptr[u8]) -> ptr[PyObject];  def _PySys_GetRequiredAttr(
        name: ptr[PyObject]
    ) -> ptr[PyObject];  def PyImport_ImportModuleLevelObject(
        name: ptr[PyObject],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: i32
    ) -> ptr[PyObject];  def _PyInterpreterState_GetConfig(
        interp: ptr[u8]
    ) -> ptr[u8];  def PyEval_EvalCode(
        co: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
    ) -> ptr[PyObject];  def PyEval_EvalCodeEx(
        _co: ptr[PyObject],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        argcount: i32,
        kws: ptr[ptr[PyObject]],
        kwcount: i32,
        defs: ptr[ptr[PyObject]],
        defcount: i32,
        kwdefs: ptr[PyObject],
        closure: ptr[PyObject]
    ) -> ptr[PyObject];  def PyEval_MergeCompilerFlags(
        cf: ptr[PyCompilerFlags]
    ) -> i32;  def _PyEval_EnsureBuiltins(
        tstate: ptr[PyThreadState],
        globals: ptr[PyObject],
        p_builtins: ptr[ptr[PyObject]]
    ) -> i32;  def _PyEval_GetFrame -> ptr[u8];  def _PyEval_GetFrameLocals -> ptr[
        PyObject
    ];  def _PyEval_GetGlobalsFromRunningMain(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def PyEval_GetGlobals -> ptr[PyObject];  def _PyEval_Vector(
        tstate: ptr[PyThreadState],
        func: ptr[PyObject],
        locals: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        argcount: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def PyMapping_SetItemString(
        o: ptr[PyObject], key: ptr[u8], value: ptr[PyObject]
    ) -> i32;  def PyNumber_Power(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_Format(
        obj_: ptr[PyObject], format_spec: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_GetAIter(o: ptr[PyObject]) -> ptr[PyObject];  def PyObject_ASCII(
        v: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_Size(o: ptr[PyObject]) -> i64;  def PyObject_DelAttr(
        v: ptr[PyObject], name: ptr[PyObject]
    ) -> i32;  def PyObject_VectorcallDict(
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_MakeTpCall(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargs: i64,
        keywords: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyStack_AsDict(
        values: ptr[ptr[PyObject]], kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def PyComplex_AsCComplex(op: ptr[PyObject]) -> Py_complex;  def _PyErr_NoMemory(
        tstate: ptr
    ) -> ptr[PyObject];  def PyFile_GetLine(
        f: ptr[PyObject], n: i32
    ) -> ptr[PyObject];  def PyFile_WriteObject(
        v: ptr[PyObject], f: ptr[PyObject], flags: i32
    ) -> i32;  def PyFile_WriteString(s: ptr[u8], f: ptr[PyObject]) -> i32;  def _PyFile_Flush(
        file: ptr[PyObject]
    ) -> i32;  def _PyFloat_ExactDealloc(ob: ptr[PyObject]);  def PyAnextAwaitable_New(
        awaitable: ptr[PyObject], default_value: ptr[PyObject]
    ) -> ptr[PyObject];  def PyCallIter_New(
        function: ptr[PyObject], sentinel: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyModule_CreateInitialized(
        module: ptr[PyModuleDef], module_api_version: i32
    ) -> ptr[PyObject];  def _PyObject_MaybeCallSpecialNoArgs(
        self_: ptr[PyObject], attr: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_MaybeCallSpecialOneArg(
        self_: ptr[PyObject], attr: ptr[PyObject], arg: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyType_CalculateMetaclass(
        metatype: ptr[PyTypeObject], bases: ptr[PyObject]
    ) -> ptr[PyTypeObject];  def PyUnicode_FSDecoder(
        arg: ptr[PyObject], addr: ptr
    ) -> i32;  glob PyClassMethod_Type: PyTypeObject,
         PyMemoryView_Type: PyTypeObject,
         PyProperty_Type: PyTypeObject,
         PyStaticMethod_Type: PyTypeObject,
         PySuper_Type: PyTypeObject; glob:priv import_keywords: list[ptr[u8]] = [
             ptr[u8]("name"),
             ptr[u8]("globals"),
             ptr[u8]("locals"),
             ptr[u8]("fromlist"),
             ptr[u8]("level"),
             ptr[u8]()
         ],
         import_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(import_keywords), fname=ptr[u8]("__import__")
         ),
         compile_keywords: list[ptr[u8]] = [
             ptr[u8]("source"),
             ptr[u8]("filename"),
             ptr[u8]("mode"),
             ptr[u8]("flags"),
             ptr[u8]("dont_inherit"),
             ptr[u8]("optimize"),
             ptr[u8]("_feature_version"),
             ptr[u8]()
         ],
         compile_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(compile_keywords), fname=ptr[u8]("compile")
         ),
         eval_keywords: list[ptr[u8]] = [
             ptr[u8](""),
             ptr[u8]("globals"),
             ptr[u8]("locals"),
             ptr[u8]()
         ],
         eval_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(eval_keywords), fname=ptr[u8]("eval")
         ),
         exec_keywords: list[ptr[u8]] = [
             ptr[u8](""),
             ptr[u8]("globals"),
             ptr[u8]("locals"),
             ptr[u8]("closure"),
             ptr[u8]()
         ],
         exec_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(exec_keywords), fname=ptr[u8]("exec")
         ),
         pow_keywords: list[ptr[u8]] = [
             ptr[u8]("base"),
             ptr[u8]("exp"),
             ptr[u8]("mod"),
             ptr[u8]()
         ],
         pow_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(pow_keywords), fname=ptr[u8]("pow")
         ),
         print_keywords: list[ptr[u8]] = [
             ptr[u8]("sep"),
             ptr[u8]("end"),
             ptr[u8]("file"),
             ptr[u8]("flush"),
             ptr[u8]()
         ],
         print_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(print_keywords), fname=ptr[u8]("print")
         ),
         round_keywords: list[ptr[u8]] = [
             ptr[u8]("number"),
             ptr[u8]("ndigits"),
             ptr[u8]()
         ],
         round_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(round_keywords), fname=ptr[u8]("round")
         ),
         sum_keywords: list[ptr[u8]] = [ptr[u8](""), ptr[u8]("start"), ptr[u8]()],
         sum_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(sum_keywords), fname=ptr[u8]("sum")
         ),
         min_max_keywords: list[ptr[u8]] = [
             ptr[u8]("key"),
             ptr[u8]("default"),
             ptr[u8]()
         ],
         min_parser: _PyArg_Parser = _PyArg_Parser(
             format=ptr[u8]("|$OO:min"), keywords=addressof(min_max_keywords)
         ),
         max_parser: _PyArg_Parser = _PyArg_Parser(
             format=ptr[u8]("|$OO:max"), keywords=addressof(min_max_keywords)
         ),
         map_kwlist: list[ptr[u8]] = [ptr[u8]("strict"), ptr[u8]()],
         zip_kwlist: list[ptr[u8]] = [ptr[u8]("strict"), ptr[u8]()],
         filter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(filter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         map_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(map_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(map_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         zip_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(zip_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(zip_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         builtin_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__build_class__"),
                 ml_meth=ptr(builtin___build_class__),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__build_class__(func, name, /, *bases, [metaclass], **kwds) -> class\n"
                     "\n"
                     "Internal helper function used by the class statement."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__import__"),
                 ml_meth=ptr(builtin___import__),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__import__($module, /, name, globals=None, locals=None, fromlist=(),\n"
                     "           level=0)\n"
                     "--\n"
                     "\n"
                     "Import a module.\n"
                     "\n"
                     "Because this function is meant for use by the Python\n"
                     "interpreter and not for general use, it is better to use\n"
                     "importlib.import_module() to programmatically import a module.\n"
                     "\n"
                     "The globals argument is only used to determine the context;\n"
                     "they are not modified.  The locals argument is unused.  The fromlist\n"
                     "should be a list of names to emulate ``from name import ...``, or an\n"
                     "empty list to emulate ``import name``.\n"
                     "When importing a module from a package, note that __import__('A.B', ...)\n"
                     "returns package A when fromlist is empty, but its submodule B when\n"
                     "fromlist is not empty.  The level argument is used to determine whether\n"
                     "to perform absolute or relative imports: 0 is absolute, while a positive\n"
                     "number is the number of parent directories to search relative to the\n"
                     "current module."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("abs"),
                 ml_meth=ptr(builtin_abs),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "abs($module, x, /)\n"
                     "--\n"
                     "\n"
                     "Return the absolute value of the argument."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("all"),
                 ml_meth=ptr(builtin_all),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "all($module, iterable, /)\n"
                     "--\n"
                     "\n"
                     "Return True if bool(x) is True for all values x in the iterable.\n"
                     "\n"
                     "If the iterable is empty, return True."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("any"),
                 ml_meth=ptr(builtin_any),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "any($module, iterable, /)\n"
                     "--\n"
                     "\n"
                     "Return True if bool(x) is True for any x in the iterable.\n"
                     "\n"
                     "If the iterable is empty, return False."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ascii"),
                 ml_meth=ptr(builtin_ascii),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "ascii($module, obj, /)\n"
                     "--\n"
                     "\n"
                     "Return an ASCII-only representation of an object.\n"
                     "\n"
                     "As repr(), return a string containing a printable representation of an\n"
                     "object, but escape the non-ASCII characters in the string returned by\n"
                     "repr() using \\\\x, \\\\u or \\\\U escapes. This generates a string similar\n"
                     "to that returned by repr() in Python 2."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("bin"),
                 ml_meth=ptr(builtin_bin),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "bin($module, number, /)\n"
                     "--\n"
                     "\n"
                     "Return the binary representation of an integer.\n"
                     "\n"
                     "   >>> bin(2796202)\n"
                     "   '0b1010101010101010101010'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("breakpoint"),
                 ml_meth=ptr(builtin_breakpoint),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "breakpoint($module, /, *args, **kws)\n"
                     "--\n"
                     "\n"
                     "Call sys.breakpointhook(*args, **kws).  sys.breakpointhook() must accept\n"
                     "whatever arguments are passed.\n"
                     "\n"
                     "By default, this drops you into the pdb debugger."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("callable"),
                 ml_meth=ptr(builtin_callable),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "callable($module, obj, /)\n"
                     "--\n"
                     "\n"
                     "Return whether the object is callable (i.e., some kind of function).\n"
                     "\n"
                     "Note that classes are callable, as are instances of classes with a\n"
                     "__call__() method."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("chr"),
                 ml_meth=ptr(builtin_chr),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "chr($module, i, /)\n"
                     "--\n"
                     "\n"
                     "Return a Unicode string of one character with ordinal i; 0 <= i <= 0x10ffff."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compile"),
                 ml_meth=ptr(builtin_compile),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "compile($module, /, source, filename, mode, flags=0,\n"
                     "        dont_inherit=False, optimize=-1, *, _feature_version=-1)\n"
                     "--\n"
                     "\n"
                     "Compile source into a code object that can be executed by exec() or eval().\n"
                     "\n"
                     "The source code may represent a Python module, statement or\n"
                     "expression.\n"
                     "The filename will be used for run-time error messages.\n"
                     "The mode must be 'exec' to compile a module, 'single' to compile a\n"
                     "single (interactive) statement, or 'eval' to compile an expression.\n"
                     "The flags argument, if present, controls which future statements\n"
                     "influence the compilation of the code.\n"
                     "The dont_inherit argument, if true, stops the compilation inheriting\n"
                     "the effects of any future statements in effect in the code calling\n"
                     "compile; if absent or false these statements do influence the\n"
                     "compilation, in addition to any features explicitly specified."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("delattr"),
                 ml_meth=ptr(builtin_delattr),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "delattr($module, obj, name, /)\n"
                     "--\n"
                     "\n"
                     "Deletes the named attribute from the given object.\n"
                     "\n"
                     "delattr(x, 'y') is equivalent to ``del x.y``"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dir"),
                 ml_meth=ptr(builtin_dir),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "dir([object]) -> list of strings\n"
                     "\n"
                     "If called without an argument, return the names in the current scope.\n"
                     "Else, return an alphabetized list of names comprising (some of) the\n"
                     "attributes of the given object, and of attributes reachable from it.\n"
                     "If the object supplies a method named __dir__, it will be used;\n"
                     "otherwise the default dir() logic is used and returns:\n"
                     "  for a module object: the module's attributes.\n"
                     "  for a class object:  its attributes, and recursively the attributes\n"
                     "    of its bases.\n"
                     "  for any other object: its attributes, its class's attributes, and\n"
                     "    recursively the attributes of its class's base classes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("divmod"),
                 ml_meth=ptr(builtin_divmod),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "divmod($module, x, y, /)\n"
                     "--\n"
                     "\n"
                     "Return the tuple (x//y, x%y).  Invariant: div*y + mod == x."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("eval"),
                 ml_meth=ptr(builtin_eval),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "eval($module, source, /, globals=None, locals=None)\n"
                     "--\n"
                     "\n"
                     "Evaluate the given source in the context of globals and locals.\n"
                     "\n"
                     "The source may be a string representing a Python expression\n"
                     "or a code object as returned by compile().\n"
                     "The globals must be a dictionary and locals can be any mapping,\n"
                     "defaulting to the current globals and locals.\n"
                     "If only globals is given, locals defaults to it."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exec"),
                 ml_meth=ptr(builtin_exec),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "exec($module, source, /, globals=None, locals=None, *, closure=None)\n"
                     "--\n"
                     "\n"
                     "Execute the given source in the context of globals and locals.\n"
                     "\n"
                     "The source may be a string representing one or more Python statements\n"
                     "or a code object as returned by compile().\n"
                     "The globals must be a dictionary and locals can be any mapping,\n"
                     "defaulting to the current globals and locals.\n"
                     "If only globals is given, locals defaults to it.\n"
                     "The closure must be a tuple of cellvars, and can only be used\n"
                     "when source is a code object requiring exactly that many cellvars."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("format"),
                 ml_meth=ptr(builtin_format),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "format($module, value, format_spec='', /)\n"
                     "--\n"
                     "\n"
                     "Return type(value).__format__(value, format_spec)\n"
                     "\n"
                     "Many built-in types implement format_spec according to the\n"
                     "Format Specification Mini-language. See help('FORMATTING').\n"
                     "\n"
                     "If type(value) does not supply a method named __format__\n"
                     "and format_spec is empty, then str(value) is returned.\n"
                     "See also help('SPECIALMETHODS')."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getattr"),
                 ml_meth=ptr(builtin_getattr),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "getattr(object, name[, default]) -> value\n"
                     "\n"
                     "Get a named attribute from an object.\n"
                     "\n"
                     "getattr(x, 'y') is equivalent to x.y.\n"
                     "When a default argument is given, it is returned when the attribute\n"
                     "doesn't exist; without it, an exception is raised in that case."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("globals"),
                 ml_meth=ptr(builtin_globals),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "globals($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the dictionary containing the current scope's global variables.\n"
                     "\n"
                     "NOTE: Updates to this dictionary *will* affect name lookups in the\n"
                     "current global scope and vice-versa."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hasattr"),
                 ml_meth=ptr(builtin_hasattr),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "hasattr($module, obj, name, /)\n"
                     "--\n"
                     "\n"
                     "Return whether the object has an attribute with the given name.\n"
                     "\n"
                     "This is done by calling getattr(obj, name) and catching AttributeError."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hash"),
                 ml_meth=ptr(builtin_hash),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "hash($module, obj, /)\n"
                     "--\n"
                     "\n"
                     "Return the integer hash value for the given object.\n"
                     "\n"
                     "Two objects that compare equal must also have the same hash value, but\n"
                     "the reverse is not necessarily true.  Hash values may differ between\n"
                     "Python processes.  Not all objects are hashable; calling hash() on an\n"
                     "unhashable object raises TypeError."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hex"),
                 ml_meth=ptr(builtin_hex),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "hex($module, number, /)\n"
                     "--\n"
                     "\n"
                     "Return the hexadecimal representation of an integer.\n"
                     "\n"
                     "   >>> hex(12648430)\n"
                     "   '0xc0ffee'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("id"),
                 ml_meth=ptr(builtin_id),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "id($module, obj, /)\n"
                     "--\n"
                     "\n"
                     "Return the identity of an object.\n"
                     "\n"
                     "This is guaranteed to be unique among simultaneously existing objects.\n"
                     "(CPython uses the object's memory address.)"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("input"),
                 ml_meth=ptr(builtin_input),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "input($module, prompt='', /)\n"
                     "--\n"
                     "\n"
                     "Read a string from standard input.  The trailing newline is stripped.\n"
                     "\n"
                     "The prompt string, if given, is printed to standard output without a\n"
                     "trailing newline before reading input.\n"
                     "\n"
                     "If the user hits EOF (*nix: Ctrl-D, Windows: Ctrl-Z+Return), raise\n"
                     "EOFError.\n"
                     "On *nix systems, readline is used if available."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isinstance"),
                 ml_meth=ptr(builtin_isinstance),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "isinstance($module, obj, class_or_tuple, /)\n"
                     "--\n"
                     "\n"
                     "Return whether an object is an instance of a class or of a subclass thereof.\n"
                     "\n"
                     "A tuple, as in ``isinstance(x, (A, B, ...))``, may be given as the\n"
                     "target to check against.  This is equivalent to ``isinstance(x, A) or\n"
                     "isinstance(x, B) or ...`` etc."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("issubclass"),
                 ml_meth=ptr(builtin_issubclass),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "issubclass($module, cls, class_or_tuple, /)\n"
                     "--\n"
                     "\n"
                     "Return whether 'cls' is derived from another class or is the same class.\n"
                     "\n"
                     "A tuple, as in ``issubclass(x, (A, B, ...))``, may be given as the\n"
                     "target to check against.  This is equivalent to ``issubclass(x, A) or\n"
                     "issubclass(x, B) or ...``."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("iter"),
                 ml_meth=ptr(builtin_iter),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "iter(iterable) -> iterator\n"
                     "iter(callable, sentinel) -> iterator\n"
                     "\n"
                     "Get an iterator from an object.  In the first form, the argument must\n"
                     "supply its own iterator, or be a sequence.\n"
                     "In the second form, the callable is called until it returns the\n"
                     "sentinel."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("aiter"),
                 ml_meth=ptr(builtin_aiter),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "aiter($module, async_iterable, /)\n"
                     "--\n"
                     "\n"
                     "Return an AsyncIterator for an AsyncIterable object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("len"),
                 ml_meth=ptr(builtin_len),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "len($module, obj, /)\n"
                     "--\n"
                     "\n"
                     "Return the number of items in a container."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("locals"),
                 ml_meth=ptr(builtin_locals),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "locals($module, /)\n"
                     "--\n"
                     "\n"
                     "Return a dictionary containing the current scope's local variables.\n"
                     "\n"
                     "NOTE: Whether or not updates to this dictionary will affect name\n"
                     "lookups in the local scope and vice-versa is *implementation\n"
                     "dependent* and not covered by any backwards compatibility\n"
                     "guarantees."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("max"),
                 ml_meth=ptr(builtin_max),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "max(iterable, *[, default=obj, key=func]) -> value\n"
                     "max(arg1, arg2, *args, *[, key=func]) -> value\n"
                     "\n"
                     "With a single iterable argument, return its biggest item. The\n"
                     "default keyword-only argument specifies an object to return if\n"
                     "the provided iterable is empty.\n"
                     "With two or more positional arguments, return the largest argument."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("min"),
                 ml_meth=ptr(builtin_min),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "min(iterable, *[, default=obj, key=func]) -> value\n"
                     "min(arg1, arg2, *args, *[, key=func]) -> value\n"
                     "\n"
                     "With a single iterable argument, return its smallest item. The\n"
                     "default keyword-only argument specifies an object to return if\n"
                     "the provided iterable is empty.\n"
                     "With two or more positional arguments, return the smallest argument."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next"),
                 ml_meth=ptr(builtin_next),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "next(iterator[, default])\n"
                     "\n"
                     "Return the next item from the iterator.  If default is given and the\n"
                     "iterator is exhausted, it is returned instead of raising StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("anext"),
                 ml_meth=ptr(builtin_anext),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "anext($module, aiterator, default=<unrepresentable>, /)\n"
                     "--\n"
                     "\n"
                     "Return the next item from the async iterator.\n"
                     "\n"
                     "If default is given and the async iterator is exhausted,\n"
                     "it is returned instead of raising StopAsyncIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("oct"),
                 ml_meth=ptr(builtin_oct),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "oct($module, number, /)\n"
                     "--\n"
                     "\n"
                     "Return the octal representation of an integer.\n"
                     "\n"
                     "   >>> oct(342391)\n"
                     "   '0o1234567'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ord"),
                 ml_meth=ptr(builtin_ord),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "ord($module, character, /)\n"
                     "--\n"
                     "\n"
                     "Return the ordinal value of a character.\n"
                     "\n"
                     "If the argument is a one-character string, return the Unicode code\n"
                     "point of that character.\n"
                     "\n"
                     "If the argument is a bytes or bytearray object of length 1, return its\n"
                     "single byte value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("pow"),
                 ml_meth=ptr(builtin_pow),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "pow($module, /, base, exp, mod=None)\n"
                     "--\n"
                     "\n"
                     "Equivalent to base**exp with 2 arguments or base**exp % mod with 3 arguments\n"
                     "\n"
                     "Some types, such as ints, are able to use a more efficient algorithm\n"
                     "when invoked using the three argument form."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("print"),
                 ml_meth=ptr(builtin_print),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "print($module, /, *args, sep=' ', end='\\n', file=None, flush=False)\n"
                     "--\n"
                     "\n"
                     "Prints the values to a stream, or to sys.stdout by default.\n"
                     "\n"
                     "  sep\n"
                     "    string inserted between values, default a space.\n"
                     "  end\n"
                     "    string appended after the last value, default a newline.\n"
                     "  file\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("repr"),
                 ml_meth=ptr(builtin_repr),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "repr($module, obj, /)\n"
                     "--\n"
                     "\n"
                     "Return the canonical string representation of the object.\n"
                     "\n"
                     "For many object types, including most builtins, eval(repr(obj)) == obj."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("round"),
                 ml_meth=ptr(builtin_round),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "round($module, /, number, ndigits=None)\n"
                     "--\n"
                     "\n"
                     "Round a number to a given precision in decimal digits.\n"
                     "\n"
                     "The return value is an integer if ndigits is omitted or None.\n"
                     "Otherwise the return value has the same type as the number.  ndigits\n"
                     "may be negative."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setattr"),
                 ml_meth=ptr(builtin_setattr),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "setattr($module, obj, name, value, /)\n"
                     "--\n"
                     "\n"
                     "Sets the named attribute on the given object to the specified value.\n"
                     "\n"
                     "setattr(x, 'y', v) is equivalent to ``x.y = v``"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("sorted"),
                 ml_meth=ptr(builtin_sorted),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "sorted($module, iterable, /, *, key=None, reverse=False)\n"
                     "--\n"
                     "\n"
                     "Return a new list containing all items from the iterable in ascending order.\n"
                     "\n"
                     "A custom key function can be supplied to customize the sort order, and the\n"
                     "reverse flag can be set to request the result in descending order."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("sum"),
                 ml_meth=ptr(builtin_sum),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "sum($module, iterable, /, start=0)\n"
                     "--\n"
                     "\n"
                     "Return the sum of a 'start' value (default: 0) plus an iterable of numbers\n"
                     "\n"
                     "When the iterable is empty, return the start value.\n"
                     "This function is intended specifically for use with numeric values and\n"
                     "may reject non-numeric types."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("vars"),
                 ml_meth=ptr(builtin_vars),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "vars([object]) -> dictionary\n"
                     "\n"
                     "Without arguments, equivalent to locals().\n"
                     "With an argument, equivalent to object.__dict__."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         builtinsmodule: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("builtins"),
             m_doc=ptr[u8](
                 "Built-in functions, types, exceptions, and other objects.\n"
                 "\n"
                 "This module provides direct access to all 'built-in'\n"
                 "identifiers of Python; for example, builtins.len is\n"
                 "the full name for the built-in function len().\n"
                 "\n"
                 "This module is not normally accessed explicitly by most\n"
                 "applications, but can be useful in modules that provide\n"
                 "objects with the same name as a built-in value, but in\n"
                 "which the built-in of that name is also needed."
             ),
             m_size=-1,
             m_methods=addressof(builtin_methods)
         ); glob PyFilter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("filter"),
             tp_basicsize=filterobject_SIZE,
             tp_dealloc=filter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "filter(function, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Return an iterator yielding those items of iterable for which\n"
                 "function(item) is true.  If function is None, return the items that\n"
                 "are true."
             ),
             tp_traverse=filter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=filter_next,
             tp_methods=addressof(filter_methods),
             tp_alloc=PyType_GenericAlloc,
             tp_new=filter_new,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=filter_vectorcall
         ),
         PyMap_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("map"),
             tp_basicsize=mapobject_SIZE,
             tp_dealloc=map_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "map(function, iterable, /, *iterables, strict=False)\n"
                 "--\n"
                 "\n"
                 "Make an iterator that computes the function using arguments from\n"
                 "each of the iterables.  Stops when the shortest iterable is exhausted.\n"
                 "\n"
                 "If strict is true and one of the arguments is exhausted before the\n"
                 "others, raise a ValueError."
             ),
             tp_traverse=map_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=map_next,
             tp_methods=addressof(map_methods),
             tp_alloc=PyType_GenericAlloc,
             tp_new=map_new,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=map_vectorcall
         ),
         PyZip_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("zip"),
             tp_basicsize=zipobject_SIZE,
             tp_dealloc=zip_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "zip(*iterables, strict=False)\n"
                 "--\n"
                 "\n"
                 "The zip object yields n-length tuples, where n is the number of\n"
                 "iterables passed as positional arguments to zip().  The i-th element\n"
                 "in every tuple comes from the i-th iterable argument to zip().  This\n"
                 "continues until the shortest argument is exhausted.\n"
                 "\n"
                 "If strict is true and one of the arguments is exhausted before the\n"
                 "others, raise a ValueError.\n"
                 "\n"
                 "   >>> list(zip('abcdefg', range(3), range(4)))\n"
                 "   [('a', 0, 0), ('b', 1, 1), ('c', 2, 2)]"
             ),
             tp_traverse=zip_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=zip_next,
             tp_methods=addressof(zip_methods),
             tp_alloc=PyType_GenericAlloc,
             tp_new=zip_new,
             tp_free=PyObject_GC_Del
         );
}

glob:priv PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     PY_SSIZE_T_MIN: Final[i64] = -0x7FFFFFFFFFFFFFFF - 1;

def arg_at(args: ptr[ptr[PyObject]], i: i64) -> ptr[PyObject];

def kwnames_size(kwnames: ptr[PyObject]) -> i64;

def unpack_keywords(
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject],
    parser: ptr[_PyArg_Parser],
    minpos: i32,
    maxpos: i32,
    minkw: i32,
    varpos: i32,
    buf: ptr[ptr[PyObject]]
) -> ptr[ptr[PyObject]];

def check_positional(nargs: i64, low: i64, high: i64) -> bool;

def set_compiler_flags(cf: ptr[u8], flags: i32);

def is_code(op: ptr[PyObject]) -> bool;

def code_nfree(op: ptr[PyObject]) -> i64;

def is_cell(op: ptr[PyObject]) -> bool;

def list_items(op: ptr[PyObject]) -> ptr[ptr[PyObject]];

def iter_next(it: ptr[PyObject]) -> ptr[PyObject];

def decref_float(op: ptr[PyObject]);

def update_bases(
    bases: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def build_class_done(
    cell: ptr[PyObject],
    ns: ptr[PyObject],
    meta: ptr[PyObject],
    mkw: ptr[PyObject],
    bases: ptr[PyObject],
    orig_bases: ptr[PyObject],
    cls: ptr[PyObject]
) -> ptr[PyObject];

def builtin___build_class__(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin___import___impl(
    module: ptr[PyObject],
    name: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    fromlist: ptr[PyObject],
    level: i32
) -> ptr[PyObject];

def builtin___import__(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_abs(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def builtin_all(module: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject];

def builtin_any(module: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject];

def builtin_ascii(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def builtin_bin(module: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject];

def builtin_callable(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def builtin_breakpoint(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, keywords: ptr[PyObject]
) -> ptr[PyObject];

def filter_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def filter_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def filter_dealloc(self_: ptr[PyObject]);

def filter_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def filter_next(self_: ptr[PyObject]) -> ptr[PyObject];

def filter_reduce(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def builtin_format_impl(
    module: ptr[PyObject], value: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject];

def builtin_format(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_chr(module: ptr[PyObject], i: ptr[PyObject]) -> ptr[PyObject];

def builtin_compile_impl(
    module: ptr[PyObject],
    source: ptr[PyObject],
    filename: ptr[PyObject],
    mode: ptr[u8],
    flags: i32,
    dont_inherit: i32,
    optimize: i32,
    feature_version: i32
) -> ptr[PyObject];

def builtin_compile(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def compile_done(
    filename_slot: ptr[ptr[PyObject]], result: ptr[PyObject]
) -> ptr[PyObject];

def builtin_dir(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def builtin_divmod_impl(
    module: ptr[PyObject], x: ptr[PyObject], y: ptr[PyObject]
) -> ptr[PyObject];

def builtin_divmod(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def eval_in(
    tstate: ptr[PyThreadState],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject]
) -> ptr[PyObject];

def builtin_eval_impl(
    module: ptr[PyObject],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject]
) -> ptr[PyObject];

def builtin_eval(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def exec_in(
    tstate: ptr[PyThreadState],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    closure: ptr[PyObject]
) -> ptr[PyObject];

def builtin_exec_impl(
    module: ptr[PyObject],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    closure: ptr[PyObject]
) -> ptr[PyObject];

def builtin_exec(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_getattr(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_globals_impl(module: ptr[PyObject]) -> ptr[PyObject];

def builtin_globals(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def builtin_hasattr_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def builtin_hasattr(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_id(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject];

def map_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def map_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def map_dealloc(self_: ptr[PyObject]);

def map_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def map_strict_check(iters: ptr[PyObject], i: i64, niters: i64);

def map_next(self_: ptr[PyObject]) -> ptr[PyObject];

def map_reduce(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def map_setstate(self_: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

def builtin_next(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_setattr_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    name: ptr[PyObject],
    value: ptr[PyObject]
) -> ptr[PyObject];

def builtin_setattr(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_delattr_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def builtin_delattr(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_hash(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def builtin_hex(module: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject];

def builtin_iter(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_aiter(
    module: ptr[PyObject], async_iterable: ptr[PyObject]
) -> ptr[PyObject];

def builtin_anext_impl(
    module: ptr[PyObject], aiterator: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def builtin_anext(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_len(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def builtin_locals_impl(module: ptr[PyObject]) -> ptr[PyObject];

def builtin_locals(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def min_max_fail(
    it: ptr[PyObject], maxitem: ptr[PyObject], maxval: ptr[PyObject]
) -> ptr[PyObject];

def min_max(
    args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject], op: i32
) -> ptr[PyObject];

def builtin_min(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_max(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_oct(module: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject];

def builtin_ord(module: ptr[PyObject], c: ptr[PyObject]) -> ptr[PyObject];

def builtin_pow_impl(
    module: ptr[PyObject],
    base_: ptr[PyObject],
    exp_: ptr[PyObject],
    mod_: ptr[PyObject]
) -> ptr[PyObject];

def builtin_pow(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_print_impl(
    module: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    args_length: i64,
    sep: ptr[PyObject],
    end: ptr[PyObject],
    file: ptr[PyObject],
    flush: i32
) -> ptr[PyObject];

def builtin_print(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def required_stream(id_offset: i64) -> ptr[PyObject];

def input_fail(
    fin: ptr[PyObject], fout: ptr[PyObject], ferr: ptr[PyObject]
) -> ptr[PyObject];

def call_fileno(stream: ptr[PyObject]) -> ptr[PyObject];

def readline_errors(
    tty: bool,
    stdin_encoding: ptr[PyObject],
    stdout_encoding: ptr[PyObject],
    stdin_errors: ptr[PyObject],
    stdout_errors: ptr[PyObject],
    po: ptr[PyObject]
) -> i32;

def input_tty(
    fin: ptr[PyObject], fout: ptr[PyObject], prompt: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def builtin_input_impl(module: ptr[PyObject], prompt: ptr[PyObject]) -> ptr[PyObject];

def builtin_input(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_repr(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def builtin_round_impl(
    module: ptr[PyObject], number: ptr[PyObject], ndigits: ptr[PyObject]
) -> ptr[PyObject];

def builtin_round(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_sorted(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_vars(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def cs_add(hi: f64, lo: f64, x: f64) -> tuple[f64, f64];

def cs_to_double(hi: f64, lo: f64) -> f64;

def sum_fail(item: ptr[PyObject], iter_obj: ptr[PyObject]) -> ptr[PyObject];

def builtin_sum_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject];

def builtin_sum(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def builtin_isinstance(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def builtin_issubclass(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def zip_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def zip_dealloc(self_: ptr[PyObject]);

def zip_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def zip_strict_check(ittuple: ptr[PyObject], i: i64, tuplesize: i64) -> ptr[PyObject];

def zip_next(self_: ptr[PyObject]) -> ptr[PyObject];

def zip_reduce(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def zip_setstate(self_: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

def set_builtin(dct: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]) -> bool;

def builtin_type(value: ptr[PyTypeObject]) -> ptr[PyObject];

import from c {
    def _PyBuiltin_Init(interp: ptr[u8]) -> ptr[PyObject] {
        config = _PyInterpreterState_GetConfig(interp);
        mod = _PyModule_CreateInitialized(
            ptr[PyModuleDef](addressof(builtinsmodule)), PYTHON_API_VERSION
        );
        if not mod {
            return NULL;
        }
        dct = PyModule_GetDict(mod);
        if not set_builtin(dct, ptr[u8]("None"), Py_None)
            or not set_builtin(dct, ptr[u8]("Ellipsis"), Py_Ellipsis)
            or not set_builtin(dct, ptr[u8]("NotImplemented"), Py_NotImplemented)
            or not set_builtin(dct, ptr[u8]("False"), py_false())
            or not set_builtin(dct, ptr[u8]("True"), py_true())
            or not set_builtin(
                dct, ptr[u8]("bool"), ptr[PyObject](addressof(PyBool_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("memoryview"), ptr[PyObject](addressof(PyMemoryView_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("bytearray"), ptr[PyObject](addressof(PyByteArray_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("bytes"), ptr[PyObject](addressof(PyBytes_Type))
            )
            or not set_builtin(
                dct,
                ptr[u8]("classmethod"),
                ptr[PyObject](addressof(PyClassMethod_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("complex"), ptr[PyObject](addressof(PyComplex_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("dict"), ptr[PyObject](addressof(PyDict_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("enumerate"), ptr[PyObject](addressof(PyEnum_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("filter"), builtin_type(addressof(PyFilter_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("float"), ptr[PyObject](addressof(PyFloat_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("frozenset"), ptr[PyObject](addressof(PyFrozenSet_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("property"), ptr[PyObject](addressof(PyProperty_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("int"), ptr[PyObject](addressof(PyLong_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("list"), ptr[PyObject](addressof(PyList_Type))
            )
            or not set_builtin(dct, ptr[u8]("map"), builtin_type(addressof(PyMap_Type)))
            or not set_builtin(
                dct, ptr[u8]("object"), ptr[PyObject](addressof(PyBaseObject_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("range"), ptr[PyObject](addressof(PyRange_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("reversed"), ptr[PyObject](addressof(PyReversed_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("set"), ptr[PyObject](addressof(PySet_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("slice"), ptr[PyObject](addressof(PySlice_Type))
            )
            or not set_builtin(
                dct,
                ptr[u8]("staticmethod"),
                ptr[PyObject](addressof(PyStaticMethod_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("str"), ptr[PyObject](addressof(PyUnicode_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("super"), ptr[PyObject](addressof(PySuper_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("tuple"), ptr[PyObject](addressof(PyTuple_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("type"), ptr[PyObject](addressof(PyType_Type))
            )
            or not set_builtin(
                dct, ptr[u8]("zip"), builtin_type(addressof(PyZip_Type))
            ) {
            return NULL;
        }
        level = ptr[i32](config + PyConfig_OPTIMIZATION_LEVEL).view(1)[0];
        debug_flag: i64 = 0;
        if level == 0 {
            debug_flag = 1;
        }
        debug = PyBool_FromLong(debug_flag);
        if PyDict_SetItemString(dct, ptr[u8]("__debug__"), debug) < 0 {
            object_decref(debug);
            return NULL;
        }
        object_decref(debug);
        return mod;
    }
}

impl arg_at(args: ptr[ptr[PyObject]], i: i64) -> ptr[PyObject] {
    return (args + i).view(1)[0];
}

impl kwnames_size(kwnames: ptr[PyObject]) -> i64 {
    if kwnames {
        return object_size(kwnames);
    }
    return 0;
}

impl unpack_keywords(
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject],
    parser: ptr[_PyArg_Parser],
    minpos: i32,
    maxpos: i32,
    minkw: i32,
    varpos: i32,
    buf: ptr[ptr[PyObject]]
) -> ptr[ptr[PyObject]] {
    if minkw == 0
        and not kwnames
        and i64(minpos) <= nargs
        and (varpos != 0 or nargs <= i64(maxpos))
        and args {
        return args;
    }
    return _PyArg_UnpackKeywords(
        args, nargs, NULL, kwnames, parser, minpos, maxpos, minkw, varpos, buf
    );
}

impl check_positional(nargs: i64, low: i64, high: i64) -> bool {
    return low <= nargs and nargs <= high;
}

impl set_compiler_flags(cf: ptr[u8], flags: i32) {
    ptr[i32](cf + PyCompilerFlags_CF_FLAGS).view(1)[0] = flags;
    ptr[i32](cf + PyCompilerFlags_CF_FEATURE_VERSION).view(1)[0] = PY_MINOR_VERSION;
}

impl is_code(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyCode_Type)));
}

impl code_nfree(op: ptr[PyObject]) -> i64 {
    return i64(ptr[i32](ptr[u8](op) + PyCodeObject_NFREEVARS).view(1)[0]);
}

impl is_cell(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyCell_Type)));
}

impl list_items(op: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[PyListObject](op).view(1)[0].ob_item;
}

impl iter_next(it: ptr[PyObject]) -> ptr[PyObject] {
    return object_type(it).view(1)[0].tp_iternext(it);
}

impl decref_float(op: ptr[PyObject]) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    if (full & 0x80000000) != 0 {
        return;
    }
    full = wrapping_sub(full, 1);
    header.view(1)[0].ob_refcnt_full = full;
    if (full & 0xFFFFFFFF) == 0 {
        reftracer_track(op, 1);
        _PyFloat_ExactDealloc(op);
    }
}

impl update_bases(
    bases: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    new_bases = NULL;
    for i in range(nargs) {
        base = arg_at(args, i);
        if type_check(base) {
            if new_bases {
                if PyList_Append(new_bases, base) < 0 {
                    object_xdecref(new_bases);
                    return NULL;
                }
            }
            continue;
        }
        meth = NULL;
        if PyObject_GetOptionalAttr(base, py_id(_Py_ID___mro_entries__), &mut meth)
            < 0 {
            object_xdecref(new_bases);
            return NULL;
        }
        if not meth {
            if new_bases {
                if PyList_Append(new_bases, base) < 0 {
                    object_xdecref(new_bases);
                    return NULL;
                }
            }
            continue;
        }
        new_base = PyObject_CallOneArg(meth, bases);
        object_decref(meth);
        if not new_base {
            object_xdecref(new_bases);
            return NULL;
        }
        if not tuple_check(new_base) {
            PyErr_SetString(PyExc_TypeError, "__mro_entries__ must return a tuple");
            object_decref(new_base);
            object_xdecref(new_bases);
            return NULL;
        }
        if not new_bases {
            new_bases = PyList_New(i);
            if not new_bases {
                object_decref(new_base);
                return NULL;
            }
            items = list_items(new_bases);
            for j in range(i) {
                (items + j).view(1)[0] = object_new_ref(arg_at(args, j));
            }
        }
        size = object_size(new_bases);
        if PyList_SetSlice(new_bases, size, size, new_base) < 0 {
            object_decref(new_base);
            object_xdecref(new_bases);
            return NULL;
        }
        object_decref(new_base);
    }
    if not new_bases {
        return bases;
    }
    result = PyList_AsTuple(new_bases);
    object_decref(new_bases);
    return result;
}

impl build_class_done(
    cell: ptr[PyObject],
    ns: ptr[PyObject],
    meta: ptr[PyObject],
    mkw: ptr[PyObject],
    bases: ptr[PyObject],
    orig_bases: ptr[PyObject],
    cls: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(cell);
    object_xdecref(ns);
    object_xdecref(meta);
    object_xdecref(mkw);
    if bases != orig_bases {
        object_decref(orig_bases);
    }
    object_decref(bases);
    return cls;
}

impl builtin___build_class__(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs < 2 {
        PyErr_SetString(PyExc_TypeError, "__build_class__: not enough arguments");
        return NULL;
    }
    func = arg_at(args, 0);
    if not object_is_type(func, ptr[PyTypeObject](addressof(PyFunction_Type))) {
        PyErr_SetString(PyExc_TypeError, "__build_class__: func must be a function");
        return NULL;
    }
    name = arg_at(args, 1);
    if not unicode_check(name) {
        PyErr_SetString(PyExc_TypeError, "__build_class__: name is not a string");
        return NULL;
    }
    orig_bases = _PyTuple_FromArray(args + 2, nargs - 2);
    if not orig_bases {
        return NULL;
    }
    bases = update_bases(orig_bases, args + 2, nargs - 2);
    if not bases {
        object_decref(orig_bases);
        return NULL;
    }
    scratch: own BuiltinStack = BuiltinStack();
    meta = NULL;
    mkw = NULL;
    isclass = False;
    if kwnames {
        mkw = _PyStack_AsDict(args + nargs, kwnames);
        if not mkw {
            return build_class_done(NULL, NULL, meta, mkw, bases, orig_bases, NULL);
        }
        if PyDict_Pop(mkw, py_id(_Py_ID_metaclass), &mut meta) < 0 {
            return build_class_done(NULL, NULL, meta, mkw, bases, orig_bases, NULL);
        }
        if meta {
            isclass = type_check(meta);
        }
    }
    if not meta {
        if object_size(bases) == 0 {
            meta = ptr[PyObject](addressof(PyType_Type));
        } else {
            meta = ptr[PyObject](object_type(tuple_get_item(bases, 0)));
        }
        object_incref(meta);
        isclass = True;
    }
    if isclass {
        winner = ptr[PyObject](
            _PyType_CalculateMetaclass(ptr[PyTypeObject](meta), bases)
        );
        if not winner {
            return build_class_done(NULL, NULL, meta, mkw, bases, orig_bases, NULL);
        }
        if winner != meta {
            old_meta = meta;
            meta = object_new_ref(winner);
            object_decref(old_meta);
        }
    }
    ns = NULL;
    prep = NULL;
    if PyObject_GetOptionalAttr(meta, py_id(_Py_ID___prepare__), &mut prep) < 0 {
        ns = NULL;
    } elif not prep {
        ns = PyDict_New();
    } else {
        pargs = ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch));
        pargs.view(1)[0] = name;
        (pargs + 1).view(1)[0] = bases;
        ns = PyObject_VectorcallDict(prep, pargs, 2, mkw);
        object_decref(prep);
    }
    if not ns {
        return build_class_done(NULL, ns, meta, mkw, bases, orig_bases, NULL);
    }
    if PyMapping_Check(ns) == 0 {
        meta_name = ptr[u8]("<metaclass>");
        if isclass {
            meta_name = ptr[PyTypeObject](meta).view(1)[0].tp_name;
        }
        PyErr_Format(
            PyExc_TypeError,
            "%.200s.__prepare__() must return a mapping, not %.200s",
            meta_name,
            object_type(ns).view(1)[0].tp_name
        );
        return build_class_done(NULL, ns, meta, mkw, bases, orig_bases, NULL);
    }
    tstate = thread_state();
    cell = _PyEval_Vector(tstate, func, ns, ptr[ptr[PyObject]](), 0, NULL);
    cls = NULL;
    if cell {
        if bases != orig_bases {
            if PyMapping_SetItemString(ns, ptr[u8]("__orig_bases__"), orig_bases) < 0 {
                return build_class_done(cell, ns, meta, mkw, bases, orig_bases, NULL);
            }
        }
        margs = ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch));
        margs.view(1)[0] = name;
        (margs + 1).view(1)[0] = bases;
        (margs + 2).view(1)[0] = ns;
        cls = PyObject_VectorcallDict(meta, margs, 3, mkw);
        if cls and type_check(cls) and is_cell(cell) {
            cell_cls = ptr[PyCellObject](cell).view(1)[0].ob_ref;
            if cell_cls {
                object_incref(cell_cls);
            }
            if cell_cls != cls {
                if not cell_cls {
                    PyErr_Format(
                        PyExc_RuntimeError,
                        "__class__ not set defining %.200R as %.200R. "
                        "Was __classcell__ propagated to type.__new__?",
                        name,
                        cls
                    );
                } else {
                    PyErr_Format(
                        PyExc_TypeError,
                        "__class__ set to %.200R defining %.200R as %.200R",
                        cell_cls,
                        name,
                        cls
                    );
                }
                object_xdecref(cell_cls);
                object_decref(cls);
                return build_class_done(cell, ns, meta, mkw, bases, orig_bases, NULL);
            }
            object_decref(cell_cls);
        }
    }
    return build_class_done(cell, ns, meta, mkw, bases, orig_bases, cls);
}

impl builtin___import___impl(
    module: ptr[PyObject],
    name: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    fromlist: ptr[PyObject],
    level: i32
) -> ptr[PyObject] {
    return PyImport_ImportModuleLevelObject(name, globals, locals, fromlist, level);
}

impl builtin___import__(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    noptargs = nargs + kwnames_size(kwnames) - 1;
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(import_parser),
        1,
        5,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
    );
    if not fast {
        return NULL;
    }
    name = arg_at(fast, 0);
    globals = NULL;
    locals = NULL;
    fromlist = NULL;
    level: i32 = 0;
    if noptargs > 0 {
        value = arg_at(fast, 1);
        if value {
            globals = value;
            noptargs -= 1;
        }
    }
    if noptargs > 0 {
        value = arg_at(fast, 2);
        if value {
            locals = value;
            noptargs -= 1;
        }
    }
    if noptargs > 0 {
        value = arg_at(fast, 3);
        if value {
            fromlist = value;
            noptargs -= 1;
        }
    }
    if noptargs > 0 {
        level = PyLong_AsInt(arg_at(fast, 4));
        if level == -1 and PyErr_Occurred() {
            return NULL;
        }
    }
    return builtin___import___impl(module, name, globals, locals, fromlist, level);
}

impl builtin_abs(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Absolute(x);
}

impl builtin_all(module: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    while True {
        item = iter_next(it);
        if not item {
            break;
        }
        cmp = PyObject_IsTrue(item);
        object_decref(item);
        if cmp < 0 {
            object_decref(it);
            return NULL;
        }
        if cmp == 0 {
            object_decref(it);
            return PyBool_FromLong(0);
        }
    }
    object_decref(it);
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
            PyErr_Clear();
        } else {
            return NULL;
        }
    }
    return PyBool_FromLong(1);
}

impl builtin_any(module: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    it = PyObject_GetIter(iterable);
    if not it {
        return NULL;
    }
    while True {
        item = iter_next(it);
        if not item {
            break;
        }
        cmp = PyObject_IsTrue(item);
        object_decref(item);
        if cmp < 0 {
            object_decref(it);
            return NULL;
        }
        if cmp > 0 {
            object_decref(it);
            return PyBool_FromLong(1);
        }
    }
    object_decref(it);
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
            PyErr_Clear();
        } else {
            return NULL;
        }
    }
    return PyBool_FromLong(0);
}

impl builtin_ascii(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_ASCII(obj_);
}

impl builtin_bin(module: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_ToBase(number, 2);
}

impl builtin_callable(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(PyCallable_Check(obj_)));
}

impl builtin_breakpoint(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, keywords: ptr[PyObject]
) -> ptr[PyObject] {
    hook = _PySys_GetRequiredAttrString(ptr[u8]("breakpointhook"));
    if not hook {
        return NULL;
    }
    if PySys_Audit("builtins.breakpoint", "O", hook) < 0 {
        object_decref(hook);
        return NULL;
    }
    retval = PyObject_Vectorcall(hook, args, u64(nargs), keywords);
    object_decref(hook);
    return retval;
}

impl filter_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    base_tp = addressof(PyFilter_Type);
    if (
        type == base_tp
        or int(type.view(1)[0].tp_init) == int(base_tp.view(1)[0].tp_init)
    )
        and kwds
        and _PyArg_NoKeywords(ptr[u8]("filter"), kwds) == 0 {
        return NULL;
    }
    func = NULL;
    seq = NULL;
    if PyArg_UnpackTuple(args, ptr[u8]("filter"), 2, 2, &mut func, &mut seq) == 0 {
        return NULL;
    }
    it = PyObject_GetIter(seq);
    if not it {
        return NULL;
    }
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = ptr[filterobject](op);
    lz.view(1)[0].func = object_new_ref(func);
    lz.view(1)[0].it = it;
    return op;
}

impl filter_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    tp = ptr[PyTypeObject](type);
    if tp == addressof(PyFilter_Type)
        and kwnames
        and _PyArg_NoKwnames(ptr[u8]("filter"), kwnames) == 0 {
        return NULL;
    }
    nargs = vectorcall_nargs(nargsf);
    if not check_positional(nargs, 2, 2)
        and _PyArg_CheckPositional(ptr[u8]("filter"), nargs, 2, 2) == 0 {
        return NULL;
    }
    it = PyObject_GetIter(arg_at(args, 1));
    if not it {
        return NULL;
    }
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(it);
        return NULL;
    }
    lz = ptr[filterobject](op);
    lz.view(1)[0].func = object_new_ref(arg_at(args, 0));
    lz.view(1)[0].it = it;
    return op;
}

impl filter_dealloc(self_: ptr[PyObject]) {
    lz = ptr[filterobject](self_);
    object_gc_untrack(self_);
    object_xdecref(lz.view(1)[0].func);
    object_xdecref(lz.view(1)[0].it);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl filter_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = ptr[filterobject](self_);
    status = visit_reference(lz.view(1)[0].it, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].func, visitor, arg);
}

impl filter_next(self_: ptr[PyObject]) -> ptr[PyObject] {
    lz = ptr[filterobject](self_);
    it = lz.view(1)[0].it;
    func = lz.view(1)[0].func;
    checktrue = func == Py_None or func == ptr[PyObject](addressof(PyBool_Type));
    tp = object_type(it);
    while True {
        item = tp.view(1)[0].tp_iternext(it);
        if not item {
            return NULL;
        }
        ok: i32 = 0;
        if checktrue {
            ok = PyObject_IsTrue(item);
        } else {
            good = PyObject_CallOneArg(func, item);
            if not good {
                object_decref(item);
                return NULL;
            }
            ok = PyObject_IsTrue(good);
            object_decref(good);
        }
        if ok > 0 {
            return item;
        }
        object_decref(item);
        if ok < 0 {
            return NULL;
        }
    }
    return NULL;
}

impl filter_reduce(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    lz = ptr[filterobject](self_);
    return Py_BuildValue(
        ptr[u8]("O(OO)"), ptr[PyObject](object_type(self_)), lz.view(1)[0].func, lz.view(1)[0].it
    );
}

impl builtin_format_impl(
    module: ptr[PyObject], value: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject] {
    return PyObject_Format(value, format_spec);
}

impl builtin_format(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 1, 2)
        and _PyArg_CheckPositional(ptr[u8]("format"), nargs, 1, 2) == 0 {
        return NULL;
    }
    value = arg_at(args, 0);
    format_spec = NULL;
    if nargs >= 2 {
        spec = arg_at(args, 1);
        if not unicode_check(spec) {
            _PyArg_BadArgument(ptr[u8]("format"), ptr[u8]("argument 2"), ptr[u8]("str"), spec);
            return NULL;
        }
        format_spec = spec;
    }
    return builtin_format_impl(module, value, format_spec);
}

impl builtin_chr(module: ptr[PyObject], i: ptr[PyObject]) -> ptr[PyObject] {
    overflow: i32 = 0;
    v = PyLong_AsLongAndOverflow(i, &mut overflow);
    if v == -1 and PyErr_Occurred() {
        return NULL;
    }
    if overflow != 0 {
        if overflow < 0 {
            v = -2147483648;
        } else {
            v = 2147483647;
        }
    } elif v < -2147483648 {
        v = -2147483648;
    } elif v > 2147483647 {
        v = 2147483647;
    }
    return PyUnicode_FromOrdinal(i32(v));
}

impl builtin_compile_impl(
    module: ptr[PyObject],
    source: ptr[PyObject],
    filename: ptr[PyObject],
    mode: ptr[u8],
    flags: i32,
    dont_inherit: i32,
    optimize: i32,
    feature_version: i32
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    cf = ptr[u8](ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch)));
    set_compiler_flags(cf, flags | PyCF_SOURCE_IS_UTF8);
    if feature_version >= 0 and (flags & PyCF_ONLY_AST) != 0 {
        ptr[i32](cf + PyCompilerFlags_CF_FEATURE_VERSION).view(1)[0] = feature_version;
    }
    if (flags & ~(PyCF_MASK | PyCF_MASK_OBSOLETE | PyCF_COMPILE_MASK)) != 0 {
        PyErr_SetString(PyExc_ValueError, "compile(): unrecognised flags");
        return NULL;
    }
    if optimize < -1 or optimize > 2 {
        PyErr_SetString(PyExc_ValueError, "compile(): invalid optimize value");
        return NULL;
    }
    flags_ptr = ptr[PyCompilerFlags](cf);
    if dont_inherit == 0 {
        PyEval_MergeCompilerFlags(flags_ptr);
    }
    start: i32 = 0;
    if strcmp(mode, ptr[u8]("exec")) == 0 {
        start = Py_file_input;
    } elif strcmp(mode, ptr[u8]("eval")) == 0 {
        start = Py_eval_input;
    } elif strcmp(mode, ptr[u8]("single")) == 0 {
        start = Py_single_input;
    } elif strcmp(mode, ptr[u8]("func_type")) == 0 {
        if (flags & PyCF_ONLY_AST) == 0 {
            PyErr_SetString(
                PyExc_ValueError,
                "compile() mode 'func_type' requires flag PyCF_ONLY_AST"
            );
            return NULL;
        }
        start = Py_func_type_input;
    } else {
        if (flags & PyCF_ONLY_AST) != 0 {
            PyErr_SetString(
                PyExc_ValueError,
                "compile() mode must be 'exec', 'eval', 'single' or 'func_type'"
            );
        } else {
            PyErr_SetString(
                PyExc_ValueError, "compile() mode must be 'exec', 'eval' or 'single'"
            );
        }
        return NULL;
    }
    is_ast = PyAST_Check(source);
    if is_ast == -1 {
        return NULL;
    }
    if is_ast != 0 {
        return _PyJac_CompileObject(source, filename, start, flags_ptr, optimize);
    }
    source_copy = NULL;
    text = _Py_SourceAsString(
        source,
        ptr[u8]("compile"),
        ptr[u8]("string, bytes or AST"),
        flags_ptr,
        &mut source_copy
    );
    if not text {
        return NULL;
    }
    result = Py_CompileStringObject(text, filename, start, flags_ptr, optimize);
    object_xdecref(source_copy);
    return result;
}

impl builtin_compile(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    slots = ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch));
    noptargs = nargs + kwnames_size(kwnames) - 3;
    fast = unpack_keywords(
        args, nargs, kwnames, addressof(compile_parser), 3, 6, 0, 0, slots
    );
    if not fast {
        return NULL;
    }
    source = arg_at(fast, 0);
    filename_slot = slots + 7;
    if PyUnicode_FSDecoder(arg_at(fast, 1), ptr(filename_slot)) == 0 {
        return compile_done(filename_slot, NULL);
    }
    mode_obj = arg_at(fast, 2);
    if not unicode_check(mode_obj) {
        _PyArg_BadArgument(ptr[u8]("compile"), ptr[u8]("argument 'mode'"), ptr[u8]("str"), mode_obj);
        return compile_done(filename_slot, NULL);
    }
    mode_length: i64 = 0;
    mode = PyUnicode_AsUTF8AndSize(mode_obj, &mut mode_length);
    if not mode {
        return compile_done(filename_slot, NULL);
    }
    if strlen(mode) != u64(mode_length) {
        PyErr_SetString(PyExc_ValueError, "embedded null character");
        return compile_done(filename_slot, NULL);
    }
    flags: i32 = 0;
    dont_inherit: i32 = 0;
    optimize: i32 = -1;
    feature_version: i32 = -1;
    positional_done = noptargs <= 0;
    if not positional_done {
        value = arg_at(fast, 3);
        if value {
            flags = PyLong_AsInt(value);
            if flags == -1 and PyErr_Occurred() {
                return compile_done(filename_slot, NULL);
            }
            noptargs -= 1;
            positional_done = noptargs == 0;
        }
    }
    if not positional_done {
        value = arg_at(fast, 4);
        if value {
            dont_inherit = PyObject_IsTrue(value);
            if dont_inherit < 0 {
                return compile_done(filename_slot, NULL);
            }
            noptargs -= 1;
            positional_done = noptargs == 0;
        }
    }
    if not positional_done {
        value = arg_at(fast, 5);
        if value {
            optimize = PyLong_AsInt(value);
            if optimize == -1 and PyErr_Occurred() {
                return compile_done(filename_slot, NULL);
            }
            noptargs -= 1;
        }
    }
    if noptargs > 0 {
        feature_version = PyLong_AsInt(arg_at(fast, 6));
        if feature_version == -1 and PyErr_Occurred() {
            return compile_done(filename_slot, NULL);
        }
    }
    result = builtin_compile_impl(
        module,
        source,
        filename_slot.view(1)[0],
        mode,
        flags,
        dont_inherit,
        optimize,
        feature_version
    );
    return compile_done(filename_slot, result);
}

impl compile_done(
    filename_slot: ptr[ptr[PyObject]], result: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(filename_slot.view(1)[0]);
    return result;
}

impl builtin_dir(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    arg = NULL;
    if PyArg_UnpackTuple(args, ptr[u8]("dir"), 0, 1, &mut arg) == 0 {
        return NULL;
    }
    return PyObject_Dir(arg);
}

impl builtin_divmod_impl(
    module: ptr[PyObject], x: ptr[PyObject], y: ptr[PyObject]
) -> ptr[PyObject] {
    return PyNumber_Divmod(x, y);
}

impl builtin_divmod(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 2, 2)
        and _PyArg_CheckPositional(ptr[u8]("divmod"), nargs, 2, 2) == 0 {
        return NULL;
    }
    return builtin_divmod_impl(module, arg_at(args, 0), arg_at(args, 1));
}

impl eval_in(
    tstate: ptr[PyThreadState],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject]
) -> ptr[PyObject] {
    if _PyEval_EnsureBuiltins(tstate, globals, ptr[ptr[PyObject]]()) < 0 {
        return NULL;
    }
    if is_code(source) {
        if PySys_Audit("exec", "O", source) < 0 {
            return NULL;
        }
        if code_nfree(source) > 0 {
            PyErr_SetString(
                PyExc_TypeError,
                "code object passed to eval() may not contain free variables"
            );
            return NULL;
        }
        return PyEval_EvalCode(source, globals, locals);
    }
    scratch: own BuiltinStack = BuiltinStack();
    cf = ptr[u8](ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch)));
    set_compiler_flags(cf, PyCF_SOURCE_IS_UTF8);
    flags_ptr = ptr[PyCompilerFlags](cf);
    source_copy = NULL;
    text = _Py_SourceAsString(
        source,
        ptr[u8]("eval"),
        ptr[u8]("string, bytes or code"),
        flags_ptr,
        &mut source_copy
    );
    if not text {
        return NULL;
    }
    while text.view(1)[0] == u8(32) or text.view(1)[0] == u8(9) {
        text = text + 1;
    }
    PyEval_MergeCompilerFlags(flags_ptr);
    result = PyRun_StringFlags(text, Py_eval_input, globals, locals, flags_ptr);
    object_xdecref(source_copy);
    return result;
}

impl builtin_eval_impl(
    module: ptr[PyObject],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    if locals != Py_None and PyMapping_Check(locals) == 0 {
        PyErr_SetString(PyExc_TypeError, "locals must be a mapping");
        return NULL;
    }
    if globals != Py_None and not dict_check(globals) {
        if PyMapping_Check(globals) != 0 {
            PyErr_SetString(
                PyExc_TypeError,
                "globals must be a real dict; try eval(expr, {}, mapping)"
            );
        } else {
            PyErr_SetString(PyExc_TypeError, "globals must be a dict");
        }
        return NULL;
    }
    fromframe = False;
    if globals != Py_None {
        object_incref(globals);
    } elif _PyEval_GetFrame() {
        fromframe = True;
        globals = PyEval_GetGlobals();
        object_incref(globals);
    } else {
        globals = _PyEval_GetGlobalsFromRunningMain(tstate);
        if not globals {
            if not exception_raised(tstate) {
                PyErr_SetString(
                    PyExc_TypeError,
                    "eval must be given globals and locals when called without a frame"
                );
            }
            return NULL;
        }
        object_incref(globals);
    }
    if locals != Py_None {
        object_incref(locals);
    } elif fromframe {
        locals = _PyEval_GetFrameLocals();
        if not locals {
            object_decref(globals);
            return NULL;
        }
    } else {
        locals = object_new_ref(globals);
    }
    result = eval_in(tstate, source, globals, locals);
    object_xdecref(globals);
    object_xdecref(locals);
    return result;
}

impl builtin_eval(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    noptargs = nargs + kwnames_size(kwnames) - 1;
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(eval_parser),
        1,
        3,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
    );
    if not fast {
        return NULL;
    }
    source = arg_at(fast, 0);
    globals = Py_None;
    locals = Py_None;
    if noptargs > 0 {
        value = arg_at(fast, 1);
        if value {
            globals = value;
            noptargs -= 1;
        }
    }
    if noptargs > 0 {
        locals = arg_at(fast, 2);
    }
    return builtin_eval_impl(module, source, globals, locals);
}

impl exec_in(
    tstate: ptr[PyThreadState],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    closure: ptr[PyObject]
) -> ptr[PyObject] {
    if not dict_check(globals) {
        PyErr_Format(
            PyExc_TypeError,
            "exec() globals must be a dict, not %.100s",
            object_type(globals).view(1)[0].tp_name
        );
        return NULL;
    }
    if PyMapping_Check(locals) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "locals must be a mapping or None, not %.100s",
            object_type(locals).view(1)[0].tp_name
        );
        return NULL;
    }
    if _PyEval_EnsureBuiltins(tstate, globals, ptr[ptr[PyObject]]()) < 0 {
        return NULL;
    }
    if closure == Py_None {
        closure = NULL;
    }
    if is_code(source) {
        num_free = code_nfree(source);
        if num_free == 0 {
            if closure {
                PyErr_SetString(
                    PyExc_TypeError, "cannot use a closure with this code object"
                );
                return NULL;
            }
        } else {
            closure_is_ok = False;
            if closure
                and tuple_check_exact(closure)
                and object_size(closure) == num_free {
                closure_is_ok = True;
            }
            if closure_is_ok {
                for i in range(num_free) {
                    if not is_cell(tuple_get_item(closure, i)) {
                        closure_is_ok = False;
                        break;
                    }
                }
            }
            if not closure_is_ok {
                PyErr_Format(
                    PyExc_TypeError,
                    "code object requires a closure of exactly length %zd",
                    num_free
                );
                return NULL;
            }
        }
        if PySys_Audit("exec", "O", source) < 0 {
            return NULL;
        }
        if not closure {
            return PyEval_EvalCode(source, globals, locals);
        }
        return PyEval_EvalCodeEx(
            source,
            globals,
            locals,
            ptr[ptr[PyObject]](),
            0,
            ptr[ptr[PyObject]](),
            0,
            ptr[ptr[PyObject]](),
            0,
            NULL,
            closure
        );
    }
    if closure {
        PyErr_SetString(
            PyExc_TypeError, "closure can only be used when source is a code object"
        );
        return NULL;
    }
    scratch: own BuiltinStack = BuiltinStack();
    cf = ptr[u8](ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch)));
    set_compiler_flags(cf, PyCF_SOURCE_IS_UTF8);
    flags_ptr = ptr[PyCompilerFlags](cf);
    source_copy = NULL;
    text = _Py_SourceAsString(
        source,
        ptr[u8]("exec"),
        ptr[u8]("string, bytes or code"),
        flags_ptr,
        &mut source_copy
    );
    if not text {
        return NULL;
    }
    v = NULL;
    if PyEval_MergeCompilerFlags(flags_ptr) != 0 {
        v = PyRun_StringFlags(text, Py_file_input, globals, locals, flags_ptr);
    } else {
        v = PyRun_StringFlags(
            text, Py_file_input, globals, locals, ptr[PyCompilerFlags]()
        );
    }
    object_xdecref(source_copy);
    return v;
}

impl builtin_exec_impl(
    module: ptr[PyObject],
    source: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    closure: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    fromframe = False;
    if globals != Py_None {
        object_incref(globals);
    } elif _PyEval_GetFrame() {
        fromframe = True;
        globals = PyEval_GetGlobals();
        object_incref(globals);
    } else {
        globals = _PyEval_GetGlobalsFromRunningMain(tstate);
        if not globals {
            if not exception_raised(tstate) {
                PyErr_SetString(PyExc_SystemError, "globals and locals cannot be NULL");
            }
            return NULL;
        }
        object_incref(globals);
    }
    if locals != Py_None {
        object_incref(locals);
    } elif fromframe {
        locals = _PyEval_GetFrameLocals();
        if not locals {
            object_decref(globals);
            return NULL;
        }
    } else {
        locals = object_new_ref(globals);
    }
    v = exec_in(tstate, source, globals, locals, closure);
    if not v {
        object_xdecref(globals);
        object_xdecref(locals);
        return NULL;
    }
    object_decref(globals);
    object_decref(locals);
    object_decref(v);
    return object_new_ref(Py_None);
}

impl builtin_exec(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    noptargs = nargs + kwnames_size(kwnames) - 1;
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(exec_parser),
        1,
        3,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
    );
    if not fast {
        return NULL;
    }
    source = arg_at(fast, 0);
    globals = Py_None;
    locals = Py_None;
    closure = NULL;
    positional_done = noptargs <= 0;
    if not positional_done {
        value = arg_at(fast, 1);
        if value {
            globals = value;
            noptargs -= 1;
            positional_done = noptargs == 0;
        }
    }
    if not positional_done {
        value = arg_at(fast, 2);
        if value {
            locals = value;
            noptargs -= 1;
        }
    }
    if noptargs > 0 {
        closure = arg_at(fast, 3);
    }
    return builtin_exec_impl(module, source, globals, locals, closure);
}

impl builtin_getattr(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 2, 3)
        and _PyArg_CheckPositional(ptr[u8]("getattr"), nargs, 2, 3) == 0 {
        return NULL;
    }
    v = arg_at(args, 0);
    name = arg_at(args, 1);
    result = NULL;
    if nargs > 2 {
        if PyObject_GetOptionalAttr(v, name, &mut result) == 0 {
            return object_new_ref(arg_at(args, 2));
        }
    } else {
        result = PyObject_GetAttr(v, name);
    }
    return result;
}

impl builtin_globals_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if _PyEval_GetFrame() {
        return object_new_ref(PyEval_GetGlobals());
    }
    tstate = thread_state();
    globals = _PyEval_GetGlobalsFromRunningMain(tstate);
    if not globals {
        if exception_raised(tstate) {
            return NULL;
        }
        return object_new_ref(Py_None);
    }
    return object_new_ref(globals);
}

impl builtin_globals(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return builtin_globals_impl(module);
}

impl builtin_hasattr_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    v = NULL;
    if PyObject_GetOptionalAttr(obj_, name, &mut v) < 0 {
        return NULL;
    }
    if not v {
        return PyBool_FromLong(0);
    }
    object_decref(v);
    return PyBool_FromLong(1);
}

impl builtin_hasattr(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 2, 2)
        and _PyArg_CheckPositional(ptr[u8]("hasattr"), nargs, 2, 2) == 0 {
        return NULL;
    }
    return builtin_hasattr_impl(module, arg_at(args, 0), arg_at(args, 1));
}

impl builtin_id(self_: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    id_obj = PyLong_FromVoidPtr(ptr(v));
    if id_obj and PySys_Audit("builtins.id", "O", id_obj) < 0 {
        object_decref(id_obj);
        return NULL;
    }
    return id_obj;
}

impl map_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    strict: i32 = 0;
    if kwds {
        empty = PyTuple_New(0);
        if not empty {
            return NULL;
        }
        parsed = PyArg_ParseTupleAndKeywords(
            empty, kwds, ptr[u8]("|$p:map"), ptr(addressof(map_kwlist)), &mut strict
        );
        object_decref(empty);
        if parsed == 0 {
            return NULL;
        }
    }
    numargs = PyTuple_Size(args);
    if numargs < 2 {
        PyErr_SetString(PyExc_TypeError, "map() must have at least two arguments.");
        return NULL;
    }
    iters = PyTuple_New(numargs - 1);
    if not iters {
        return NULL;
    }
    for i in range(1, numargs) {
        it = PyObject_GetIter(tuple_get_item(args, i));
        if not it {
            object_decref(iters);
            return NULL;
        }
        tuple_set_item(iters, i - 1, it);
    }
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        object_decref(iters);
        return NULL;
    }
    lz = ptr[mapobject](op);
    lz.view(1)[0].iters = iters;
    lz.view(1)[0].func = object_new_ref(tuple_get_item(args, 0));
    lz.view(1)[0].strict = strict;
    return op;
}

impl map_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    tp = ptr[PyTypeObject](type);
    nargs = vectorcall_nargs(nargsf);
    if kwnames and object_size(kwnames) != 0 {
        return _PyObject_MakeTpCall(thread_state(), type, args, nargs, kwnames);
    }
    if nargs < 2 {
        PyErr_SetString(PyExc_TypeError, "map() must have at least two arguments.");
        return NULL;
    }
    iters = PyTuple_New(nargs - 1);
    if not iters {
        return NULL;
    }
    for i in range(1, nargs) {
        it = PyObject_GetIter(arg_at(args, i));
        if not it {
            object_decref(iters);
            return NULL;
        }
        tuple_set_item(iters, i - 1, it);
    }
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        object_decref(iters);
        return NULL;
    }
    lz = ptr[mapobject](op);
    lz.view(1)[0].iters = iters;
    lz.view(1)[0].func = object_new_ref(arg_at(args, 0));
    lz.view(1)[0].strict = 0;
    return op;
}

impl map_dealloc(self_: ptr[PyObject]) {
    lz = ptr[mapobject](self_);
    object_gc_untrack(self_);
    object_xdecref(lz.view(1)[0].iters);
    object_xdecref(lz.view(1)[0].func);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl map_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = ptr[mapobject](self_);
    status = visit_reference(lz.view(1)[0].iters, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].func, visitor, arg);
}

impl map_strict_check(iters: ptr[PyObject], i: i64, niters: i64) {
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
            return;
        }
        PyErr_Clear();
    }
    if i != 0 {
        plural = ptr[u8](" ") if i == 1 else ptr[u8]("s 1-");
        PyErr_Format(
            PyExc_ValueError,
            "map() argument %zd is shorter than argument%s%zd",
            i + 1,
            plural,
            i
        );
        return;
    }
    j: i64 = 1;
    while j < niters {
        val = iter_next(tuple_get_item(iters, j));
        if val {
            object_decref(val);
            plural = ptr[u8](" ") if j == 1 else ptr[u8]("s 1-");
            PyErr_Format(
                PyExc_ValueError,
                "map() argument %zd is longer than argument%s%zd",
                j + 1,
                plural,
                j
            );
            return;
        }
        if PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
                return;
            }
            PyErr_Clear();
        }
        j += 1;
    }
}

impl map_next(self_: ptr[PyObject]) -> ptr[PyObject] {
    lz = ptr[mapobject](self_);
    tstate = thread_state();
    iters = lz.view(1)[0].iters;
    niters = object_size(iters);
    scratch: own BuiltinStack = BuiltinStack();
    small_stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch));
    stack = small_stack;
    if niters > _PY_FASTCALL_SMALL_STACK {
        stack = ptr[ptr[PyObject]](PyMem_Malloc(u64(niters) * u64(8)));
        if not stack {
            _PyErr_NoMemory(ptr(tstate));
            return NULL;
        }
    }
    nargs: i64 = 0;
    result = NULL;
    exhausted = False;
    while nargs < niters {
        val = iter_next(tuple_get_item(iters, nargs));
        if not val {
            exhausted = True;
            break;
        }
        (stack + nargs).view(1)[0] = val;
        nargs += 1;
    }
    if not exhausted {
        result = vectorcall_tstate(tstate, lz.view(1)[0].func, stack, u64(nargs), NULL);
    } elif lz.view(1)[0].strict != 0 {
        map_strict_check(iters, nargs, niters);
    }
    for i in range(nargs) {
        object_decref((stack + i).view(1)[0]);
    }
    if stack != small_stack {
        PyMem_Free(ptr(stack));
    }
    return result;
}

impl map_reduce(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    lz = ptr[mapobject](self_);
    iters = lz.view(1)[0].iters;
    numargs = object_size(iters);
    args = PyTuple_New(numargs + 1);
    if not args {
        return NULL;
    }
    tuple_set_item(args, 0, object_new_ref(lz.view(1)[0].func));
    for i in range(numargs) {
        tuple_set_item(args, i + 1, object_new_ref(tuple_get_item(iters, i)));
    }
    if lz.view(1)[0].strict != 0 {
        return Py_BuildValue(ptr[u8]("ONO"), ptr[PyObject](object_type(self_)), args, py_true());
    }
    return Py_BuildValue(ptr[u8]("ON"), ptr[PyObject](object_type(self_)), args);
}

impl map_setstate(self_: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    strict = PyObject_IsTrue(state);
    if strict < 0 {
        return NULL;
    }
    ptr[mapobject](self_).view(1)[0].strict = strict;
    return object_new_ref(Py_None);
}

impl builtin_next(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 1, 2)
        and _PyArg_CheckPositional(ptr[u8]("next"), nargs, 1, 2) == 0 {
        return NULL;
    }
    it = arg_at(args, 0);
    if PyIter_Check(it) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' object is not an iterator",
            object_type(it).view(1)[0].tp_name
        );
        return NULL;
    }
    res = iter_next(it);
    if res {
        return res;
    }
    if nargs > 1 {
        if PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
                return NULL;
            }
            PyErr_Clear();
        }
        return object_new_ref(arg_at(args, 1));
    }
    if PyErr_Occurred() {
        return NULL;
    }
    PyErr_SetNone(PyExc_StopIteration);
    return NULL;
}

impl builtin_setattr_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    name: ptr[PyObject],
    value: ptr[PyObject]
) -> ptr[PyObject] {
    if PyObject_SetAttr(obj_, name, value) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl builtin_setattr(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 3, 3)
        and _PyArg_CheckPositional(ptr[u8]("setattr"), nargs, 3, 3) == 0 {
        return NULL;
    }
    return builtin_setattr_impl(
        module, arg_at(args, 0), arg_at(args, 1), arg_at(args, 2)
    );
}

impl builtin_delattr_impl(
    module: ptr[PyObject], obj_: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    if PyObject_DelAttr(obj_, name) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl builtin_delattr(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 2, 2)
        and _PyArg_CheckPositional(ptr[u8]("delattr"), nargs, 2, 2) == 0 {
        return NULL;
    }
    return builtin_delattr_impl(module, arg_at(args, 0), arg_at(args, 1));
}

impl builtin_hash(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    x = PyObject_Hash(obj_);
    if x == -1 {
        return NULL;
    }
    return PyLong_FromSsize_t(x);
}

impl builtin_hex(module: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_ToBase(number, 16);
}

impl builtin_iter(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 1, 2)
        and _PyArg_CheckPositional(ptr[u8]("iter"), nargs, 1, 2) == 0 {
        return NULL;
    }
    v = arg_at(args, 0);
    if nargs == 1 {
        return PyObject_GetIter(v);
    }
    if PyCallable_Check(v) == 0 {
        PyErr_SetString(PyExc_TypeError, "iter(v, w): v must be callable");
        return NULL;
    }
    return PyCallIter_New(v, arg_at(args, 1));
}

impl builtin_aiter(
    module: ptr[PyObject], async_iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return PyObject_GetAIter(async_iterable);
}

impl builtin_anext_impl(
    module: ptr[PyObject], aiterator: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    t = object_type(aiterator);
    am = t.view(1)[0].tp_as_async;
    if not am or int(am.view(1)[0].am_anext) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' object is not an async iterator",
            t.view(1)[0].tp_name
        );
        return NULL;
    }
    awaitable = am.view(1)[0].am_anext(aiterator);
    if not awaitable {
        return NULL;
    }
    if not default_value {
        return awaitable;
    }
    new_awaitable = PyAnextAwaitable_New(awaitable, default_value);
    object_decref(awaitable);
    return new_awaitable;
}

impl builtin_anext(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 1, 2)
        and _PyArg_CheckPositional(ptr[u8]("anext"), nargs, 1, 2) == 0 {
        return NULL;
    }
    default_value = NULL;
    if nargs >= 2 {
        default_value = arg_at(args, 1);
    }
    return builtin_anext_impl(module, arg_at(args, 0), default_value);
}

impl builtin_len(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    res = PyObject_Size(obj_);
    if res < 0 {
        return NULL;
    }
    return PyLong_FromSsize_t(res);
}

impl builtin_locals_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if _PyEval_GetFrame() {
        return _PyEval_GetFrameLocals();
    }
    tstate = thread_state();
    locals = _PyEval_GetGlobalsFromRunningMain(tstate);
    if not locals {
        if exception_raised(tstate) {
            return NULL;
        }
        return object_new_ref(Py_None);
    }
    return object_new_ref(locals);
}

impl builtin_locals(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return builtin_locals_impl(module);
}

impl min_max_fail(
    it: ptr[PyObject], maxitem: ptr[PyObject], maxval: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(maxval);
    object_xdecref(maxitem);
    object_xdecref(it);
    return NULL;
}

impl min_max(
    args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    name = ptr[u8]("max");
    parser = addressof(max_parser);
    if op == Py_LT {
        name = ptr[u8]("min");
        parser = addressof(min_parser);
    }
    if nargs == 0 {
        PyErr_Format(PyExc_TypeError, "%s expected at least 1 argument, got 0", name);
        return NULL;
    }
    keyfunc = NULL;
    defaultval = NULL;
    if kwnames
        and _PyArg_ParseStackAndKeywords(
            args + nargs, 0, kwnames, parser, &mut keyfunc, &mut defaultval
        )
            == 0 {
        return NULL;
    }
    positional = nargs > 1;
    if positional and defaultval {
        PyErr_Format(
            PyExc_TypeError,
            "Cannot specify a default for %s() with multiple positional arguments",
            name
        );
        return NULL;
    }
    it = NULL;
    if not positional {
        it = PyObject_GetIter(args.view(1)[0]);
        if not it {
            return NULL;
        }
    }
    if keyfunc == Py_None {
        keyfunc = NULL;
    }
    maxitem = NULL;
    maxval = NULL;
    index: i64 = 0;
    while True {
        item = NULL;
        if not it {
            if index >= nargs {
                break;
            }
            item = object_new_ref(arg_at(args, index));
            index += 1;
        } else {
            item = PyIter_Next(it);
            if not item {
                if PyErr_Occurred() {
                    return min_max_fail(it, maxitem, maxval);
                }
                break;
            }
        }
        val = NULL;
        if keyfunc {
            val = PyObject_CallOneArg(keyfunc, item);
            if not val {
                object_decref(item);
                return min_max_fail(it, maxitem, maxval);
            }
        } else {
            val = object_new_ref(item);
        }
        if not maxval {
            maxitem = item;
            maxval = val;
        } else {
            cmp = PyObject_RichCompareBool(val, maxval, op);
            if cmp < 0 {
                object_decref(val);
                object_decref(item);
                return min_max_fail(it, maxitem, maxval);
            } elif cmp > 0 {
                object_decref(maxval);
                object_decref(maxitem);
                maxval = val;
                maxitem = item;
            } else {
                object_decref(item);
                object_decref(val);
            }
        }
    }
    if not maxval {
        if defaultval {
            maxitem = object_new_ref(defaultval);
        } else {
            PyErr_Format(PyExc_ValueError, "%s() iterable argument is empty", name);
        }
    } else {
        object_decref(maxval);
    }
    object_xdecref(it);
    return maxitem;
}

impl builtin_min(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return min_max(args, nargs, kwnames, Py_LT);
}

impl builtin_max(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return min_max(args, nargs, kwnames, Py_GT);
}

impl builtin_oct(module: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_ToBase(number, 8);
}

impl builtin_ord(module: ptr[PyObject], c: ptr[PyObject]) -> ptr[PyObject] {
    size: i64 = 0;
    if bytes_check(c) {
        size = object_size(c);
        if size == 1 {
            return PyLong_FromLong(i64(bytes_data(c).view(1)[0]));
        }
    } elif unicode_check(c) {
        size = unicode_length(c);
        if size == 1 {
            return PyLong_FromLong(i64(uo_read_char(c, 0)));
        }
    } elif bytearray_check(c) {
        size = object_size(c);
        if size == 1 {
            return PyLong_FromLong(
                i64(ptr[PyByteArrayObject](c).view(1)[0].ob_start.view(1)[0])
            );
        }
    } else {
        PyErr_Format(
            PyExc_TypeError,
            "ord() expected string of length 1, but %.200s found",
            object_type(c).view(1)[0].tp_name
        );
        return NULL;
    }
    PyErr_Format(
        PyExc_TypeError,
        "ord() expected a character, but string of length %zd found",
        size
    );
    return NULL;
}

impl builtin_pow_impl(
    module: ptr[PyObject],
    base_: ptr[PyObject],
    exp_: ptr[PyObject],
    mod_: ptr[PyObject]
) -> ptr[PyObject] {
    return PyNumber_Power(base_, exp_, mod_);
}

impl builtin_pow(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    noptargs = nargs + kwnames_size(kwnames) - 2;
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(pow_parser),
        2,
        3,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
    );
    if not fast {
        return NULL;
    }
    mod_ = Py_None;
    if noptargs > 0 {
        mod_ = arg_at(fast, 2);
    }
    return builtin_pow_impl(module, arg_at(fast, 0), arg_at(fast, 1), mod_);
}

impl builtin_print_impl(
    module: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    args_length: i64,
    sep: ptr[PyObject],
    end: ptr[PyObject],
    file: ptr[PyObject],
    flush: i32
) -> ptr[PyObject] {
    if file == Py_None {
        file = _PySys_GetRequiredAttr(py_id(_Py_ID_stdout));
        if not file {
            return NULL;
        }
        if file == Py_None {
            object_decref(file);
            return object_new_ref(Py_None);
        }
    } else {
        object_incref(file);
    }
    if sep == Py_None {
        sep = NULL;
    } elif sep and not unicode_check(sep) {
        PyErr_Format(
            PyExc_TypeError,
            "sep must be None or a string, not %.200s",
            object_type(sep).view(1)[0].tp_name
        );
        object_decref(file);
        return NULL;
    }
    if end == Py_None {
        end = NULL;
    } elif end and not unicode_check(end) {
        PyErr_Format(
            PyExc_TypeError,
            "end must be None or a string, not %.200s",
            object_type(end).view(1)[0].tp_name
        );
        object_decref(file);
        return NULL;
    }
    err: i32 = 0;
    for i in range(args_length) {
        if i > 0 {
            if not sep {
                err = PyFile_WriteString(ptr[u8](" "), file);
            } else {
                err = PyFile_WriteObject(sep, file, Py_PRINT_RAW);
            }
            if err != 0 {
                object_decref(file);
                return NULL;
            }
        }
        err = PyFile_WriteObject(arg_at(args, i), file, Py_PRINT_RAW);
        if err != 0 {
            object_decref(file);
            return NULL;
        }
    }
    if not end {
        err = PyFile_WriteString(ptr[u8]("\n"), file);
    } else {
        err = PyFile_WriteObject(end, file, Py_PRINT_RAW);
    }
    if err != 0 {
        object_decref(file);
        return NULL;
    }
    if flush != 0 {
        if _PyFile_Flush(file) < 0 {
            object_decref(file);
            return NULL;
        }
    }
    object_decref(file);
    return object_new_ref(Py_None);
}

impl builtin_print(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    sep = Py_None;
    end = Py_None;
    file = Py_None;
    flush: i32 = 0;
    if kwnames {
        scratch: own BuiltinStack = BuiltinStack();
        noptargs = kwnames_size(kwnames);
        fastargs = unpack_keywords(
            args,
            nargs,
            kwnames,
            addressof(print_parser),
            0,
            0,
            0,
            1,
            ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
        );
        if not fastargs {
            return NULL;
        }
        if noptargs > 0 {
            value = arg_at(fastargs, 0);
            if value {
                sep = value;
                noptargs -= 1;
            }
        }
        if noptargs > 0 {
            value = arg_at(fastargs, 1);
            if value {
                end = value;
                noptargs -= 1;
            }
        }
        if noptargs > 0 {
            value = arg_at(fastargs, 2);
            if value {
                file = value;
                noptargs -= 1;
            }
        }
        if noptargs > 0 {
            flush = PyObject_IsTrue(arg_at(fastargs, 3));
            if flush < 0 {
                return NULL;
            }
        }
    }
    return builtin_print_impl(module, args, nargs, sep, end, file, flush);
}

impl required_stream(id_offset: i64) -> ptr[PyObject] {
    return _PySys_GetRequiredAttr(py_id(id_offset));
}

impl input_fail(
    fin: ptr[PyObject], fout: ptr[PyObject], ferr: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(fin);
    object_xdecref(fout);
    object_xdecref(ferr);
    return NULL;
}

impl call_fileno(stream: ptr[PyObject]) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch));
    stack.view(1)[0] = stream;
    return PyObject_VectorcallMethod(
        py_id(_Py_ID_fileno), stack, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl readline_errors(
    tty: bool,
    stdin_encoding: ptr[PyObject],
    stdout_encoding: ptr[PyObject],
    stdin_errors: ptr[PyObject],
    stdout_errors: ptr[PyObject],
    po: ptr[PyObject]
) -> i32 {
    object_xdecref(stdin_encoding);
    object_xdecref(stdout_encoding);
    object_xdecref(stdin_errors);
    object_xdecref(stdout_errors);
    object_xdecref(po);
    if tty {
        return 1;
    }
    PyErr_Clear();
    return 2;
}

impl input_tty(
    fin: ptr[PyObject], fout: ptr[PyObject], prompt: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    po = NULL;
    stdin_encoding = NULL;
    stdin_errors = NULL;
    stdout_encoding = NULL;
    stdout_errors = NULL;
    stdin_encoding = PyObject_GetAttr(fin, py_id(_Py_ID_encoding));
    if not stdin_encoding {
        return (
            readline_errors(
                False, stdin_encoding, stdout_encoding, stdin_errors, stdout_errors, po
            ),
            NULL
        );
    }
    stdin_errors = PyObject_GetAttr(fin, py_id(_Py_ID_errors));
    if not stdin_errors {
        return (
            readline_errors(
                False, stdin_encoding, stdout_encoding, stdin_errors, stdout_errors, po
            ),
            NULL
        );
    }
    if not unicode_check(stdin_encoding) or not unicode_check(stdin_errors) {
        return (
            readline_errors(
                False, stdin_encoding, stdout_encoding, stdin_errors, stdout_errors, po
            ),
            NULL
        );
    }
    stdin_encoding_str = PyUnicode_AsUTF8(stdin_encoding);
    if not stdin_encoding_str {
        return (
            readline_errors(
                True, stdin_encoding, stdout_encoding, stdin_errors, stdout_errors, po
            ),
            NULL
        );
    }
    stdin_errors_str = PyUnicode_AsUTF8(stdin_errors);
    if not stdin_errors_str {
        return (
            readline_errors(
                True, stdin_encoding, stdout_encoding, stdin_errors, stdout_errors, po
            ),
            NULL
        );
    }
    if _PyFile_Flush(fout) < 0 {
        PyErr_Clear();
    }
    promptstr = ptr[u8]("");
    if prompt {
        stdout_encoding = PyObject_GetAttr(fout, py_id(_Py_ID_encoding));
        if not stdout_encoding {
            return (
                readline_errors(
                    False,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        stdout_errors = PyObject_GetAttr(fout, py_id(_Py_ID_errors));
        if not stdout_errors {
            return (
                readline_errors(
                    False,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        if not unicode_check(stdout_encoding) or not unicode_check(stdout_errors) {
            return (
                readline_errors(
                    False,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        stdout_encoding_str = PyUnicode_AsUTF8(stdout_encoding);
        if not stdout_encoding_str {
            return (
                readline_errors(
                    True,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        stdout_errors_str = PyUnicode_AsUTF8(stdout_errors);
        if not stdout_errors_str {
            return (
                readline_errors(
                    True,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        stringpo = PyObject_Str(prompt);
        if not stringpo {
            return (
                readline_errors(
                    True,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        po = PyUnicode_AsEncodedString(
            stringpo, stdout_encoding_str, stdout_errors_str
        );
        object_decref(stdout_encoding);
        stdout_encoding = NULL;
        object_decref(stdout_errors);
        stdout_errors = NULL;
        object_decref(stringpo);
        if not po {
            return (
                readline_errors(
                    True,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
        promptstr = bytes_data(po);
        if i64(strlen(promptstr)) != object_size(po) {
            PyErr_SetString(
                PyExc_ValueError, "input: prompt string cannot contain null characters"
            );
            return (
                readline_errors(
                    True,
                    stdin_encoding,
                    stdout_encoding,
                    stdin_errors,
                    stdout_errors,
                    po
                ),
                NULL
            );
        }
    }
    s = PyOS_Readline(jacpy_stdio_stream(0), jacpy_stdio_stream(1), promptstr);
    if not s {
        PyErr_CheckSignals();
        if not PyErr_Occurred() {
            PyErr_SetNone(PyExc_KeyboardInterrupt);
        }
        return (
            readline_errors(
                True, stdin_encoding, stdout_encoding, stdin_errors, stdout_errors, po
            ),
            NULL
        );
    }
    result = NULL;
    length = strlen(s);
    if length == u64(0) {
        PyErr_SetNone(PyExc_EOFError);
    } elif length > u64(0x7FFFFFFFFFFFFFFF) {
        PyErr_SetString(PyExc_OverflowError, "input: input too long");
    } else {
        n = i64(length) - 1;
        if n != 0 and (s + (n - 1)).view(1)[0] == u8(13) {
            n -= 1;
        }
        result = PyUnicode_Decode(s, n, stdin_encoding_str, stdin_errors_str);
    }
    object_decref(stdin_encoding);
    object_decref(stdin_errors);
    object_xdecref(po);
    PyMem_Free(ptr(s));
    if result {
        if PySys_Audit("builtins.input/result", "O", result) < 0 {
            return (i32(1), NULL);
        }
    }
    return (i32(0), result);
}

impl builtin_input_impl(module: ptr[PyObject], prompt: ptr[PyObject]) -> ptr[PyObject] {
    fin = NULL;
    fout = NULL;
    ferr = NULL;
    fin = required_stream(_Py_ID_stdin);
    if not fin {
        return input_fail(fin, fout, ferr);
    }
    if fin == Py_None {
        PyErr_SetString(PyExc_RuntimeError, "lost sys.stdin");
        return input_fail(fin, fout, ferr);
    }
    fout = required_stream(_Py_ID_stdout);
    if not fout {
        return input_fail(fin, fout, ferr);
    }
    if fout == Py_None {
        PyErr_SetString(PyExc_RuntimeError, "lost sys.stdout");
        return input_fail(fin, fout, ferr);
    }
    ferr = required_stream(_Py_ID_stderr);
    if not ferr {
        return input_fail(fin, fout, ferr);
    }
    if ferr == Py_None {
        PyErr_SetString(PyExc_RuntimeError, "lost sys.stderr");
        return input_fail(fin, fout, ferr);
    }
    audit_prompt = prompt;
    if not audit_prompt {
        audit_prompt = Py_None;
    }
    if PySys_Audit("builtins.input", "O", audit_prompt) < 0 {
        return input_fail(fin, fout, ferr);
    }
    if _PyFile_Flush(ferr) < 0 {
        PyErr_Clear();
    }
    tty = False;
    tmp = call_fileno(fin);
    if not tmp {
        PyErr_Clear();
    } else {
        fd = PyLong_AsLong(tmp);
        object_decref(tmp);
        if fd < 0 and PyErr_Occurred() {
            return input_fail(fin, fout, ferr);
        }
        tty = fd == i64(jacpy_stdio_fileno(0)) and isatty(i32(fd)) != 0;
    }
    if tty {
        tmp = call_fileno(fout);
        if not tmp {
            PyErr_Clear();
            tty = False;
        } else {
            fd = PyLong_AsLong(tmp);
            object_decref(tmp);
            if fd < 0 and PyErr_Occurred() {
                return input_fail(fin, fout, ferr);
            }
            tty = fd == i64(jacpy_stdio_fileno(1)) and isatty(i32(fd)) != 0;
        }
    }
    if tty {
        (status, result) = input_tty(fin, fout, prompt);
        if status == 0 {
            object_decref(fin);
            object_decref(fout);
            object_decref(ferr);
            return result;
        }
        if status == 1 {
            return input_fail(fin, fout, ferr);
        }
    }
    if prompt {
        if PyFile_WriteObject(prompt, fout, Py_PRINT_RAW) != 0 {
            return input_fail(fin, fout, ferr);
        }
    }
    if _PyFile_Flush(fout) < 0 {
        PyErr_Clear();
    }
    line = PyFile_GetLine(fin, -1);
    object_decref(fin);
    object_decref(fout);
    object_decref(ferr);
    return line;
}

impl builtin_input(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional(nargs, 0, 1)
        and _PyArg_CheckPositional(ptr[u8]("input"), nargs, 0, 1) == 0 {
        return NULL;
    }
    prompt = NULL;
    if nargs >= 1 {
        prompt = arg_at(args, 0);
    }
    return builtin_input_impl(module, prompt);
}

impl builtin_repr(module: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_Repr(obj_);
}

impl builtin_round_impl(
    module: ptr[PyObject], number: ptr[PyObject], ndigits: ptr[PyObject]
) -> ptr[PyObject] {
    result = NULL;
    if ndigits == Py_None {
        result = _PyObject_MaybeCallSpecialNoArgs(number, py_id(_Py_ID___round__));
    } else {
        result = _PyObject_MaybeCallSpecialOneArg(
            number, py_id(_Py_ID___round__), ndigits
        );
    }
    if not result and not PyErr_Occurred() {
        PyErr_Format(
            PyExc_TypeError,
            "type %.100s doesn't define __round__ method",
            object_type(number).view(1)[0].tp_name
        );
    }
    return result;
}

impl builtin_round(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    noptargs = nargs + kwnames_size(kwnames) - 1;
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(round_parser),
        1,
        2,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
    );
    if not fast {
        return NULL;
    }
    ndigits = Py_None;
    if noptargs > 0 {
        ndigits = arg_at(fast, 1);
    }
    return builtin_round_impl(module, arg_at(fast, 0), ndigits);
}

impl builtin_sorted(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    seq = NULL;
    if _PyArg_UnpackStack(args, nargs, ptr[u8]("sorted"), 1, 1, &mut seq) == 0 {
        return NULL;
    }
    newlist = PySequence_List(seq);
    if not newlist {
        return NULL;
    }
    callable = PyObject_GetAttr(newlist, py_id(_Py_ID_sort));
    if not callable {
        object_decref(newlist);
        return NULL;
    }
    v = PyObject_Vectorcall(callable, args + 1, u64(nargs - 1), kwnames);
    object_decref(callable);
    if not v {
        object_decref(newlist);
        return NULL;
    }
    object_decref(v);
    return newlist;
}

impl builtin_vars(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    v = NULL;
    if PyArg_UnpackTuple(args, ptr[u8]("vars"), 0, 1, &mut v) == 0 {
        return NULL;
    }
    d = NULL;
    if not v {
        if _PyEval_GetFrame() {
            d = _PyEval_GetFrameLocals();
        } else {
            tstate = thread_state();
            d = _PyEval_GetGlobalsFromRunningMain(tstate);
            if not d {
                if not exception_raised(tstate) {
                    d = _PyEval_GetFrameLocals();
                }
            } else {
                object_incref(d);
            }
        }
    } elif PyObject_GetOptionalAttr(v, py_id(_Py_ID___dict__), &mut d) == 0 {
        PyErr_SetString(
            PyExc_TypeError, "vars() argument must have __dict__ attribute"
        );
    }
    return d;
}

impl cs_add(hi: f64, lo: f64, x: f64) -> tuple[f64, f64] {
    t = hi + x;
    new_lo = lo;
    if fabs(hi) >= fabs(x) {
        new_lo = lo + ((hi - t) + x);
    } else {
        new_lo = lo + ((x - t) + hi);
    }
    return (t, new_lo);
}

impl cs_to_double(hi: f64, lo: f64) -> f64 {
    if lo != 0.0 and lo - lo == 0.0 {
        return hi + lo;
    }
    return hi;
}

impl sum_fail(item: ptr[PyObject], iter_obj: ptr[PyObject]) -> ptr[PyObject] {
    object_decref(item);
    object_decref(iter_obj);
    return NULL;
}

impl builtin_sum_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject] {
    result = start;
    iter_obj = PyObject_GetIter(iterable);
    if not iter_obj {
        return NULL;
    }
    if not result {
        result = PyLong_FromLong(0);
        if not result {
            object_decref(iter_obj);
            return NULL;
        }
    } else {
        if unicode_check(result) {
            PyErr_SetString(
                PyExc_TypeError, "sum() can't sum strings [use ''.join(seq) instead]"
            );
            object_decref(iter_obj);
            return NULL;
        }
        if bytes_check(result) {
            PyErr_SetString(
                PyExc_TypeError, "sum() can't sum bytes [use b''.join(seq) instead]"
            );
            object_decref(iter_obj);
            return NULL;
        }
        if bytearray_check(result) {
            PyErr_SetString(
                PyExc_TypeError, "sum() can't sum bytearray [use b''.join(seq) instead]"
            );
            object_decref(iter_obj);
            return NULL;
        }
        object_incref(result);
    }
    if long_check_exact(result) {
        overflow: i32 = 0;
        i_result = PyLong_AsLongAndOverflow(result, &mut overflow);
        if overflow == 0 {
            object_decref(result);
            result = NULL;
        }
        while not result {
            item = PyIter_Next(iter_obj);
            if not item {
                object_decref(iter_obj);
                if PyErr_Occurred() {
                    return NULL;
                }
                return PyLong_FromSsize_t(i_result);
            }
            if long_check_exact(item) or bool_check(item) {
                b: i64 = 0;
                overflow = 0;
                if long_is_compact(ptr[PyLongObject](item)) {
                    b = compact_value(ptr[PyLongObject](item));
                } else {
                    b = PyLong_AsLongAndOverflow(item, &mut overflow);
                }
                if overflow == 0
                    and (
                        (i_result >= 0 and b <= PY_SSIZE_T_MAX - i_result)
                        or (i_result < 0 and b >= PY_SSIZE_T_MIN - i_result)
                    ) {
                    i_result = i_result + b;
                    object_decref(item);
                    continue;
                }
            }
            result = PyLong_FromSsize_t(i_result);
            if not result {
                return sum_fail(item, iter_obj);
            }
            temp = PyNumber_Add(result, item);
            object_decref(result);
            object_decref(item);
            result = temp;
            if not result {
                object_decref(iter_obj);
                return NULL;
            }
        }
    }
    if float_check_exact(result) {
        re_hi = float_value(result);
        re_lo = 0.0;
        object_decref(result);
        result = NULL;
        while not result {
            item = PyIter_Next(iter_obj);
            if not item {
                object_decref(iter_obj);
                if PyErr_Occurred() {
                    return NULL;
                }
                return PyFloat_FromDouble(cs_to_double(re_hi, re_lo));
            }
            if float_check_exact(item) {
                (re_hi, re_lo) = cs_add(re_hi, re_lo, float_value(item));
                decref_float(item);
                continue;
            }
            if long_check(item) {
                value = PyLong_AsDouble(item);
                if value != -1.0 or not PyErr_Occurred() {
                    (re_hi, re_lo) = cs_add(re_hi, re_lo, value);
                    object_decref(item);
                    continue;
                }
                return sum_fail(item, iter_obj);
            }
            result = PyFloat_FromDouble(cs_to_double(re_hi, re_lo));
            if not result {
                return sum_fail(item, iter_obj);
            }
            temp = PyNumber_Add(result, item);
            object_decref(result);
            object_decref(item);
            result = temp;
            if not result {
                object_decref(iter_obj);
                return NULL;
            }
        }
    }
    if complex_check_exact(result) {
        z = PyComplex_AsCComplex(result);
        re_hi = z.real;
        re_lo = 0.0;
        im_hi = z.imag;
        im_lo = 0.0;
        object_decref(result);
        result = NULL;
        while not result {
            item = PyIter_Next(iter_obj);
            if not item {
                object_decref(iter_obj);
                if PyErr_Occurred() {
                    return NULL;
                }
                return PyComplex_FromDoubles(
                    cs_to_double(re_hi, re_lo), cs_to_double(im_hi, im_lo)
                );
            }
            if complex_check_exact(item) {
                zi = PyComplex_AsCComplex(item);
                (re_hi, re_lo) = cs_add(re_hi, re_lo, zi.real);
                (im_hi, im_lo) = cs_add(im_hi, im_lo, zi.imag);
                object_decref(item);
                continue;
            }
            if long_check(item) {
                value = PyLong_AsDouble(item);
                if value != -1.0 or not PyErr_Occurred() {
                    (re_hi, re_lo) = cs_add(re_hi, re_lo, value);
                    object_decref(item);
                    continue;
                }
                return sum_fail(item, iter_obj);
            }
            if float_check(item) {
                (re_hi, re_lo) = cs_add(re_hi, re_lo, float_value(item));
                decref_float(item);
                continue;
            }
            result = PyComplex_FromDoubles(
                cs_to_double(re_hi, re_lo), cs_to_double(im_hi, im_lo)
            );
            if not result {
                return sum_fail(item, iter_obj);
            }
            temp = PyNumber_Add(result, item);
            object_decref(result);
            object_decref(item);
            result = temp;
            if not result {
                object_decref(iter_obj);
                return NULL;
            }
        }
    }
    while True {
        item = PyIter_Next(iter_obj);
        if not item {
            if PyErr_Occurred() {
                object_decref(result);
                result = NULL;
            }
            break;
        }
        temp = PyNumber_Add(result, item);
        object_decref(result);
        object_decref(item);
        result = temp;
        if not result {
            break;
        }
    }
    object_decref(iter_obj);
    return result;
}

impl builtin_sum(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own BuiltinStack = BuiltinStack();
    noptargs = nargs + kwnames_size(kwnames) - 1;
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(sum_parser),
        1,
        2,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch))
    );
    if not fast {
        return NULL;
    }
    start = NULL;
    if noptargs > 0 {
        start = arg_at(fast, 1);
    }
    return builtin_sum_impl(module, arg_at(fast, 0), start);
}

impl builtin_isinstance(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs != 2 and _PyArg_CheckPositional(ptr[u8]("isinstance"), nargs, 2, 2) == 0 {
        return NULL;
    }
    retval = PyObject_IsInstance(arg_at(args, 0), arg_at(args, 1));
    if retval < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(retval));
}

impl builtin_issubclass(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs != 2 and _PyArg_CheckPositional(ptr[u8]("issubclass"), nargs, 2, 2) == 0 {
        return NULL;
    }
    retval = PyObject_IsSubclass(arg_at(args, 0), arg_at(args, 1));
    if retval < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(retval));
}

impl zip_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    strict: i32 = 0;
    if kwds {
        empty = PyTuple_New(0);
        if not empty {
            return NULL;
        }
        parsed = PyArg_ParseTupleAndKeywords(
            empty, kwds, ptr[u8]("|$p:zip"), ptr(addressof(zip_kwlist)), &mut strict
        );
        object_decref(empty);
        if parsed == 0 {
            return NULL;
        }
    }
    tuplesize = object_size(args);
    ittuple = PyTuple_New(tuplesize);
    if not ittuple {
        return NULL;
    }
    for i in range(tuplesize) {
        it = PyObject_GetIter(tuple_get_item(args, i));
        if not it {
            object_decref(ittuple);
            return NULL;
        }
        tuple_set_item(ittuple, i, it);
    }
    result = PyTuple_New(tuplesize);
    if not result {
        object_decref(ittuple);
        return NULL;
    }
    for i in range(tuplesize) {
        tuple_set_item(result, i, object_new_ref(Py_None));
    }
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        object_decref(ittuple);
        object_decref(result);
        return NULL;
    }
    lz = ptr[zipobject](op);
    lz.view(1)[0].ittuple = ittuple;
    lz.view(1)[0].tuplesize = tuplesize;
    lz.view(1)[0].result = result;
    lz.view(1)[0].strict = strict;
    return op;
}

impl zip_dealloc(self_: ptr[PyObject]) {
    lz = ptr[zipobject](self_);
    object_gc_untrack(self_);
    object_xdecref(lz.view(1)[0].ittuple);
    object_xdecref(lz.view(1)[0].result);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl zip_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    lz = ptr[zipobject](self_);
    status = visit_reference(lz.view(1)[0].ittuple, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(lz.view(1)[0].result, visitor, arg);
}

impl zip_strict_check(ittuple: ptr[PyObject], i: i64, tuplesize: i64) -> ptr[PyObject] {
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
            return NULL;
        }
        PyErr_Clear();
    }
    if i != 0 {
        plural = ptr[u8](" ") if i == 1 else ptr[u8]("s 1-");
        return PyErr_Format(
            PyExc_ValueError,
            "zip() argument %zd is shorter than argument%s%zd",
            i + 1,
            plural,
            i
        );
    }
    j: i64 = 1;
    while j < tuplesize {
        item = iter_next(tuple_get_item(ittuple, j));
        if item {
            object_decref(item);
            plural = ptr[u8](" ") if j == 1 else ptr[u8]("s 1-");
            return PyErr_Format(
                PyExc_ValueError,
                "zip() argument %zd is longer than argument%s%zd",
                j + 1,
                plural,
                j
            );
        }
        if PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
                return NULL;
            }
            PyErr_Clear();
        }
        j += 1;
    }
    return NULL;
}

impl zip_next(self_: ptr[PyObject]) -> ptr[PyObject] {
    lz = ptr[zipobject](self_);
    tuplesize = lz.view(1)[0].tuplesize;
    ittuple = lz.view(1)[0].ittuple;
    result = lz.view(1)[0].result;
    if tuplesize == 0 {
        return NULL;
    }
    if object_refcount(result) == 1 {
        object_incref(result);
        for i in range(tuplesize) {
            item = iter_next(tuple_get_item(ittuple, i));
            if not item {
                object_decref(result);
                if lz.view(1)[0].strict != 0 {
                    return zip_strict_check(ittuple, i, tuplesize);
                }
                return NULL;
            }
            olditem = tuple_get_item(result, i);
            tuple_set_item(result, i, item);
            object_decref(olditem);
        }
        tuple_recycle(result);
        return result;
    }
    result = PyTuple_New(tuplesize);
    if not result {
        return NULL;
    }
    for i in range(tuplesize) {
        item = iter_next(tuple_get_item(ittuple, i));
        if not item {
            object_decref(result);
            if lz.view(1)[0].strict != 0 {
                return zip_strict_check(ittuple, i, tuplesize);
            }
            return NULL;
        }
        tuple_set_item(result, i, item);
    }
    return result;
}

impl zip_reduce(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    lz = ptr[zipobject](self_);
    if lz.view(1)[0].strict != 0 {
        return PyTuple_Pack(
            3, ptr[PyObject](object_type(self_)), lz.view(1)[0].ittuple, py_true()
        );
    }
    return PyTuple_Pack(2, ptr[PyObject](object_type(self_)), lz.view(1)[0].ittuple);
}

impl zip_setstate(self_: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    strict = PyObject_IsTrue(state);
    if strict < 0 {
        return NULL;
    }
    ptr[zipobject](self_).view(1)[0].strict = strict;
    return object_new_ref(Py_None);
}

impl set_builtin(dct: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]) -> bool {
    return PyDict_SetItemString(dct, name, value) >= 0;
}

impl builtin_type(value: ptr[PyTypeObject]) -> ptr[PyObject] {
    return ptr[PyObject](value);
}
