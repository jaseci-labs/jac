"""Regression fixture for #7221: a `sv import` nested in a `cl { }` block
must lower to an RPC stub, not a client import of the server module."""

walker:pub say_hi {
    has name: str;

    can g with Root entry {
        report {"msg": "hi " + self.name};
    }
}

cl {
    sv import from .sv_import_cl_block { say_hi }

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
