"""The aarch64 LSE outline-atomics helpers a sealed artifact has to carry itself.

The aarch64 C floor (pbs's libcrypto, libpython and friends) is built with
`-moutline-atomics`, so every atomic in it compiles to a call into the LSE
dispatch family -- `__aarch64_ldadd4_relax` and ninety-nine siblings. Those
helpers live only in a static libgcc/compiler-rt: `libgcc_s.so.1` exports not
one of them. Nothing in the floor set defines them either, so a sealed shared
library linked perfectly clean and then died at `dlopen` with

    libjac_unitree.so: undefined symbol: __aarch64_ldadd4_relax

Executables link the same floor archives and pay the same debt. Once the
launcher stopped being a Zig-linked stub and became `jac nacompile --strict
launcher/launcher.jac` (#8468), nothing supplied compiler_rt for it any more,
and the linux/arm64 `jac` binary linked clean and then refused to start with

    jac: symbol lookup error: jac: undefined symbol: __aarch64_ldset8_acq_rel

(#8727). So the emitter hangs off the link plan's glue module
(`link_glue.link_glue_ir`), the one point every `nacompile` artifact passes
through -- shared library and executable alike -- and it is keyed on the
TARGET triple, not on `platform.machine()`: the host
that cross-compiles an aarch64 image is usually an x86_64 runner.

Our own codegen is not the source and cannot be the fix: under the exact target
machine the link plan builds, LLVM lowers `atomicrmw` to inline `ldxr`/`stxr`
and never calls a helper. The vendored objects are the callers, so the artifact
has to bring the callees. The vendored `libcompiler_rt.a` does define all one
hundred, but as a single 1.9 MB object that also redefines `strlen`, `memset`
and `memcmp` -- merging it would collide with libc. So the family is emitted as
module-level assembly instead, ~2.4 KB of it, `.weak` and `.hidden` so it can
neither collide with nor escape into anything else.

These helpers use a restricted register contract: a caller may assume only x0,
x1, x15, x16, x17 and the flags are clobbered. That rules out writing them in
IR -- no LLVM calling convention matches -- which is why they are assembly, and
why these tests exist. They always take the LL/SC path rather than dispatching
on `__aarch64_have_lse_atomics`, which is correct on every ARMv8 and costs only
the LSE fast path.

Pinned here on every host: the family is complete and every member is weak and
hidden, both restated from the ABI's own axes rather than read back out of the
generator, the block is well-formed IR, and -- since #8788 -- a real aarch64
object assembles out of the executable path on ANY host, carrying all one
hundred helpers into its symbol table.

That last one is the lesson of #8788. Parsing is not assembling: `parse_assembly`
accepts a `module asm` block without looking inside it, and the failure lands
later, when the streamer has to hand the block to an asm parser for the target
and finds none registered. It is `report_fatal_error`, so the process aborts:

    LLVM ERROR: Inline asm not supported by this streamer because we don't have
    an asm parser for this target

The parse-level test that shipped with #8781 stopped exactly one step short of
that, which is why the object-emission test below runs in a subprocess.

There are two object-emission tests, and the difference between them is the
whole point. One calls `init_object_codegen` itself and proves the emitter
works: every helper assembles and reaches the symbol table, on any host. It
does NOT prove that `jac nacompile` calls that initialization, so the
executable path could drop it and that test would stay green -- which is the
shape of the original miss, one level up. The other drives the real
`jac nacompile` CLI and pins the property that actually broke the release:
the executable compile path registers an asm parser for ITS target.

Not pinned here at all, because it needs an aarch64 machine: the semantics. Each
helper was run under qemu-aarch64 against a C harness checking the returned old
value, the stored new value, sub-word CAS's zero-extension of a caller's wide
`expected`, and cas16's paired compare -- all four orderings of all of it.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.backends.native.link_glue {
    GlueSpec,
    GlueUnit,
    aarch64_floor_atomics_ir,
    aarch64_outline_atomics_ir,
    link_glue_ir
}

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

"""Every symbol the LSE outline-atomics ABI defines, spelled out from its axes."""
def _abi_family -> list[str] {
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

"""The generated block with its `module asm "..."` wrapper peeled back off."""
def _raw_asm -> list[str] {
    out: list[str] = [];
    for ln in aarch64_outline_atomics_ir().splitlines() {
        s = ln.strip();
        if s.startswith("module asm \"") and s.endswith("\"") {
            out.append(s[len("module asm \""):-1]);
        }
    }
    return out;
}

test "the emitted family covers the whole outline-atomics ABI" {
    defined = {
        ln[:-1]
        for ln in _raw_asm()
        if ln.endswith(":") and not ln.startswith(".")
    };
    want = _abi_family();
    assert len(want) == 100 , f"the ABI has 100 helpers, not {len(want)}";
    missing = sorted(
        {
            n
            for n in want
            if n not in defined
        }
    );
    assert not missing , (
        f"{len(missing)} outline-atomics helper(s) unemitted, so a floor object "
        f"calling one would leave the artifact unloadable: {missing[:6]}"
    );
    assert "__aarch64_have_lse_atomics" in defined , (
        "the LSE feature flag must be defined too: an object carrying its own "
        "copy of the helpers references it directly"
    );
}

test "every helper is weak and hidden, so it neither collides nor escapes" {
    asm = _raw_asm();
    for nm in _abi_family() {
        assert f"  .weak {nm}" in asm , (
            f"{nm} is not weak; a floor member carrying its own copy would "
            "make this a duplicate-symbol link failure"
        );
        assert f"  .hidden {nm}" in asm , (
            f"{nm} is not hidden; it would join the artifact's dynamic symbol "
            "table and interpose on every other library's copy"
        );
    }
}

test "an aarch64 host assembles every instruction through the NATIVE parser" {
    # Module-level asm is assembled by the MC layer's *assembly parser*. Since
    # #8788 the shim registers every target's, so the cross-host case is covered
    # by the object-emission test at the bottom of this file; what is left here
    # is the host==target path through LLVMPY_InitializeNativeAsmParser, which
    # is still what an aarch64 machine takes. It stays in-process and therefore
    # host-gated: a missing parser is report_fatal_error, and an abort in here
    # would take the whole file's worker with it.
    import platform;

    if platform.machine() not in ["aarch64", "arm64"] {
        return;
    }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    llvm.initialize_native_asmparser();
    src = (
        "target triple = \"aarch64-unknown-linux-gnu\"\n" + aarch64_outline_atomics_ir()
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    tgt = llvm.Target.from_triple("aarch64-unknown-linux-gnu");
    tm = tgt.create_target_machine(opt=2, reloc="pic", codemodel="small");
    blob = tm.emit_object(mod);
    assert len(blob) > 0 , "the assembler produced no object at all";
    absent = sorted(
        {
            nm
            for nm in _abi_family()
            if nm.encode("utf-8") not in blob
        }
    );
    assert not absent , (
        f"{len(absent)} helper(s) never reached the object's symbol table: "
        f"{absent[:6]}"
    );
}

test "the asm block is well-formed IR on every host, not just aarch64" {
    # Parsing is host-independent. It does not assemble the asm, but it does
    # prove the block is well-formed IR -- a stray quote in a `module asm` line
    # would take down every sealed artifact on every platform, not only this
    # one, and that must not wait for a release leg to surface.
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    src = (
        "target triple = \"aarch64-unknown-linux-gnu\"\n" + aarch64_outline_atomics_ir()
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    text = str(mod);
    for nm in _abi_family() {
        assert nm in text , f"{nm} did not survive into the parsed module";
    }
}


"""The glue IR the link plan (`link_plan.build_link_plan` ->
`link_artifact`) synthesizes beside its units for one target, straight off
the production emitter (`link_glue.link_glue_ir`): one stub root unit with
no initializer or entry body. Every argument but the ones a test varies is
the launcher's own shape: a plain executable, not shared, not Windows, not
macOS. The text carries its own `target triple` line."""
def _finalized(
    triple: str,
    clib_paths: list[str],
    shared: bool = False,
    is_macos: bool = False,
    static_musl: bool = False
) -> str {
    spec = GlueSpec(
        units=[GlueUnit(prefix="stub_root")],
        root_index=0,
        shared=shared,
        platform="macho" if is_macos else "elf",
        static_musl=static_musl,
        triple=triple,
        clib_paths=list(clib_paths)
    );
    (out, _exports) = link_glue_ir(spec);
    return out;
}


test "the aarch64 executable path defines the whole family (issue #8727)" {
    # This host is x86_64 in CI and on every dev box that is not an ARM Mac, so
    # a pass here is also the proof that the decision follows the TARGET and not
    # `platform.machine()` -- the bug that made the injection wrong under the
    # cross-compiling release legs.
    ir = _finalized("aarch64-unknown-linux-gnu", ["libz.so"]);
    assert "__aarch64_ldset8_acq_rel" in ir , (
        "the aarch64 executable path emitted no __aarch64_ldset8_acq_rel; a "
        "floor object calling it leaves the binary unable to start at all "
        "(`jac: symbol lookup error: jac: undefined symbol: "
        "__aarch64_ldset8_acq_rel`)"
    );
    missing = sorted(
        {
            n
            for n in _abi_family()
            if n not in ir
        }
    );
    assert not missing , (
        f"{len(missing)} outline-atomics helper(s) missing from the aarch64 "
        f"executable's IR: {missing[:6]}"
    );
}


test "the static-musl executable path defines them too" {
    ir = _finalized("aarch64-unknown-linux-musl", ["libz.so"], static_musl=True);
    assert "__aarch64_ldset8_acq_rel" in ir , (
        "a fully static aarch64 executable merges the same floor archive "
        "members, so it needs the same callees"
    );
}


test "the aarch64 shared-library path defines them too" {
    ir = _finalized("aarch64-unknown-linux-gnu", ["libz.so"], shared=True);
    assert "__aarch64_ldset8_acq_rel" in ir , (
        "`jac nacompile --shared` links the floor archives as well; this is "
        "the dlopen failure the family was first written for"
    );
}


test "a non-aarch64 target carries none of them" {
    ir = _finalized("x86_64-unknown-linux-gnu", ["libz.so"]);
    assert "__aarch64_" not in ir , (
        "the helpers are aarch64 machine code; an x86_64 artifact carrying "
        "them would not assemble"
    );
}


test "an artifact that links no floor archive carries none of them" {
    ir = _finalized("aarch64-unknown-linux-gnu", []);
    assert "__aarch64_" not in ir , (
        "our own codegen never calls these -- with no vendored objects in the "
        "link there is no caller, so nothing to define"
    );
}


test "an aarch64 Mach-O artifact carries none of them" {
    ir = _finalized("arm64-apple-darwin", ["libz.dylib"], is_macos=True);
    assert "__aarch64_" not in ir , (
        "`.hidden` and `%function` are ELF directives, and Apple's toolchain "
        "supplies the helpers itself; emitting them here would fail to "
        "assemble"
    );
}


test "the finalized aarch64 executable IR still parses" {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    src = _finalized("aarch64-unknown-linux-gnu", ["libz.so"]);
    assert src.startswith('target triple = "aarch64-unknown-linux-gnu"') , src[:80];
    mod = llvm.parse_assembly(src);
    mod.verify();
    text = str(mod);
    for nm in _abi_family() {
        assert nm in text , (f"{nm} did not survive into the parsed executable module");
    }
}


test "the emitter itself is gated on the target, not the host" {
    # `link_glue_ir` is the one consumer, for executables and shared
    # libraries alike, so the gate is pinned on the helper directly as well
    # as through the glue path above.
    assert aarch64_floor_atomics_ir("aarch64-unknown-linux-gnu", ["libz.so"]) != "";
    assert aarch64_floor_atomics_ir("aarch64-unknown-linux-gnu", []) == "";
    assert aarch64_floor_atomics_ir("x86_64-unknown-linux-gnu", ["libz.so"]) == "";
    assert aarch64_floor_atomics_ir("arm64-apple-darwin", ["libz.dylib"]) == "";
    assert aarch64_floor_atomics_ir("aarch64-pc-windows-msvc", ["z.lib"]) == "";
}


test "the aarch64 executable path assembles to a real object (#8788)" {
    # The whole point of this one is that it does NOT stop at parse_assembly.
    # Emitting the object is where the missing asm parser aborts, and abort is
    # not catchable, so the emit runs in its own process. On an x86_64 host this
    # is also the cross-compilation case (`jac nacompile --target aarch64-...`),
    # where a host-only asm parser is no help at all.
    fixture = os.path.join(FIXTURES, "emit_aarch64_atomics_obj.jac");
    res = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", fixture],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert res.returncode == 0 , (
        f"emitting an aarch64 object out of the executable path exited "
        f"{res.returncode}; a `module asm` block needs an asm parser "
        f"registered for the TARGET, and LLVM aborts the process when there "
        f"is none.\nstdout: {res.stdout[-800:]}\nstderr: {res.stderr[-800:]}"
    );
    assert "EMIT_OK" in res.stdout , (
        f"the object emitted, but not as an aarch64 ELF carrying every member "
        f"of the outline-atomics family.\nstdout: {res.stdout[-800:]}"
    );
}


test "jac nacompile itself registers a parser for its target (#8788)" {
    # The property that broke the aarch64 release build, driven through the real
    # CLI rather than through a helper the test initializes for itself: revert
    # link_glue's `init_object_codegen()` (which `link_plan` runs before it
    # creates a target machine) to the bare initialize_all_targets/asmprinters
    # pair and this goes red, which is the control the previous test did not
    # answer.
    #
    # The C floor import is what puts `module asm` in this module at all, so
    # JAC_DUMP_IR is read back first: it holds the finalized module, written
    # just BEFORE emission, and is therefore present in the aborting case too.
    # Without that check a fixture that quietly lost its clib import would make
    # this pass while proving nothing.
    #
    # No aarch64 toolchain is involved. The abort is at object emission, which
    # is upstream of linking, so cross-compiling from any host reaches it.
    work = tempfile.mkdtemp();
    dump = os.path.join(work, "finalized.ll");
    env = dict(os.environ);
    env["JAC_DUMP_IR"] = dump;
    res = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            "--target",
            "aarch64-unknown-linux-gnu",
            os.path.join(FIXTURES, "static_archive_crc32.jac"),
            "-o",
            os.path.join(work, "crc32_aarch64")
        ],
        capture_output=True,
        text=True,
        timeout=900,
        env=env
    );
    out = res.stdout + res.stderr;

    assert os.path.isfile(dump) , (
        f"nacompile never dumped its finalized module, so nothing here says "
        f"whether the run carried module asm at all.\n{out[-800:]}"
    );
    with open(dump) as _f {
        finalized = _f.read();
    }
    assert "__aarch64_ldset8_acq_rel" in finalized , (
        "the fixture compiled without the outline-atomics helpers in its "
        "module, so this run exercised nothing: the helpers ride on a C floor "
        "import, and static_archive_crc32.jac must keep one"
    );

    assert "Inline asm not supported by this streamer" not in out , (
        f"jac nacompile aborted assembling the outline-atomics `module asm` "
        f"for an aarch64 target: the executable compile path registered no asm "
        f"parser for the target it was emitting.\n{out[-800:]}"
    );
    assert res.returncode not in [134, -6] , (
        f"jac nacompile died on SIGABRT ({res.returncode}) emitting for "
        f"aarch64.\n{out[-800:]}"
    );
    assert "Object code emitted" in out , (
        f"jac nacompile never got past object emission for an aarch64 target, "
        f"which is where a missing asm parser kills it.\n{out[-800:]}"
    );
}
