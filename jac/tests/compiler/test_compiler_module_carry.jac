"""A compiler edit rebuilds the modules it touched, not the whole compiler.

Every edit under the compiler's sources mints a new cache generation, and the
compiler's own modules used to be recompiled into it one by one: about two
minutes before the next command could run, for a one-line change. In a source
checkout an unchanged module now takes its bytecode from the generation an
earlier compiler wrote.

What makes that safe is what these tests hold: the module's own source and
annexes, its compile-time dependencies and the Python emitter must all be what
they were. Anything that builds a distributable, and any checkout that asks,
stays exact and never accepts carried bytecode.

The compiler's native kernel follows the same rule one level down. A kernel
unit built in a source checkout is stamped with the kernel's ABI, not with the
compiler that happened to lower it, so an edit elsewhere in the compiler
leaves its interface, bitcode and object valid; the unit's own source, its
compile-time rows and its dependencies' interfaces still decide. A user
program's native products keep the exact compiler stamp, in a checkout too.
"""

import marshal;
import os;
import tempfile;
import from pathlib { Path }
import jaclang.compiler.driver.jir as jir;
import from jaclang.compiler.driver.jir {
    DEV_NATIVE_PRODUCER,
    FLAG_CARRIED,
    SEC_CTDEPS,
    SEC_MODKEY,
    SEC_NIFACE,
    SEC_NOBJ,
    carried_module_bytecode,
    carried_native_sections,
    current_native_stamp,
    ct_deps_section,
    get_module_cache_path,
    is_module_cache_valid,
    merge_native_sections,
    module_cache_invalid_reason,
    native_producer_digest,
    native_section_payload,
    native_section_variants,
    parse_header,
    py_emitter_digest,
    read_sections,
    running_compiler_digest,
    write_module_cache,
    write_precompiled_jir
}
import from tests.support { cache_env }

glob PKG: Path = Path(str(jir.__file__)).resolve().parent.parent.parent,
     MODULE: str = str(PKG / "cache" / "policy.jac"),
     EMITTER_ROW: str = "compiler/backends/py/jcir_gen_pass.jac",
     NATIVE_ROW: str = "compiler/backends/native/link_plan.jac",
     INTERPRETER_ROW: str = "compiler/backends/py/jacpython/runtime.jac",
     SCRUBBED_ENV: tuple[str, ...] = (
         "JAC_DEV_EXACT",
         "JAC_PRECOMPILE_REQUIRED",
         "JAC_REBUILD",
         "JAC_NO_PRECOMPILE"
     );

"""A source checkout with its own cache, entered as one compiler build after
another. Each build is a generation directory, a compiler digest and the
input rows the emitter identity is folded from."""
obj Checkout {
    has cache: str,
        saved_env: dict[str, (str | None)] = {},
        saved_digest: list[str] = [],
        saved_generation: list[str] = [],
        minted: list[str] = [];

    def __enter__ -> Checkout {
        env = dict(cache_env(self.cache));
        env["JAC_DEV_SOURCE"] = str(PKG.parent);
        for name in SCRUBBED_ENV {
            self.saved_env[name] = os.environ.pop(name, None);
        }
        for (name, value) in env.items() {
            self.saved_env[name] = os.environ.get(name);
            os.environ[name] = value;
        }
        self.saved_digest = list(jir._COMPILER_DIGEST_CACHE);
        self.saved_generation = list(jir._COMPILER_GENERATION_CACHE);
        return self;
    }

    def __exit__(exc_type: any, exc: any, trace: any) {
        for (name, value) in self.saved_env.items() {
            if value is None {
                os.environ.pop(name, None);
            } else {
                os.environ[name] = value;
            }
        }
        jir._COMPILER_DIGEST_CACHE.clear();
        jir._COMPILER_DIGEST_CACHE.extend(self.saved_digest);
        jir._COMPILER_GENERATION_CACHE.clear();
        jir._COMPILER_GENERATION_CACHE.extend(self.saved_generation);
        for digest in self.minted {
            jir._COMPILER_INPUT_ROWS.pop(digest, None);
            jir._PY_EMITTER_DIGESTS.pop(digest, None);
            jir._NATIVE_PRODUCER_DIGESTS.pop(digest, None);
        }
    }

    def build(
        tag: str, emitter: str = "e0", native: str = "n0", interpreter: str = "i0"
    ) {
        digest = "3:" + tag * 64;
        self.minted.append(digest);
        jir._COMPILER_DIGEST_CACHE.clear();
        jir._COMPILER_DIGEST_CACHE.append(digest);
        jir._COMPILER_GENERATION_CACHE.clear();
        jir._COMPILER_GENERATION_CACHE.append(tag * 16);
        jir._COMPILER_INPUT_ROWS[digest] = [
            (EMITTER_ROW, emitter),
            (NATIVE_ROW, native),
            (INTERPRETER_ROW, interpreter)
        ];
        jir._PY_EMITTER_DIGESTS.pop(digest, None);
    }
}

