"""
JavaScript / TypeScript AST Node Types for js_engine.

All parser output is expressed as `ASTNode` values discriminated by
`ASTNodeType`.  A single "fat-node" design is used: one `ASTNode` obj
carries every possible field; unused fields stay at their zero/None/[]
defaults.  This is native-compilation friendly (LLVM struct, fixed layout)
and avoids the inheritance limitations of Jac Native.

Factory functions (`make_*`) are the only public API for constructing nodes.
They explicitly pass every list field as `[]` to keep construction uniform
regardless of whether a default is provided.

Bun reference: bun/src/js_ast.zig — Expr/Stmt tagged unions
ECMAScript spec: §13-16  https://tc39.es/ecma262/
"""

# ══════════════════════════════════════════════════════════════════════════════
# 1.  ASTNodeType — discriminant enum
# ══════════════════════════════════════════════════════════════════════════════

"""All AST node kinds produced by the parser."""
enum:pub ASTNodeType {
    # ── Special ────────────────────────────────────────────────────────────
    Invalid = 0,  # null / unset sentinel
    # ── Top-level ──────────────────────────────────────────────────────────
    Program = 1,  # root; body:list, source_type:str
    # ── Statements ─────────────────────────────────────────────────────────
    BlockStatement = 10,  # { body:list }
    ExpressionStatement = 11,  # expression:node
    EmptyStatement = 12,  # ;
    VariableDeclaration = 13,  # kind:str, declarations:list
    VariableDeclarator = 14,  # id:node, init:node?
    FunctionDeclaration = 15,  # id:node?, params:list, body:node, is_async, is_generator
    ReturnStatement = 16,  # argument:node?
    IfStatement = 17,  # test:node, consequent:node, alternate:node?
    WhileStatement = 18,  # test:node, body:node
    DoWhileStatement = 19,  # body:node, test:node
    ForStatement = 20,  # init:node?, test:node?, update:node?, body:node
    ForInStatement = 21,  # left:node, right:node, body:node
    ForOfStatement = 22,  # left:node, right:node, body:node, is_async
    BreakStatement = 23,  # label:str ("")
    ContinueStatement = 24,  # label:str ("")
    ThrowStatement = 25,  # argument:node
    TryStatement = 26,  # body:node(Block), handler:node?(Catch), finalizer:node?(Block)
    CatchClause = 27,  # param:node?, body:node(Block)
    SwitchStatement = 28,  # discriminant:node, cases:list
    SwitchCase = 29,  # test:node?(None=default), consequent:list
    ClassDeclaration = 30,  # id:node?, superclass:node?, body:list(MethodDef)
    LabeledStatement = 31,  # label:str, body:node
    DebuggerStatement = 32,  #
    ImportDeclaration = 33,  # specifiers:list, source:node(Literal)
    ExportNamedDecl = 34,  # specifiers:list, declaration:node?, source:node?
    ExportDefaultDecl = 35,  # declaration:node
    ExportAllDecl = 36,  # source:node(Literal), exported:node?(Identifier)
    ImportSpecifier = 37,  # imported:node, local:node
    ExportSpecifier = 38,  # local:node, exported:node
    WithStatement = 39,  # object:node (expression), body:node
    # ── Expressions ────────────────────────────────────────────────────────
    Identifier = 50,  # name:str
    Literal = 51,  # value:str, raw:str
    TemplateLiteral = 52,  # quasis:list[str], expressions:list
    TemplateElement = 53,  # value:str, tail:bool
    BinaryExpression = 54,  # operator:str, left:node, right:node
    UnaryExpression = 55,  # operator:str, argument:node, prefix:bool
    LogicalExpression = 56,  # operator:str, left:node, right:node
    AssignmentExpression = 57,  # operator:str, left:node, right:node
    UpdateExpression = 58,  # operator:str, argument:node, prefix:bool
    ConditionalExpression = 59,  # test:node, consequent:node, alternate:node
    CallExpression = 60,  # callee:node, arguments:list
    NewExpression = 61,  # callee:node, arguments:list
    MemberExpression = 62,  # object:node, property:node, computed:bool
    OptionalChainExpr = 63,  # object:node, property:node, computed:bool
    SpreadElement = 64,  # argument:node
    ArrayExpression = 65,  # elements:list (None slots = elision)
    ObjectExpression = 66,  # properties:list
    Property = 67,  # key:node, value:node, kind:str, shorthand, computed
    MethodDefinition = 68,  # key:node, value:node(FuncExpr), kind:str, is_static, computed
    FunctionExpression = 69,  # id:node?, params:list, body:node, is_async, is_generator
    ArrowFunctionExpr = 70,  # params:list, body:node, is_async, expression:bool(body=expr)
    ClassExpression = 71,  # id:node?, superclass:node?, body:list
    SequenceExpression = 72,  # expressions:list
    AwaitExpression = 73,  # argument:node
    YieldExpression = 74,  # argument:node?, delegate:bool
    TaggedTemplateExpr = 75,  # tag:node, quasi:node(TemplateLiteral)
    MetaProperty = 76,  # meta:str (e.g. "new"), property:str (e.g. "target")
    AssignmentPattern = 77,  # left:node, right:node  (default param)
    # ── Patterns ───────────────────────────────────────────────────────────
    ObjectPattern = 90,  # properties:list
    ArrayPattern = 91,  # elements:list
    RestElement = 92,  # argument:node
    Elision = 93  # array literal hole (empty slot)
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  SourceRange
# ══════════════════════════════════════════════════════════════════════════════

"""
Byte-offset span + start position of an AST node in the source.

  start / end   — byte offsets (0-based) into the original source string
  line          — 1-based line number of the *first* character
  col           — 1-based column number of the *first* character
"""
obj:pub SourceRange {
    has start: int,
        end: int,
        line: int,
        col: int;
}

"""Construct a SourceRange."""
def:pub make_range(start: int, end: int, line: int, col: int) -> SourceRange {
    return SourceRange(start=start, end=end, line=line, col=col);
}

"""A zero/unknown source range used as a placeholder."""
glob:pub ZERO_RANGE: SourceRange = SourceRange(start=0, end=0, line=0, col=0);

# ══════════════════════════════════════════════════════════════════════════════
# 3.  ASTNode — fat discriminated node
# ══════════════════════════════════════════════════════════════════════════════

"""
Single fat-node representation for all AST node types.

Every possible field for every node kind lives here; unused fields hold their
zero / None / [] defaults.  Use the `make_*` factory functions rather than
constructing `ASTNode` directly — factories always pass list fields explicitly
to prevent the null-pointer crash that occurs when list-defaulted fields are
omitted from a native constructor call.

Field usage by node kind (non-exhaustive quick reference):

  Identifier              name
  Literal                 value, raw
  TemplateLiteral         quasis, expressions
  BinaryExpression        operator, left, right
  UnaryExpression         operator, argument, prefix
  AssignmentExpression    operator, left, right
  UpdateExpression        operator, argument, prefix
  LogicalExpression       operator, left, right
  ConditionalExpression   test, consequent, alternate
  CallExpression          callee, arguments
  NewExpression           callee, arguments
  MemberExpression        object, property, computed
  SpreadElement           argument
  ArrayExpression         elements
  ObjectExpression        properties
  Property                key, value, kind, shorthand, computed
  MethodDefinition        key, value, kind, is_static, computed
  FunctionDeclaration     id, params, body, is_async, is_generator
  FunctionExpression      id, params, body, is_async, is_generator
  ArrowFunctionExpr       params, body, is_async, expression_body
  ClassDeclaration        id, superclass, body
  VariableDeclaration     kind, declarations
  VariableDeclarator      id, init
  Program                 body, value (source_type)
  BlockStatement          body
  ExpressionStatement     expression
  IfStatement             test, consequent, alternate
  WhileStatement / DoWhile test, body
  ForStatement            init, test, update, body
  ForInStatement/OfStatement  left, right, body, is_async
  ReturnStatement         argument
  ThrowStatement          argument
  TryStatement            body, handler, finalizer
  CatchClause             param, body
  SwitchStatement         discriminant, cases
  SwitchCase              test, body (consequent list)
  BreakStatement          name (label)
  ContinueStatement       name (label)
  LabeledStatement        name, body
  ImportDeclaration       specifiers, source
  ExportNamedDecl         specifiers, expression (declaration), source
  ExportDefaultDecl       expression (declaration)
  ExportAllDecl           source, expression (exported name)
  ImportSpecifier         left (imported), right (local)
  ExportSpecifier         left (local), right (exported)
  YieldExpression         argument, prefix (delegate flag)
  AwaitExpression         argument
  TaggedTemplateExpr      tag, quasi
  MetaProperty            name (meta.property string, e.g. "new.target")
  AssignmentPattern       left, right
  RestElement             argument
  ObjectPattern           properties
  ArrayPattern            elements
"""
obj:pub ASTNode {
    has ntype: ASTNodeType,
        loc: SourceRange,
        name: str = "",
        value: str = "",
        raw: str = "",
        operator: str = "",
        kind: str = "",
        computed: bool = False,
        shorthand: bool = False,
        prefix: bool = False,
        is_async: bool = False,
        is_generator: bool = False,
        is_static: bool = False,
        tail: bool = False,
        expression_body: bool = False,
        is_method: bool = False,
        parenthesized: bool = False,
        left: ASTNode | None = None,
        right: ASTNode | None = None,
        argument: ASTNode | None = None,
        callee: ASTNode | None = None,
        object: ASTNode | None = None,
        property: ASTNode | None = None,
        key: ASTNode | None = None,
        cond_expr: ASTNode | None = None,
        consequent: ASTNode | None = None,
        alternate: ASTNode | None = None,
        update: ASTNode | None = None,
        init: ASTNode | None = None,
        id: ASTNode | None = None,
        body: ASTNode | None = None,
        handler: ASTNode | None = None,
        finalizer: ASTNode | None = None,
        param: ASTNode | None = None,
        discriminant: ASTNode | None = None,
        superclass: ASTNode | None = None,
        tag: ASTNode | None = None,
        quasi: ASTNode | None = None,
        source: ASTNode | None = None,
        expression: ASTNode | None = None,
        children: list[ASTNode] = [],
        params: list[ASTNode] = [],
        arguments: list[ASTNode] = [],
        declarations: list[ASTNode] = [],
        properties: list[ASTNode] = [],
        elements: list[ASTNode] = [],
        cases: list[ASTNode] = [],
        expressions: list[ASTNode] = [],
        specifiers: list[ASTNode] = [],
        quasis: list[str] = [];
}

# ── string / name data ─────────────────────────────────────────────────
# Identifier.name, label, MetaProperty string
# Literal.value, Property.kind, VarDecl.kind,
#   Program.source_type, TemplateElement.value
# Literal.raw
# Binary/Unary/Logical/Assignment/Update.operator
# Property.kind ("init"|"get"|"set"), MethodDef.kind

# ── bool flags ─────────────────────────────────────────────────────────
# MemberExpr/Property/MethodDef
# Property
# UnaryExpr/UpdateExpr prefix? | YieldExpr delegate
# Function/Arrow/ForOf
# FunctionDecl/Expr
# MethodDefinition
# TemplateElement.tail
# ArrowFunctionExpr (body is expr, not block)
# FunctionExpression that is a concise method/accessor (no own `prototype`)
# node was wrapped in a CoverParenthesizedExpression `( … )`

# ── single child nodes ─────────────────────────────────────────────────
# Binary/Logical/Assignment/ForIn/ForOf
# Binary/Logical/Assignment/ForIn/ForOf
# Unary/Return/Throw/Spread/Rest/Await/Yield
# Call/New callee
# MemberExpr.object
# MemberExpr.property
# Property/MethodDef key
# If/While/For/Switch/Condition
# If/Conditional consequent
# If/Conditional alternate
# ForStatement.update
# VarDeclarator.init, ForStatement.init
# FunctionDecl/ClassDecl/VarDeclarator.id
# Function/Class/Try/Catch body (single node)
# TryStatement.handler (CatchClause)
# TryStatement.finalizer (BlockStatement)
# CatchClause.param
# SwitchStatement.discriminant
# ClassDecl/Expr.superClass
# TaggedTemplateExpr.tag
# TaggedTemplateExpr.quasi
# Import/Export .source (Literal)
# ExpressionStatement.expression
#   Export default/named declaration

# ── list children ──────────────────────────────────────────────────────
# Program/Block body; SwitchCase consequent
# Function/Arrow params
# Call/NewExpression
# VariableDeclaration
# ObjectExpr/ObjectPattern
# ArrayExpr/ArrayPattern
# SwitchStatement
# SequenceExpr / TemplateLiteral interps
# Import/Export specifiers
# TemplateLiteral cooked text parts
# ══════════════════════════════════════════════════════════════════════════════
# 4.  Internal base constructor
# ══════════════════════════════════════════════════════════════════════════════

# Shared empty-list singletons — reused as the initial value for every unused
# list field in ASTNode.  Factory functions immediately replace the field they
# own (e.g. `n.children = body`), so the singleton is never mutated.
# Using singletons avoids allocating 10 fresh `[]` per node (saves ~640 bytes
# of RC-header overhead per node × ~6 nodes per statement).
glob _EMPTY_NODES: list[ASTNode] = [],
     _EMPTY_STRS: list[str] = [];

"""
Internal: create an ASTNode with a given type and location, all list/optional
fields explicitly set to empty/None to avoid null-pointer crashes.
"""
def _node(ntype: ASTNodeType, loc: SourceRange) -> ASTNode {
    return ASTNode(
        ntype=ntype,
        loc=loc,
        name="",
        value="",
        raw="",
        operator="",
        kind="",
        computed=False,
        shorthand=False,
        prefix=False,
        is_async=False,
        is_generator=False,
        is_static=False,
        tail=False,
        expression_body=False,
        parenthesized=False,
        left=None,
        right=None,
        argument=None,
        callee=None,
        object=None,
        property=None,
        key=None,
        cond_expr=None,
        consequent=None,
        alternate=None,
        update=None,
        init=None,
        id=None,
        body=None,
        handler=None,
        finalizer=None,
        param=None,
        discriminant=None,
        superclass=None,
        tag=None,
        quasi=None,
        source=None,
        expression=None,
        children=_EMPTY_NODES,
        params=_EMPTY_NODES,
        arguments=_EMPTY_NODES,
        declarations=_EMPTY_NODES,
        properties=_EMPTY_NODES,
        elements=_EMPTY_NODES,
        cases=_EMPTY_NODES,
        expressions=_EMPTY_NODES,
        specifiers=_EMPTY_NODES,
        quasis=_EMPTY_STRS
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Factory functions
# ══════════════════════════════════════════════════════════════════════════════

# ── Top-level ─────────────────────────────────────────────────────────────────

"""Create a Program node (script or module root)."""
def:pub make_program(
    body: list[ASTNode], loc: SourceRange, source_type: str = "script"
) -> ASTNode {
    n = _node(ASTNodeType.Program, loc);
    n.children = body;
    n.value = source_type;
    return n;
}

# ── Statements ────────────────────────────────────────────────────────────────

"""Create a BlockStatement: `{ ... }`."""
def:pub make_block(body: list[ASTNode], loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.BlockStatement, loc);
    n.children = body;
    return n;
}

"""Create an ExpressionStatement: `expr;`."""
def:pub make_expr_stmt(expr: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ExpressionStatement, loc);
    n.expression = expr;
    return n;
}

"""Create an EmptyStatement: `;`."""
def:pub make_empty_stmt(loc: SourceRange) -> ASTNode {
    return _node(ASTNodeType.EmptyStatement, loc);
}

"""Create a VariableDeclaration: `var/let/const id = init, ...`."""
def:pub make_var_decl(
    kind: str, declarations: list[ASTNode], loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.VariableDeclaration, loc);
    n.value = kind;
    n.declarations = declarations;
    return n;
}

