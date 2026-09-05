"""The one object a link plan synthesizes beside its units.

Every native artifact needs a little code no unit owns: the `jac_entry`
preamble that runs every unit's initializer in dependency order and then
the root's entry, the platform entry point (`main`, `_start`, the PE
start-up shim), the `__jac_shared_init` a shared library exports, the
`jac_retain` / `jac_release` / `jac_str_new` C ABI wrappers, the `atexit`
shim for glibc floors and the aarch64 outline-atomics helpers the C floor
was built against. All of it is emitted here as one LLVM module from the
plan's unit records, never by pattern-matching linked IR.
"""

glob SHARED_INIT_SYMBOL: str = "__jac_shared_init",
     ENTRY_SYMBOL: str = "jac_entry";

"""What the glue needs to know about one unit, in link order."""
obj GlueUnit {
    has prefix: str,
        init: str = "",
        entry: str = "",
        probe: str = "",
        retain: bool = False,
        release: bool = False,
        str_new: bool = False;
}

obj GlueSpec {
    has units: list[GlueUnit],
        root_index: int = -1,
        shared: bool = False,
        platform: str = "elf",
        static_musl: bool = False,
        triple: str = "",
        data_layout: str = "",
        clib_paths: list[str] = [],
        needs_atexit_shim: bool = False,
        needs_region_hook: bool = True;
}

def _decl_void_fn(name: str) -> str {
    return f'declare void @"{name}"()\n';
}

"""`jac_entry`: the root's runtime probe, every unit's initializer in
dependency order, then the root's entry body. For a library the same list
becomes `__jac_shared_init` and there is no entry body."""
def entry_preamble_ir(spec: GlueSpec) -> str {
    decls: list[str] = [];
    calls: list[str] = [];
    root = spec.units[spec.root_index] if spec.root_index >= 0 else None;
    if root is not None and root.probe {
        decls.append(_decl_void_fn(root.probe));
        calls.append(f'  call void @"{root.probe}"()');
    }
    for unit in spec.units {
        if unit.init {
            decls.append(_decl_void_fn(unit.init));
            calls.append(f'  call void @"{unit.init}"()');
        }
    }
    if not spec.shared and root is not None and root.entry {
        decls.append(_decl_void_fn(root.entry));
        calls.append(f'  call void @"{root.entry}"()');
    }
    name = SHARED_INIT_SYMBOL if spec.shared else ENTRY_SYMBOL;
    body = "\n".join(calls) + "\n" if calls else "";
    return (
        "".join(decls)
        + f"define void @{name}() {{\nentry:\n"
        + body
        + "  ret void\n}\n\n"
    );
}

"""The C ABI wrappers a shared library promises: `jac_retain`, `jac_release`
and `jac_str_new`. The retain/release shims of the root unit and the
`weak_odr` string constructor every unit carries are what they bind to."""
def rc_wrapper_ir(spec: GlueSpec) -> tuple[str, list[str]] {
    parts: list[str] = [];
    exports: list[str] = [];
    if not spec.shared or spec.root_index < 0 {
        return ("", exports);
    }
    root = spec.units[spec.root_index];
    if root.retain {
        parts.append(
            f'declare void @"{root.prefix}.jac_retain"(ptr)\n'
            "define void @jac_retain(ptr %p) {\nentry:\n"
            f'  call void @"{root.prefix}.jac_retain"(ptr %p)\n  ret void\n}}\n'
        );
        exports.append("jac_retain");
    }
    if root.release {
        parts.append(
            f'declare void @"{root.prefix}.jac_release"(ptr)\n'
            "define void @jac_release(ptr %p) {\nentry:\n"
            f'  call void @"{root.prefix}.jac_release"(ptr %p)\n  ret void\n}}\n'
        );
        exports.append("jac_release");
    }
    if root.str_new {
        parts.append(
            "declare ptr @__jac_str_new(ptr, i64)\n"
            "define ptr @jac_str_new(ptr %d, i64 %n) {\nentry:\n"
            "  %r = call ptr @__jac_str_new(ptr %d, i64 %n)\n"
            "  ret ptr %r\n}\n"
        );
        exports.append("jac_str_new");
    }
    return ("\n".join(parts), exports);
}

