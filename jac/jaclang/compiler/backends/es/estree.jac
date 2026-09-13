import from typing { TypeAlias }
import from typing { Literal as TypingLiteral }

glob VariableDeclarationKind: TypeAlias = TypingLiteral[('var', 'let', 'const')],
     PropertyKind: TypeAlias = TypingLiteral[('init', 'get', 'set')],
     MethodDefinitionKind: TypeAlias = TypingLiteral[
         ('constructor', 'method', 'get', 'set')
     ];

obj SourceLocation {
    has source: (str | None) = None,
        start: (Position | None) = None,
        end: (Position | None) = None;
}

obj Position {
    has line: int = 0,
        column: int = 0;
}

obj Node {
    has `type: str,
        loc: (SourceLocation | None) = None;
}

obj Expression(Node) {}

obj Statement(Node) {}

obj Identifier(Expression) {
    has name: str = '',
        `type: TypingLiteral['Identifier'] = 'Identifier';
}

obj RawCode(Expression) {
    has code: str = '',
        `type: TypingLiteral['RawCode'] = 'RawCode';
}

obj PrivateIdentifier(Node) {
    has name: str = '',
        `type: TypingLiteral['PrivateIdentifier'] = 'PrivateIdentifier';
}

obj Literal(Expression) {
    has value: str | bool | None | int | float = None,
        raw: (str | None) = None,
        `type: TypingLiteral['Literal'] = 'Literal';
}

obj Program(Node) {
    has body: list[(Statement | ModuleDeclaration)] = [],
        `type: TypingLiteral['Program'] = 'Program';
}

obj ExpressionStatement(Statement) {
    has expression: (Expression | None) = None,
        `type: TypingLiteral['ExpressionStatement'] = 'ExpressionStatement';
}

obj BlockStatement(Statement) {
    has body: list[Statement] = [],
        `type: TypingLiteral['BlockStatement'] = 'BlockStatement';
}

obj ReturnStatement(Statement) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['ReturnStatement'] = 'ReturnStatement';
}

obj BreakStatement(Statement) {
    has label: (Identifier | None) = None,
        `type: TypingLiteral['BreakStatement'] = 'BreakStatement';
}

obj ContinueStatement(Statement) {
    has label: (Identifier | None) = None,
        `type: TypingLiteral['ContinueStatement'] = 'ContinueStatement';
}

obj IfStatement(Statement) {
    has `test: (Expression | None) = None,
        consequent: (Statement | None) = None,
        alternate: (Statement | None) = None,
        `type: TypingLiteral['IfStatement'] = 'IfStatement';
}

obj SwitchStatement(Statement) {
    has discriminant: (Expression | None) = None,
        cases: list[SwitchCase] = [],
        `type: TypingLiteral['SwitchStatement'] = 'SwitchStatement';
}

obj SwitchCase(Node) {
    has `test: (Expression | None) = None,
        consequent: list[Statement] = [],
        `type: TypingLiteral['SwitchCase'] = 'SwitchCase';
}

obj ThrowStatement(Statement) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['ThrowStatement'] = 'ThrowStatement';
}

obj TryStatement(Statement) {
    has block: (BlockStatement | None) = None,
        handler: (CatchClause | None) = None,
        finalizer: (BlockStatement | None) = None,
        `type: TypingLiteral['TryStatement'] = 'TryStatement';
}

