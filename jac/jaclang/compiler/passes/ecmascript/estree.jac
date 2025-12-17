"""ESTree AST Node Definitions for ECMAScript.

This module provides a complete implementation of the ESTree specification,
which defines the standard AST format for JavaScript and ECMAScript.

The ESTree specification represents ECMAScript programs as abstract syntax trees
that are language-agnostic and can be used for various tools like parsers,
transpilers, and code analysis tools.

Reference: https://github.com/estree/estree
"""
import from __future__ { annotations }
import from dataclasses { dataclass, field }
import from typing { Any, TypeAlias }
import from typing { Literal as TypingLiteral }

glob SourceType: TypeAlias = TypingLiteral[('script', 'module')] , VariableDeclarationKind:
    TypeAlias = TypingLiteral[('var', 'let', 'const')] , PropertyKind: TypeAlias = TypingLiteral[
    ('init', 'get', 'set')
] , MethodDefinitionKind: TypeAlias = TypingLiteral[
    ('constructor', 'method', 'get', 'set')
];

"""Source location information for a node."""
@dataclass
class SourceLocation {
    with entry {
        source: (str | None) = None;
        start: (Position | None) = None;
        end: (Position | None) = None;
    }
}

"""Position in source code."""
@dataclass
class Position {
    with entry {
        line: int = 0;
        column: int = 0;
    }
}

"""Base class for all ESTree nodes."""
@dataclass
class Node {
    with entry {
        <>type: str;
        loc: (SourceLocation | None) = field(<>default=None);
    }
}

"""Identifier node."""
@dataclass
class Identifier(Node) {
    with entry {
        name: str = '';
        <>type: TypingLiteral['Identifier'] = field(
            <>default='Identifier', <>init=False
        );
    }
}

"""Private identifier for class members (ES2022)."""
@dataclass
class PrivateIdentifier(Node) {
    with entry {
        name: str = '';
        <>type: TypingLiteral['PrivateIdentifier'] = field(
            <>default='PrivateIdentifier', <>init=False
        );
    }
}

"""Literal value node (supports BigInt in ES2020)."""
@dataclass
class Literal(Node) {
    with entry {
        value: str | bool | None | int | float = None;
        raw: (str | None) = None;
        bigint: (str | None) = None;
        <>type: TypingLiteral['Literal'] = field(<>default='Literal', <>init=False);
    }
}

"""Root node of an ESTree."""
@dataclass
class Program(Node) {
    with entry {
        body: list[(Statement | ModuleDeclaration)] = field(default_factory=<>list);
        sourceType: SourceType = 'script';
        <>type: TypingLiteral['Program'] = field(<>default='Program', <>init=False);
    }
}

"""Expression statement."""
@dataclass
class ExpressionStatement(Node) {
    with entry {
        expression: (Expression | None) = None;
        <>type: TypingLiteral['ExpressionStatement'] = field(
            <>default='ExpressionStatement', <>init=False
        );
    }
}

"""Directive (e.g., 'use strict') - ES5."""
@dataclass
class Directive(ExpressionStatement) {
    with entry {
        directive: str = '';
        <>type: TypingLiteral['ExpressionStatement'] = field(
            <>default='ExpressionStatement', <>init=False
        );
    }
}

"""Block statement."""
@dataclass
class BlockStatement(Node) {
    with entry {
        body: list[Statement] = field(default_factory=<>list);
        <>type: TypingLiteral['BlockStatement'] = field(
            <>default='BlockStatement', <>init=False
        );
    }
}

"""Empty statement (;)."""
@dataclass
class EmptyStatement(Node) {
    with entry {
        <>type: TypingLiteral['EmptyStatement'] = field(
            <>default='EmptyStatement', <>init=False
        );
    }
}

"""Debugger statement."""
@dataclass
class DebuggerStatement(Node) {
    with entry {
        <>type: TypingLiteral['DebuggerStatement'] = field(
            <>default='DebuggerStatement', <>init=False
        );
    }
}

