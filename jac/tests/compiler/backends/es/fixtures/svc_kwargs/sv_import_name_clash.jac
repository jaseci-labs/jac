"""Client fixture: one name imported from two server modules is E5118."""

import from sv_import_kwargs { greet }

def:pub app -> JsxElement {
    has result: str = "";

    async def call_other {
        import from sv_import_kwargs_dup_server { greet }
        result = await greet("World");
    }

    async def call_aliased {
        import from sv_import_kwargs_dup_server { greet as greet_dup }
        result = await greet_dup("World");
    }

    async def call_same {
        import from sv_import_kwargs { greet }
        result = await greet("World");
    }

    return <p>{result}</p>;
}