def atexit_shim_ir -> str {
    return (
        "declare i32 @__cxa_atexit(ptr, ptr, ptr)\n"
        "@__dso_handle = weak global i8 0\n"
        "define hidden i32 @atexit(ptr %f) {\nentry:\n"
        "  %r = call i32 @__cxa_atexit(ptr %f, ptr null, ptr @__dso_handle)\n"
        "  ret i32 %r\n}\n\n"
    );
}

"""The default region-death hook: a weak definition every executable
carries so an arena that dies with no OSP unit in the link still resolves."""
def region_hook_ir -> str {
    return (
        "define linkonce_odr void @__jac_region_died_hook(i64 %rgn) {\n"
        "entry:\n  ret void\n}\n\n"
    );
}

def argv_globals_ir -> str {
    return "@__jac_argc = weak global i32 0\n@__jac_argv = weak global ptr null\n\n";
}

def init_array_globals_ir -> str {
    return "@__jac_init_array = weak global ptr null\n@__jac_init_count = weak global i64 0\n\n";
}

def _main_body_with_init_array -> str {
    return (
        "define i32 @main(i32 %argc, ptr %argv) {\n"
        "entry:\n"
        "    store i32 %argc, ptr @__jac_argc\n"
        "    store ptr %argv, ptr @__jac_argv\n"
        "    %ia = load ptr, ptr @__jac_init_array\n"
        "    %ic = load i64, ptr @__jac_init_count\n"
        "    br label %ia.cond\n"
        "ia.cond:\n"
        "    %i = phi i64 [ 0, %entry ], [ %inext, %ia.body ]\n"
        "    %more = icmp ult i64 %i, %ic\n"
        "    br i1 %more, label %ia.body, label %ia.done\n"
        "ia.body:\n"
        "    %slot = getelementptr ptr, ptr %ia, i64 %i\n"
        "    %fn = load ptr, ptr %slot\n"
        "    call void %fn()\n"
        "    %inext = add i64 %i, 1\n"
        "    br label %ia.cond\n"
        "ia.done:\n"
        "    call void @jac_entry()\n"
        "    ret i32 0\n"
        "}\n\n"
    );
}

def entry_elf_ir -> str {
    return (
        "; --- ELF entry point ---\n"
        + argv_globals_ir()
        + init_array_globals_ir()
        + "declare void @exit(i32) noreturn\n\n"
        + "declare i32 @__libc_start_main(ptr, i32, ptr, ptr, ptr, ptr, ptr)\n\n"
        + "declare ptr @llvm.stacksave()\n\n"
        + _main_body_with_init_array()
        + "define void @_start() naked noreturn {\n"
        + "entry:\n"
        + "    %sp = call ptr @llvm.stacksave()\n"
        + "    %argc = load i32, ptr %sp\n"
        + "    %argv = getelementptr i8, ptr %sp, i64 8\n"
        + "    call void @_jac_boot(i32 %argc, ptr %argv, ptr %sp)\n"
        + "    unreachable\n"
        + "}\n\n"
        + "define internal void @_jac_boot(i32 %bargc, ptr %bargv, ptr %bstack) noreturn {\n"
        + "entry:\n"
        + "    %r = call i32 @__libc_start_main(ptr @main, i32 %bargc, ptr %bargv, ptr null, ptr null, ptr null, ptr %bstack)\n"
        + "    unreachable\n"
        + "}\n"
    );
}

def entry_elf_static_ir -> str {
    return (
        "; --- ELF entry point (musl static) ---\n"
        + argv_globals_ir()
        + init_array_globals_ir()
        + _main_body_with_init_array()
    );
}

def entry_macho_ir -> str {
    return (
        "; --- Mach-O entry point ---\n"
        + argv_globals_ir()
        + "define i32 @main(i32 %argc, ptr %argv) {\n"
        + "entry:\n"
        + "    store i32 %argc, ptr @__jac_argc\n"
        + "    store ptr %argv, ptr @__jac_argv\n"
        + "    call void @jac_entry()\n"
        + "    ret i32 0\n"
        + "}\n"
    );
}

