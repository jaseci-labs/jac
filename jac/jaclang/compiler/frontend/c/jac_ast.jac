"""Construct standard Jac UniTree nodes for C lowering, without source templates.

All output tokens belong to one generated source. C origins are retained
separately so the shared unparser does not filter included C declarations as
though they were annexed Jac modules.
"""
import jaclang.compiler.frontend.unitree as uni;
import copy;
import json;
import from .semantics { CType, CScalar, CEnum, CPointer, CArray, CQualified, CAttributed, CRecord, CFunctionType, CField, CEmitConfig, unqualified, attributes_of, lowering_attributes }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.parser.tokens { KEYWORDS }
import from jaclang.compiler.frontend.srcloc { Span }

obj CJacAst {
    has source: uni.Source,
        origin: uni.UniNode,
        origins: dict[int, Span] = {},
        required_records: dict[int, CRecord] = {},
        required_layouts: set[int] = set(),
        config: CEmitConfig = CEmitConfig();

    def mark[T: uni.UniNode](nd: T) -> T {
        self.origins[id(nd)] = Span.from_loc(self.origin.loc);
        return nd;
    }

    def token(kind: str, value: str) -> uni.Token {
        return self.mark(uni.Token(self.source, kind, value, 1, 1, 1, 1, 0, 0));
    }

    def name(value: str) -> uni.Name {
        return self.mark(uni.Name(self.source, Tok.NAME, value, 1, 1, 1, 1, 0, 0, is_kwesc=value in KEYWORDS));
    }

    def typ(value: str | uni.Expr) -> uni.Expr {
        if isinstance(value, uni.Expr) { return value; }
        if value == "None" { return self.mark(uni.Null(self.source, Tok.NULL, "None", 1, 1, 1, 1, 0, 0)); }
        return self.mark(uni.BuiltinType(self.source, "TYP_" + value.upper(), value, 1, 1, 1, 1, 0, 0));
    }

    def generic_type(name: str, arguments: list[uni.Expr]) -> uni.Expr {
        target = self.name(name);
        argument: uni.Expr = arguments[0] if len(arguments) == 1 else self.mark(
            uni.TupleVal(values=arguments, kid=arguments));
        part = self.mark(uni.Slice(start=argument, stop=None, step=None, kid=[argument]));
        index = self.mark(uni.IndexSlice(slices=[part], is_range=False, kid=[part]));
        return self.mark(uni.AtomTrailer(target=target, right=index, is_attr=False,
            is_null_ok=False, kid=[target, index]));
    }

    def type_node(typ: CType, require_layout: bool = True) -> uni.Expr {
        attributes = lowering_attributes(attributes_of(typ));
        if attributes { raise ValueError("C type attributes require explicit lowering: " + "; ".join(attribute.value for attribute in attributes)); }
        if isinstance(typ, CAttributed) { return self.type_node(typ.base, require_layout); }
        if isinstance(typ, CQualified) {
            # Volatile affects accesses, not storage representation. The C
            # lowerer retains the qualifier and checks each memory operation.
            if "_Atomic" in typ.qualifiers and not self.config.scalar_atomic_storage(typ.base) {
                raise ValueError("Atomic storage requires a supported target scalar representation");
            }
            if any(q not in ["const", "restrict", "volatile", "_Atomic"] for q in typ.qualifiers) {
                raise ValueError("Qualified C storage needs memory-operation lowering");
            }
            return self.type_node(typ.base, require_layout);
        }
        if isinstance(typ, CEnum) and not typ.complete { raise ValueError("Incomplete C enum requires a known target representation"); }
        if isinstance(typ, CScalar) { return self.typ(typ.jac); }
        if isinstance(typ, CFunctionType) {
            if not typ.prototype or typ.variadic {
                raise ValueError("Function pointer signature needs prototype and variadic ABI lowering");
            }
            parameters = [self.type_node(parameter) for parameter in typ.parameters];
            arguments = self.list_value(parameters);
            return self.generic_type("Callable", [arguments, self.type_node(typ.returns)]);
        }
        if isinstance(typ, CRecord) {
            self.required_records[typ.identity] = typ;
            if require_layout { self.required_layouts.add(typ.identity); }
            return self.name(self.record_name(typ));
        }
        if isinstance(typ, CPointer) {
            attributes = lowering_attributes(attributes_of(typ.pointee));
            if attributes { raise ValueError("C pointee attributes require explicit lowering: " + "; ".join(attribute.value for attribute in attributes)); }
            pointee = unqualified(typ.pointee);
            element = self.typ("u8") if isinstance(pointee, CScalar) and pointee.category == "void"
                else self.type_node(typ.pointee, require_layout=False);
            return self.generic_type("ptr", [element]);
        }
        if isinstance(typ, CArray) {
            if typ.length is None {
                raise ValueError("Array bound requires complete constant-expression or VLA lowering");
            }
            return self.generic_type("array", [self.type_node(typ.element), self.integer(typ.length)]);
        }
        raise ValueError("C declaration type has no Jac source representation yet: " + type(typ).__name__);
    }

    def field_name(field: CField) -> str {
        return "c_" + field.name if field.name else "_c2jac_anon_" + str(field.ordinal);
    }

    def record_name(typ: CRecord) -> str {
        return "c_" + typ.kind + "_" + str(typ.identity) + ("_" + typ.name if typ.name else "");
    }

    def union_storage_type(typ: CRecord) -> uni.Expr {
        if not typ.complete or not typ.fields { raise ValueError("Union storage requires at least one complete member"); }
        alternatives = [self.type_node(field.typ) for field in typ.fields];
        storage = alternatives[-1];
        if len(alternatives) == 1 {
            return self.generic_type("overlay", [alternatives[0], self.type_node(typ.fields[0].typ)]);
        }
        for alternative in reversed(alternatives[:-1]) {
            storage = self.generic_type("overlay", [alternative, storage]);
        }
        return storage;
    }

    def packed_storage_type(record: CRecord) -> uni.Expr {
        storage: uni.Expr = self.generic_type("array", [self.typ("u8"), self.integer(0)]);
        for field in reversed(record.fields) {
            storage = self.generic_type("packed", [self.type_node(field.typ), storage]);
        }
        return storage;
    }

    def field_offset(record: CRecord, field: CField) -> uni.Expr {
        if record.kind == "union" { return self.integer(0); }
        if not record.is_packed() {
            return self.call("offset_of", [self.type_node(record), self.string(self.field_name(field))]);
        }
        offset: uni.Expr = self.integer(0);
        for preceding in record.fields {
            if preceding is field { return offset; }
            if preceding.bit_width is not None { raise ValueError("Packed bitfield offset requires allocation-unit layout"); }
            offset = self.binary("+", offset, self.call("size_of", [self.type_node(preceding.typ)]));
        }
        raise ValueError("Field does not belong to its record");
    }

    def field_access(owner: uni.Expr, record: CRecord, field: CField) -> uni.Expr {
        self.required_records[record.identity] = record;
        self.required_layouts.add(record.identity);
        if record.is_packed() { raise ValueError("Packed member access requires unaligned memory operations"); }
        if record.kind == "struct" { return self.member(owner, self.field_name(field)); }
        storage = self.member(owner, "_c2jac_storage");
        address = self.invoke(self.member(self.call("addr_of", [storage]), "address"), []);
        pointer = self.type_node(CPointer(field.typ));
        view = self.invoke(self.member(pointer, "from_address"), [address]);
        return self.index(view, self.integer(0));
    }

    def field_declaration(name: str, annotation: uni.Expr) -> uni.ArchHas {
        ident = self.name(name);
        tag = self.mark(uni.SubTag[uni.Expr](tag=annotation, kid=[annotation]));
        variable = self.mark(uni.HasVar(name=ident, type_tag=tag, value=None,
            defer=False, kid=[ident, tag]));
        return self.mark(uni.ArchHas(is_static=False, is_frozen=False,
            vars=[variable], kid=[variable]));
    }

    def record(typ: CRecord) -> uni.Archetype {
        complete = typ.complete and typ.identity in self.required_layouts;
        packed_record = typ.is_packed();
        if complete and lowering_attributes(typ.attributes, {"packed"} if packed_record else None) { raise ValueError("Record attributes require layout-aware lowering"); }
        if complete and typ.assertions { raise ValueError("Record assertions require C constant-expression lowering"); }
        members: list[uni.UniNode] = [];
        bit_units = typ.full_bitfield_units() if complete else None;
        byte_fields = typ.byte_bitfields() if complete else None;
        if packed_record and complete {
            if bit_units is not None or any(field.bit_width is not None for field in typ.fields) {
                raise ValueError("Packed bitfields require explicit allocation-unit layout");
            }
            members = [self.field_declaration("_c2jac_storage", self.packed_storage_type(typ))];
        } elif bit_units is not None {
            members = [self.field_declaration("_c2jac_bits_" + str(index), self.typ("u32"))
                for index in range(bit_units)];
        }
        for field in (typ.fields if complete and bit_units is None and not packed_record else []) {
            self.origin = field.declaration;
            if field.bit_width is not None {
                if byte_fields is None { raise ValueError("Bitfields require a supported target allocation-unit layout"); }
                bits = next(bit for bit in byte_fields if bit.field is field);
                if bits.field.ordinal == bits.storage_ordinal {
                    members.append(self.field_declaration(bits.storage_name, self.typ("u8")));
                }
                continue;
            }
            if typ.kind == "struct" {
                members.append(self.field_declaration(self.field_name(field), self.type_node(field.typ)));
            }
        }
        if typ.kind == "union" and complete {
            members.append(self.field_declaration("_c2jac_storage", self.union_storage_type(typ)));
        }
        if typ.definition is not None { self.origin = typ.definition; }
        ident = self.name(self.record_name(typ));
        kind = self.token(Tok.KW_STRUCT, "struct");
        kids: list[uni.UniNode] = [kind, ident]; kids.extend(members);
        return self.mark(uni.Archetype(name=ident, arch_type=kind, body=members if complete else None,
            decorators=None, base_classes=[], kid=kids));
    }

    def list_value(values: list[uni.Expr]) -> uni.ListVal {
        kids: list[uni.UniNode] = [self.token(Tok.LSQUARE, "[")];
        kids.extend(values); kids.append(self.token(Tok.RSQUARE, "]"));
        return self.mark(uni.ListVal(values=values, kid=kids));
    }

    def integer(value: int) -> uni.Int {
        return self.mark(uni.Int(self.source, Tok.INT, str(value), 1, 1, 1, 1, 0, 0));
    }

    def string(value: str) -> uni.String {
        return self.mark(uni.String(self.source, Tok.STRING, json.dumps(value), 1, 1, 1, 1, 0, 0));
    }

    def floating(value: float) -> uni.Float {
        return self.mark(uni.Float(self.source, Tok.FLOAT, repr(value), 1, 1, 1, 1, 0, 0));
    }

    def boolean(value: bool) -> uni.Bool {
        return self.mark(uni.Bool(self.source, Tok.BOOL, "True" if value else "False", 1, 1, 1, 1, 0, 0));
    }

    def call(name: str, args: list[uni.Expr]) -> uni.FuncCall {
        parts = name.split(".");
        target: uni.Expr = self.typ(parts[0]) if parts[0] in ["bool", "i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64", "f32", "f64"] else self.name(parts[0]);
        for part in parts[1:] { target = self.member(target, part); }
        return self.invoke(target, args);
    }

    def invoke(target: uni.Expr, args: list[uni.Expr]) -> uni.FuncCall {
        kids: list[uni.UniNode] = [target]; kids.extend(args);
        return self.mark(uni.FuncCall(target=target, params=args, genai_call=None, kid=kids));
    }

    def member(target: uni.Expr, name: str) -> uni.AtomTrailer {
        right = self.name(name);
        return self.mark(uni.AtomTrailer(target=target, right=right, is_attr=True,
            is_null_ok=False, kid=[target, right]));
    }

    def index(target: uni.Expr, index: uni.Expr) -> uni.AtomTrailer {
        part = self.mark(uni.Slice(start=index, stop=None, step=None, kid=[index]));
        right = self.mark(uni.IndexSlice(slices=[part], is_range=False, kid=[part]));
        return self.mark(uni.AtomTrailer(target=target, right=right, is_attr=False,
            is_null_ok=False, kid=[target, right]));
    }

    def grouped(value: uni.Expr) -> uni.AtomUnit {
        return self.mark(uni.AtomUnit(value=value, kid=[value]));
    }

    def binary(op: str, left: uni.Expr, right: uni.Expr) -> uni.Expr {
        kinds = {"+": Tok.PLUS, "-": Tok.MINUS, "*": Tok.STAR_MUL,
            "/": Tok.DIV, "//": Tok.FLOOR_DIV, "%": Tok.MOD, "<<": Tok.LSHIFT, ">>": Tok.RSHIFT,
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

    def evaluated_block(statements: list[uni.CodeBlockStmt], value: uni.Expr, typ: CType) -> uni.Expr {
        result_type = self.type_node(typ);
        signature = self.mark(uni.FuncSignature(posonly_params=[], params=[], varargs=None,
            kwonlyargs=[], kwargs=None, return_type=result_type, kid=[result_type]));
        body = list(statements); body.append(self.returned(value));
        kids: list[uni.UniNode] = [signature]; kids.extend(body);
        expression = self.mark(uni.LambdaExpr(body=body, signature=signature, kid=kids));
        return self.invoke(self.grouped(expression), []);
    }

    def assignment(name: str, value: uni.Expr | None, typ: str | uni.Expr = "") -> uni.Assignment {
        target = self.name(name);
        tag: uni.SubTag[uni.Expr] | None = None;
        kids: list[uni.UniNode] = [target];
        if typ {
            annotation = self.typ(typ);
            tag = self.mark(uni.SubTag[uni.Expr](tag=annotation, kid=[annotation]));
            kids.append(tag);
        }
        if value is not None { kids.append(value); }
        return self.mark(uni.Assignment(target=[target], value=value, type_tag=tag, kid=kids));
    }

    def store(target: uni.Expr, value: uni.Expr) -> uni.Assignment {
        return self.mark(uni.Assignment(target=[target], value=value, type_tag=None,
            kid=[target, value]));
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

    def parameter(name: str, typ: str | uni.Expr, variadic: bool = False) -> uni.ParamVar {
        ident = self.name(name); annotation = self.typ(typ);
        tag = self.mark(uni.SubTag[uni.Expr](tag=annotation, kid=[annotation]));
        unpack = self.token(Tok.STAR_MUL, "*") if variadic else None;
        kids: list[uni.UniNode] = [ident, tag];
        if unpack is not None { kids.insert(0, unpack); }
        return self.mark(uni.ParamVar(name=ident, type_tag=tag, unpack=unpack, value=None, kid=kids));
    }

    def private_access -> uni.SubTag[uni.Token] {
        keyword = self.token(Tok.KW_PRIV, "priv");
        return self.mark(uni.SubTag[uni.Token](tag=keyword, kid=[self.token(Tok.COLON, ":"), keyword]));
    }

    def function(name: str, params: list[uni.ParamVar], returns: str | uni.Expr, body: list[uni.CodeBlockStmt] | None, internal: bool = False, variadic: bool = False) -> uni.Ability {
        ident = self.name(name); return_type = self.typ(returns);
        signature_kids: list[uni.UniNode] = []; signature_kids.extend(params); signature_kids.append(return_type);
        varargs = self.parameter("args", "any", variadic=True) if variadic else None;
        if varargs is not None {
            varargs.param_kind = uni.ParamKind.VARARG;
            signature_kids.append(varargs);
        }
        signature = self.mark(uni.FuncSignature(posonly_params=[], params=params, varargs=varargs,
            kwonlyargs=[], kwargs=None, return_type=return_type, kid=signature_kids));
        access = self.private_access() if internal else None;
        kids: list[uni.UniNode] = [ident, signature];
        if access is not None { kids.append(access); }
        kids.extend(body or []);
        return self.mark(uni.Ability(name_ref=ident, signature=signature, body=body, access=access,
            is_override=False, is_static=False, is_classmethod=False, is_abstract=False, kid=kids));
    }

    def global_var(name: str, typ: str | uni.Expr, value: uni.Expr | None, thread_local: bool = False, internal: bool = False) -> uni.GlobalVars {
        assignment = self.assignment(name, value, typ);
        access = self.private_access() if internal else None;
        kids: list[uni.UniNode] = [assignment];
        if access is not None { kids.insert(0, access); }
        return self.mark(uni.GlobalVars(assignments=[assignment], is_frozen=False,
            is_thread_local=thread_local, access=access, kid=kids));
    }

    def foreign(declarations: list[uni.UniNode]) -> uni.Import {
        return self.mark(uni.Import(from_loc=None, items=[], is_absorb=False,
            clib_decls=declarations, kid=declarations));
    }

    def alias(name: str, typ: str | uni.Expr) -> uni.TypeAlias {
        ident = self.name(name); value = self.typ(typ);
        return self.mark(uni.TypeAlias(name=ident, type_params=[], value=value, kid=[ident, value]));
    }

    def module(body: list[uni.ElementStmt]) -> uni.Module {
        kids: list[uni.UniNode] = [self.token(Tok.NAME, "")]; kids.extend(body);
        return self.mark(uni.Module(name="c2jac", source=self.source, body=body, terminals=[], kid=kids));
    }

    def clone[T: uni.UniNode](nd: T) -> T {
        cloned = copy.deepcopy(nd);
        for (original, copied) in zip(nd.flatten(), cloned.flatten()) {
            span = self.origins.get(id(original));
            if span is not None { self.origins[id(copied)] = span; }
        }
        return cloned;
    }

    def clone_block(body: list[uni.CodeBlockStmt]) -> list[uni.CodeBlockStmt] {
        return [self.clone(statement) for statement in body];
    }
}