"""Create a VariableDeclarator: `id = init`."""
def:pub make_var_declarator(
    id: ASTNode, initialization: ASTNode | None, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.VariableDeclarator, loc);
    n.id = id;
    n.init = initialization;
    return n;
}

"""Create a FunctionDeclaration."""
def:pub make_function_decl(
    id: ASTNode | None,
    params: list[ASTNode],
    body: ASTNode,
    loc: SourceRange,
    is_async: bool = False,
    is_generator: bool = False
) -> ASTNode {
    n = _node(ASTNodeType.FunctionDeclaration, loc);
    n.id = id;
    n.params = params;
    n.body = body;
    n.is_async = is_async;
    n.is_generator = is_generator;
    return n;
}

"""Create a ReturnStatement."""
def:pub make_return(argument: ASTNode | None, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ReturnStatement, loc);
    n.argument = argument;
    return n;
}

"""Create an IfStatement."""
def:pub make_if(
    cond: ASTNode, consequent: ASTNode, alternate: ASTNode | None, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.IfStatement, loc);
    n.cond_expr = cond;
    n.consequent = consequent;
    n.alternate = alternate;
    return n;
}

"""Create a WhileStatement."""
def:pub make_while(cond: ASTNode, body: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.WhileStatement, loc);
    n.cond_expr = cond;
    n.body = body;
    return n;
}

