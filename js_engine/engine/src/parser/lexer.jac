"""
JavaScript / TypeScript Lexer for js_engine.

Converts raw JS/TS source text into a flat Token stream.  Hand-written,
single-pass, no regex.  Handles the full ES2024 lexical grammar including
template literals, numeric separators, BigInt literals, and the main
operator set.  TypeScript-specific tokens (decorators via @) and JSX angle
brackets are also covered.

RegExp literal scanning requires parser context (is this `/` a division or a
regexp start?) — the Lexer exposes a `set_regexp_mode(v: bool)` method that
the parser calls after each token to signal when the next `/` begins a regexp.

Bun reference: bun/src/js_lexer.zig (~3 000 lines)
ECMAScript spec: §12 — Lexical Grammar  https://tc39.es/ecma262/#sec-lexical-grammar
"""
import from engine.src.runtime.mem { byte_chr }


# ══════════════════════════════════════════════════════════════════════════════
# 1.  TokenType enum
# ══════════════════════════════════════════════════════════════════════════════

"""All token categories produced by the lexer."""
enum:pub TokenType {
    # ── Special ────────────────────────────────────────────────────────────
    EOF = 0,
    Error = 1,  # unrecognised character
    # ── Literals ───────────────────────────────────────────────────────────
    NumericLiteral = 10,
    BigIntLiteral = 11,
    StringLiteral = 12,
    TemplateLiteral = 13,  # simple `str` (no interpolation)
    TemplateHead = 14,  # `head${
    TemplateMiddle = 15,  # }middle${
    TemplateTail = 16,  # }tail`
    RegExpLiteral = 17,
    # ── Identifier & keywords ──────────────────────────────────────────────
    Identifier = 20,
    PrivateName = 21,  # #identifier (private class member)
    # ── Punctuation ────────────────────────────────────────────────────────
    LParen = 30,  # (
    RParen = 31,  # )
    LBrace = 32,  # {
    RBrace = 33,  # }
    LBracket = 34,  # [
    RBracket = 35,  # ]
    Semicolon = 36,  # ;
    Comma = 37,  # ,
    Dot = 38,  # .
    DotDotDot = 39,  # ...
    Colon = 40,  # :
    Question = 41,  # ?
    QuestionDot = 42,  # ?.
    Arrow = 43,  # =>
    At = 44,  # @
    # ── Operators ──────────────────────────────────────────────────────────
    Plus = 50,  # +
    Minus = 51,  # -
    Star = 52,  # *
    StarStar = 53,  # **
    Slash = 54,  # /
    Percent = 55,  # %
    Amp = 56,  # &
    Pipe = 57,  # |
    Caret = 58,  # ^
    Tilde = 59,  # ~
    Bang = 60,  # !
    Lt = 61,  # <
    Gt = 62,  # >
    LtLt = 63,  # <<
    GtGt = 64,  # >>
    GtGtGt = 65,  # >>>
    AmpAmp = 66,  # &&
    PipePipe = 67,  # ||
    QuestionQuestion = 68,  # ??
    PlusPlus = 69,  # ++
    MinusMinus = 70,  # --
    # ── Assignment & compound operators ───────────────────────────────────
    Eq = 80,  # =
    EqEq = 81,  # ==
    EqEqEq = 82,  # ===
    BangEq = 83,  # !=
    BangEqEq = 84,  # !==
    LtEq = 85,  # <=
    GtEq = 86,  # >=
    PlusEq = 87,  # +=
    MinusEq = 88,  # -=
    StarEq = 89,  # *=
    SlashEq = 90,  # /=
    PercentEq = 91,  # %=
    AmpEq = 92,  # &=
    PipeEq = 93,  # |=
    CaretEq = 94,  # ^=
    LtLtEq = 95,  # <<=
    GtGtEq = 96,  # >>=
    GtGtGtEq = 97,  # >>>=
    StarStarEq = 98,  # **=
    AmpAmpEq = 99,  # &&=
    PipePipeEq = 100,  # ||=
    QuestionQuestionEq = 101,  # ??=
    # ── Keywords ───────────────────────────────────────────────────────────
    KwVar = 110,
    KwLet = 111,
    KwConst = 112,
    KwFunction = 113,
    KwClass = 114,
    KwIf = 115,
    KwElse = 116,
    KwFor = 117,
    KwWhile = 118,
    KwDo = 119,
    KwReturn = 120,
    KwNew = 121,
    KwDelete = 122,
    KwTypeof = 123,
    KwVoid = 124,
    KwIn = 125,
    KwOf = 126,
    KwImport = 127,
    KwExport = 128,
    KwDefault = 129,
    KwFrom = 130,
    KwAs = 131,
    KwExtends = 132,
    KwSuper = 133,
    KwThis = 134,
    KwYield = 135,
    KwAsync = 136,
    KwAwait = 137,
    KwStatic = 138,
    KwGet = 139,
    KwSet = 140,
    KwTry = 141,
    KwCatch = 142,
    KwFinally = 143,
    KwThrow = 144,
    KwSwitch = 145,
    KwCase = 146,
    KwBreak = 147,
    KwContinue = 148,
    KwWith = 149,
    KwDebugger = 150,
    KwInstanceof = 151,
    KwTrue = 152,
    KwFalse = 153,
    KwNull = 154,
    KwUndefined = 155,
    KwTypeOf = 156,  # alias (same as KwTypeof)
    KwIn2 = 157  # placeholder to keep contiguous values
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Token & SourceLocation structs
# ══════════════════════════════════════════════════════════════════════════════

"""
A single token produced by the lexer.

  ttype              — token category
  value              — raw source text (for literals: content without quotes)
  line / col         — 1-based source position of the first character
  has_newline_before — true if at least one newline appeared between the
                       previous token and this one.  Used by the parser for
                       Automatic Semicolon Insertion (ASI).
"""
obj:pub Token {
    has ttype: TokenType,
        value: str,
        line: int,
        col: int,
        start_offset: int = 0,
        end_offset: int = 0,
        has_newline_before: bool = False;
}

"""Source position (line / column / byte offset — all 1-based)."""
obj:pub SourceLocation {
    has line: int,
        col: int,
        offset: int;
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Character utilities
# ══════════════════════════════════════════════════════════════════════════════

"""
Return the character of `s` at index `i`, or "" if out of bounds.
Works around the Jac native slice bug (s[a:b] → only first char).
"""
def _ch(s: str, i: int) -> str {
    n: int = len(s);
    if i < 0 or i >= n {
        return "";
    }
    return s[i];
}

"""
Build the substring s[start:end] character by character.
No bounds checks required on the caller — clamped internally.
"""
def _substr(s: str, start: int, end: int) -> str {
    n: int = len(s);
    st: int = start;
    en: int = end;
    if st < 0 {
        st = 0;
    }
    if en > n {
        en = n;
    }
    result: str = "";
    i: int = st;
    while i < en {
        result = result + s[i];
        i = i + 1;
    }
    return result;
}

"""Return true if `c` is an ASCII decimal digit."""
def _is_digit(c: str) -> bool {
    return c >= "0" and c <= "9";
}

"""Return true if `c` is a valid hexadecimal digit."""
def _is_hex_digit(c: str) -> bool {
    return (c >= "0" and c <= "9")
        or (c >= "a" and c <= "f")
        or (c >= "A" and c <= "F");
}

"""Return the numeric value (0–15) of a single hex digit. Assumes `_is_hex_digit(c)`."""
def _lex_hex_val(c: str) -> int {
    if c >= "0" and c <= "9" {
        return ord(c) - 48;
    }
    if c >= "a" and c <= "f" {
        return ord(c) - 97 + 10;
    }
    return ord(c) - 65 + 10;
}

"""Encode a Unicode code point as a UTF-8 byte string (mirrors
runtime.jsstring.utf8_encode_scalar; kept local so the lexer imports only mem)."""
def _lex_utf8_cp(cp: int) -> str {
    # the NUL sentinel C0 80, not a real NUL byte — see jsstring.nul_sentinel.
    if cp == 0 {
        return byte_chr(192) + byte_chr(128);
    }
    if cp < 0 or cp > 1114111 {
        return "?";
    }
    return chr(cp);
}

"""
Decode the UTF-8 code point starting at byte `pos` in `s`.
Returns [code_point, byte_length].  On a malformed/truncated sequence, returns
the raw lead byte as the code point with length 1 (lenient — the lexer then
treats it as a non-identifier byte).  Pure-ASCII bytes return [byte, 1].
"""
def _lex_utf8_decode_at(s: str, pos: int) -> list[int] {
    n: int = len(s);
    if pos >= n {
        return [0, 0];
    }
    b0: int = ord(s[pos]);
    if b0 < 128 {
        return [b0, 1];
    }
    # 2-byte: 110xxxxx 10xxxxxx
    if b0 >= 192 and b0 < 224 and pos + 1 < n {
        b1: int = ord(s[pos + 1]);
        if b1 >= 128 and b1 < 192 {
            return [((b0 & 31) << 6) | (b1 & 63), 2];
        }
    }
    # 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
    if b0 >= 224 and b0 < 240 and pos + 2 < n {
        c1: int = ord(s[pos + 1]);
        c2: int = ord(s[pos + 2]);
        if c1 >= 128 and c1 < 192 and c2 >= 128 and c2 < 192 {
            return [((b0 & 15) << 12) | ((c1 & 63) << 6) | (c2 & 63), 3];
        }
    }
    # 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    if b0 >= 240 and b0 < 248 and pos + 3 < n {
        d1: int = ord(s[pos + 1]);
        d2: int = ord(s[pos + 2]);
        d3: int = ord(s[pos + 3]);
        if d1 >= 128
            and d1 < 192
            and d2 >= 128
            and d2 < 192
            and d3 >= 128
            and d3 < 192 {
            return [
                ((b0 & 7) << 18) | ((d1 & 63) << 12) | ((d2 & 63) << 6) | (d3 & 63),
                4
            ];
        }
    }
    return [b0, 1];
}

"""
Return true if Unicode code point `cp` is JS whitespace (WhiteSpace production,
ES §12.2): TAB/VT/FF/SP (ASCII, handled separately), plus NBSP (U+00A0),
ZWNBSP/BOM (U+FEFF), and the Unicode "Space_Separator" (Zs) code points.
"""
def _is_unicode_space_cp(cp: int) -> bool {
    if cp == 0x00A0 {
        return True;
    }  # NO-BREAK SPACE
    if cp == 0xFEFF {
        return True;
    }  # ZERO WIDTH NO-BREAK SPACE (BOM)
    if cp == 0x1680 {
        return True;
    }  # OGHAM SPACE MARK
    if cp >= 0x2000 and cp <= 0x200A {
        return True;
    }  # EN QUAD … HAIR SPACE
    if cp == 0x202F {
        return True;
    }  # NARROW NO-BREAK SPACE
    if cp == 0x205F {
        return True;
    }  # MEDIUM MATHEMATICAL SPACE
    if cp == 0x3000 {
        return True;
    }  # IDEOGRAPHIC SPACE
    return False;
}

"""
Return true if Unicode code point `cp` is a JS LineTerminator (ES §12.3):
LF, CR (ASCII, handled separately), LINE SEPARATOR (U+2028), PARAGRAPH
SEPARATOR (U+2029).
"""
def _is_unicode_newline_cp(cp: int) -> bool {
    return cp == 0x2028 or cp == 0x2029;
}

"""
Return true if non-ASCII code point `cp` may begin/continue a JS identifier.
Pragmatic: accept any non-ASCII scalar that is not Unicode whitespace / a line
terminator (full ID_Start/ID_Continue tables not used).  ASCII is handled by the
byte-level _is_id_start/_is_id_cont; this is only consulted for cp >= 128.
"""
def _is_unicode_id_cp(cp: int) -> bool {
    if cp < 128 {
        return False;
    }
    if _is_unicode_space_cp(cp) {
        return False;
    }
    if _is_unicode_newline_cp(cp) {
        return False;
    }
    return True;
}

"""Return true if `c` is a binary digit (0 or 1)."""
def _is_bin_digit(c: str) -> bool {
    return c == "0" or c == "1";
}

"""Return true if `c` is an octal digit (0–7)."""
def _is_oct_digit(c: str) -> bool {
    return c >= "0" and c <= "7";
}

"""Return true if `c` is a ASCII letter or underscore."""
def _is_alpha(c: str) -> bool {
    return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_";
}

"""
Return true if `c` can start a JS identifier.
Covers ASCII letters, underscore, dollar sign, and the common Unicode ranges
(simplified to ASCII; full Unicode support not yet implemented).
"""
def _is_id_start(c: str) -> bool {
    return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c == "$";
}

"""Return true if `c` can continue a JS identifier (start chars + digits)."""
def _is_id_cont(c: str) -> bool {
    return _is_id_start(c) or (c >= "0" and c <= "9");
}

"""Hoisted chr() control-byte singletons — chr() allocates a fresh string per
call, and _is_space/_is_newline run per source character (a multi-MB bundle
paid 4 allocations per char just for whitespace tests). Jac native string
literals do not reliably interpret backslash-x hex escapes (VT/FF were
silently never matched), hence chr() rather than literals. chr(9)=TAB,
11=VT, 12=FF, 13=CR."""
glob _CH_TAB: str = chr(9);
glob _CH_VT: str = chr(11),
     _CH_FF: str = chr(12),
     _CH_CR: str = chr(13);

"""Single bytes of U+2028 LINE SEPARATOR (E2 80 A8) and U+2029 PARAGRAPH
SEPARATOR (E2 80 A9), sliced out of their UTF-8 encodings. `chr(226)` is not
the byte 0xE2: chr UTF-8-encodes code points >= 128 (C3 A2)."""
glob _B_E2: str = chr(8232)[0:1];
glob _B_80: str = chr(8232)[1:2],
     _B_A8: str = chr(8232)[2:3],
     _B_A9: str = chr(8233)[2:3];

"""Return true if `c` is ASCII whitespace (excluding newlines)."""
def _is_space(c: str) -> bool {
    if c == " " {
        return True;
    }
    # Comparing against a literal is inline; against a glob it is a memcmp call.
    # Only control bytes (below " ") can be TAB/VT/FF/CR, so screen the rest out.
    if not (c < " ") {
        return False;
    }
    return c == _CH_TAB or c == _CH_VT or c == _CH_FF or c == _CH_CR;
}

"""Return true if `c` is a JS LineTerminator character."""
def _is_newline(c: str) -> bool {
    return c == "\n" or (c < " " and c == _CH_CR);
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Keyword lookup
# ══════════════════════════════════════════════════════════════════════════════

"""
Map a scanned identifier string to its keyword TokenType, or return
TokenType.Identifier if the string is not a reserved word.
"""
def:pub keyword_type(s: str) -> TokenType {
    if s == "var" {
        return TokenType.KwVar;
    } elif s == "let" {
        return TokenType.KwLet;
    } elif s == "const" {
        return TokenType.KwConst;
    } elif s == "function" {
        return TokenType.KwFunction;
    } elif s == "class" {
        return TokenType.KwClass;
    } elif s == "if" {
        return TokenType.KwIf;
    } elif s == "else" {
        return TokenType.KwElse;
    } elif s == "for" {
        return TokenType.KwFor;
    } elif s == "while" {
        return TokenType.KwWhile;
    } elif s == "do" {
        return TokenType.KwDo;
    } elif s == "return" {
        return TokenType.KwReturn;
    } elif s == "new" {
        return TokenType.KwNew;
    } elif s == "delete" {
        return TokenType.KwDelete;
    } elif s == "typeof" {
        return TokenType.KwTypeof;
    } elif s == "void" {
        return TokenType.KwVoid;
    } elif s == "in" {
        return TokenType.KwIn;
    } elif s == "of" {
        return TokenType.KwOf;
    } elif s == "import" {
        return TokenType.KwImport;
    } elif s == "export" {
        return TokenType.KwExport;
    } elif s == "default" {
        return TokenType.KwDefault;
    } elif s == "from" {
        return TokenType.KwFrom;
    } elif s == "as" {
        return TokenType.KwAs;
    } elif s == "extends" {
        return TokenType.KwExtends;
    } elif s == "super" {
        return TokenType.KwSuper;
    } elif s == "this" {
        return TokenType.KwThis;
    } elif s == "yield" {
        return TokenType.KwYield;
    } elif s == "async" {
        return TokenType.KwAsync;
    } elif s == "await" {
        return TokenType.KwAwait;
    } elif s == "static" {
        return TokenType.KwStatic;
    } elif s == "get" {
        return TokenType.KwGet;
    } elif s == "set" {
        return TokenType.KwSet;
    } elif s == "try" {
        return TokenType.KwTry;
    } elif s == "catch" {
        return TokenType.KwCatch;
    } elif s == "finally" {
        return TokenType.KwFinally;
    } elif s == "throw" {
        return TokenType.KwThrow;
    } elif s == "switch" {
        return TokenType.KwSwitch;
    } elif s == "case" {
        return TokenType.KwCase;
    } elif s == "break" {
        return TokenType.KwBreak;
    } elif s == "continue" {
        return TokenType.KwContinue;
    } elif s == "with" {
        return TokenType.KwWith;
    } elif s == "debugger" {
        return TokenType.KwDebugger;
    } elif s == "instanceof" {
        return TokenType.KwInstanceof;
    } elif s == "true" {
        return TokenType.KwTrue;
    } elif s == "false" {
        return TokenType.KwFalse;
    } elif s == "null" {
        return TokenType.KwNull;
    } elif s == "undefined" {
        return TokenType.KwUndefined;
    } else {
        return TokenType.Identifier;
    }
}

"""Return true if the given TokenType is a keyword variant."""
def:pub is_keyword(tt: TokenType) -> bool {
    return tt == TokenType.KwVar
        or tt == TokenType.KwLet
        or tt == TokenType.KwConst
        or tt == TokenType.KwFunction
        or tt == TokenType.KwClass
        or tt == TokenType.KwIf
        or tt == TokenType.KwElse
        or tt == TokenType.KwFor
        or tt == TokenType.KwWhile
        or tt == TokenType.KwDo
        or tt == TokenType.KwReturn
        or tt == TokenType.KwNew
        or tt == TokenType.KwDelete
        or tt == TokenType.KwTypeof
        or tt == TokenType.KwVoid
        or tt == TokenType.KwIn
        or tt == TokenType.KwOf
        or tt == TokenType.KwImport
        or tt == TokenType.KwExport
        or tt == TokenType.KwDefault
        or tt == TokenType.KwFrom
        or tt == TokenType.KwAs
        or tt == TokenType.KwExtends
        or tt == TokenType.KwSuper
        or tt == TokenType.KwThis
        or tt == TokenType.KwYield
        or tt == TokenType.KwAsync
        or tt == TokenType.KwAwait
        or tt == TokenType.KwStatic
        or tt == TokenType.KwGet
        or tt == TokenType.KwSet
        or tt == TokenType.KwTry
        or tt == TokenType.KwCatch
        or tt == TokenType.KwFinally
        or tt == TokenType.KwThrow
        or tt == TokenType.KwSwitch
        or tt == TokenType.KwCase
        or tt == TokenType.KwBreak
        or tt == TokenType.KwContinue
        or tt == TokenType.KwWith
        or tt == TokenType.KwDebugger
        or tt == TokenType.KwInstanceof
        or tt == TokenType.KwTrue
        or tt == TokenType.KwFalse
        or tt == TokenType.KwNull
        or tt == TokenType.KwUndefined;
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Lexer object
# ══════════════════════════════════════════════════════════════════════════════

"""
JavaScript / TypeScript lexer.

Usage:
    lx: Lexer = make_lexer(source_code);
    tokens: list[Token] = lx.tokenize();

Or incrementally:
    lx: Lexer = make_lexer(source_code);
    while True {
        tok: Token = lx.next_token();
        if tok.ttype == TokenType.EOF { break; }
        # use tok
    }
"""
obj:pub Lexer {
    has source: str,
        source_len: int = 0,
        pos: int = 0,
        line: int = 1,
        col: int = 1,
        _had_newline: bool = False,
        _regexp_mode: bool = True,
        _tmpl_depth: int = 0,
        _tmpl_stack: list[int] = [];

    # ── Low-level position helpers ─────────────────────────────────────────

    """Return the character at the current position, or "" at EOF."""
    def _cur -> str {
        if self.pos >= self.source_len {
            return "";
        }
        return self.source[self.pos];
    }

    """Look ahead by `offset` characters without consuming."""
    def _peek(offset: int) -> str {
        p: int = self.pos + offset;
        if p < 0 or p >= self.source_len {
            return "";
        }
        return self.source[p];
    }

    """Consume and return the current character, advancing pos and col."""
    def _advance -> str {
        if self.pos >= self.source_len {
            return "";
        }
        c: str = self.source[self.pos];
        self.pos = self.pos + 1;
        if c == "\n" {
            self.line = self.line + 1;
            self.col = 1;
        } elif c < " " and c == _CH_CR {
            # \r\n counts as one line break
            if self.pos < self.source_len and self.source[self.pos] == "\n" {
                self.pos = self.pos + 1;
            }
            self.line = self.line + 1;
            self.col = 1;
        } else {
            self.col = self.col + 1;
        }
        return c;
    }

    """
    Skip whitespace (spaces, tabs, form-feed) and JS comments.
    Sets `_had_newline` to True if any LineTerminator was encountered.
    """
    def _skip_ws {
        self._had_newline = False;
        cont: bool = True;
        while cont and self.pos < self.source_len {
            c: str = self._cur();

            if _is_space(c) {
                self._advance();
            } elif _is_newline(c) {
                self._had_newline = True;
                self._advance();
            } elif c == "/" {
                # Check for comments
                nxt: str = self._peek(1);
                if nxt == "/" {
                    # Line comment: skip until LineTerminator
                    self._advance();  # /
                    self._advance();  # /
                    while self.pos < self.source_len and not _is_newline(self._cur()) {
                        self._advance();
                    }
                } elif nxt == "*" {
                    # Block comment: skip until */
                    self._advance();  # /
                    self._advance();  # *
                    found: bool = False;
                    while not found and self.pos < self.source_len {
                        cc: str = self._cur();
                        if cc == "*" and self._peek(1) == "/" {
                            self._advance();  # *
                            self._advance();  # /
                            found = True;
                        } elif _is_newline(cc) {
                            self._had_newline = True;
                            self._advance();
                        } else {
                            self._advance();
                        }
                    }
                } else {
                    cont = False;
                }
            } elif ord(c) >= 128 {
                # Non-ASCII: may be Unicode whitespace (NBSP, Zs, BOM) or a Unicode
                # line terminator (U+2028 / U+2029).  Decode and skip if so.
                ws_arr: list[int] = _lex_utf8_decode_at(self.source, self.pos);
                ws_cp: int = ws_arr[0];
                ws_len: int = ws_arr[1];
                if ws_len > 0 and _is_unicode_newline_cp(ws_cp) {
                    self._had_newline = True;
                    wk: int = 0;
                    while wk < ws_len {
                        self._advance();
                        wk = wk + 1;
                    }
                } elif ws_len > 0 and _is_unicode_space_cp(ws_cp) {
                    wk2: int = 0;
                    while wk2 < ws_len {
                        self._advance();
                        wk2 = wk2 + 1;
                    }
                } else {
                    cont = False;
                }
            } else {
                cont = False;
            }
        }
    }

    """Build a Token from its parts."""
    def _tok(tt: TokenType, value: str, start_line: int, start_col: int) -> Token {
        end_off: int = self.pos;
        start_off: int = end_off - len(value);
        if start_off < 0 {
            start_off = 0;
        }
        tok: Token = Token(
            ttype=tt,
            value=value,
            line=start_line,
            col=start_col,
            start_offset=start_off,
            end_offset=end_off
        );
        tok.has_newline_before = self._had_newline;
        return tok;
    }

    # ── Identifier / keyword scanner ───────────────────────────────────────

    """
    Decode a Unicode escape (`\\uXXXX` or `\\u{...}`) appearing in an
    IdentifierName / PrivateName.  Assumes `self.pos` points at the backslash.
    Consumes the whole escape (advancing pos/col) and returns the decoded
    character as a UTF-8 string.  Returns "" on a malformed escape (caller
    treats that as the end of the identifier).
    ECMAScript §12.7.1 — IdentifierName may contain UnicodeEscapeSequence.
    """
    def _decode_id_unicode_escape -> str {
        # Expect: \ u ...
        if self._cur() != "\\" or self._peek(1) != "u" {
            return "";
        }
        self._advance();  # backslash
        self._advance();  # u
        cp: int = 0;
        if self._cur() == "{" {
            # \u{ HexDigits }
            self._advance();  # {
            ndig: int = 0;
            while self.pos < self.source_len and _is_hex_digit(self._cur()) {
                cp = cp * 16 + _lex_hex_val(self._cur());
                self._advance();
                ndig = ndig + 1;
            }
            if self._cur() != "}" or ndig == 0 or cp > 1114111 {
                return "";
            }
            self._advance();  # }
        } else {
            # \u HexDigit HexDigit HexDigit HexDigit
            k: int = 0;
            while k < 4 {
                if not _is_hex_digit(self._cur()) {
                    return "";
                }
                cp = cp * 16 + _lex_hex_val(self._cur());
                self._advance();
                k = k + 1;
            }
        }
        return _lex_utf8_cp(cp);
    }

    """Scan an identifier or keyword starting at the current position.
    Handles Unicode escapes (`\\uXXXX` / `\\u{...}`) within the identifier."""
    def _scan_ident -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        # append+join, not per-char concat — see _scan_string.
        vparts: list[str] = [];
        had_escape: bool = False;
        running: bool = True;
        while running and self.pos < self.source_len {
            c: str = self._cur();
            if c == "\\" and self._peek(1) == "u" {
                dec: str = self._decode_id_unicode_escape();
                if dec == "" {
                    running = False;
                } else {
                    vparts.append(dec);
                    had_escape = True;
                }
            } elif ord(c) < 128 {
                if _is_id_cont(c) {
                    vparts.append(self._advance());
                } else {
                    running = False;
                }
            } else {
                # Non-ASCII: decode the full UTF-8 code point and accept it as an
                # identifier part if it isn't whitespace / a line terminator.
                dec_arr: list[int] = _lex_utf8_decode_at(self.source, self.pos);
                cp_id: int = dec_arr[0];
                cp_len: int = dec_arr[1];
                if cp_len > 0 and _is_unicode_id_cp(cp_id) {
                    bk: int = 0;
                    while bk < cp_len {
                        vparts.append(self._advance());
                        bk = bk + 1;
                    }
                } else {
                    running = False;
                }
            }
        }
        value: str = "".join(vparts);
        # ES §12.7.1: an IdentifierName that contains a Unicode escape is never a
        # ReservedWord — `let`, `await`, `yield`, etc. are plain
        # identifiers even though their decoded spelling matches a keyword.
        tt: TokenType = TokenType.Identifier;
        if not had_escape {
            tt = keyword_type(value);
        }
        return self._tok(tt, value, start_line, start_col);
    }

    # ── Number scanner ─────────────────────────────────────────────────────

    """
    Scan a numeric literal (integer, float, hex, octal, binary, BigInt).
    Returns a NumericLiteral or BigIntLiteral token.
    The `value` field holds the raw source text.
    """
    def _scan_number -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        raw: str = "";
        is_bigint: bool = False;

        c0: str = self._cur();
        c1: str = self._peek(1);

        if c0 == "0" and (c1 == "x" or c1 == "X") {
            # Hexadecimal  0x...
            raw = raw + self._advance();  # 0
            raw = raw + self._advance();  # x/X
            while self.pos < self.source_len
                and (_is_hex_digit(self._cur()) or self._cur() == "_") {
                raw = raw + self._advance();
            }
        } elif c0 == "0" and (c1 == "o" or c1 == "O") {
            # Octal  0o...
            raw = raw + self._advance();  # 0
            raw = raw + self._advance();  # o/O
            while self.pos < self.source_len
                and (_is_oct_digit(self._cur()) or self._cur() == "_") {
                raw = raw + self._advance();
            }
        } elif c0 == "0" and (c1 == "b" or c1 == "B") {
            # Binary  0b...
            raw = raw + self._advance();  # 0
            raw = raw + self._advance();  # b/B
            while self.pos < self.source_len
                and (_is_bin_digit(self._cur()) or self._cur() == "_") {
                raw = raw + self._advance();
            }
        } else {
            # Decimal integer part (also handles leading `.` via caller check)
            while self.pos < self.source_len
                and (_is_digit(self._cur()) or self._cur() == "_") {
                raw = raw + self._advance();
            }
            # Optional fractional part.  A trailing `.` with no following digits is a
            # valid DecimalLiteral (`1.` === 1, `1.e1` === 10), so consume the `.` as
            # the decimal point unconditionally.  `1..toString()` then tokenizes as the
            # number `1.` followed by `.toString()`; `1.5` consumes the fraction digits.
            if self.pos < self.source_len and self._cur() == "." {
                raw = raw + self._advance();  # .
                while self.pos < self.source_len
                    and (_is_digit(self._cur()) or self._cur() == "_") {
                    raw = raw + self._advance();
                }
            }
            # Optional exponent
            if self.pos < self.source_len
                and (self._cur() == "e" or self._cur() == "E") {
                raw = raw + self._advance();  # e/E
                if self.pos < self.source_len
                    and (self._cur() == "+" or self._cur() == "-") {
                    raw = raw + self._advance();
                }
                while self.pos < self.source_len
                    and (_is_digit(self._cur()) or self._cur() == "_") {
                    raw = raw + self._advance();
                }
            }
        }

        # BigInt suffix
        if self.pos < self.source_len and self._cur() == "n" {
            raw = raw + self._advance();
            is_bigint = True;
        }

        if is_bigint {
            return self._tok(TokenType.BigIntLiteral, raw, start_line, start_col);
        }
        return self._tok(TokenType.NumericLiteral, raw, start_line, start_col);
    }

    # ── String literal scanner ─────────────────────────────────────────────

    """
    Scan a single- or double-quoted string literal.
    `quote` is the opening quote character (' or ").
    The token value is the raw content between the quotes (escapes not processed).
    """
    def _scan_string(quote: str) -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        self._advance();  # consume opening quote
        # Per-char `raw = raw + c` concat is O(n²) bytes per literal (a multi-KB
        # minified/inlined literal allocated MBs); chars from _advance() are
        # char-cache singletons, so append + one join is O(n) with no copies.
        parts: list[str] = [];
        closed: bool = False;

        while self.pos < self.source_len and not closed {
            c: str = self._cur();
            if c == quote {
                self._advance();  # closing quote
                closed = True;
            } elif c == "\\" {
                # Escape sequence — consume both \ and next char raw
                parts.append(self._advance());  # backslash
                if self.pos < self.source_len {
                    parts.append(self._advance());  # escaped char
                }
            } elif _is_newline(c) {
                # Unterminated string — stop here (error recovery)
                closed = True;
            } else {
                parts.append(self._advance());
            }
        }

        return self._tok(
            TokenType.StringLiteral, "".join(parts), start_line, start_col
        );
    }

