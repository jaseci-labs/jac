"""Client module that calls sv-imported def:pub functions with kwargs.

Regression fixture for issue #5852.  The kwargs form (``greet(name=x)``)
must compile to the same ``__jacCallFunction("greet", {"name": x})``
shape that the positional form produces — not drop the kwargs and emit
an empty object.
"""

# Server function imports — these become __jacCallFunction RPC stubs.
sv import from sv_import_kwargs { greet, add_pair }

def:pub app -> JsxElement {
    has input_text: str = "World",
        result: str = "",
        sum_val: int = 0;

    async def call_greet -> None {
        # Kwargs form — the case the bug was about.
        response = await greet(name=input_text);
        result = str(response);
    }

    async def call_add_kw_only -> None {
        # Both args by name, written out-of-source-order to confirm the
        # generated object keys come from the kwarg names, not call order.
        sum_val = await add_pair(b=2, a=1);
    }

    async def call_add_mixed -> None {
        # Positional + kwarg — first param goes positional, second by name.
        sum_val = await add_pair(1, b=2);
    }

    async def call_add_kw_spread -> None {
        # ``**dict`` spread — unknown keys at compile time, must be carried
        # through as an ObjectExpression spread element.
        kw: dict = {"a": 1, "b": 2};
        sum_val = await add_pair(**kw);
    }

    return
        <div>
            <input
                value={input_text}
                onChange={lambda e: Any -> None { input_text = e.target.value; }}
            />
            <button onClick={call_greet}>Greet</button>
            <button onClick={call_add_kw_only}>Add KW</button>
            <button onClick={call_add_mixed}>Add Mixed</button>
            <p>{result}</p>
            <p>{sum_val}</p>
        </div>;
}
