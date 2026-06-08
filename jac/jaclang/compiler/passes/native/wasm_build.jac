"""Compile Jac native (`na`) code to a browser-loadable WebAssembly module.

Shared by `nacompile --target wasm32` (whole-file) and the client bundler
(the `na {}` codespace of a full-stack module). Runs the native LLVM backend at
the `wasm32-unknown-unknown` triple, then links the single relocatable object
into an instantiable module with the pure-Jac `WasmLinker` -- no wasm-ld /
emscripten.
"""

import os;

"""Parse, optimise (opt2, no internalize so every defined fn stays exported),
emit one relocatable wasm object, and link it into a module."""
def emit_wasm_from_ir(llvm_ir_str: str, export_funcs: list = []) -> bytes {
    import llvmlite.binding as llvm;
    import from jaclang.compiler.passes.native.wasm_linker { WasmLinker }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(llvm_ir_str);
    mod.verify();
    tm = llvm.Target.from_triple("wasm32-unknown-unknown").create_target_machine(opt=2);
    pto = llvm.create_pipeline_tuning_options(speed_level=2, size_level=0);
    pb = llvm.create_pass_builder(tm, pto);
    pb.getModulePassManager().run(mod, pb);
    obj_bytes = tm.emit_object(mod);
    return WasmLinker.link(obj_bytes, export_funcs, 256);
}

"""Compile a `.jac`/`.na.jac` file's native codespace to a wasm module.

Targets wasm32 (restoring any prior JAC_NATIVE_TARGET), compiles AOT with the
type checker off (native has its own discipline), and links. Returns the wasm
bytes, or None when the file has no native code to emit."""
def compile_to_wasm(file_path: str, export_funcs: list = []) -> (bytes | None) {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.abspath(file_path),
            options=CompileOptions(aot_mode=True, type_check=False)
        );
        if (ir is None) or (ir.gen.llvm_ir is None) {
            return None;
        }
        llvm_ir_str = str(ir.gen.llvm_ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
    return emit_wasm_from_ir(llvm_ir_str, export_funcs);
}
