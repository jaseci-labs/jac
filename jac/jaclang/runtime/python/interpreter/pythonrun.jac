import from c {
    def _PyJac_CompileString(
        text: ptr[u8],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[PyCompilerFlags],
        optimize: i32
    ) -> ptr[PyObject];  def _PyJac_CompileFile(
        fp: ptr[FILE], filename: ptr[PyObject], start: i32, flags: ptr[PyCompilerFlags]
    ) -> ptr[PyObject];  def _PyParser_InteractiveASTFromFile(
        fp: ptr[FILE],
        filename: ptr[PyObject],
        encoding: ptr[u8],
        start: i32,
        ps1: ptr[u8],
        ps2: ptr[u8],
        flags: ptr[PyCompilerFlags],
        errcode: &mut i32,
        interactive_src: &mut ptr[PyObject],
        arena: ptr
    ) -> ptr;  def _PyAST_Compile(
        tree: ptr,
        filename: ptr[PyObject],
        flags: ptr[PyCompilerFlags],
        optimize: i32,
        arena: ptr
    ) -> ptr[PyObject];  def _PyArena_New -> ptr;  def _PyArena_Free(arena: ptr);  def _Py_FdIsInteractive(
        fp: ptr[FILE], filename: ptr[PyObject]
    ) -> i32;  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: &mut ptr[PyObject]
    ) -> i32;  def _PySys_SetAttr(key: ptr[PyObject], v: ptr[PyObject]) -> i32;  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], format_: ptr[u8], *args: any
    ) -> i32;  def PySys_Audit(event: ptr[u8], argFormat: ptr[u8], *args: any) -> i32;  def PySys_WriteStderr(
        format: ptr[u8], *args: any
    );  def PyImport_AddModuleRef(name: ptr[u8]) -> ptr[PyObject];  def PyImport_GetMagicNumber -> i64;  def _PyImport_GetImportlibExternalLoader(
        interp: ptr[u8], loader_name: ptr[u8]
    ) -> ptr[PyObject];  def PyMarshal_ReadLongFromFile(fp: ptr[FILE]) -> i64;  def PyMarshal_ReadLastObjectFromFile(
        fp: ptr[FILE]
    ) -> ptr[PyObject];  def PyDict_ContainsString(
        op: ptr[PyObject], key: ptr[u8]
    ) -> i32;  def PyEval_EvalCode(
        co: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
    ) -> ptr[PyObject];  def Py_Exit(sts: i32);  def _Py_GetConfig -> ptr[u8];  def PyFile_WriteObject(
        v: ptr[PyObject], f: ptr[PyObject], flags: i32
    ) -> i32;  def PyFile_WriteString(s: ptr[u8], f: ptr[PyObject]) -> i32;  def _PyFile_Flush(
        file: ptr[PyObject]
    ) -> i32;  def PyObject_Print(op: ptr[PyObject], fp: ptr, flags: i32) -> i32;  def PyType_GetQualName(
        type: ptr[PyTypeObject]
    ) -> ptr[PyObject];  def PyException_GetCause(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def PyException_GetContext(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyTraceBack_Print(
        v: ptr[PyObject], header: ptr[u8], f: ptr[PyObject]
    ) -> i32;  def _PyObject_Dump(op: ptr[PyObject]);  def Py_EnterRecursiveCall(
        where: ptr[u8]
    ) -> i32;  def Py_LeaveRecursiveCall;  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyErr_Clear(tstate: ptr[PyThreadState]);  def _PyUnicode_Equal(
        str1: ptr[PyObject], str2: ptr[PyObject]
    ) -> i32;  def PyUnicode_Tailmatch(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        start: i64,
        end: i64,
        direction: i32
    ) -> i64;  def ftell(stream: ptr[FILE]) -> i64;  def fread(
        buffer: ptr, size: u64, count: u64, stream: ptr[FILE]
    ) -> u64;  def rewind(stream: ptr[FILE]);  def fclose(stream: ptr[FILE]) -> i32;  def fflush(
        stream: ptr
    ) -> i32;  def fputs(text: ptr[u8], stream: ptr) -> i32;  def strlen(
        text: ptr[u8]
    ) -> u64;  def jacpy_stdio_stream(stream: i32) -> ptr;  obj RunStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0;
    }  def jacpy_stack_address(slots: &mut RunStack) -> int;
}

glob:priv E_EOF: i32 = 11,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

def:priv id_object(offset: i64) -> ptr[PyObject];

def:priv tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def:priv stdio(stream: i32) -> ptr;

def:priv is_unicode(op: ptr[PyObject]) -> bool;

def:priv is_bytes(op: ptr[PyObject]) -> bool;

def:priv is_bytearray(op: ptr[PyObject]) -> bool;

def:priv is_long(op: ptr[PyObject]) -> bool;

def:priv is_dict(op: ptr[PyObject]) -> bool;

def:priv is_exception_instance(op: ptr[PyObject]) -> bool;

def:priv is_code(op: ptr[PyObject]) -> bool;

def:priv init_compiler_flags(cf: ptr[u8]) -> ptr[PyCompilerFlags];

def:priv compiler_flags_slot(flags: ptr[PyCompilerFlags]) -> ptr[i32];

def:priv jac_eval_compiled(
    code: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
) -> ptr[PyObject];

def:priv pyrun_one_parse_ast(
    fp: ptr[FILE], filename: ptr[PyObject], flags: ptr[PyCompilerFlags], arena: ptr
) -> tuple[i32, ptr, ptr[PyObject]];

def:priv PyRun_InteractiveOneObjectEx(
    fp: ptr[FILE], filename: ptr[PyObject], flags: ptr[PyCompilerFlags]
) -> i32;

def:priv maybe_pyc_file(fp: ptr[FILE], filename: ptr[PyObject], closeit: i32) -> i32;

def:priv set_main_loader(
    d: ptr[PyObject], filename: ptr[PyObject], loader_name: ptr[u8]
) -> i32;

def:priv parse_exit_code(code: ptr[PyObject]) -> tuple[bool, i32];

def:priv handle_exit_and_interrupt -> tuple[i32, i32];

def:priv handle_system_exit;

def:priv set_sys_attr_or_clear(
    tstate: ptr[PyThreadState], name: ptr[PyObject], value: ptr[PyObject]
);

def:priv _PyErr_PrintEx(tstate: ptr[PyThreadState], set_sys_last_vars: i32);

def:priv print_exception_invalid_type(f: ptr[PyObject], value: ptr[PyObject]) -> i32;

def:priv print_exception_traceback(f: ptr[PyObject], value: ptr[PyObject]) -> i32;

def:priv print_exception_file_and_line(f: ptr[PyObject], value: ptr[PyObject]) -> i32;

