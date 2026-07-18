"""Client that calls a server endpoint whose module fails to import (#6507)."""

sv import from .failload_server { do_thing }

cl def:pub Panel() -> JsxElement {
    has value: int = 0;

    async can with entry {
        value = await do_thing();
    }

    return
        <div id="panel">{value}</div>;
}