"""With statement."""
@dataclass
class WithStatement(Node) {
    with entry {
        object: (Expression | None) = None;
        body: (Statement | None) = None;
        <>type: TypingLiteral['WithStatement'] = field(
            <>default='WithStatement', <>init=False
        );
    }
}

"""Return statement."""
@dataclass
class ReturnStatement(Node) {
    with entry {
        argument: (Expression | None) = None;
        <>type: TypingLiteral['ReturnStatement'] = field(
            <>default='ReturnStatement', <>init=False
        );
    }
}

"""Labeled statement."""
@dataclass
class LabeledStatement(Node) {
    with entry {
        label: (Identifier | None) = None;
        body: (Statement | None) = None;
        <>type: TypingLiteral['LabeledStatement'] = field(
            <>default='LabeledStatement', <>init=False
        );
    }
}

"""Break statement."""
@dataclass
class BreakStatement(Node) {
    with entry {
        label: (Identifier | None) = None;
        <>type: TypingLiteral['BreakStatement'] = field(
            <>default='BreakStatement', <>init=False
        );
    }
}

"""Continue statement."""
@dataclass
class ContinueStatement(Node) {
    with entry {
        label: (Identifier | None) = None;
        <>type: TypingLiteral['ContinueStatement'] = field(
            <>default='ContinueStatement', <>init=False
        );
    }
}

"""If statement."""
@dataclass
class IfStatement(Node) {
    with entry {
        <>test: (Expression | None) = None;
        consequent: (Statement | None) = None;
        alternate: (Statement | None) = None;
        <>type: TypingLiteral['IfStatement'] = field(
            <>default='IfStatement', <>init=False
        );
    }
}

"""Switch statement."""
@dataclass
class SwitchStatement(Node) {
    with entry {
        discriminant: (Expression | None) = None;
        cases: list[SwitchCase] = field(default_factory=<>list);
        <>type: TypingLiteral['SwitchStatement'] = field(
            <>default='SwitchStatement', <>init=False
        );
    }
}

"""Switch case clause."""
@dataclass
class SwitchCase(Node) {
    with entry {
        <>test: (Expression | None) = None;
        consequent: list[Statement] = field(default_factory=<>list);
        <>type: TypingLiteral['SwitchCase'] = field(
            <>default='SwitchCase', <>init=False
        );
    }
}

"""Throw statement."""
@dataclass
class ThrowStatement(Node) {
    with entry {
        argument: (Expression | None) = None;
        <>type: TypingLiteral['ThrowStatement'] = field(
            <>default='ThrowStatement', <>init=False
        );
    }
}

"""Try statement."""
@dataclass
class TryStatement(Node) {
    with entry {
        block: (BlockStatement | None) = None;
        handler: (CatchClause | None) = None;
        finalizer: (BlockStatement | None) = None;
        <>type: TypingLiteral['TryStatement'] = field(
            <>default='TryStatement', <>init=False
        );
    }
}

"""Catch clause."""
@dataclass
class CatchClause(Node) {
    with entry {
        param: (Pattern | None) = None;
        body: (BlockStatement | None) = None;
        <>type: TypingLiteral['CatchClause'] = field(
            <>default='CatchClause', <>init=False
        );
    }
}

"""While statement."""
@dataclass
class WhileStatement(Node) {
    with entry {
        <>test: (Expression | None) = None;
        body: (Statement | None) = None;
        <>type: TypingLiteral['WhileStatement'] = field(
            <>default='WhileStatement', <>init=False
        );
    }
}

"""Do-while statement."""
@dataclass
class DoWhileStatement(Node) {
    with entry {
        body: (Statement | None) = None;
        <>test: (Expression | None) = None;
        <>type: TypingLiteral['DoWhileStatement'] = field(
            <>default='DoWhileStatement', <>init=False
        );
    }
}

