"""ESTree AST Node Definitions for ECMAScript.

This module provides a complete implementation of the ESTree specification,
which defines the standard AST format for JavaScript and ECMAScript.

The ESTree specification represents ECMAScript programs as abstract syntax trees
that are language-agnostic and can be used for various tools like parsers,
transpilers, and code analysis tools.

Reference: https://github.com/estree/estree
"""
import from typing { Any, TypeAlias }
import from typing { Literal as TypingLiteral }

glob SourceType: TypeAlias = TypingLiteral[('script', 'module')],
     VariableDeclarationKind: TypeAlias = TypingLiteral[('var', 'let', 'const')],
     PropertyKind: TypeAlias = TypingLiteral[('init', 'get', 'set')],
     MethodDefinitionKind: TypeAlias = TypingLiteral[
         ('constructor', 'method', 'get', 'set')
     ];

"""Source location information for a node."""
obj SourceLocation {
    has source: (str | None) = None,
        start: (Position | None) = None,
        end: (Position | None) = None;
}

"""Position in source code."""
obj Position {
    has line: int = 0,
        column: int = 0;
}

"""Base obj for all ESTree nodes."""
obj Node {
    has `type: str,
        loc: (SourceLocation | None) = None;
}

"""Identifier node."""
obj Identifier(Node) {
    has name: str = '',
        `type: TypingLiteral['Identifier'] = 'Identifier';
}

"""Private identifier for obj members (ES2022)."""
obj PrivateIdentifier(Node) {
    has name: str = '',
        `type: TypingLiteral['PrivateIdentifier'] = 'PrivateIdentifier';
}

"""Literal value node (supports BigInt in ES2020)."""
obj Literal(Node) {
    has value: str | bool | None | int | float = None,
        raw: (str | None) = None,
        bigint: (str | None) = None,
        `type: TypingLiteral['Literal'] = 'Literal';
}

"""Root node of an ESTree."""
obj Program(Node) {
    has body: list[(Statement | ModuleDeclaration)] = [],
        sourceType: SourceType = 'script',
        `type: TypingLiteral['Program'] = 'Program';
}

"""Expression statement."""
obj ExpressionStatement(Node) {
    has expression: (Expression | None) = None,
        `type: TypingLiteral['ExpressionStatement'] = 'ExpressionStatement';
}

"""Directive (e.g., 'use strict') - ES5."""
obj Directive(ExpressionStatement) {
    has directive: str = '',
        `type: TypingLiteral['ExpressionStatement'] = 'ExpressionStatement';
}

"""Block statement."""
obj BlockStatement(Node) {
    has body: List[Statement] = [],
        `type: TypingLiteral['BlockStatement'] = 'BlockStatement';
}

"""Empty statement (;)."""
obj EmptyStatement(Node) {
    has `type: TypingLiteral['EmptyStatement'] = 'EmptyStatement';
}

"""Debugger statement."""
obj DebuggerStatement(Node) {
    has `type: TypingLiteral['DebuggerStatement'] = 'DebuggerStatement';
}

"""With statement."""
obj WithStatement(Node) {
    has object: (Expression | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['WithStatement'] = 'WithStatement';
}

"""Return statement."""
obj ReturnStatement(Node) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['ReturnStatement'] = 'ReturnStatement';
}