"""Create a WithStatement: `with (object) body`.  The object expression is
stored in `.expression`; the body statement in `.body`."""
def:pub make_with(object: ASTNode, body: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.WithStatement, loc);
    n.expression = object;
    n.body = body;
    return n;
}

"""Create a DoWhileStatement."""
def:pub make_do_while(body: ASTNode, cond: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.DoWhileStatement, loc);
    n.body = body;
    n.cond_expr = cond;
    return n;
}

"""Create a ForStatement: `for (init; test; update) body`."""
def:pub make_for(
    initialization: ASTNode | None,
    cond: ASTNode | None,
    update: ASTNode | None,
    body: ASTNode,
    loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ForStatement, loc);
    n.init = initialization;
    n.cond_expr = cond;
    n.update = update;
    n.body = body;
    return n;
}

"""Create a ForInStatement: `for (left in right) body`."""
def:pub make_for_in(
    left: ASTNode, right: ASTNode, body: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ForInStatement, loc);
    n.left = left;
    n.right = right;
    n.body = body;
    return n;
}

"""Create a ForOfStatement: `for [await] (left of right) body`."""
def:pub make_for_of(
    left: ASTNode,
    right: ASTNode,
    body: ASTNode,
    loc: SourceRange,
    is_async: bool = False
) -> ASTNode {
    n = _node(ASTNodeType.ForOfStatement, loc);
    n.left = left;
    n.right = right;
    n.body = body;
    n.is_async = is_async;
    return n;
}