def:priv print_exception_message(
    f: ptr[PyObject], type: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def:priv print_exception(f: ptr[PyObject], value: ptr[PyObject]) -> i32;

def:priv print_chained(
    f: ptr[PyObject], seen: ptr[PyObject], value: ptr[PyObject], message: ptr[u8]
) -> i32;

def:priv print_exception_seen_lookup(
    seen: ptr[PyObject], value: ptr[PyObject]
) -> bool;

def:priv print_exception_cause_and_context(
    f: ptr[PyObject], seen: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def:priv print_exception_recursive(
    f: ptr[PyObject], seen: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def:priv _PyRun_StringFlagsWithName(
    text: ptr[u8],
    name: ptr[PyObject],
    start: i32,
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    flags: ptr[PyCompilerFlags],
    generate_new_source: i32
) -> ptr[PyObject];

def:priv pyrun_file(
    fp: ptr[FILE],
    filename: ptr[PyObject],
    start: i32,
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    closeit: i32,
    flags: ptr[PyCompilerFlags]
) -> ptr[PyObject];

def:priv flush_io_stream(name: ptr[PyObject]);

def:priv flush_io;

def:priv run_eval_code_obj(
    tstate: ptr[PyThreadState],
    co: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject]
) -> ptr[PyObject];

def:priv get_interactive_filename(
    filename: ptr[PyObject], count: i64
) -> ptr[PyObject];

def:priv run_mod(
    mod: ptr,
    filename: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    flags: ptr[PyCompilerFlags],
    arena: ptr,
    interactive_src: ptr[PyObject],
    generate_new_source: i32
) -> ptr[PyObject];

def:priv run_pyc_file(
    fp: ptr[FILE],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    flags: ptr[PyCompilerFlags]
) -> ptr[PyObject];

import from c {
    def _PyRun_AnyFileObject(
        fp: ptr[FILE],
        filename: ptr[PyObject],
        closeit: i32,
        flags: ptr[PyCompilerFlags]
    ) -> i32 {
        decref_filename = False;
        name = filename;
        if not name {
            name = PyUnicode_FromString(ptr[u8]("???"));
            if not name {
                PyErr_Print();
                return -1;
            }
            decref_filename = True;
        }

        res: i32 = 0;
        if _Py_FdIsInteractive(fp, name) != 0 {
            res = _PyRun_InteractiveLoopObject(fp, name, flags);
            if closeit != 0 {
                fclose(fp);
            }
        } else {
            res = _PyRun_SimpleFileObject(fp, name, closeit, flags);
        }

        if decref_filename {
            object_decref(name);
        }
        return res;
    }  def PyRun_AnyFileExFlags(
        fp: ptr[FILE], filename: ptr[u8], closeit: i32, flags: ptr[PyCompilerFlags]
    ) -> i32 {
        filename_obj = NULL;
        if filename {
            filename_obj = PyUnicode_DecodeFSDefault(filename);
            if not filename_obj {
                PyErr_Print();
                return -1;
            }
        }
        res = _PyRun_AnyFileObject(fp, filename_obj, closeit, flags);
        object_xdecref(filename_obj);
        return res;
    }  def _PyRun_InteractiveLoopObject(
        fp: ptr[FILE], filename: ptr[PyObject], flags_in: ptr[PyCompilerFlags]
    ) -> i32 {
        slots: own RunStack = RunStack();
        flags = flags_in;
        if not flags {
            flags = init_compiler_flags(ptr[u8](jacpy_stack_address(&mut slots)));
        }

        v = NULL;
        if _PySys_GetOptionalAttr(id_object(_Py_ID_ps1), &mut v) < 0 {
            PyErr_Print();
            return -1;
        }
        if not v {
            v = PyUnicode_FromString(ptr[u8](">>> "));
            if not v {
                PyErr_Clear();
            }
            if _PySys_SetAttr(id_object(_Py_ID_ps1), v) < 0 {
                PyErr_Clear();
            }
        }
        object_xdecref(v);
        v = NULL;
        if _PySys_GetOptionalAttr(id_object(_Py_ID_ps2), &mut v) < 0 {
            PyErr_Print();
            return -1;
        }
        if not v {
            v = PyUnicode_FromString(ptr[u8]("... "));
            if not v {
                PyErr_Clear();
            }
            if _PySys_SetAttr(id_object(_Py_ID_ps2), v) < 0 {
                PyErr_Clear();
            }
        }
        object_xdecref(v);

        err: i32 = 0;
        ret: i32 = 0;
        nomem_count: i32 = 0;
        while True {
            ret = PyRun_InteractiveOneObjectEx(fp, filename, flags);
            if ret == -1 and PyErr_Occurred() {
                if PyErr_ExceptionMatches(PyExc_MemoryError) != 0 {
                    nomem_count += 1;
                    if nomem_count > 16 {
                        PyErr_Clear();
                        err = -1;
                        break;
                    }
                } else {
                    nomem_count = 0;
                }
                PyErr_Print();
                flush_io();
            } else {
                nomem_count = 0;
            }
            if ret == E_EOF {
                break;
            }
        }
        return err;
    }  def PyRun_InteractiveLoopFlags(
        fp: ptr[FILE], filename: ptr[u8], flags: ptr[PyCompilerFlags]
    ) -> i32 {
        filename_obj = PyUnicode_DecodeFSDefault(filename);
        if not filename_obj {
            PyErr_Print();
            return -1;
        }

        err = _PyRun_InteractiveLoopObject(fp, filename_obj, flags);
        object_decref(filename_obj);
        return err;
    }  def PyRun_InteractiveOneObject(
        fp: ptr[FILE], filename: ptr[PyObject], flags: ptr[PyCompilerFlags]
    ) -> i32 {
        res = PyRun_InteractiveOneObjectEx(fp, filename, flags);
        if res == -1 {
            PyErr_Print();
            flush_io();
        }
        return res;
    }  def PyRun_InteractiveOneFlags(
        fp: ptr[FILE], filename_str: ptr[u8], flags: ptr[PyCompilerFlags]
    ) -> i32 {
        filename = PyUnicode_DecodeFSDefault(filename_str);
        if not filename {
            PyErr_Print();
            return -1;
        }
        res = PyRun_InteractiveOneObject(fp, filename, flags);
        object_decref(filename);
        return res;
    }  def _PyRun_SimpleFileObject(
        fp: ptr[FILE],
        filename: ptr[PyObject],
        closeit: i32,
        flags: ptr[PyCompilerFlags]
    ) -> i32 {
        ret: i32 = -1;

        main_module = PyImport_AddModuleRef(ptr[u8]("__main__"));
        if not main_module {
            return -1;
        }
        dct = PyModule_GetDict(main_module);

        set_file_name = False;
        while True {
            has_file = PyDict_ContainsString(dct, ptr[u8]("__file__"));
            if has_file < 0 {
                break;
            }
            if has_file == 0 {
                if PyDict_SetItemString(dct, ptr[u8]("__file__"), filename) < 0 {
                    break;
                }
                if PyDict_SetItemString(dct, ptr[u8]("__cached__"), Py_None) < 0 {
                    break;
                }
                set_file_name = True;
            }

            pyc = maybe_pyc_file(fp, filename, closeit);
            if pyc < 0 {
                break;
            }

            v = NULL;
            if pyc != 0 {
                if closeit != 0 {
                    fclose(fp);
                }

                pyc_fp = Py_fopen(filename, ptr[u8]("rb"));
                if not pyc_fp {
                    fputs(ptr[u8]("python: Can't reopen .pyc file\n"), stdio(2));
                    break;
                }

                if set_main_loader(dct, filename, ptr[u8]("SourcelessFileLoader"))
                    < 0 {
                    fputs(
                        ptr[u8]("python: failed to set __main__.__loader__\n"), stdio(2)
                    );
                    ret = -1;
                    fclose(pyc_fp);
                    break;
                }
                v = run_pyc_file(pyc_fp, dct, dct, flags);
            } else {
                if (
                    not is_unicode(filename)
                    or PyUnicode_EqualToUTF8(filename, ptr[u8]("<stdin>")) == 0
                )
                    and set_main_loader(dct, filename, ptr[u8]("SourceFileLoader"))
                        < 0 {
                    fputs(
                        ptr[u8]("python: failed to set __main__.__loader__\n"), stdio(2)
                    );
                    ret = -1;
                    break;
                }
                v = pyrun_file(fp, filename, Py_file_input, dct, dct, closeit, flags);
            }
            flush_io();
            if not v {
                old_main = main_module;
                main_module = NULL;
                object_decref(old_main);
                PyErr_Print();
                break;
            }
            object_decref(v);
            ret = 0;
            break;
        }

        if set_file_name {
            popped = NULL;
            if PyDict_PopString(dct, ptr[u8]("__file__"), &mut popped) < 0 {
                PyErr_Print();
            }
            object_xdecref(popped);
            popped = NULL;
            if PyDict_PopString(dct, ptr[u8]("__cached__"), &mut popped) < 0 {
                PyErr_Print();
            }
            object_xdecref(popped);
        }
        object_xdecref(main_module);
        return ret;
    }  def PyRun_SimpleFileExFlags(
        fp: ptr[FILE], filename: ptr[u8], closeit: i32, flags: ptr[PyCompilerFlags]
    ) -> i32 {
        filename_obj = PyUnicode_DecodeFSDefault(filename);
        if not filename_obj {
            return -1;
        }
        res = _PyRun_SimpleFileObject(fp, filename_obj, closeit, flags);
        object_decref(filename_obj);
        return res;
    }  def _PyRun_SimpleStringFlagsWithName(
        command: ptr[u8], name: ptr[u8], flags: ptr[PyCompilerFlags]
    ) -> i32 {
        main_module = PyImport_AddModuleRef(ptr[u8]("__main__"));
        if not main_module {
            return -1;
        }
        dct = PyModule_GetDict(main_module);

        res = NULL;
        if not name {
            res = PyRun_StringFlags(command, Py_file_input, dct, dct, flags);
        } else {
            the_name = PyUnicode_FromString(name);
            if not the_name {
                PyErr_Print();
                return -1;
            }
            res = _PyRun_StringFlagsWithName(
                command, the_name, Py_file_input, dct, dct, flags, 0
            );
            object_decref(the_name);
        }
        object_decref(main_module);
        if not res {
            PyErr_Print();
            return -1;
        }

        object_decref(res);
        return 0;
    }  def PyRun_SimpleStringFlags(
        command: ptr[u8], flags: ptr[PyCompilerFlags]
    ) -> i32 {
        return _PyRun_SimpleStringFlagsWithName(command, ptr[u8](), flags);
    }  def _Py_HandleSystemExitAndKeyboardInterrupt(exitcode_p: ptr[i32]) -> i32 {
        (handled, exitcode) = handle_exit_and_interrupt();
        if handled != 0 {
            exitcode_p.view(1)[0] = exitcode;
        }
        return handled;
    }  def _PyErr_Print(tstate: ptr[PyThreadState]) {
        _PyErr_PrintEx(tstate, 1);
    }  def PyErr_PrintEx(set_sys_last_vars: i32) {
        _PyErr_PrintEx(current_tstate(), set_sys_last_vars);
    }  def PyErr_Print {
        PyErr_PrintEx(1);
    }  def _PyErr_Display(
        file: ptr[PyObject],
        unused: ptr[PyObject],
        value: ptr[PyObject],
        tb: ptr[PyObject]
    ) {
        if is_exception_instance(value)
            and tb
            and int(object_type(tb)) == int(addressof(PyTraceBack_Type)) {
            cur_tb = PyException_GetTraceback(value);
            if not cur_tb {
                PyException_SetTraceback(value, tb);
            } else {
                object_decref(cur_tb);
            }
        }

        print_exception_fn = PyImport_ImportModuleAttrString(
            "traceback", "_print_exception_bltin"
        );
        if print_exception_fn and PyCallable_Check(print_exception_fn) != 0 {
            result = PyObject_CallOneArg(print_exception_fn, value);
            object_xdecref(print_exception_fn);
            if result {
                object_decref(result);
                return;
            }
        } else {
            object_xdecref(print_exception_fn);
        }

        PyErr_Clear();

        seen = PySet_New(NULL);
        if not seen {
            PyErr_Clear();
        }
        if print_exception_recursive(file, seen, value) < 0 {
            PyErr_Clear();
            _PyObject_Dump(value);
            fputs(ptr[u8]("lost sys.stderr\n"), stdio(2));
        }
        object_xdecref(seen);

        if _PyFile_Flush(file) < 0 {
            PyErr_Clear();
        }
    }  def PyErr_Display(
        unused: ptr[PyObject], value: ptr[PyObject], tb: ptr[PyObject]
    ) {
        file = NULL;
        if _PySys_GetOptionalAttr(id_object(_Py_ID_stderr), &mut file) < 0 {
            exc = PyErr_GetRaisedException();
            _PyObject_Dump(value);
            fputs(ptr[u8]("lost sys.stderr\n"), stdio(2));
            _PyObject_Dump(exc);
            object_decref(exc);
            return;
        }
        if not file {
            _PyObject_Dump(value);
            fputs(ptr[u8]("lost sys.stderr\n"), stdio(2));
            return;
        }
        if file == Py_None {
            object_decref(file);
            return;
        }
        _PyErr_Display(file, NULL, value, tb);
        object_decref(file);
    }  def _PyErr_DisplayException(file: ptr[PyObject], exc: ptr[PyObject]) {
        _PyErr_Display(file, NULL, exc, NULL);
    }  def PyErr_DisplayException(exc: ptr[PyObject]) {
        PyErr_Display(NULL, exc, NULL);
    }  def PyRun_StringFlags(
        text: ptr[u8],
        start: i32,
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        flags: ptr[PyCompilerFlags]
    ) -> ptr[PyObject] {
        return _PyRun_StringFlagsWithName(text, NULL, start, globals, locals, flags, 0);
    }  def PyRun_FileExFlags(
        fp: ptr[FILE],
        filename: ptr[u8],
        start: i32,
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        closeit: i32,
        flags: ptr[PyCompilerFlags]
    ) -> ptr[PyObject] {
        filename_obj = PyUnicode_DecodeFSDefault(filename);
        if not filename_obj {
            return NULL;
        }

        res = pyrun_file(fp, filename_obj, start, globals, locals, closeit, flags);
        object_decref(filename_obj);
        return res;
    }  def Py_CompileStringObject(
        text: ptr[u8],
        filename: ptr[PyObject],
        start: i32,
        flags: ptr[PyCompilerFlags],
        optimize: i32
    ) -> ptr[PyObject] {
        return _PyJac_CompileString(text, filename, start, flags, optimize);
    }  def Py_CompileStringExFlags(
        text: ptr[u8],
        filename_str: ptr[u8],
        start: i32,
        flags: ptr[PyCompilerFlags],
        optimize: i32
    ) -> ptr[PyObject] {
        filename = PyUnicode_DecodeFSDefault(filename_str);
        if not filename {
            return NULL;
        }
        co = Py_CompileStringObject(text, filename, start, flags, optimize);
        object_decref(filename);
        return co;
    }  def _PyObject_SupportedAsScript(cmd: ptr[PyObject]) -> i32 {
        if is_unicode(cmd) {
            return 1;
        } elif is_bytes(cmd) {
            return 1;
        } elif is_bytearray(cmd) {
            return 1;
        } elif PyObject_CheckBuffer(cmd) != 0 {
            return 1;
        }
        return 0;
    }  def _Py_SourceAsString(
        cmd: ptr[PyObject],
        funcname: ptr[u8],
        what: ptr[u8],
        cf: ptr[PyCompilerFlags],
        cmd_copy: ptr[ptr[PyObject]]
    ) -> ptr[u8] {
        text = ptr[u8]();
        size: i64 = 0;

        cmd_copy.view(1)[0] = NULL;
        if is_unicode(cmd) {
            slot = compiler_flags_slot(cf);
            slot.view(1)[0] = slot.view(1)[0] | PyCF_IGNORE_COOKIE;
            text = PyUnicode_AsUTF8AndSize(cmd, &mut size);
            if not text {
                return ptr[u8]();
            }
        } elif is_bytes(cmd) {
            text = PyBytes_AsString(cmd);
            size = object_size(cmd);
        } elif is_bytearray(cmd) {
            text = PyByteArray_AsString(cmd);
            size = object_size(cmd);
        } else {
            slots: own RunStack = RunStack();
            view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
            if PyObject_GetBuffer(cmd, view, PyBUF_SIMPLE) == 0 {
                copy = PyBytes_FromStringAndSize(
                    ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
                );
                PyBuffer_Release(view);
                if not copy {
                    return ptr[u8]();
                }
                cmd_copy.view(1)[0] = copy;
                text = PyBytes_AsString(copy);
                size = object_size(copy);
            } else {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("%s() arg 1 must be a %s object"),
                    funcname,
                    what
                );
                return ptr[u8]();
            }
        }

        if strlen(text) != u64(size) {
            PyErr_SetString(
                PyExc_SyntaxError,
                ptr[u8]("source code string cannot contain null bytes")
            );
            old = cmd_copy.view(1)[0];
            cmd_copy.view(1)[0] = NULL;
            object_xdecref(old);
            return ptr[u8]();
        }
        return text;
    }  def PyRun_AnyFile(fp: ptr[FILE], name: ptr[u8]) -> i32 {
        return PyRun_AnyFileExFlags(fp, name, 0, ptr[PyCompilerFlags]());
    }  def PyRun_AnyFileEx(fp: ptr[FILE], name: ptr[u8], closeit: i32) -> i32 {
        return PyRun_AnyFileExFlags(fp, name, closeit, ptr[PyCompilerFlags]());
    }  def PyRun_AnyFileFlags(
        fp: ptr[FILE], name: ptr[u8], flags: ptr[PyCompilerFlags]
    ) -> i32 {
        return PyRun_AnyFileExFlags(fp, name, 0, flags);
    }  def PyRun_File(
        fp: ptr[FILE], p: ptr[u8], s: i32, g: ptr[PyObject], l: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyRun_FileExFlags(fp, p, s, g, l, 0, ptr[PyCompilerFlags]());
    }  def PyRun_FileEx(
        fp: ptr[FILE], p: ptr[u8], s: i32, g: ptr[PyObject], l: ptr[PyObject], c: i32
    ) -> ptr[PyObject] {
        return PyRun_FileExFlags(fp, p, s, g, l, c, ptr[PyCompilerFlags]());
    }  def PyRun_FileFlags(
        fp: ptr[FILE],
        p: ptr[u8],
        s: i32,
        g: ptr[PyObject],
        l: ptr[PyObject],
        flags: ptr[PyCompilerFlags]
    ) -> ptr[PyObject] {
        return PyRun_FileExFlags(fp, p, s, g, l, 0, flags);
    }  def PyRun_SimpleFile(f: ptr[FILE], p: ptr[u8]) -> i32 {
        return PyRun_SimpleFileExFlags(f, p, 0, ptr[PyCompilerFlags]());
    }  def PyRun_SimpleFileEx(f: ptr[FILE], p: ptr[u8], c: i32) -> i32 {
        return PyRun_SimpleFileExFlags(f, p, c, ptr[PyCompilerFlags]());
    }  def PyRun_String(
        text: ptr[u8], s: i32, g: ptr[PyObject], l: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyRun_StringFlags(text, s, g, l, ptr[PyCompilerFlags]());
    }  def PyRun_SimpleString(s: ptr[u8]) -> i32 {
        return PyRun_SimpleStringFlags(s, ptr[PyCompilerFlags]());
    }  def Py_CompileString(text: ptr[u8], p: ptr[u8], s: i32) -> ptr[PyObject] {
        return Py_CompileStringExFlags(text, p, s, ptr[PyCompilerFlags](), -1);
    }  def Py_CompileStringFlags(
        text: ptr[u8], p: ptr[u8], s: i32, flags: ptr[PyCompilerFlags]
    ) -> ptr[PyObject] {
        return Py_CompileStringExFlags(text, p, s, flags, -1);
    }  def PyRun_InteractiveOne(f: ptr[FILE], p: ptr[u8]) -> i32 {
        return PyRun_InteractiveOneFlags(f, p, ptr[PyCompilerFlags]());
    }  def PyRun_InteractiveLoop(f: ptr[FILE], p: ptr[u8]) -> i32 {
        return PyRun_InteractiveLoopFlags(f, p, ptr[PyCompilerFlags]());
    }
}

impl id_object(offset: i64) -> ptr[PyObject] {
    return ptr[PyObject](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_GLOBAL_STRINGS + offset
    );
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl stdio(stream: i32) -> ptr {
    return jacpy_stdio_stream(stream);
}

impl is_unicode(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl is_bytes(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl is_bytearray(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyByteArray_Type)));
}

impl is_long(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl is_dict(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl is_exception_instance(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}

impl is_code(op: ptr[PyObject]) -> bool {
    return int(object_type(op)) == int(addressof(PyCode_Type));
}

impl init_compiler_flags(cf: ptr[u8]) -> ptr[PyCompilerFlags] {
    ptr[i32](cf + PyCompilerFlags_CF_FLAGS).view(1)[0] = 0;
    ptr[i32](cf + PyCompilerFlags_CF_FEATURE_VERSION).view(1)[0] = PY_MINOR_VERSION;
    return ptr[PyCompilerFlags](cf);
}

impl compiler_flags_slot(flags: ptr[PyCompilerFlags]) -> ptr[i32] {
    return ptr[i32](ptr[u8](flags) + PyCompilerFlags_CF_FLAGS);
}

impl jac_eval_compiled(
    code: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
) -> ptr[PyObject] {
    if not code {
        return NULL;
    }
    if not is_code(code) {
        object_decref(code);
        PyErr_SetString(PyExc_TypeError, ptr[u8]("execution requires a code object"));
        return NULL;
    }
    result = NULL;
    if PySys_Audit(ptr[u8]("exec"), ptr[u8]("O"), code) == 0 {
        result = run_eval_code_obj(current_tstate(), code, globals, locals);
    }
    object_decref(code);
    return result;
}

impl pyrun_one_parse_ast(
    fp: ptr[FILE], filename: ptr[PyObject], flags: ptr[PyCompilerFlags], arena: ptr
) -> tuple[i32, ptr, ptr[PyObject]] {
    attr = NULL;
    encoding_obj = NULL;
    encoding = ptr[u8]();
    if int(fp) == int(stdio(0)) {
        if _PySys_GetOptionalAttr(id_object(_Py_ID_stdin), &mut attr) < 0 {
            PyErr_Clear();
        } elif attr and attr != Py_None {
            if PyObject_GetOptionalAttr(
                attr, id_object(_Py_ID_encoding), &mut encoding_obj
            )
                < 0 {
                PyErr_Clear();
            } elif encoding_obj and is_unicode(encoding_obj) {
                encoding = PyUnicode_AsUTF8(encoding_obj);
                if not encoding {
                    PyErr_Clear();
                }
            }
        }
        object_xdecref(attr);
    }

    ps1_obj = NULL;
    ps1 = ptr[u8]("");
    attr = NULL;
    if _PySys_GetOptionalAttr(id_object(_Py_ID_ps1), &mut attr) < 0 {
        PyErr_Clear();
    } elif attr {
        ps1_obj = PyObject_Str(attr);
        object_decref(attr);
        if not ps1_obj {
            PyErr_Clear();
        } elif is_unicode(ps1_obj) {
            ps1 = PyUnicode_AsUTF8(ps1_obj);
            if not ps1 {
                PyErr_Clear();
                ps1 = ptr[u8]("");
            }
        }
    }

    ps2_obj = NULL;
    ps2 = ptr[u8]("");
    attr = NULL;
    if _PySys_GetOptionalAttr(id_object(_Py_ID_ps2), &mut attr) < 0 {
        PyErr_Clear();
    } elif attr {
        ps2_obj = PyObject_Str(attr);
        object_decref(attr);
        if not ps2_obj {
            PyErr_Clear();
        } elif is_unicode(ps2_obj) {
            ps2 = PyUnicode_AsUTF8(ps2_obj);
            if not ps2 {
                PyErr_Clear();
                ps2 = ptr[u8]("");
            }
        }
    }

    errcode: i32 = 0;
    interactive_src = NULL;
    mod = _PyParser_InteractiveASTFromFile(
        fp,
        filename,
        encoding,
        Py_single_input,
        ps1,
        ps2,
        flags,
        &mut errcode,
        &mut interactive_src,
        arena
    );
    object_xdecref(ps1_obj);
    object_xdecref(ps2_obj);
    object_xdecref(encoding_obj);

    if not mod {
        if errcode == E_EOF {
            PyErr_Clear();
            return (E_EOF, mod, interactive_src);
        }
        return (i32(-1), mod, interactive_src);
    }
    return (i32(0), mod, interactive_src);
}

impl PyRun_InteractiveOneObjectEx(
    fp: ptr[FILE], filename: ptr[PyObject], flags: ptr[PyCompilerFlags]
) -> i32 {
    arena = _PyArena_New();
    if not arena {
        return -1;
    }

    (parse_res, mod, interactive_src) = pyrun_one_parse_ast(fp, filename, flags, arena);
    if parse_res != 0 {
        _PyArena_Free(arena);
        return parse_res;
    }

    main_module = PyImport_AddModuleRef(ptr[u8]("__main__"));
    if not main_module {
        _PyArena_Free(arena);
        return -1;
    }
    main_dict = PyModule_GetDict(main_module);

    res = run_mod(
        mod, filename, main_dict, main_dict, flags, arena, interactive_src, 1
    );
    object_incref(interactive_src);
    _PyArena_Free(arena);
    object_decref(main_module);
    if not res {
        tstate = current_tstate();
        exc = _PyErr_GetRaisedException(tstate);
        if PyType_IsSubtype(ptr[PyObject](object_type(exc)), PyExc_SyntaxError) != 0 {
            xs = PyUnicode_Splitlines(interactive_src, 1);
            if xs {
                exc_lineno = PyObject_GetAttr(exc, id_object(_Py_ID_lineno));
                if not exc_lineno {
                    object_decref(xs);
                } else {
                    n = PyLong_AsInt(exc_lineno);
                    object_decref(exc_lineno);
                    if n <= 0 or i64(n) > object_size(xs) {
                        object_decref(xs);
                    } else {
                        line = PyList_GetItem(xs, i64(n) - 1);
                        PyObject_SetAttr(exc, id_object(_Py_ID_text), line);
                        object_decref(xs);
                    }
                }
            }
        }
        object_decref(interactive_src);
        _PyErr_SetRaisedException(tstate, exc);
        return -1;
    }
    object_decref(interactive_src);
    object_decref(res);

    flush_io();
    return 0;
}

impl maybe_pyc_file(fp: ptr[FILE], filename: ptr[PyObject], closeit: i32) -> i32 {
    ext = PyUnicode_FromString(ptr[u8](".pyc"));
    if not ext {
        return -1;
    }
    endswith = PyUnicode_Tailmatch(filename, ext, 0, PY_SSIZE_T_MAX, 1);
    object_decref(ext);
    if endswith != 0 {
        return 1;
    }

    if closeit == 0 {
        return 0;
    }

    halfmagic = PyImport_GetMagicNumber() & 0xFFFF;
    slots: own RunStack = RunStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    ispyc: i32 = 0;
    if ftell(fp) == 0 {
        if fread(ptr(buf), 1, 2, fp) == 2
            and ((i64(buf.view(2)[1]) << 8) | i64(buf.view(2)[0])) == halfmagic {
            ispyc = 1;
        }
        rewind(fp);
    }
    return ispyc;
}

impl set_main_loader(
    d: ptr[PyObject], filename: ptr[PyObject], loader_name: ptr[u8]
) -> i32 {
    loader_type = _PyImport_GetImportlibExternalLoader(current_interp(), loader_name);
    if not loader_type {
        return -1;
    }

    loader = PyObject_CallFunction(loader_type, "sO", ptr[u8]("__main__"), filename);
    object_decref(loader_type);
    if not loader {
        return -1;
    }

    if PyDict_SetItemString(d, ptr[u8]("__loader__"), loader) < 0 {
        object_decref(loader);
        return -1;
    }
    object_decref(loader);
    return 0;
}

impl parse_exit_code(code: ptr[PyObject]) -> tuple[bool, i32] {
    if is_long(code) {
        exitcode = i32.wrap(PyLong_AsLongLong(code));
        if exitcode == -1 and PyErr_Occurred() {
            PyErr_Clear();
            return (True, i32(-1));
        }
        return (True, exitcode);
    } elif code == Py_None {
        return (True, i32(0));
    }
    return (False, i32(0));
}

impl handle_exit_and_interrupt -> tuple[i32, i32] {
    if PyErr_ExceptionMatches(PyExc_KeyboardInterrupt) != 0 {
        __atomic_store_i32(
            int(ptr[u8](addressof(_PyRuntime)))
                + _PyRuntimeState_SIGNALS_UNHANDLED_KEYBOARD_INTERRUPT,
            i32(1),
            5
        );
        return (i32(0), i32(0));
    }

    inspect = ptr[i32](_Py_GetConfig() + PyConfig_INSPECT).view(1)[0];
    if inspect != 0 {
        return (i32(0), i32(0));
    }

    if PyErr_ExceptionMatches(PyExc_SystemExit) == 0 {
        return (i32(0), i32(0));
    }

    fflush(stdio(1));

    exc = PyErr_GetRaisedException();
    exitcode: i32 = 0;

    code = PyObject_GetAttr(exc, id_object(_Py_ID_code));
    if not code {
        PyErr_Clear();
    } else {
        (handled, parsed) = parse_exit_code(code);
        if handled {
            object_decref(code);
            object_decref(exc);
            return (i32(1), parsed);
        }
        object_decref(exc);
        exc = code;
    }

    sys_stderr = NULL;
    if _PySys_GetOptionalAttr(id_object(_Py_ID_stderr), &mut sys_stderr) < 0 {
        PyErr_Clear();
    } elif sys_stderr and sys_stderr != Py_None {
        if PyFile_WriteObject(exc, sys_stderr, Py_PRINT_RAW) < 0 {
            PyErr_Clear();
        }
    } else {
        if PyObject_Print(exc, stdio(2), Py_PRINT_RAW) < 0 {
            PyErr_Clear();
        }
        fflush(stdio(2));
    }
    PySys_WriteStderr(ptr[u8]("\n"));
    object_xdecref(sys_stderr);
    object_decref(exc);
    exitcode = 1;
    return (i32(1), exitcode);
}

impl handle_system_exit {
    (handled, exitcode) = handle_exit_and_interrupt();
    if handled != 0 {
        Py_Exit(exitcode);
    }
}

impl set_sys_attr_or_clear(
    tstate: ptr[PyThreadState], name: ptr[PyObject], value: ptr[PyObject]
) {
    if _PySys_SetAttr(name, value) < 0 {
        _PyErr_Clear(tstate);
    }
}

impl _PyErr_PrintEx(tstate: ptr[PyThreadState], set_sys_last_vars: i32) {
    typ = NULL;
    tb = NULL;
    hook = NULL;
    handle_system_exit();

    exc = _PyErr_GetRaisedException(tstate);
    if exc {
        typ = object_new_ref(ptr[PyObject](object_type(exc)));
        tb = PyException_GetTraceback(exc);
        if not tb {
            tb = object_new_ref(Py_None);
        }

        if set_sys_last_vars != 0 {
            set_sys_attr_or_clear(tstate, id_object(_Py_ID_last_exc), exc);

            set_sys_attr_or_clear(tstate, id_object(_Py_ID_last_type), typ);
            set_sys_attr_or_clear(tstate, id_object(_Py_ID_last_value), exc);
            set_sys_attr_or_clear(tstate, id_object(_Py_ID_last_traceback), tb);
        }
        if _PySys_GetOptionalAttr(id_object(_Py_ID_excepthook), &mut hook) < 0 {
            PyErr_Clear();
        }
        hook_arg = hook or Py_None;
        proceed = True;
        if _PySys_Audit(
            tstate, ptr[u8]("sys.excepthook"), ptr[u8]("OOOO"), hook_arg, typ, exc, tb
        )
            < 0 {
            if PyErr_ExceptionMatches(PyExc_RuntimeError) != 0 {
                PyErr_Clear();
                proceed = False;
            } else {
                PyErr_FormatUnraisable(ptr[u8]("Exception ignored in audit hook"));
            }
        }
        if proceed {
            if hook {
                slots: own RunStack = RunStack();
                args = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
                args.view(3)[0] = typ;
                args.view(3)[1] = exc;
                args.view(3)[2] = tb;
                result = PyObject_Vectorcall(hook, args, 3, NULL);
                if not result {
                    handle_system_exit();

                    exc2 = _PyErr_GetRaisedException(tstate);
                    fflush(stdio(1));
                    PySys_WriteStderr(ptr[u8]("Error in sys.excepthook:\n"));
                    PyErr_DisplayException(exc2);
                    PySys_WriteStderr(ptr[u8]("\nOriginal exception was:\n"));
                    PyErr_DisplayException(exc);
                    object_decref(exc2);
                } else {
                    object_decref(result);
                }
            } else {
                PySys_WriteStderr(ptr[u8]("sys.excepthook is missing\n"));
                PyErr_DisplayException(exc);
            }
        }
    }

    object_xdecref(hook);
    object_xdecref(typ);
    object_xdecref(exc);
    object_xdecref(tb);
}

impl print_exception_invalid_type(f: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if PyFile_WriteString(
        ptr[u8]("TypeError: print_exception(): Exception expected for value, "), f
    )
        < 0 {
        return -1;
    }
    if PyFile_WriteString(object_type(value).view(1)[0].tp_name, f) < 0 {
        return -1;
    }
    if PyFile_WriteString(ptr[u8](" found\n"), f) < 0 {
        return -1;
    }
    return 0;
}

impl print_exception_traceback(f: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    err: i32 = 0;

    tb = PyException_GetTraceback(value);
    if tb and tb != Py_None {
        err = _PyTraceBack_Print(
            tb, ptr[u8]("Traceback (most recent call last):\n"), f
        );
    }
    object_xdecref(tb);
    return err;
}

impl print_exception_file_and_line(f: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    tmp = NULL;
    res = PyObject_GetOptionalAttr(
        value, id_object(_Py_ID_print_file_and_line), &mut tmp
    );
    if res <= 0 {
        if res < 0 {
            PyErr_Clear();
        }
        return 0;
    }
    object_decref(tmp);

    lineno: i64 = 0;
    v = PyObject_GetAttr(value, id_object(_Py_ID_filename));
    if not v {
        return -1;
    }
    filename = v;
    if v == Py_None {
        object_decref(v);
        filename = object_new_ref(id_object(_Py_STR_anon_string));
    }

    line = PyUnicode_FromFormat("  File \"%S\", line %zd\n", filename, lineno);
    object_decref(filename);
    if not line {
        return -1;
    }
    if PyFile_WriteObject(line, f, Py_PRINT_RAW) < 0 {
        object_decref(line);
        return -1;
    }
    object_decref(line);
    return 0;
}

impl print_exception_message(
    f: ptr[PyObject], type: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if PyErr_GivenExceptionMatches(value, PyExc_MemoryError) != 0 {
        return -1;
    }

    modulename = PyObject_GetAttr(type, id_object(_Py_ID___module__));
    if not modulename or not is_unicode(modulename) {
        object_xdecref(modulename);
        PyErr_Clear();
        if PyFile_WriteString(ptr[u8]("<unknown>."), f) < 0 {
            return -1;
        }
    } elif _PyUnicode_Equal(modulename, id_object(_Py_ID_builtins)) == 0
        and _PyUnicode_Equal(modulename, id_object(_Py_ID___main__)) == 0 {
        res = PyFile_WriteObject(modulename, f, Py_PRINT_RAW);
        object_decref(modulename);
        if res < 0 {
            return -1;
        }
        if PyFile_WriteString(ptr[u8]("."), f) < 0 {
            return -1;
        }
    } else {
        object_decref(modulename);
    }

    qualname = PyType_GetQualName(ptr[PyTypeObject](type));
    if not qualname or not is_unicode(qualname) {
        object_xdecref(qualname);
        PyErr_Clear();
        if PyFile_WriteString(ptr[u8]("<unknown>"), f) < 0 {
            return -1;
        }
    } else {
        res = PyFile_WriteObject(qualname, f, Py_PRINT_RAW);
        object_decref(qualname);
        if res < 0 {
            return -1;
        }
    }

    if value == Py_None {
        return 0;
    }

    s = PyObject_Str(value);
    if not s {
        PyErr_Clear();
        if PyFile_WriteString(ptr[u8](": <exception str() failed>"), f) < 0 {
            return -1;
        }
    } else {
        if not is_unicode(s) or PyUnicode_GetLength(s) != 0 {
            if PyFile_WriteString(ptr[u8](": "), f) < 0 {
                object_decref(s);
                return -1;
            }
        }
        res = PyFile_WriteObject(s, f, Py_PRINT_RAW);
        object_decref(s);
        if res < 0 {
            return -1;
        }
    }

    return 0;
}

impl print_exception(f: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if not is_exception_instance(value) {
        return print_exception_invalid_type(f, value);
    }

    object_incref(value);
    fflush(stdio(1));

    failed = print_exception_traceback(f, value) < 0;
    if not failed {
        type = ptr[PyObject](object_type(value));
        failed = print_exception_file_and_line(f, value) < 0
            or print_exception_message(f, type, value) < 0
            or PyFile_WriteString(ptr[u8]("\n"), f) < 0;
    }
    object_decref(value);
    if failed {
        return -1;
    }
    return 0;
}

impl print_chained(
    f: ptr[PyObject], seen: ptr[PyObject], value: ptr[PyObject], message: ptr[u8]
) -> i32 {
    if Py_EnterRecursiveCall(ptr[u8](" in print_chained")) != 0 {
        return -1;
    }
    res = print_exception_recursive(f, seen, value);
    Py_LeaveRecursiveCall();
    if res < 0 {
        return -1;
    }

    if PyFile_WriteString(ptr[u8]("\n"), f) < 0 {
        return -1;
    }
    if PyFile_WriteString(message, f) < 0 {
        return -1;
    }
    if PyFile_WriteString(ptr[u8]("\n"), f) < 0 {
        return -1;
    }
    return 0;
}

impl print_exception_seen_lookup(seen: ptr[PyObject], value: ptr[PyObject]) -> bool {
    check_id = PyLong_FromVoidPtr(ptr(value));
    if not check_id {
        PyErr_Clear();
        return True;
    }

    in_seen = PySet_Contains(seen, check_id);
    object_decref(check_id);
    if in_seen == -1 {
        PyErr_Clear();
        return True;
    }

    if in_seen == 1 {
        return True;
    }
    return False;
}

impl print_exception_cause_and_context(
    f: ptr[PyObject], seen: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    value_id = PyLong_FromVoidPtr(ptr(value));
    if not value_id or PySet_Add(seen, value_id) == -1 {
        PyErr_Clear();
        object_xdecref(value_id);
        return 0;
    }
    object_decref(value_id);

    if not is_exception_instance(value) {
        return 0;
    }

    err: i32 = 0;
    cause = PyException_GetCause(value);
    if cause {
        if not print_exception_seen_lookup(seen, cause) {
            err = print_chained(
                f,
                seen,
                cause,
                ptr[u8](
                    "The above exception was the direct cause of the following exception:\n"
                )
            );
        }
        object_decref(cause);
        return err;
    }
    if ptr[u8](ptr[u8](value) + PyBaseExceptionObject_SUPPRESS_CONTEXT).view(1)[0]
        != 0 {
        return 0;
    }
    context = PyException_GetContext(value);
    if context {
        if not print_exception_seen_lookup(seen, context) {
            err = print_chained(
                f,
                seen,
                context,
                ptr[u8](
                    "During handling of the above exception, another exception occurred:\n"
                )
            );
        }
        object_decref(context);
        return err;
    }
    return 0;
}

impl print_exception_recursive(
    f: ptr[PyObject], seen: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if Py_EnterRecursiveCall(ptr[u8](" in print_exception_recursive")) != 0 {
        return -1;
    }
    failed = False;
    if seen {
        failed = print_exception_cause_and_context(f, seen, value) < 0;
    }
    if not failed {
        failed = print_exception(f, value) < 0;
    }
    Py_LeaveRecursiveCall();
    if failed {
        return -1;
    }
    return 0;
}

impl _PyRun_StringFlagsWithName(
    text: ptr[u8],
    name: ptr[PyObject],
    start: i32,
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    flags: ptr[PyCompilerFlags],
    generate_new_source: i32
) -> ptr[PyObject] {
    filename = NULL;
    if name {
        if generate_new_source != 0 {
            slot = ptr[i64](
                tstate_interp(current_tstate())
                    + PyInterpreterState_INTERACTIVE_SRC_COUNT
            );
            count = slot.view(1)[0];
            slot.view(1)[0] = count + 1;
            filename = get_interactive_filename(name, count);
        } else {
            filename = object_new_ref(name);
        }
    } else {
        filename = PyUnicode_FromString(ptr[u8]("<string>"));
    }
    if not filename {
        return NULL;
    }
    code = _PyJac_CompileString(text, filename, start, flags, -1);
    object_decref(filename);
    if not code {
        return NULL;
    }
    if name {
        source = PyUnicode_FromString(text);
        if not source {
            PyErr_Clear();
        } else {
            register_code = PyImport_ImportModuleAttrString(
                "linecache", "_register_code"
            );
            registered = NULL;
            if register_code {
                registered = PyObject_CallFunctionObjArgs(
                    register_code, code, source, name, NULL
                );
            }
            object_xdecref(register_code);
            object_decref(source);
            if not registered {
                object_decref(code);
                return NULL;
            }
            object_decref(registered);
        }
    }
    return jac_eval_compiled(code, globals, locals);
}

impl pyrun_file(
    fp: ptr[FILE],
    filename: ptr[PyObject],
    start: i32,
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    closeit: i32,
    flags: ptr[PyCompilerFlags]
) -> ptr[PyObject] {
    code = _PyJac_CompileFile(fp, filename, start, flags);
    if closeit != 0 {
        fclose(fp);
    }
    return jac_eval_compiled(code, globals, locals);
}

impl flush_io_stream(name: ptr[PyObject]) {
    f = NULL;
    if _PySys_GetOptionalAttr(name, &mut f) < 0 {
        PyErr_Clear();
    }
    if f {
        if _PyFile_Flush(f) < 0 {
            PyErr_Clear();
        }
        object_decref(f);
    }
}

impl flush_io {
    tstate = current_tstate();
    exc = _PyErr_GetRaisedException(tstate);
    flush_io_stream(id_object(_Py_ID_stderr));
    flush_io_stream(id_object(_Py_ID_stdout));
    _PyErr_SetRaisedException(tstate, exc);
}

impl run_eval_code_obj(
    tstate: ptr[PyThreadState],
    co: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject]
) -> ptr[PyObject] {
    if not globals or not is_dict(globals) {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("globals must be a real dict"));
        return NULL;
    }
    has_builtins = PyDict_ContainsString(globals, ptr[u8]("__builtins__"));
    if has_builtins < 0 {
        return NULL;
    }
    if has_builtins == 0 {
        builtins = ptr[ptr[PyObject]](
            tstate_interp(tstate) + PyInterpreterState_BUILTINS
        ).view(
            1
        )[0];
        if PyDict_SetItemString(globals, ptr[u8]("__builtins__"), builtins) < 0 {
            return NULL;
        }
    }

    return PyEval_EvalCode(co, globals, locals);
}

impl get_interactive_filename(filename: ptr[PyObject], count: i64) -> ptr[PyObject] {
    length = PyUnicode_GetLength(filename);

    if length >= 2
        and PyUnicode_ReadChar(filename, 0) == u32(60)
        and PyUnicode_ReadChar(filename, length - 1) == u32(62) {
        middle = PyUnicode_Substring(filename, 1, length - 1);
        if not middle {
            return NULL;
        }
        result = PyUnicode_FromFormat("<%U-%zd>", middle, count);
        object_decref(middle);
        return result;
    }
    return PyUnicode_FromFormat("%U-%zd", filename, count);
}

impl run_mod(
    mod: ptr,
    filename: ptr[PyObject],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    flags: ptr[PyCompilerFlags],
    arena: ptr,
    interactive_src: ptr[PyObject],
    generate_new_source: i32
) -> ptr[PyObject] {
    tstate = current_tstate();
    interactive_filename = filename;
    if interactive_src {
        interp = tstate_interp(tstate);
        if generate_new_source != 0 {
            slot = ptr[i64](interp + PyInterpreterState_INTERACTIVE_SRC_COUNT);
            count = slot.view(1)[0];
            slot.view(1)[0] = count + 1;
            interactive_filename = get_interactive_filename(filename, count);
        } else {
            object_incref(interactive_filename);
        }
        if not interactive_filename {
            return NULL;
        }
    }

    co = _PyAST_Compile(mod, interactive_filename, flags, -1, arena);
    if not co {
        if interactive_src {
            object_decref(interactive_filename);
        }
        return NULL;
    }

    if interactive_src {
        print_tb_func = PyImport_ImportModuleAttrString("linecache", "_register_code");
        if not print_tb_func {
            object_decref(co);
            object_decref(interactive_filename);
            return NULL;
        }

        if PyCallable_Check(print_tb_func) == 0 {
            object_decref(co);
            object_decref(interactive_filename);
            object_decref(print_tb_func);
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("linecache._register_code is not callable")
            );
            return NULL;
        }

        result = PyObject_CallFunction(
            print_tb_func, "OOO", co, interactive_src, filename
        );

        object_decref(interactive_filename);

        object_xdecref(print_tb_func);
        object_xdecref(result);
        if not result {
            object_decref(co);
            return NULL;
        }
    }

    if _PySys_Audit(tstate, ptr[u8]("exec"), ptr[u8]("O"), co) < 0 {
        object_decref(co);
        return NULL;
    }

    v = run_eval_code_obj(tstate, co, globals, locals);
    object_decref(co);
    return v;
}

