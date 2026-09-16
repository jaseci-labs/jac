"""Token-based C preprocessing with explicit include paths and definitions."""
import os;
import from .tokens { CToken, CDiagnostic }
import from .lexer { lex_c }
import from .conditions { PPExpression }
import from jaclang.compiler.frontend.unitree_c {
    CNode, CPreprocessorDirective, CPreprocessingUnit, CPreprocessorText, CPreprocessorToken
}

obj CConfig {
    has include_paths: list[str] = [],
        defines: dict[str, str] = {},
        virtual_headers: dict[str, str] = {},
        intmax_width: int = 64,
        max_include_depth: int = 100,
        max_expansions: int = 100000;
}

obj CMacro {
    has name: str,
        replacement: list[CToken],
        parameters: list[str] = [],
        function_like: bool = False,
        variadic: bool = False;
}

obj CConditional {
    has parent_active: bool,
        active: bool,
        taken: bool,
        seen_else: bool = False;
}

obj CPreprocessResult {
    has tokens: list[CToken] = [],
        directives: list[CPreprocessorDirective] = [],
        diagnostics: list[CDiagnostic] = [],
        operations: list[CNode] = [],
        eof: CToken | None = None,
        # Physical sources, including inactive branches, remain available.
        sources: dict[str, str] = {};
}