"""Create a BreakStatement (label="" means unlabelled)."""
def:pub make_break(label: str, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.BreakStatement, loc);
    n.name = label;
    return n;
}

"""Create a ContinueStatement (label="" means unlabelled)."""
def:pub make_continue(label: str, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ContinueStatement, loc);
    n.name = label;
    return n;
}

"""Create a ThrowStatement."""
def:pub make_throw(argument: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ThrowStatement, loc);
    n.argument = argument;
    return n;
}

"""Create a TryStatement."""
def:pub make_try(
    body: ASTNode, handler: ASTNode | None, finalizer: ASTNode | None, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.TryStatement, loc);
    n.body = body;
    n.handler = handler;
    n.finalizer = finalizer;
    return n;
}

"""Create a CatchClause: `catch (param) body`."""
def:pub make_catch(param: ASTNode | None, body: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.CatchClause, loc);
    n.param = param;
    n.body = body;
    return n;
}

"""Create a SwitchStatement."""
def:pub make_switch(
    discriminant: ASTNode, cases: list[ASTNode], loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.SwitchStatement, loc);
    n.discriminant = discriminant;
    n.cases = cases;
    return n;
}

"""Create a SwitchCase (test=None means `default:`)."""
def:pub make_switch_case(
    cond: ASTNode | None, consequent: list[ASTNode], loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.SwitchCase, loc);
    n.cond_expr = cond;
    n.children = consequent;
    return n;
}

