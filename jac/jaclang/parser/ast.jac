"""AST node definitions for Jac.

This module defines all AST node types used by the parser. The type structure
encodes the grammar:
- Field types = referenced grammar rules
- Required fields = required grammar elements
- Optional fields (T | None) = optional grammar elements (?)
- List fields (list[T]) = zero-or-more repetition (*)

No runtime reflection is needed - the grammar can be derived from type
definitions at build time.
"""

import from .tokens { Token, TokenKind, SourceLoc }
import from typing { TypeAlias }

# =============================================================================
# Base AST Node
# =============================================================================
obj AstNode {
    has loc: SourceLoc = SourceLoc();

    def span_from(start: AstNode) {
        self.loc = start.loc.span_to(self.loc);
    }
}

# =============================================================================
# Expression Base and Types
# =============================================================================
obj Expr(AstNode) {}

obj Stmt(AstNode) {}

obj CodeBlockStmt(Stmt) {}

obj ElementStmt(Stmt) {}

obj ArchBlockStmt(Stmt) {}

# =============================================================================
# Literal Expressions
# =============================================================================
obj IntLiteral(Expr) {
    has token: Token,
        value: int = 0;
}

obj FloatLiteral(Expr) {
    has token: Token,
        value: float = 0.0;
}

obj StringLiteral(Expr) {
    has token: Token,
        value: str = "";
}

obj MultiString(Expr) {
    has parts: list[Expr] = [];  # StringLiteral or FString elements
}

obj BoolLiteral(Expr) {
    has token: Token,
        value: bool = False;
}

obj NullLiteral(Expr) {
    has token: Token;
}

obj EllipsisLiteral(Expr) {
    has token: Token;
}

# =============================================================================
# Name and Identifier Expressions
# =============================================================================
obj NameExpr(Expr) {
    has name: Token;
}

obj TypeRef(Expr) {
    has type_op: Token,
        target: Expr;
}

# =============================================================================
# Compound Literal Expressions
# =============================================================================
obj ListExpr(Expr) {
    has elements: list[Expr] = [];
}

obj TupleExpr(Expr) {
    has elements: list[Expr] = [];
}

obj SetExpr(Expr) {
    has elements: list[Expr] = [];
}

obj DictExpr(Expr) {
    has entries: list[DictEntry] = [];
}

obj DictEntry(AstNode) {
    has key: Expr,
        value: Expr;
}

# =============================================================================
# Comprehension Expressions
# =============================================================================
obj ListCompr(Expr) {
    has element: Expr,
        generators: list[ComprGenerator] = [];
}

obj SetCompr(Expr) {
    has element: Expr,
        generators: list[ComprGenerator] = [];
}

obj DictCompr(Expr) {
    has key: Expr,
        value: Expr,
        generators: list[ComprGenerator] = [];
}

obj GeneratorExpr(Expr) {
    has element: Expr,
        generators: list[ComprGenerator] = [];
}

obj ComprGenerator(AstNode) {
    has target: Expr,
        iter: Expr,
        conditions: list[Expr] = [],
        is_async: bool = False;
}

# =============================================================================
# Operator Expressions
# =============================================================================
obj BinaryExpr(Expr) {
    has left: Expr,
        op: Token,
        right: Expr;
}

obj UnaryExpr(Expr) {
    has op: Token,
        operand: Expr;
}

obj CompareExpr(Expr) {
    has first: Expr,
        comparisons: list[Comparison] = [];
}

obj Comparison(AstNode) {
    has op: Token,
        right: Expr;
}

obj IfElseExpr(Expr) {
    has value: Expr,
        condition: Expr,
        else_value: Expr;
}

obj WalrusExpr(Expr) {
    has target: NameExpr,
        value: Expr;
}

# =============================================================================
# Call and Access Expressions
# =============================================================================
obj FuncCall(Expr) {
    has target: Expr,
        args: list[Expr] = [],
        kwargs: list[KeywordArg] = [];
}

obj KeywordArg(AstNode) {
    has name: Token,
        value: Expr;
}

obj AttrAccess(Expr) {
    has target: Expr,
        attr: Token,
        null_ok: bool = False;
}

obj IndexExpr(Expr) {
    has target: Expr,
        index: Expr;
}

obj SliceExpr(Expr) {
    has target: Expr,
        start: Expr | None = None,
        stop: Expr | None = None,
        step: Expr | None = None;
}

# =============================================================================
# Lambda and Special Expressions
# =============================================================================
obj LambdaExpr(Expr) {
    has body: Expr,
        params: list[ParamVar] = [];
}

obj SpawnExpr(Expr) {
    has target: Expr,
        location: Expr | None = None;
}

