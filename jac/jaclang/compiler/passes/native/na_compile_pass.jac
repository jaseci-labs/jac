"""JIT compile LLVM IR to native machine code using llvmlite.

Takes the LLVM IR module from NaIRGenPass and compiles it to
executable native code via MCJIT. Function addresses can then
be called via ctypes.
"""

import jaclang.compiler.passes.native.llvm.binding as llvm;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { Transform }
import from jaclang.jac0core.codeinfo { CodeGenTarget }
import from jaclang.jac0core.diagnostics {
    E5020,
    W5021,
    W5022,
    W5023,
    E5024,
    E5025,
    E5026
}

"""Per-dependency native C-ABI metadata gathered while linking an imported
.na.jac module.

Single carrier for every field that must survive the .ir_meta cache round-trip
and -- for the propagated subset -- merge up into the root module's IR-gen
state. Collapses what were eight parallel locals threaded through five hand-kept
sites (declare / cache-read / cache-write / fresh-read / merge-up): the omission
of one such site is exactly what dropped `clib_symbol_lib` on Windows and
bucketed every sub-module Win32 symbol into msvcrt.dll. Adding a field is now
one `has` line (plus one block in `propagate_to` if it must reach the root)."""
obj DepClibMeta {
    # Fields, in order: .so/.dylib/.dll paths (AOT link surface + JIT load);
    # symbol -> owning DLL (Windows PE import table); `:pub` C-ABI exports;
    # symbols imported from other native modules and symbols owned by this dep's
    # own source (both for the collision check); source paths of this dep's own
    # native imports (work-queue enqueue).
    has clib_paths: list[str] = [],
        clib_symbol_lib: dict[str, str] = {},
        exported_symbols: list[str] = [],
        imported_symbols: list[str] = [],
        owned_symbols: list[str] = [],
        transitive_deps: list[str] = [];

    # Serialize to the .ir_meta cache dict.
    def to_meta -> dict;
    # Build from a .ir_meta cache dict (missing keys default to empty).
    static def from_meta(meta: dict) -> DepClibMeta;
    # Merge the propagated C-ABI surface up into the root module's IR-gen state
    # (`gen`), first-seen-wins. THE single propagation site -- a new field that
    # must reach the root module gets one block here. Does not JIT-load
    # clib_paths; that runtime concern stays with the caller.
    # Note: imported_symbols, owned_symbols, and transitive_deps intentionally
    # do NOT propagate -- they are consumed locally by the collision checker and
    # dep enqueuing and do not belong on the root's CodeGenTarget.
    def propagate_to(gen: CodeGenTarget) -> None;
}


"""JIT compile LLVM IR module to native machine code."""
obj NativeCompilePass(Transform) {
    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    # Link imported .na.jac modules at IR level (na↔na linking)
    def _compile_and_link_native_imports(
        module: uni.Module, main_mod: object, imports: list, target_machine: object
    ) -> None;
    # Load a C shared library into the process so MCJIT can resolve its
    # symbols at JIT time, stripping any AOT-only `$ORIGIN`/`@loader_path`
    # loader token first. Returns True when the library was loaded.
    def _jit_load_clib(lib_path: str) -> bool;
    # Link the portable OSP kernel's IR into an OSP program (issue #6146)
    def _link_osp_kernel(main_mod: object) -> None;
    # True when the linked IR references the OSP kernel but no module defines it
    # -- e.g. the spawn/visit lives in an imported module (issue #6669)
    def _references_undefined_osp_kernel(main_mod: object) -> bool;
}
