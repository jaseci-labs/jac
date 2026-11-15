"""The IR generator reads its target in a few named places only (#10219).

What a C library spells, lays out or numbers per target belongs to the
runtime floor, and object formats and library naming belong to the linker, so
lowering stays the same for every 64-bit target. This gate keeps it that way:
a new test of the module's triple anywhere else in the IR generator fails here
and has to move behind the floor or join the list below with a reason.
"""
import re;
import from pathlib { Path }

"""Where the IR generator may read its triple, and why."""
glob ALLOWED: dict[str, str] = {
         "postinit": "stamps the module's triple and data layout",
         "_target_is_wasm": "wasm has no floor and its own libc",
         "_emit_platform_name": "names sys.platform for wasm, which has no floor",
         "_resolve_clib_lib_name": "spells a C library's file name for the linker",
         "_exc_jmp_symbols": "Windows keeps its own setjmp pair, which no floor function can wrap",
         "_thunk_tail_callable": "musttail is unavailable on 32-bit and wasm targets",
         "_declare_clib_ability": "passes C structs by value under the target's C ABI",
         "_c_va_start": "names the target in its diagnostic"
     };

test "the IR generator reads the target only where the list says" {
    import jaclang;
    annex = Path(jaclang.__file__).resolve().parent
        / "compiler"
        / "backends"
        / "native"
        / "na_ir_gen_pass.impl";
    found: dict[str, list[str]] = {};
    for path in sorted(annex.glob("*.jac")) {
        current = "";
        for (lineno, line) in enumerate(path.read_text().splitlines(), 1) {
            head = re.match(r"impl NaIRGenPass\.(\w+)", line);
            if head {
                current = head.group(1);
            }
            if "llvm_module.triple" in line {
                found.setdefault(current, []).append(f"{path.name}:{lineno}");
            }
        }
    }
    stray = {
        name: places
        for (name, places) in found.items()
        if name not in ALLOWED
    };
    assert not stray , (
        "these IR generator methods read the target triple; move the decision "
        f"behind the runtime floor or the linker: {stray}"
    );
}