obj AwaitExpr(Expr) {
    has target: Expr;
}

obj YieldExpr(Expr) {
    has value: Expr | None = None,
        is_from: bool = False;
}

# =============================================================================
# Pipe Expressions
# =============================================================================
obj PipeExpr(Expr) {
    has left: Expr,
        op: Token,
        right: Expr;
}

obj AtomicPipeExpr(Expr) {
    has left: Expr,
        op: Token,
        right: Expr;
}

obj ByExpr(Expr) {
    has target: Expr,
        by_clause: Expr;
}

obj ConcurrentExpr(Expr) {
    has kind: Token,
        target: Expr;
}

obj UnpackExpr(Expr) {
    has target: Expr;
}

obj RefExpr(Expr) {
    has target: Expr;
}

# =============================================================================
# Graph Expressions (Jac-specific)
# =============================================================================
obj EdgeExpr(Expr) {
    has source: Expr,
        direction: Token,
        target: Expr | None = None,
        filter_type: Expr | None = None;
}

obj ConnectExpr(Expr) {
    has source: Expr,
        direction: Token,
        target: Expr,
        edge: Expr | None = None;
}

obj DisconnectExpr(Expr) {
    has source: Expr,
        direction: Token,
        target: Expr;
}

obj EdgeRefChain(Expr) {
    has base: Expr | None = None,
        is_async: bool = False,
        arch_kind: Token | None = None,
        operations: list[EdgeOp] = [];
}

obj EdgeOp(AstNode) {
    has direction: Token,
        filter_type: Expr | None = None,
        filter_expr: Expr | None = None;
}

obj FilterCompr(Expr) {
    has is_typed: bool = False,
        type_filter: Expr | None = None,
        null_ok: bool = False,
        filters: list[FilterItem] = [];
}

obj FilterItem(AstNode) {
    has name: Token,
        op: Token,
        value: Expr;
}

obj AssignCompr(Expr) {
    has assignments: list[KeywordArg] = [];
}

# =============================================================================
# F-String Expressions
# =============================================================================
obj FString(Expr) {
    has parts: list[FStringPart] = [];
}

obj FStringPart(AstNode) {}

obj FStringText(FStringPart) {
    has text: str;
}

obj FStringExpr(FStringPart) {
    has expr: Expr,
        conversion: str | None = None,
        format_spec: str | None = None;
}

# =============================================================================
# JSX Expressions
# =============================================================================
obj JsxElement(Expr) {
    has tag: Token,
        attrs: list[JsxAttr] = [],
        children: list[JsxChild] = [],
        is_self_closing: bool = False;
}

obj JsxAttr(AstNode) {
    has name: Token,
        value: Expr | None = None;
}

obj JsxChild(AstNode) {}

obj JsxChildExpr(JsxChild) {
    has expr: Expr;
}

obj JsxChildText(JsxChild) {
    has text: str;
}

obj JsxFragment(Expr) {
    has children: list[JsxChild] = [];
}

# =============================================================================
# Statement Nodes
# =============================================================================
obj ExprStmt(CodeBlockStmt) {
    has expr: Expr;
}

obj Assignment(CodeBlockStmt) {
    has targets: list[Expr] = [],
        type_tag: Expr | None = None,
        value: Expr | None = None,
        aug_op: Token | None = None;
}

obj IfStmt(CodeBlockStmt) {
    has condition: Expr,
        body: list[CodeBlockStmt] = [],
        else_body: ElseClause | None = None;
}

glob ElseClause: TypeAlias = ElseIf | ElseStmt;

obj ElseIf(CodeBlockStmt) {
    has condition: Expr,
        body: list[CodeBlockStmt] = [],
        else_body: ElseClause | None = None;
}

obj ElseStmt(CodeBlockStmt) {
    has body: list[CodeBlockStmt] = [];
}

obj WhileStmt(CodeBlockStmt) {
    has condition: Expr,
        body: list[CodeBlockStmt] = [],
        else_body: list[CodeBlockStmt] = [];
}

obj ForStmt(CodeBlockStmt) {
    has target: Expr,
        iter: Expr,
        body: list[CodeBlockStmt] = [],
        else_body: list[CodeBlockStmt] = [],
        is_async: bool = False;
}

obj RangeForStmt(CodeBlockStmt) {
    has target: NameExpr,
        start: Expr,
        end: Expr,
        step: Expr | None = None,
        body: list[CodeBlockStmt] = [],
        else_body: list[CodeBlockStmt] = [];
}

obj TryStmt(CodeBlockStmt) {
    has body: list[CodeBlockStmt] = [],
        handlers: list[ExceptHandler] = [],
        else_body: list[CodeBlockStmt] = [],
        finally_body: list[CodeBlockStmt] = [];
}

