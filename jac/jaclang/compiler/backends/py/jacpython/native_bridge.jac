import from c {
    def jac_str_new(data: ptr[u8], size: i64) -> ptr;  def jac_release(value: ptr);  def jacpy_compile_object(
        source: u64,
        filename: u64,
        mode_owner: ptr,
        mode_data: ptr[u8],
        mode_size: i64,
        optimize: i64,
        options: i64,
        feature: i64
    ) -> u64;  def jacpy_mangle(private: u64, name: u64) -> u64;  def jacpy_stack_effect(
        opcode: i64, oparg: i64, jump: i64
    ) -> i64;  def jacpy_fd_encoding(fd: i64) -> u64;  def jacpy_symtable_object(
        source: u64, filename: u64, mode_owner: ptr, mode_data: ptr[u8], mode_size: i64
    ) -> u64;  def jacpy_token_create(
        reader: u64,
        encoding_owner: ptr,
        encoding_data: ptr[u8],
        encoding_size: i64,
        decode: bool,
        extra: bool
    ) -> ptr;  def jacpy_token_step(iterator: ptr) -> u64;  def jacpy_token_dispose(
        iterator: ptr
    );  def strlen(text: ptr[u8]) -> u64;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memchr(source: ptr, value: i32, size: u64) -> ptr;  def fread(
        buffer: ptr, size: u64, count: u64, stream: ptr
    ) -> u64;  def ferror(stream: ptr) -> i32;  def fgetc(stream: ptr) -> i32;  def fileno(
        stream: ptr
    ) -> i32;  def isatty(fd: i32) -> i32;  def __jac_stdio(fd: i32) -> ptr;  def PyAST_obj2mod(
        ast: ptr[PyObject], arena: ptr, mode: i32
    ) -> ptr;  def PyAST_mod2obj(tree: ptr) -> ptr[PyObject];  def PyOS_Readline(
        stdin: ptr, stdout: ptr, prompt: ptr[u8]
    ) -> ptr[u8];  def PyUnicode_FromString(text: ptr[u8]) -> ptr[PyObject];  def PyByteArray_FromStringAndSize(
        bytes_: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyByteArray_Resize(
        self_: ptr[PyObject], size: i64
    ) -> i32;  def PyBytes_FromObject(x: ptr[PyObject]) -> ptr[PyObject];  def PyUnicode_Decode(
        s: ptr[u8], size: i64, encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject];  def PyErr_SetFromErrno(exc: ptr[PyObject]) -> ptr[PyObject];  def PyErr_ExceptionMatches(
        exc: ptr[PyObject]
    ) -> i32;  def PyErr_GetRaisedException -> ptr[PyObject];  def PyErr_Clear;  def PyObject_GetAttrString(
        op: ptr[PyObject], name: ptr[u8]
    ) -> ptr[PyObject];  def PyUnicode_FSDecoder(
        arg: ptr[PyObject], addr: ptr
    ) -> i32;  def PyType_FromModuleAndSpec(
        module: ptr[PyObject], spec: ptr[PyType_Spec], bases: ptr[PyObject]
    ) -> ptr[PyObject];  def PyModuleDef_Init(
        definition: ptr[ModuleDef]
    ) -> ptr[PyObject];  def PyObject_GC_UnTrack(op: ptr);  obj CompilerFlags {
        has cf_flags: i32 = 0,
            cf_feature_version: i32 = 0;
    }  obj TokenizerObject {
        has ob_base: _object,
            reader: ptr[PyObject],
            iterator: ptr;
    }  obj NativeBridgeCall {
        has visit_call: Callable[[ptr[PyObject], ptr], i32] = 0;
    }  glob:priv token_slots: list[PyType_Slot] = [
             PyType_Slot(slot=52, pfunc=ptr(token_dealloc)),
             PyType_Slot(slot=71, pfunc=ptr(token_traverse)),
             PyType_Slot(slot=51, pfunc=ptr(token_clear)),
             PyType_Slot(slot=62, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=63, pfunc=ptr(token_next)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         token_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_tokenize.TokenizerIter"),
             basicsize=32,
             itemsize=0,
             flags=u32(Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC),
             slots=addressof(token_slots)
         ),
         tokenize_keywords: list[ptr[u8]] = [
             ptr[u8]("readline"),
             ptr[u8]("extra_tokens"),
             ptr[u8]("encoding"),
             ptr[u8]()
         ],
         symtable_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("symtable"),
                 ml_meth=ptr(symtable_call),
                 ml_flags=1,
                 ml_doc=ptr[u8]("Build a symbol table with JacPython.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         tokenize_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("TokenizerIter"),
                 ml_meth=ptr(tokenize_call),
                 ml_flags=3,
                 ml_doc=ptr[u8]("Construct JacPython's streaming token iterator.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         symtable_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=2, value=ptr(symtable_exec)),
             PyModuleDef_Slot(slot=3, value=ptr(2)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         tokenize_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=2, value=ptr(tokenize_exec)),
             PyModuleDef_Slot(slot=3, value=ptr(2)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ],
         symtable_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_symtable"),
             m_doc=ptr[u8](),
             m_size=0,
             m_methods=addressof(symtable_methods),
             m_slots=addressof(symtable_slots)
         ),
         tokenize_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_tokenize"),
             m_doc=ptr[u8](),
             m_size=0,
             m_methods=addressof(tokenize_methods),
             m_slots=addressof(tokenize_slots)
         );
}

glob:priv PY_SINGLE_INPUT: Final[i32] = 256,
     PY_FILE_INPUT: Final[i32] = 257,
     PY_EVAL_INPUT: Final[i32] = 258,
     PY_FUNC_TYPE_INPUT: Final[i32] = 345,
     CF_SOURCE_IS_UTF8: Final[i32] = 0x0100,
     CF_DONT_IMPLY_DEDENT: Final[i32] = 0x0200,
     CF_ONLY_AST: Final[i32] = 0x0400,
     CF_IGNORE_COOKIE: Final[i32] = 0x0800,
     CF_ALLOW_INCOMPLETE_INPUT: Final[i32] = 0x4000,
     PY_MINOR_VERSION: Final[i32] = 14,
     E_EOF: Final[i32] = 11,
     E_DONE: Final[i32] = 16,
     E_ERROR: Final[i32] = 17,
     STDIO_EOF: Final[i32] = -1,
     PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     READ_CHUNK: Final[i64] = 8192;

def native_object(handle: u64) -> ptr[PyObject];

def compile_mode(start: i32) -> ptr[u8];

def config_word(offset: i64) -> i32;

def code_check(op: ptr[PyObject]) -> bool;

def source_object(text: ptr[u8], flags: ptr[CompilerFlags]) -> ptr[PyObject];

def bytearray_data(op: ptr[PyObject]) -> ptr[u8];

def append_bytes(source: ptr[PyObject], data: ptr[u8], size: i64) -> i32;

def decoded_source(data: ptr[PyObject], encoding: ptr[u8]) -> ptr[PyObject];

def copy_flags(flags: ptr[CompilerFlags], target: ptr[CompilerFlags]);

def parse_object(
    source: ptr[PyObject],
    filename: ptr[PyObject],
    start: i32,
    flags: ptr[CompilerFlags],
    arena: ptr
) -> ptr;

def read_file(fp: ptr, encoding: ptr[u8]) -> ptr[PyObject];

def incomplete_input -> bool;

def symtable_call(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def token_of(op: ptr[PyObject]) -> ptr[TokenizerObject];

def token_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def token_clear(op: ptr[PyObject]) -> i32;

def token_dealloc(op: ptr[PyObject]);

def token_next(op: ptr[PyObject]) -> ptr[PyObject];

def tokenize_call(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def tokenize_exec(module: ptr[PyObject]) -> i32;

def symtable_constant(module: ptr[PyObject], name: ptr[u8], value: i64) -> bool;

def symtable_exec(module: ptr[PyObject]) -> i32;

import from c {
    def _PyJac_CompilerBridgeVersion -> i32 {
        return i32(4);
    }  def _PyJac_SymtableBridgeVersion -> i32 {
        return i32(3);
    }  def _PyJac_TokenizeBridgeVersion -> i32 {
        return i32(3);
    }  def _PyJac_CompilerRequired -> i32 {
        return i32(1);
    }  def _PyJac_CompileObject(
        source: ptr[PyObject],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[CompilerFlags],
        optimize: i32
    ) -> ptr[PyObject] {
        mode = compile_mode(start);
        if not mode {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("invalid compilation mode"));
            return NULL;
        }
        if PySys_Audit(ptr[u8]("compile"), ptr[u8]("OO"), source, filename) < 0 {
            return NULL;
        }
        options: i32 = 0;
        feature: i32 = -1;
        if flags {
            options = flags.view(1)[0].cf_flags;
            feature = flags.view(1)[0].cf_feature_version;
        }
        options = options & ~(CF_SOURCE_IS_UTF8 | CF_IGNORE_COOKIE);
        level = optimize;
        if level < 0 {
            level = config_word(PyConfig_OPTIMIZATION_LEVEL);
        }
        length = i64(strlen(mode));
        mode_string = jac_str_new(mode, length);
        if not mode_string {
            return PyErr_NoMemory();
        }
        native = jacpy_compile_object(
            u64(int(source)),
            u64(int(filename)),
            mode_string,
            ptr[u8](mode_string),
            length,
            i64(level),
            i64(options),
            i64(feature)
        );
        jac_release(mode_string);
        result = native_object(native);
        if not result {
            return NULL;
        }
        if (options & CF_ONLY_AST) == i32(0) and not code_check(result) {
            object_decref(result);
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("JacPython compiler must return a code object")
            );
            return NULL;
        }
        if flags and code_check(result) {
            co_flags = ptr[i32](ptr[u8](result) + PyCodeObject_FLAGS).view(1)[0];
            flags.view(1)[0].cf_flags = flags.view(1)[0].cf_flags
                | (co_flags & PyCF_MASK);
        }
        return result;
    }  def _PyJac_CompileString(
        text: ptr[u8],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[CompilerFlags],
        optimize: i32
    ) -> ptr[PyObject] {
        source = source_object(text, flags);
        if not source {
            return NULL;
        }
        result = _PyJac_CompileObject(source, filename, start, flags, optimize);
        object_decref(source);
        return result;
    }  def _PyParser_ASTFromString(
        text: ptr[u8],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[CompilerFlags],
        arena: ptr
    ) -> ptr {
        source = source_object(text, flags);
        if not source {
            return ptr();
        }
        result = parse_object(source, filename, start, flags, arena);
        object_decref(source);
        return result;
    }  def _PyJac_CompileFile(
        fp: ptr, filename: ptr[PyObject], start: i32, flags: ptr[CompilerFlags]
    ) -> ptr[PyObject] {
        source = read_file(fp, ptr[u8]());
        if not source {
            return NULL;
        }
        result = _PyJac_CompileObject(source, filename, start, flags, i32(-1));
        object_decref(source);
        return result;
    }  def _PyParser_ASTFromFile(
        fp: ptr,
        filename: ptr[PyObject],
        encoding: ptr[u8],
        start: i32,
        ps1: ptr[u8],
        ps2: ptr[u8],
        flags: ptr[CompilerFlags],
        errcode: ptr[i32],
        arena: ptr
    ) -> ptr {
        if ps1 or ps2 {
            interactive = ptr[ptr[PyObject]](__alloca(8));
            interactive.view(1)[0] = NULL;
            parsed = _PyParser_InteractiveASTFromFile(
                fp,
                filename,
                encoding,
                start,
                ps1,
                ps2,
                flags,
                errcode,
                interactive,
                arena
            );
            object_xdecref(interactive.view(1)[0]);
            return parsed;
        }
        source = read_file(fp, encoding);
        if not source {
            return ptr();
        }
        result = parse_object(source, filename, start, flags, arena);
        object_decref(source);
        if errcode {
            errcode.view(1)[0] = E_DONE if result else E_ERROR;
        }
        return result;
    }  def _PyParser_InteractiveASTFromFile(
        fp: ptr,
        filename: ptr[PyObject],
        encoding: ptr[u8],
        start: i32,
        ps1: ptr[u8],
        ps2: ptr[u8],
        flags: ptr[CompilerFlags],
        errcode: ptr[i32],
        interactive_src: ptr[ptr[PyObject]],
        arena: ptr
    ) -> ptr {
        data = PyByteArray_FromStringAndSize(ptr[u8](), 0);
        if not data {
            return ptr();
        }
        interactive_src.view(1)[0] = NULL;
        if errcode {
            errcode.view(1)[0] = E_ERROR;
        }
        result = ptr();
        byte = ptr[u8](__alloca(8));
        cf = ptr[CompilerFlags](__alloca(8));
        while True {
            eof = False;
            if fp == __jac_stdio(0)
                and (
                    isatty(fileno(fp)) != 0 or config_word(PyConfig_INTERACTIVE) != 0
                ) {
                prompt = ps1 if object_size(data) == 0 else ps2;
                if not prompt {
                    prompt = ptr[u8]("");
                }
                line = PyOS_Readline(fp, __jac_stdio(1), prompt);
                if not line {
                    if not PyErr_Occurred() {
                        PyErr_SetNone(PyExc_KeyboardInterrupt);
                    }
                    break;
                }
                size = i64(strlen(line));
                status = append_bytes(data, line, size);
                PyMem_Free(ptr(line));
                if status < 0 {
                    break;
                }
                eof = size == 0;
            } else {
                failed = False;
                ch = fgetc(fp);
                while ch != STDIO_EOF {
                    byte.view(1)[0] = u8.wrap(ch);
                    if append_bytes(data, byte, 1) < 0 {
                        failed = True;
                        break;
                    }
                    if ch == i32(10) {
                        break;
                    }
                    ch = fgetc(fp);
                }
                if failed {
                    break;
                }
                if ferror(fp) != 0 {
                    PyErr_SetFromErrno(PyExc_OSError);
                    break;
                }
                eof = ch == STDIO_EOF;
            }
            if eof and object_size(data) == 0 {
                if errcode {
                    errcode.view(1)[0] = E_EOF;
                }
                break;
            }
            source = decoded_source(data, encoding);
            if not source {
                break;
            }
            copy_flags(flags, cf);
            if not eof {
                cf.view(1)[0].cf_flags = cf.view(1)[0].cf_flags
                    | CF_ALLOW_INCOMPLETE_INPUT
                    | CF_DONT_IMPLY_DEDENT;
            }
            result = parse_object(source, filename, start, cf, arena);
            object_decref(source);
            if result {
                text = PyUnicode_Decode(
                    bytearray_data(data),
                    object_size(data),
                    encoding or ptr[u8]("utf-8"),
                    ptr[u8]("strict")
                );
                interactive_src.view(1)[0] = text;
                if not text {
                    result = ptr();
                } elif errcode {
                    errcode.view(1)[0] = E_DONE;
                }
                break;
            }
            if not eof and PyErr_ExceptionMatches(PyExc_SyntaxError) != 0 {
                if incomplete_input() {
                    continue;
                }
            }
            break;
        }
        object_decref(data);
        return result;
    }  def _PyAST_Compile(
        tree: ptr,
        filename: ptr[PyObject],
        flags: ptr[CompilerFlags],
        optimize: i32,
        arena: ptr
    ) -> ptr[PyObject] {
        source = PyAST_mod2obj(tree);
        if not source {
            return NULL;
        }
        kind = ptr[i32](tree).view(1)[0];
        start = PY_EVAL_INPUT;
        if kind == i32(1) {
            start = PY_FILE_INPUT;
        } elif kind == i32(2) {
            start = PY_SINGLE_INPUT;
        }
        result = _PyJac_CompileObject(source, filename, start, flags, optimize);
        object_decref(source);
        return result;
    }  def _Py_Mangle(privateobj: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
        if not privateobj
            or not type_has_feature(
                object_type(privateobj), Py_TPFLAGS_UNICODE_SUBCLASS
            ) {
            return object_new_ref(name);
        }
        return native_object(jacpy_mangle(u64(int(privateobj)), u64(int(name))));
    }  def PyCompile_OpcodeStackEffectWithJump(
        opcode: i32, oparg: i32, jump: i32
    ) -> i32 {
        return i32.wrap(jacpy_stack_effect(i64(opcode), i64(oparg), i64(jump)));
    }  def PyCompile_OpcodeStackEffect(opcode: i32, oparg: i32) -> i32 {
        return PyCompile_OpcodeStackEffectWithJump(opcode, oparg, i32(-1));
    }  def _PyTokenizer_FindEncodingFilename(
        fd: i32, filename: ptr[PyObject]
    ) -> ptr[u8] {
        result = native_object(jacpy_fd_encoding(i64(fd)));
        if not result {
            return ptr[u8]();
        }
        length: i64 = 0;
        text = PyUnicode_AsUTF8AndSize(result, &mut length);
        copy = ptr[u8]();
        if text {
            copy = ptr[u8](PyMem_Malloc(u64(length + 1)));
            if copy {
                memcpy(ptr(copy), ptr(text), u64(length + 1));
            } else {
                PyErr_NoMemory();
            }
        }
        object_decref(result);
        return copy;
    }  def PyInit__symtable -> ptr[PyObject] {
        return PyModuleDef_Init(addressof(symtable_module));
    }  def PyInit__tokenize -> ptr[PyObject] {
        return PyModuleDef_Init(addressof(tokenize_module));
    }
}

impl native_object(handle: u64) -> ptr[PyObject] {
    value = ptr[PyObject](handle);
    if not value and not PyErr_Occurred() {
        PyErr_SetString(
            PyExc_SystemError, ptr[u8]("native JacPython failed without an exception")
        );
    }
    return value;
}

impl compile_mode(start: i32) -> ptr[u8] {
    if start == PY_FILE_INPUT {
        return ptr[u8]("exec");
    }
    if start == PY_EVAL_INPUT {
        return ptr[u8]("eval");
    }
    if start == PY_SINGLE_INPUT {
        return ptr[u8]("single");
    }
    if start == PY_FUNC_TYPE_INPUT {
        return ptr[u8]("func_type");
    }
    return ptr[u8]();
}

impl config_word(offset: i64) -> i32 {
    config = current_interp() + PyInterpreterState_CONFIG;
    return ptr[i32](config + offset).view(1)[0];
}

impl code_check(op: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](addressof(PyCode_Type));
}

impl source_object(text: ptr[u8], flags: ptr[CompilerFlags]) -> ptr[PyObject] {
    if flags and (flags.view(1)[0].cf_flags & CF_IGNORE_COOKIE) != i32(0) {
        return PyUnicode_FromString(text);
    }
    return PyBytes_FromString(ptr(text));
}

impl bytearray_data(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[PyByteArrayObject](op).view(1)[0].ob_start;
}

impl append_bytes(source: ptr[PyObject], data: ptr[u8], size: i64) -> i32 {
    previous = object_size(source);
    if size > PY_SSIZE_T_MAX - previous {
        PyErr_NoMemory();
        return i32(-1);
    }
    if PyByteArray_Resize(source, previous + size) < 0 {
        return i32(-1);
    }
    memcpy(ptr(bytearray_data(source) + previous), ptr(data), u64(size));
    return i32(0);
}

impl decoded_source(data: ptr[PyObject], encoding: ptr[u8]) -> ptr[PyObject] {
    if encoding {
        return PyUnicode_Decode(
            bytearray_data(data), object_size(data), encoding, ptr[u8]("strict")
        );
    }
    return PyBytes_FromObject(data);
}

impl copy_flags(flags: ptr[CompilerFlags], target: ptr[CompilerFlags]) {
    if flags {
        target.view(1)[0].cf_flags = flags.view(1)[0].cf_flags;
        target.view(1)[0].cf_feature_version = flags.view(1)[0].cf_feature_version;
    } else {
        target.view(1)[0].cf_flags = 0;
        target.view(1)[0].cf_feature_version = PY_MINOR_VERSION;
    }
}

impl parse_object(
    source: ptr[PyObject],
    filename: ptr[PyObject],
    start: i32,
    flags: ptr[CompilerFlags],
    arena: ptr
) -> ptr {
    cf = ptr[CompilerFlags](__alloca(8));
    copy_flags(flags, cf);
    cf.view(1)[0].cf_flags = cf.view(1)[0].cf_flags | CF_ONLY_AST;
    tree = _PyJac_CompileObject(source, filename, start, cf, i32(-1));
    if not tree {
        return ptr();
    }
    mode: i32 = 3;
    if start == PY_FILE_INPUT {
        mode = 0;
    } elif start == PY_EVAL_INPUT {
        mode = 1;
    } elif start == PY_SINGLE_INPUT {
        mode = 2;
    }
    result = PyAST_obj2mod(tree, arena, mode);
    object_decref(tree);
    return result;
}

impl read_file(fp: ptr, encoding: ptr[u8]) -> ptr[PyObject] {
    data = PyByteArray_FromStringAndSize(ptr[u8](), 0);
    if not data {
        return NULL;
    }
    buffer = ptr[u8](__alloca(READ_CHUNK));
    count = fread(ptr(buffer), u64(1), u64(READ_CHUNK), fp);
    while count != u64(0) {
        if append_bytes(data, buffer, i64(count)) < 0 {
            object_decref(data);
            return NULL;
        }
        count = fread(ptr(buffer), u64(1), u64(READ_CHUNK), fp);
    }
    if ferror(fp) != 0 {
        object_decref(data);
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }
    source = decoded_source(data, encoding);
    object_decref(data);
    return source;
}

impl incomplete_input -> bool {
    error = PyErr_GetRaisedException();
    message = PyObject_GetAttrString(error, ptr[u8]("msg"));
    incomplete = message
        and type_has_feature(object_type(message), Py_TPFLAGS_UNICODE_SUBCLASS)
        and PyUnicode_CompareWithASCIIString(message, ptr[u8]("incomplete input")) == 0;
    object_xdecref(message);
    PyErr_Clear();
    if incomplete {
        object_decref(error);
        return True;
    }
    PyErr_SetRaisedException(error);
    return False;
}

impl symtable_call(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    source = NULL;
    filename = NULL;
    mode = ptr[u8]();
    if PyArg_ParseTuple(
        args,
        ptr[u8]("OO&s:symtable"),
        &mut source,
        ptr(PyUnicode_FSDecoder),
        &mut filename,
        &mut mode
    )
        == 0 {
        return NULL;
    }
    length = i64(strlen(mode));
    text = jac_str_new(mode, length);
    if not text {
        object_decref(filename);
        return PyErr_NoMemory();
    }
    native = jacpy_symtable_object(
        u64(int(source)), u64(int(filename)), text, ptr[u8](text), length
    );
    jac_release(text);
    object_decref(filename);
    return native_object(native);
}

impl token_of(op: ptr[PyObject]) -> ptr[TokenizerObject] {
    return ptr[TokenizerObject](op);
}

impl token_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    reader = token_of(op).view(1)[0].reader;
    if not reader {
        return i32(0);
    }
    calls = ptr[NativeBridgeCall](
        __thread_local_block("jac_compiler_native_bridge_call_slot", 8)
    );
    calls.view(1)[0].visit_call = int(visitor);
    return calls.view(1)[0].visit_call(reader, arg);
}

