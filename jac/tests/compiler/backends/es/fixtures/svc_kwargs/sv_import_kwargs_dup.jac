"""Client fixture: same param given both positionally and by keyword.

Mirrors Python's ``TypeError: got multiple values for argument 'name'``.
The type checker should emit ``E1057`` rather than silently produce an
ObjectExpression with a duplicated key.
"""

import from sv_import_kwargs_dup_server { greet }

def:pub app -> JsxElement {
    has input_text: str = "World",
        result: str = "";

    async def call_bad {
        # ``name`` is given both positionally and by keyword.
        response = await greet(input_text, name="other");
        result = str(response);
    }

    return
        <div>
            <button onClick={call_bad}>Greet</button>
            <p>{result}</p>
        </div>;
}