obj ExceptHandler(AstNode) {
    has exc_type: Expr | None = None,
        name: Token | None = None,
        body: list[CodeBlockStmt] = [];
}

obj WithStmt(CodeBlockStmt) {
    has items: list[WithItem] = [],
        body: list[CodeBlockStmt] = [];
}

obj WithItem(AstNode) {
    has context: Expr,
        name: Token | None = None;
}

obj MatchStmt(CodeBlockStmt) {
    has target: Expr,
        cases: list[MatchCase] = [];
}

obj MatchCase(AstNode) {
    has pattern: MatchPattern,
        guard: Expr | None = None,
        body: list[CodeBlockStmt] = [];
}

obj MatchPattern(AstNode) {}

obj LiteralPattern(MatchPattern) {
    has value: Expr;
}

obj CapturePattern(MatchPattern) {
    has name: Token;
}

obj WildcardPattern(MatchPattern) {}

obj SequencePattern(MatchPattern) {
    has elements: list[MatchPattern] = [];
}

obj MappingPattern(MatchPattern) {
    has entries: list[MappingPatternEntry] = [],
        rest_name: Token | None = None;
}

obj MappingPatternEntry(AstNode) {
    has key: Expr,
        pattern: MatchPattern;
}

obj StarPattern(MatchPattern) {
    has name: Token;
}

obj SingletonPattern(MatchPattern) {
    has value: Expr;
}

obj AttrPattern(MatchPattern) {
    has names: list[Token] = [];
}

obj ClassPattern(MatchPattern) {
    has cls: Expr,
        args: list[MatchPattern] = [],
        kwargs: list[KeywordPattern] = [];
}

obj KeywordPattern(AstNode) {
    has name: Token,
        pattern: MatchPattern;
}

obj OrPattern(MatchPattern) {
    has patterns: list[MatchPattern] = [];
}

obj AsPattern(MatchPattern) {
    has pattern: MatchPattern,
        name: Token;
}

# =============================================================================
# Switch Statement
# =============================================================================
obj SwitchStmt(CodeBlockStmt) {
    has target: Expr,
        cases: list[SwitchCase] = [];
}

obj SwitchCase(AstNode) {
    has patterns: list[MatchPattern] = [],
        is_default: bool = False,
        body: list[CodeBlockStmt] = [];
}

# =============================================================================
# Jump Statements
# =============================================================================
obj ReturnStmt(CodeBlockStmt) {
    has value: Expr | None = None;
}

obj YieldStmt(CodeBlockStmt) {
    has value: Expr | None = None,
        is_from: bool = False;
}

obj BreakStmt(CodeBlockStmt) {}

obj ContinueStmt(CodeBlockStmt) {}

obj RaiseStmt(CodeBlockStmt) {
    has exc: Expr | None = None,
        cause: Expr | None = None;
}

obj AssertStmt(CodeBlockStmt) {
    has condition: Expr,
        message: Expr | None = None;
}

obj DeleteStmt(CodeBlockStmt) {
    has target: Expr;
}

obj PassStmt(CodeBlockStmt) {}

# =============================================================================
# Walker/Graph Statements
# =============================================================================
obj VisitStmt(CodeBlockStmt) {
    has target: Expr,
        filter: Expr | None = None,
        else_body: list[CodeBlockStmt] = [];
}

obj DisengageStmt(CodeBlockStmt) {}

obj ReportStmt(CodeBlockStmt) {
    has value: Expr;
}

# =============================================================================
# Declaration Nodes
# =============================================================================
obj GlobalStmt(CodeBlockStmt) {
    has names: list[Token] = [];
}

obj NonLocalStmt(CodeBlockStmt) {
    has names: list[Token] = [];
}

obj TypedContextBlock(CodeBlockStmt) {
    has type_expr: Expr,
        body: list[CodeBlockStmt] = [];
}

# =============================================================================
# Type Annotations
# =============================================================================
obj TypeExpr(Expr) {}

obj SimpleType(TypeExpr) {
    has name: Expr;
}

obj GenericType(TypeExpr) {
    has base: Expr,
        args: list[TypeExpr] = [];
}

obj UnionType(TypeExpr) {
    has types: list[TypeExpr] = [];
}

obj OptionalType(TypeExpr) {
    has inner: TypeExpr;
}

# =============================================================================
# Parameter and Signature
# =============================================================================
obj ParamVar(AstNode) {
    has name: Token,
        type_tag: Expr | None = None,
        default: Expr | None = None,
        is_star: bool = False,
        is_kwargs: bool = False;
}

obj FuncSignature(AstNode) {
    has params: list[ParamVar] = [],
        return_type: Expr | None = None;
}

