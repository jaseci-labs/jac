"""str.format with a literal template, parsed natively."""

def format_hits(n: int, word: str) -> int {
    hits = 0;
    if "{}-{}".format(n, word) == "7-ok" {
        hits += 1;
    }
    if "{1}{0}{1}".format(n, word) == "ok7ok" {
        hits += 2;
    }
    if "{w!r}".format(w=word) == "'ok'" {
        hits += 4;
    }
    if "[{:>4}]".format(n) == "[   7]" {
        hits += 8;
    }
    if "{{{}}}".format(word) == "{ok}" {
        hits += 16;
    }
    if "plain".format() == "plain" {
        hits += 32;
    }
    return hits;
}

def chk_format(n: int) -> int {
    return format_hits(n, "ok");
}

with entry {
    print(chk_format(7));
}
