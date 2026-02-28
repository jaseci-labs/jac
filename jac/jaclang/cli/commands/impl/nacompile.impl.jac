"""Implementation of the nacompile command.

Compiles a .na.jac file to a standalone native binary:
1. Compile .na.jac through Jac pipeline to get LLVM IR
2. Inject main() (+ _start on Linux) as pure LLVM IR (zero assembly)
3. Emit object code via llvmlite
4. Link into executable via pure Python linker (ELF on Linux, Mach-O on macOS)
"""

import os;
import sys;

import from jaclang.cli.console { console }


"""Inject main() and _start into the LLVM IR for ELF (Linux).

main() calls jac_entry() and returns 0.
_start is the ELF entry point, written in pure LLVM IR — no inline
assembly. It calls main(0, null) then exit(). LLVM handles all
architecture-specific code generation via emit_object().

alignstack(16) is needed because _start is jumped to by the kernel
(not called), so there's no return address on the stack and LLVM's
default stack alignment assumption is wrong.
"""
def _inject_entry_elf(llvm_ir_str: str) -> str {
    ir = '\n; --- injected entry point ---\n' + 'declare void @exit(i32) noreturn\n\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n\n' + 'define void @_start() noreturn alignstack(16) {\n' + 'entry:\n' + '    %ret = call i32 @main(i32 0, ptr null)\n' + '    call void @exit(i32 %ret)\n' + '    unreachable\n' + '}\n';
    return llvm_ir_str + ir;
}


"""Inject main() into the LLVM IR for Mach-O (macOS).

Only main() is needed — dyld handles entry via LC_MAIN, and the
system CRT manages _start. No exit() declaration needed since
returning from main() is handled by dyld.
"""
def _inject_entry_macho(llvm_ir_str: str) -> str {
    ir = '\n; --- injected entry point ---\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n';
    return llvm_ir_str + ir;
}


"""Compile a .na.jac file to a standalone native binary."""
impl nacompile(filename: str, output: str = "") -> int {
    # Validate input
    if not filename.endswith(".na.jac") {
        console.error("Input must be a .na.jac file.");
        return 1;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }

    # Detect platform
    is_macos = sys.platform == "darwin";

    # Determine output path
    if not output {
        output = os.path.basename(filename);
        # Strip .na.jac extension
        if output.endswith(".na.jac") {
            output = output[:-7];
        }
    }

    console.print(f"Compiling {filename} to native binary...");

    # Step 1: Compile through Jac pipeline to get LLVM IR
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }

    try {
        prog = JacProgram();
        options = CompileOptions(skip_native_engine=True);
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    }

    if ir_module is None or ir_module.gen.llvm_ir is None {
        console.error("Native compilation produced no LLVM IR.");
        if prog.errors_had {
            for err in prog.errors_had {
                console.error(f"  {err}");
            }
        }
        return 1;
    }

    # Step 2: Check for Python/server interop (can't compile standalone)
    manifest = ir_module.gen.interop_manifest;
    if manifest and manifest.native_imports {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for binding in manifest.native_imports {
            console.error(f"  - {binding.name}");
        }
        return 1;
    }

    llvm_ir_str = str(ir_module.gen.llvm_ir);

    # Check that jac_entry exists (requires with entry {} block)
    if "jac_entry" not in llvm_ir_str {
        console.error(
            "No entry point found. "
            "The .na.jac file must have a 'with entry { }' block."
        );
        return 1;
    }

    console.print("  LLVM IR generated successfully.");

    # Step 3: Initialize llvmlite
    import llvmlite.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();

    triple = llvm.get_default_triple();
    console.print(f"  Target: {triple}");

    # Step 4: Inject entry point (platform-specific)
    if is_macos {
        llvm_ir_str = _inject_entry_macho(llvm_ir_str);
    } else {
        llvm_ir_str = _inject_entry_elf(llvm_ir_str);
    }

    # Step 5: Determine needed libraries
    # Note: libgc (Boehm GC) no longer needed — using reference counting
    if is_macos {
        needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"];
    } else {
        needed_libs: list[str] = ["libc.so.6"];
    }

    # Step 6: Emit object code via llvmlite
    try {
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
    } except Exception as e {
        console.error(f"LLVM IR verification failed: {e}");
        return 1;
    }

    target = llvm.Target.from_default_triple();
    target_machine = target.create_target_machine();
    obj_bytes = target_machine.emit_object(mod);
    console.print(f"  Object code emitted ({len(obj_bytes)} bytes).");

    # Step 7: Link into native executable (platform-specific)
    if is_macos {
        import from jaclang.compiler.passes.native.macho_linker { MachOLinker }

        try {
            success = MachOLinker.link(
                obj_bytes=obj_bytes, output_path=output, needed_libs=needed_libs
            );
        } except Exception as e {
            console.error(f"Mach-O linking failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }

        if not success {
            console.error("Mach-O linking failed: could not parse object file.");
            return 1;
        }
    } else {
        import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
        try {
            success = ElfLinker.link(
                obj_bytes=obj_bytes, output_path=output, needed_libs=needed_libs
            );
        } except Exception as e {
            console.error(f"ELF linking failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
        if not success {
            console.error("ELF linking failed: could not parse object file.");
            return 1;
        }
    }

    file_size = os.path.getsize(output);
    console.print(f"  Binary written to [bold]{output}[/bold] ({file_size} bytes).");
    console.print(f"  Run with: ./{output}");
    return 0;
}
