"""Client fixture: one server name imported from two modules is E5118."""

import from sv_import_kwargs { greet }

def:pub app -> JsxElement {
    async def call_other {
        import from sv_import_kwargs_dup_server { greet }
        await greet("World");
    }
    return <p/>;
}
