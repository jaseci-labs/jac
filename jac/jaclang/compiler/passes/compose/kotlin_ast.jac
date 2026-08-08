import from typing { TypeAlias }
import from typing { Literal as TypingLiteral }

obj KtNode {
    has `type: str;
}

obj KtIdentifier(KtNode) {
    has name: str = "",
        `type: TypingLiteral["KtIdentifier"] = "KtIdentifier";
}

obj KtLiteral(KtNode) {
    has value: str | bool | None | int | float = None,
        `type: TypingLiteral["KtLiteral"] = "KtLiteral";
}

obj KtStringTemplate(KtNode) {
    has parts: list[str | KtNode] = [],
        `type: TypingLiteral["KtStringTemplate"] = "KtStringTemplate";
}

obj KtThis(KtNode) {
    has `type: TypingLiteral["KtThis"] = "KtThis";
}

obj KtMemberAccess(KtNode) {
    has object: (KtNode | None) = None,
        property: (KtNode | None) = None,
        computed: bool = False,
        safe: bool = False,
        `type: TypingLiteral["KtMemberAccess"] = "KtMemberAccess";
}

obj KtNamedArg {
    has name: str = "",
        value: (KtNode | None) = None;
}

obj KtLambda(KtNode) {
    has params: list[str] = [],
        body: list[KtNode] = [],
        expression_body: (KtNode | None) = None,
        label: (str | None) = None,
        `type: TypingLiteral["KtLambda"] = "KtLambda";
}

obj KtCall(KtNode) {
    has callee: (KtNode | None) = None,
        args: list[KtNode] = [],
        named_args: list[KtNamedArg] = [],
        trailing_lambda: (KtLambda | None) = None,
        safe: bool = False,
        `type: TypingLiteral["KtCall"] = "KtCall";
}

obj KtBinary(KtNode) {
    has operator: str = "",
        left: (KtNode | None) = None,
        right: (KtNode | None) = None,
        infix_fun: bool = False,
        `type: TypingLiteral["KtBinary"] = "KtBinary";
}

obj KtUnary(KtNode) {
    has operator: str = "",
        argument: (KtNode | None) = None,
        prefix: bool = True,
        `type: TypingLiteral["KtUnary"] = "KtUnary";
}

obj KtConditional(KtNode) {
    has `test: (KtNode | None) = None,
        consequent: (KtNode | None) = None,
        alternate: (KtNode | None) = None,
        `type: TypingLiteral["KtConditional"] = "KtConditional";
}

obj KtAssignment(KtNode) {
    has operator: str = "=",
        left: (KtNode | None) = None,
        right: (KtNode | None) = None,
        `type: TypingLiteral["KtAssignment"] = "KtAssignment";
}

obj KtListLiteral(KtNode) {
    has elements: list[KtNode] = [],
        `type: TypingLiteral["KtListLiteral"] = "KtListLiteral";
}

obj KtMapLiteral(KtNode) {
    has entries: list[(KtNode, KtNode)] = [],
        `type: TypingLiteral["KtMapLiteral"] = "KtMapLiteral";
}

obj KtSpread(KtNode) {
    has argument: (KtNode | None) = None,
        `type: TypingLiteral["KtSpread"] = "KtSpread";
}

obj KtRaw(KtNode) {
    has code: str = "",
        `type: TypingLiteral["KtRaw"] = "KtRaw";
}

obj KtExprStmt(KtNode) {
    has expression: (KtNode | None) = None,
        `type: TypingLiteral["KtExprStmt"] = "KtExprStmt";
}

