"""Construct standard Jac UniTree nodes for C lowering, without source templates.

All output tokens belong to one generated source. C origins are retained
separately so the shared unparser does not filter included C declarations as
though they were annexed Jac modules.
"""
import jaclang.compiler.frontend.unitree as uni;
import copy;
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.srcloc { Span }

obj CJacAst {
    has source: uni.Source,
        origin: uni.UniNode,
        origins: dict[int, Span] = {};

    def mark[T: uni.UniNode](nd: T) -> T {
        self.origins[id(nd)] = Span.from_loc(self.origin.loc);
        return nd;
    }

    def token(kind: str, value: str) -> uni.Token {
        return self.mark(uni.Token(self.source, kind, value, 1, 1, 1, 1, 0, 0));
    }

    def name(value: str) -> uni.Name {
        return self.mark(uni.Name(self.source, Tok.NAME, value, 1, 1, 1, 1, 0, 0));
    }

    def typ(value: str) -> uni.Expr {
        if value == "None" { return self.mark(uni.Null(self.source, Tok.NULL, "None", 1, 1, 1, 1, 0, 0)); }
        return self.mark(uni.BuiltinType(self.source, "TYP_" + value.upper(), value, 1, 1, 1, 1, 0, 0));
    }

    def integer(value: int) -> uni.Int {
        return self.mark(uni.Int(self.source, Tok.INT, str(value), 1, 1, 1, 1, 0, 0));
    }

    def boolean(value: bool) -> uni.Bool {
        return self.mark(uni.Bool(self.source, Tok.BOOL, "True" if value else "False", 1, 1, 1, 1, 0, 0));
    }

    def call(name: str, args: list[uni.Expr]) -> uni.FuncCall {
        parts = name.split(".");
        target: uni.Expr = self.typ(parts[0]) if parts[0] in ["bool", "i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64"] else self.name(parts[0]);
        for part in parts[1:] {
            right = self.name(part);
            target = self.mark(uni.AtomTrailer(target=target, right=right, is_attr=True, is_null_ok=False, kid=[target, right]));
        }
        kids: list[uni.UniNode] = [target]; kids.extend(args);
        return self.mark(uni.FuncCall(target=target, params=args, genai_call=None, kid=kids));
    }

    def grouped(value: uni.Expr) -> uni.AtomUnit {
        return self.mark(uni.AtomUnit(value=value, kid=[value]));
    }

    def binary(op: str, left: uni.Expr, right: uni.Expr) -> uni.Expr {
        kinds = {"+": Tok.PLUS, "-": Tok.MINUS, "*": Tok.STAR_MUL,
            "//": Tok.FLOOR_DIV, "%": Tok.MOD, "<<": Tok.LSHIFT, ">>": Tok.RSHIFT,
            "&": Tok.BW_AND, "|": Tok.BW_OR, "^": Tok.BW_XOR,
            "==": Tok.EE, "!=": Tok.NE, "<": Tok.LT, ">": Tok.GT,
            "<=": Tok.LTE, ">=": Tok.GTE, "and": Tok.KW_AND, "or": Tok.KW_OR};
        token = self.token(kinds[op], op);
        if op in ["==", "!=", "<", ">", "<=", ">="] {
            return self.grouped(self.mark(uni.CompareExpr(left=left, rights=[right], ops=[token], kid=[left, token, right])));
        }
        if op in ["and", "or"] {
            first = self.mark(uni.CfgExpr(expr=left, kid=[left]));
            second = self.mark(uni.CfgExpr(expr=right, kid=[right]));
            return self.grouped(self.mark(uni.BoolExpr(op=token, values=[first, second], kid=[first, token, second])));
        }
        return self.grouped(self.mark(uni.BinaryExpr(left=left, right=right, op=token, kid=[left, token, right])));
    }

    def unary(op: str, value: uni.Expr) -> uni.Expr {
        token = self.token({"+": Tok.PLUS, "-": Tok.MINUS, "~": Tok.BW_NOT, "not": Tok.NOT}[op], op);
        return self.grouped(self.mark(uni.UnaryExpr(op=token, operand=value, kid=[token, value])));
    }

    def conditional(condition: uni.Expr, yes: uni.Expr, no: uni.Expr) -> uni.Expr {
        guard = self.mark(uni.CfgExpr(expr=condition, kid=[condition]));
        selected = self.mark(uni.CfgExpr(expr=yes, kid=[yes]));
        alternative = self.mark(uni.CfgExpr(expr=no, kid=[no]));
        return self.grouped(self.mark(uni.IfElseExpr(condition=guard, value=selected, else_value=alternative, kid=[selected, guard, alternative])));
    }

    def assignment(name: str, value: uni.Expr, typ: str = "") -> uni.Assignment {
        target = self.name(name);
        tag: uni.SubTag[uni.Expr] | None = None;
        kids: list[uni.UniNode] = [target];
        if typ {
            annotation = self.typ(typ);
            tag = self.mark(uni.SubTag[uni.Expr](tag=annotation, kid=[annotation]));
            kids.append(tag);
        }
        kids.append(value);
        return self.mark(uni.Assignment(target=[target], value=value, type_tag=tag, kid=kids));
    }

    def returned(value: uni.Expr | None = None) -> uni.ReturnStmt {
        kids: list[uni.UniNode] = [self.token(Tok.KW_RETURN, "return")];
        if value is not None { kids.append(value); }
        return self.mark(uni.ReturnStmt(expr=value, kid=kids));
    }

    def control(value: str) -> uni.CtrlStmt {
        token = self.token(Tok.KW_BREAK if value == "break" else Tok.KW_CONTINUE, value);
        return self.mark(uni.CtrlStmt(ctrl=token, kid=[token]));
    }

    def expression(value: uni.Expr) -> uni.ExprStmt {
        return self.mark(uni.ExprStmt(expr=value, in_fstring=False, kid=[value]));
    }

    def branch(condition: uni.Expr, body: list[uni.CodeBlockStmt], otherwise: list[uni.CodeBlockStmt] | None = None) -> uni.IfStmt {
        kids: list[uni.UniNode] = [condition]; kids.extend(body);
        alternative: uni.ElseStmt | None = None;
        if otherwise is not None {
            other_kids: list[uni.UniNode] = [self.token(Tok.KW_ELSE, "else")]; other_kids.extend(otherwise);
            alternative = self.mark(uni.ElseStmt(body=otherwise, kid=other_kids)); kids.append(alternative);
        }
        return self.mark(uni.IfStmt(condition=condition, body=body, else_body=alternative, kid=kids));
    }

    def loop(condition: uni.Expr, body: list[uni.CodeBlockStmt]) -> uni.WhileStmt {
        kids: list[uni.UniNode] = [condition]; kids.extend(body);
        return self.mark(uni.WhileStmt(condition=condition, body=body, kid=kids));
    }

    def parameter(name: str, typ: str) -> uni.ParamVar {
        ident = self.name(name); annotation = self.typ(typ);
        tag = self.mark(uni.SubTag[uni.Expr](tag=annotation, kid=[annotation]));
        return self.mark(uni.ParamVar(name=ident, type_tag=tag, unpack=None, value=None, kid=[ident, tag]));
    }

    def function(name: str, params: list[uni.ParamVar], returns: str, body: list[uni.CodeBlockStmt]) -> uni.Ability {
        ident = self.name(name); return_type = self.typ(returns);
        signature_kids: list[uni.UniNode] = []; signature_kids.extend(params); signature_kids.append(return_type);
        signature = self.mark(uni.FuncSignature(posonly_params=[], params=params, varargs=None,
            kwonlyargs=[], kwargs=None, return_type=return_type, kid=signature_kids));
        kids: list[uni.UniNode] = [ident, signature]; kids.extend(body);
        return self.mark(uni.Ability(name_ref=ident, signature=signature, body=body,
            is_override=False, is_static=False, is_classmethod=False, is_abstract=False, kid=kids));
    }

    def global_var(name: str, typ: str, value: uni.Expr) -> uni.GlobalVars {
        assignment = self.assignment(name, value, typ);
        return self.mark(uni.GlobalVars(assignments=[assignment], is_frozen=False, kid=[assignment]));
    }

    def alias(name: str, typ: str) -> uni.TypeAlias {
        ident = self.name(name); value = self.typ(typ);
        return self.mark(uni.TypeAlias(name=ident, type_params=[], value=value, kid=[ident, value]));
    }

    def module(body: list[uni.ElementStmt]) -> uni.Module {
        kids: list[uni.UniNode] = [self.token(Tok.NAME, "")]; kids.extend(body);
        return self.mark(uni.Module(name="c2jac", source=self.source, body=body, terminals=[], kid=kids));
    }

    def clone_block(body: list[uni.CodeBlockStmt]) -> list[uni.CodeBlockStmt] {
        result: list[uni.CodeBlockStmt] = [];
        for statement in body {
            cloned = copy.deepcopy(statement);
            for (original, copied) in zip(statement.flatten(), cloned.flatten()) {
                span = self.origins.get(id(original));
                if span is not None { self.origins[id(copied)] = span; }
            }
            result.append(cloned);
        }
        return result;
    }
}
