"""Native dependency cache keys include implementation annexes."""

import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.jir { module_cache_key }

test "editing an implementation invalidates its native dependency artifact" {
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "library.jac";
        annex = Path(directory) / "library.impl.jac";
        source.write_text("def value -> int;\n");
        annex.write_text("impl value -> int { return 1; }\n");
        before = module_cache_key(str(source));
        annex.write_text("impl value -> int { return 2; }\n");
        after = module_cache_key(str(source));
        assert before != after;
    }
}


test "native caches distinguish identical sources and compilation modes" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        current_native_stamp
    }
    with tempfile.TemporaryDirectory() as directory {
        folder = Path(directory);
        first = folder / "first" / "library.jac";
        second = folder / "second" / "library.jac";
        first.parent.mkdir();
        second.parent.mkdir();
        for source in (first, second) {
            source.write_text("def value -> int { return 1; }\n");
        }
        ordinary = CompileOptions(aot_mode=True, default_codespace="native");
        required = CompileOptions(aot_mode=True, native_required=True);
        identities = [
            (
                str(get_module_cache_path(str(source))),
                current_native_stamp(options.codegen_identity(), "").key()
            ) for source in (first, second) for options in (ordinary, required)
        ];
        assert len(set(identities)) == 4;
    }
}
