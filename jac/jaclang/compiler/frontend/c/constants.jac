"""Typed C integer constant evaluation shared by declarations and lowering."""
import from .semantics { CType, CScalar, CEmitConfig, integer_literal, promote, common, unqualified, attributes_of, string_bytes, character_literal, is_floating_literal, floating_literal }
import from jaclang.compiler.frontend.unitree_c { CNode }

obj CInteger {
    has value: int,
        typ: CScalar;

    def converted(target: CScalar) -> CInteger {
        if target.category == "bool" { return CInteger(int(bool(self.value)), target); }
        if target.category != "integer" { raise ValueError("Constant conversion requires an integer type"); }
        bits = self.value % (1 << target.width);
        if target.signed and bits >= (1 << (target.width - 1)) { bits -= 1 << target.width; }
        return CInteger(bits, target);
    }
}

def integer_result(value: int, typ: CScalar) -> CInteger {
    if typ.signed and not (-(1 << (typ.width - 1)) <= value < (1 << (typ.width - 1))) {
        raise ValueError("Signed overflow in C integer constant expression");
    }
    return CInteger(value, typ).converted(typ);
}

def integer_unary(op: str, operand: CInteger) -> CInteger {
    value = operand.converted(promote(operand.typ));
    if op == "!" { return CInteger(int(not value.value), CScalar()); }
    if op == "+" { return value; }
    if op == "-" { return integer_result(-value.value, value.typ); }
    if op == "~" { return CInteger(~value.value, value.typ).converted(value.typ); }
    raise ValueError("Unsupported integer constant operator " + op);
}

def integer_binary(op: str, left: CInteger, right: CInteger) -> CInteger {
    typ = promote(left.typ) if op in ["<<", ">>"] else common(left.typ, right.typ);
    a = left.converted(typ).value;
    b = right.converted(promote(right.typ) if op in ["<<", ">>"] else typ).value;
    if op in ["<<", ">>"] {
        if b < 0 or b >= typ.width { raise ValueError("Invalid shift count in C integer constant expression"); }
        if op == "<<" {
            if typ.signed and a < 0 { raise ValueError("Left shift of a negative C integer"); }
            return integer_result(a << b, typ);
        }
        return integer_result(a >> b, typ);
    }
    if op in ["/", "%"] {
        if b == 0 { raise ValueError("Division by zero in C integer constant expression"); }
        quotient = abs(a) // abs(b);
        if (a < 0) != (b < 0) { quotient = -quotient; }
        integer_result(quotient, typ);
        return integer_result(quotient if op == "/" else a - quotient * b, typ);
    }
    if op == "+" { return integer_result(a + b, typ); }
    if op == "-" { return integer_result(a - b, typ); }
    if op == "*" { return integer_result(a * b, typ); }
    if op == "&" { return CInteger(a & b, typ).converted(typ); }
    if op == "|" { return CInteger(a | b, typ).converted(typ); }
    if op == "^" { return CInteger(a ^ b, typ).converted(typ); }
    if op == "==" { return CInteger(int(a == b), CScalar()); }
    if op == "!=" { return CInteger(int(a != b), CScalar()); }
    if op == "<" { return CInteger(int(a < b), CScalar()); }
    if op == "<=" { return CInteger(int(a <= b), CScalar()); }
    if op == ">" { return CInteger(int(a > b), CScalar()); }
    if op == ">=" { return CInteger(int(a >= b), CScalar()); }
    if op == "&&" { return CInteger(int(bool(a) and bool(b)), CScalar()); }
    if op == "||" { return CInteger(int(bool(a) or bool(b)), CScalar()); }
    raise ValueError("Unsupported binary integer constant operator " + op);
}

