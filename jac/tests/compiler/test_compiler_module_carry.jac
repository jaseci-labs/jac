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
"""

import marshal;
import os;
import tempfile;
import from pathlib { Path }
import jaclang.compiler.driver.jir as jir;
import from jaclang.compiler.driver.jir {
    FLAG_CARRIED,
    SEC_CTDEPS,
    SEC_MODKEY,
    carried_module_bytecode,
    ct_deps_section,
    get_module_cache_path,
    is_module_cache_valid,
    module_cache_invalid_reason,
    parse_header,
    py_emitter_digest,
    read_sections_blob,
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

def checkout -> Checkout {
    return Checkout(cache=tempfile.mkdtemp());
}

def rewrite_entry(sections: dict[int, bytes]) {
    slot = get_module_cache_path(MODULE);
    merged = read_sections_blob(slot.read_bytes());
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