obj CatchClause(Node) {
    has param: (Pattern | None) = None,
        body: (BlockStatement | None) = None,
        `type: TypingLiteral['CatchClause'] = 'CatchClause';
}

obj WhileStatement(Statement) {
    has `test: (Expression | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['WhileStatement'] = 'WhileStatement';
}

obj ForStatement(Statement) {
    has `init: VariableDeclaration | Expression | None = None,
        `test: (Expression | None) = None,
        update: (Expression | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['ForStatement'] = 'ForStatement';
}

obj ForOfStatement(Statement) {
    has left: VariableDeclaration | Pattern | None = None,
        right: (Expression | None) = None,
        body: (Statement | None) = None,
        await_: bool = False,
        `type: TypingLiteral['ForOfStatement'] = 'ForOfStatement';
}

obj FunctionDeclaration(Statement) {
    has id: (Identifier | None) = None,
        params: list[Pattern] = [],
        body: (BlockStatement | None) = None,
        generator: bool = False,
        async_: bool = False,
        `type: TypingLiteral['FunctionDeclaration'] = 'FunctionDeclaration';
}

obj VariableDeclaration(Statement) {
    has declarations: list[VariableDeclarator] = [],
        kind: VariableDeclarationKind = 'var',
        `type: TypingLiteral['VariableDeclaration'] = 'VariableDeclaration';
}

obj VariableDeclarator(Node) {
    has id: (Pattern | None) = None,
        `init: (Expression | None) = None,
        `type: TypingLiteral['VariableDeclarator'] = 'VariableDeclarator';
}

obj ThisExpression(Expression) {
    has `type: TypingLiteral['ThisExpression'] = 'ThisExpression';
}

obj ArrayExpression(Expression) {
    has elements: list[Expression | SpreadElement | None] = [],
        `type: TypingLiteral['ArrayExpression'] = 'ArrayExpression';
}

obj ObjectExpression(Expression) {
    has properties: list[(Property | SpreadElement)] = [],
        `type: TypingLiteral['ObjectExpression'] = 'ObjectExpression';
}

obj Property(Node) {
    has key: (Expression | Identifier | Literal | None) = None,
        value: (Expression | None) = None,
        kind: PropertyKind = 'init',
        method: bool = False,
        shorthand: bool = False,
        computed: bool = False,
        `type: TypingLiteral['Property'] = 'Property';
}

obj FunctionExpression(Expression) {
    has id: (Identifier | None) = None,
        params: list[Pattern] = [],
        body: (BlockStatement | None) = None,
        generator: bool = False,
        async_: bool = False,
        `type: TypingLiteral['FunctionExpression'] = 'FunctionExpression';
}

obj ArrowFunctionExpression(Expression) {
    has params: list[Pattern] = [],
        body: BlockStatement | Expression | None = None,
        expression: bool = False,
        async_: bool = False,
        `type: TypingLiteral['ArrowFunctionExpression'] = 'ArrowFunctionExpression';
}

obj UnaryExpression(Expression) {
    has operator: str = '',
        prefix: bool = True,
        argument: (Expression | None) = None,
        `type: TypingLiteral['UnaryExpression'] = 'UnaryExpression';
}

obj BinaryExpression(Expression) {
    has operator: str = '',
        left: (Expression | None) = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['BinaryExpression'] = 'BinaryExpression';
}

obj AssignmentExpression(Expression) {
    has operator: str = '=',
        left: Pattern | Expression | None = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['AssignmentExpression'] = 'AssignmentExpression';
}

obj LogicalExpression(Expression) {
    has operator: str = '&&',
        left: (Expression | None) = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['LogicalExpression'] = 'LogicalExpression';
}

obj MemberExpression(Expression) {
    has object: Expression | None = None,
        property: (Expression | None) = None,
        computed: bool = False,
        optional: bool = False,
        `type: TypingLiteral['MemberExpression'] = 'MemberExpression';
}

obj ConditionalExpression(Expression) {
    has `test: (Expression | None) = None,
        consequent: (Expression | None) = None,
        alternate: (Expression | None) = None,
        `type: TypingLiteral['ConditionalExpression'] = 'ConditionalExpression';
}

obj CallExpression(Expression) {
    has callee: Expression | None = None,
        arguments: list[(Expression | SpreadElement)] = [],
        optional: bool = False,
        `type: TypingLiteral['CallExpression'] = 'CallExpression';
}

obj NewExpression(Expression) {
    has callee: (Expression | None) = None,
        arguments: list[(Expression | SpreadElement)] = [],
        `type: TypingLiteral['NewExpression'] = 'NewExpression';
}

obj AwaitExpression(Expression) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['AwaitExpression'] = 'AwaitExpression';
}

obj YieldExpression(Expression) {
    has argument: (Expression | None) = None,
        delegate: bool = False,
        `type: TypingLiteral['YieldExpression'] = 'YieldExpression';
}

obj TemplateLiteral(Expression) {
    has quasis: list[TemplateElement] = [],
        expressions: list[Expression] = [],
        `type: TypingLiteral['TemplateLiteral'] = 'TemplateLiteral';
}

obj TemplateElement(Node) {
    has tail: bool = False,
        value: dict[(str, str)] = {},
        `type: TypingLiteral['TemplateElement'] = 'TemplateElement';
}

obj SpreadElement(Node) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['SpreadElement'] = 'SpreadElement';
}

obj AssignmentPattern(Node) {
    has left: (Pattern | None) = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['AssignmentPattern'] = 'AssignmentPattern';
}

obj ArrayPattern(Node) {
    has elements: list[(Pattern | None)] = [],
        `type: TypingLiteral['ArrayPattern'] = 'ArrayPattern';
}

obj ObjectPattern(Node) {
    has properties: list[(AssignmentProperty | RestElement)] = [],
        `type: TypingLiteral['ObjectPattern'] = 'ObjectPattern';
}

obj AssignmentProperty(Node) {
    has key: (Expression | Identifier | Literal | None) = None,
        value: (Pattern | None) = None,
        kind: PropertyKind = 'init',
        method: bool = False,
        shorthand: bool = False,
        computed: bool = False,
        `type: TypingLiteral['Property'] = 'Property';
}

obj RestElement(Node) {
    has argument: (Pattern | None) = None,
        `type: TypingLiteral['RestElement'] = 'RestElement';
}

obj ClassDeclaration(Statement) {
    has id: (Identifier | None) = None,
        superClass: (Expression | None) = None,
        body: (ClassBody | None) = None,
        `type: TypingLiteral['ClassDeclaration'] = 'ClassDeclaration';
}

obj ClassBody(Node) {
    has body: list[MethodDefinition | PropertyDefinition] = [],
        `type: TypingLiteral['ClassBody'] = 'ClassBody';
}

obj MethodDefinition(Node) {
    has key: (Expression | Identifier | PrivateIdentifier | None) = None,
        value: (FunctionExpression | None) = None,
        kind: MethodDefinitionKind = 'method',
        computed: bool = False,
        `static: bool = False,
        `type: TypingLiteral['MethodDefinition'] = 'MethodDefinition';
}

obj PropertyDefinition(Node) {
    has key: (Expression | Identifier | PrivateIdentifier | None) = None,
        value: (Expression | None) = None,
        computed: bool = False,
        `static: bool = False,
        `type: TypingLiteral['PropertyDefinition'] = 'PropertyDefinition';
}

obj ImportDeclaration(Node) {
    has specifiers:
        list[ImportSpecifier | ImportDefaultSpecifier | ImportNamespaceSpecifier] = [],
        source: (Literal | None) = None,
        `type: TypingLiteral['ImportDeclaration'] = 'ImportDeclaration';
}

obj ImportSpecifier(Node) {
    has imported: (Identifier | None) = None,
        local: (Identifier | None) = None,
        `type: TypingLiteral['ImportSpecifier'] = 'ImportSpecifier';
}

obj ImportDefaultSpecifier(Node) {
    has local: (Identifier | None) = None,
        `type: TypingLiteral['ImportDefaultSpecifier'] = 'ImportDefaultSpecifier';
}

obj ImportNamespaceSpecifier(Node) {
    has local: (Identifier | None) = None,
        `type: TypingLiteral['ImportNamespaceSpecifier'] = 'ImportNamespaceSpecifier';
}

obj ExportNamedDeclaration(Node) {
    has declaration: Declaration | Expression | None = None,
        specifiers: list[ExportSpecifier] = [],
        source: (Literal | None) = None,
        `type: TypingLiteral['ExportNamedDeclaration'] = 'ExportNamedDeclaration';
}

obj ExportSpecifier(Node) {
    has exported: (Identifier | None) = None,
        local: (Identifier | None) = None,
        `type: TypingLiteral['ExportSpecifier'] = 'ExportSpecifier';
}

obj JsxIdentifier(Node) {
    has name: str = '',
        `type: TypingLiteral['JsxIdentifier'] = 'JsxIdentifier';
}

obj JsxMemberExpression(Node) {
    has object: (JsxMemberExpression | JsxIdentifier | None) = None,
        property: (JsxIdentifier | None) = None,
        `type: TypingLiteral['JsxMemberExpression'] = 'JsxMemberExpression';
}

obj JsxEmptyExpression(Node) {
    has `type: TypingLiteral['JsxEmptyExpression'] = 'JsxEmptyExpression';
}

obj JsxExpressionContainer(Node) {
    has expression: (Expression | JsxEmptyExpression | None) = None,
        `type: TypingLiteral['JsxExpressionContainer'] = 'JsxExpressionContainer';
}

obj JsxSpreadAttribute(Node) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['JsxSpreadAttribute'] = 'JsxSpreadAttribute';
}

