impl es_children(nd: Node) -> dict[str, any] {
    if isinstance(nd, Identifier) {
        return {"name": nd.name};
    }
    if isinstance(nd, RawCode) {
        return {"code": nd.code};
    }
    if isinstance(nd, PrivateIdentifier) {
        return {"name": nd.name};
    }
    if isinstance(nd, Literal) {
        return {"value": nd.value, "raw": nd.raw};
    }
    if isinstance(nd, Program) {
        return {"body": nd.body};
    }
    if isinstance(nd, ExpressionStatement) {
        return {"expression": nd.expression};
    }
    if isinstance(nd, BlockStatement) {
        return {"body": nd.body};
    }
    if isinstance(nd, ReturnStatement) {
        return {"argument": nd.argument};
    }
    if isinstance(nd, BreakStatement) {
        return {"label": nd.label};
    }
    if isinstance(nd, ContinueStatement) {
        return {"label": nd.label};
    }
    if isinstance(nd, LabeledStatement) {
        return {"label": nd.label, "body": nd.body};
    }
    if isinstance(nd, IfStatement) {
        return {
            "test": nd.test,
            "consequent": nd.consequent,
            "alternate": nd.alternate
        };
    }
    if isinstance(nd, SwitchStatement) {
        return {"discriminant": nd.discriminant, "cases": nd.cases};
    }
    if isinstance(nd, SwitchCase) {
        return {"test": nd.test, "consequent": nd.consequent};
    }
    if isinstance(nd, ThrowStatement) {
        return {"argument": nd.argument};
    }
    if isinstance(nd, TryStatement) {
        return {"block": nd.block, "handler": nd.handler, "finalizer": nd.finalizer};
    }
    if isinstance(nd, CatchClause) {
        return {"param": nd.param, "body": nd.body};
    }
    if isinstance(nd, WhileStatement) {
        return {"test": nd.test, "body": nd.body};
    }
    if isinstance(nd, ForStatement) {
        return {"init": nd.init, "test": nd.test, "update": nd.update, "body": nd.body};
    }
    if isinstance(nd, ForOfStatement) {
        return {
            "left": nd.left,
            "right": nd.right,
            "body": nd.body,
            "await_": nd.await_
        };
    }
    if isinstance(nd, FunctionDeclaration) {
        return {
            "id": nd.id,
            "params": nd.params,
            "body": nd.body,
            "generator": nd.generator,
            "async_": nd.async_
        };
    }
    if isinstance(nd, VariableDeclaration) {
        return {"declarations": nd.declarations, "kind": nd.kind};
    }
    if isinstance(nd, VariableDeclarator) {
        return {"id": nd.id, "init": nd.init};
    }
    if isinstance(nd, ThisExpression) {
        return {};
    }
    if isinstance(nd, ArrayExpression) {
        return {"elements": nd.elements};
    }
    if isinstance(nd, ObjectExpression) {
        return {"properties": nd.properties};
    }
    if isinstance(nd, Property) {
        return {
            "key": nd.key,
            "value": nd.value,
            "kind": nd.kind,
            "method": nd.method,
            "shorthand": nd.shorthand,
            "computed": nd.computed
        };
    }
    if isinstance(nd, FunctionExpression) {
        return {
            "id": nd.id,
            "params": nd.params,
            "body": nd.body,
            "generator": nd.generator,
            "async_": nd.async_
        };
    }
    if isinstance(nd, ArrowFunctionExpression) {
        return {
            "params": nd.params,
            "body": nd.body,
            "expression": nd.expression,
            "async_": nd.async_
        };
    }
    if isinstance(nd, UnaryExpression) {
        return {"operator": nd.operator, "prefix": nd.prefix, "argument": nd.argument};
    }
    if isinstance(nd, BinaryExpression) {
        return {"operator": nd.operator, "left": nd.left, "right": nd.right};
    }
    if isinstance(nd, AssignmentExpression) {
        return {"operator": nd.operator, "left": nd.left, "right": nd.right};
    }
    if isinstance(nd, LogicalExpression) {
        return {"operator": nd.operator, "left": nd.left, "right": nd.right};
    }
    if isinstance(nd, MemberExpression) {
        return {
            "object": nd.object,
            "property": nd.property,
            "computed": nd.computed,
            "optional": nd.optional
        };
    }
    if isinstance(nd, ConditionalExpression) {
        return {
            "test": nd.test,
            "consequent": nd.consequent,
            "alternate": nd.alternate
        };
    }
    if isinstance(nd, CallExpression) {
        return {
            "callee": nd.callee,
            "arguments": nd.arguments,
            "optional": nd.optional
        };
    }
    if isinstance(nd, NewExpression) {
        return {"callee": nd.callee, "arguments": nd.arguments};
    }
    if isinstance(nd, AwaitExpression) {
        return {"argument": nd.argument};
    }
    if isinstance(nd, YieldExpression) {
        return {"argument": nd.argument, "delegate": nd.delegate};
    }
    if isinstance(nd, TemplateLiteral) {
        return {"quasis": nd.quasis, "expressions": nd.expressions};
    }
    if isinstance(nd, TemplateElement) {
        return {"tail": nd.tail, "value": nd.value};
    }
    if isinstance(nd, SpreadElement) {
        return {"argument": nd.argument};
    }
    if isinstance(nd, AssignmentPattern) {
        return {"left": nd.left, "right": nd.right};
    }
    if isinstance(nd, ArrayPattern) {
        return {"elements": nd.elements};
    }
    if isinstance(nd, ObjectPattern) {
        return {"properties": nd.properties};
    }
    if isinstance(nd, AssignmentProperty) {
        return {
            "key": nd.key,
            "value": nd.value,
            "kind": nd.kind,
            "method": nd.method,
            "shorthand": nd.shorthand,
            "computed": nd.computed
        };
    }
    if isinstance(nd, RestElement) {
        return {"argument": nd.argument};
    }
    if isinstance(nd, ClassDeclaration) {
        return {"id": nd.id, "superClass": nd.superClass, "body": nd.body};
    }
    if isinstance(nd, ClassBody) {
        return {"body": nd.body};
    }
    if isinstance(nd, MethodDefinition) {
        return {
            "key": nd.key,
            "value": nd.value,
            "kind": nd.kind,
            "computed": nd.computed,
            "static": nd.static
        };
    }
    if isinstance(nd, PropertyDefinition) {
        return {
            "key": nd.key,
            "value": nd.value,
            "computed": nd.computed,
            "static": nd.static
        };
    }
    if isinstance(nd, ImportDeclaration) {
        return {"specifiers": nd.specifiers, "source": nd.source};
    }
    if isinstance(nd, ImportSpecifier) {
        return {"imported": nd.imported, "local": nd.local};
    }
    if isinstance(nd, ImportDefaultSpecifier) {
        return {"local": nd.local};
    }
    if isinstance(nd, ImportNamespaceSpecifier) {
        return {"local": nd.local};
    }
    if isinstance(nd, ExportNamedDeclaration) {
        return {
            "declaration": nd.declaration,
            "specifiers": nd.specifiers,
            "source": nd.source
        };
    }
    if isinstance(nd, ExportSpecifier) {
        return {"exported": nd.exported, "local": nd.local};
    }
    if isinstance(nd, JsxIdentifier) {
        return {"name": nd.name};
    }
    if isinstance(nd, JsxMemberExpression) {
        return {"object": nd.object, "property": nd.property};
    }
    if isinstance(nd, JsxEmptyExpression) {
        return {};
    }
    if isinstance(nd, JsxExpressionContainer) {
        return {"expression": nd.expression};
    }
    if isinstance(nd, JsxSpreadAttribute) {
        return {"argument": nd.argument};
    }
    if isinstance(nd, JsxAttribute) {
        return {"name": nd.name, "value": nd.value};
    }
    if isinstance(nd, JsxOpeningElement) {
        return {
            "name": nd.name,
            "attributes": nd.attributes,
            "selfClosing": nd.selfClosing
        };
    }
    if isinstance(nd, JsxClosingElement) {
        return {"name": nd.name};
    }
    if isinstance(nd, JsxText) {
        return {"value": nd.value, "raw": nd.raw};
    }
    if isinstance(nd, JsxElement) {
        return {
            "openingElement": nd.openingElement,
            "children": nd.children,
            "closingElement": nd.closingElement
        };
    }
    if isinstance(nd, JsxFragment) {
        return {"children": nd.children};
    }
    return {};
}

impl es_node_to_dict(nd: Node) -> dict[str, any] {
    result: dict[(str, any)] = {'type': nd.type};
    for (key, value) in es_children(nd).items() {
        if value is None {
            continue;
        }
        if isinstance(value, Node) {
            result[key] = es_node_to_dict(value);
        } elif isinstance(value, list) {
            result[key] = [
                es_node_to_dict(item) if isinstance(item, Node) else item
                for item in value
            ];
        } else {
            result[key] = value;
        }
    }
    if nd.loc {
        result['loc'] = {
            'source': nd.loc.source,
            'start': {'line': nd.loc.start.line, 'column': nd.loc.start.column}
                if nd.loc.start
                else None,
            'end': {'line': nd.loc.end.line, 'column': nd.loc.end.column}
                if nd.loc.end
                else None
        };
    }
    return result;
}