obj CIntegerEvaluator {
    has config: CEmitConfig = CEmitConfig(),
        resolve_type: Callable[[CNode], CType] | None = None,
        storage_size: Callable[[CType], int | None] | None = None,
        resolve_name: Callable[[str], CInteger | None] | None = None;

    def type_of(nd: CNode) -> CScalar | None {
        if nd.kind in ["sizeof_type", "sizeof_expr"] { return self.config.size_type(); }
        if nd.kind == "char" { return CScalar(); }
        if nd.kind == "identifier" {
            resolve_name = self.resolve_name;
            value = resolve_name(nd.value) if resolve_name is not None else None;
            return value.typ if value is not None else None;
        }
        if nd.kind == "number" {
            return floating_literal(nd.value)[1] if is_floating_literal(nd.value)
                else integer_literal(nd.value, self.config)[1];
        }
        if nd.kind == "cast" {
            resolve_type = self.resolve_type;
            if resolve_type is None or self.type_of(nd.operands[1]) is None { return None; }
            declared = resolve_type(nd.operands[0]);
            target = unqualified(declared);
            if attributes_of(declared) { return None; }
            return target if isinstance(target, CScalar) and target.category in ["integer", "bool", "floating"] else None;
        }
        if nd.kind in ["parenthesized", "extension"] { return self.type_of(nd.operands[0]); }
        if nd.kind == "unary" and nd.value in ["+", "-", "~", "!"] {
            operand = self.type_of(nd.operands[0]);
            if operand is not None and operand.category == "floating" and nd.value == "~" {
                raise ValueError("Bitwise complement requires an integer operand");
            }
            return None if operand is None else (CScalar() if nd.value == "!" else promote(operand));
        }
        if nd.kind in ["binary", "conditional"] {
            left = self.type_of(nd.operands[1] if nd.kind == "conditional" else nd.operands[0]);
            right = self.type_of(nd.operands[2] if nd.kind == "conditional" else nd.operands[1]);
            if left is None or right is None { return None; }
            if nd.kind == "binary" and nd.value in ["%", "<<", ">>", "&", "|", "^"]
                and "floating" in [left.category, right.category] {
                raise ValueError("C operator requires integer operands: " + nd.value);
            }
            if nd.kind == "conditional" { return common(left, right); }
            if nd.value in ["==", "!=", "<", "<=", ">", ">=", "&&", "||"] { return CScalar(); }
            return promote(left) if nd.value in ["<<", ">>"] else common(left, right);
        }
        return None;
    }

    def evaluate(nd: CNode) -> CInteger | None {
        typ = self.type_of(nd);
        if typ is None or typ.category == "floating" { return None; }
        if nd.kind == "identifier" {
            resolve_name = self.resolve_name;
            return resolve_name(nd.value) if resolve_name is not None else None;
        }
        if nd.kind == "char" { return CInteger(character_literal(nd.value), typ); }
        if nd.kind == "sizeof_expr" {
            operand = nd.operands[0];
            while operand.kind in ["parenthesized", "extension"] { operand = operand.operands[0]; }
            if operand.kind == "string" {
                string_length = len(string_bytes(operand)) + 1;
                return CInteger(string_length, typ);
            }
            operand_type = self.type_of(operand); storage_size = self.storage_size;
            if operand_type is None or storage_size is None { return None; }
            size = storage_size(operand_type);
            return CInteger(size, typ) if size is not None else None;
        }
        if nd.kind == "sizeof_type" {
            resolve_type = self.resolve_type; storage_size = self.storage_size;
            if resolve_type is None or storage_size is None { return None; }
            size = storage_size(resolve_type(nd.operands[0]));
            return CInteger(size, typ) if size is not None else None;
        }
        if nd.kind == "number" { return CInteger(integer_literal(nd.value, self.config)[0], typ); }
        if nd.kind == "cast" {
            cast_operand = nd.operands[1];
            if cast_operand.kind == "number" and is_floating_literal(cast_operand.value) {
                floating = floating_literal(cast_operand.value)[0];
                if typ.category == "bool" { return CInteger(int(bool(floating)), typ); }
                converted = int(floating);
                minimum = -(1 << (typ.width - 1)) if typ.signed else 0;
                maximum = (1 << (typ.width - (1 if typ.signed else 0))) - 1;
                if not (minimum <= converted <= maximum) {
                    raise ValueError("Floating constant conversion is outside the C integer range");
                }
                return CInteger(converted, typ);
            }
            operand_value = self.evaluate(cast_operand);
            return operand_value.converted(typ) if operand_value is not None else None;
        }
        if nd.kind in ["parenthesized", "extension"] { return self.evaluate(nd.operands[0]); }
        left = self.evaluate(nd.operands[0]);
        if left is None { return None; }
        if nd.kind == "unary" { return integer_unary(nd.value, left); }
        if nd.kind == "conditional" {
            selected = self.evaluate(nd.operands[1] if left.value else nd.operands[2]);
            return selected.converted(typ) if selected is not None else None;
        }
        if nd.value == "&&" and not left.value { return CInteger(0, CScalar()); }
        if nd.value == "||" and left.value { return CInteger(1, CScalar()); }
        right = self.evaluate(nd.operands[1]);
        return integer_binary(nd.value, left, right) if right is not None else None;
    }
}
