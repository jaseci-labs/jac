"""Preprocessor integer expressions, without host-language eval.

intmax_t/uintmax_t width is explicit. Unevaluated operands are still parsed;
short-circuiting prevents spurious divide-by-zero diagnostics.
"""
import from .tokens { CToken }

obj PPValue {
    has number: int,
        unsigned: bool = False;
}

obj PPExpression {
    has tokens: list[CToken],
        width: int = 64,
        pos: int = 0;

    def peek -> str {
        return self.tokens[self.pos].text if self.pos < len(self.tokens) else "";
    }

    def take -> str {
        value = self.peek();
        if not value { raise ValueError("Expected preprocessor expression operand"); }
        self.pos += 1;
        return value;
    }

    def expect(value: str) {
        if self.take() != value { raise ValueError("Expected '" + value + "' in preprocessor expression"); }
    }

    def normalized(value: int, unsigned: bool) -> PPValue {
        modulus = 1 << self.width;
        value = value % modulus;
        if not unsigned and value >= (modulus >> 1) { value -= modulus; }
        return PPValue(value, unsigned);
    }

    def literal(value: str) -> PPValue {
        if "'" in value {
            body = value[value.index("'") + 1:-1];
            escapes = {"\\n": 10, "\\r": 13, "\\t": 9, "\\0": 0, "\\\\": 92, "\\'": 39};
            if body in escapes { return PPValue(escapes[body]); }
            if len(body) == 1 { return PPValue(ord(body)); }
            if body.startswith("\\x") { return PPValue(int(body[2:], 16)); }
            if body.startswith("\\") and all(c in "01234567" for c in body[1:]) {
                return PPValue(int(body[1:], 8));
            }
            raise ValueError("Unsupported implementation-defined character constant");
        }
        end = len(value);
        while end > 0 and value[end - 1] in "uUlL" { end -= 1; }
        suffix = value[end:].lower();
        if suffix not in ["", "u", "l", "ll", "ul", "lu", "ull", "llu"] {
            raise ValueError("Invalid integer suffix in preprocessor condition");
        }
        digits = value[:end]; base = 10;
        if digits.lower().startswith("0x") { base = 16; }
        elif len(digits) > 1 and digits.startswith("0") { base = 8; }
        number = int(digits, base);
        unsigned = "u" in suffix or (base != 10 and number >= (1 << (self.width - 1)));
        if number >= (1 << self.width) or (not unsigned and number >= (1 << (self.width - 1))) {
            raise ValueError("Integer outside configured preprocessor width");
        }
        return self.normalized(number, unsigned);
    }

    def unary(evaluate: bool) -> PPValue {
        text = self.take();
        if text in ["+", "-", "!", "~"] {
            v = self.unary(evaluate);
            if text == "!" { return PPValue(int(v.number == 0)); }
            if text == "-" {
                if evaluate and not v.unsigned and v.number == -(1 << (self.width - 1)) {
                    raise ValueError("Signed overflow in preprocessor negation");
                }
                return self.normalized(-v.number, v.unsigned);
            }
            if text == "~" { return self.normalized(~v.number, v.unsigned); }
            return v;
        }
        if text == "(" {
            v = self.expression(0, evaluate); self.expect(")"); return v;
        }
        token = self.tokens[self.pos - 1];
        if token.kind == "identifier" { return PPValue(0); }
        if token.kind not in ["number", "char"] { raise ValueError("Invalid preprocessor operand: " + text); }
        return self.literal(text);
    }

    def expression(minimum: int = 0, evaluate: bool = True) -> PPValue {
        precedence = {"||": 1, "&&": 2, "|": 3, "^": 4, "&": 5,
            "==": 6, "!=": 6, "<": 7, ">": 7, "<=": 7, ">=": 7,
            "<<": 8, ">>": 8, "+": 9, "-": 9, "*": 10, "/": 10, "%": 10};
        left = self.unary(evaluate);
        while self.peek() in precedence and precedence[self.peek()] >= minimum {
            op = self.take();
            enabled = evaluate;
            if op == "&&" and left.number == 0 { enabled = False; }
            if op == "||" and left.number != 0 { enabled = False; }
            right = self.expression(precedence[op] + 1, enabled);
            unsigned = left.unsigned or right.unsigned;
            a = self.normalized(left.number, unsigned).number;
            b = self.normalized(right.number, unsigned).number;
            n = 0;
            if op == "&&" { left = PPValue(int(left.number != 0 and right.number != 0)); continue; }
            if op == "||" { left = PPValue(int(left.number != 0 or right.number != 0)); continue; }
            if op in ["==", "!=", "<", ">", "<=", ">="] {
                yes = False;
                if op == "==" { yes = a == b; }
                elif op == "!=" { yes = a != b; }
                elif op == "<" { yes = a < b; }
                elif op == ">" { yes = a > b; }
                elif op == "<=" { yes = a <= b; }
                else { yes = a >= b; }
                left = PPValue(int(yes)); continue;
            }
            if evaluate {
                if op == "+" { n = a + b; }
                elif op == "-" { n = a - b; }
                elif op == "*" { n = a * b; }
                elif op in ["/", "%"] {
                    if b == 0 { raise ValueError("Division by zero in preprocessor condition"); }
                    if not unsigned and a == -(1 << (self.width - 1)) and b == -1 {
                        raise ValueError("Signed overflow in preprocessor division");
                    }
                    q = abs(a) // abs(b);
                    if (a < 0) != (b < 0) { q = -q; }
                    n = q if op == "/" else a - q * b;
                } elif op in ["<<", ">>"] {
                    if right.number < 0 or right.number >= self.width { raise ValueError("Invalid preprocessor shift count"); }
                    unsigned = left.unsigned;
                    if op == "<<" and not unsigned and left.number < 0 {
                        raise ValueError("Left shift of negative preprocessor value");
                    }
                    n = left.number << right.number if op == "<<" else left.number >> right.number;
                } elif op == "&" { n = a & b; }
                elif op == "|" { n = a | b; }
                elif op == "^" { n = a ^ b; }
                if not unsigned and (n < -(1 << (self.width - 1)) or n >= (1 << (self.width - 1))) {
                    raise ValueError("Signed overflow in preprocessor condition");
                }
            }
            left = self.normalized(n, unsigned);
        }
        if minimum == 0 and self.peek() == "?" {
            self.take();
            true_value = self.expression(0, evaluate and left.number != 0);
            self.expect(":");
            false_value = self.expression(0, evaluate and left.number == 0);
            chosen = true_value if left.number != 0 else false_value;
            return self.normalized(chosen.number, true_value.unsigned or false_value.unsigned);
        }
        return left;
    }

    def run -> bool {
        value = self.expression();
        if self.pos != len(self.tokens) { raise ValueError("Unexpected token in preprocessor condition: " + self.peek()); }
        return value.number != 0;
    }
}
