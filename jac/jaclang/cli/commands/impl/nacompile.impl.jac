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

main() stores argc/argv into globals, calls jac_entry(), and returns 0.
_start is the ELF entry point. It uses the naked attribute with
@llvm.stacksave() to read the raw stack pointer without a prologue,
then loads argc and argv from the kernel-placed stack layout:
[sp]=argc, [sp+8..]=argv array. No inline assembly needed.
"""
def _inject_entry_elf(llvm_ir_str: str, triple: str = "") -> str {
    # Declare __jac_argc/__jac_argv only if the IR gen pass didn't already
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    # Only declare exit() if sys.exit() didn't already declare it
    # llvmlite quotes the name as @"exit", so check both forms
    has_exit = "@exit" in llvm_ir_str or '@"exit"' in llvm_ir_str;
    exit_decl = "" if has_exit else 'declare void @exit(i32) noreturn\n\n';
    ir = (
        '\n; --- injected entry point ---\n' + globals_ir + exit_decl + 'declare ptr @llvm.stacksave()\n\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n\n' + 'define void @_start() naked noreturn {\n' + 'entry:\n' + '    %sp = call ptr @llvm.stacksave()\n' + '    %argc = load i32, ptr %sp\n' + '    %argv = getelementptr i8, ptr %sp, i64 8\n' + '    %ret = call i32 @main(i32 %argc, ptr %argv)\n' + '    call void @exit(i32 %ret)\n' + '    unreachable\n' + '}\n'
    );
    return llvm_ir_str + ir;
}


"""Inject main() into the LLVM IR for Mach-O (macOS).

Only main() is needed — dyld handles entry via LC_MAIN, and the
system CRT manages _start. No exit() declaration needed since
returning from main() is handled by dyld.
"""
def _inject_entry_macho(llvm_ir_str: str) -> str {
    # Declare __jac_argc/__jac_argv only if the IR gen pass didn't already
    has_jac_argc = "__jac_argc" in llvm_ir_str;
    globals_ir = ""
        if has_jac_argc
        else ('@__jac_argc = global i32 0\n' + '@__jac_argv = global ptr null\n\n');
    ir = '\n; --- injected entry point ---\n' + globals_ir + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '    store i32 %argc, ptr @__jac_argc\n' + '    store ptr %argv, ptr @__jac_argv\n' + '    call void @jac_entry()\n' + '    ret i32 0\n' + '}\n';
    return llvm_ir_str + ir;
}


"""Compile a .na.jac file to a standalone native binary."""
impl nacompile(filename: str, output: str = "") -> int {
    # Validate input
    if not filename.endswith(".na.jac") and not filename.endswith(".jac") {
        console.error("Input must be a .jac or .na.jac file.");
        return 1;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }

    auto_promote = filename.endswith(".jac") and not filename.endswith(".na.jac");

    # Detect platform
    is_macos = sys.platform == "darwin";

    # Determine output path
    if not output {
        output = os.path.basename(filename);
        if output.endswith(".na.jac") {
            output = output[:-7];
        } elif output.endswith(".jac") {
            output = output[:-4];
        }
    }

    console.print(f"Compiling {filename} to native binary...");

    # Step 1: Compile through Jac pipeline to get LLVM IR
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }

    try {
        prog = JacProgram();
        if auto_promote {
            prog._auto_promote_native = True;
            prog._auto_promote_target = os.path.abspath(filename);
        }
        options = CompileOptions(skip_native_engine=True);
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    }

    if ir_module is None or ir_module.gen.llvm_ir is None {
        if auto_promote
        and not getattr(
            ir_module.gen if ir_module else None, '_auto_promoted_native', False
        ) {
            console.error(
                "This .jac file is not compatible with native compilation.\n"
                "  It may use walkers, nodes, edges, async, lambdas, or other\n"
                "  constructs not supported by the native backend.\n"
                "  Use a .na.jac file or remove incompatible constructs."
            );
        } else {
            console.error("Native compilation produced no LLVM IR.");
        }
        if prog.errors_had {
            for err in prog.errors_had {
                console.error(f"  {err}");
            }
        }
        return 1;
    }

    if auto_promote {
        console.print("  Auto-promoted to native compilation.");
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
        llvm_ir_str = _inject_entry_elf(llvm_ir_str, triple);
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
