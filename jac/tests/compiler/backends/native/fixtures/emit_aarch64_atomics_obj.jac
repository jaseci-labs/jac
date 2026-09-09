"""Emit a real aarch64-linux object out of the executable path's finalized IR.

Run as a subprocess by test_aarch64_outline_atomics.jac: the failure this pins
is an LLVM `report_fatal_error`, which aborts the process rather than raising,
so it cannot be caught in-process.

The outline-atomics helpers are `module asm`, and assembling module asm needs a
registered asm parser FOR THE TARGET. Parsing the IR does not: `parse_assembly`
accepts the block happily, which is why the emit has to run all the way to an
object here.

Because the shim registers every target's parser, this runs on any host, which
is what turns "every helper assembles and reaches the symbol table" from a
property only aarch64 CI could check into one every run checks.
"""

import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.backends.native.shared_emit { init_object_codegen }
import from jaclang.cli.commands.native_build { _finalize_native_ir }

glob TRIPLE = "aarch64-unknown-linux-gnu",
     EM_AARCH64 = 183;

"""The ABI's members, restated from its own axes rather than read back out of
the generator, so the two have to agree."""
def abi_family -> list[str] {
    names: list[str] = [];
    for order in ["relax", "acq", "rel", "acq_rel"] {
        for size in [1, 2, 4, 8] {
            for op in ["ldadd", "ldclr", "ldeor", "ldset", "swp", "cas"] {
                names.append(f"__aarch64_{op}{size}_{order}");
            }
        }
        names.append(f"__aarch64_cas16_{order}");
    }
    return names;
}

with entry {
    init_object_codegen();
    (ir, _exports) = _finalize_native_ir(
        llvm_ir_str='define void @"jac_entry"() {\nentry:\n  ret void\n}\n',
        triple=TRIPLE,
        clib_paths=["libz.so"],
        manifest=None,
        shared=False,
        is_windows=False,
        is_macos=False,
        static_musl=False
    );
    mod = llvm.parse_assembly(f'target triple = "{TRIPLE}"\n' + ir);
    mod.verify();
    tm = llvm.Target.from_triple(TRIPLE).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    blob = tm.emit_object(mod);
    if blob[:4] != b"\x7fELF" {
        print("EMIT_NOT_ELF");
    } elif (blob[18] + (blob[19] * 256)) != EM_AARCH64 {
        print("EMIT_WRONG_MACHINE");
    } else {
        absent = sorted(
            {
                nm
                for nm in abi_family()
                if blob.find(nm.encode("utf-8")) < 0
            }
        );
        if absent {
            print(f"EMIT_MISSING_SYMBOLS {len(absent)} {absent[:6]}");
        } else {
            print("EMIT_OK");
        }
    }
}
