"""Fixture: varargs (`*args`) / kwargs (`**kwargs`) parameters in client codegen.

`*args` must lower to a JS rest parameter (`...args`); previously the param was
dropped from the signature entirely, leaving the body referencing an undefined
name (e.g. the shadcn `cn(*inputs)` helper -> `function cn() { ...clsx(inputs) }`).
"""

cl {
    def:pub collect(*items: any) -> any {
        return items;
    }

    def:pub mixed(first: any, *rest: any) -> any {
        return [first, rest];
    }
}
