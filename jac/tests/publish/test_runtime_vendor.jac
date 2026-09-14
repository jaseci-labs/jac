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
