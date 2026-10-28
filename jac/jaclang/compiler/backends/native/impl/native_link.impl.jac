impl triple_arch_of(triple: str) -> str {
    head = triple.split("-", 1)[0].lower();
    if head in ("arm64", "aarch64") {
        return "aarch64";
    }
    if head in ("amd64", "x86_64", "x64") {
        return "x86_64";
    }
    return head;
}

impl floor_lib_dir(triple: str) -> (str | None) {
    found = resolve(f"c-floor@{osarch(triple)}").found;
    return found.path if found is not None else None;
}

impl musl_lib_dir(triple: str) -> (str | None) {
    found = resolve(f"musl@{osarch(triple)}").found;
    return found.path if found is not None else None;
}

impl clib_to_archive_name(clib_path: str) -> str {
    return os.path.basename(clib_path).split(".")[0] + ".a";
}

impl floor_archives(clib_paths: list[str], triple: str) -> tuple[list[str], set[str]] {
    archives: list[str] = [];
    handled: set[str] = set();
    tl = triple.lower();
    if not clib_paths or any(w in tl for w in ("windows", "win32", "msvc", "mingw")) {
        return (archives, handled);
    }
    lib_dir = floor_lib_dir(triple);
    if lib_dir is None {
        return (archives, handled);
    }
    for clib_path in clib_paths {
        archive = os.path.join(lib_dir, clib_to_archive_name(clib_path));
        if not os.path.isfile(archive) {
            continue;
        }
        if archive not in archives {
            archives.append(archive);
        }
        handled.add(clib_path);
    }
    return (archives, handled);
}

impl musl_runtime(triple: str) -> (tuple[list[str], list[str]] | None) {
    lib_dir = musl_lib_dir(triple);
    if lib_dir is None or not os.path.isfile(os.path.join(lib_dir, "libc.a")) {
        return None;
    }
    if not os.path.isfile(os.path.join(lib_dir, "crt1.o")) {
        return None;
    }
    crt = [
        os.path.join(lib_dir, name)
        for name in MUSL_CRT
        if os.path.isfile(os.path.join(lib_dir, name))
    ];
    archives = [
        os.path.join(lib_dir, name)
        for name in MUSL_ARCHIVES
        if os.path.isfile(os.path.join(lib_dir, name))
    ];
    return (crt, archives);
}

impl outline_atomics_archive(triple: str) -> (str | None) {
    if triple_arch_of(triple) != "aarch64" or "linux" not in triple {
        return None;
    }
    lib_dir = musl_lib_dir(triple);
    if lib_dir is None {
        return None;
    }
    path = os.path.join(lib_dir, "libclang_rt.atomics.a");
    return path if os.path.isfile(path) else None;
}

impl elf_runtime_soname(name: str) -> str {
    import ctypes.util;
    import re;
    matched = re.fullmatch(r"lib([^/]+)\.so", name);
    if matched is None {
        return name;
    }
    try {
        found = ctypes.util.find_library(matched.group(1));
    } except Exception {
        return name;
    }
    if found and "/" not in found and found.startswith(name + ".") {
        return found;
    }
    return name;
}

impl clib_needed_libs(
    needed_libs: list[str],
    clib_paths: list[str],
    floor_handled: set[str],
    host_elf: bool = False
) -> dict[str, str] {
    lib_norm: dict[str, str] = {};
    for lib_path in clib_paths {
        if lib_path in floor_handled {
            continue;
        }
        needed = lib_path;
        if (not os.path.isabs(lib_path))
            and (not lib_path.startswith("$"))
            and (not lib_path.startswith("@"))
            and ("/" in lib_path or "\\" in lib_path) {
            needed = os.path.basename(lib_path);
        }
        base = os.path.basename(needed);
        if base == "libc.so" {
            needed = "libc.so.6";
        } elif base == "libm.so" {
            needed = "libm.so.6";
        } elif base in ["libc.dylib", "libm.dylib"] {
            needed = MACHO_SYSTEM_DYLIB;
        } elif host_elf and needed == base {
            needed = elf_runtime_soname(base);
        }
        if needed not in needed_libs {
            needed_libs.append(needed);
        }
        lib_norm[lib_path] = needed;
    }
    return lib_norm;
}

impl clib_symbol_lib_map(
    clib_symbol_lib: dict[str, str],
    floor_handled: set[str],
    lib_norm: dict[str, str],
    shared: bool,
    is_macos: bool
) -> dict[str, str] {
    symbol_lib_map: dict[str, str] = {};
    for (sym, raw) in clib_symbol_lib.items() {
        if raw in floor_handled {
            continue;
        }
        if shared and is_macos {
            symbol_lib_map[sym] = "@process";
        } else {
            symbol_lib_map[sym] = lib_norm.get(raw, raw);
        }
    }
    return symbol_lib_map;
}

impl _run_lld(args: list[str], what: str) -> list[str] {
    (code, text) = llvm.lld_link(args);
    if code != 0 {
        raise NativeLinkError(f"{what} link failed:\n{text.strip()}");
    }
    return [
        line
        for line in text.splitlines()
        if "warning:" in line
    ];
}