impl token_clear(op: ptr[PyObject]) -> i32 {
    token = token_of(op);
    iterator = token.view(1)[0].iterator;
    if iterator {
        jacpy_token_dispose(iterator);
        jac_release(iterator);
        token.view(1)[0].iterator = ptr();
    }
    reader = token.view(1)[0].reader;
    token.view(1)[0].reader = NULL;
    object_xdecref(reader);
    return i32(0);
}

impl token_dealloc(op: ptr[PyObject]) {
    type = object_type(op);
    PyObject_GC_UnTrack(ptr(op));
    token_clear(op);
    type.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](type));
}

impl token_next(op: ptr[PyObject]) -> ptr[PyObject] {
    iterator = token_of(op).view(1)[0].iterator;
    if not iterator {
        return NULL;
    }
    return ptr[PyObject](jacpy_token_step(iterator));
}

impl tokenize_call(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    reader = NULL;
    extra = NULL;
    encoding = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwargs,
        ptr[u8]("O|$OO:TokenizerIter"),
        ptr(addressof(tokenize_keywords)),
        &mut reader,
        &mut extra,
        &mut encoding
    )
        == 0 {
        return NULL;
    }
    if not extra {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("tokenizeriter() missing required argument 'extra_tokens' (pos 2)")
        );
        return NULL;
    }
    if encoding
        and not type_has_feature(object_type(encoding), Py_TPFLAGS_UNICODE_SUBCLASS) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("tokenizeriter() argument 'encoding' must be str")
        );
        return NULL;
    }
    size: i64 = 0;
    text = ptr[u8]("");
    if encoding {
        text = PyUnicode_AsUTF8AndSize(encoding, &mut size);
    }
    if not text {
        return NULL;
    }
    if memchr(ptr(text), 0, u64(size)) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("embedded null character"));
        return NULL;
    }
    extra_flag = PyObject_IsTrue(extra);
    if extra_flag < 0 {
        return NULL;
    }
    type = PyObject_GetAttrString(module, ptr[u8]("_Iterator"));
    if not type {
        return NULL;
    }
    result = PyType_GenericAlloc(type, 0);
    object_decref(type);
    if not result {
        return NULL;
    }
    token = token_of(result);
    token.view(1)[0].reader = object_new_ref(reader);
    owner = jac_str_new(text, size);
    if not owner {
        object_decref(result);
        return PyErr_NoMemory();
    }
    iterator = jacpy_token_create(
        u64(int(reader)),
        owner,
        ptr[u8](owner),
        size,
        True if encoding else False,
        extra_flag != 0
    );
    jac_release(owner);
    token.view(1)[0].iterator = iterator;
    if not iterator {
        object_decref(result);
        if not PyErr_Occurred() {
            PyErr_NoMemory();
        }
        return NULL;
    }
    return result;
}