obj KtBlock(KtNode) {
    has body: list[KtNode] = [],
        `type: TypingLiteral["KtBlock"] = "KtBlock";
}

obj KtProperty(KtNode) {
    has name: str = "",
        mutable: bool = False,
        `init: (KtNode | None) = None,
        type_ann: (str | None) = None,
        delegate: (KtNode | None) = None,
        annotations: list[str] = [],
        `type: TypingLiteral["KtProperty"] = "KtProperty";
}

obj KtIf(KtNode) {
    has `test: (KtNode | None) = None,
        consequent: list[KtNode] = [],
        alternate: list[KtNode] = [],
        `type: TypingLiteral["KtIf"] = "KtIf";
}

obj KtFor(KtNode) {
    has variable: str = "",
        iterable: (KtNode | None) = None,
        body: list[KtNode] = [],
        `type: TypingLiteral["KtFor"] = "KtFor";
}

obj KtWhile(KtNode) {
    has `test: (KtNode | None) = None,
        body: list[KtNode] = [],
        `type: TypingLiteral["KtWhile"] = "KtWhile";
}

obj KtReturn(KtNode) {
    has argument: (KtNode | None) = None,
        label: (str | None) = None,
        `type: TypingLiteral["KtReturn"] = "KtReturn";
}

obj KtTry(KtNode) {
    has try_body: list[KtNode] = [],
        catch_param: str = "e",
        catch_type: str = "Exception",
        catch_body: list[KtNode] = [],
        finally_body: list[KtNode] = [],
        `type: TypingLiteral["KtTry"] = "KtTry";
}

obj KtThrow(KtNode) {
    has argument: (KtNode | None) = None,
        `type: TypingLiteral["KtThrow"] = "KtThrow";
}

obj KtBreak(KtNode) {
    has `type: TypingLiteral["KtBreak"] = "KtBreak";
}

obj KtContinue(KtNode) {
    has `type: TypingLiteral["KtContinue"] = "KtContinue";
}

obj KtWhenEntry {
    has `test: (KtNode | None) = None,
        body: list[KtNode] = [];
}

obj KtWhen(KtNode) {
    has subject: (KtNode | None) = None,
        entries: list[KtWhenEntry] = [],
        `type: TypingLiteral["KtWhen"] = "KtWhen";
}

obj KtParam {
    has name: str = "",
        type_ann: str = "",
        default: (KtNode | None) = None;
}

obj KtFunction(KtNode) {
    has name: str = "",
        params: list[KtParam] = [],
        return_type: (str | None) = None,
        body: list[KtNode] = [],
        annotations: list[str] = [],
        modifiers: list[str] = [],
        is_suspend: bool = False,
        is_expression_body: bool = False,
        expression_body: (KtNode | None) = None,
        `type: TypingLiteral["KtFunction"] = "KtFunction";
}

obj KtClass(KtNode) {
    has name: str = "",
        kind: str = "class",
        primary_params: list[KtParam] = [],
        body: list[KtNode] = [],
        annotations: list[str] = [],
        modifiers: list[str] = [],
        super_types: list[str] = [],
        `type: TypingLiteral["KtClass"] = "KtClass";
}

obj KtObject(KtNode) {
    has name: str = "",
        body: list[KtNode] = [],
        annotations: list[str] = [],
        `type: TypingLiteral["KtObject"] = "KtObject";
}

obj KtImport(KtNode) {
    has path: str = "",
        alias: (str | None) = None,
        `type: TypingLiteral["KtImport"] = "KtImport";
}

obj KtFile(KtNode) {
    has package: str = "",
        imports: list[KtImport] = [],
        declarations: list[KtNode] = [],
        `type: TypingLiteral["KtFile"] = "KtFile";
}

obj KtModifierCall {
    has name: str = "",
        args: list[KtNode] = [],
        named_args: list[KtNamedArg] = [];
}

obj KtModifierChain(KtNode) {
    has calls: list[KtModifierCall] = [],
        `type: TypingLiteral["KtModifierChain"] = "KtModifierChain";
}

obj KtComposableCall(KtNode) {
    has name: str = "",
        args: list[KtNamedArg] = [],
        content: list[KtNode] = [],
        `type: TypingLiteral["KtComposableCall"] = "KtComposableCall";
}
