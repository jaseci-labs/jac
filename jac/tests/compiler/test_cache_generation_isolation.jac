"""One binary, several compiler trees, one cache: the slots must not collide.

The dev loop picks a compiler source per process from the nearest `jac.toml`,
so two checkouts can compile the same file concurrently through the same
binary. The module cache keyed only the source path, and the compiler identity
lived in the JIR's ENVKEY -- a field read *after* the file was opened. Both
trees therefore targeted one filename and each rejected, then overwrote, what
the other had just written: correct results, unbounded rebuilds.

The compiler digest now names a generation directory, so each tree owns its
own slot. Generations are cheap to create -- every compiler edit mints one --
so an unused generation is swept once it goes untouched past the TTL, and the
pre-generation flat layout retires the same way. The live generation is held
by identity, never by age.
"""

import os;
import tempfile;
import time;
import from pathlib { Path }
import jaclang.compiler.driver.jir as jir;
import from jaclang.compiler.driver.jir {
    get_module_cache_path,
    get_native_debug_dir,
    sweep_stale_generations
}

glob GEN_A: str = "a" * 16,
     GEN_B: str = "b" * 16,
     GEN_C: str = "c" * 16,
     STALE_AGE: float = 40.0 * 86400.0;

def _pin_generation(tag: str) {
    jir._COMPILER_GENERATION_CACHE.clear();
    jir._COMPILER_GENERATION_CACHE.append(tag);
}

def _unpin_generation {
    jir._COMPILER_GENERATION_CACHE.clear();
}

def _seeded_module -> str {
    tmp = tempfile.mkdtemp();
    src = os.path.join(tmp, "mod.jac");
    with open(src, "w") as f {
        f.write("with entry { print('x'); }\n");
    }
    return src;
}

def _age(path: Path) {
    old = time.time() - STALE_AGE;
    os.utime(path, (old, old));
}

test "two compiler generations get disjoint cache slots for one module" {
    src = _seeded_module();
    _pin_generation(GEN_A);
    first = get_module_cache_path(src);
    _pin_generation(GEN_B);
    second = get_module_cache_path(src);
    _unpin_generation();
    assert first != second , "one cache slot served two compiler generations";
    assert first.name == second.name , "only the generation directory may differ";
    assert first.parent.name == GEN_A;
    assert second.parent.name == GEN_B;
    assert first.parent.parent == second.parent.parent , (
        "generations must be siblings under one cache root"
    );
}

test "native artifacts ride the generation of the compiler that emitted them" {
    src = _seeded_module();
    _pin_generation(GEN_A);
    native = get_native_debug_dir(src);
    _unpin_generation();
    assert native.name == "native-debug";
    assert native.parent.name == GEN_A , (
        "native artifacts escaped their compiler's generation"
    );
}

test "the sweep drops abandoned generations and keeps the live one" {
    cache_root = Path(tempfile.mkdtemp());
    for tag in [GEN_A, GEN_B, GEN_C] {
        gen = cache_root / tag;
        gen.mkdir();
        (gen / "mod.deadbeef.cpython-314.jir").write_bytes(b"x");
    }
    _age(cache_root / GEN_A);
    _age(cache_root / GEN_C);
    removed = sweep_stale_generations(cache_root, GEN_A);
    assert removed == 1 , f"expected one generation swept, got {removed}";
    assert (cache_root / GEN_A).is_dir() , "the live generation was swept despite its age";
    assert (cache_root / GEN_B).is_dir() , "a recently used generation was swept";
    assert not (cache_root / GEN_C).exists() , "the abandoned generation survived";
}

test "the sweep retires the pre-generation flat layout" {
    cache_root = Path(tempfile.mkdtemp());
    legacy = cache_root / "mod.deadbeef.cpython-314.jir";
    legacy.write_bytes(b"x");
    native = cache_root / "native";
    native.mkdir();
    (native / "mod.o").write_bytes(b"x");
    _age(legacy);
    _age(native);
    removed = sweep_stale_generations(cache_root, GEN_A);
    assert removed == 2 , f"expected the flat layout retired, got {removed}";
    assert not legacy.exists() , "a flat-layout jir survived";
    assert not native.exists() , "the flat-layout native directory survived";
}

test "an unrelated file in the cache root is never swept" {
    cache_root = Path(tempfile.mkdtemp());
    keeper = cache_root / "notes.txt";
    keeper.write_text("not ours");
    _age(keeper);
    removed = sweep_stale_generations(cache_root, GEN_A);
    assert removed == 0 , "the sweep removed something it does not own";
    assert keeper.exists();
}

test "a zero TTL disables the sweep" {
    cache_root = Path(tempfile.mkdtemp());
    gen = cache_root / GEN_C;
    gen.mkdir();
    _age(gen);
    prior = os.environ.get("JAC_CACHE_GENERATION_TTL_DAYS");
    os.environ["JAC_CACHE_GENERATION_TTL_DAYS"] = "0";
    try {
        removed = sweep_stale_generations(cache_root, GEN_A);
    } finally {
        if prior is None {
            del os.environ["JAC_CACHE_GENERATION_TTL_DAYS"];
        } else {
            os.environ["JAC_CACHE_GENERATION_TTL_DAYS"] = prior;
        }
    }
    assert removed == 0 , "a zero TTL still swept a generation";
    assert gen.is_dir();
}