obj CPreprocessor {
    has config: CConfig,
        macros: dict[str, CMacro] = {},
        result: CPreprocessResult = CPreprocessResult(),
        once: set[str] = set(),
        expansions: int = 0;

    def error(message: str, token: CToken) {
        self.result.diagnostics.append(CDiagnostic(message, token));
    }

    def run(code: str, path: str = "<c-input>") -> CPreprocessResult {
        # A preprocessor instance represents one translation unit.
        self.macros = {}; self.result = CPreprocessResult();
        self.once = set(); self.expansions = 0;
        if self.config.intmax_width < 16 { raise ValueError("intmax_width must be at least 16"); }
        for (name, value) in self.config.defines.items() {
            scanned = lex_c(value, "<command-line>");
            self.result.diagnostics.extend(scanned.diagnostics);
            self.macros[name] = CMacro(name, [t for t in scanned.tokens if t.kind not in ["eof", "newline"]]);
        }
        self.result.tokens = self.process(code, path, 0);
        eof = self.result.eof;
        if eof is not None { self.result.tokens.append(eof); }
        return self.result;
    }

    def arguments(tokens: list[CToken], opening: int) -> tuple[list[list[CToken]], int] {
        args: list[list[CToken]] = [[]]; depth = 0; i = opening + 1;
        while i < len(tokens) {
            token = tokens[i];
            if token.text == ")" and depth == 0 { return (args, i + 1); }
            if token.text == "," and depth == 0 { args.append([]); }
            else {
                if token.text == "(" { depth += 1; }
                elif token.text == ")" { depth -= 1; }
                args[-1].append(token);
            }
            i += 1;
        }
        raise ValueError("Unterminated function-like macro invocation");
    }

    def stringify(tokens: list[CToken]) -> str {
        body = "";
        for t in tokens {
            if body and t.space { body += " "; }
            spelling = t.text;
            if t.kind in ["string", "char"] {
                spelling = spelling.replace("\\", "\\\\").replace('"', '\\"');
            }
            body += spelling;
        }
        return '"' + body + '"';
    }

    def substitute(macro: CMacro, args: list[list[CToken]], origin: CToken) -> list[CToken] {
        raw: dict[str, list[CToken]] = {};
        expanded: dict[str, list[CToken]] = {};
        if not macro.parameters and not macro.variadic and len(args) == 1 and not args[0] { args = []; }
        required = len(macro.parameters);
        if (not macro.variadic and len(args) != required) or (macro.variadic and len(args) < required) {
            raise ValueError("Wrong number of arguments to macro " + macro.name);
        }
        for i in range(required) { raw[macro.parameters[i]] = args[i]; }
        if macro.variadic {
            tail: list[CToken] = [];
            for i in range(required, len(args)) {
                if i > required { tail.append(origin.copy(text=",", kind="punct")); }
                tail.extend(args[i]);
            }
            raw["__VA_ARGS__"] = tail;
        }
        replacement = macro.replacement; i = 0;
        pieces: list[CToken] = [];
        while i < len(replacement) {
            t = replacement[i];
            if t.text == "#" and macro.function_like {
                i += 1;
                if i >= len(replacement) or replacement[i].text not in raw {
                    raise ValueError("Macro # must precede a parameter");
                }
                pieces.append(origin.copy(text=self.stringify(raw[replacement[i].text]), kind="string"));
            } elif t.text in raw {
                pasted = (i > 0 and replacement[i - 1].text == "##") or (i + 1 < len(replacement) and replacement[i + 1].text == "##");
                values = raw[t.text];
                if not pasted {
                    if t.text not in expanded { expanded[t.text] = self.expand(values); }
                    values = expanded[t.text];
                }
                if not values and pasted { pieces.append(origin.copy(text="<placemarker>", kind="placemarker")); }
                else {
                    copied = [v.copy() for v in values];
                    if copied { copied[0].space = t.space; }
                    pieces.extend(copied);
                }
            } else {
                copied_token = t.copy();
                if t.text == "##" { copied_token.kind = "paste"; }
                pieces.append(copied_token);
            }
            i += 1;
        }
        joined: list[CToken] = []; i = 0;
        while i < len(pieces) {
            t = pieces[i];
            if t.kind != "paste" { joined.append(t); i += 1; continue; }
            if not joined or i + 1 >= len(pieces) { raise ValueError("## requires two macro operands"); }
            left = joined.pop(); right = pieces[i + 1];
            if left.kind == "placemarker" { joined.append(right); }
            elif right.kind == "placemarker" { joined.append(left); }
            else {
                scan = lex_c(left.text + right.text, "<token-paste>");
                if scan.diagnostics or len(scan.tokens) != 2 or scan.tokens[0].kind in ["newline", "eof"] {
                    raise ValueError("Token paste does not produce one preprocessing token");
                }
                pasted_token = origin.copy(text=scan.tokens[0].text, kind=scan.tokens[0].kind);
                pasted_token.hidden = left.hidden & right.hidden;
                pasted_token.space = left.space;
                joined.append(pasted_token);
            }
            i += 2;
        }
        return [t for t in joined if t.kind != "placemarker"];
    }

    def expand(tokens: list[CToken]) -> list[CToken] {
        pending = [t.copy() for t in tokens]; output: list[CToken] = []; i = 0;
        while i < len(pending) {
            t = pending[i]; macro = self.macros.get(t.text);
            if t.kind == "identifier" and t.text in ["__FILE__", "__LINE__"] {
                logical_path = t.presumed_path or t.source.file_path;
                value = str(t.presumed_line or t.line) if t.text == "__LINE__" else '"' + logical_path.replace("\\", "\\\\").replace('"', '\\"') + '"';
                output.append(t.copy(text=value, kind="number" if t.text == "__LINE__" else "string"));
                i += 1; continue;
            }
            if macro is None or t.text in t.hidden { output.append(t); i += 1; continue; }
            end = i + 1; hidden = set(t.hidden);
            if macro.function_like {
                if end >= len(pending) or pending[end].text != "(" { output.append(t); i += 1; continue; }
                (args, end) = self.arguments(pending, end);
                hidden = hidden & pending[end - 1].hidden;
                replacement = self.substitute(macro, args, t);
            } else {
                # Object-like macros can also contain token pastes.
                replacement = self.substitute(macro, [], t);
            }
            self.expansions += 1;
            if self.expansions > self.config.max_expansions { raise ValueError("Macro expansion budget exceeded"); }
            hidden.add(macro.name);
            for r in replacement {
                r.hidden.update(hidden);
                r.expansion = t.expansion + [macro.name] + r.expansion;
                # Expansion location is the invocation; spelling stays in the directive IR.
                r.source = t.source; r.start = t.start; r.end = t.end;
                r.line = t.line; r.column = t.column;
                r.end_line = t.end_line; r.end_column = t.end_column;
                r.presumed_line = t.presumed_line; r.presumed_path = t.presumed_path;
            }
            if replacement { replacement[0].space = t.space; }
            pending[i:end] = replacement;
        }
        return output;
    }

    def condition(tokens: list[CToken]) -> bool {
        rewritten: list[CToken] = []; i = 0;
        while i < len(tokens) {
            t = tokens[i];
            if t.text != "defined" { rewritten.append(t); i += 1; continue; }
            i += 1; parens = i < len(tokens) and tokens[i].text == "(";
            if parens { i += 1; }
            if i >= len(tokens) or tokens[i].kind != "identifier" { raise ValueError("defined requires an identifier"); }
            value = int(tokens[i].text in self.macros or tokens[i].text in ["__FILE__", "__LINE__"]); i += 1;
            if parens {
                if i >= len(tokens) or tokens[i].text != ")" { raise ValueError("Expected ')' after defined"); }
                i += 1;
            }
            rewritten.append(t.copy(text=str(value), kind="number"));
        }
        return PPExpression(self.expand(rewritten), width=self.config.intmax_width).run();
    }

    def define(tokens: list[CToken]) {
        if not tokens or tokens[0].kind != "identifier" { raise ValueError("#define requires a macro name"); }
        name = tokens[0].text; i = 1;
        if name in ["defined", "__FILE__", "__LINE__"] { raise ValueError("Cannot redefine " + name); }
        function_like = i < len(tokens) and tokens[i].text == "(" and not tokens[i].space;
        params: list[str] = []; variadic = False;
        if function_like {
            i += 1;
            while i < len(tokens) and tokens[i].text != ")" {
                t = tokens[i];
                if t.text == "..." { variadic = True; i += 1; break; }
                if t.kind != "identifier" or t.text in params or t.text == "__VA_ARGS__" { raise ValueError("Invalid macro parameter"); }
                params.append(t.text); i += 1;
                if i < len(tokens) and tokens[i].text == "," {
                    i += 1;
                    if i < len(tokens) and tokens[i].text == ")" { raise ValueError("Trailing comma in macro parameters"); }
                } else { break; }
            }
            if i >= len(tokens) or tokens[i].text != ")" { raise ValueError("Unterminated macro parameter list"); }
            i += 1;
        }
        replacement = tokens[i:];
        if replacement and (replacement[0].text == "##" or replacement[-1].text == "##") { raise ValueError("## at edge of macro replacement"); }
        for j in range(len(replacement)) {
            t = replacement[j];
            if t.text == "__VA_OPT__" { raise ValueError("C23 __VA_OPT__ is not implemented"); }
            if t.text == "__VA_ARGS__" and not variadic { raise ValueError("__VA_ARGS__ outside variadic macro"); }
            if t.text == "#" and function_like {
                if j + 1 >= len(replacement) or replacement[j + 1].text not in params + (["__VA_ARGS__"] if variadic else []) {
                    raise ValueError("# must precede a macro parameter");
                }
            }
        }
        macro = CMacro(name, replacement, params, function_like, variadic);
        old = self.macros.get(name);
        if old is not None {
            old_body = [(t.text, t.space if j > 0 else False) for (j, t) in enumerate(old.replacement)];
            new_body = [(t.text, t.space if j > 0 else False) for (j, t) in enumerate(replacement)];
            if old.parameters != params or old.function_like != function_like or old.variadic != variadic or old_body != new_body {
                raise ValueError("Incompatible redefinition of macro " + name);
            }
        }
        self.macros[name] = macro;
    }

    def include_file(tokens: list[CToken], path: str, depth: int) -> list[CToken] {
        # Header names inside angle brackets are not macro-expanded.
        expanded = tokens if tokens and (tokens[0].text == "<" or tokens[0].kind == "header") else self.expand(tokens);
        quoted = len(expanded) == 1 and expanded[0].kind == "string";
        if quoted or (len(expanded) == 1 and expanded[0].kind == "header") { name = expanded[0].text[1:-1]; }
        elif len(expanded) >= 3 and expanded[0].text == "<" and expanded[-1].text == ">" {
            name = "".join(t.text for t in expanded[1:-1]);
        } else { raise ValueError("#include requires a quoted or bracketed header name"); }
        if name in self.config.virtual_headers {
            return self.process(self.config.virtual_headers[name], name, depth + 1);
        }
        paths = list(self.config.include_paths);
        if quoted { paths.insert(0, os.path.dirname(os.path.abspath(path))); }
        for directory in paths {
            candidate = os.path.realpath(os.path.join(directory, name));
            if os.path.isfile(candidate) {
                with open(candidate, encoding="utf-8") as stream { code = stream.read(); }
                return self.process(code, candidate, depth + 1);
            }
        }
        raise ValueError("Header not found in configured include paths: " + name);
    }

    def process(code: str, path: str, depth: int) -> list[CToken] {
        if path in self.once { return []; }
        if depth > self.config.max_include_depth { raise ValueError("Include depth limit exceeded"); }
        self.result.sources[path] = code;
        scanned = lex_c(code, path); self.result.diagnostics.extend(scanned.diagnostics);
        if depth == 0 { self.result.eof = scanned.tokens[-1]; }
        output: list[CToken] = []; pending: list[CToken] = [];
        line_delta = 0; logical_path = path;
        stack: list[CConditional] = []; lines: list[list[CToken]] = [[]];
        for token in scanned.tokens {
            if token.kind in ["newline", "eof"] { lines.append([]); }
            else { lines[-1].append(token); }
        }
        for line in lines {
            if not line { continue; }
            for token in line {
                token.presumed_line = token.line + line_delta;
                token.presumed_path = logical_path;
            }
            active = not stack or stack[-1].active;
            raw_tokens: list[CNode] = [];
            for token in line {
                raw = CPreprocessorToken(token.kind, token.as_unitree(), value=token.text);
                raw.leading_space = token.space;
                raw_tokens.append(raw);
            }
            if line[0].text != "#" {
                fragment = CPreprocessorText("pp_text", line[0].as_unitree(), raw_tokens,
                    end=line[-1].as_unitree());
                fragment.active = active;
                self.result.operations.append(fragment);
                if active {
                    if pending { line[0].space = True; }
                    pending.extend(line);
                }
                continue;
            }
            try {
                if pending { output.extend(self.expand(pending)); pending = []; }
                name = line[1].text if len(line) > 1 else ""; args = line[2:];
                directive = CPreprocessorDirective("pp_" + name, line[0].as_unitree(), raw_tokens,
                    value=" ".join(t.text for t in args), end=line[-1].as_unitree());
                directive.active = active;
                self.result.directives.append(directive);
                self.result.operations.append(directive);
                if name in ["if", "ifdef", "ifndef"] {
                    selected = False;
                    if name in ["ifdef", "ifndef"] {
                        if len(args) != 1 or args[0].kind != "identifier" { raise ValueError("#" + name + " requires one identifier"); }
                        selected = args[0].text in self.macros or args[0].text in ["__FILE__", "__LINE__"];
                        if name == "ifndef" { selected = not selected; }
                    } elif active { selected = self.condition(args); }
                    stack.append(CConditional(active, active and selected, active and selected));
                } elif name in ["elif", "else", "endif"] {
                    if not stack { raise ValueError("Unmatched #" + name); }
                    frame = stack[-1];
                    if name == "endif" {
                        if args { raise ValueError("Unexpected tokens after #endif"); }
                        stack.pop();
                    } else {
                        if frame.seen_else { raise ValueError("#" + name + " after #else"); }
                        selected = False;
                        if name == "else" {
                            if args { raise ValueError("Unexpected tokens after #else"); }
                            frame.seen_else = True; selected = True;
                        } elif frame.parent_active and not frame.taken { selected = self.condition(args); }
                        frame.active = frame.parent_active and not frame.taken and selected;
                        frame.taken = frame.taken or frame.active;
                    }
                } elif active {
                    if name == "define" { self.define(args); }
                    elif name == "undef" {
                        if len(args) != 1 or args[0].kind != "identifier" { raise ValueError("#undef requires one identifier"); }
                        if args[0].text in ["__FILE__", "__LINE__"] { raise ValueError("Cannot undefine builtin macro"); }
                        if args[0].text in self.macros { del self.macros[args[0].text]; }
                    } elif name == "include" { output.extend(self.include_file(args, path, depth)); }
                    elif name == "line" {
                        values = self.expand(args);
                        if not values or len(values) > 2 or not values[0].text.isdigit() {
                            raise ValueError("#line requires a decimal line number and optional file name");
                        }
                        number = int(values[0].text);
                        if number < 1 or number > 2147483647 { raise ValueError("#line number outside C range"); }
                        if len(values) == 2 {
                            if values[1].kind != "string" or not values[1].text.startswith('"') {
                                raise ValueError("#line file name must be an ordinary string literal");
                            }
                            logical_path = values[1].text[1:-1].replace('\\"', '"').replace("\\\\", "\\");
                        }
                        line_delta = number - line[-1].end_line - 1;
                    }
                    elif name == "error" { raise ValueError("#error " + " ".join(t.text for t in args)); }
                    elif name == "warning" {
                        self.result.diagnostics.append(CDiagnostic("#warning " + " ".join(t.text for t in args), line[0], "warning"));
                    }
                    elif name == "pragma" and len(args) == 1 and args[0].text == "once" { self.once.add(path); }
                    elif name { raise ValueError("Unsupported active preprocessing directive: #" + name); }
                }
            } except ValueError as error {
                self.error(str(error), line[0]); pending = [];
            } except OSError as error {
                self.error(str(error), line[0]);
            } except UnicodeError as error {
                self.error(str(error), line[0]);
            }
        }
        if pending {
            try { output.extend(self.expand(pending)); }
            except ValueError as error { self.error(str(error), pending[0]); }
        }
        if stack { self.error("Unterminated preprocessing conditional", scanned.tokens[-1]); }
        return output;
    }
}