impl tokenize_exec(module: ptr[PyObject]) -> i32 {
    type = PyType_FromModuleAndSpec(module, addressof(token_spec), NULL);
    if not type {
        return i32(-1);
    }
    status = PyModule_AddObjectRef(module, ptr[u8]("_Iterator"), type);
    object_decref(type);
    return status;
}

impl symtable_constant(module: ptr[PyObject], name: ptr[u8], value: i64) -> bool {
    return PyModule_AddIntConstant(module, name, value) >= 0;
}

impl symtable_exec(module: ptr[PyObject]) -> i32 {
    if symtable_constant(module, ptr[u8]("USE"), 16)
        and symtable_constant(module, ptr[u8]("DEF_GLOBAL"), 1)
        and symtable_constant(module, ptr[u8]("DEF_NONLOCAL"), 8)
        and symtable_constant(module, ptr[u8]("DEF_LOCAL"), 2)
        and symtable_constant(module, ptr[u8]("DEF_PARAM"), 4)
        and symtable_constant(module, ptr[u8]("DEF_TYPE_PARAM"), 1024)
        and symtable_constant(module, ptr[u8]("DEF_FREE_CLASS"), 64)
        and symtable_constant(module, ptr[u8]("DEF_IMPORT"), 128)
        and symtable_constant(module, ptr[u8]("DEF_BOUND"), 134)
        and symtable_constant(module, ptr[u8]("DEF_ANNOT"), 256)
        and symtable_constant(module, ptr[u8]("DEF_COMP_ITER"), 512)
        and symtable_constant(module, ptr[u8]("DEF_COMP_CELL"), 2048)
        and symtable_constant(module, ptr[u8]("LOCAL"), 1)
        and symtable_constant(module, ptr[u8]("GLOBAL_EXPLICIT"), 2)
        and symtable_constant(module, ptr[u8]("GLOBAL_IMPLICIT"), 3)
        and symtable_constant(module, ptr[u8]("FREE"), 4)
        and symtable_constant(module, ptr[u8]("CELL"), 5)
        and symtable_constant(module, ptr[u8]("SCOPE_MASK"), 15)
        and symtable_constant(module, ptr[u8]("SCOPE_OFF"), 12)
        and symtable_constant(module, ptr[u8]("TYPE_FUNCTION"), 0)
        and symtable_constant(module, ptr[u8]("TYPE_CLASS"), 1)
        and symtable_constant(module, ptr[u8]("TYPE_MODULE"), 2)
        and symtable_constant(module, ptr[u8]("TYPE_ANNOTATION"), 3)
        and symtable_constant(module, ptr[u8]("TYPE_TYPE_ALIAS"), 4)
        and symtable_constant(module, ptr[u8]("TYPE_TYPE_PARAMETERS"), 5)
        and symtable_constant(module, ptr[u8]("TYPE_TYPE_VARIABLE"), 6) {
        return i32(0);
    }
    return i32(-1);
}