"""For statement."""
@dataclass
class ForStatement(Node) {
    with entry {
        <>init: VariableDeclaration | Expression | None = None;
        <>test: (Expression | None) = None;
        update: (Expression | None) = None;
        body: (Statement | None) = None;
        <>type: TypingLiteral['ForStatement'] = field(
            <>default='ForStatement', <>init=False
        );
    }
}

"""For-in statement."""
@dataclass
class ForInStatement(Node) {
    with entry {
        left: VariableDeclaration | Pattern | None = None;
        right: (Expression | None) = None;
        body: (Statement | None) = None;
        <>type: TypingLiteral['ForInStatement'] = field(
            <>default='ForInStatement', <>init=False
        );
    }
}

"""For-of statement (ES6)."""
@dataclass
class ForOfStatement(Node) {
    with entry {
        left: VariableDeclaration | Pattern | None = None;
        right: (Expression | None) = None;
        body: (Statement | None) = None;
        await_: bool = False;
        <>type: TypingLiteral['ForOfStatement'] = field(
            <>default='ForOfStatement', <>init=False
        );
    }
}

"""Function declaration."""
@dataclass
class FunctionDeclaration(Node) {
    with entry {
        id: (Identifier | None) = None;
        params: list[Pattern] = field(default_factory=<>list);
        body: (BlockStatement | None) = None;
        generator: bool = False;
        async_: bool = False;
        <>type: TypingLiteral['FunctionDeclaration'] = field(
            <>default='FunctionDeclaration', <>init=False
        );
    }
}

"""Variable declaration."""
@dataclass
class VariableDeclaration(Node) {
    with entry {
        declarations: list[VariableDeclarator] = field(default_factory=<>list);
        kind: VariableDeclarationKind = 'var';
        <>type: TypingLiteral['VariableDeclaration'] = field(
            <>default='VariableDeclaration', <>init=False
        );
    }
}

"""Variable declarator."""
@dataclass
class VariableDeclarator(Node) {
    with entry {
        id: (Pattern | None) = None;
        <>init: (Expression | None) = None;
        <>type: TypingLiteral['VariableDeclarator'] = field(
            <>default='VariableDeclarator', <>init=False
        );
    }
}

"""This expression."""
@dataclass
class ThisExpression(Node) {
    with entry {
        <>type: TypingLiteral['ThisExpression'] = field(
            <>default='ThisExpression', <>init=False
        );
    }
}

"""Array expression."""
@dataclass
class ArrayExpression(Node) {
    with entry {
        elements: list[Expression | SpreadElement | None] = field(
            default_factory=<>list
        );
        <>type: TypingLiteral['ArrayExpression'] = field(
            <>default='ArrayExpression', <>init=False
        );
    }
}

"""Object expression."""
@dataclass
class ObjectExpression(Node) {
    with entry {
        properties: list[(Property | SpreadElement)] = field(default_factory=<>list);
        <>type: TypingLiteral['ObjectExpression'] = field(
            <>default='ObjectExpression', <>init=False
        );
    }
}

"""Object property."""
@dataclass
class Property(Node) {
    with entry {
        key: (Expression | Identifier | Literal | None) = None;
        value: (Expression | None) = None;
        kind: PropertyKind = 'init';
        method: bool = False;
        shorthand: bool = False;
        computed: bool = False;
        <>type: TypingLiteral['Property'] = field(<>default='Property', <>init=False);
    }
}

"""Function expression."""
@dataclass
class FunctionExpression(Node) {
    with entry {
        id: (Identifier | None) = None;
        params: list[Pattern] = field(default_factory=<>list);
        body: (BlockStatement | None) = None;
        generator: bool = False;
        async_: bool = False;
        <>type: TypingLiteral['FunctionExpression'] = field(
            <>default='FunctionExpression', <>init=False
        );
    }
}