def entry_pe_ir -> str {
    return (
        "; --- PE entry point ---\n"
        + argv_globals_ir()
        + "declare void @exit(i32)\n\n"
        + "@_fltused = weak global i32 0\n\n"
        + "declare i32 @__getmainargs(ptr, ptr, ptr, i32, ptr)\n\n"
        + "define i32 @main(i32 %argc, ptr %argv) {\n"
        + "entry:\n"
        + "    store i32 %argc, ptr @__jac_argc\n"
        + "    store ptr %argv, ptr @__jac_argv\n"
        + "    call void @jac_entry()\n"
        + "    ret i32 0\n"
        + "}\n\n"
        + "define void @_jac_win_start() {\n"
        + "entry:\n"
        + "    %argc.addr = alloca i32\n"
        + "    %argv.addr = alloca ptr\n"
        + "    %env.addr = alloca ptr\n"
        + "    %si = alloca i32\n"
        + "    store i32 0, ptr %si\n"
        + "    %gr = call i32 @__getmainargs(ptr %argc.addr, ptr %argv.addr, ptr %env.addr, i32 0, ptr %si)\n"
        + "    %ac = load i32, ptr %argc.addr\n"
        + "    %av = load ptr, ptr %argv.addr\n"
        + "    %r = call i32 @main(i32 %ac, ptr %av)\n"
        + "    call void @exit(i32 %r)\n"
        + "    ret void\n"
        + "}\n"
    );
}

def platform_entry_ir(spec: GlueSpec) -> str {
    if spec.shared or spec.platform in ("jit", "wasm") {
        return "";
    }
    if spec.platform == "pe" {
        return entry_pe_ir();
    }
    if spec.platform == "macho" {
        return entry_macho_ir();
    }
    if spec.static_musl {
        return entry_elf_static_ir();
    }
    return entry_elf_ir();
}

"""The complete glue module as LLVM IR text, and the C ABI symbols it adds
to a shared library's export list."""
def link_glue_ir(spec: GlueSpec) -> tuple[str, list[str]] {
    parts: list[str] = [];
    if spec.data_layout {
        parts.append(f'target datalayout = "{spec.data_layout}"\n');
    }
    if spec.triple {
        parts.append(f'target triple = "{spec.triple}"\n\n');
    }
    parts.append(entry_preamble_ir(spec));
    (rc_ir, exports) = rc_wrapper_ir(spec);
    if rc_ir {
        parts.append(rc_ir);
    }
    parts.append(platform_entry_ir(spec));
    if spec.needs_region_hook {
        parts.append(region_hook_ir());
    }
    if spec.needs_atexit_shim {
        parts.append(atexit_shim_ir());
    }
    parts.append(aarch64_floor_atomics_ir(spec.triple, spec.clib_paths));
    if spec.shared {
        exports.append(SHARED_INIT_SYMBOL);
    }
    return ("".join(parts), exports);
}

