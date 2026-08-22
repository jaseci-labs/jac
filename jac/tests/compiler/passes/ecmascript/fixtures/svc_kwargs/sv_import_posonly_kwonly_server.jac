"""Fixture: sv-imported def:pub with posonly + kwonly boundary-typed params.

Regression for the latent stub-generation bug uncovered in #5852 cleanup.
``_generate_sv_import_stubs`` previously walked only ``sig.params``
(regular params), silently dropping posonly_params and kwonlyargs from
the generated JS wrapper — both from its function signature and from
its ``__jacCallFunction`` args object.  When the dropped param was a
boundary type, the wrapper additionally skipped its ``__to_wire`` call.
"""

obj SearchFilter {
    has query: str,
        max_results: int = 10;
}

obj SearchScope {
    has tag: str;
}

# `filter` is positional-only, `scope` is keyword-only.  Both are
# boundary-typed objects so the stub generator must emit ``__to_wire()``
# for them when forming the RPC args object.
def:pub query(filter: SearchFilter, /, query: str, *, scope: SearchScope) -> int {
    return filter.max_results;
}
