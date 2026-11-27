import from ctypes { c_bool, c_int, c_size_t, POINTER, Structure, byref, c_char_p }
import from enum { IntFlag }
import from typing { NamedTuple }
def create_pass_builder(tm: any, pto: any) -> PassBuilder {
    return PassBuilder(tm, pto);
}

def create_pipeline_tuning_options(speed_level: any = 2) -> PipelineTuningOptions {
    return PipelineTuningOptions(speed_level);
}

""" Holds statistics from reference count pruning.
    """
class NewPassManager {
    def init(self: NewPassManager) -> object {
        if (`type(self) is NewPassManager) {
            raise TypeError("Cannot instantiate NewPassManager directly");
        }
    }

    def run(self: NewPassManager, IR: any, pb: any) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_RunNewModulePassManager(self, IR, pb);
        } else {
            ffi.lib.LLVMPY_RunNewFunctionPassManager(self, IR, pb);
        }
    }

    def _dispose(self: NewPassManager) -> object {
        if isinstance(self, ModulePassManager) {
            ffi.lib.LLVMPY_DisposeNewModulePassManger(self);
        } else {
            ffi.lib.LLVMPY_DisposeNewFunctionPassManger(self);
        }
    }
}

class ModulePassManager(ffi.ObjectRef, NewPassManager) {
    def init(self: ModulePassManager, ptr: any = None) -> object {
        if (ptr is None) {
            ptr = ffi.lib.LLVMPY_CreateNewModulePassManager();
        }
        super.init(ptr);
    }
}

class FunctionPassManager(ffi.ObjectRef, NewPassManager) {
    def init(self: FunctionPassManager, ptr: any = None) -> object {
        if (ptr is None) {
            ptr = ffi.lib.LLVMPY_CreateNewFunctionPassManager();
        }
        super.init(ptr);
    }
}

class PipelineTuningOptions(ffi.ObjectRef) {
    def init(self: PipelineTuningOptions, speed_level: any = 2) -> object {
        self._speed_level = speed_level;
        self.speed_level = speed_level;
        super.init(ffi.lib.LLVMPY_CreatePipelineTuningOptions());
    }

    @property
    def speed_level(self: PipelineTuningOptions) -> object {
        return self._speed_level;
    }

    @speed_level.setter
    def speed_level(self: PipelineTuningOptions, value: any) -> object {
        if not (0 <= value <= 3) {
            raise ValueError("Optimization level for speed should be 0, 1, 2, or 3");
        }
        self._speed_level = value;
    }

    @property
    def loop_interleaving(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetLoopInterleaving(self);
    }

    @loop_interleaving.setter
    def loop_interleaving(self: PipelineTuningOptions, value: any) -> object {
        ffi.lib.LLVMPY_PTOSetLoopInterleaving(self, value);
    }

    @property
    def loop_vectorization(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetLoopVectorization(self);
    }

    @loop_vectorization.setter
    def loop_vectorization(self: PipelineTuningOptions, value: any) -> object {
        ffi.lib.LLVMPY_PTOSetLoopVectorization(self, value);
    }

    @property
    def slp_vectorization(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetSLPVectorization(self);
    }

    @slp_vectorization.setter
    def slp_vectorization(self: PipelineTuningOptions, value: any) -> object {
        ffi.lib.LLVMPY_PTOSetSLPVectorization(self, value);
    }

    @property
    def loop_unrolling(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetLoopUnrolling(self);
    }

    @loop_unrolling.setter
    def loop_unrolling(self: PipelineTuningOptions, value: any) -> object {
        ffi.lib.LLVMPY_PTOSetLoopUnrolling(self, value);
    }

    @property
    def inlining_threshold(self: PipelineTuningOptions) -> object {
        return ffi.lib.LLVMPY_PTOGetInlinerThreshold(self);
    }

    @inlining_threshold.setter
    def inlining_threshold(self: PipelineTuningOptions, value: any) -> object {
        ffi.lib.LLVMPY_PTOSetInlinerThreshold(self, value);
    }

    def _dispose(self: PipelineTuningOptions) -> object {
        ffi.lib.LLVMPY_DisposePipelineTuningOptions(self);
    }
}

class PassBuilder(ffi.ObjectRef) {
    with entry {}

    def init(self: PassBuilder, tm: any, pto: any) -> object {
        super.init(ffi.lib.LLVMPY_CreatePassBuilder(tm, pto));
        self._pto = pto;
        self._tm = tm;
    }

    def getModulePassManager(self: PassBuilder) -> ModulePassManager {
        return ModulePassManager(
            ffi.lib.LLVMPY_buildPerModuleDefaultPipeline(self, self._pto.speed_level)
        );
    }

    def getFunctionPassManager(self: PassBuilder) -> object {
        return FunctionPassManager(
            ffi.lib.LLVMPY_buildFunctionSimplificationPipeline(
                self, self._pto.speed_level
            )
        );
    }

    def _dispose(self: PassBuilder) -> object {
        ffi.lib.LLVMPY_DisposePassBuilder(self);
    }
}

with entry {
    ffi.lib.LLVMPY_CreateNewModulePassManager.restype = ffi.LLVMModulePassManagerRef;
    ffi.lib.LLVMPY_RunNewModulePassManager.argtypes = [
        ffi.LLVMModulePassManagerRef,
        ffi.LLVMModuleRef,
        ffi.LLVMPassBuilderRef
    ];
    ffi.lib.LLVMPY_DisposeNewModulePassManger.argtypes = [ffi.LLVMModulePassManagerRef];
    ffi.lib.LLVMPY_CreateNewFunctionPassManager.restype = ffi.LLVMFunctionPassManagerRef;
    ffi.lib.LLVMPY_RunNewFunctionPassManager.argtypes = [
        ffi.LLVMFunctionPassManagerRef,
        ffi.LLVMValueRef,
        ffi.LLVMPassBuilderRef
    ];
    ffi.lib.LLVMPY_DisposeNewFunctionPassManger.argtypes = [
        ffi.LLVMFunctionPassManagerRef
    ];
    ffi.lib.LLVMPY_CreatePipelineTuningOptions.restype = ffi.LLVMPipelineTuningOptionsRef;
    ffi.lib.LLVMPY_PTOGetLoopInterleaving.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetLoopInterleaving.argtypes = [ffi.LLVMPipelineTuningOptionsRef];
    ffi.lib.LLVMPY_PTOSetLoopInterleaving.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetLoopVectorization.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetLoopVectorization.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef
    ];
    ffi.lib.LLVMPY_PTOSetLoopVectorization.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetSLPVectorization.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetSLPVectorization.argtypes = [ffi.LLVMPipelineTuningOptionsRef];
    ffi.lib.LLVMPY_PTOSetSLPVectorization.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetLoopUnrolling.restype = c_bool;
    ffi.lib.LLVMPY_PTOGetLoopUnrolling.argtypes = [ffi.LLVMPipelineTuningOptionsRef];
    ffi.lib.LLVMPY_PTOSetLoopUnrolling.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_bool
    ];
    ffi.lib.LLVMPY_PTOGetInlinerThreshold.restype = c_int;
    ffi.lib.LLVMPY_PTOSetInlinerThreshold.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef,
        c_int
    ];
    ffi.lib.LLVMPY_DisposePipelineTuningOptions.argtypes = [
        ffi.LLVMPipelineTuningOptionsRef
    ];
    ffi.lib.LLVMPY_CreatePassBuilder.restype = ffi.LLVMPassBuilderRef;
    ffi.lib.LLVMPY_CreatePassBuilder.argtypes = [
        ffi.LLVMTargetMachineRef,
        ffi.LLVMPipelineTuningOptionsRef
    ];
    ffi.lib.LLVMPY_DisposePassBuilder.argtypes = [ffi.LLVMPassBuilderRef];
    ffi.lib.LLVMPY_buildPerModuleDefaultPipeline.restype = ffi.LLVMModulePassManagerRef;
    ffi.lib.LLVMPY_buildPerModuleDefaultPipeline.argtypes = [
        ffi.LLVMPassBuilderRef,
        c_int
    ];
    ffi.lib.LLVMPY_buildFunctionSimplificationPipeline.restype = ffi.LLVMFunctionPassManagerRef;
    ffi.lib.LLVMPY_buildFunctionSimplificationPipeline.argtypes = [
        ffi.LLVMPassBuilderRef,
        c_int
    ];
}