def aarch64_outline_atomics_ir -> str {
    ops: dict[str, str] = {
        "ldadd": "add",
        "ldclr": "bic",
        "ldeor": "eor",
        "ldset": "orr"
    };
    sizes: list[int] = [1, 2, 4, 8];
    orders: list[str] = ["relax", "acq", "rel", "acq_rel"];
    sfx: dict[int, str] = {1: "b", 2: "h", 4: "", 8: ""};
    widen: dict[int, str] = {1: "uxtb", 2: "uxth"};

    asm: list[str] = [
        "  .weak __aarch64_have_lse_atomics",
        "  .hidden __aarch64_have_lse_atomics",
        "  .type __aarch64_have_lse_atomics,%object",
        "  .data",
        "__aarch64_have_lse_atomics:",
        "  .byte 0",
        "  .size __aarch64_have_lse_atomics,1",
        "  .text"
    ];

    for order in orders {
        for size in sizes {
            r = "x" if size == 8 else "w";
            ld = ("ldaxr" if order in ["acq", "acq_rel"] else "ldxr") + sfx[size];
            st = ("stlxr" if order in ["rel", "acq_rel"] else "stxr") + sfx[size];

            for (op, insn) in ops.items() {
                nm = f"__aarch64_{op}{size}_{order}";
                asm += _lse_sym(nm)
                    + [
                        f"  mov {r}16, {r}0",
                        f".L{nm}:",
                        f"  {ld} {r}0, [x1]",
                        f"  {insn} {r}17, {r}0, {r}16",
                        f"  {st} w15, {r}17, [x1]",
                        f"  cbnz w15, .L{nm}",
                        "  ret",
                        f"  .size {nm},.-{nm}"
                    ];
            }

            nm = f"__aarch64_swp{size}_{order}";
            asm += _lse_sym(nm)
                + [
                    f"  mov {r}16, {r}0",
                    f".L{nm}:",
                    f"  {ld} {r}0, [x1]",
                    f"  {st} w15, {r}16, [x1]",
                    f"  cbnz w15, .L{nm}",
                    "  ret",
                    f"  .size {nm},.-{nm}"
                ];

            nm = f"__aarch64_cas{size}_{order}";
            wide = (
                f"  {widen[size]} {r}16, {r}0"
                    if size in widen
                    else f"  mov {r}16, {r}0"
            );
            asm += _lse_sym(nm)
                + [
                    wide,
                    f".L{nm}:",
                    f"  {ld} {r}0, [x2]",
                    f"  cmp {r}0, {r}16",
                    f"  b.ne .L{nm}_out",
                    f"  {st} w17, {r}1, [x2]",
                    f"  cbnz w17, .L{nm}",
                    f".L{nm}_out:",
                    "  ret",
                    f"  .size {nm},.-{nm}"
                ];
        }

        nm = f"__aarch64_cas16_{order}";
        ldp = "ldaxp" if order in ["acq", "acq_rel"] else "ldxp";
        stp = "stlxp" if order in ["rel", "acq_rel"] else "stxp";
        asm += _lse_sym(nm)
            + [
                "  mov x16, x0",
                "  mov x17, x1",
                f".L{nm}:",
                f"  {ldp} x0, x1, [x4]",
                "  cmp x0, x16",
                "  ccmp x1, x17, #0, eq",
                f"  b.ne .L{nm}_out",
                f"  {stp} w15, x2, x3, [x4]",
                f"  cbnz w15, .L{nm}",
                f".L{nm}_out:",
                "  ret",
                f"  .size {nm},.-{nm}"
            ];
    }
    head = (
        "\n; --- aarch64 LSE outline-atomics helpers: the C floor is built with"
        "\n; -moutline-atomics, so its objects call __aarch64_ldadd4_relax and"
        "\n; family, which live only in a static libgcc/compiler-rt -- libgcc_s"
        "\n; exports none of them and nothing in the floor set defines them, so"
        "\n; the artifact linked clean and failed its load canary. Our own"
        "\n; codegen never calls these (atomicrmw lowers to inline ldxr/stxr);"
        "\n; they are here purely for the vendored objects. Always LL/SC, so no"
        "\n; dispatch on __aarch64_have_lse_atomics is needed. Weak + hidden:"
        "\n; they must neither collide with a floor member's own copy nor reach"
        "\n; the dynamic symbol table. Only x0/x1/x15/x16/x17 are clobbered,"
        "\n; which is the contract callers assume and why this is not IR ---\n"
    );
    return head + "\n".join([f"module asm \"{ln}\"" for ln in asm]) + "\n";
}

def _lse_sym(nm: str) -> list[str] {
    return [f"  .weak {nm}", f"  .hidden {nm}", f"  .type {nm},%function", f"{nm}:"];
}

def init_object_codegen {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    llvm.initialize_all_asmparsers();
}

def aarch64_floor_atomics_ir(triple: str, clib_paths: list[str]) -> str {
    import from jaclang.runtime.graph_utils { triple_arch }
    if not clib_paths or triple_arch(triple) != "aarch64" {
        return "";
    }
    tl = triple.lower();
    is_pe = ("windows" in tl) or ("win32" in tl) or ("msvc" in tl) or ("mingw" in tl);
    is_macho = ("darwin" in tl) or ("apple" in tl) or ("macos" in tl) or ("ios" in tl);
    if is_pe or is_macho {
        return "";
    }
    return aarch64_outline_atomics_ir();
}
