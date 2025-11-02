"""ESTree AST Node Definitions for ECMAScript.

This module provides a complete implementation of the ESTree specification,
which defines the standard AST format for JavaScript and ECMAScript.

The ESTree specification represents ECMAScript programs as abstract syntax trees
that are language-agnostic and can be used for various tools like parsers,
transpilers, and code analysis tools.

Reference: https://github.com/estree/estree
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal as TypingLiteral, Optional, TypeAlias, Union


# Literal type aliases for repeated enumerations
SourceType: TypeAlias = TypingLiteral["script", "module"]  # noqa: F821
VariableDeclarationKind: TypeAlias = TypingLiteral["var", "let", "const"]  # noqa: F821
PropertyKind: TypeAlias = TypingLiteral["init", "get", "set"]  # noqa: F821
MethodDefinitionKind: TypeAlias = TypingLiteral[
    "constructor", "method", "get", "set"  # noqa: F821
]


# Base Node Types
# ================


@dataclass
class SourceLocation:
    """Source location information for a node."""

    source: Optional[str] = None
    start: Optional["Position"] = None
    end: Optional["Position"] = None


@dataclass
class Position:
    """Position in source code."""

    line: int = 0
    column: int = 0


@dataclass
class Node:
    """Base class for all ESTree nodes."""

    type: str
    loc: Optional[SourceLocation] = field(default=None)


# Identifier and Literals
# =======================


@dataclass
class Identifier(Node):
    """Identifier node."""

    name: str = ""
    type: TypingLiteral["Identifier"] = field(default="Identifier", init=False)


@dataclass
class PrivateIdentifier(Node):
    """Private identifier for class members (ES2022)."""

    name: str = ""
    type: TypingLiteral["PrivateIdentifier"] = field(
        default="PrivateIdentifier", init=False
    )


@dataclass
class Literal(Node):
    """Literal value node (supports BigInt in ES2020)."""

    value: Union[str, bool, None, int, float] = None
    raw: Optional[str] = None
    bigint: Optional[str] = None  # ES2020: BigInt represented as string
    type: TypingLiteral["Literal"] = field(default="Literal", init=False)


@dataclass
class RegExpLiteral(Literal):
    """Regular expression literal."""

    regex: dict[str, str] = field(default_factory=dict)  # {pattern: str, flags: str}
    type: TypingLiteral["Literal"] = field(default="Literal", init=False)


# Program and Statements
# ======================


@dataclass
class Program(Node):
    """Root node of an ESTree."""

    body: list[Union["Statement", "ModuleDeclaration"]] = field(default_factory=list)
    sourceType: SourceType = "script"  # noqa: N815
    type: TypingLiteral["Program"] = field(default="Program", init=False)


@dataclass
class ExpressionStatement(Node):
    """Expression statement."""

    expression: Optional["Expression"] = None
    type: TypingLiteral["ExpressionStatement"] = field(
        default="ExpressionStatement", init=False
    )


@dataclass
class Directive(ExpressionStatement):
    """Directive (e.g., 'use strict') - ES5."""

    directive: str = ""
    type: TypingLiteral["ExpressionStatement"] = field(
        default="ExpressionStatement", init=False
    )


@dataclass
class BlockStatement(Node):
    """Block statement."""

    body: list["Statement"] = field(default_factory=list)
    type: TypingLiteral["BlockStatement"] = field(default="BlockStatement", init=False)


@dataclass
class EmptyStatement(Node):
    """Empty statement (;)."""

    type: TypingLiteral["EmptyStatement"] = field(default="EmptyStatement", init=False)


@dataclass
class DebuggerStatement(Node):
    """Debugger statement."""

    type: TypingLiteral["DebuggerStatement"] = field(
        default="DebuggerStatement", init=False
    )


@dataclass
class WithStatement(Node):
    """With statement."""

    object: Optional["Expression"] = None
    body: Optional["Statement"] = None
    type: TypingLiteral["WithStatement"] = field(default="WithStatement", init=False)


@dataclass
class ReturnStatement(Node):
    """Return statement."""

    argument: Optional["Expression"] = None
    type: TypingLiteral["ReturnStatement"] = field(
        default="ReturnStatement", init=False
    )


@dataclass
class LabeledStatement(Node):
    """Labeled statement."""

    label: Optional[Identifier] = None
    body: Optional["Statement"] = None
    type: TypingLiteral["LabeledStatement"] = field(
        default="LabeledStatement", init=False
    )


@dataclass
class BreakStatement(Node):
    """Break statement."""

    label: Optional[Identifier] = None
    type: TypingLiteral["BreakStatement"] = field(default="BreakStatement", init=False)


@dataclass
class ContinueStatement(Node):
    """Continue statement."""

    label: Optional[Identifier] = None
    type: TypingLiteral["ContinueStatement"] = field(
        default="ContinueStatement", init=False
    )


@dataclass
class IfStatement(Node):
    """If statement."""

    test: Optional["Expression"] = None
    consequent: Optional["Statement"] = None
    alternate: Optional["Statement"] = None
    type: TypingLiteral["IfStatement"] = field(default="IfStatement", init=False)


@dataclass
class SwitchStatement(Node):
    """Switch statement."""

    discriminant: Optional["Expression"] = None
    cases: list["SwitchCase"] = field(default_factory=list)
    type: TypingLiteral["SwitchStatement"] = field(
        default="SwitchStatement", init=False
    )


@dataclass
class SwitchCase(Node):
    """Switch case clause."""

    test: Optional["Expression"] = None  # null for default case
    consequent: list["Statement"] = field(default_factory=list)
    type: TypingLiteral["SwitchCase"] = field(default="SwitchCase", init=False)


@dataclass
class ThrowStatement(Node):
    """Throw statement."""

    argument: Optional["Expression"] = None
    type: TypingLiteral["ThrowStatement"] = field(default="ThrowStatement", init=False)


@dataclass
class TryStatement(Node):
    """Try statement."""

    block: Optional[BlockStatement] = None
    handler: Optional["CatchClause"] = None
    finalizer: Optional[BlockStatement] = None
    type: TypingLiteral["TryStatement"] = field(default="TryStatement", init=False)


@dataclass
class CatchClause(Node):
    """Catch clause."""

    param: Optional["Pattern"] = None
    body: Optional[BlockStatement] = None
    type: TypingLiteral["CatchClause"] = field(default="CatchClause", init=False)


@dataclass
class WhileStatement(Node):
    """While statement."""

    test: Optional["Expression"] = None
    body: Optional["Statement"] = None
    type: TypingLiteral["WhileStatement"] = field(default="WhileStatement", init=False)


@dataclass
class DoWhileStatement(Node):
    """Do-while statement."""

    body: Optional["Statement"] = None
    test: Optional["Expression"] = None
    type: TypingLiteral["DoWhileStatement"] = field(
        default="DoWhileStatement", init=False
    )


@dataclass
class ForStatement(Node):
    """For statement."""

    init: Optional[Union["VariableDeclaration", "Expression"]] = None
    test: Optional["Expression"] = None
    update: Optional["Expression"] = None
    body: Optional["Statement"] = None
    type: TypingLiteral["ForStatement"] = field(default="ForStatement", init=False)


@dataclass
class ForInStatement(Node):
    """For-in statement."""

    left: Optional[Union["VariableDeclaration", "Pattern"]] = None
    right: Optional["Expression"] = None
    body: Optional["Statement"] = None
    type: TypingLiteral["ForInStatement"] = field(default="ForInStatement", init=False)


@dataclass
class ForOfStatement(Node):
    """For-of statement (ES6)."""

    left: Optional[Union["VariableDeclaration", "Pattern"]] = None
    right: Optional["Expression"] = None
    body: Optional["Statement"] = None
    await_: bool = False
    type: TypingLiteral["ForOfStatement"] = field(default="ForOfStatement", init=False)


# Declarations
# ============


@dataclass
class FunctionDeclaration(Node):
    """Function declaration."""

    id: Optional[Identifier] = None
    params: list["Pattern"] = field(default_factory=list)
    body: Optional[BlockStatement] = None
    generator: bool = False
    async_: bool = False
    type: TypingLiteral["FunctionDeclaration"] = field(
        default="FunctionDeclaration", init=False
    )


@dataclass
class VariableDeclaration(Node):
    """Variable declaration."""

    declarations: list["VariableDeclarator"] = field(default_factory=list)
    kind: VariableDeclarationKind = "var"
    type: TypingLiteral["VariableDeclaration"] = field(
        default="VariableDeclaration", init=False
    )


@dataclass
class VariableDeclarator(Node):
    """Variable declarator."""

    id: Optional["Pattern"] = None
    init: Optional["Expression"] = None
    type: TypingLiteral["VariableDeclarator"] = field(
        default="VariableDeclarator", init=False
    )


# Expressions
# ===========


@dataclass
class ThisExpression(Node):
    """This expression."""

    type: TypingLiteral["ThisExpression"] = field(default="ThisExpression", init=False)


@dataclass
class ArrayExpression(Node):
    """Array expression."""

    elements: list[Optional[Union["Expression", "SpreadElement"]]] = field(
        default_factory=list
    )
    type: TypingLiteral["ArrayExpression"] = field(
        default="ArrayExpression", init=False
    )


@dataclass
class ObjectExpression(Node):
    """Object expression."""

    properties: list[Union["Property", "SpreadElement"]] = field(default_factory=list)
    type: TypingLiteral["ObjectExpression"] = field(
        default="ObjectExpression", init=False
    )


@dataclass
class Property(Node):
    """Object property."""

    key: Optional[Union["Expression", Identifier, Literal]] = None
    value: Optional["Expression"] = None
    kind: PropertyKind = "init"
    method: bool = False
    shorthand: bool = False
    computed: bool = False
    type: TypingLiteral["Property"] = field(default="Property", init=False)


@dataclass
class FunctionExpression(Node):
    """Function expression."""

    id: Optional[Identifier] = None
    params: list["Pattern"] = field(default_factory=list)
    body: Optional[BlockStatement] = None
    generator: bool = False
    async_: bool = False
    type: TypingLiteral["FunctionExpression"] = field(
        default="FunctionExpression", init=False
    )


@dataclass
class ArrowFunctionExpression(Node):
    """Arrow function expression (ES6)."""

    params: list["Pattern"] = field(default_factory=list)
    body: Optional[Union[BlockStatement, "Expression"]] = None
    expression: bool = False
    async_: bool = False
    type: TypingLiteral["ArrowFunctionExpression"] = field(
        default="ArrowFunctionExpression", init=False
    )


@dataclass
class UnaryExpression(Node):
    """Unary expression."""

    operator: str = ""  # "-", "+", "!", "~", "typeof", "void", "delete"
    prefix: bool = True
    argument: Optional["Expression"] = None
    type: TypingLiteral["UnaryExpression"] = field(
        default="UnaryExpression", init=False
    )


@dataclass
class UpdateExpression(Node):
    """Update expression."""

    # Allowed operators: ++, --
    operator: str = "++"
    argument: Optional["Expression"] = None
    prefix: bool = True
    type: TypingLiteral["UpdateExpression"] = field(
        default="UpdateExpression", init=False
    )


@dataclass
class BinaryExpression(Node):
    """Binary expression."""

    # Supported operators align with ESTree spec:
    # == != === !== < <= > >= << >> >>> + - * / % | ^ & in instanceof
    operator: str = ""
    left: Optional["Expression"] = None
    right: Optional["Expression"] = None
    type: TypingLiteral["BinaryExpression"] = field(
        default="BinaryExpression", init=False
    )


@dataclass
class AssignmentExpression(Node):
    """Assignment expression."""

    # Supported operators: =, +=, -=, *=, /=, %=, <<=, >>=, >>>=, |=, ^=, &=
    operator: str = "="
    left: Optional[Union["Pattern", "Expression"]] = None
    right: Optional["Expression"] = None
    type: TypingLiteral["AssignmentExpression"] = field(
        default="AssignmentExpression", init=False
    )


@dataclass
class LogicalExpression(Node):
    """Logical expression."""

    # Supported operators: ||, &&, ??
    operator: str = "&&"
    left: Optional["Expression"] = None
    right: Optional["Expression"] = None
    type: TypingLiteral["LogicalExpression"] = field(
        default="LogicalExpression", init=False
    )


@dataclass
class MemberExpression(Node):
    """Member expression."""

    object: Optional[Union["Expression", "Super"]] = None
    property: Optional["Expression"] = None
    computed: bool = False
    optional: bool = False
    type: TypingLiteral["MemberExpression"] = field(
        default="MemberExpression", init=False
    )


@dataclass
class ConditionalExpression(Node):
    """Conditional (ternary) expression."""

    test: Optional["Expression"] = None
    consequent: Optional["Expression"] = None
    alternate: Optional["Expression"] = None
    type: TypingLiteral["ConditionalExpression"] = field(
        default="ConditionalExpression", init=False
    )


@dataclass
class CallExpression(Node):
    """Call expression."""

    callee: Optional[Union["Expression", "Super"]] = None
    arguments: list[Union["Expression", "SpreadElement"]] = field(default_factory=list)
    optional: bool = False
    type: TypingLiteral["CallExpression"] = field(default="CallExpression", init=False)


@dataclass
class ChainExpression(Node):
    """Optional chaining expression (ES2020)."""

    expression: Optional[Union[CallExpression, MemberExpression]] = None
    type: TypingLiteral["ChainExpression"] = field(
        default="ChainExpression", init=False
    )


@dataclass
class NewExpression(Node):
    """New expression."""

    callee: Optional["Expression"] = None
    arguments: list[Union["Expression", "SpreadElement"]] = field(default_factory=list)
    type: TypingLiteral["NewExpression"] = field(default="NewExpression", init=False)


@dataclass
class SequenceExpression(Node):
    """Sequence expression."""

    expressions: list["Expression"] = field(default_factory=list)
    type: TypingLiteral["SequenceExpression"] = field(
        default="SequenceExpression", init=False
    )


@dataclass
class YieldExpression(Node):
    """Yield expression."""

    argument: Optional["Expression"] = None
    delegate: bool = False
    type: TypingLiteral["YieldExpression"] = field(
        default="YieldExpression", init=False
    )


@dataclass
class AwaitExpression(Node):
    """Await expression (ES2017)."""

    argument: Optional["Expression"] = None
    type: TypingLiteral["AwaitExpression"] = field(
        default="AwaitExpression", init=False
    )


@dataclass
class TemplateLiteral(Node):
    """Template literal (ES6)."""

    quasis: list["TemplateElement"] = field(default_factory=list)
    expressions: list["Expression"] = field(default_factory=list)
    type: TypingLiteral["TemplateLiteral"] = field(
        default="TemplateLiteral", init=False
    )


@dataclass
class TemplateElement(Node):
    """Template element."""

    tail: bool = False
    value: dict[str, str] = field(default_factory=dict)  # {cooked: str, raw: str}
    type: TypingLiteral["TemplateElement"] = field(
        default="TemplateElement", init=False
    )


@dataclass
class TaggedTemplateExpression(Node):
    """Tagged template expression (ES6)."""

    tag: Optional["Expression"] = None
    quasi: Optional[TemplateLiteral] = None
    type: TypingLiteral["TaggedTemplateExpression"] = field(
        default="TaggedTemplateExpression", init=False
    )


@dataclass
class SpreadElement(Node):
    """Spread element (ES6)."""

    argument: Optional["Expression"] = None
    type: TypingLiteral["SpreadElement"] = field(default="SpreadElement", init=False)


@dataclass
class Super(Node):
    """Super keyword."""

    type: TypingLiteral["Super"] = field(default="Super", init=False)


@dataclass
class MetaProperty(Node):
    """Meta property (e.g., new.target)."""

    meta: Optional[Identifier] = None
    property: Optional[Identifier] = None
    type: TypingLiteral["MetaProperty"] = field(default="MetaProperty", init=False)


# Patterns (ES6)
# ==============


@dataclass
class AssignmentPattern(Node):
    """Assignment pattern (default parameters)."""

    left: Optional["Pattern"] = None
    right: Optional["Expression"] = None
    type: TypingLiteral["AssignmentPattern"] = field(
        default="AssignmentPattern", init=False
    )


@dataclass
class ArrayPattern(Node):
    """Array destructuring pattern."""

    elements: list[Optional["Pattern"]] = field(default_factory=list)
    type: TypingLiteral["ArrayPattern"] = field(default="ArrayPattern", init=False)


@dataclass
class ObjectPattern(Node):
    """Object destructuring pattern."""

    properties: list[Union["AssignmentProperty", "RestElement"]] = field(
        default_factory=list
    )
    type: TypingLiteral["ObjectPattern"] = field(default="ObjectPattern", init=False)


@dataclass
class AssignmentProperty(Node):
    """Assignment property in object pattern."""

    key: Optional[Union["Expression", Identifier, Literal]] = None
    value: Optional["Pattern"] = None
    kind: PropertyKind = "init"
    method: bool = False
    shorthand: bool = False
    computed: bool = False
    type: TypingLiteral["Property"] = field(default="Property", init=False)


@dataclass
class RestElement(Node):
    """Rest element."""

    argument: Optional["Pattern"] = None
    type: TypingLiteral["RestElement"] = field(default="RestElement", init=False)


# Classes (ES6)
# =============


@dataclass
class ClassDeclaration(Node):
    """Class declaration."""

    id: Optional[Identifier] = None
    superClass: Optional["Expression"] = None  # noqa: N815
    body: Optional["ClassBody"] = None
    type: TypingLiteral["ClassDeclaration"] = field(
        default="ClassDeclaration", init=False
    )


@dataclass
class ClassExpression(Node):
    """Class expression."""

    id: Optional[Identifier] = None
    superClass: Optional["Expression"] = None  # noqa: N815
    body: Optional["ClassBody"] = None
    type: TypingLiteral["ClassExpression"] = field(
        default="ClassExpression", init=False
    )


@dataclass
class ClassBody(Node):
    """Class body (ES2022: supports methods, properties, and static blocks)."""

    body: list[Union["MethodDefinition", "PropertyDefinition", "StaticBlock"]] = field(
        default_factory=list
    )
    type: TypingLiteral["ClassBody"] = field(default="ClassBody", init=False)


@dataclass
class MethodDefinition(Node):
    """Method definition (ES2022: supports private identifiers)."""

    key: Optional[Union["Expression", Identifier, "PrivateIdentifier"]] = None
    value: Optional[FunctionExpression] = None
    kind: MethodDefinitionKind = "method"
    computed: bool = False
    static: bool = False
    type: TypingLiteral["MethodDefinition"] = field(
        default="MethodDefinition", init=False
    )


@dataclass
class PropertyDefinition(Node):
    """Class field definition (ES2022)."""

    key: Optional[Union["Expression", Identifier, "PrivateIdentifier"]] = None
    value: Optional["Expression"] = None
    computed: bool = False
    static: bool = False
    type: TypingLiteral["PropertyDefinition"] = field(
        default="PropertyDefinition", init=False
    )


@dataclass
class StaticBlock(Node):
    """Static initialization block (ES2022)."""

    body: list["Statement"] = field(default_factory=list)
    type: TypingLiteral["StaticBlock"] = field(default="StaticBlock", init=False)


# Modules (ES6)
# =============


@dataclass
class ImportDeclaration(Node):
    """Import declaration."""

    specifiers: list[
        Union["ImportSpecifier", "ImportDefaultSpecifier", "ImportNamespaceSpecifier"]
    ] = field(default_factory=list)
    source: Optional[Literal] = None
    type: TypingLiteral["ImportDeclaration"] = field(
        default="ImportDeclaration", init=False
    )


@dataclass
class ImportExpression(Node):
    """Dynamic import expression (ES2020)."""

    source: Optional["Expression"] = None
    type: TypingLiteral["ImportExpression"] = field(
        default="ImportExpression", init=False
    )


@dataclass
class ImportSpecifier(Node):
    """Import specifier."""

    imported: Optional[Identifier] = None
    local: Optional[Identifier] = None
    type: TypingLiteral["ImportSpecifier"] = field(
        default="ImportSpecifier", init=False
    )


@dataclass
class ImportDefaultSpecifier(Node):
    """Import default specifier."""

    local: Optional[Identifier] = None
    type: TypingLiteral["ImportDefaultSpecifier"] = field(
        default="ImportDefaultSpecifier", init=False
    )


@dataclass
class ImportNamespaceSpecifier(Node):
    """Import namespace specifier."""

    local: Optional[Identifier] = None
    type: TypingLiteral["ImportNamespaceSpecifier"] = field(
        default="ImportNamespaceSpecifier", init=False
    )


@dataclass
class ExportNamedDeclaration(Node):
    """Export named declaration."""

    declaration: Optional[Union["Declaration", "Expression"]] = None
    specifiers: list["ExportSpecifier"] = field(default_factory=list)
    source: Optional[Literal] = None
    type: TypingLiteral["ExportNamedDeclaration"] = field(
        default="ExportNamedDeclaration", init=False
    )


@dataclass
class ExportSpecifier(Node):
    """Export specifier."""

    exported: Optional[Identifier] = None
    local: Optional[Identifier] = None
    type: TypingLiteral["ExportSpecifier"] = field(
        default="ExportSpecifier", init=False
    )


@dataclass
class ExportDefaultDeclaration(Node):
    """Export default declaration."""

    declaration: Optional[Union["Declaration", "Expression"]] = None
    type: TypingLiteral["ExportDefaultDeclaration"] = field(
        default="ExportDefaultDeclaration", init=False
    )


@dataclass
class ExportAllDeclaration(Node):
    """Export all declaration."""

    source: Optional[Literal] = None
    exported: Optional[Identifier] = None
    type: TypingLiteral["ExportAllDeclaration"] = field(
        default="ExportAllDeclaration", init=False
    )


# Type Aliases for Union Types
# ============================

Statement = Union[
    ExpressionStatement,
    BlockStatement,
    EmptyStatement,
    DebuggerStatement,
    WithStatement,
    ReturnStatement,
    LabeledStatement,
    BreakStatement,
    ContinueStatement,
    IfStatement,
    SwitchStatement,
    ThrowStatement,
    TryStatement,
    WhileStatement,
    DoWhileStatement,
    ForStatement,
    ForInStatement,
    ForOfStatement,
    FunctionDeclaration,
    VariableDeclaration,
    ClassDeclaration,
]

Expression = Union[
    Identifier,
    Literal,
    ThisExpression,
    ArrayExpression,
    ObjectExpression,
    FunctionExpression,
    ArrowFunctionExpression,
    UnaryExpression,
    UpdateExpression,
    BinaryExpression,
    AssignmentExpression,
    LogicalExpression,
    MemberExpression,
    ConditionalExpression,
    CallExpression,
    ChainExpression,  # ES2020
    NewExpression,
    SequenceExpression,
    YieldExpression,
    AwaitExpression,
    TemplateLiteral,
    TaggedTemplateExpression,
    ClassExpression,
    ImportExpression,  # ES2020
]

Pattern = Union[
    Identifier,
    ArrayPattern,
    ObjectPattern,
    AssignmentPattern,
    RestElement,
]

Declaration = Union[
    FunctionDeclaration,
    VariableDeclaration,
    ClassDeclaration,
]

ModuleDeclaration = Union[
    ImportDeclaration,
    ExportNamedDeclaration,
    ExportDefaultDeclaration,
    ExportAllDeclaration,
]


# Utility Functions
# =================


def es_node_to_dict(node: Node) -> dict[str, Any]:
    """Convert an ESTree node to a dictionary representation."""
    result: dict[str, Any] = {"type": node.type}

    for key, value in node.__dict__.items():
        if key in ("type", "loc") or value is None:
            continue
        if isinstance(value, Node):
            result[key] = es_node_to_dict(value)
        elif isinstance(value, list):
            result[key] = [
                es_node_to_dict(item) if isinstance(item, Node) else item
                for item in value
            ]
        else:
            result[key] = value

    if node.loc:
        result["loc"] = {
            "source": node.loc.source,
            "start": (
                {"line": node.loc.start.line, "column": node.loc.start.column}
                if node.loc.start
                else None
            ),
            "end": (
                {"line": node.loc.end.line, "column": node.loc.end.column}
                if node.loc.end
                else None
            ),
        }

    return result
