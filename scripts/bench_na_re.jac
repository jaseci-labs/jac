"""Benchmark: bundled native re/string/reprlib vs CPython's own modules.

Lanes: `jac run -b native scripts/bench_na_re.jac` (bundled na_stdlib) and
`jac run -b python scripts/bench_na_re.jac` (CPython's re/string/reprlib).
Every row prints ns/op as the median of ROUNDS timed rounds after one warmup,
plus a checksum that must agree across lanes.
"""

import time;
import sys;
import re;
import reprlib;
import from string { capwords, Template }

glob TEXT: str = "The quick brown fox jumps over the lazy dog 12345 times; email bob@example.com, id AB-9876, <b>bold</b> and <i>it</i> end.",
     ROUNDS: int = 7,
     P_LIT: re.Pattern = re.compile("lazy dog"),
     P_CLASS: re.Pattern = re.compile("[A-Z]{2}-\\d+"),
     P_ALT: re.Pattern = re.compile("fox|dog|cat|bird"),
     P_ANCHOR: re.Pattern = re.compile("^\\w+@\\w+\\.com$"),
     P_GROUPS: re.Pattern = re.compile("(\\w+)-(\\d+)"),
     P_LAZY: re.Pattern = re.compile("<.+?>"),
     P_GREEDY: re.Pattern = re.compile("q.*z"),
     P_NOMATCH: re.Pattern = re.compile("xyz\\d"),
     P_FULL: re.Pattern = re.compile("[0-9a-f]+"),
     P_WORD: re.Pattern = re.compile("\\w+"),
     P_DIGIT: re.Pattern = re.compile("\\d"),
     P_SEP: re.Pattern = re.compile("[,;]\\s*"),
     TPL: Template = Template("Hello $name, you owe ${amount} to $who; $$5 fee."),
     TPL_MAP: dict[str, any] = {"name": "Ada", "amount": "42", "who": "Bob"},
     TPL_PART: dict[str, any] = {"name": "Ada"},
     REPR_LIST: list[any] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
     REPR_STR: str = "abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz";


def b_lit_search(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        m = P_LIT.search(TEXT);
        if m is not None {
            acc += m.start();
        }
    }
    return acc;
}


def b_class_search(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        m = P_CLASS.search(TEXT);
        if m is not None {
            acc += m.end();
        }
    }
    return acc;
}


def b_alt_findall(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(P_ALT.findall(TEXT));
    }
    return acc;
}


def b_anchor_match(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        m = P_ANCHOR.match("bob@example.com");
        if m is not None {
            acc += m.end();
        }
    }
    return acc;
}


def b_groups_search(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        m = P_GROUPS.search(TEXT);
        if m is not None {
            acc += m.start(1) + m.end(2);
        }
    }
    return acc;
}


def b_lazy_findall(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(P_LAZY.findall(TEXT));
    }
    return acc;
}


def b_greedy_search(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        m = P_GREEDY.search(TEXT);
        if m is not None {
            acc += m.end();
        }
    }
    return acc;
}


def b_nomatch_search(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        if P_NOMATCH.search(TEXT) is None {
            acc += 1;
        }
    }
    return acc;
}


def b_fullmatch(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        if P_FULL.fullmatch("deadbeef0123") is not None {
            acc += 1;
        }
    }
    return acc;
}


def b_finditer(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        for m in P_WORD.finditer(TEXT) {
            acc += 1;
        }
    }
    return acc;
}


def b_sub(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(P_DIGIT.sub("#", TEXT));
    }
    return acc;
}


def b_split(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(P_SEP.split(TEXT));
    }
    return acc;
}


def b_module_search(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        m = re.search("\\d+", TEXT);
        if m is not None {
            acc += m.start();
        }
    }
    return acc;
}


def b_capwords(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(capwords(TEXT));
    }
    return acc;
}


def b_substitute(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(TPL.substitute(TPL_MAP));
    }
    return acc;
}


def b_safe_substitute(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(TPL.safe_substitute(TPL_PART));
    }
    return acc;
}


def b_reprlib(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        acc += len(reprlib.repr(REPR_LIST)) + len(reprlib.repr(REPR_STR));
    }
    return acc;
}


def run_row(k: int, n: int) -> int {
    if k == 0 {
        return b_lit_search(n);
    } elif k == 1 {
        return b_class_search(n);
    } elif k == 2 {
        return b_alt_findall(n);
    } elif k == 3 {
        return b_anchor_match(n);
    } elif k == 4 {
        return b_groups_search(n);
    } elif k == 5 {
        return b_lazy_findall(n);
    } elif k == 6 {
        return b_greedy_search(n);
    } elif k == 7 {
        return b_nomatch_search(n);
    } elif k == 8 {
        return b_fullmatch(n);
    } elif k == 9 {
        return b_finditer(n);
    } elif k == 10 {
        return b_sub(n);
    } elif k == 11 {
        return b_split(n);
    } elif k == 12 {
        return b_module_search(n);
    } elif k == 13 {
        return b_capwords(n);
    } elif k == 14 {
        return b_substitute(n);
    } elif k == 15 {
        return b_safe_substitute(n);
    }
    return b_reprlib(n);
}


glob NAMES: list[str] = [
         "re lit search",
         "re class search",
         "re alt findall",
         "re anchor match",
         "re groups search",
         "re lazy findall",
         "re greedy search",
         "re nomatch search",
         "re fullmatch",
         "re finditer",
         "re sub",
         "re split",
         "re module search",
         "string capwords",
         "Template substitute",
         "Template safe_substitute",
         "reprlib repr"
     ];


with entry {
    n: int = 20000;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    only: str = "";
    if len(sys.argv) > 2 {
        only = sys.argv[2];
    }
    for k in range(len(NAMES)) {
        if only != "" and only not in NAMES[k] {
            continue;
        }
        acc: int = run_row(k, n // 10);
        times: list[int] = [];
        for r in range(ROUNDS) {
            t0 = time.perf_counter_ns();
            acc = run_row(k, n);
            times.append(time.perf_counter_ns() - t0);
        }
        times.sort();
        med: int = times[ROUNDS // 2];
        sys.stdout.write(NAMES[k] + "\t" + str(med // n) + "\tacc=" + str(acc) + "\n");
    }
}
