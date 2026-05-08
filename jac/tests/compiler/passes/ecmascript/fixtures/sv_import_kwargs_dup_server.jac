"""Server module backing sv_import_kwargs_dup.cl.jac."""

def:pub greet(name: str) -> str {
    return "Hello, " + name + "!";
}

cl {
    import from sv_import_kwargs_dup { app as ClientApp }

    def:pub app -> JsxElement {
        return
            <ClientApp/>;
    }
}