"""Create a ClassDeclaration."""
def:pub make_class_decl(
    id: ASTNode | None,
    superclass: ASTNode | None,
    body: list[ASTNode],
    loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ClassDeclaration, loc);
    n.id = id;
    n.superclass = superclass;
    n.children = body;
    return n;
}

"""Create a LabeledStatement."""
def:pub make_labeled(label: str, body: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.LabeledStatement, loc);
    n.name = label;
    n.body = body;
    return n;
}

"""Create a DebuggerStatement."""
def:pub make_debugger(loc: SourceRange) -> ASTNode {
    return _node(ASTNodeType.DebuggerStatement, loc);
}

"""Create an ImportDeclaration."""
def:pub make_import(
    specifiers: list[ASTNode], source: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ImportDeclaration, loc);
    n.specifiers = specifiers;
    n.source = source;
    return n;
}

"""Create an ExportNamedDeclaration."""
def:pub make_export_named(
    specifiers: list[ASTNode],
    declaration: ASTNode | None,
    source: ASTNode | None,
    loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ExportNamedDecl, loc);
    n.specifiers = specifiers;
    n.expression = declaration;
    n.source = source;
    return n;
}

"""Create an ExportDefaultDeclaration."""
def:pub make_export_default(declaration: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ExportDefaultDecl, loc);
    n.expression = declaration;
    return n;
}