impl _write_objects(work: str, objects: list[bytes], suffix: str) -> list[str] {
    paths: list[str] = [];
    for (i, blob) in enumerate(objects) {
        path = os.path.join(work, f"input{i}{suffix}");
        with open(path, "wb") as f {
            f.write(blob);
        }
        paths.append(path);
    }
    return paths;
}

impl _undefined_symbols(objects: list[bytes]) -> list[str] {
    defined: set[str] = set();
    undefined: set[str] = set();
    for blob in objects {
        (d, u) = llvm.object_symbols(blob);
        defined |= d;
        undefined |= u;
    }
    return sorted(undefined - defined);
}

impl link_native(job: NativeLinkJob) -> list[str] {
    final = job.output_path;
    directory = os.path.dirname(os.path.abspath(final)) or ".";
    os.makedirs(directory, exist_ok=True);
    if not job.soname {
        job.soname = os.path.basename(final);
    }
    staged = os.path.join(directory, f".{os.path.basename(final)}.{os.getpid()}.lld");
    work = tempfile.mkdtemp(prefix="jac-link-");
    job.output_path = staged;
    try {
        if job.platform == "elf" {
            warnings = _link_elf(job, work);
        } elif job.platform == "macho" {
            warnings = _link_macho(job, work);
        } elif job.platform == "pe" {
            warnings = _link_pe(job, work);
        } else {
            raise NativeLinkError(f"no native linker for the {job.platform} format");
        }
        os.chmod(staged, 0o755);
        os.replace(staged, final);
    } finally {
        job.output_path = final;
        shutil.rmtree(work, ignore_errors=True);
        if os.path.exists(staged) {
            os.unlink(staged);
        }
    }
    return warnings;
}

impl _elf_interpreter(triple: str) -> str {
    candidates = ELF_INTERPRETERS.get(triple_arch_of(triple), []);
    for path in candidates {
        if os.path.exists(path) {
            return path;
        }
    }
    return candidates[0] if candidates else "";
}

impl _empty_object(work: str, triple: str) -> str {
    path = os.path.join(work, "empty.o");
    if not os.path.exists(path) {
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        target = llvm.Target.from_triple(triple);
        tm = target.create_target_machine(reloc="pic");
        module = llvm.parse_assembly(f'target triple = "{triple}"\n');
        with open(path, "wb") as f {
            f.write(tm.emit_object(module));
        }
    }
    return path;
}

impl _elf_stub_library(work: str, triple: str, soname: str, index: int) -> str {
    stub = os.path.join(work, f"stub{index}.so");
    _run_lld(
        [
            "ld.lld",
            "-shared",
            "-soname",
            soname,
            "--build-id=none",
            "-o",
            stub,
            _empty_object(work, triple)
        ],
        "stub library"
    );
    return stub;
}

impl _link_elf(job: NativeLinkJob, work: str) -> list[str] {
    inputs = _write_objects(work, job.objects, ".o");
    args = [
        "ld.lld",
        "-o",
        job.output_path,
        "--build-id=none",
        "-z",
        "noexecstack",
        "--hash-style=both"
    ];
    if job.static_musl {
        crt = [
            p
            for p in job.crt_objects
            if os.path.basename(p) != "crtn.o"
        ];
        crtn = [
            p
            for p in job.crt_objects
            if os.path.basename(p) == "crtn.o"
        ];
        args += ["-static", "--warn-unresolved-symbols"];
        args += crt + inputs + job.archives + crtn;
        return _run_lld(args, "static ELF");
    }
    args += ["-rpath", "$ORIGIN", "--enable-new-dtags"];
    if job.shared {
        args += ["-shared", "-soname", job.soname];
        script = os.path.join(work, "exports.map");
        with open(script, "w") as f {
            f.write("{\n  global:\n");
            for sym in job.export_symbols {
                f.write(f'    "{sym}";\n');
            }
            f.write("  local: *;\n};\n");
        }
        args += ["--version-script", script];
    } else {
        args += [
            "-pie",
            "--dynamic-linker",
            _elf_interpreter(job.triple),
            "-z",
            "undefs",
            "-z",
            "dynamic-undefined-weak"
        ];
    }
    args.append("--no-as-needed");
    index = 0;
    for lib in job.needed_libs {
        args.append(_elf_stub_library(work, job.triple, lib, index));
        index += 1;
    }
    args += inputs + job.archives;
    return _run_lld(args, "shared ELF" if job.shared else "ELF");
}

impl _macho_version(triple: str, arch: str) -> str {
    import re;
    matched = re.search(r"macosx?(\d+(?:\.\d+)?)", triple.lower());
    if matched is not None {
        version = matched.group(1);
        return version if "." in version else version + ".0";
    }
    return MACHO_MIN_VERSION.get(arch, "11.0");
}

impl _tbd(path: str, install_name: str, target: str, symbols: list[str]) {
    lines = [
        "--- !tapi-tbd",
        "tbd-version: 4",
        f"targets: [ {target} ]",
        f"install-name: '{install_name}'",
        "current-version: 1"
    ];
    if symbols {
        quoted = ", ".join(f"'{s}'" for s in symbols);
        lines += [
            "exports:",
            f"  - targets: [ {target} ]",
            f"    symbols: [ {quoted} ]"
        ];
    }
    lines.append("...");
    with open(path, "w") as f {
        f.write("\n".join(lines) + "\n");
    }
}

