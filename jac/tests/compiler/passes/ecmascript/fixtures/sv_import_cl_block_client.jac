"""Regression fixture: a `sv import` nested in a `cl { }` block must lower
to an RPC stub, not a client import of the server module."""

cl {
    sv import from .sv_import_cl_block_server { say_hi }

    def:pub Greet() -> JsxElement {
        has msg: str = "";

        can with entry {
            call_it();
        }

        async def call_it {
            result = root spawn say_hi(name="x");
            msg = str(result.reports[0]["msg"]);
        }

        return <div>{msg}</div>;
    }
}
