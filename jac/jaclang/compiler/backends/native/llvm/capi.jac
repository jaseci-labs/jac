"""The C API of the LLVM shim, `libjacllvm`, as the kernel calls it.

The shim sits beside this module; a native unit records it as a needed
library and the kernel's runpath finds it. Strings a function returns through
a `char **` belong to the shim and go back through `LLVMPY_DisposeString`
unless the shim documents them as borrowed."""
import from .jacllvm {
    def LLVMPY_DisposeString(text: ptr[u8]);
    def LLVMPY_GetGlobalContext -> ptr;
    def LLVMPY_ContextCreate -> ptr;
    def LLVMPY_ContextDispose(context: ptr);
    def LLVMPY_ParseAssembly(context: ptr, ir: str, err: &mut ptr[u8]) -> ptr;
    def LLVMPY_ParseBitcode(
        context: ptr, data: bytes, size: u64, err: &mut ptr[u8]
    ) -> ptr;
    def LLVMPY_DisposeModule(module: ptr);
    def LLVMPY_PrintModuleToString(module: ptr, out: &mut ptr[u8]);
    def LLVMPY_WriteBitcodeToString(module: ptr, out: &mut ptr[u8], size: &mut u64);
    def LLVMPY_SplitModuleBitcode(
        module: ptr, parts: u32, buffers: ptr[ptr[u8]], sizes: ptr[u64]
    );
    def LLVMPY_GetNamedFunction(module: ptr, name: str) -> ptr;
    def LLVMPY_GetNamedGlobalVariable(module: ptr, name: str) -> ptr;
    def LLVMPY_VerifyModule(module: ptr, out: &mut ptr[u8]) -> bool;
    def LLVMPY_GetModuleName(module: ptr) -> ptr[u8];
    def LLVMPY_SetModuleName(module: ptr, name: str);
    def LLVMPY_GetDataLayout(module: ptr, out: &mut ptr[u8]);
    def LLVMPY_SetDataLayout(module: ptr, layout: str);
    def LLVMPY_GetTarget(module: ptr, out: &mut ptr[u8]);
    def LLVMPY_SetTarget(module: ptr, triple: str);
    def LLVMPY_ModuleGlobalsIter(module: ptr) -> ptr;
    def LLVMPY_GlobalsIterNext(iterator: ptr) -> ptr;
    def LLVMPY_DisposeGlobalsIter(iterator: ptr);
    def LLVMPY_ModuleFunctionsIter(module: ptr) -> ptr;
    def LLVMPY_FunctionsIterNext(iterator: ptr) -> ptr;
    def LLVMPY_DisposeFunctionsIter(iterator: ptr);
    def LLVMPY_CloneModule(module: ptr) -> ptr;
    def LLVMPY_LinkModules(target: ptr, source: ptr, err: &mut ptr[u8]) -> i32;
    def LLVMPY_PrintValueToString(value: ptr, out: &mut ptr[u8]);
    def LLVMPY_GetValueName(value: ptr) -> ptr[u8];
    def LLVMPY_SetValueName(value: ptr, name: str);
    def LLVMPY_GetLinkage(value: ptr) -> i32;
    def LLVMPY_SetLinkage(value: ptr, linkage: i32);
    def LLVMPY_GetVisibility(value: ptr) -> i32;
    def LLVMPY_SetVisibility(value: ptr, visibility: i32);
    def LLVMPY_IsDeclaration(value: ptr) -> i32;
    def LLVMPY_GlobalGetValueType(value: ptr) -> ptr;
    def LLVMPY_PrintType(type_ref: ptr) -> ptr[u8];
    def LLVMPY_GetReturnType(type_ref: ptr) -> ptr;
    def LLVMPY_CountParamTypes(type_ref: ptr) -> u32;
    def LLVMPY_GetParamTypes(type_ref: ptr, out: ptr[ptr]);
    def LLVMPY_IsFunctionVararg(type_ref: ptr) -> i32;
    def LLVMPY_GetDefaultTargetTriple(out: &mut ptr[u8]);
    def LLVMPY_CreateTargetData(layout: str) -> ptr;
    def LLVMPY_CopyStringRepOfTargetData(data: ptr, out: &mut ptr[u8]);
    def LLVMPY_DisposeTargetData(data: ptr);
    def LLVMPY_ABISizeOfType(data: ptr, type_ref: ptr) -> i64;
    def LLVMPY_OffsetOfElement(data: ptr, type_ref: ptr, position: i32) -> i64;
    def LLVMPY_ABIAlignmentOfType(data: ptr, type_ref: ptr) -> i64;
    def LLVMPY_GetTargetFromTriple(triple: str, err: &mut ptr[u8]) -> ptr;
    def LLVMPY_GetTargetName(target: ptr) -> ptr[u8];
    def LLVMPY_GetTargetDescription(target: ptr) -> ptr[u8];
    def LLVMPY_CreateTargetMachine(
        target: ptr,
        triple: str,
        cpu: str,
        features: str,
        opt: i32,
        reloc: str,
        codemodel: str,
        printmc: i32,
        jit: i32,
        abiname: str
    ) -> ptr;
    def LLVMPY_DisposeTargetMachine(machine: ptr);
    def LLVMPY_GetTargetMachineTriple(machine: ptr, out: &mut ptr[u8]);
    def LLVMPY_SetTargetMachineAsmVerbosity(machine: ptr, verbose: i32);
    def LLVMPY_TargetMachineEmitToMemory(
        machine: ptr, module: ptr, use_object: i32, err: &mut ptr[u8]
    ) -> ptr;
    def LLVMPY_GetBufferStart(buffer: ptr) -> ptr[u8];
    def LLVMPY_GetBufferSize(buffer: ptr) -> u64;
    def LLVMPY_DisposeMemoryBuffer(buffer: ptr);
    def LLVMPY_CreateTargetMachineData(machine: ptr) -> ptr;
    def LLVMPY_CreatePipelineTuningOptions -> ptr;
    def LLVMPY_DisposePipelineTuningOptions(options: ptr);
    def LLVMPY_PTOGetLoopInterleaving(options: ptr) -> bool;
    def LLVMPY_PTOSetLoopInterleaving(options: ptr, value: bool);
    def LLVMPY_PTOGetLoopVectorization(options: ptr) -> bool;
    def LLVMPY_PTOSetLoopVectorization(options: ptr, value: bool);
    def LLVMPY_PTOGetSLPVectorization(options: ptr) -> bool;
    def LLVMPY_PTOSetSLPVectorization(options: ptr, value: bool);
    def LLVMPY_PTOGetLoopUnrolling(options: ptr) -> bool;
    def LLVMPY_PTOSetLoopUnrolling(options: ptr, value: bool);
    def LLVMPY_PTOGetInlinerThreshold(options: ptr) -> i32;
    def LLVMPY_PTOSetInlinerThreshold(options: ptr, value: i32);
    def LLVMPY_CreatePassBuilder(machine: ptr, options: ptr) -> ptr;
    def LLVMPY_DisposePassBuilder(builder: ptr);
    def LLVMPY_buildPerModuleDefaultPipeline(builder: ptr, speed_level: i32) -> ptr;
    def LLVMPY_CreateNewModulePassManager -> ptr;
    def LLVMPY_RunNewModulePassManager(manager: ptr, module: ptr, builder: ptr);
    def LLVMPY_DisposeNewModulePassManger(manager: ptr);
    def LLVMPY_module_AddVerifierPass(manager: ptr);
    def LLVMPY_LldLink(
        argv: ptr[ptr[u8]], argc: u64, out: &mut ptr[u8], can_run_again: &mut i32
    ) -> i32;
    def LLVMPY_WriteImportLibrary(
        dll_name: str,
        path: str,
        machine: u32,
        names: ptr[ptr[u8]],
        import_names: ptr[ptr[u8]],
        count: u64,
        err: &mut ptr[u8]
    ) -> i32;
    def LLVMPY_ObjectSymbols(
        data: bytes, size: u64, with_locals: i32, out: &mut ptr[u8]
    ) -> i32;
    def LLVMPY_SetCommandLine(name: str, option: str);
    def LLVMPY_InitializeAllTargetInfos;
    def LLVMPY_InitializeAllTargets;
    def LLVMPY_InitializeAllTargetMCs;
    def LLVMPY_InitializeAllAsmPrinters;
    def LLVMPY_InitializeAllAsmParsers;
    def LLVMPY_InitializeNativeTarget;
    def LLVMPY_InitializeNativeAsmPrinter;
    def LLVMPY_InitializeNativeAsmParser;
}

import from c {
    def malloc(size: u64) -> ptr;
    def free(memory: ptr);
    def strlen(text: ptr[u8]) -> u64;
    def memcpy(target: bytes, source: ptr, size: u64) -> ptr;
}
