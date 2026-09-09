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
