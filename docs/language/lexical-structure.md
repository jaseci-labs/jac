---
description: What a Jac source file is made of: encoding, comments, names, reserved words and the backtick escape, literals, and how statements and blocks are delimited.
keywords: comment, #, #*, name, identifier, keyword, reserved word, backtick, literal, None, True, False, ..., ellipsis, ;, block, statement
grammar: block, block_rest, stmt, stmts, any_word, KEYWORD, OPERATOR
---
# Lexical structure

A Jac source file is a text file named `<module>.jac`. The compiler reads it as a sequence of
tokens: names, keywords, literals and operators. Spaces, tabs and line breaks separate tokens and
mean nothing else. Statements end with `;` and blocks are written in braces, so indentation is
layout only. `jac fmt` rewrites a file into the one standard layout.

## Source files and encoding

- A file is UTF-8. A string literal may hold any UTF-8 text.
- Names are ASCII: a letter or `_`, then letters, digits and `_`. Any other character outside a
  string or a comment is an error (E0105).
- An empty file is a valid module. So is a file that holds only declarations, or only a docstring.

```jac
with entry {
    greeting = "héllo wörld ✓";
    print(greeting, len(greeting), len(greeting.encode()));
}
```

```output
héllo wörld ✓ 13 17
```

## Comments

| Form | Extent |
|---|---|
| `# text` | To the end of the line |
| `#* text *#` | To the next `*#`; may span lines and may sit inside a line |

Block comments do not nest: the first `*#` ends the comment. A block comment that is never closed
is an error (E0101).

```jac
#* A block comment
   over two lines. *#
with entry {
    # A line comment.
    print(1 #* inside an expression *# + 2);  # after a statement
}
```

```output
3
```

A string is never a comment. A string that documents a declaration is a docstring; see
[Modules](modules.md).

## Names

A name starts with a letter or `_` and continues with letters, digits and `_`. Case matters: `Total`
and `total` are two names.

A name refers to a local variable, a parameter, a global, a function, an archetype, a module or one
of their members. Which one is decided by the scope rules in [Variables](variables.md).

## Keywords

The words below are reserved. A reserved word is never a name: it cannot name a local, a parameter,
a global, a function, an archetype, a field, an enum member or an import's alias (E0013).

```ebnf
KEYWORD ::=
    "str" | "int" | "float" | "list" | "tuple" | "set" | "dict" | "bool" | "bytes"
    | "any" | "type" | "i8" | "u8" | "i16" | "u16" | "i32" | "u32" | "i64" | "u64"
    | "i128" | "u128" | "f16" | "bf16" | "f8e4m3fn" | "f8e5m2" | "f4e2m1fn" | "f32"
    | "f64" | "abst" | "obj" | "class" | "enum" | "node" | "edge" | "walker" | "has"
    | "can" | "def" | "static" | "override" | "comptime" | "impl" | "getter" | "setter"
    | "deleter" | "sem" | "test" | "glob" | "graph" | "import" | "include" | "from"
    | "as" | "if" | "elif" | "else" | "for" | "by" | "while" | "forever" | "match"
    | "switch" | "case" | "default" | "try" | "except" | "finally" | "awaiting" | "with"
    | "return" | "yield" | "break" | "continue" | "raise" | "del" | "assert" | "skip"
    | "report" | "visit" | "spawn" | "entry" | "exit" | "disengage" | "here" | "visitor"
    | "root" | "async" | "await" | "flow" | "wait" | "and" | "or" | "not" | "in" | "is"
    | "lambda" | "own" | "lin" | "mut" | "imm" | "pub" | "priv" | "protect" | "self"
    | "init" | "super" | "postinit" | "True" | "False" | "None"
```

Four points a reader coming from Python or from the reference design will not expect:

- **The type words are reserved.** `int`, `str`, `float`, `bool`, `bytes`, `list`, `dict`, `set`,
  `tuple`, `type`, `any` and every sized number type (`i32`, `u8`, `f32`, ...) are keywords.
  `list = [1]` and `def type() {...}` are errors, not shadowing.
- **`self` is a parameter only as the receiver.** `init` and `postinit`, the names of a
  constructor's hooks, may also name a function or a method.
- **Words the grammar uses in one construct only are not reserved.** `struct`, `tail`, `where`,
  `dyn`, `space`, `app`, `run` and `serve` are ordinary names everywhere else.
- **Another language's reserved words are names here** when Jac does not reserve them: `pass`,
  `global`, `nonlocal`, `catch`, `function`, `undefined` and the reference design's `props` name variables like any
  other word.

