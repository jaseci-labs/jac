"""Executable smoke fixture for the direct ELF/Mach-O linker tests.

The `with entry` block becomes `jac_entry` — the symbol the injected `main()`
calls — and drives the build_executable() relocation path end-to-end:
  - `print` lowers to `printf`, reached through the PLT (external-func reloc),
  - the format string + "JAC_EXEC_OK " live in rodata (PC-relative reloc),
  - `add2` is an intra-image call (local relocation).

Output is exactly "JAC_EXEC_OK 42" (print emits no trailing newline; the second
print formats the int via "%lld"). The ELF binary is executed for real on a
Linux x86_64 host; the Mach-O binary is checked structurally since it cannot run
on Linux.
"""

def add2(a: int, b: int) -> int {
    return a + b;
}

with entry {
    print("JAC_EXEC_OK ");
    print(add2(20, 22));
}