obj EventSignature(AstNode) {
    has event_type: Token,
        arch_tag: Expr | None = None;
}

# =============================================================================
# Top-Level Declarations
# =============================================================================
obj Archetype(ElementStmt, ArchBlockStmt) {
    has arch_type: Token,
        name: Token,
        access: Token | None = None,
        base_classes: list[Expr] = [],
        body: list[ArchBlockStmt] = [],
        decorators: list[Expr] = [],
        is_async: bool = False,
        is_abstract: bool = False,
        doc: StringLiteral | None = None;
}

obj Ability(ElementStmt, ArchBlockStmt) {
    has ability_type: Token,
        name: Token,
        signature: FuncSignature | EventSignature,
        access: Token | None = None,
        body: list[CodeBlockStmt] = [],
        decorators: list[Expr] = [],
        is_async: bool = False,
        is_static: bool = False,
        is_override: bool = False,
        is_abstract: bool = False,
        doc: StringLiteral | None = None;
}

obj HasStmt(ArchBlockStmt) {
    has is_static: bool = False,
        access: Token | None = None,
        vars: list[HasVarDecl] = [];
}

obj HasVarDecl(AstNode) {
    has name: Token,
        type_tag: Expr | None = None,
        value: Expr | None = None,
        is_frozen: bool = False,
        is_post_init: bool = False,
        doc: StringLiteral | None = None;
}

obj HasVar(ArchBlockStmt) {
    has name: Token,
        access: Token | None = None,
        type_tag: Expr | None = None,
        value: Expr | None = None,
        is_static: bool = False,
        is_frozen: bool = False,
        doc: StringLiteral | None = None;
}

obj Enum(ElementStmt, ArchBlockStmt) {
    has name: Token,
        access: Token | None = None,
        members: list[EnumMember] = [],
        decorators: list[Expr] = [],
        doc: StringLiteral | None = None;
}

obj EnumMember(AstNode) {
    has name: Token,
        value: Expr | None = None;
}

obj ImplDef(ElementStmt) {
    has target: Expr,
        for_type: Expr | None = None,
        body: list[ArchBlockStmt] = [],
        decorators: list[Expr] = [];
}

obj TestDef(ElementStmt) {
    has name: StringLiteral,
        body: list[CodeBlockStmt] = [];
}

obj GlobalVarDef(ElementStmt) {
    has name: Token,
        type_tag: Expr | None = None,
        value: Expr | None = None;
}

# =============================================================================
# Import Statements
# =============================================================================
obj ImportStmt(ElementStmt) {
    has path: list[Token] = [],
        items: list[ImportItem] = [],
        alias: Token | None = None,
        is_include: bool = False,
        leading_dots: int = 0;
}

obj ImportItem(AstNode) {
    has name: Token,
        alias: Token | None = None;
}

# =============================================================================
# Context Blocks
# =============================================================================
obj ContextBlock(ElementStmt) {
    has context: Token,
        body: list[ElementStmt] = [];
}

obj EntryBlock(ElementStmt) {
    has is_exit: bool = False,
        target_name: Token | None = None,
        body: list[CodeBlockStmt] = [];
}

# =============================================================================
# Semantic Annotation
# =============================================================================
obj SemDef(ElementStmt) {
    has target: Expr,
        description: StringLiteral;
}

# =============================================================================
# Inline Python
# =============================================================================
obj PyCodeBlock(ElementStmt, ArchBlockStmt, CodeBlockStmt) {
    has token: Token,
        code: str = "";
}

obj TypeAliasStmt(ElementStmt) {
    has name: Token,
        value: Expr;
}

# =============================================================================
# Module
# =============================================================================
obj Module(AstNode) {
    has name: str,
        file_path: str,
        doc: StringLiteral | None = None,
        body: list[ElementStmt] = [];
}
# The backtick
# The type expression

# True for ?. access

# |> or <|

# :> or <:

# flow or wait keyword

# -->, <--, <-->

# ++>, <++, <++>

# Optional starting node expression

# node or edge keyword

# -->, <--, <--> or parameterized
# Type filter for edges
# Additional filter expression

# !s, !r, !a

# For augmented assignment (+=, etc.)

# Executed if loop completes normally

# Executed if loop completes normally

# Executed if loop completes normally

# For **rest

# Empty for default case

# Optional filter expression
# Optional else clause

# *args
# **kwargs

# entry or exit

# obj, node, edge, walker, class

# pub, priv, protect

# can or def

# For `by post_init`

# impl Trait for Type

# Dotted path
# Specific items (from import)
# import path as alias
# include vs import
# For relative imports (., .., ...)

# cl, sv, na

# Optional target name