"""Arrow function expression (ES6)."""
@dataclass
class ArrowFunctionExpression(Node) {
    with entry {
        params: list[Pattern] = field(default_factory=<>list);
        body: BlockStatement | Expression | None = None;
        expression: bool = False;
        async_: bool = False;
        <>type: TypingLiteral['ArrowFunctionExpression'] = field(
            <>default='ArrowFunctionExpression', <>init=False
        );
    }
}

"""Unary expression."""
@dataclass
class UnaryExpression(Node) {
    with entry {
        operator: str = '';
        prefix: bool = True;
        argument: (Expression | None) = None;
        <>type: TypingLiteral['UnaryExpression'] = field(
            <>default='UnaryExpression', <>init=False
        );
    }
}

"""Update expression."""
@dataclass
class UpdateExpression(Node) {
    with entry {
        operator: str = '++';
        argument: (Expression | None) = None;
        prefix: bool = True;
        <>type: TypingLiteral['UpdateExpression'] = field(
            <>default='UpdateExpression', <>init=False
        );
    }
}

"""Binary expression."""
@dataclass
class BinaryExpression(Node) {
    with entry {
        operator: str = '';
        left: (Expression | None) = None;
        right: (Expression | None) = None;
        <>type: TypingLiteral['BinaryExpression'] = field(
            <>default='BinaryExpression', <>init=False
        );
    }
}

"""Assignment expression."""
@dataclass
class AssignmentExpression(Node) {
    with entry {
        operator: str = '=';
        left: Pattern | Expression | None = None;
        right: (Expression | None) = None;
        <>type: TypingLiteral['AssignmentExpression'] = field(
            <>default='AssignmentExpression', <>init=False
        );
    }
}

"""Logical expression."""
@dataclass
class LogicalExpression(Node) {
    with entry {
        operator: str = '&&';
        left: (Expression | None) = None;
        right: (Expression | None) = None;
        <>type: TypingLiteral['LogicalExpression'] = field(
            <>default='LogicalExpression', <>init=False
        );
    }
}

"""Member expression."""
@dataclass
class MemberExpression(Node) {
    with entry {
        object: Expression | Super | None = None;
        property: (Expression | None) = None;
        computed: bool = False;
        optional: bool = False;
        <>type: TypingLiteral['MemberExpression'] = field(
            <>default='MemberExpression', <>init=False
        );
    }
}

"""Conditional (ternary) expression."""
@dataclass
class ConditionalExpression(Node) {
    with entry {
        <>test: (Expression | None) = None;
        consequent: (Expression | None) = None;
        alternate: (Expression | None) = None;
        <>type: TypingLiteral['ConditionalExpression'] = field(
            <>default='ConditionalExpression', <>init=False
        );
    }
}

"""Call expression."""
@dataclass
class CallExpression(Node) {
    with entry {
        callee: Expression | Super | None = None;
        arguments: list[(Expression | SpreadElement)] = field(default_factory=<>list);
        optional: bool = False;
        <>type: TypingLiteral['CallExpression'] = field(
            <>default='CallExpression', <>init=False
        );
    }
}

"""Optional chaining expression (ES2020)."""
@dataclass
class ChainExpression(Node) {
    with entry {
        expression: CallExpression | MemberExpression | None = None;
        <>type: TypingLiteral['ChainExpression'] = field(
            <>default='ChainExpression', <>init=False
        );
    }
}

"""New expression."""
@dataclass
class NewExpression(Node) {
    with entry {
        callee: (Expression | None) = None;
        arguments: list[(Expression | SpreadElement)] = field(default_factory=<>list);
        <>type: TypingLiteral['NewExpression'] = field(
            <>default='NewExpression', <>init=False
        );
    }
}

"""Sequence expression."""
@dataclass
class SequenceExpression(Node) {
    with entry {
        expressions: list[Expression] = field(default_factory=<>list);
        <>type: TypingLiteral['SequenceExpression'] = field(
            <>default='SequenceExpression', <>init=False
        );
    }
}