"""Labeled statement."""
obj LabeledStatement(Node) {
    has label: (Identifier | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['LabeledStatement'] = 'LabeledStatement';
}

"""Break statement."""
obj BreakStatement(Node) {
    has label: (Identifier | None) = None,
        `type: TypingLiteral['BreakStatement'] = 'BreakStatement';
}

"""Continue statement."""
obj ContinueStatement(Node) {
    has label: (Identifier | None) = None,
        `type: TypingLiteral['ContinueStatement'] = 'ContinueStatement';
}

"""If statement."""
obj IfStatement(Node) {
    has `test: (Expression | None) = None,
        consequent: (Statement | None) = None,
        alternate: (Statement | None) = None,
        `type: TypingLiteral['IfStatement'] = 'IfStatement';
}

"""Switch statement."""
obj SwitchStatement(Node) {
    has discriminant: (Expression | None) = None,
        cases: list[SwitchCase] = [],
        `type: TypingLiteral['SwitchStatement'] = 'SwitchStatement';
}

"""Switch case clause."""
obj SwitchCase(Node) {
    has `test: (Expression | None) = None,
        consequent: list[Statement] = [],
        `type: TypingLiteral['SwitchCase'] = 'SwitchCase';
}

"""Throw statement."""
obj ThrowStatement(Node) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['ThrowStatement'] = 'ThrowStatement';
}

"""Try statement."""
obj TryStatement(Node) {
    has block: (BlockStatement | None) = None,
        handler: (CatchClause | None) = None,
        finalizer: (BlockStatement | None) = None,
        `type: TypingLiteral['TryStatement'] = 'TryStatement';
}

"""Catch clause."""
obj CatchClause(Node) {
    has param: (Pattern | None) = None,
        body: (BlockStatement | None) = None,
        `type: TypingLiteral['CatchClause'] = 'CatchClause';
}

"""While statement."""
obj WhileStatement(Node) {
    has `test: (Expression | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['WhileStatement'] = 'WhileStatement';
}

"""Do-while statement."""
obj DoWhileStatement(Node) {
    has body: (Statement | None) = None,
        `test: (Expression | None) = None,
        `type: TypingLiteral['DoWhileStatement'] = 'DoWhileStatement';
}

"""For statement."""
obj ForStatement(Node) {
    has `init: VariableDeclaration | Expression | None = None,
        `test: (Expression | None) = None,
        update: (Expression | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['ForStatement'] = 'ForStatement';
}

"""For-in statement."""
obj ForInStatement(Node) {
    has left: VariableDeclaration | Pattern | None = None,
        right: (Expression | None) = None,
        body: (Statement | None) = None,
        `type: TypingLiteral['ForInStatement'] = 'ForInStatement';
}

"""For-of statement (ES6)."""
obj ForOfStatement(Node) {
    has left: VariableDeclaration | Pattern | None = None,
        right: (Expression | None) = None,
        body: (Statement | None) = None,
        await_: bool = False,
        `type: TypingLiteral['ForOfStatement'] = 'ForOfStatement';
}

"""Function declaration."""
obj FunctionDeclaration(Node) {
    has id: (Identifier | None) = None,
        params: list[Pattern] = [],
        body: (BlockStatement | None) = None,
        generator: bool = False,
        async_: bool = False,
        `type: TypingLiteral['FunctionDeclaration'] = 'FunctionDeclaration';
}

"""Variable declaration."""
obj VariableDeclaration(Node) {
    has declarations: list[VariableDeclarator] = [],
        kind: VariableDeclarationKind = 'var',
        `type: TypingLiteral['VariableDeclaration'] = 'VariableDeclaration';
}

"""Variable declarator."""
obj VariableDeclarator(Node) {
    has id: (Pattern | None) = None,
        `init: (Expression | None) = None,
        `type: TypingLiteral['VariableDeclarator'] = 'VariableDeclarator';
}

"""This expression."""
obj ThisExpression(Node) {
    has `type: TypingLiteral['ThisExpression'] = 'ThisExpression';
}

"""Array expression."""
obj ArrayExpression(Node) {
    has elements: list[Expression | SpreadElement | None] = [],
        `type: TypingLiteral['ArrayExpression'] = 'ArrayExpression';
}

"""Object expression."""
obj ObjectExpression(Node) {
    has properties: list[(Property | SpreadElement)] = [],
        `type: TypingLiteral['ObjectExpression'] = 'ObjectExpression';
}

"""Object property."""
obj Property(Node) {
    has key: (Expression | Identifier | Literal | None) = None,
        value: (Expression | None) = None,
        kind: PropertyKind = 'init',
        method: bool = False,
        shorthand: bool = False,
        computed: bool = False,
        `type: TypingLiteral['Property'] = 'Property';
}

"""Function expression."""
obj FunctionExpression(Node) {
    has id: (Identifier | None) = None,
        params: list[Pattern] = [],
        body: (BlockStatement | None) = None,
        generator: bool = False,
        async_: bool = False,
        `type: TypingLiteral['FunctionExpression'] = 'FunctionExpression';
}

"""Arrow function expression (ES6)."""
obj ArrowFunctionExpression(Node) {
    has params: list[Pattern] = [],
        body: BlockStatement | Expression | None = None,
        expression: bool = False,
        async_: bool = False,
        `type: TypingLiteral['ArrowFunctionExpression'] = 'ArrowFunctionExpression';
}

"""Unary expression."""
obj UnaryExpression(Node) {
    has operator: str = '',
        prefix: bool = True,
        argument: (Expression | None) = None,
        `type: TypingLiteral['UnaryExpression'] = 'UnaryExpression';
}

"""Update expression."""
obj UpdateExpression(Node) {
    has operator: str = '++',
        argument: (Expression | None) = None,
        prefix: bool = True,
        `type: TypingLiteral['UpdateExpression'] = 'UpdateExpression';
}

"""Binary expression."""
obj BinaryExpression(Node) {
    has operator: str = '',
        left: (Expression | None) = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['BinaryExpression'] = 'BinaryExpression';
}

"""Assignment expression."""
obj AssignmentExpression(Node) {
    has operator: str = '=',
        left: Pattern | Expression | None = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['AssignmentExpression'] = 'AssignmentExpression';
}

"""Logical expression."""
obj LogicalExpression(Node) {
    has operator: str = '&&',
        left: (Expression | None) = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['LogicalExpression'] = 'LogicalExpression';
}

"""Member expression."""
obj MemberExpression(Node) {
    has object: Expression | Super | None = None,
        property: (Expression | None) = None,
        computed: bool = False,
        optional: bool = False,
        `type: TypingLiteral['MemberExpression'] = 'MemberExpression';
}

"""Conditional (ternary) expression."""
obj ConditionalExpression(Node) {
    has `test: (Expression | None) = None,
        consequent: (Expression | None) = None,
        alternate: (Expression | None) = None,
        `type: TypingLiteral['ConditionalExpression'] = 'ConditionalExpression';
}

"""Call expression."""
obj CallExpression(Node) {
    has callee: Expression | Super | None = None,
        arguments: list[(Expression | SpreadElement)] = [],
        optional: bool = False,
        `type: TypingLiteral['CallExpression'] = 'CallExpression';
}

"""Optional chaining expression (ES2020)."""
obj ChainExpression(Node) {
    has expression: CallExpression | MemberExpression | None = None,
        `type: TypingLiteral['ChainExpression'] = 'ChainExpression';
}

"""New expression."""
obj NewExpression(Node) {
    has callee: (Expression | None) = None,
        arguments: list[(Expression | SpreadElement)] = [],
        `type: TypingLiteral['NewExpression'] = 'NewExpression';
}

"""Sequence expression."""
obj SequenceExpression(Node) {
    has expressions: list[Expression] = [],
        `type: TypingLiteral['SequenceExpression'] = 'SequenceExpression';
}

"""Yield expression."""
obj YieldExpression(Node) {
    has argument: (Expression | None) = None,
        delegate: bool = False,
        `type: TypingLiteral['YieldExpression'] = 'YieldExpression';
}

"""Await expression (ES2017)."""
obj AwaitExpression(Node) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['AwaitExpression'] = 'AwaitExpression';
}

"""Template literal (ES6)."""
obj TemplateLiteral(Node) {
    has quasis: list[TemplateElement] = [],
        expressions: list[Expression] = [],
        `type: TypingLiteral['TemplateLiteral'] = 'TemplateLiteral';
}

"""Template element."""
obj TemplateElement(Node) {
    has tail: bool = False,
        value: dict[(str, str)] = {},
        `type: TypingLiteral['TemplateElement'] = 'TemplateElement';
}

"""Tagged template expression (ES6)."""
obj TaggedTemplateExpression(Node) {
    has tag: (Expression | None) = None,
        quasi: (TemplateLiteral | None) = None,
        `type: TypingLiteral['TaggedTemplateExpression'] = 'TaggedTemplateExpression';
}

"""Spread element (ES6)."""
obj SpreadElement(Node) {
    has argument: (Expression | None) = None,
        `type: TypingLiteral['SpreadElement'] = 'SpreadElement';
}

"""Super keyword."""
obj Super(Node) {
    has `type: TypingLiteral['Super'] = 'Super';
}

"""Meta property (e.g., new.target)."""
obj MetaProperty(Node) {
    has meta: (Identifier | None) = None,
        property: (Identifier | None) = None,
        `type: TypingLiteral['MetaProperty'] = 'MetaProperty';
}

"""Assignment pattern (default parameters)."""
obj AssignmentPattern(Node) {
    has left: (Pattern | None) = None,
        right: (Expression | None) = None,
        `type: TypingLiteral['AssignmentPattern'] = 'AssignmentPattern';
}

"""Array destructuring pattern."""
obj ArrayPattern(Node) {
    has elements: list[(Pattern | None)] = [],
        `type: TypingLiteral['ArrayPattern'] = 'ArrayPattern';
}

"""Object destructuring pattern."""
obj ObjectPattern(Node) {
    has properties: list[(AssignmentProperty | RestElement)] = [],
        `type: TypingLiteral['ObjectPattern'] = 'ObjectPattern';
}

"""Assignment property in object pattern."""
obj AssignmentProperty(Node) {
    has key: (Expression | Identifier | Literal | None) = None,
        value: (Pattern | None) = None,
        kind: PropertyKind = 'init',
        method: bool = False,
        shorthand: bool = False,
        computed: bool = False,
        `type: TypingLiteral['Property'] = 'Property';
}

"""Rest element."""
obj RestElement(Node) {
    has argument: (Pattern | None) = None,
        `type: TypingLiteral['RestElement'] = 'RestElement';
}

"""Class declaration."""
obj ClassDeclaration(Node) {
    has id: (Identifier | None) = None,
        superClass: (Expression | None) = None,
        body: (ClassBody | None) = None,
        `type: TypingLiteral['ClassDeclaration'] = 'ClassDeclaration';
}

"""Class expression."""
obj ClassExpression(Node) {
    has id: (Identifier | None) = None,
        superClass: (Expression | None) = None,
        body: (ClassBody | None) = None,
        `type: TypingLiteral['ClassExpression'] = 'ClassExpression';
}

"""Class body (ES2022: supports methods, properties, and static blocks)."""
obj ClassBody(Node) {
    has body: list[MethodDefinition | PropertyDefinition | StaticBlock] = [],
        `type: TypingLiteral['ClassBody'] = 'ClassBody';
}

"""Method definition (ES2022: supports private identifiers)."""
obj MethodDefinition(Node) {
    has key: (Expression | Identifier | PrivateIdentifier | None) = None,
        value: (FunctionExpression | None) = None,
        kind: MethodDefinitionKind = 'method',
        computed: bool = False,
        `static: bool = False,
        `type: TypingLiteral['MethodDefinition'] = 'MethodDefinition';
}

"""Class field definition (ES2022)."""
obj PropertyDefinition(Node) {
    has key: (Expression | Identifier | PrivateIdentifier | None) = None,
        value: (Expression | None) = None,
        computed: bool = False,
        `static: bool = False,
        `type: TypingLiteral['PropertyDefinition'] = 'PropertyDefinition';
}

"""Static initialization block (ES2022)."""
obj StaticBlock(Node) {
    has body: list[Statement] = [],
        `type: TypingLiteral['StaticBlock'] = 'StaticBlock';
}

"""Import declaration."""
obj ImportDeclaration(Node) {
    has specifiers:
        list[ImportSpecifier | ImportDefaultSpecifier | ImportNamespaceSpecifier] = [],
        source: (Literal | None) = None,
        `type: TypingLiteral['ImportDeclaration'] = 'ImportDeclaration';
}

"""Dynamic import expression (ES2020)."""
obj ImportExpression(Node) {
    has source: (Expression | None) = None,
        `type: TypingLiteral['ImportExpression'] = 'ImportExpression';
}

"""Import specifier."""
obj ImportSpecifier(Node) {
    has imported: (Identifier | None) = None,
        local: (Identifier | None) = None,
        `type: TypingLiteral['ImportSpecifier'] = 'ImportSpecifier';
}

"""Import default specifier."""
obj ImportDefaultSpecifier(Node) {
    has local: (Identifier | None) = None,
        `type: TypingLiteral['ImportDefaultSpecifier'] = 'ImportDefaultSpecifier';
}

"""Import namespace specifier."""
obj ImportNamespaceSpecifier(Node) {
    has local: (Identifier | None) = None,
        `type: TypingLiteral['ImportNamespaceSpecifier'] = 'ImportNamespaceSpecifier';
}

"""Export named declaration."""
obj ExportNamedDeclaration(Node) {
    has declaration: Declaration | Expression | None = None,
        specifiers: list[ExportSpecifier] = [],
        source: (Literal | None) = None,
        `type: TypingLiteral['ExportNamedDeclaration'] = 'ExportNamedDeclaration';
}

"""Export specifier."""
obj ExportSpecifier(Node) {
    has exported: (Identifier | None) = None,
        local: (Identifier | None) = None,
        `type: TypingLiteral['ExportSpecifier'] = 'ExportSpecifier';
}

"""Export default declaration."""
obj ExportDefaultDeclaration(Node) {
    has declaration: Declaration | Expression | None = None,
        `type: TypingLiteral['ExportDefaultDeclaration'] = 'ExportDefaultDeclaration';
}

"""Export all declaration."""
obj ExportAllDeclaration(Node) {
    has source: (Literal | None) = None,
        exported: (Identifier | None) = None,
        `type: TypingLiteral['ExportAllDeclaration'] = 'ExportAllDeclaration';
}

"""Represents slice operation info (e.g., arr[start:stop])."""
obj SliceInfo {
    has start: (Node | None) = None,
        stop: (Node | None) = None;
}

"""Represents index operation info (e.g., arr[index])."""
obj IndexInfo {
    has value: (Node | None) = None;
}

glob Statement = ExpressionStatement | BlockStatement | EmptyStatement | DebuggerStatement | WithStatement | ReturnStatement | LabeledStatement | BreakStatement | ContinueStatement | IfStatement | SwitchStatement | ThrowStatement | TryStatement | WhileStatement | DoWhileStatement | ForStatement | ForInStatement | ForOfStatement | FunctionDeclaration | VariableDeclaration | ClassDeclaration,
     Expression = (
         Identifier | Literal | ThisExpression | ArrayExpression | ObjectExpression | FunctionExpression | ArrowFunctionExpression | UnaryExpression | UpdateExpression | BinaryExpression | AssignmentExpression | LogicalExpression | MemberExpression | ConditionalExpression | CallExpression | ChainExpression | NewExpression | SequenceExpression | YieldExpression | AwaitExpression | TemplateLiteral | TaggedTemplateExpression | ClassExpression | ImportExpression
     ),
     Pattern = Identifier | ArrayPattern | ObjectPattern | AssignmentPattern | RestElement,
     Declaration = FunctionDeclaration | VariableDeclaration | ClassDeclaration,
     ModuleDeclaration = (
         ImportDeclaration | ExportNamedDeclaration | ExportDefaultDeclaration | ExportAllDeclaration
     );

def es_node_to_dict(nd: Node) -> dict[str, Any];