glob _warmed: list[bool] = [];

"""A checkout moves the cache, and a compiler module first imported after
that would be compiled into the empty one. Compiling one small program first
loads the pipeline from the cache this process started with."""
def warm_compiler {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.program { JacProgram }
    if _warmed {
        return;
    }
    _warmed.append(True);
    with tempfile.TemporaryDirectory() as scratch {
        probe = Path(scratch) / "probe.jac";
        probe.write_text("def double(x: int) -> int {\n    return x * 2;\n}\n");
        assert JacCompiler().get_bytecode(str(probe), JacProgram()) is not None;
    }
}

def checkout -> Checkout {
    warm_compiler();
    return Checkout(cache=tempfile.mkdtemp());
}

def entry_sections(slot: Path) -> dict[int, bytes] {
    data = slot.read_bytes();
    magic: any = jir.SECTIONS_MAGIC;
    return read_sections(data, data.find(magic, jir.HEADER_SIZE) + len(magic));
}

def rewrite_entry(sections: dict[int, bytes]) {
    slot = get_module_cache_path(MODULE);
    merged = entry_sections(slot);
    assert merged , "the entry under edit has no sections";
    merged.update(sections);
    slot.write_bytes(write_precompiled_jir(None, "", 0, merged));
}

def entry_flags -> int {
    header = parse_header(get_module_cache_path(MODULE).read_bytes()[:jir.HEADER_SIZE]);
    assert header is not None;
    return header.flags;
}

test "an unchanged compiler module is carried to the next compiler build" {
    with checkout() as tree {
        tree.build("a");
        assert write_module_cache(MODULE, b"emitted-by-a");
        assert carried_module_bytecode(MODULE) is None , "a build carried from itself";
        tree.build("b", native="n1");
        assert not get_module_cache_path(MODULE).exists();
        assert carried_module_bytecode(MODULE) == (b"emitted-by-a", b"");
    }
}

test "the interpreter beside the Python backend is not the emitter" {
    with checkout() as tree {
        tree.build("a");
        before = py_emitter_digest();
        write_module_cache(MODULE, b"emitted-by-a");
        tree.build("b", interpreter="i1");
        assert py_emitter_digest() == before;
        assert carried_module_bytecode(MODULE) == (b"emitted-by-a", b"");
    }
}

test "a changed Python emitter carries nothing" {
    with checkout() as tree {
        tree.build("a");
        before = py_emitter_digest();
        write_module_cache(MODULE, b"emitted-by-a");
        tree.build("b", emitter="e1");
        assert py_emitter_digest() != before;
        assert carried_module_bytecode(MODULE) is None , "bytecode outlived the emitter that produced it";
    }
}

test "a module whose own source changed is not carried" {
    with checkout() as tree {
        tree.build("a");
        write_module_cache(MODULE, b"emitted-by-a");
        rewrite_entry({SEC_MODKEY: b"the key of an earlier revision of this module"});
        tree.build("b", native="n1");
        assert carried_module_bytecode(MODULE) is None , "bytecode of an edited module was reused";
    }
}

test "a module whose compile-time dependency changed is not carried" {
    with checkout() as tree {
        dep = Path(tree.cache) / "folded.jac";
        dep.write_text("glob LIMIT: int = 4;\n");
        tree.build("a");
        rows = ct_deps_section([str(dep)]);
        write_module_cache(MODULE, b"emitted-by-a", extra_sections={SEC_CTDEPS: rows});
        tree.build("b", native="n1");
        assert carried_module_bytecode(MODULE) == (b"emitted-by-a", rows);
        dep.write_text("glob LIMIT: int = 5;\n");
        assert carried_module_bytecode(MODULE) is None , "a folded value outlived its source";
    }
}

test "the most recent earlier build is the one carried" {
    with checkout() as tree {
        tree.build("a");
        write_module_cache(MODULE, b"emitted-by-a");
        os.utime(get_module_cache_path(MODULE), (1000.0, 1000.0));
        tree.build("b");
        write_module_cache(MODULE, b"emitted-by-b");
        os.utime(get_module_cache_path(MODULE), (2000.0, 2000.0));
        tree.build("c", native="n1");
        assert carried_module_bytecode(MODULE) == (b"emitted-by-b", b"");
    }
}