"""Yield expression."""
@dataclass
class YieldExpression(Node) {
    with entry {
        argument: (Expression | None) = None;
        delegate: bool = False;
        <>type: TypingLiteral['YieldExpression'] = field(
            <>default='YieldExpression', <>init=False
        );
    }
}

"""Await expression (ES2017)."""
@dataclass
class AwaitExpression(Node) {
    with entry {
        argument: (Expression | None) = None;
        <>type: TypingLiteral['AwaitExpression'] = field(
            <>default='AwaitExpression', <>init=False
        );
    }
}

"""Template literal (ES6)."""
@dataclass
class TemplateLiteral(Node) {
    with entry {
        quasis: list[TemplateElement] = field(default_factory=<>list);
        expressions: list[Expression] = field(default_factory=<>list);
        <>type: TypingLiteral['TemplateLiteral'] = field(
            <>default='TemplateLiteral', <>init=False
        );
    }
}

"""Template element."""
@dataclass
class TemplateElement(Node) {
    with entry {
        tail: bool = False;
        value: dict[(str, str)] = field(default_factory=<>dict);
        <>type: TypingLiteral['TemplateElement'] = field(
            <>default='TemplateElement', <>init=False
        );
    }
}

"""Tagged template expression (ES6)."""
@dataclass
class TaggedTemplateExpression(Node) {
    with entry {
        tag: (Expression | None) = None;
        quasi: (TemplateLiteral | None) = None;
        <>type: TypingLiteral['TaggedTemplateExpression'] = field(
            <>default='TaggedTemplateExpression', <>init=False
        );
    }
}

"""Spread element (ES6)."""
@dataclass
class SpreadElement(Node) {
    with entry {
        argument: (Expression | None) = None;
        <>type: TypingLiteral['SpreadElement'] = field(
            <>default='SpreadElement', <>init=False
        );
    }
}

"""Super keyword."""
@dataclass
class Super(Node) {
    with entry {
        <>type: TypingLiteral['Super'] = field(<>default='Super', <>init=False);
    }
}

"""Meta property (e.g., new.target)."""
@dataclass
class MetaProperty(Node) {
    with entry {
        meta: (Identifier | None) = None;
        property: (Identifier | None) = None;
        <>type: TypingLiteral['MetaProperty'] = field(
            <>default='MetaProperty', <>init=False
        );
    }
}

"""Assignment pattern (default parameters)."""
@dataclass
class AssignmentPattern(Node) {
    with entry {
        left: (Pattern | None) = None;
        right: (Expression | None) = None;
        <>type: TypingLiteral['AssignmentPattern'] = field(
            <>default='AssignmentPattern', <>init=False
        );
    }
}

"""Array destructuring pattern."""
@dataclass
class ArrayPattern(Node) {
    with entry {
        elements: list[(Pattern | None)] = field(default_factory=<>list);
        <>type: TypingLiteral['ArrayPattern'] = field(
            <>default='ArrayPattern', <>init=False
        );
    }
}

"""Object destructuring pattern."""
@dataclass
class ObjectPattern(Node) {
    with entry {
        properties: list[(AssignmentProperty | RestElement)] = field(
            default_factory=<>list
        );
        <>type: TypingLiteral['ObjectPattern'] = field(
            <>default='ObjectPattern', <>init=False
        );
    }
}

"""Assignment property in object pattern."""
@dataclass
class AssignmentProperty(Node) {
    with entry {
        key: (Expression | Identifier | Literal | None) = None;
        value: (Pattern | None) = None;
        kind: PropertyKind = 'init';
        method: bool = False;
        shorthand: bool = False;
        computed: bool = False;
        <>type: TypingLiteral['Property'] = field(<>default='Property', <>init=False);
    }
}

"""Rest element."""
@dataclass
class RestElement(Node) {
    with entry {
        argument: (Pattern | None) = None;
        <>type: TypingLiteral['RestElement'] = field(
            <>default='RestElement', <>init=False
        );
    }
}

