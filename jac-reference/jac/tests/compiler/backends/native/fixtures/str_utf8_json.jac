"""json.dumps and json.loads walk multibyte text once and agree with CPython."""
import json;

def run -> int {
    big = "日本" * 40000 + "é \"q\"";
    print(len(json.dumps(big)), len(json.dumps(big, ensure_ascii=False)));
    for w in ["héllo", "日本語", "🙂x🙂", "abc", "", "è\n"] {
        print(json.dumps(w), json.dumps(w, ensure_ascii=False));
    }
    print(json.dumps("tab\t \"q\" \\ é 🙂 \x7f end"));
    print(json.dumps("tab\t é 🙂 \x7f end", ensure_ascii=False));
    return len(big);
}

def run_loads -> int {
    unit = "é\\\"x\\n\\u00e8";
    doc = "{\"k\": \""
        + unit * 30000
        + "\", \"日本\": [\"a\\tb\", \"🙂\\u00e9\", \"plain é\", 1.5, -2, true, null]}";
    raw: dict[str, any] = json.loads(doc);
    k: str = raw["k"];
    print(len(k), k[:10] == "é\"x\nè" * 2, k[-5:] == "é\"x\nè");
    items: list[any] = raw["日本"];
    print(json.dumps(items, ensure_ascii=False));
    print(json.dumps(json.loads("[\"日本\", \"\\u65e5é\\\\\", \"🙂\"]")));
    pairs: str = json.loads("\"\\ud83d\\ude42|\\ud83d\\u0041|\\ude42\\ud83d|\\ud83d\"");
    print([ord(c) for c in pairs]);
    for lone in [
        "a" + chr(0xD800) + "é",
        "é\"" + chr(0xD800) + "x\n🙂" + chr(0xDFFF) + "\\end",
        chr(0xDBFF),
        chr(0xD83D) + "A" + chr(0xDE42) + chr(0xD83D)
    ] {
        for ascii_only in [False, True] {
            back: str = json.loads(json.dumps(lone, ensure_ascii=ascii_only));
            print(back == lone, len(back), [ord(c) for c in back]);
        }
    }
    return len(k);
}

with entry {
    print(run());
    print(run_loads());
}
