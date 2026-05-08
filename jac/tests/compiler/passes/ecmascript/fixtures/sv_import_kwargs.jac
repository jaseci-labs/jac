"""Server module: def:pub functions called with kwargs from a .cl.jac client.

Companion to ``sv_import_kwargs_client.cl.jac`` — exercises the kwargs
form of ``sv import`` calls (e.g. ``greet(name=x)``) which previously
miscompiled (issue #5852): the compiler dropped the kwargs and emitted
``__jacCallFunction("greet", {})``, producing a server 422.
"""

"""Greet by name."""
def:pub greet(name: str) -> str {
    return "Hello, " + name + "!";
}

"""Two-arg add for kwargs ordering coverage."""
def:pub add_pair(a: int, b: int) -> int {
    return a + b;
}

# Client entry point imports from the standalone client module
cl {
    import from sv_import_kwargs_client { app as ClientApp }

    def:pub app -> JsxElement {
        return
            <ClientApp/>;
    }
}
