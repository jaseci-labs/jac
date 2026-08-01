"""Server module backing sv_import_kwargs_dup.jac."""

def:pub greet(name: str) -> str {
    return "Hello, " + name + "!";
}


import from sv_import_kwargs_dup { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp/>;
}