obj JsxAttribute(Node) {
    has name: (JsxIdentifier | None) = None,
        value: (Literal | JsxExpressionContainer | JsxElement | None) = None,
        `type: TypingLiteral['JsxAttribute'] = 'JsxAttribute';
}

obj JsxOpeningElement(Node) {
    has name: (JsxIdentifier | JsxMemberExpression | None) = None,
        attributes: list[(JsxAttribute | JsxSpreadAttribute)] = [],
        selfClosing: bool = False,
        `type: TypingLiteral['JsxOpeningElement'] = 'JsxOpeningElement';
}

obj JsxClosingElement(Node) {
    has name: (JsxIdentifier | JsxMemberExpression | None) = None,
        `type: TypingLiteral['JsxClosingElement'] = 'JsxClosingElement';
}

obj JsxText(Node) {
    has value: str = '',
        raw: (str | None) = None,
        `type: TypingLiteral['JsxText'] = 'JsxText';
}

obj JsxElement(Expression) {
    has openingElement: (JsxOpeningElement | None) = None,
        children: list[JsxText | JsxExpressionContainer | JsxElement | JsxFragment] = [],
        closingElement: (JsxClosingElement | None) = None,
        `type: TypingLiteral['JsxElement'] = 'JsxElement';
}

obj JsxFragment(Expression) {
    has children: list[JsxText | JsxExpressionContainer | JsxElement | JsxFragment] = [],
        `type: TypingLiteral['JsxFragment'] = 'JsxFragment';
}

obj SliceInfo {
    has start: (Node | None) = None,
        stop: (Node | None) = None;
}

obj IndexInfo {
    has value: (Node | None) = None;
}

glob Pattern: TypeAlias = Identifier
         | ArrayPattern
         | ObjectPattern
         | AssignmentPattern
         | RestElement,
     Declaration: TypeAlias = FunctionDeclaration
         | VariableDeclaration
         | ClassDeclaration,
     ModuleDeclaration: TypeAlias = ImportDeclaration | ExportNamedDeclaration;

def es_node_to_dict(nd: Node) -> dict[str, any];
