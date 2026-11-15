"""Client module whose annex repeats its bridged import (#10756)."""

import from sv_import_kwargs { greet }

def:pub app -> JsxElement {
    has result: str = "";

    async def load -> None;

    return <p>{result}</p>;
}