    # ── Template literal scanner ───────────────────────────────────────────

    """
    Scan a template literal opened with a backtick.

    Returns one of:
      TemplateLiteral  — simple `str` with no interpolation
      TemplateHead     — `head${ (first chunk of an interpolated template)

    After a TemplateHead the parser is responsible for scanning the
    interpolated expression.  When `}` closes the expression, the parser calls
    `scan_template_continuation()` which returns TemplateMiddle or TemplateTail.
    """
    def _scan_template_open -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        self._advance();  # consume opening `
        # append+join, not per-char concat — see _scan_string.
        parts: list[str] = [];

        while self.pos < self.source_len {
            c: str = self._cur();
            if c == "`" {
                self._advance();  # closing `
                return self._tok(
                    TokenType.TemplateLiteral, "".join(parts), start_line, start_col
                );
            } elif c == "$" and self._peek(1) == "{" {
                self._advance();  # $
                self._advance();  # {
                self._tmpl_stack.append(self._tmpl_depth);
                self._tmpl_depth = 1;  # entering ${...} interpolation
                return self._tok(
                    TokenType.TemplateHead, "".join(parts), start_line, start_col
                );
            } elif c == "\\" {
                parts.append(self._advance());  # backslash
                if self.pos < self.source_len {
                    parts.append(self._advance());
                }
            } else {
                parts.append(self._advance());
            }
        }
        # Unterminated template — return what we have
        return self._tok(
            TokenType.TemplateLiteral, "".join(parts), start_line, start_col
        );
    }

    """
    Scan the continuation of a template literal after `}` closes an expression.
    Returns TemplateMiddle (more interpolations follow) or TemplateTail (done).
    Called by the parser after consuming the closing `}` of an interpolation.
    """
    def scan_template_continuation -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        # append+join, not per-char concat — see _scan_string.
        parts: list[str] = [];

        while self.pos < self.source_len {
            c: str = self._cur();
            if c == "`" {
                self._advance();
                return self._tok(
                    TokenType.TemplateTail, "".join(parts), start_line, start_col
                );
            } elif c == "$" and self._peek(1) == "{" {
                self._advance();  # $
                self._advance();  # {
                return self._tok(
                    TokenType.TemplateMiddle, "".join(parts), start_line, start_col
                );
            } elif c == "\\" {
                parts.append(self._advance());
                if self.pos < self.source_len {
                    parts.append(self._advance());
                }
            } else {
                parts.append(self._advance());
            }
        }
        return self._tok(TokenType.TemplateTail, "".join(parts), start_line, start_col);
    }

    # ── RegExp literal scanner ─────────────────────────────────────────────

    """True if the current position begins a LineTerminator: LF, CR, or the
    multi-byte U+2028 LINE SEPARATOR (E2 80 A8) / U+2029 PARAGRAPH SEPARATOR
    (E2 80 A9).  The source is UTF-8 bytes, so LS/PS are matched by their byte
    sequence (unlike `_is_newline`, which only sees a single ASCII byte)."""
    def _at_line_terminator -> bool {
        c: str = self._cur();
        if c == "\n" or c == _CH_CR {
            return True;
        }
        if c == _B_E2 and self._peek(1) == _B_80 {
            b3: str = self._peek(2);
            if b3 == _B_A8 or b3 == _B_A9 {
                return True;
            }
        }
        return False;
    }

    """
    Scan a regular expression literal /pattern/flags.
    Called when `_regexp_mode` is true and the current char is `/`.
    Returns a RegExpLiteral token whose value is the full raw text /pat/flags.
    """
    def _scan_regexp -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        raw: str = "";
        raw = raw + self._advance();  # opening /
        in_class: bool = False;

        # A RegularExpressionLiteral may not contain a LineTerminator (ES §12.9.5):
        # LF, CR, or the multi-byte LS (U+2028 = E2 80 A8) / PS (U+2029 = E2 80 A9).
        # Reaching one before the closing `/` leaves the literal unterminated, which
        # the parser reports as a SyntaxError.  A `\` followed by a LineTerminator is
        # likewise invalid (no closing `/` on the line).
        closed: bool = False;
        while self.pos < self.source_len and not closed {
            c: str = self._cur();
            if c == "[" {
                in_class = True;
                raw = raw + self._advance();
            } elif c == "]" and in_class {
                in_class = False;
                raw = raw + self._advance();
            } elif c == "/" and not in_class {
                raw = raw + self._advance();  # closing /
                closed = True;
            } elif c == "\\" {
                raw = raw + self._advance();
                # `\<LineTerminator>` is not a valid RegExp BackslashSequence — leave
                # the literal unterminated (SyntaxError) rather than consuming it.
                if self.pos < self.source_len and not self._at_line_terminator() {
                    raw = raw + self._advance();
                }
            } elif _is_newline(c) or self._at_line_terminator() {
                # Unterminated regexp (raw LineTerminator, incl. LS/PS) — stop.
                closed = True;
            } else {
                raw = raw + self._advance();
            }
        }

        # Flags
        while self.pos < self.source_len and _is_id_cont(self._cur()) {
            raw = raw + self._advance();
        }

        return self._tok(TokenType.RegExpLiteral, raw, start_line, start_col);
    }

    # ── Operator / punctuation scanner ────────────────────────────────────

    """
    Scan operators and punctuation at the current position.
    Handles all multi-character operator sequences.
    """
    def _scan_op -> Token {
        start_line: int = self.line;
        start_col: int = self.col;
        c0: str = self._cur();

        # ── ( ) { } [ ] ; , @ ─────────────────────────────────────────────
        if c0 == "(" {
            self._advance();
            return self._tok(TokenType.LParen, "(", start_line, start_col);
        } elif c0 == ")" {
            self._advance();
            return self._tok(TokenType.RParen, ")", start_line, start_col);
        } elif c0 == "{" {
            self._advance();
            if self._tmpl_depth > 0 {
                self._tmpl_depth = self._tmpl_depth + 1;
            }
            return self._tok(TokenType.LBrace, "{", start_line, start_col);
        } elif c0 == "}" {
            if self._tmpl_depth > 1 {
                # Nested brace inside a template expression — just decrement.
                self._tmpl_depth = self._tmpl_depth - 1;
                self._advance();
                return self._tok(TokenType.RBrace, "}", start_line, start_col);
            }
            if self._tmpl_depth == 1 {
                # Closing brace of a ${…} interpolation — switch to template continuation.
                self._tmpl_depth = 0;
                self._advance();  # consume }
                nt_cont: Token = self.scan_template_continuation();
                self._update_regexp_mode_for_tok(nt_cont.ttype);
                # If continuation is TemplateMiddle, another ${ follows in the same template.
                if nt_cont.ttype == TokenType.TemplateMiddle {
                    self._tmpl_depth = 1;
                } else {
                    if len(self._tmpl_stack) > 0 {
                        self._tmpl_depth = self._tmpl_stack[len(self._tmpl_stack) - 1];
                        del self._tmpl_stack[len(self._tmpl_stack) - 1];
                    }
                }
                return nt_cont;
            }
            # _tmpl_depth == 0 — normal brace
            self._advance();
            return self._tok(TokenType.RBrace, "}", start_line, start_col);
        } elif c0 == "[" {
            self._advance();
            return self._tok(TokenType.LBracket, "[", start_line, start_col);
        } elif c0 == "]" {
            self._advance();
            return self._tok(TokenType.RBracket, "]", start_line, start_col);
        } elif c0 == ";" {
            self._advance();
            return self._tok(TokenType.Semicolon, ";", start_line, start_col);
        } elif c0 == "," {
            self._advance();
            return self._tok(TokenType.Comma, ",", start_line, start_col);
        } elif c0 == ":" {
            self._advance();
            return self._tok(TokenType.Colon, ":", start_line, start_col);
        } elif c0 == "@" {
            self._advance();
            return self._tok(TokenType.At, "@", start_line, start_col);
        } elif c0 == "~" {
            self._advance();
            return self._tok(TokenType.Tilde, "~", start_line, start_col);

            # ── . or ... ──────────────────────────────────────────────────────
        } elif c0 == "." {
            if self._peek(1) == "." and self._peek(2) == "." {
                self._advance();
                self._advance();
                self._advance();
                return self._tok(TokenType.DotDotDot, "...", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Dot, ".", start_line, start_col);

            # ── + ++ += ───────────────────────────────────────────────────────
        } elif c0 == "+" {
            c1: str = self._peek(1);
            if c1 == "+" {
                self._advance();
                self._advance();
                return self._tok(TokenType.PlusPlus, "++", start_line, start_col);
            } elif c1 == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.PlusEq, "+=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Plus, "+", start_line, start_col);

            # ── - -- -= ───────────────────────────────────────────────────────
        } elif c0 == "-" {
            c1b: str = self._peek(1);
            if c1b == "-" {
                self._advance();
                self._advance();
                return self._tok(TokenType.MinusMinus, "--", start_line, start_col);
            } elif c1b == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.MinusEq, "-=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Minus, "-", start_line, start_col);

            # ── * ** *= **= ───────────────────────────────────────────────────
        } elif c0 == "*" {
            c1c: str = self._peek(1);
            if c1c == "*" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(
                        TokenType.StarStarEq, "**=", start_line, start_col
                    );
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.StarStar, "**", start_line, start_col);
            } elif c1c == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.StarEq, "*=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Star, "*", start_line, start_col);

            # ── / /= (or division — regexp handled in next_token) ─────────────
        } elif c0 == "/" {
            if self._peek(1) == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.SlashEq, "/=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Slash, "/", start_line, start_col);

            # ── % %= ──────────────────────────────────────────────────────────
        } elif c0 == "%" {
            if self._peek(1) == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.PercentEq, "%=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Percent, "%", start_line, start_col);

            # ── & && &&= &= ───────────────────────────────────────────────────
        } elif c0 == "&" {
            c1d: str = self._peek(1);
            if c1d == "&" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(TokenType.AmpAmpEq, "&&=", start_line, start_col);
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.AmpAmp, "&&", start_line, start_col);
            } elif c1d == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.AmpEq, "&=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Amp, "&", start_line, start_col);

            # ── | || ||= |= ───────────────────────────────────────────────────
        } elif c0 == "|" {
            c1e: str = self._peek(1);
            if c1e == "|" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(
                        TokenType.PipePipeEq, "||=", start_line, start_col
                    );
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.PipePipe, "||", start_line, start_col);
            } elif c1e == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.PipeEq, "|=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Pipe, "|", start_line, start_col);

            # ── ^ ^= ──────────────────────────────────────────────────────────
        } elif c0 == "^" {
            if self._peek(1) == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.CaretEq, "^=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Caret, "^", start_line, start_col);

            # ── ! != !== ──────────────────────────────────────────────────────
        } elif c0 == "!" {
            c1f: str = self._peek(1);
            if c1f == "=" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(TokenType.BangEqEq, "!==", start_line, start_col);
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.BangEq, "!=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Bang, "!", start_line, start_col);

            # ── < << <<= <= ───────────────────────────────────────────────────
        } elif c0 == "<" {
            c1g: str = self._peek(1);
            if c1g == "<" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(TokenType.LtLtEq, "<<=", start_line, start_col);
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.LtLt, "<<", start_line, start_col);
            } elif c1g == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.LtEq, "<=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Lt, "<", start_line, start_col);

            # ── > >> >>= >>> >>>= >= ──────────────────────────────────────────
        } elif c0 == ">" {
            c1h: str = self._peek(1);
            if c1h == ">" {
                c2h: str = self._peek(2);
                if c2h == ">" {
                    if self._peek(3) == "=" {
                        self._advance();
                        self._advance();
                        self._advance();
                        self._advance();
                        return self._tok(
                            TokenType.GtGtGtEq, ">>>=", start_line, start_col
                        );
                    }
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(TokenType.GtGtGt, ">>>", start_line, start_col);
                } elif c2h == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(TokenType.GtGtEq, ">>=", start_line, start_col);
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.GtGt, ">>", start_line, start_col);
            } elif c1h == "=" {
                self._advance();
                self._advance();
                return self._tok(TokenType.GtEq, ">=", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Gt, ">", start_line, start_col);

            # ── = == === => ───────────────────────────────────────────────────
        } elif c0 == "=" {
            c1i: str = self._peek(1);
            if c1i == "=" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(TokenType.EqEqEq, "===", start_line, start_col);
                }
                self._advance();
                self._advance();
                return self._tok(TokenType.EqEq, "==", start_line, start_col);
            } elif c1i == ">" {
                self._advance();
                self._advance();
                return self._tok(TokenType.Arrow, "=>", start_line, start_col);
            }
            self._advance();
            return self._tok(TokenType.Eq, "=", start_line, start_col);

            # ── ? ?. ?? ??= ───────────────────────────────────────────────────
        } elif c0 == "?" {
            c1j: str = self._peek(1);
            if c1j == "." and not _is_digit(self._peek(2)) {
                self._advance();
                self._advance();
                return self._tok(TokenType.QuestionDot, "?.", start_line, start_col);
            } elif c1j == "?" {
                if self._peek(2) == "=" {
                    self._advance();
                    self._advance();
                    self._advance();
                    return self._tok(
                        TokenType.QuestionQuestionEq, "??=", start_line, start_col
                    );
                }
                self._advance();
                self._advance();
                return self._tok(
                    TokenType.QuestionQuestion, "??", start_line, start_col
                );
            }
            self._advance();
            return self._tok(TokenType.Question, "?", start_line, start_col);
        }

        # Unknown character — emit Error token and skip it
        bad: str = self._advance();
        return self._tok(TokenType.Error, bad, start_line, start_col);
    }

    # ── Public API ─────────────────────────────────────────────────────────

    """
    Update the regexp-vs-division context hint.
    The parser should call this after each produced token:
      - regexp_mode = True  after any operator, keyword, `(`, `[`, `=`, ...
      - regexp_mode = False after a literal, identifier, `)`, `]`
    """
    def set_regexp_mode(v: bool) {
        self._regexp_mode = v;
    }

    """
    Update _regexp_mode automatically based on the token type just produced.
    After expression-ending tokens, '/' must be treated as division;
    after everything else (operators, keywords, '(' etc.) as regexp start.
    ECMAScript spec §12.2 / Annex B regex grammar.
    """
    def _update_regexp_mode_for_tok(tt: TokenType) {
        if tt == TokenType.NumericLiteral
            or tt == TokenType.BigIntLiteral
            or tt == TokenType.StringLiteral
            or tt == TokenType.TemplateLiteral
            or tt == TokenType.TemplateTail
            or tt == TokenType.RegExpLiteral
            or tt == TokenType.Identifier
            or tt == TokenType.RParen
            or tt == TokenType.RBracket
            or tt == TokenType.PlusPlus
            or tt == TokenType.MinusMinus
            or tt == TokenType.KwThis
            or tt == TokenType.KwTrue
            or tt == TokenType.KwFalse
            or tt == TokenType.KwNull
            or tt == TokenType.KwUndefined
            or tt == TokenType.PrivateName {
            # A private member access `obj.#x` ends an expression, so a following `/` is
            # division, not a regexp start (`this.#field /= 2`, test262 *-div compound-assign).
            self._regexp_mode = False;
        } else {
            self._regexp_mode = True;
        }
    }

    """
    Scan and return the next token from the source.
    Calling this after EOF always returns another EOF token.
    """
    def next_token -> Token {
        self._skip_ws();

        if self.pos >= self.source_len {
            self._regexp_mode = True;
            return self._tok(TokenType.EOF, "", self.line, self.col);
        }

        c: str = self._cur();

        # ── Private name (#identifier) ────────────────────────────────────
        # The name after `#` may begin with an identifier char, a non-ASCII
        # identifier code point (`#℘`, `#café`), or a Unicode escape
        # (`#\u{6F}` etc.), and may contain further escapes.
        pn_start_nonascii: bool = False;
        if c == "#" {
            pn_n1: str = self._peek(1);
            if ord(pn_n1) >= 128 {
                # Decode the code point at pos+1 (the byte right after `#`).
                pn_s_arr: list[int] = _lex_utf8_decode_at(self.source, self.pos + 1);
                if pn_s_arr[1] > 0 and _is_unicode_id_cp(pn_s_arr[0]) {
                    pn_start_nonascii = True;
                }
            }
        }
        if c == "#"
            and (
                _is_id_start(self._peek(1))
                or pn_start_nonascii
                or (self._peek(1) == "\\" and self._peek(2) == "u")
            ) {
            start_line: int = self.line;
            start_col: int = self.col;
            self._advance();  # skip #
            pn_body: str = "";
            pn_run: bool = True;
            while pn_run and self.pos < self.source_len {
                pc: str = self._cur();
                if pc == "\\" and self._peek(1) == "u" {
                    pn_dec: str = self._decode_id_unicode_escape();
                    if pn_dec == "" {
                        pn_run = False;
                    } else {
                        pn_body = pn_body + pn_dec;
                    }
                } elif ord(pc) < 128 {
                    if _is_id_cont(pc) {
                        pn_body = pn_body + self._advance();
                    } else {
                        pn_run = False;
                    }
                } else {
                    # Non-ASCII IdentifierPart: decode the full UTF-8 code point and
                    # accept it if it's a valid identifier continuation. Mirrors the
                    # non-ASCII branch in _scan_ident(); without this the private-name
                    # body would truncate at the first multibyte char (e.g. `#℘`),
                    # producing a key that no longer matches the public spelling.
                    pn_arr: list[int] = _lex_utf8_decode_at(self.source, self.pos);
                    pn_cp: int = pn_arr[0];
                    pn_clen: int = pn_arr[1];
                    if pn_clen > 0 and _is_unicode_id_cp(pn_cp) {
                        pn_bk: int = 0;
                        while pn_bk < pn_clen {
                            pn_body = pn_body + self._advance();
                            pn_bk = pn_bk + 1;
                        }
                    } else {
                        pn_run = False;
                    }
                }
            }
            pn_val: str = "#" + pn_body;
            nt_pn: Token = self._tok(
                TokenType.PrivateName, pn_val, start_line, start_col
            );
            self._update_regexp_mode_for_tok(nt_pn.ttype);
            return nt_pn;
        }

        # ── Identifier or keyword ──────────────────────────────────────────
        # An identifier may begin with a Unicode escape (`\u{6F}bc` ≡ `obc`) or a
        # non-ASCII identifier code point (`café`, `ω`, CJK, Cyrillic, …).
        id_start_nonascii: bool = False;
        if ord(c) >= 128 {
            ids_arr: list[int] = _lex_utf8_decode_at(self.source, self.pos);
            if ids_arr[1] > 0 and _is_unicode_id_cp(ids_arr[0]) {
                id_start_nonascii = True;
            }
        }
        if _is_id_start(c)
            or (c == "\\" and self._peek(1) == "u")
            or id_start_nonascii {
            nt_id: Token = self._scan_ident();
            self._update_regexp_mode_for_tok(nt_id.ttype);
            return nt_id;
        }

        # ── Numeric literal (or .5 decimal) ───────────────────────────────
        if _is_digit(c) {
            nt_num: Token = self._scan_number();
            self._update_regexp_mode_for_tok(nt_num.ttype);
            return nt_num;
        }
        if c == "." and _is_digit(self._peek(1)) {
            nt_dot: Token = self._scan_number();
            self._update_regexp_mode_for_tok(nt_dot.ttype);
            return nt_dot;
        }

        # ── String literals ────────────────────────────────────────────────
        if c == "\"" or c == "'" {
            nt_str: Token = self._scan_string(c);
            self._update_regexp_mode_for_tok(nt_str.ttype);
            return nt_str;
        }

        # ── Template literal ───────────────────────────────────────────────
        if c == "`" {
            nt_tpl: Token = self._scan_template_open();
            self._update_regexp_mode_for_tok(nt_tpl.ttype);
            return nt_tpl;
        }

        # ── RegExp or division ─────────────────────────────────────────────
        if c == "/" {
            if self._regexp_mode and self._peek(1) != "/" and self._peek(1) != "*" {
                nt_re: Token = self._scan_regexp();
                self._update_regexp_mode_for_tok(nt_re.ttype);
                return nt_re;
            }
        }

        # ── Operators and punctuation ─────────────────────────────────────
        nt_op: Token = self._scan_op();
        self._update_regexp_mode_for_tok(nt_op.ttype);
        return nt_op;
    }

    """
    Return the next token WITHOUT consuming it (save/restore position).
    Note: this re-runs all whitespace/comment skipping logic.
    """
    def peek_token -> Token {
        saved_pos: int = self.pos;
        saved_line: int = self.line;
        saved_col: int = self.col;
        saved_nl: bool = self._had_newline;
        saved_re: bool = self._regexp_mode;

        tok: Token = self.next_token();

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
        self._had_newline = saved_nl;
        self._regexp_mode = saved_re;

        return tok;
    }

    """
    Tokenize the entire source and return a list of Tokens (including EOF).
    """
    def tokenize -> list[Token] {
        tokens: list[Token] = [];
        all_done: bool = False;
        while not all_done {
            tok: Token = self.next_token();
            tokens.append(tok);
            if tok.ttype == TokenType.EOF {
                all_done = True;
            }
        }
        return tokens;
    }

    """Save lexer position for speculative tokenization (rewind via restore_cursor)."""
    def save_cursor -> list[int] {
        return [self.pos, self.line, self.col];
    }

    """Restore a cursor snapshot from save_cursor()."""
    def restore_cursor(snap: list[int]) {
        self.pos = snap[0];
        self.line = snap[1];
        self.col = snap[2];
    }
}

# ASI helper — set when skipping whitespace found a LineTerminator

# Parser sets this to true after tokens that begin an expression context,
# so the lexer knows '/' starts a RegExp rather than division.

# Template literal brace nesting depth.  When > 0 we are inside a `${…}`
# interpolation.  Each `{` inside the expression increments, each `}`
# decrements.  When a `}` would take us to 0 the lexer switches to
# `scan_template_continuation` instead of emitting RBrace.

# Stack of saved _tmpl_depth values for nested template literals.
# Pushed when a TemplateHead `${` is encountered (saving the outer depth),
# popped when a TemplateTail closes the matching template.
# ══════════════════════════════════════════════════════════════════════════════
# 6.  Factory
# ══════════════════════════════════════════════════════════════════════════════

"""Create a new Lexer for the given source string."""
def:pub make_lexer(source: str) -> Lexer {
    lx: Lexer = Lexer(source=source);
    lx.source_len = len(source);
    return lx;
}
