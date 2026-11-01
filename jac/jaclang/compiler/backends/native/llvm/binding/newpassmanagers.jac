def create_pass_builder(
    machine: TargetMachine, options: PipelineTuningOptions
) -> PassBuilder {
    return PassBuilder(machine, options);
}

def create_pipeline_tuning_options(speed_level: int = 2) -> PipelineTuningOptions {
    return PipelineTuningOptions(speed_level);
}

class PipelineTuningOptions(ObjectRef) {
    has level: int = 2;

    def init(self: PipelineTuningOptions, speed_level: int = 2) {
        super.init(LLVMPY_CreatePipelineTuningOptions());
        self.speed_level = speed_level;
    }

    def _dispose(self: PipelineTuningOptions) {
        LLVMPY_DisposePipelineTuningOptions(self.handle);
    }

    has speed_level: int {
        getter {
            return self.level;
        }
        setter(self: PipelineTuningOptions, value: int) {
            if value < 0 or value > 3 {
                raise ValueError("the speed optimization level must be 0, 1, 2 or 3");
            }
            self.level = value;
        }
    }

    has loop_interleaving: bool {
        getter {
            return LLVMPY_PTOGetLoopInterleaving(self.live());
        }
        setter(self: PipelineTuningOptions, value: bool) {
            LLVMPY_PTOSetLoopInterleaving(self.live(), value);
        }
    }

    has loop_vectorization: bool {
        getter {
            return LLVMPY_PTOGetLoopVectorization(self.live());
        }
        setter(self: PipelineTuningOptions, value: bool) {
            LLVMPY_PTOSetLoopVectorization(self.live(), value);
        }
    }

    has slp_vectorization: bool {
        getter {
            return LLVMPY_PTOGetSLPVectorization(self.live());
        }
        setter(self: PipelineTuningOptions, value: bool) {
            LLVMPY_PTOSetSLPVectorization(self.live(), value);
        }
    }

    has loop_unrolling: bool {
        getter {
            return LLVMPY_PTOGetLoopUnrolling(self.live());
        }
        setter(self: PipelineTuningOptions, value: bool) {
            LLVMPY_PTOSetLoopUnrolling(self.live(), value);
        }
    }

    has inlining_threshold: int {
        getter {
            return int(LLVMPY_PTOGetInlinerThreshold(self.live()));
        }
        setter(self: PipelineTuningOptions, value: int) {
            LLVMPY_PTOSetInlinerThreshold(self.live(), i32(value));
        }
    }
}

class ModulePassManager(ObjectRef) {
    def _dispose(self: ModulePassManager) {
        LLVMPY_DisposeNewModulePassManger(self.handle);
    }

    def add_verifier(self: ModulePassManager) {
        LLVMPY_module_AddVerifierPass(self.live());
    }

    def run(self: ModulePassManager, module: ModuleRef, builder: PassBuilder) {
        LLVMPY_RunNewModulePassManager(self.live(), module.live(), builder.live());
    }
}

def create_module_pass_manager -> ModulePassManager {
    return ModulePassManager(LLVMPY_CreateNewModulePassManager());
}

class PassBuilder(ObjectRef) {
    has options: PipelineTuningOptions,
        machine: TargetMachine;

    def init(
        self: PassBuilder, machine: TargetMachine, options: PipelineTuningOptions
    ) {
        super.init(LLVMPY_CreatePassBuilder(machine.live(), options.live()));
        self.options = options;
        self.machine = machine;
    }

    def _dispose(self: PassBuilder) {
        LLVMPY_DisposePassBuilder(self.handle);
    }

    def getModulePassManager(self: PassBuilder) -> ModulePassManager {
        return ModulePassManager(
            LLVMPY_buildPerModuleDefaultPipeline(
                self.live(), i32(self.options.speed_level)
            )
        );
    }
}
