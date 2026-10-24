glob _NAME_CHARS: str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._$-",
     _DIGITS: str = "0123456789",
     _HEX_DIGITS: str = "0123456789abcdefABCDEF";

class Context {
    has scope: _utils.NameScope,
        identified_types: dict[str, types.IdentifiedStructType];

    def init(self: Context) {
        self.scope = _utils.NameScope();
        self.identified_types = {};
    }

    def get_identified_type(
        self: Context, name: str, packed: bool = False
    ) -> types.IdentifiedStructType {
        ty = self.identified_types.get(name);
        if ty is None {
            self.scope.register(name);
            ty = types.IdentifiedStructType(self, name, packed);
            self.identified_types[name] = ty;
        }
        return ty;
    }

    """The type a type's text names, read back in this context: the inverse of
    `str(type)`. A named struct resolves to this context's struct of that name,
    opaque until its body is set."""
    def parse_type(self: Context, text: str) -> types.Type {
        reader = _TypeReader(text, self);
        found = reader.read_type();
        reader.skip_blanks();
        if reader.at != len(text) {
            raise ValueError(f"trailing text at {reader.at} in type {text!r}");
        }
        return found;
    }
}

class _TypeReader {
    has text: str,
        at: int,
        context: Context;

    def init(self: _TypeReader, text: str, context: Context) {
        self.text = text;
        self.at = 0;
        self.context = context;
    }

    def skip_blanks(self: _TypeReader) {
        while self.at < len(self.text) and self.text[self.at] == " " {
            self.at += 1;
        }
    }

    def take(self: _TypeReader, token: str) -> bool {
        self.skip_blanks();
        if self.text.startswith(token, self.at) {
            self.at += len(token);
            return True;
        }
        return False;
    }

    def expect(self: _TypeReader, token: str) {
        if not self.take(token) {
            raise ValueError(f"expected {token!r} at {self.at} in type {self.text!r}");
        }
    }

    def take_word(self: _TypeReader, word: str) -> bool {
        self.skip_blanks();
        stop = self.at + len(word);
        if self.text.startswith(word, self.at)
            and (stop >= len(self.text) or self.text[stop] not in _NAME_CHARS) {
            self.at = stop;
            return True;
        }
        return False;
    }

    def read_number(self: _TypeReader) -> int {
        self.skip_blanks();
        start = self.at;
        while self.at < len(self.text) and self.text[self.at] in _DIGITS {
            self.at += 1;
        }
        if start == self.at {
            raise ValueError(f"expected a number at {start} in type {self.text!r}");
        }
        return int(self.text[start:self.at]);
    }

    def read_name(self: _TypeReader) -> str {
        if self.at < len(self.text) and self.text[self.at] == '"' {
            self.at += 1;
            out = "";
            while self.at < len(self.text) and self.text[self.at] != '"' {
                ch = self.text[self.at];
                if ch == "\\"
                    and self.at + 2 < len(self.text)
                    and self.text[self.at + 1] in _HEX_DIGITS
                    and self.text[self.at + 2] in _HEX_DIGITS {
                    out += chr(int(self.text[self.at + 1:self.at + 3], 16));
                    self.at += 3;
                } else {
                    out += ch;
                    self.at += 1;
                }
            }
            self.expect('"');
            return out;
        }
        start = self.at;
        while self.at < len(self.text) and self.text[self.at] in _NAME_CHARS {
            self.at += 1;
        }
        if start == self.at {
            raise ValueError(
                f"expected a struct name at {start} in type {self.text!r}"
            );
        }
        return self.text[start:self.at];
    }

    def read_members(self: _TypeReader, close: str) -> list[types.Type] {
        members: list[types.Type] = [];
        if self.take(close) {
            return members;
        }
        while True {
            members.append(self.read_type());
            if self.take(close) {
                return members;
            }
            self.expect(",");
        }
    }

    def read_addrspace(self: _TypeReader) -> int {
        if self.take_word("addrspace") {
            self.expect("(");
            space = self.read_number();
            self.expect(")");
            return space;
        }
        return 0;
    }

    def read_element(self: _TypeReader) -> types.Type {
        self.skip_blanks();
        if self.take("<{") {
            members = self.read_members("}>");
            return types.LiteralStructType(members, packed=True);
        }
        if self.take("{") {
            return types.LiteralStructType(self.read_members("}"));
        }
        if self.take("[") {
            count = self.read_number();
            self.expect("x");
            element = self.read_type();
            self.expect("]");
            return types.ArrayType(element, count);
        }
        if self.take("<") {
            count = self.read_number();
            self.expect("x");
            element = self.read_type();
            self.expect(">");
            return types.VectorType(element, count);
        }
        if self.take("%") {
            return self.context.get_identified_type(self.read_name());
        }
        if self.take_word("ptr") {
            return types.PointerType(None, self.read_addrspace());
        }
        if self.take_word("void") {
            return types.VoidType();
        }
        if self.take_word("half") {
            return types.HalfType();
        }
        if self.take_word("float") {
            return types.FloatType();
        }
        if self.take_word("double") {
            return types.DoubleType();
        }
        if self.take_word("label") {
            return types.LabelType();
        }
        if self.take_word("metadata") {
            return types.MetaDataType();
        }
        if self.at + 1 < len(self.text)
            and self.text[self.at] == "i"
            and self.text[self.at + 1] in _DIGITS {
            self.at += 1;
            return types.IntType(self.read_number());
        }
        raise ValueError(f"unknown type at {self.at} in {self.text!r}");
    }

    def read_type(self: _TypeReader) -> types.Type {
        found = self.read_element();
        while True {
            space = self.read_addrspace();
            if self.take("*") {
                found = types.PointerType(found, space);
                continue;
            }
            if space != 0 {
                raise ValueError(f"expected '*' after addrspace in type {self.text!r}");
            }
            if self.take("(") {
                args: list[types.Type] = [];
                var_arg = False;
                if not self.take(")") {
                    while True {
                        if self.take("...") {
                            var_arg = True;
                            self.expect(")");
                            break;
                        }
                        args.append(self.read_type());
                        if self.take(")") {
                            break;
                        }
                        self.expect(",");
                    }
                }
                found = types.FunctionType(found, args, var_arg=var_arg);
                continue;
            }
            return found;
        }
    }
}

glob global_context: Context = Context();