impl run_pyc_file(
    fp: ptr[FILE],
    globals: ptr[PyObject],
    locals: ptr[PyObject],
    flags: ptr[PyCompilerFlags]
) -> ptr[PyObject] {
    tstate = current_tstate();

    magic = PyMarshal_ReadLongFromFile(fp);
    if magic != PyImport_GetMagicNumber() {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("Bad magic number in .pyc file")
            );
        }
        fclose(fp);
        return NULL;
    }

    PyMarshal_ReadLongFromFile(fp);
    PyMarshal_ReadLongFromFile(fp);
    PyMarshal_ReadLongFromFile(fp);
    if PyErr_Occurred() {
        fclose(fp);
        return NULL;
    }
    v = PyMarshal_ReadLastObjectFromFile(fp);
    if not v or not is_code(v) {
        object_xdecref(v);
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("Bad code object in .pyc file"));
        fclose(fp);
        return NULL;
    }
    fclose(fp);
    co = v;
    v = run_eval_code_obj(tstate, co, globals, locals);
    if v and flags {
        co_flags = ptr[i32](ptr[u8](co) + PyCodeObject_FLAGS).view(1)[0];
        slot = compiler_flags_slot(flags);
        slot.view(1)[0] = slot.view(1)[0] | (co_flags & PyCF_MASK);
    }
    object_decref(co);
    return v;
}
