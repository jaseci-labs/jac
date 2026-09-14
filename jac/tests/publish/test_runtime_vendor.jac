"""Explicit runtime dependencies must resolve before source is emitted."""

import from jaclang.dist.publish.runtime_vendor { build_runtime_closure }

test "unresolvable extra seed fails loudly" {
    # This exact module was deleted by #7947; the vendorer used to skip the
    # seed silently and exit 0, leaving a backend that dies on first import.
    with testraises(ValueError) as exc {
        build_runtime_closure(
            [], extra_seeds=["jaclang.data.storage.sqlalchemy_memory"]
        );
    }
    assert "sqlalchemy_memory" in str(exc.value);
}

test "prepared runtime closure excludes optional compiler services" {
    import json;
    closure = build_runtime_closure([], native_sources=False);
    assert "runtime/source_app.py" in closure;
    assert "runtime/runtime.py" in closure;
    assert "extensions.py" in closure;
    compiler_paths = sorted(
        path
        for path in closure
        if path.startswith("compiler/")
    );
    assert not compiler_paths , compiler_paths;
    assert "meta_importer.py" not in closure;
    manifest = json.loads(closure["runtime.json"]);
    assert all(
        not module["path"].startswith("compiler/") for module in manifest["modules"]
    );
}
