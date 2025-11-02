# flake8: noqa
"""Pygments Syntax highlighter for Jac code."""
"""
    pygments.lexers.python
    ~~~~~~~~~~~~~~~~~~~~~~

    Lexers for Python and related languages.

    :copyright: Copyright 2006-2023 by the Pygments team, see AUTHORS.
    :license: BSD, see LICENSE for details.
"""

import keyword
from pygments.lexer import (
    RegexLexer,
    include,
    bygroups,
    using,
    default,
    words,
    combined,
    this,
)
from pygments.util import shebang_matches
from pygments.token import (
    Text,
    Comment,
    Operator,
    Keyword,
    Name,
    String,
    Number,
    Punctuation,
    Whitespace,
)
from pygments import unistring as uni


class JacLexer(RegexLexer):
    """
    For Jac source code,
    Adapted from Python source code (version 3.x).
        .. versionadded:: 0.10
        .. versionchanged:: 2.5
        This is now the default ``PythonLexer``.  It is still available as the
        alias ``Python3Lexer``.
    """

    name = "Jac"
    url = "http://www.jac-lang.org"
    aliases = ["jac"]
    filenames = ["*.jac"]
    mimetypes = [
        "text/x-jac",
        "application/x-jac",
        "text/x-jac3",
    ]

    uni_name = "[%s][%s]*" % (uni.xid_start, uni.xid_continue)

    def innerstring_rules(ttype):
        return [
            # the old style '%s' % (...) string formatting (still valid in Py3)
            (
                r"%(\(\w+\))?[-#0 +]*([0-9]+|[*])?(\.([0-9]+|[*]))?"
                "[hlL]?[E-GXc-giorsaux%]",
                String.Interpol,
            ),
            # the new style '{}'.format(...) string formatting
            (
                r"\{"
                r"((\w+)((\.\w+)|(\[[^\]]+\]))*)?"  # field name
                r"(\![sra])?"  # conversion
                r"(\:(.?[<>=\^])?[-+ ]?#?0?(\d+)?,?(\.\d+)?[E-GXb-gnosx%]?)?"
                r"\}",
                String.Interpol,
            ),
            # backslashes, quotes and formatting signs must be parsed one at a time
            (r'[^\\\'"%{\n]+', ttype),
            (r'[\'"\\]', ttype),
            # unhandled string formatting sign
            (r"%|(\{{1,2})", ttype),
            # newlines are an error (use "nl" state)
        ]

    def fstring_rules(ttype):
        return [
            # Assuming that a '}' is the closing brace after format specifier.
            # Sadly, this means that we won't detect syntax error. But it's
            # more important to parse correct syntax correctly, than to
            # highlight invalid syntax.
            (r"\}", String.Interpol),
            (r"\{", String.Interpol, "expr-inside-fstring"),
            # backslashes, quotes and formatting signs must be parsed one at a time
            (r'[^\\\'"{}\n]+', ttype),
            (r'[\'"\\]', ttype),
            # newlines are an error (use "nl" state)
        ]

    tokens = {
        "root": [
            (r"\n", Whitespace),
            (
                r'^(\s*)([rRuUbB]{,2})("""(?:.|\n)*?""")',
                bygroups(Whitespace, String.Affix, String.Doc),
            ),
            (
                r"^(\s*)([rRuUbB]{,2})('''(?:.|\n)*?''')",
                bygroups(Whitespace, String.Affix, String.Doc),
            ),
            (r"\A#!.+$", Comment.Hashbang),
            (r"#\*(.|\n|\r)*?\*#", Comment.Multiline),
            (r"#.*$", Comment.Single),
            (r"\\\n", Text),
            (r"\\", Text),
            include("jsx"),
            include("keywords"),
            include("soft-keywords"),
            (r"(static\s+can)((?:\s|\\\s)+)", bygroups(Keyword, Text), "funcname"),
            (r"(static\s+def)((?:\s|\\\s)+)", bygroups(Keyword, Text), "funcname"),
            (r"(can)((?:\s|\\\s)+)", bygroups(Keyword, Text), "funcname"),
            (r"(def)((?:\s|\\\s)+)", bygroups(Keyword, Text), "funcname"),
            (r"(enum)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            (r"(class)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            (r"(obj)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            (r"(walker)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            (r"(node)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            (r"(edge)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            (r"(test)((?:\s|\\\s)+)", bygroups(Keyword, Text), "classname"),
            # Handle all import patterns directly in the root
            # Import from with curly braces (no semicolon yet)
            (
                r"(import)(\s+)(from)(\s+)([A-Za-z][A-Za-z0-9_\.]*)",
                bygroups(
                    Keyword.Namespace, Text, Keyword.Namespace, Text, Name.Namespace
                ),
                "import_from_braces",
            ),
            # Standard import with semicolon
            (
                r"(import)(\s+)([A-Za-z][A-Za-z0-9_\.]*)(\s*)(;)",
                bygroups(Keyword.Namespace, Text, Name.Namespace, Text, Punctuation),
            ),
            # Import with alias and semicolon
            (
                r"(import)(\s+)([A-Za-z][A-Za-z0-9_\.]*)(\s+)(as)(\s+)([A-Za-z][A-Za-z0-9_]*)(\s*)(;)",
                bygroups(Keyword.Namespace, Text, Name.Namespace, Text, Punctuation),
            ),
            # Include with semicolon
            (
                r"(include)(\s+)([A-Za-z][A-Za-z0-9_\.]*)(\s*)(;)",
                bygroups(Keyword.Namespace, Text, Name.Namespace, Text, Punctuation),
            ),
            # Fallback for any other import forms
            (
                r"(from)(\s+)([A-Za-z][A-Za-z0-9_\.]*)",
                bygroups(Keyword.Namespace, Text, Name.Namespace),
                "fromimport",
            ),
            include("expr"),
        ],
        "jsx": [
            # JSX Fragment: <>...</>
            (r"(<>)", Punctuation, "jsx-fragment"),
            # JSX opening tag: <Component or <div
            (
                r"(<)([A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*)",
                bygroups(Punctuation, Name.Class),
                "jsx-tag",
            ),
            (r"(<)([a-z][A-Za-z0-9_\-]*)", bygroups(Punctuation, Name.Tag), "jsx-tag"),
        ],
        "jsx-fragment": [
            (r"(</>)", Punctuation, "#pop"),
            include("jsx-children"),
        ],
        "jsx-tag": [
            # Self-closing tag end: />
            (r"(/>)", Punctuation, "#pop"),
            # Opening tag end: >
            (r"(>)", Punctuation, "jsx-children-tag"),
            # Attributes
            (r"\s+", Whitespace),
            # Attribute name (including hyphenated names like data-id, aria-label)
            (
                r"([A-Za-z_][-A-Za-z0-9_]*)(=)",
                bygroups(Name.Attribute, Operator),
                "jsx-attr-value",
            ),
            # Attribute without value
            (r"[A-Za-z_][-A-Za-z0-9_]*", Name.Attribute),
            # Spread attribute: {...}
            (r"(\{)(\.\.\.)", bygroups(Punctuation, Operator), "jsx-spread"),
        ],
        "jsx-attr-value": [
            # String values
            (r'"[^"]*"', String, "#pop"),
            (r"'[^']*'", String, "#pop"),
            # Expression values: {expr}
            (r"\{", Punctuation, "jsx-expr-attr"),
        ],
        "jsx-spread": [
            (r"\}", Punctuation, "#pop"),
            include("expr"),
        ],
        "jsx-expr-attr": [
            (r"\}", Punctuation, "#pop:2"),
            include("expr"),
        ],
        "jsx-children-tag": [
            # Closing tag: </Component>
            (
                r"(</)([A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*)(>)",
                bygroups(Punctuation, Name.Class, Punctuation),
                "#pop:2",
            ),
            (
                r"(</)([a-z][A-Za-z0-9_\-]*)(>)",
                bygroups(Punctuation, Name.Tag, Punctuation),
                "#pop:2",
            ),
            include("jsx-children"),
        ],
        "jsx-children": [
            # Nested JSX elements
            include("jsx"),
            # JSX expressions: {expr}
            (r"\{", Punctuation, "jsx-expr-child"),
            # Text content (anything except < > { })
            (r"[^<>{}\n]+", String),
            (r"\n", Whitespace),
        ],
        "jsx-expr-child": [
            (r"\}", Punctuation, "#pop"),
            include("expr"),
        ],
        "expr": [
            # raw f-strings
            (
                '(?i)(rf|fr)(""")',
                bygroups(String.Affix, String.Double),
                combined("rfstringescape", "tdqf"),
            ),
            (
                "(?i)(rf|fr)(''')",
                bygroups(String.Affix, String.Single),
                combined("rfstringescape", "tsqf"),
            ),
            (
                '(?i)(rf|fr)(")',
                bygroups(String.Affix, String.Double),
                combined("rfstringescape", "dqf"),
            ),
            (
                "(?i)(rf|fr)(')",
                bygroups(String.Affix, String.Single),
                combined("rfstringescape", "sqf"),
            ),
            # non-raw f-strings
            (
                '([fF])(""")',
                bygroups(String.Affix, String.Double),
                combined("fstringescape", "tdqf"),
            ),
            (
                "([fF])(''')",
                bygroups(String.Affix, String.Single),
                combined("fstringescape", "tsqf"),
            ),
            (
                '([fF])(")',
                bygroups(String.Affix, String.Double),
                combined("fstringescape", "dqf"),
            ),
            (
                "([fF])(')",
                bygroups(String.Affix, String.Single),
                combined("fstringescape", "sqf"),
            ),
            # raw bytes and strings
            ('(?i)(rb|br|r)(""")', bygroups(String.Affix, String.Double), "tdqs"),
            ("(?i)(rb|br|r)(''')", bygroups(String.Affix, String.Single), "tsqs"),
            ('(?i)(rb|br|r)(")', bygroups(String.Affix, String.Double), "dqs"),
            ("(?i)(rb|br|r)(')", bygroups(String.Affix, String.Single), "sqs"),
            # non-raw strings
            (
                '([uU]?)(""")',
                bygroups(String.Affix, String.Double),
                combined("stringescape", "tdqs"),
            ),
            (
                "([uU]?)(''')",
                bygroups(String.Affix, String.Single),
                combined("stringescape", "tsqs"),
            ),
            (
                '([uU]?)(")',
                bygroups(String.Affix, String.Double),
                combined("stringescape", "dqs"),
            ),
            (
                "([uU]?)(')",
                bygroups(String.Affix, String.Single),
                combined("stringescape", "sqs"),
            ),
            # non-raw bytes
            (
                '([bB])(""")',
                bygroups(String.Affix, String.Double),
                combined("bytesescape", "tdqs"),
            ),
            (
                "([bB])(''')",
                bygroups(String.Affix, String.Single),
                combined("bytesescape", "tsqs"),
            ),
            (
                '([bB])(")',
                bygroups(String.Affix, String.Double),
                combined("bytesescape", "dqs"),
            ),
            (
                "([bB])(')",
                bygroups(String.Affix, String.Single),
                combined("bytesescape", "sqs"),
            ),
            (r"[^\S\n]+", Text),
            include("numbers"),
            (
                r"(in|is|and|or|not|to|by)\b",
                Operator.Word,
            ),
            (
                r"(global|nonlocal|visitor|here|self|def|self|<i>|init|<sup>|super|root|impl|sem)",
                Operator.Word,
            ),
            (r"\?:|\?|:\+:|!=|==|<<|>>|:=|[-~+/*%=<>&^|.]", Operator),
            (r"[]{}:(),;[]", Punctuation),
            include("expr-keywords"),
            include("builtins"),
            include("magicfuncs"),
            include("magicvars"),
            include("name"),
        ],
        "expr-inside-fstring": [
            (r"[{([]", Punctuation, "expr-inside-fstring-inner"),
            # without format specifier
            (
                r"(=\s*)?"  # debug (https://bugs.python.org/issue36817)
                r"(\![sraf])?"  # conversion
                r"\}",
                String.Interpol,
                "#pop",
            ),
            # with format specifier
            # we'll catch the remaining '}' in the outer scope
            (
                r"(=\s*)?"  # debug (https://bugs.python.org/issue36817)
                r"(\![sraf])?"  # conversion
                r":",
                String.Interpol,
                "#pop",
            ),
            (r"\s+", Whitespace),  # allow new lines
            include("expr"),
        ],
        "expr-inside-fstring-inner": [
            (r"[{([]", Punctuation, "expr-inside-fstring-inner"),
            (r"[])}]", Punctuation, "#pop"),
            (r"\s+", Whitespace),  # allow new lines
            include("expr"),
        ],
        "expr-keywords": [
            # Based on https://docs.python.org/3/reference/expressions.html
            (
                words(
                    (
                        # "async for",
                        # "await",
                        "else",
                        "for",
                        "if",
                        "lambda",
                        "yield",
                        # "yield from",
                        # -----
                    ),
                    suffix=r"\b",
                ),
                Keyword,
            ),
            (words(("True", "False", "None"), suffix=r"\b"), Keyword.Constant),
        ],
        "keywords": [
            (
                words(
                    (
                        "assert",
                        "async",
                        "await",
                        "break",
                        "continue",
                        "del",
                        "elif",
                        "else",
                        "except",
                        "finally",
                        "for",
                        "import",
                        "include",
                        "def",
                        "can",
                        "glob",
                        "if",
                        "lambda",
                        "pass",
                        "raise",
                        "nonlocal",
                        "return",
                        "report",
                        "try",
                        "while",
                        "yield",
                        "yield from",
                        "as",
                        "with",
                        "to",
                        "by",
                        # -----
                        "let",
                        "abs",
                        "ignore",
                        "visit",
                        "revisit",
                        "spawn",
                        "entry",
                        "exit",
                        "disengage",
                        "skip",
                        "await",
                        "priv",
                        "pub",
                        "protect",
                        "has",
                        "check",
                        "cl",
                    ),
                    suffix=r"\b",
                ),
                Keyword,
            ),
            (words(("True", "False", "None"), suffix=r"\b"), Keyword.Constant),
        ],
        "soft-keywords": [
            # `match`, `case` and `_` soft keywords
            (
                r"(^[ \t]*)"  # at beginning of line + possible indentation
                r"(match|case|switch|default)\b"  # a possible keyword
                r"(?![ \t]*(?:"  # not followed by...
                r"[:,;=^&|@~)\]}]|(?:"
                + r"|".join(  # characters and keywords that mean this isn't
                    keyword.kwlist
                )
                + r")\b))",  # pattern matching
                bygroups(Text, Keyword),
                "soft-keywords-inner",
            ),
        ],
        "soft-keywords-inner": [
            # optional `_` keyword
            (r"(\s+)([^\n_]*)(_\b)", bygroups(Whitespace, using(this), Keyword)),
            default("#pop"),
        ],
        "builtins": [
            (
                words(
                    (
                        "__import__",
                        "abs",
                        "aiter",
                        "all",
                        "any",
                        "bin",
                        "bool",
                        "bytearray",
                        "breakpoint",
                        "bytes",
                        "callable",
                        "chr",
                        "classmethod",
                        "compile",
                        "complex",
                        "delattr",
                        "dict",
                        "dir",
                        "divmod",
                        "enumerate",
                        "eval",
                        "filter",
                        "float",
                        "format",
                        "frozenset",
                        "getattr",
                        "globals",
                        "hasattr",
                        "hash",
                        "hex",
                        "id",
                        "input",
                        "int",
                        "isinstance",
                        "issubclass",
                        "iter",
                        "len",
                        "list",
                        "locals",
                        "map",
                        "max",
                        "memoryview",
                        "min",
                        "next",
                        "object",
                        "oct",
                        "open",
                        "ord",
                        "pow",
                        "print",
                        "property",
                        "range",
                        "repr",
                        "reversed",
                        "round",
                        "set",
                        "setattr",
                        "slice",
                        "sorted",
                        "static",
                        "override",
                        "str",
                        "sum",
                        "super",
                        "tuple",
                        "type",
                        "vars",
                        "zip",
                    ),
                    prefix=r"(?<!\.)",
                    suffix=r"\b",
                ),
                Name.Builtin,
            ),
            (r"(?<!\.)(self|Ellipsis|NotImplemented|cls)\b", Name.Builtin.Pseudo),
            (
                words(
                    (
                        "ArithmeticError",
                        "AssertionError",
                        "AttributeError",
                        "BaseException",
                        "BufferError",
                        "BytesWarning",
                        "DeprecationWarning",
                        "EOFError",
                        "EnvironmentError",
                        "Exception",
                        "FloatingPointError",
                        "FutureWarning",
                        "GeneratorExit",
                        "IOError",
                        "ImportError",
                        "ImportWarning",
                        "IndentationError",
                        "IndexError",
                        "KeyError",
                        "KeyboardInterrupt",
                        "LookupError",
                        "MemoryError",
                        "NameError",
                        "NotImplementedError",
                        "OSError",
                        "OverflowError",
                        "PendingDeprecationWarning",
                        "ReferenceError",
                        "ResourceWarning",
                        "RuntimeError",
                        "RuntimeWarning",
                        "StopIteration",
                        "SyntaxError",
                        "SyntaxWarning",
                        "SystemError",
                        "SystemExit",
                        "TabError",
                        "TypeError",
                        "UnboundLocalError",
                        "UnicodeDecodeError",
                        "UnicodeEncodeError",
                        "UnicodeError",
                        "UnicodeTranslateError",
                        "UnicodeWarning",
                        "UserWarning",
                        "ValueError",
                        "VMSError",
                        "Warning",
                        "WindowsError",
                        "ZeroDivisionError",
                        # new builtin exceptions from PEP 3151
                        "BlockingIOError",
                        "ChildProcessError",
                        "ConnectionError",
                        "BrokenPipeError",
                        "ConnectionAbortedError",
                        "ConnectionRefusedError",
                        "ConnectionResetError",
                        "FileExistsError",
                        "FileNotFoundError",
                        "InterruptedError",
                        "IsADirectoryError",
                        "NotADirectoryError",
                        "PermissionError",
                        "ProcessLookupError",
                        "TimeoutError",
                        # others new in Python 3
                        "StopAsyncIteration",
                        "ModuleNotFoundError",
                        "RecursionError",
                        "EncodingWarning",
                    ),
                    prefix=r"(?<!\.)",
                    suffix=r"\b",
                ),
                Name.Exception,
            ),
        ],
        "magicfuncs": [
            (
                words(
                    (
                        "__abs__",
                        "__add__",
                        "__aenter__",
                        "__aexit__",
                        "__aiter__",
                        "__and__",
                        "__anext__",
                        "__await__",
                        "__bool__",
                        "__bytes__",
                        "__call__",
                        "__complex__",
                        "__contains__",
                        "__del__",
                        "__delattr__",
                        "__delete__",
                        "__delitem__",
                        "__dir__",
                        "__divmod__",
                        "__enter__",
                        "__eq__",
                        "__exit__",
                        "__float__",
                        "__floordiv__",
                        "__format__",
                        "__ge__",
                        "__get__",
                        "__getattr__",
                        "__getattribute__",
                        "__getitem__",
                        "__gt__",
                        "__hash__",
                        "__iadd__",
                        "__iand__",
                        "__ifloordiv__",
                        "__ilshift__",
                        "__imatmul__",
                        "__imod__",
                        "__imul__",
                        "__index__",
                        "__init__",
                        "__instancecheck__",
                        "__int__",
                        "__invert__",
                        "__ior__",
                        "__ipow__",
                        "__irshift__",
                        "__isub__",
                        "__iter__",
                        "__itruediv__",
                        "__ixor__",
                        "__le__",
                        "__len__",
                        "__length_hint__",
                        "__lshift__",
                        "__lt__",
                        "__matmul__",
                        "__missing__",
                        "__mod__",
                        "__mul__",
                        "__ne__",
                        "__neg__",
                        "__new__",
                        "__next__",
                        "__or__",
                        "__pos__",
                        "__pow__",
                        "__prepare__",
                        "__radd__",
                        "__rand__",
                        "__rdivmod__",
                        "__repr__",
                        "__reversed__",
                        "__rfloordiv__",
                        "__rlshift__",
                        "__rmatmul__",
                        "__rmod__",
                        "__rmul__",
                        "__ror__",
                        "__round__",
                        "__rpow__",
                        "__rrshift__",
                        "__rshift__",
                        "__rsub__",
                        "__rtruediv__",
                        "__rxor__",
                        "__set__",
                        "__setattr__",
                        "__setitem__",
                        "__str__",
                        "__sub__",
                        "__subclasscheck__",
                        "__truediv__",
                        "__xor__",
                    ),
                    suffix=r"\b",
                ),
                Name.Function.Magic,
            ),
        ],
        "magicvars": [
            (
                words(
                    (
                        "__annotations__",
                        "__bases__",
                        "__class__",
                        "__closure__",
                        "__code__",
                        "__defaults__",
                        "__dict__",
                        "__doc__",
                        "__file__",
                        "__func__",
                        "__globals__",
                        "__kwdefaults__",
                        "__module__",
                        "__mro__",
                        "__name__",
                        "__objclass__",
                        "__qualname__",
                        "__self__",
                        "__slots__",
                        "__weakref__",
                    ),
                    suffix=r"\b",
                ),
                Name.Variable.Magic,
            ),
        ],
        "numbers": [
            (
                r"(\d(?:_?\d)*\.(?:\d(?:_?\d)*)?|(?:\d(?:_?\d)*)?\.\d(?:_?\d)*)"
                r"([eE][+-]?\d(?:_?\d)*)?",
                Number.Float,
            ),
            (r"\d(?:_?\d)*[eE][+-]?\d(?:_?\d)*j?", Number.Float),
            (r"0[oO](?:_?[0-7])+", Number.Oct),
            (r"0[bB](?:_?[01])+", Number.Bin),
            (r"0[xX](?:_?[a-fA-F0-9])+", Number.Hex),
            (r"\d(?:_?\d)*", Number.Integer),
        ],
        "name": [
            (r"@" + uni_name, Name.Decorator),
            (r"@", Operator),  # new matrix multiplication operator
            (uni_name, Name),
        ],
        "funcname": [
            include("magicfuncs"),
            (uni_name, Name.Function, "#pop"),
            default("#pop"),
        ],
        "classname": [
            (uni_name, Name.Class, "#pop"),
        ],
        "fromimport": [
            (r"(\s+)(import)\b", bygroups(Text, Keyword.Namespace), "#pop"),
            (
                r"(\s*)(;)(\s*)",
                bygroups(Text, Punctuation, Text),
                "#pop",
            ),  # Handle semicolons
            (r"\.", Name.Namespace),
            # if None occurs here, it's "raise x from None", since None can
            # never be a module name
            (r"None\b", Keyword.Constant, "#pop"),
            (uni_name, Name.Namespace),
            default("#pop"),
        ],
        "import_from_braces": [
            (r"(\s*)(\{)(\s*)", bygroups(Text, Punctuation, Text), "import_from_items"),
        ],
        "import_from_items": [
            (r"([A-Za-z][A-Za-z0-9_]*)", Name),
            (
                r"(\s+)(as)(\s+)([A-Za-z][A-Za-z0-9_]*)",
                bygroups(Text, Keyword, Text, Name),
            ),
            (r"(\s*)(,)(\s*)", bygroups(Text, Punctuation, Text)),
            (
                r"(\s*)(\})(\s*)(;?)",
                bygroups(Text, Punctuation, Text, Punctuation),
                "#pop:2",
            ),  # Pop back to root
        ],
        "rfstringescape": [
            (r"\{\{", String.Escape),
            (r"\}\}", String.Escape),
        ],
        "fstringescape": [
            include("rfstringescape"),
            include("stringescape"),
        ],
        "bytesescape": [
            (r'\\([\\abfnrtv"\']|\n|x[a-fA-F0-9]{2}|[0-7]{1,3})', String.Escape)
        ],
        "stringescape": [
            (r"\\(N\{.*?\}|u[a-fA-F0-9]{4}|U[a-fA-F0-9]{8})", String.Escape),
            include("bytesescape"),
        ],
        "fstrings-single": fstring_rules(String.Single),
        "fstrings-double": fstring_rules(String.Double),
        "strings-single": innerstring_rules(String.Single),
        "strings-double": innerstring_rules(String.Double),
        "dqf": [
            (r'"', String.Double, "#pop"),
            (r'\\\\|\\"|\\\n', String.Escape),  # included here for raw strings
            include("fstrings-double"),
        ],
        "sqf": [
            (r"'", String.Single, "#pop"),
            (r"\\\\|\\'|\\\n", String.Escape),  # included here for raw strings
            include("fstrings-single"),
        ],
        "dqs": [
            (r'"', String.Double, "#pop"),
            (r'\\\\|\\"|\\\n', String.Escape),  # included here for raw strings
            include("strings-double"),
        ],
        "sqs": [
            (r"'", String.Single, "#pop"),
            (r"\\\\|\\'|\\\n", String.Escape),  # included here for raw strings
            include("strings-single"),
        ],
        "tdqf": [
            (r'"""', String.Double, "#pop"),
            include("fstrings-double"),
            (r"\n", String.Double),
        ],
        "tsqf": [
            (r"'''", String.Single, "#pop"),
            include("fstrings-single"),
            (r"\n", String.Single),
        ],
        "tdqs": [
            (r'"""', String.Double, "#pop"),
            include("strings-double"),
            (r"\n", String.Double),
        ],
        "tsqs": [
            (r"'''", String.Single, "#pop"),
            include("strings-single"),
            (r"\n", String.Single),
        ],
    }

    def analyse_text(text):
        return shebang_matches(text, r"pythonw?(3(\.\d)?)?") or "import " in text[:1000]


# # Custom Plugin Definition
# class JacLexerPlugin(BasePlugin):
#     def on_config(self, config):
#         # Registering the lexer
#         # _mapping.LEXERS["JacLexer"] = (
#         #     "jac",
#         #     "Jac Lexer",
#         #     ("jac",),
#         #     ("*.jac",),
#         #     (),
#         # )
#         load_lexer_from_file(__file__, "JacLexer")
#         print(get_lexer_by_name("JacLexer"))
#         return config
