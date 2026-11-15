"""The bootstrap bytecode cache is keyed by source content, so checkouts
with the same seed source share an entry; each must still report its own
file in code objects and tracebacks."""

import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.meta_importer as meta_importer;

def _filenames(code: any) -> set[str] {
    found = {code.co_filename};
    for const in code.co_consts {
        if hasattr(const, "co_filename") {
            found.update(_filenames(const));
        }
    }
    return found;
}

test "a seed module cached by another checkout reports this checkout's file" {
    source = "def answer() -> int {\n    return 42;\n}\n";
    with tempfile.TemporaryDirectory(prefix="jac-bootstrap-") as tmp {
        with patch.object(
            meta_importer, "get_bootstrap_cache_dir", return_value=Path(tmp)
        ) {
            first = meta_importer._bootstrap_compile("/one/jaclang/seed.jac", source);
            second = meta_importer._bootstrap_compile("/two/jaclang/seed.jac", source);
        }
        entries = list(Path(tmp).glob("seed.*.jbc"));
    }
    assert len(entries) == 1 , f"the two checkouts must share one entry: {entries}";
    assert _filenames(first) == {"/one/jaclang/seed.jac"} , _filenames(first);
    assert _filenames(second) == {"/two/jaclang/seed.jac"} , _filenames(second);
}
