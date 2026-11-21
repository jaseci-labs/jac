---
description: The native csv module, as CPython's csv, its readers, writers and dialects, and the reading modes it does not have.
keywords: csv, csv.reader, csv.writer, csv.DictReader, csv.DictWriter, csv.Dialect, csv.excel, csv.excel_tab, csv.unix_dialect, csv.Sniffer, csv.register_dialect, csv.get_dialect, csv.list_dialects, csv.field_size_limit, csv.Error, csv.QUOTE_MINIMAL, csv.QUOTE_ALL, csv.QUOTE_NONNUMERIC, csv.QUOTE_NONE, csv.QUOTE_STRINGS, csv.QUOTE_NOTNULL
---
# csv

`csv` reads and writes comma-separated values as CPython's `csv` does: the same readers,
writers, dialects, quoting, output text, exceptions and messages. It is native (see
[The library](index.md), `jac docs library`).

```jac
import csv;
import io;

with entry {
    out = io.StringIO();
    w = csv.writer(out);
    w.writerow(["name", "note", "score"]);
    w.writerow(["Ada", "likes, commas", 9.5]);
    w.writerows([["Bo", "said \"hi\"", 7], ["Cy", None, 8]]);
    text = out.getvalue();
    print(repr(text));
    for row in csv.reader(io.StringIO(text)) {
        print(row);
    }
    for rec in csv.DictReader(io.StringIO(text)) {
        print(rec["name"], rec["score"]);
    }
    print(list(csv.reader(["x;y", "1;2"], delimiter=";")));
}
```

```output
'name,note,score\r\nAda,"likes, commas",9.5\r\nBo,"said ""hi""",7\r\nCy,,8\r\n'
['name', 'note', 'score']
['Ada', 'likes, commas', '9.5']
['Bo', 'said "hi"', '7']
['Cy', '', '8']
Ada 9.5
Bo 7
Cy 8
[['x', 'y'], ['1', '2']]
```

A reader takes any iterable of lines: a file opened with `newline=""`, an `io.StringIO`, a list
of strs. A writer takes any object with a `write(str)` method.

## What is there

| Name | What it is |
|---|---|
| `reader(csvfile, dialect="excel", **fmtparams)` | An iterator of rows, each a `list[str]`; `line_num` counts physical lines read |
| `writer(csvfile, dialect="excel", **fmtparams)` | `writerow` (returns what the sink's `write` returned), `writerows`, `dialect` |
| `DictReader(f, fieldnames=None, restkey=None, restval=None, ...)` | Rows as dicts keyed by the first row or `fieldnames`; blank rows are skipped |
| `DictWriter(f, fieldnames, restval="", extrasaction="raise", ...)` | `writeheader`, `writerow`, `writerows` from dicts |
| `Dialect`, `excel`, `excel_tab`, `unix_dialect` | Dialects; a program's `obj` may inherit one to make its own |
| `register_dialect`, `unregister_dialect`, `get_dialect`, `list_dialects` | The dialect registry: `excel`, `excel-tab` and `unix` at start |
| `Sniffer` | `sniff(sample)` guesses a dialect; `has_header(sample)` |
| `field_size_limit(new_limit=None)` | 131072 by default, counted in characters |
| `QUOTE_MINIMAL`, `QUOTE_ALL`, `QUOTE_NONNUMERIC`, `QUOTE_NONE`, `QUOTE_STRINGS`, `QUOTE_NOTNULL` | 0 to 5, as CPython 3.12 and later number them |
| `Error` | A malformed row or a row that cannot be written |

The default dialect is `excel`: delimiter `,`, quote character `"`, quotes doubled, lines ended
with `"\r\n"`, `QUOTE_MINIMAL`. A writer writes `None` as an empty field and numbers unquoted.
Dialect parameters are checked as CPython checks them (`TypeError: "delimiter" must be a unicode
character, not a string of length 2`), and `DictWriter` with `extrasaction="raise"` refuses a key
not in `fieldnames` (`ValueError: dict contains fields not in fieldnames: 'color'`).

Also as in CPython:

- Under `QUOTE_NONNUMERIC` a writer counts an `obj` with `__float__` as a number, writes it
  unquoted through its `__str__`, and quotes everything else.
- A writer under `QUOTE_NONE` with no `escapechar` raises
  `csv.Error: need to escape, but no escapechar set` for a field holding the delimiter, and a
  row of one empty field raises `csv.Error: single empty field record must be quoted`.
- A reader with an `escapechar` takes the character after it as it is: an escaped delimiter,
  quote character or newline is part of the field
  (`csv.reader(["a\\,b"], escapechar="\\")` gives `[['a,b']]`).
- The quoting parameters are checked as CPython checks them: a `quoting` that is not an int,
  or is out of range (`TypeError: bad "quoting" value`), and `quotechar=None` with a quoting
  mode that quotes (`TypeError: quotechar must be set if quoting enabled`).
- `Sniffer().preferred` lists the delimiters `sniff` prefers: `[',', '\t', ';', ' ', ':']`.

## Differences from CPython

- **A reader's rows are `list[str]`**, so the three reading modes that convert fields do not
  exist natively: `reader(..., quoting=QUOTE_NONNUMERIC)` (and `QUOTE_STRINGS`,
  `QUOTE_NOTNULL`) raises `NotImplementedError` when the reader is made. Read strs and convert
  them (`float(row[2])`). Writers take every quoting mode.
- **`Sniffer.sniff` returns a `Dialect` instance**, where CPython returns a new class (a Jac
  class cannot be made as the program runs). Every function that takes a dialect takes it.

```jac
import csv;

with entry {
    d = csv.Sniffer().sniff("a;b\n1;2\n");
    print(repr(d.delimiter), list(csv.reader(["1;2"], dialect=d)));
}
```

```output
';' [['1', '2']]
```