test "nothing is carried outside a source checkout" {
    with checkout() as tree {
        tree.build("a");
        write_module_cache(MODULE, b"emitted-by-a");
        tree.build("b", native="n1");
        assert carried_module_bytecode(MODULE) is not None;
        os.environ["JAC_DEV_SOURCE"] = tree.cache;
        assert carried_module_bytecode(MODULE) is None , "another checkout's compiler was carried";
        del os.environ["JAC_DEV_SOURCE"];
        assert carried_module_bytecode(MODULE) is None , "an installed compiler carried bytecode";
    }
}

test "a build that requires its bundle or asks to be exact carries nothing" {
    for name in ["JAC_DEV_EXACT", "JAC_PRECOMPILE_REQUIRED"] {
        with checkout() as tree {
            tree.build("a");
            write_module_cache(MODULE, b"emitted-by-a");
            tree.build("b", native="n1");
            os.environ[name] = "1";
            assert carried_module_bytecode(MODULE) is None , f"{name} still carried bytecode";
        }
    }
}

test "carried bytecode is refused by an exact build and replaced by a real compile" {
    with checkout() as tree {
        tree.build("a");
        write_module_cache(MODULE, b"emitted-by-a");
        tree.build("b", native="n1");
        write_module_cache(MODULE, b"emitted-by-a", flags=FLAG_CARRIED);
        slot = get_module_cache_path(MODULE);
        assert entry_flags() & FLAG_CARRIED;
        assert is_module_cache_valid(MODULE, slot);
        os.environ["JAC_DEV_EXACT"] = "1";
        assert module_cache_invalid_reason(MODULE, slot)
            == "bytecode carried from an earlier compiler";
        write_module_cache(MODULE, b"emitted-by-b");
        assert not (entry_flags() & FLAG_CARRIED) , "a real compile kept the carried mark";
        assert is_module_cache_valid(MODULE, slot);
    }
}

test "the compiler loads a carried module without compiling it" {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.program { JacProgram }
    with checkout() as tree {
        compiler = JacCompiler();
        if compiler._sealed_jir_data(MODULE) is not None {
            return;
        }
        os.environ["JAC_NO_PRECOMPILE"] = "1";
        tree.build("a");
        code = compile("CARRIED = 41 + 1\n", MODULE, "exec");
        write_module_cache(MODULE, marshal.dumps(code));
        tree.build("b", native="n1");
        loaded = compiler.get_bytecode(MODULE, JacProgram());
        assert loaded is not None;
        scope: dict[str, any] = {};
        exec(loaded, scope);
        assert scope["CARRIED"] == 42 , "the module was compiled instead of carried";
        assert entry_flags() & FLAG_CARRIED , "the carried entry is not marked";
        assert is_module_cache_valid(MODULE, get_module_cache_path(MODULE));
    }
}

glob KERNEL_LEAVES: tuple[str, ...] = (
         "compiler/types/ct_int.jac",
         "project/app_kinds.jac",
         "runtime/osp_tag.jac"
     );

"""The native products one build wrote for the module, as a kernel unit or as
part of a user program."""
def write_native(kernel: bool, payload: bytes) -> jir.NativeStamp {
    stamp = current_native_stamp("gc=cycles", "host", native_producer_digest(kernel));
    write_module_cache(
        MODULE,
        None,
        extra_sections={SEC_NIFACE: stamp.pack(payload), SEC_NOBJ: stamp.pack(payload)}
    );
    return stamp;
}

"""Plan a kernel made of leaf units of the real compiler and name the units
that were lowered to do it. `cached` off lowers every unit whatever the cache
holds, which loads the native backend before a test moves the cache."""
def lowered_kernel_units(cached: bool = True) -> list[str] {
    import from jaclang.compiler.backends.native.kernel_resolve { kernel_options }
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    import from jaclang.compiler.driver.program { JacProgram }
    program = JacProgram();
    roots = [str(PKG / rel) for rel in KERNEL_LEAVES];
    options = kernel_options();
    options.no_ir_cache = not cached;
    build_link_plan(program, roots, options, native_unit=True);
    return sorted({Path(p).name for p in program.native_units().compiled_paths});
}

test "a kernel unit is stamped with the kernel's ABI in a source checkout" {
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ABI_VERSION }
    with checkout() as tree {
        tree.build("a");
        first = native_producer_digest(True);
        assert first.startswith(f"{DEV_NATIVE_PRODUCER}{NATIVE_ABI_VERSION}:");
        tree.build("b", native="n1", emitter="e1");
        assert native_producer_digest(True) == first , "a compiler edit changed the kernel's stamp";
        assert native_producer_digest(False) == running_compiler_digest() , (
            "a user program's products lost the compiler that built them"
        );
        os.environ["JAC_DEV_EXACT"] = "1";
        assert native_producer_digest(True) == running_compiler_digest() , (
            "an exact build stamped a kernel unit by its ABI"
        );
    }
}

