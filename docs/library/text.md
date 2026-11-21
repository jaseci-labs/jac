---
description: The native text modules, as CPython's - string, textwrap, difflib, shlex, fnmatch, pprint, reprlib, html, html.parser and html.entities.
keywords: text modules, string.Template, string.Formatter, string.capwords, string.ascii_letters, string.ascii_lowercase, string.ascii_uppercase, string.digits, string.hexdigits, string.octdigits, string.punctuation, string.printable, string.whitespace, textwrap, textwrap.wrap, textwrap.fill, textwrap.shorten, textwrap.dedent, textwrap.indent, textwrap.TextWrapper, difflib, difflib.SequenceMatcher, difflib.Differ, difflib.HtmlDiff, difflib.unified_diff, difflib.context_diff, difflib.ndiff, difflib.get_close_matches, shlex, shlex.split, shlex.quote, shlex.join, shlex.shlex, fnmatch, fnmatch.fnmatch, fnmatch.fnmatchcase, fnmatch.filter, fnmatch.translate, pprint, pprint.pprint, pprint.pformat, pprint.pp, pprint.PrettyPrinter, reprlib, reprlib.repr, reprlib.Repr, reprlib.recursive_repr, html, html.escape, html.unescape, html.parser, html.parser.HTMLParser, HTMLParser, html.entities
---
# Text: string, textwrap, difflib, shlex, fnmatch, pprint, reprlib, html

These modules work on text as CPython's do, with the same results, exceptions and messages, and
each has the whole interface of CPython 3.15's module. They are native (see
[The library](index.md), `jac docs library`). Regular expressions are [`re`](re.md);
encodings and the Unicode database are [`codecs` and `unicodedata`](codecs.md).

```jac
import difflib;
import pprint;
import reprlib;
import shlex;
import string;
import textwrap;

with entry {
    print(string.capwords("hello  world"), string.Formatter().format("{0}-{x}", 1, x=2));
    print(string.Template("$who likes $what").substitute({"who": "Ada", "what": "graphs"}));
    print(textwrap.shorten("The quick brown fox jumps over the lazy dog", width=20));
    w = textwrap.TextWrapper(width=12, initial_indent="* ", subsequent_indent="  ");
    print(w.fill("one two three four five"));
    print(textwrap.dedent("    a\n      b\n"), end="");
    old = ["apple\n", "pear\n", "plum\n"];
    new = ["apple\n", "peach\n", "plum\n"];
    print("".join(difflib.unified_diff(old, new, "old", "new")), end="");
    print(
        difflib.get_close_matches("appel", ["ape", "apple", "peach"]),
        difflib.SequenceMatcher(None, "abcd", "bcde").ratio(),
    );
    print(
        shlex.split("cp 'my file.txt' \"dest dir\""), shlex.quote("it's"), shlex.join(["a b", "c"])
    );
    pprint.pprint({"name": "y" * 20, "tags": ["a", "b"], "id": 7}, width=40);
    print(reprlib.repr(list(range(100))), reprlib.repr("x" * 50));
}
```

```output
Hello World 1-2
Ada likes graphs
The quick [...]
* one two
  three four
  five
a
  b
--- old
+++ new
@@ -1,3 +1,3 @@
 apple
-pear
+peach
 plum
['apple', 'ape'] 0.75
['cp', 'my file.txt', 'dest dir'] 'it'"'"'s' 'a b' c
{'id': 7,
 'name': 'yyyyyyyyyyyyyyyyyyyy',
 'tags': ['a', 'b']}
[0, 1, 2, 3, 4, 5, ...] 'xxxxxxxxxxxx...xxxxxxxxxxxxx'
```

## The modules

| Module | What it has |
|---|---|
| `string` | The character constants (`ascii_letters`, `digits`, `punctuation`, ...), `capwords`, `Template` (`substitute`, `safe_substitute`, `get_identifiers`, `is_valid`), `Formatter` (`format`, `vformat`, `parse`, `get_field`, `format_field`, `convert_field`); `string.templatelib` is not there, as Jac has no template string literal (E5143) |
| `textwrap` | `wrap`, `fill`, `shorten`, `dedent`, `indent`, and `TextWrapper` with every option of CPython's (`break_long_words`, `break_on_hyphens`, `max_lines`, `placeholder`, `tabsize`, `drop_whitespace`, ...) |
| `difflib` | `SequenceMatcher` (`ratio`, `quick_ratio`, `get_matching_blocks`, `get_opcodes`, `get_grouped_opcodes`, ...), `Differ`, `HtmlDiff`, `unified_diff`, `context_diff`, `ndiff`, `diff_bytes`, `restore`, `get_close_matches`, `IS_LINE_JUNK`, `IS_CHARACTER_JUNK` |
| `shlex` | `split`, `join`, `quote`, and the `shlex` lexer class with its POSIX and punctuation modes |
| `fnmatch` | `fnmatch`, `fnmatchcase`, `filter`, `filterfalse`, `translate` |
| `pprint` | `pprint`, `pformat`, `pp`, `isreadable`, `isrecursive`, `saferepr`, `PrettyPrinter` |
| `reprlib` | `repr`, `Repr` with its limits, `recursive_repr`, `aRepr` |
| `html` | `escape`, `unescape` (HTML5's references, and a reference without its `;` by its longest known prefix) |
| `html.entities` | `name2codepoint`, `codepoint2name`, `entitydefs`, `html5` |
| `html.parser` | `HTMLParser`, which a program's class inherits and overrides `handle_starttag`, `handle_data` and the rest of; CPython's tokenizer, `convert_charrefs` and CDATA handling |

```jac
import fnmatch;

with entry {
    print(fnmatch.fnmatch("data.CSV", "*.csv"), fnmatch.fnmatch("data.csv", "d?ta.[ct]sv"));
    print(fnmatch.filter(["a.py", "b.txt", "c.py"], "*.py"), fnmatch.translate("*.py"));
}
```

```output
False True
['a.py', 'c.py'] (?s:.*\.py)\z
```

`fnmatch.fnmatch` folds case as `os.path.normcase` does (on Windows, not elsewhere);
`fnmatchcase` never does.

```jac
import html;
import html.entities;
import from html.parser { HTMLParser }

class Links(HTMLParser) {
    has found: list[str] = [];

    override def handle_starttag(tag: str, attrs: list[tuple[str, str | None]]) {
        for (name, value) in attrs {
            if tag == "a" and name == "href" and value is not None {
                self.found.append(value);
            }
        }
    }
}

with entry {
    print(html.escape("<a href='x'>&</a>"), html.unescape("&lt;p&gt; &eacute; &#x263A;"));
    print(html.entities.name2codepoint["eacute"], html.entities.html5["amp;"]);
    p = Links();
    p.feed("<p>See <a href=\"/one\">one</a> and <a class=x href='/two'>two</a>.</p>");
    p.close();
    print(p.found);
}
```

```output
&lt;a href=&#x27;x&#x27;&gt;&amp;&lt;/a&gt; <p> é ☺
233 &
['/one', '/two']
```

## Differences from CPython

- **`reprlib.recursive_repr()` wraps a function of one argument, called as a function**: Jac has
  no decorators on methods, and the wrapper has no `__name__`, `__doc__` or `__wrapped__`, as a
  Jac function value has no attributes.
- **`textwrap.TextWrapper` has no `uspace`, `whitespace_trans` or `x`**: CPython's stub keeps
  these names of Python 2's module, which CPython's class does not have (E5142).

## Speed

`textwrap.shorten` is slower than CPython's on long text.
