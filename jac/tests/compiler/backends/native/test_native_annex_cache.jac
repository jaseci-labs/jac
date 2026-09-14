"""Native dependency cache keys include implementation annexes."""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.na_compile_pass { native_dep_cache_paths }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "editing an implementation invalidates its native dependency artifact" {
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "library.jac";
        annex = Path(directory) / "library.impl.jac";
        source.write_text("def value -> int;\n");
        annex.write_text("impl value -> int { return 1; }\n");
        options = CompileOptions(aot_mode=True, default_codespace="native");
        before = native_dep_cache_paths(os.path.realpath(str(source)), options);
        annex.write_text("impl value -> int { return 2; }\n");
        after = native_dep_cache_paths(os.path.realpath(str(source)), options);
        assert before != after;
    }
}


test "native caches distinguish identical sources and compilation modes" {
    import from unittest.mock { patch }
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
        # Installed modules and modules in one project share a cache directory.
        with patch(
            "jaclang.compiler.driver.jir.get_native_cache_dir", return_value=folder
        ) {
            paths = [
                native_dep_cache_paths(str(source), options)[0]
                for source in (first, second) for options in (ordinary, required)
            ];
            assert len(set(paths)) == 4;
        }
    }
}