impl _macho_install_name(lib: str) -> str {
    if lib.startswith("/") or lib.startswith("@") {
        return lib;
    }
    return f"@loader_path/{lib}";
}

impl macho_stub_symbols(
    job: NativeLinkJob, undefined: list[str]
) -> dict[str, list[str]] {
    by_lib: dict[str, list[str]] = {};
    for lib in [MACHO_SYSTEM_DYLIB] + job.needed_libs {
        by_lib.setdefault(_macho_install_name(lib), []);
    }
    if job.shared {
        return by_lib;
    }
    for sym in undefined {
        bare = sym[1:] if sym.startswith("_") else sym;
        if bare in job.archive_symbols {
            continue;
        }
        lib = job.symbol_lib_map.get(bare, MACHO_SYSTEM_DYLIB);
        if lib == "@process" {
            continue;
        }
        by_lib.setdefault(_macho_install_name(lib), []).append(sym);
    }
    return by_lib;
}

impl _link_macho(job: NativeLinkJob, work: str) -> list[str] {
    arch = MACHO_ARCH.get(triple_arch_of(job.triple), "arm64");
    version = _macho_version(job.triple, arch);
    target = f"{arch}-macos";
    inputs = _write_objects(work, job.objects, ".o");
    args = [
        "ld64.lld",
        "-arch",
        arch,
        "-platform_version",
        "macos",
        version,
        version,
        "-o",
        job.output_path,
        "-rpath",
        "@loader_path",
        "-undefined",
        "dynamic_lookup"
    ];
    if job.shared {
        args += ["-dylib", "-install_name", f"@rpath/{job.soname}"];
        for sym in job.export_symbols {
            args += ["-exported_symbol", "_" + sym];
        }
    }
    by_lib = macho_stub_symbols(job, _undefined_symbols(job.objects));
    index = 0;
    for lib in by_lib {
        stub = os.path.join(work, f"stub{index}.tbd");
        _tbd(stub, lib, target, by_lib[lib]);
        args.append(stub);
        index += 1;
    }
    args += inputs + job.archives;
    return _run_lld(args, "Mach-O dylib" if job.shared else "Mach-O");
}

impl _link_pe(job: NativeLinkJob, work: str) -> list[str] {
    arch = triple_arch_of(job.triple);
    machine = PE_MACHINE.get(arch);
    if machine is None {
        raise NativeLinkError(f"no PE target for {arch}");
    }
    inputs = _write_objects(work, job.objects, ".obj");
    args = [
        "lld-link",
        f"/out:{job.output_path}",
        f"/machine:{PE_LINK_MACHINE[arch]}",
        "/nodefaultlib",
        "/subsystem:console",
        "/Brepro",
        "/debug:none",
        "/opt:ref"
    ];
    if job.shared {
        args += ["/dll", f"/entry:{PE_DLL_ENTRY}"];
        for sym in job.export_symbols {
            args.append(f"/export:{sym}");
        }
    } else {
        args.append(f"/entry:{PE_EXE_ENTRY}");
    }
    crt = job.needed_libs[0] if job.needed_libs else "";
    by_dll: dict[str, list[str]] = {};
    for sym in _undefined_symbols(job.objects) {
        name = sym[len("__imp_"):] if sym.startswith("__imp_") else sym;
        dll = win_import_dll(name, job.symbol_lib_map.get(name), crt);
        if name not in by_dll.setdefault(dll, []) {
            by_dll[dll].append(name);
        }
    }
    index = 0;
    for dll in sorted(by_dll) {
        names = by_dll[dll];
        implib = os.path.join(work, f"import{index}.lib");
        llvm.write_import_library(
            dll, implib, machine, names, [win_import_name(n) for n in names]
        );
        args.append(implib);
        index += 1;
    }
    args += inputs + job.archives;
    return _run_lld(args, "PE DLL" if job.shared else "PE");
}

impl link_wasm_module(job: WasmLinkJob) {
    work = tempfile.mkdtemp(prefix="jac-wasm-link-");
    try {
        inputs = _write_objects(work, job.objects, ".o");
        allow_file = "";
        if job.allowed_imports is not None {
            allow_file = os.path.join(work, "imports.txt");
            write_allowed_imports(allow_file, job.allowed_imports);
        }
        _run_lld(
            ["wasm-ld"]
                + wasm_ld_args(job.output_path, inputs, job.export_funcs, allow_file),
            "wasm"
        );
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
}

impl write_symbol_map(output_path: str) {
    with open(output_path, "rb") as f {
        image = f.read();
    }
    rows = sorted(llvm.image_symbol_addresses(image), key=lambda (kv) { kv[1]; });
    text = "".join(f"{name} 0x{address:016x}\n" for (name, address) in rows);
    atomic_write(output_path + ".symmap", text.encode("utf-8"));
}
