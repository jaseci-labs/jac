impl win_import_dll(name: str, declared: (str | None), crt: str = "") -> str {
    """The DLL a PE image imports `name` from. `declared` is the library the
    program named for it, if it named one; `crt` is the C runtime the link
    asked for, the UCRT if it asked for none.""";
    import os;

    if declared {
        base = os.path.basename(declared.replace("\\", "/"));
        if base.lower().endswith(".dll") and base.lower() not in WIN_CRT_LIBRARIES {
            return base;
        }
    }
    if name == "__chkstk" or name in WIN_FLOOR_KERNEL32 {
        return "kernel32.dll";
    }
    return crt or WIN_CRT_DLL;
}

impl win_import_name(name: str) -> str {
    """The spelling `name` is imported under.""";
    if name.startswith(WIN_UCRT_PREFIX) {
        return name[len(WIN_UCRT_PREFIX):];
    }
    return WIN_CRT_ALIAS.get(name, name);
}

impl _win_jmp_ir -> str {
    """`__jac_setjmp` and `__jac_longjmp`: the pair native exception frames arm
    and raise through. The UCRT's `longjmp` unwinds through the image's
    exception tables, which a Jac image does not carry, so the floor keeps its
    own pair: the Win64 callee-saved state (rbx, rbp, rsi, rdi, r12-r15, rsp,
    the return address and xmm6-xmm15) in 240 bytes, with no unwind.""";
    lines = [
        ".text",
        ".globl __jac_setjmp",
        ".p2align 4",
        "__jac_setjmp:",
        "movq %rbx, 0(%rcx)",
        "movq %rbp, 8(%rcx)",
        "movq %rsi, 16(%rcx)",
        "movq %rdi, 24(%rcx)",
        "movq %r12, 32(%rcx)",
        "movq %r13, 40(%rcx)",
        "movq %r14, 48(%rcx)",
        "movq %r15, 56(%rcx)",
        "leaq 8(%rsp), %rax",
        "movq %rax, 64(%rcx)",
        "movq (%rsp), %rax",
        "movq %rax, 72(%rcx)",
        "movups %xmm6, 80(%rcx)",
        "movups %xmm7, 96(%rcx)",
        "movups %xmm8, 112(%rcx)",
        "movups %xmm9, 128(%rcx)",
        "movups %xmm10, 144(%rcx)",
        "movups %xmm11, 160(%rcx)",
        "movups %xmm12, 176(%rcx)",
        "movups %xmm13, 192(%rcx)",
        "movups %xmm14, 208(%rcx)",
        "movups %xmm15, 224(%rcx)",
        "xorl %eax, %eax",
        "retq",
        ".globl __jac_longjmp",
        ".p2align 4",
        "__jac_longjmp:",
        "movl %edx, %eax",
        "testl %eax, %eax",
        "jne 1f",
        "movl $1, %eax",
        "1:",
        "movq 0(%rcx), %rbx",
        "movq 8(%rcx), %rbp",
        "movq 16(%rcx), %rsi",
        "movq 24(%rcx), %rdi",
        "movq 32(%rcx), %r12",
        "movq 40(%rcx), %r13",
        "movq 48(%rcx), %r14",
        "movq 56(%rcx), %r15",
        "movups 80(%rcx), %xmm6",
        "movups 96(%rcx), %xmm7",
        "movups 112(%rcx), %xmm8",
        "movups 128(%rcx), %xmm9",
        "movups 144(%rcx), %xmm10",
        "movups 160(%rcx), %xmm11",
        "movups 176(%rcx), %xmm12",
        "movups 192(%rcx), %xmm13",
        "movups 208(%rcx), %xmm14",
        "movups 224(%rcx), %xmm15",
        "movq 64(%rcx), %rsp",
        "jmpq *72(%rcx)"
    ];
    return "".join([f'module asm "{line}"\n' for line in lines]) + "\n";
}

impl win_floor_ir -> str {
    """The Windows floor's IR, for the link glue of a PE artifact.

    A Windows image imports the Universal C Runtime, which is a C library
    but not the POSIX one the native runtime was written against. The floor
    closes the gap: win_floor.c, compiled once to the text in win_floor_ir.jac
    (WIN_FLOOR_IR, with WIN_FLOOR_KERNEL32 naming its kernel32 imports;
    scripts/gen_win_floor.jac regenerates both), defines the names the
    runtime calls with the meaning and record layouts they have on Linux,
    and `_win_jmp_ir` adds the exception frames' jump pair. A name the floor
    does not define is imported from ucrtbase.dll, under the spelling
    WIN_CRT_ALIAS gives it where the UCRT spells it otherwise or types it
    with a 32-bit `long`. A UCRT function the floor also defines is called
    from the floor as `__ucrt_<name>` (WIN_UCRT_PREFIX), and a library named
    in WIN_CRT_LIBRARIES is the CRT, not a DLL of that name.
    """;

    return "; --- Windows floor ---\n" + _win_jmp_ir() + WIN_FLOOR_IR;
}
