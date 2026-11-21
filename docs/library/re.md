---
description: The native re module, as CPython's re, with how str and bytes patterns are typed and what is left out.
keywords: re, regular expression, regex, re.compile, re.search, re.match, re.fullmatch, re.prefixmatch, re.findall, re.finditer, re.sub, re.subn, re.split, re.escape, re.purge, re.Pattern, re.Match, re.RegexFlag, re.error, re.PatternError
---
# re

`re` matches regular expressions as CPython's `re` does: the same syntax, flags, functions,
results, errors and error positions. It is native: `import re` compiles jac's own engine into
the program, with no Python in it (see [The library](index.md), `jac docs library`).

```jac
import re;

with entry {
    date = re.compile(r"(?P<y>\d{4})-(?P<m>\d\d)-(?P<d>\d\d)");
    m = date.search("due 2026-11-12, paid 2026-12-01");
    if m is not None {
        print(m.group(0), m["y"], m.group("m", "d"), m.span());
    }
    print(date.findall("2026-11-12 and 2027-01-02"));
    print(re.sub(r"(\w+)@(\w+)", r"\2 at \1", "ann@home bob@work"));
    print(
        re.sub(r"\d+", lambda (m: re.Match) -> str { return str(int(m.group()) * 2); }, "a1 b22")
    );
    print(re.split(r"[,;]\s*", "a, b;c"), re.fullmatch(r"\w+", "héllo") is not None);
    print([x.group() for x in re.finditer(r"\b\w", "one two three")]);
}
```

```output
2026-11-12 2026 ('11', '12') (4, 14)
[('2026', '11', '12'), ('2027', '01', '02')]
home at ann work at bob
a2 b44
['a', 'b', 'c'] True
['o', 't', 't']
```

## What is there

| Names | What they are |
|---|---|
| `compile`, `search`, `match`, `fullmatch`, `prefixmatch`, `findall`, `finditer`, `sub`, `subn`, `split`, `escape`, `purge` | The module's functions, with CPython's parameters (`pos`, `endpos`, `count`, `maxsplit`, `flags`) |
| `Pattern` | A compiled pattern: the same methods, and `pattern`, `flags`, `groups`, `groupindex` |
| `Match` | A match: `group`, `groups`, `groupdict`, `start`, `end`, `span`, `expand`, `m[i]`, `m["name"]`, `pos`, `endpos`, `lastindex`, `lastgroup`, `re`, `string`, `regs` |
| `A`/`ASCII`, `I`/`IGNORECASE`, `L`/`LOCALE`, `M`/`MULTILINE`, `S`/`DOTALL`, `U`/`UNICODE`, `X`/`VERBOSE`, `NOFLAG` | The flags, and the enum `RegexFlag` of their long names |
| `error`, `PatternError` | The exception for a bad pattern (one class: catching either catches both), with `msg`, `pattern`, `pos`, `lineno`, `colno` |

`prefixmatch` is Python 3.15's name for `match`. `match` is a Jac keyword, but `re.match(...)`
needs no backtick.

The syntax is all of CPython's: classes and sets, counted, lazy and possessive repeats
(`a{2,}`, `*?`, `*+`), atomic groups `(?>...)`, lookahead and lookbehind, numbered and named
groups and backreferences, conditionals `(?(1)a|b)`, inline flags `(?i)`, `(?i:...)` and
`(?-i:...)`, verbose mode, `\A \Z \z \b \B`, and replacement templates `\1 \g<1> \g<name>`.
Matching follows CPython in its details:

- For a str pattern, `\w`, `\d`, `\s` and `\b` are Unicode-aware, and ASCII-only under `re.A`
  or `(?a)`; `(?i)` folds case beyond ASCII. Positions (`span`, `pos`) count code points.
- Empty matches follow Python 3.7 and later: `re.sub(r"x*", "-", "axxb")` is `-a--b-`.
- An unmatched group is `None` in `groups()`, `(-1, -1)` in `span()` and empty in a
  replacement template; a group that does not exist raises `IndexError: no such group`.
- `re.split(r"x*", "axxb")` is `['', 'a', '', 'b', '']` and `re.findall("", "ab")` is
  `['', '', '']`.
- `(?i)` folds as CPython does beyond ASCII: `ſ` matches `s`, the Kelvin sign `K` matches `k`,
  and `ß` and the final sigma fold too. `\s` matches the separators U+001C to U+001F.
- `re.compile` of an equal pattern and flags returns the same cached object until `purge()`;
  compiled patterns with equal pattern and flags are equal and hash equal.
- The flags have CPython's values (`re.I | re.M | re.S | re.X | re.A` is 346, `re.U` 32, `re.L`
  4, `re.NOFLAG` 0), and a str pattern's `flags` includes `re.U` (`re.compile("x", re.I).flags`
  is 34). `re.A | re.U`, and `re.U` with a bytes pattern, raise `ValueError`.
- A pattern error on a later line reports it: `missing ), unterminated subpattern at position 2
  (line 2, column 1)`, with `lineno` and `colno`. A repeat count too large raises
  `OverflowError: the repetition number is too large`.
- No operation is quadratic in the length of the text.

## str and bytes patterns

`Pattern` and `Match` are generic over `str` and `bytes`: `re.compile("a")` is a
`Pattern[str]`, `re.compile(b"a")` a `Pattern[bytes]`, and what they match and return has that
type. Applying a str pattern to bytes is therefore a compile error (E1053) where the types are
known:

```jac
# expect: E1053
import re;

with entry {
    p = re.compile("a");
    print(p.search(b"a"));
}
```

When the pattern is held as an `any`, the mismatch raises CPython's
`TypeError: cannot use a string pattern on a bytes-like object` as the program runs.

## Errors

A bad pattern raises `re.error` with CPython's message and position:

```jac
import re;

with entry {
    for pattern in ["(abc", r"(?<=a+)b"] {
        try {
            re.compile(pattern);
        } except re.error as e {
            print(e, "|", e.pos);
        }
    }
}
```

```output
missing ), unterminated subpattern at position 0 | 0
look-behind requires fixed-width pattern | None
```

## Differences from CPython

- **`\N{name}` in a pattern** raises `NotImplementedError: re: \N{...} needs the Unicode
  character names, which the native library does not have`.
- **`LOCALE`** works with bytes patterns, as the C locale reads them. With a str pattern it is a
  `ValueError` (`cannot use LOCALE flag with a str pattern`), as in CPython.
- **`re.DEBUG`** is left out on purpose: the native engine does not run CPython's instructions,
  so it has none to print. Naming it is E5142.
- **`RegexFlag`'s one-letter members** (`RegexFlag.I`, ...) are left out: a Jac enum member cannot
  be an alias of another. Write `RegexFlag.IGNORECASE`, or the module's `re.I`. E5142:

```jac
# expect: E5142
import re;

with entry {
    print(re.RegexFlag.I);
}
```

- **Flags combined with `|` are an `int`**, not a `RegexFlag`. Every function takes `flags` as an
  `int`.
