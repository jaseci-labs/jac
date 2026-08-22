import from fnmatch { fnmatch, fnmatchcase }

glob pats: list[str] = [
         "*",
         "?",
         "a*",
         "*a",
         "a?c",
         "[abc]",
         "[!abc]",
         "[a-z]",
         "[!a-z]",
         "[]a]",
         "[!]a]",
         "[a-]",
         "[-a]",
         "a[",
         "a[]",
         "[",
         "]",
         "*.txt",
         "*.*",
         "a*b*c",
         "**",
         "[A-Za-z]",
         "[!]",
         "x[a-c]y",
         "[[]",
         "[]]",
         "*a*b*",
         "?*?",
         "[0-9][0-9]"
     ],
     names: list[str] = [
         "",
         "a",
         "b",
         "abc",
         "a.txt",
         "]",
         "[",
         "-",
         "aXc",
         "abcbc",
         "A",
         "xby",
         "42",
         "aXbY"
     ];

with entry {
    for p in pats {
        row: str = "";
        for n in names {
            if fnmatchcase(n, p) {
                row = row + "1";
            } else {
                row = row + "0";
            }
        }
        print(p + " " + row);
    }
    for p in pats {
        row2: str = "";
        for n in names {
            if fnmatch(n, p) {
                row2 = row2 + "1";
            } else {
                row2 = row2 + "0";
            }
        }
        print(p + " " + row2);
    }
}