```jac
# expect: E0013 x4
glob dict = 1;

def str -> int {
    return 2;
}

def given(type: int) -> int {
    return type;
}

with entry {
    list = [1];
    print(list);
}
```

### Where any word is taken

Some positions do not bind a name; they refer to a name that something else declared, often in
Python or JavaScript. These take any word, reserved or not, written as it stands:

```ebnf
any_word ::= NAME | KEYWORD
```

| Position | Example |
|---|---|
| An attribute after `.` | `obj.type`, `m.from` |
| A keyword argument's name | `f(type=1)`, `int.from_bytes(bytes=b, byteorder="little")` |
| A keyword in a class pattern | `case P(type="x"):` |
| An attribute in a dotted pattern | `case Color.default:` |
| An import item bound under an alias | `import from m { match as find }` |
| A dict key | `{"type": 1}` (a string, so never a name) |

### The backtick escape

A backtick before a keyword makes it a name: `` `type `` is the name `type`. It is how a program
declares a field, a parameter, a local or a method whose name the language reserves, usually
because a JSON document, a Python API or a JavaScript API names it that way.

- Write the backtick where the name is **bound** and wherever the bare word would otherwise be read
  as the keyword: `` has `type: str ``, `` def f(`type: str) ``, and `` return `type; `` in the body
  (`type` alone is the builtin).
- Do not write it where any word is taken (the table above): `r.type`, `f(type="x")`.
  After `.`, in a module path and in an `impl` target the backtick is an error (E0157).
- A backtick before a word that is not a keyword is an error (E0014).

```jac
obj Record {
    has `type: str = "plain",
        `from: int = 0;
}

def describe(`type: str, `in: int = 0) -> str {
    return `type + ":" + str(`in);
}

with entry {
    r = Record(type="kind", from=2);
    print(r.type, r.from);
    print(describe(type="x", in=4), describe("y"));
    print(type(r).__name__);
}
```

```output
kind 2
x:4 y:0
Record
```

```jac
# expect: E0014, E0157
obj Box {
    has `str: int = 0;
}

with entry {
    `count = 1;
    print(Box().`str);
}
```

## Literals

| Literal | Examples | Type |
|---|---|---|
| Decimal integer | `0`, `42`, `1_000_000` | `int` |
| Hexadecimal, binary, octal integer | `0x1F`, `0b101`, `0o17` (the prefix letter in lower case; hex digits in either) | `int` |
| Float | `1.5`, `.5`, `1e-3`, `2.5e2`, `1_0.5` (the exponent's `e` in lower case) | `float` |
| String | `"a"`, `'a'`, `"""a"""`, `r"\d"`, `f"{x}"` | `str` |
| Bytes | `b"a"`, `rb"\d"` | `bytes` |
| Boolean | `True`, `False` | `bool` |
| None | `None` | `None` |
| Ellipsis | `...` | the `Ellipsis` value |

- `_` may separate digits in any number.
- An `int` is 64 bits. A literal past 9223372036854775807 is an error (E1126); so is a literal that
  does not fit the sized type it meets. See [Numbers](numbers.md) for sized types and for
  arithmetic that overflows.
- A float needs a digit after its point: `1.5` and `.5` are floats, `1.` is not a literal.
- There is no complex literal: `1j` is an error. `complex(1, 2)` makes a complex number.
- There is no negative literal: `-1` is the operator `-` applied to `1`.
- String and bytes forms, escapes and f-strings are in [Strings](strings.md).

```jac
with entry {
    print(0x1F, 0b101, 0o17, 1_000_000);
    print(1.5, .5, 1e-3, 2.5e2);
    print(True, False, None, ...);
    print(complex(1, 2));
}
```

```output
31 5 15 1000000
1.5 0.5 0.001 250.0
True False None Ellipsis
(1+2j)
```

```jac
# expect: E1126
with entry {
    print(9223372036854775808);
}
```

## Operators and delimiters

Where several operators could start at the same character, the longest one is taken. The full
set:

```ebnf
OPERATOR ::=
    "<-->" | "<++>" | "<--" | "<++" | "<-:" | "<+:" | "<<=" | "</>" | "<=" | "<<" | "<|"
    | "<:" | "<." | "</" | "<>" | "<" | "-->" | "->:" | "-%=" | "-|=" | "->" | "-="
    | "-%" | "-|" | "-" | "++>" | "+>:" | "+%=" | "+|=" | "+=" | "+%" | "+|" | "+"
    | ":->" | ":+>" | ":<-" | ":<+" | ":>" | ":=" | ":" | "..." | ".>" | "." | "**="
    | "*%=" | "*|=" | "**" | "*=" | "*%" | "*|" | "*" | "//=" | "//" | "/=" | "/>" | "/"
    | ">>=" | ">=" | ">>" | ">" | "==" | "=" | "!=" | "|>" | "|=" | "|" | "@=" | "@"
    | "&=" | "&" | "%=" | "%" | "^=" | "^" | "?" | "(" | ")" | "[" | "]" | "{" | "}"
    | "," | ";" | "~"
