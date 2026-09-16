"""C preprocessing-token scanner; splicing precedes comment recognition."""
import from jaclang.compiler.frontend.unitree { Source }
import from .tokens { CToken, CDiagnostic, CLexResult }

def lex_c(code: str, path: str = "<c-input>") -> CLexResult {
    source = Source(code, path);
    # Translation phase two, with a map back to physical source positions.
    chars: list[str] = [];
    offsets: list[int] = [];
    lines: list[int] = [];
    columns: list[int] = [];
    i = 0; line = 1; column = 1;
    trigraphs = {"=": "#", "/": "\\", "'": "^", "(": "[", ")": "]", "!": "|", "<": "{", ">": "}", "-": "~"};
    while i < len(code) {
        width = 1; current = code[i];
        if code[i:i + 2] == "??" and i + 2 < len(code) and code[i + 2] in trigraphs {
            current = trigraphs[code[i + 2]]; width = 3;
        }
        if current == "\\" and code[i + width:i + width + 1] == "\n" {
            i += width + 1; line += 1; column = 1; continue;
        }
        if current == "\\" and code[i + width:i + width + 2] == "\r\n" {
            i += width + 2; line += 1; column = 1; continue;
        }
        chars.append(current); offsets.append(i);
        lines.append(line); columns.append(column);
        if current == "\n" { line += 1; column = 1; }
        else { column += width; }
        i += width;
    }
    offsets.append(len(code)); lines.append(line); columns.append(column);
    text = "".join(chars);
    result = CLexResult();
    i = 0; spaced = False;
    punct = ["%:%:", ">>=", "<<=", "...", "->", "++", "--", "<<", ">>",
        "<=", ">=", "==", "!=", "&&", "||", "*=", "/=", "%=", "+=", "-=",
        "&=", "^=", "|=", "##", "<:", ":>", "<%", "%>", "%:"];
    digraphs = {"<:": "[", ":>": "]", "<%": "{", "%>": "}", "%:": "#", "%:%:": "##"};
    while i < len(text) {
        ch = text[i];
        if ch in " \t\r\v\f" { spaced = True; i += 1; continue; }
        if text[i:i + 2] == "//" {
            while i < len(text) and text[i] != "\n" { i += 1; }
            spaced = True; continue;
        }
        if text[i:i + 2] == "/*" {
            begin = i; i += 2;
            while i < len(text) and text[i:i + 2] != "*/" {
                i += 1;
            }
            if i == len(text) {
                bad = CToken(kind="invalid", text="/*", source=source,
                    start=offsets[begin], end=offsets[i], line=lines[begin],
                    column=columns[begin], end_line=lines[i], end_column=columns[i]);
                result.diagnostics.append(CDiagnostic("Unterminated comment", bad));
            } else { i += 2; }
            spaced = True; continue;
        }
        begin = i; kind = "punct";
        quote_at = i;
        if text[i:i + 2] in ["L\"", "L'", "u\"", "u'", "U\"", "U'"] { quote_at = i + 1; }
        elif text[i:i + 3] == 'u8"' { quote_at = i + 2; }
        header = ch == "<" and len(result.tokens) >= 2 and result.tokens[-1].text == "include" and result.tokens[-2].text == "#" and (len(result.tokens) == 2 or result.tokens[-3].kind == "newline");
        if header {
            kind = "header"; i += 1;
            while i < len(text) and text[i] not in ">\n" { i += 1; }
            if i < len(text) and text[i] == ">" { i += 1; }
            else { kind = "invalid"; }
        } elif text[quote_at] in "\"'" {
            quote = text[quote_at]; kind = "string" if quote == '"' else "char";
            i = quote_at + 1;
            while i < len(text) and text[i] != quote and text[i] != "\n" {
                if text[i] == "\\" { i += 1; }
                if i < len(text) { i += 1; }
            }
            if i < len(text) and text[i] == quote { i += 1; }
            else { kind = "invalid"; }
        } elif ch == "_" or ch.isalpha() {
            kind = "identifier"; i += 1;
            while i < len(text) and (text[i] == "_" or text[i].isalnum()) { i += 1; }
        } elif ch.isdigit() or (ch == "." and i + 1 < len(text) and text[i + 1].isdigit()) {
            kind = "number"; i += 1;
            while i < len(text) {
                c = text[i];
                if c.isalnum() or c in "_." { i += 1; }
                elif c in "+-" and text[i - 1] in "eEpP" { i += 1; }
                else { break; }
            }
        } elif ch == "\n" { kind = "newline"; i += 1; }
        else {
            found = "";
            for p in punct {
                if text[i:i + len(p)] == p { found = p; break; }
            }
            i += len(found) if found else 1;
            if not found and ch not in "[](){}.&*+-~!/%<>^|?:;=,#" { kind = "invalid"; }
        }
        spelling = text[begin:i];
        tok = CToken(kind=kind, text=digraphs.get(spelling, spelling), source=source,
            start=offsets[begin], end=offsets[i], line=lines[begin], column=columns[begin],
            end_line=lines[i], end_column=columns[i], space=spaced);
        result.tokens.append(tok);
        if kind == "invalid" { result.diagnostics.append(CDiagnostic("Invalid or unterminated C token", tok)); }
        spaced = kind == "newline";
    }
    result.tokens.append(CToken(kind="eof", text="", source=source,
        start=len(code), end=len(code), line=line, column=column,
        end_line=line, end_column=column));
    return result;
}
