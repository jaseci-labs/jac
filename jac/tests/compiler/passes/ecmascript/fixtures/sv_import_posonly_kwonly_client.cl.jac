"""Client side for sv-imported posonly/kwonly boundary-typed params.

The generated JS wrapper for ``query`` must include both ``filter``
(posonly) and ``scope`` (kwonly) in its signature and pass them through
``__to_wire()`` in the RPC args object.  Before the stubs path used
``_param_names_from_ability`` / ``_param_type_map_from_ability``, those
two params silently disappeared from the wrapper.
"""

sv import from sv_import_posonly_kwonly_server { query, SearchFilter, SearchScope }

def:pub app -> JsxElement {
    has total: int = 0;
    return <div><p>{total}</p></div>;
}