"""Create an ExportAllDeclaration: `export * [as name] from "mod"`."""
def:pub make_export_all(
    source: ASTNode, exported: ASTNode | None, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ExportAllDecl, loc);
    n.source = source;
    n.expression = exported;
    return n;
}

"""Create an ImportSpecifier: `{ imported as local }`."""
def:pub make_import_specifier(
    imported: ASTNode, local: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ImportSpecifier, loc);
    n.left = imported;
    n.right = local;
    return n;
}

"""Create an ExportSpecifier: `{ local as exported }`."""
def:pub make_export_specifier(
    local: ASTNode, exported: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ExportSpecifier, loc);
    n.left = local;
    n.right = exported;
    return n;
}

# ── Expressions ───────────────────────────────────────────────────────────────

"""Create an Identifier node."""
def:pub make_identifier(name: str, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.Identifier, loc);
    n.name = name;
    return n;
}

"""Create a Literal node (string/number/bool/null/regexp/bigint)."""
def:pub make_literal(value: str, raw: str, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.Literal, loc);
    n.value = value;
    n.raw = raw;
    return n;
}

"""Create a TemplateLiteral node."""
def:pub make_template_literal(
    quasis: list[str], expressions: list[ASTNode], loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.TemplateLiteral, loc);
    n.quasis = quasis;
    n.expressions = expressions;
    return n;
}

"""Create a TemplateElement (one cooked text segment)."""
def:pub make_template_element(value: str, tail: bool, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.TemplateElement, loc);
    n.value = value;
    n.tail = tail;
    return n;
}

"""Create a BinaryExpression: `left op right`."""
def:pub make_binary(
    operator: str, left: ASTNode, right: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.BinaryExpression, loc);
    n.operator = operator;
    n.left = left;
    n.right = right;
    return n;
}

"""Create a UnaryExpression: `op argument`."""
def:pub make_unary(
    operator: str, argument: ASTNode, prefix: bool, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.UnaryExpression, loc);
    n.operator = operator;
    n.argument = argument;
    n.prefix = prefix;
    return n;
}

"""Create a LogicalExpression: `left && right`, `left || right`, `left ?? right`."""
def:pub make_logical(
    operator: str, left: ASTNode, right: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.LogicalExpression, loc);
    n.operator = operator;
    n.left = left;
    n.right = right;
    return n;
}

"""Create an AssignmentExpression: `left op= right`."""
def:pub make_assignment(
    operator: str, left: ASTNode, right: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.AssignmentExpression, loc);
    n.operator = operator;
    n.left = left;
    n.right = right;
    return n;
}

"""Create an UpdateExpression: `++x`, `x--`, etc."""
def:pub make_update(
    operator: str, argument: ASTNode, prefix: bool, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.UpdateExpression, loc);
    n.operator = operator;
    n.argument = argument;
    n.prefix = prefix;
    return n;
}