test "a kernel unit's native products are carried to the next compiler build" {
    with checkout() as tree {
        tree.build("a");
        stamp = write_native(True, b"lowered-by-a");
        tree.build("b", native="n1");
        carried = carried_native_sections(MODULE, native_producer_digest(True));
        assert sorted(carried) == [SEC_NIFACE, SEC_NOBJ];
        assert native_section_payload(carried[SEC_NIFACE], stamp) == b"lowered-by-a";
        assert native_section_payload(carried[SEC_NOBJ], stamp) == b"lowered-by-a";
    }
}

test "native products stamped with a compiler are never carried" {
    with checkout() as tree {
        tree.build("a");
        write_native(False, b"lowered-by-a");
        tree.build("b", native="n1");
        assert carried_native_sections(MODULE, native_producer_digest(True)) == {};
        assert carried_native_sections(MODULE, native_producer_digest(False)) == {} , (
            "a user program took an earlier compiler's native products"
        );
    }
}

test "an edited kernel unit's native products are not carried" {
    with checkout() as tree {
        tree.build("a");
        write_native(True, b"lowered-by-a");
        rewrite_entry({SEC_MODKEY: b"the key of an earlier revision of this module"});
        tree.build("b", native="n1");
        assert carried_native_sections(MODULE, native_producer_digest(True)) == {};
    }
}

test "an exact build carries no native products" {
    with checkout() as tree {
        tree.build("a");
        write_native(True, b"lowered-by-a");
        tree.build("b", native="n1");
        kernel = native_producer_digest(True);
        os.environ["JAC_DEV_EXACT"] = "1";
        assert carried_native_sections(MODULE, kernel) == {};
    }
}

test "a unit's kernel products and a user build's products coexist" {
    with checkout() as tree {
        tree.build("a");
        kernel = write_native(True, b"kernel");
        user_a = write_native(False, b"user-a");
        written = entry_sections(get_module_cache_path(MODULE));
        assert {kernel.key(), user_a.key()}
            <= set(native_section_variants(written[SEC_NIFACE]));
        tree.build("b", native="n1");
        user_b = current_native_stamp(
            "gc=cycles", "host", native_producer_digest(False)
        );
        merged = merge_native_sections(written, {SEC_NIFACE: user_b.pack(b"user-b")});
        keys = set(native_section_variants(merged[SEC_NIFACE]));
        assert kernel.key() in keys , "a user build pruned the kernel's products";
        assert user_b.key() in keys;
        assert user_a.key() not in keys , "an earlier compiler's user products survived";
    }
}

test "an unrelated compiler edit lowers no kernel unit again" {
    lowered_kernel_units(cached=False);
    with checkout() as tree {
        tree.build("a");
        cold = lowered_kernel_units();
        assert set(cold) >= {Path(rel).name for rel in KERNEL_LEAVES} , cold;
        assert lowered_kernel_units() == [];
        tree.build("b", native="n1");
        assert lowered_kernel_units() == [] , "a compiler edit lowered unchanged kernel units";
        os.environ["JAC_DEV_EXACT"] = "1";
        assert lowered_kernel_units() == cold , "an exact build reused a kernel unit";
    }
}

test "a kernel linked before a compiler edit is still accepted after it" {
    import sys;
    import from jaclang.compiler.backends.native.kernel_resolve {
        _unit_sources_match,
        kernel_options
    }
    import from jaclang.compiler.backends.native.link_plan { units_source_key }
    import from jaclang.compiler.driver.jir { unit_source_digest }
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    with checkout() as tree {
        tree.build("a");
        options = kernel_options();
        ident = native_unit_identity(MODULE);
        sidecar: dict[str, any] = {
            "compiler_digest": native_producer_digest(True),
            "codegen_identity": options.base_codegen_identity(),
            "triple": options.effective_triple(),
            "python": f"{sys.version_info.major}.{sys.version_info.minor}",
            "unit_ids": [ident],
            "unit_policy": {ident: int(options.native_required_for(MODULE))}
        };
        recorded = {ident: unit_source_digest(MODULE)};
        source_key = units_source_key([MODULE], options);
        assert _unit_sources_match(sidecar, recorded, [MODULE]);
        tree.build("b", native="n1");
        assert _unit_sources_match(sidecar, recorded, [MODULE]) , (
            "a compiler edit outside the kernel's units retired the kernel"
        );
        assert units_source_key([MODULE], options) == source_key;
        assert not _unit_sources_match(
            sidecar, {ident: "an earlier revision"}, [MODULE]
        );
        os.environ["JAC_DEV_EXACT"] = "1";
        assert not _unit_sources_match(sidecar, recorded, [MODULE]) , (
            "an exact build accepted a kernel stamped by its ABI"
        );
        assert units_source_key([MODULE], options) != source_key;
    }
}