"""Class declaration."""
@dataclass
class ClassDeclaration(Node) {
    with entry {
        id: (Identifier | None) = None;
        superClass: (Expression | None) = None;
        body: (ClassBody | None) = None;
        <>type: TypingLiteral['ClassDeclaration'] = field(
            <>default='ClassDeclaration', <>init=False
        );
    }
}

"""Class expression."""
@dataclass
class ClassExpression(Node) {
    with entry {
        id: (Identifier | None) = None;
        superClass: (Expression | None) = None;
        body: (ClassBody | None) = None;
        <>type: TypingLiteral['ClassExpression'] = field(
            <>default='ClassExpression', <>init=False
        );
    }
}

"""Class body (ES2022: supports methods, properties, and static blocks)."""
@dataclass
class ClassBody(Node) {
    with entry {
        body: list[MethodDefinition | PropertyDefinition | StaticBlock] = field(
            default_factory=<>list
        );
        <>type: TypingLiteral['ClassBody'] = field(<>default='ClassBody', <>init=False);
    }
}

"""Method definition (ES2022: supports private identifiers)."""
@dataclass
class MethodDefinition(Node) {
    with entry {
        key: (Expression | Identifier | PrivateIdentifier | None) = None;
        value: (FunctionExpression | None) = None;
        kind: MethodDefinitionKind = 'method';
        computed: bool = False;
        <>static: bool = False;
        <>type: TypingLiteral['MethodDefinition'] = field(
            <>default='MethodDefinition', <>init=False
        );
    }
}

"""Class field definition (ES2022)."""
@dataclass
class PropertyDefinition(Node) {
    with entry {
        key: (Expression | Identifier | PrivateIdentifier | None) = None;
        value: (Expression | None) = None;
        computed: bool = False;
        <>static: bool = False;
        <>type: TypingLiteral['PropertyDefinition'] = field(
            <>default='PropertyDefinition', <>init=False
        );
    }
}

"""Static initialization block (ES2022)."""
@dataclass
class StaticBlock(Node) {
    with entry {
        body: list[Statement] = field(default_factory=<>list);
        <>type: TypingLiteral['StaticBlock'] = field(
            <>default='StaticBlock', <>init=False
        );
    }
}

"""Import declaration."""
@dataclass
class ImportDeclaration(Node) {
    with entry {
        specifiers:
            list[ImportSpecifier | ImportDefaultSpecifier | ImportNamespaceSpecifier] = field(
            default_factory=<>list
        );
        source: (Literal | None) = None;
        <>type: TypingLiteral['ImportDeclaration'] = field(
            <>default='ImportDeclaration', <>init=False
        );
    }
}

"""Dynamic import expression (ES2020)."""
@dataclass
class ImportExpression(Node) {
    with entry {
        source: (Expression | None) = None;
        <>type: TypingLiteral['ImportExpression'] = field(
            <>default='ImportExpression', <>init=False
        );
    }
}

"""Import specifier."""
@dataclass
class ImportSpecifier(Node) {
    with entry {
        imported: (Identifier | None) = None;
        local: (Identifier | None) = None;
        <>type: TypingLiteral['ImportSpecifier'] = field(
            <>default='ImportSpecifier', <>init=False
        );
    }
}

"""Import default specifier."""
@dataclass
class ImportDefaultSpecifier(Node) {
    with entry {
        local: (Identifier | None) = None;
        <>type: TypingLiteral['ImportDefaultSpecifier'] = field(
            <>default='ImportDefaultSpecifier', <>init=False
        );
    }
}

"""Import namespace specifier."""
@dataclass
class ImportNamespaceSpecifier(Node) {
    with entry {
        local: (Identifier | None) = None;
        <>type: TypingLiteral['ImportNamespaceSpecifier'] = field(
            <>default='ImportNamespaceSpecifier', <>init=False
        );
    }
}

