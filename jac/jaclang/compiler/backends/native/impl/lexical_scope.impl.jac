impl LexicalScope.function(name: str) -> (ir.Function | None) {
    scope: (LexicalScope | None) = self;
    outermost: LexicalScope = self;
    while scope is not None {
        found = scope.functions.get(name);
        if found is not None {
            return found;
        }
        outermost = scope;
        scope = scope.parent;
    }
    if outermost.source is not None {
        return outermost.source.resolve(name);
    }
    return None;
}

impl LexicalScope.binds_function(name: str) -> bool {
    scope: (LexicalScope | None) = self;
    outermost: LexicalScope = self;
    while scope is not None {
        if name in scope.functions {
            return True;
        }
        outermost = scope;
        scope = scope.parent;
    }
    return outermost.source is not None and outermost.source.provides(name);
}

impl LexicalScope.bind_function(name: str, func: ir.Function) {
    self.functions[name] = func;
}

impl LexicalScope.unbind_function(name: str) {
    self.functions.pop(name, None);
}

impl LexicalScope.function_entries -> list[tuple[str, ir.Function]] {
    merged: dict[str, ir.Function] = {};
    for scope in reversed(self.chain()) {
        merged.update(scope.functions);
    }
    return list(merged.items());
}

impl LexicalScope.closure(
    name: str
) -> (tuple[ir.Function, list[tuple[str, str]]] | None) {
    scope: (LexicalScope | None) = self;
    while scope is not None {
        found = scope.closures.get(name);
        if found is not None {
            return found;
        }
        scope = scope.parent;
    }
    return None;
}

impl LexicalScope.bind_closure(
    name: str, closure: tuple[ir.Function, list[tuple[str, str]]]
) {
    self.closures[name] = closure;
}

impl LexicalScope.lambda_captures(name: str) -> (list[tuple[str, ir.Value]] | None) {
    scope: (LexicalScope | None) = self;
    while scope is not None {
        found = scope.lambdas.get(name);
        if found is not None {
            return found;
        }
        scope = scope.parent;
    }
    return None;
}

impl LexicalScope.bind_lambda(name: str, captures: list[tuple[str, ir.Value]]) {
    self.lambdas[name] = captures;
}

impl LexicalScope.child -> LexicalScope {
    return LexicalScope(parent=self);
}

impl LexicalScope.outermost -> LexicalScope {
    scope: LexicalScope = self;
    while scope.parent is not None {
        scope = scope.parent;
    }
    return scope;
}

impl LexicalScope.chain -> list[LexicalScope] {
    scopes: list[LexicalScope] = [];
    scope: (LexicalScope | None) = self;
    while scope is not None {
        scopes.append(scope);
        scope = scope.parent;
    }
    return scopes;
}
