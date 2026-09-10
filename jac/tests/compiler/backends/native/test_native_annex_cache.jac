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