```

`not in` and `is not` are each one operator, written with one or more spaces between the two words.
What each operator means, and how tightly it binds, is in [Operators](operators.md).

## Statements and blocks

```ebnf
block ::= "{" block_rest

block_rest ::= stmts "}"

stmts ::= stmt*
```

- **A statement ends with `;`.** A line break does not end one, so a statement may run over any
  number of lines and several may share a line. A missing `;` is an error (E0002), and so is one
  missing after a block's last expression (E2084, or E0159 where the function returns a value: a
  value is returned with `return`). Two expressions stand without one: the body of a
  [one-expression lambda](functions.md), and a JSX element in a [component](../apps/components.md)'s
  slot.
- **A block is `{ ... }`.** Every compound statement (`if`, `while`, `for`, `def`, `try`, ...) takes
  a block, never a single statement, and no `:` introduces it. A compound statement ends at its
  closing brace and takes no `;` after it.
- **A `;` on its own is not a statement** (W3013), and at module level it is E0030.
- **Any expression is a statement** when followed by `;`. Its value is dropped.
- **A module's top level holds declarations only.** Statements such as `print(1);` or `x = 1;` are
  written inside a `with entry` block or a function (E0005 otherwise). See [Modules](modules.md).

```jac
with entry {
    total = 0;
    for n in [1, 2, 3] {
        if n % 2 == 1 {
            total += n;
        }
    }
    print(total);
}
```

```output
4
```

```jac
# expect: E0002
with entry {
    x = 1
    print(x);
}
```

```jac
# expect: W3013 x2
def count -> int {
    ;
    return 1;;
}
```

### The statements

```ebnf
stmt ::=
    jsx_element ";"?
    | comptime_stmt
    | import_stmt
    | if_stmt
    | while_stmt
    | open_stmt
    | forever_stmt
    | for_stmt
    | with_stmt
    | try_stmt
    | match_stmt
    | switch_stmt
    | return_stmt
    | yield_expr ";"
    | ctrl_stmt
    | raise_stmt
    | assert_stmt
    | delete_stmt
    | global_vars
    | visit_stmt
    | report_stmt
    | docstring_target
    | ability
    | decorated
    | archetype
    | impl_def
    | has_stmt
    | "->" expression block
    | expression (assignment | ";")
```

| Statement | Page |
|---|---|
| `expression ;` and assignment (`=`, `+=`, annotations), `del` | [Variables](variables.md) |
| `if`, `while`, `for`, `forever`, `switch`, `break`, `continue` | [Control flow](control-flow.md) |
| `match` | [Pattern matching](pattern-matching.md) |
| `def` inside a function, `return` | [Functions](functions.md) |
| `try`, `raise`, `assert` | [Exceptions](exceptions.md) |
| `with` | [Context managers](context-managers.md) |
| `yield` | [Generators](generators.md) |
| `await`, `async for`, `async with`, `flow`, `wait` | [Async](async.md) |
| `visit`, `report`, `skip`, `disengage`, `-> T { ... }` | Walkers: `jac docs visit` |
| `comptime` statements | `jac docs comptime` |
| `in region { ... }` | `jac docs region` |
| `has` in a function, JSX elements | Components of a UI space: `jac docs jsx` |

Some statements the grammar takes are refused in a function body today, with E5090: `import`,
`glob`, and an archetype declaration.

## Differences from Python

- Blocks are braces and statements end in `;`. Indentation carries no meaning.
- A comment that spans lines is `#* ... *#`. A string on its own line is an expression statement,
  not a comment, and at module level one that documents no declaration is warned of (W0060).
- `int`, `str`, `list`, `type` and the other type words are keywords, so they cannot be rebound.
- There is no line-continuation backslash outside strings; none is needed.
- An integer literal is 64 bits wide, and there is no complex literal.
- Names are ASCII.

## Differences from the reference design

- A keyword is never a name without a backtick. The reference design accepts many keywords as names in some
  positions; jac refuses all of them with E0013 and takes any word only in the positions listed
  above.
- A backtick that is not needed is an error (E0014, E0157), not a spelling choice.
