import platform;
import from ctypes {
    POINTER,
    c_char_p,
    c_bool,
    c_void_p,
    c_int,
    c_uint64,
    c_size_t,
    CFUNCTYPE,
    string_at,
    cast,
    py_object,
    Structure
}
import from jaclang.compiler.passes.native.llvm.binding { ffi, targets, object_file }
with entry {
    ffi.lib.LLVMPY_LinkInMCJIT;
}
"""
    Create a MCJIT ExecutionEngine from the given *module* and
    *target_machine*.

    *lmm* controls whether the jaclang.compiler.passes.native.llvm memory manager is used. If not supplied,
    the default choice for the platform will be used (``True`` on 64-bit ARM
    systems, ``False`` otherwise).
    """
def create_mcjit_compiler(
    module: Any, target_machine: Any, use_lmm: Any = None
) -> object {
    if (use_lmm is None) {
        use_lmm = platform.machine() in ('arm64', 'aarch64');
    }
    with ffi.OutputString() as outerr {
        engine = ffi.lib.LLVMPY_CreateMCJITCompiler(
            module, target_machine, use_lmm, outerr
        );
        if not engine {
            raise RuntimeError(str(outerr));
        }
    }
    target_machine._owned = True;
    return ExecutionEngine(engine, module=module);
}

"""
    Check the system allows execution of in-memory JITted functions.
    An exception is raised otherwise.
    """
def check_jit_execution() -> object {
    errno = ffi.lib.LLVMPY_TryAllocateExecutableMemory();
    if (errno != 0) {
        raise OSError(
            errno,
            "cannot allocate executable memory. "
            "This may be due to security restrictions on your "
            "system, such as SELinux or similar mechanisms."
        );
    }
}

"""An ExecutionEngine owns all Modules associated with it.
    Deleting the engine will remove all associated modules.
    It is an error to delete the associated modules.
    """
class ExecutionEngine(ffi.ObjectRef) {
    with entry {
        _object_cache = None;
    }

