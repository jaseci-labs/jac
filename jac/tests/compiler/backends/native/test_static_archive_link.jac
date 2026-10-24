"""End-to-end gate for static C-archive linking on Mach-O and ELF (#6978 0.1a).

The Mach-O tests compile a tiny `na` program that calls `lzma_crc32` (an extern
C symbol), hand LLD the bundled `liblzma.a` whole (it loads only the members
the program reaches), and run the result -- proving the floor links statically
into the executable instead of being a runtime dylib dependency. Gated to
macOS arm64 (where the binary can run and the bundled archives are TLS-free);
skips elsewhere or when no pbs build is staged.

The ELF test is the Linux counterpart: it links a member object defining the
extern the program calls into a static musl executable, and executes only on
a Linux x86_64 host, where a clean run with the right value proves the link.
"""

import from tests.support { jac_command }

import os;
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.native_link {
    NativeLinkJob,
    link_native,
    musl_runtime
}
import from tests.support { program_ir }
import jaclang.compiler.backends.native.llvm.binding as llvm;

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");


"""Assemble IR into a position-independent relocatable object, the code
model `jac build --native` emits."""
def _emit_object(ir_txt: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir_txt);
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    return tm.emit_object(mod);
}


def _link_macho_with_archive(relobj: bytes, triple: str, out: str, archive: str) {
    link_native(
        NativeLinkJob(
            platform="macho",
            triple=triple,
            output_path=out,
            objects=[relobj],
            archives=[archive],
            needed_libs=["/usr/lib/libSystem.B.dylib"]
        )
    );
}


"""Locate a bundled archive by name from any pbs build, or None."""
def _find_bundled(libname: str) -> (str | None) {
    jac_dir = Path(__file__).resolve().parents[4];
    hits = sorted(jac_dir.`glob(f".python-build/*/*/python/build/lib/{libname}"));
    hits += sorted(jac_dir.`glob(f".python-build/*/python/build/lib/{libname}"));
    return str(hits[0]) if hits else None;
}


test "Mach-O: static-link lzma_crc32 from liblzma.a, run, verify (#6978 0.1a)" {
    triple = llvm.get_default_triple();
    # Only macOS arm64 can both run the result and offers TLS-free floor archives.
    if not (sys.platform == "darwin" and "arm64" in triple) {
        return;
    }
    archive_path = _find_bundled("liblzma.a");
    if archive_path is None {
        return;  # no pbs build staged here
    }
    relobj = _emit_object(program_ir("static_archive_crc32.jac", triple), triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "crc32_static");
    _link_macho_with_archive(relobj, triple, out, archive_path);

    res = subprocess.run([out], capture_output=True, timeout=30);
    assert res.returncode == 0 , (f"exec exited {res.returncode}, stderr={res.stderr}");
    # CRC-32/ISO of "123456789" == 0xCBF43926 == 3421780262.
    assert b"3421780262" in res.stdout , f"unexpected output: {res.stdout}";
}


test "Mach-O: static-link XML_ExpatVersion from libexpat.a (multi-member) (#6978 0.1a)" {
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "arm64" in triple) {
        return;
    }
    archive_path = _find_bundled("libexpat.a");
    if archive_path is None {
        return;
    }
    # The program reaches several cross-referencing members (xmlparse +
    # xmltok + xmlrole + an entropy helper), exercising member<->member symbol
    # resolution and GOT references to libc.
    relobj = _emit_object(program_ir("static_archive_expat.jac", triple), triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "expat_static");
    _link_macho_with_archive(relobj, triple, out, archive_path);

    res = subprocess.run([out], capture_output=True, timeout=30);
    assert res.returncode == 0 , (f"exec exited {res.returncode}, stderr={res.stderr}");
    assert b"expat_" in res.stdout , f"unexpected output: {res.stdout}";
}


test "nacompile CLI: `import from lzma` static-links the floor, no dylib dep (#6978 0.1a)" {
    # Full integration through the real CLI: the clib floor import resolves to the
    # bundled archive, members are selected and merged, and the result has no
    # liblzma dependency (otool -L shows only libSystem).
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "arm64" in triple) {
        return;
    }
    if _find_bundled("liblzma.a") is None {
        return;
    }
    fixture = os.path.join(FIXTURES, "static_archive_crc32.jac");
    d = tempfile.mkdtemp();
    out = os.path.join(d, "crc32_cli");
    comp = subprocess.run(
        jac_command("build", "--native", fixture, "-o", out),
        capture_output=True,
        text=True,
        timeout=180
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-600:]}";
    assert "Static-linking" in comp.stdout , (
        f"floor was not static-linked: {comp.stdout[-600:]}"
    );

    res = subprocess.run([out], capture_output=True, timeout=30);
    assert res.returncode == 0 , f"exec exited {res.returncode}, stderr={res.stderr}";
    assert b"3421780262" in res.stdout , f"unexpected output: {res.stdout}";

    # The floor must be linked in, not a runtime dylib dependency.
    deps = subprocess.run(
        ["otool", "-L", out], capture_output=True, text=True, timeout=30
    );
    assert "lzma" not in deps.stdout , f"unexpected liblzma dep:\n{deps.stdout}";
}


test "ELF: static-link jac_floor_magic from a member object, run, verify (#6978 0.1a)" {
    # Pin an explicit ELF triple so the object is ELF on any host (this file also
    # runs on the macOS native job, whose default triple is darwin/Mach-O).
    # Execution stays gated to a Linux x86_64 host that can run the result.
    triple = "x86_64-unknown-linux-gnu";
    main_obj = _emit_object(
        program_ir("static_archive_elf_leaf.jac", triple, static_musl=True), triple
    );
    # A leaf object defining the extern the main object calls. Emitted from
    # IR so the test needs no checked-in binary and no host C toolchain.
    member_ir = f'target triple = "{triple}"\n\n'
        + "define i64 @jac_floor_magic() {\nentry:\n  ret i64 1234605616436508552\n}\n";
    member_obj = _emit_object(member_ir, triple);

    d = tempfile.mkdtemp();
    out = os.path.join(d, "floor_static_elf");
    runtime = musl_runtime(triple);
    if runtime is None {
        return;
    }
    (crt, archives) = runtime;
    # Were the member not linked, `jac_floor_magic` would stay undefined
    # (resolved to 0) and the program would crash, so a clean run proves it.
    link_native(
        NativeLinkJob(
            platform="elf",
            triple=triple,
            output_path=out,
            objects=[main_obj, member_obj],
            crt_objects=crt,
            archives=archives,
            static_musl=True
        )
    );
    raw = Path(out).read_bytes();
    assert raw[:4] == b"\x7fELF" , "not an ELF image";
    e_type = struct.unpack_from("<H", raw, 16)[0];
    assert e_type == 2 , f"expected ET_EXEC (2), got {e_type}";

    # Only a Linux x86_64 host can execute the produced ELF. Were the member not
    # merged, jac_floor_magic would stay an unresolved libc import and the loader
    # would abort -- so a clean run with the right value proves the merge.
    if sys.platform.startswith("linux") and ("x86_64" in llvm.get_default_triple()) {
        res = subprocess.run([out], capture_output=True, timeout=30);
        assert res.returncode == 0 , (
            f"exec exited {res.returncode}, stderr={res.stderr}"
        );
        assert b"1234605616436508552" in res.stdout , f"unexpected output: {res.stdout}";
    }
}