"""Create a ConditionalExpression: `cond ? consequent : alternate`."""
def:pub make_conditional(
    cond: ASTNode, consequent: ASTNode, alternate: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ConditionalExpression, loc);
    n.cond_expr = cond;
    n.consequent = consequent;
    n.alternate = alternate;
    return n;
}

"""Create a CallExpression: `callee(args)`."""
def:pub make_call(
    callee: ASTNode, arguments: list[ASTNode], loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.CallExpression, loc);
    n.callee = callee;
    n.arguments = arguments;
    return n;
}

"""Create a NewExpression: `new callee(args)`."""
def:pub make_new(
    callee: ASTNode, arguments: list[ASTNode], loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.NewExpression, loc);
    n.callee = callee;
    n.arguments = arguments;
    return n;
}

"""Create a MemberExpression: `obj.prop` or `obj[prop]`."""
def:pub make_member(
    object: ASTNode, property: ASTNode, computed: bool, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.MemberExpression, loc);
    n.object = object;
    n.property = property;
    n.computed = computed;
    return n;
}

"""Create an OptionalChainExpression: `obj?.prop`."""
def:pub make_optional_chain(
    object: ASTNode, property: ASTNode, computed: bool, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.OptionalChainExpr, loc);
    n.object = object;
    n.property = property;
    n.computed = computed;
    return n;
}

"""Create a SpreadElement: `...arg`."""
def:pub make_spread(argument: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.SpreadElement, loc);
    n.argument = argument;
    return n;
}

"""Create an ArrayExpression: `[a, b, c]`."""
def:pub make_array(elements: list[ASTNode], loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ArrayExpression, loc);
    n.elements = elements;
    return n;
}

"""Create an Elision node for an array literal hole: `[a, , b]`."""
def:pub make_elision(loc: SourceRange) -> ASTNode {
    return _node(ASTNodeType.Elision, loc);
}

"""Create an ObjectExpression: `{ a: 1, b: 2 }`."""
def:pub make_object(properties: list[ASTNode], loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ObjectExpression, loc);
    n.properties = properties;
    return n;
}

"""Create a Property node: `key: value`."""
def:pub make_property(
    key: ASTNode,
    value: ASTNode,
    kind: str,
    shorthand: bool,
    computed: bool,
    loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.Property, loc);
    n.key = key;
    n.expression = value;  # value stored in expression field
    n.kind = kind;
    n.shorthand = shorthand;
    n.computed = computed;
    return n;
}

"""Create a MethodDefinition (class body method)."""
def:pub make_method_def(
    key: ASTNode,
    value: ASTNode,
    kind: str,
    is_static: bool,
    computed: bool,
    loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.MethodDefinition, loc);
    n.key = key;
    n.expression = value;
    n.kind = kind;
    n.is_static = is_static;
    n.computed = computed;
    return n;
}

"""Create a FunctionExpression."""
def:pub make_function_expr(
    id: ASTNode | None,
    params: list[ASTNode],
    body: ASTNode,
    loc: SourceRange,
    is_async: bool = False,
    is_generator: bool = False
) -> ASTNode {
    n = _node(ASTNodeType.FunctionExpression, loc);
    n.id = id;
    n.params = params;
    n.body = body;
    n.is_async = is_async;
    n.is_generator = is_generator;
    return n;
}

"""Create an ArrowFunctionExpression."""
def:pub make_arrow(
    params: list[ASTNode],
    body: ASTNode,
    loc: SourceRange,
    is_async: bool = False,
    expression_body: bool = False
) -> ASTNode {
    n = _node(ASTNodeType.ArrowFunctionExpr, loc);
    n.params = params;
    n.body = body;
    n.is_async = is_async;
    n.expression_body = expression_body;
    return n;
}

"""Create a ClassExpression."""
def:pub make_class_expr(
    id: ASTNode | None,
    superclass: ASTNode | None,
    body: list[ASTNode],
    loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.ClassExpression, loc);
    n.id = id;
    n.superclass = superclass;
    n.children = body;
    return n;
}