"""Export named declaration."""
@dataclass
class ExportNamedDeclaration(Node) {
    with entry {
        declaration: Declaration | Expression | None = None;
        specifiers: list[ExportSpecifier] = field(default_factory=<>list);
        source: (Literal | None) = None;
        <>type: TypingLiteral['ExportNamedDeclaration'] = field(
            <>default='ExportNamedDeclaration', <>init=False
        );
    }
}

"""Export specifier."""
@dataclass
class ExportSpecifier(Node) {
    with entry {
        exported: (Identifier | None) = None;
        local: (Identifier | None) = None;
        <>type: TypingLiteral['ExportSpecifier'] = field(
            <>default='ExportSpecifier', <>init=False
        );
    }
}

"""Export default declaration."""
@dataclass
class ExportDefaultDeclaration(Node) {
    with entry {
        declaration: Declaration | Expression | None = None;
        <>type: TypingLiteral['ExportDefaultDeclaration'] = field(
            <>default='ExportDefaultDeclaration', <>init=False
        );
    }
}

"""Export all declaration."""
@dataclass
class ExportAllDeclaration(Node) {
    with entry {
        source: (Literal | None) = None;
        exported: (Identifier | None) = None;
        <>type: TypingLiteral['ExportAllDeclaration'] = field(
            <>default='ExportAllDeclaration', <>init=False
        );
    }
}

"""Represents slice operation info (e.g., arr[start:stop])."""
@dataclass
class SliceInfo {
    with entry {
        start: (Node | None) = None;
        stop: (Node | None) = None;
    }
}

"""Represents index operation info (e.g., arr[index])."""
@dataclass
class IndexInfo {
    with entry {
        value: (Node | None) = None;
    }
}

glob Statement = ExpressionStatement | BlockStatement | EmptyStatement | DebuggerStatement | WithStatement | ReturnStatement | LabeledStatement | BreakStatement | ContinueStatement | IfStatement | SwitchStatement | ThrowStatement | TryStatement | WhileStatement | DoWhileStatement | ForStatement | ForInStatement | ForOfStatement | FunctionDeclaration | VariableDeclaration | ClassDeclaration , Expression = (
    Identifier | Literal | ThisExpression | ArrayExpression | ObjectExpression | FunctionExpression | ArrowFunctionExpression | UnaryExpression | UpdateExpression | BinaryExpression | AssignmentExpression | LogicalExpression | MemberExpression | ConditionalExpression | CallExpression | ChainExpression | NewExpression | SequenceExpression | YieldExpression | AwaitExpression | TemplateLiteral | TaggedTemplateExpression | ClassExpression | ImportExpression
) , Pattern = Identifier | ArrayPattern | ObjectPattern | AssignmentPattern | RestElement , Declaration = FunctionDeclaration | VariableDeclaration | ClassDeclaration , ModuleDeclaration = (
    ImportDeclaration | ExportNamedDeclaration | ExportDefaultDeclaration | ExportAllDeclaration
);

"""Convert an ESTree node to a dictionary representation."""
def es_node_to_dict(<>node: Node) -> dict[str, Any] {
    result: dict[(str, Any)] = {'type': <>node.type};
    for (key, value) in <>node.__dict__.items() {
        if ((key in ('type', 'loc')) or (value is None)) {
            continue;
        }
        if isinstance(value, Node) {
            result[key] = es_node_to_dict(value);
        } elif isinstance(value, <>list) {
            result[key] = [
                es_node_to_dict(item) if isinstance(item, Node) else item
                for item in value
            ];
        } else {
            result[key] = value;
        }
    }
    if <>node.loc {
        result['loc'] = {
            'source': <>node.loc.source,
            'start': {'line': <>node.loc.start.line, 'column': <>node.loc.start.column}
            if <>node.loc.start
            else None,
            'end': {'line': <>node.loc.end.line, 'column': <>node.loc.end.column}
            if <>node.loc.end
            else None
        };
    }
    return result;
}