    """
        Module ownership is transferred to the EE
        """
    def init(self: ExecutionEngine, ptr: Any, module: Any) -> object {
        self._modules = `set([module]);
        self._td = None;
        module._owned = True;
        ffi.ObjectRef.init(self, ptr);
    }

    """
        Return the address of the function named *name* as an integer.

        It's a fatal error in LLVM if the symbol of *name* doesn't exist.
        """
    def get_function_address(self: ExecutionEngine, name: Any) -> object {
        return ffi.lib.LLVMPY_GetFunctionAddress(self, name.encode("ascii"));
    }

    """
        Return the address of the global value named *name* as an integer.

        It's a fatal error in LLVM if the symbol of *name* doesn't exist.
        """
    def get_global_value_address(self: ExecutionEngine, name: Any) -> object {
        return ffi.lib.LLVMPY_GetGlobalValueAddress(self, name.encode("ascii"));
    }

    def add_global_mapping(self: ExecutionEngine, gv: Any, addr: Any) -> object {
        ffi.lib.LLVMPY_AddGlobalMapping(self, gv, addr);
    }
    """
        Ownership of module is transferred to the execution engine
        """
    def add_module(self: ExecutionEngine, module: Any) -> object {
        if (module in self._modules) {
            raise KeyError("module already added to this engine");
        }
        ffi.lib.LLVMPY_AddModule(self, module);
        module._owned = True;
        self._modules.add(module);
    }

    """
        Make sure all modules owned by the execution engine are fully processed
        and "usable" for execution.
        """
    def finalize_object(self: ExecutionEngine) -> object {
        ffi.lib.LLVMPY_FinalizeObject(self);
    }

    """
        Run static constructors which initialize module-level static objects.
        """
    def run_static_constructors(self: ExecutionEngine) -> object {
        ffi.lib.LLVMPY_RunStaticConstructors(self);
    }

    """
        Run static destructors which perform module-level cleanup of static
        resources.
        """
    def run_static_destructors(self: ExecutionEngine) -> object {
        ffi.lib.LLVMPY_RunStaticDestructors(self);
    }

    """
        Ownership of module is returned
        """
    def remove_module(self: ExecutionEngine, module: Any) -> object {
        with ffi.OutputString() as outerr {
            if ffi.lib.LLVMPY_RemoveModule(self, module, outerr) {
                raise RuntimeError(str(outerr));
            }
        }
        self._modules.remove(module);
        module._owned = False;
    }

    """
        The TargetData for this execution engine.
        """
    @property
    def target_data(self: ExecutionEngine) -> object {
        if (self._td is not None) {
            return self._td;
        }
        ptr = ffi.lib.LLVMPY_GetExecutionEngineTargetData(self);
        self._td = targets.TargetData(ptr);
        self._td._owned = True;
        return self._td;
    }

    """
        Enable JIT events for profiling of generated code.
        Return value indicates whether connection to profiling tool
        was successful.
        """
    def enable_jit_events(self: ExecutionEngine) -> object {
        ret = ffi.lib.LLVMPY_EnableJITEvents(self);
        return ret;
    }

    """
        Find the ModuleRef corresponding to the given pointer.
        """
    def _find_module_ptr(self: ExecutionEngine, module_ptr: Any) -> object {
        ptr = cast(module_ptr, c_void_p).value;
        for module in self._modules {
            if (cast(module._ptr, c_void_p).value == ptr) {
                return module;
            }
        }
        return None;
    }

    """
        Add object file to the jit. object_file can be instance of
        :class:ObjectFile or a string representing file system path
        """
    def add_object_file(self: ExecutionEngine, obj_file: Any) -> object {
        if isinstance(obj_file, str) {
            obj_file = object_file.ObjectFileRef.from_path(obj_file);
        }
        ffi.lib.LLVMPY_MCJITAddObjectFile(self, obj_file);
    }

    """
        Set the object cache "notifyObjectCompiled" and "getBuffer"
        callbacks to the given Python functions.
        """
    def set_object_cache(
        self: ExecutionEngine, notify_func: Any = None, getbuffer_func: Any = None
    ) -> object {
        self._object_cache_notify = notify_func;
        self._object_cache_getbuffer = getbuffer_func;
        self._object_cache = _ObjectCacheRef(self);
        ffi.lib.LLVMPY_SetObjectCache(self, self._object_cache);
    }

    """
        Low-level notify hook.
        """
    def _raw_object_cache_notify(self: ExecutionEngine, data: Any) -> object {
        if (self._object_cache_notify is None) {
            return;
        }
        module_ptr = data.contents.module_ptr;
        buf_ptr = data.contents.buf_ptr;
        buf_len = data.contents.buf_len;
        buf = string_at(buf_ptr, buf_len);
        module = self._find_module_ptr(module_ptr);
        if (module is None) {
            raise RuntimeError(
                (
                    "object compilation notification " "for unknown module %s" % (
                        module_ptr,

                    )
                )
            );
        }
        self._object_cache_notify(module, buf);
    }

    """
        Low-level getbuffer hook.
        """
    def _raw_object_cache_getbuffer(self: ExecutionEngine, data: Any) -> object {
        if (self._object_cache_getbuffer is None) {
            return;
        }
        module_ptr = data.contents.module_ptr;
        module = self._find_module_ptr(module_ptr);
        if (module is None) {
            raise RuntimeError(
                (
                    "object compilation notification " "for unknown module %s" % (
                        module_ptr,

                    )
                )
            );
        }
        buf = self._object_cache_getbuffer(module);
        if (buf is not None) {
            data[0].buf_ptr = ffi.lib.LLVMPY_CreateByteString(buf, len(buf));
            data[0].buf_len = len(buf);
        }
    }

    def _dispose(self: ExecutionEngine) -> object {
        for mod in self._modules {
            mod.detach();
        }
        if (self._td is not None) {
            self._td.detach();
        }
        self._modules.clear();
        self._object_cache = None;
        self._capi.LLVMPY_DisposeExecutionEngine(self);
    }
}

"""
    Internal: an ObjectCache instance for use within an ExecutionEngine.
    """
class _ObjectCacheRef(ffi.ObjectRef) {
    def init(self: _ObjectCacheRef, `obj: Any) -> object {
        ptr = ffi.lib.LLVMPY_CreateObjectCache(_notify_c_hook, _getbuffer_c_hook, `obj);
        ffi.ObjectRef.init(self, ptr);
    }
    def _dispose(self: _ObjectCacheRef) -> object {
        self._capi.LLVMPY_DisposeObjectCache(self);
    }
}

with entry {
    ffi.lib.LLVMPY_CreateMCJITCompiler.argtypes = [
        ffi.LLVMModuleRef,
        ffi.LLVMTargetMachineRef,
        c_bool,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_CreateMCJITCompiler.restype = ffi.LLVMExecutionEngineRef;
    ffi.lib.LLVMPY_RemoveModule.argtypes = [
        ffi.LLVMExecutionEngineRef,
        ffi.LLVMModuleRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_RemoveModule.restype = c_bool;
    ffi.lib.LLVMPY_AddModule.argtypes = [ffi.LLVMExecutionEngineRef, ffi.LLVMModuleRef];
    ffi.lib.LLVMPY_AddGlobalMapping.argtypes = [
        ffi.LLVMExecutionEngineRef,
        ffi.LLVMValueRef,
        c_void_p
    ];
    ffi.lib.LLVMPY_FinalizeObject.argtypes = [ffi.LLVMExecutionEngineRef];
    ffi.lib.LLVMPY_GetExecutionEngineTargetData.argtypes = [ffi.LLVMExecutionEngineRef];
    ffi.lib.LLVMPY_GetExecutionEngineTargetData.restype = ffi.LLVMTargetDataRef;
    ffi.lib.LLVMPY_TryAllocateExecutableMemory.argtypes = [];
    ffi.lib.LLVMPY_TryAllocateExecutableMemory.restype = c_int;
    ffi.lib.LLVMPY_GetFunctionAddress.argtypes = [ffi.LLVMExecutionEngineRef, c_char_p];
    ffi.lib.LLVMPY_GetFunctionAddress.restype = c_uint64;
    ffi.lib.LLVMPY_GetGlobalValueAddress.argtypes = [
        ffi.LLVMExecutionEngineRef,
        c_char_p
    ];
    ffi.lib.LLVMPY_GetGlobalValueAddress.restype = c_uint64;
    ffi.lib.LLVMPY_MCJITAddObjectFile.argtypes = [
        ffi.LLVMExecutionEngineRef,
        ffi.LLVMObjectFileRef
    ];
}
class _ObjectCacheData(Structure) {
    with entry {
        _fields_ = [
            ('module_ptr', ffi.LLVMModuleRef),
            ('buf_ptr', c_void_p),
            ('buf_len', c_size_t)
        ];
    }
}
with entry {
    _ObjectCacheNotifyFunc = CFUNCTYPE(None, py_object, POINTER(_ObjectCacheData));
    _ObjectCacheGetBufferFunc = CFUNCTYPE(None, py_object, POINTER(_ObjectCacheData));
    _notify_c_hook = _ObjectCacheNotifyFunc(ExecutionEngine._raw_object_cache_notify);
    _getbuffer_c_hook = _ObjectCacheGetBufferFunc(
        ExecutionEngine._raw_object_cache_getbuffer
    );
    ffi.lib.LLVMPY_CreateObjectCache.argtypes = [
        _ObjectCacheNotifyFunc,
        _ObjectCacheGetBufferFunc,
        py_object
    ];
    ffi.lib.LLVMPY_CreateObjectCache.restype = ffi.LLVMObjectCacheRef;
    ffi.lib.LLVMPY_DisposeObjectCache.argtypes = [ffi.LLVMObjectCacheRef];
    ffi.lib.LLVMPY_SetObjectCache.argtypes = [
        ffi.LLVMExecutionEngineRef,
        ffi.LLVMObjectCacheRef
    ];
    ffi.lib.LLVMPY_CreateByteString.restype = c_void_p;
    ffi.lib.LLVMPY_CreateByteString.argtypes = [c_void_p, c_size_t];
}