"""Create a SequenceExpression: `a, b, c`."""
def:pub make_sequence(expressions: list[ASTNode], loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.SequenceExpression, loc);
    n.expressions = expressions;
    return n;
}

"""Create an AwaitExpression: `await arg`."""
def:pub make_await(argument: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.AwaitExpression, loc);
    n.argument = argument;
    return n;
}

"""Create a YieldExpression: `yield [*] [arg]`."""
def:pub make_yield(
    argument: ASTNode | None, delegate: bool, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.YieldExpression, loc);
    n.argument = argument;
    n.prefix = delegate;  # reuse prefix flag for delegate (yield*)
    return n;
}

"""Create a TaggedTemplateExpression: tag followed by a template literal."""
def:pub make_tagged_template(
    tag: ASTNode, quasi: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.TaggedTemplateExpr, loc);
    n.tag = tag;
    n.quasi = quasi;
    return n;
}

"""Create a MetaProperty: `new.target`, `import.meta`."""
def:pub make_meta_property(meta: str, prop: str, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.MetaProperty, loc);
    n.name = meta + "." + prop;
    return n;
}

"""Create an AssignmentPattern: `left = right` (default param/destructure)."""
def:pub make_assignment_pattern(
    left: ASTNode, right: ASTNode, loc: SourceRange
) -> ASTNode {
    n = _node(ASTNodeType.AssignmentPattern, loc);
    n.left = left;
    n.right = right;
    return n;
}

# ── Patterns ──────────────────────────────────────────────────────────────────

"""Create an ObjectPattern: `{ a, b: c, ...rest }`."""
def:pub make_object_pattern(properties: list[ASTNode], loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ObjectPattern, loc);
    n.properties = properties;
    return n;
}

"""Create an ArrayPattern: `[a, b, ...rest]`."""
def:pub make_array_pattern(elements: list[ASTNode], loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.ArrayPattern, loc);
    n.elements = elements;
    return n;
}

"""Create a RestElement: `...arg`."""
def:pub make_rest(argument: ASTNode, loc: SourceRange) -> ASTNode {
    n = _node(ASTNodeType.RestElement, loc);
    n.argument = argument;
    return n;
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Utility
# ══════════════════════════════════════════════════════════════════════════════

"""Return true if node is the invalid/null sentinel."""
def:pub is_null_node(n: ASTNode | None) -> bool {
    if n is None {
        return True;
    }
    return n.ntype == ASTNodeType.Invalid;
}

"""Return a short human-readable label for a node (for debugging)."""
def:pub node_label(n: ASTNode) -> str {
    t = n.ntype;
    if t == ASTNodeType.Identifier {
        return "Identifier(" + n.name + ")";
    }
    if t == ASTNodeType.Literal {
        return "Literal(" + n.raw + ")";
    }
    if t == ASTNodeType.BinaryExpression {
        return "BinaryExpr(" + n.operator + ")";
    }
    if t == ASTNodeType.UnaryExpression {
        return "UnaryExpr(" + n.operator + ")";
    }
    if t == ASTNodeType.LogicalExpression {
        return "LogicalExpr(" + n.operator + ")";
    }
    if t == ASTNodeType.AssignmentExpression {
        return "AssignExpr(" + n.operator + ")";
    }
    if t == ASTNodeType.UpdateExpression {
        return "UpdateExpr(" + n.operator + ")";
    }
    if t == ASTNodeType.CallExpression {
        return "CallExpr";
    }
    if t == ASTNodeType.MemberExpression {
        return "MemberExpr";
    }
    if t == ASTNodeType.VariableDeclaration {
        return "VarDecl(" + n.value + ")";
    }
    if t == ASTNodeType.FunctionDeclaration {
        return "FunctionDecl";
    }
    if t == ASTNodeType.Program {
        return "Program(" + n.value + ")";
    }
    if t == ASTNodeType.BlockStatement {
        return "BlockStatement";
    }
    if t == ASTNodeType.ReturnStatement {
        return "ReturnStatement";
    }
    if t == ASTNodeType.IfStatement {
        return "IfStatement";
    }
    return "ASTNode";
}
