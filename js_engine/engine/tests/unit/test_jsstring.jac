import from engine.src.runtime.global { global_context_create }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsstring {
    str_char_at,
    str_substr,
    str_chars,
    str_hash,
    str_intern,
    str_from_id,
    JSString,
    js_string,
    js_string_from_code
}

with entry {
    # Engine startup: wire every module's realm singleton (string table,
    # object table, …); the engine code under test reads them.
    ctx = global_context_create();

    ok: int = 0;
    err: int = 0;

    # ── str_char_at ──────────────────────────────────────────────────────────
    if str_char_at("Hello", 0) == "H" {
        ok += 1;
    } else {
        print("FAIL str_char_at[0]");
        err += 1;
    }
    if str_char_at("Hello", 4) == "o" {
        ok += 1;
    } else {
        print("FAIL str_char_at[4]");
        err += 1;
    }
    if str_char_at("Hello", -1) == "o" {
        ok += 1;
    } else {
        print("FAIL str_char_at[-1]");
        err += 1;
    }
    if str_char_at("Hello", 99) == "" {
        ok += 1;
    } else {
        print("FAIL str_char_at oob");
        err += 1;
    }

    # ── str_substr ───────────────────────────────────────────────────────────
    if str_substr("Hello World", 6, 11) == "World" {
        ok += 1;
    } else {
        print("FAIL str_substr World");
        err += 1;
    }
    if str_substr("Hello", 0, 0) == "" {
        ok += 1;
    } else {
        print("FAIL str_substr empty");
        err += 1;
    }
    if str_substr("Hello", 1, 3) == "el" {
        ok += 1;
    } else {
        print("FAIL str_substr el");
        err += 1;
    }

    # ── str_chars ─────────────────────────────────────────────────────────────
    ch: list[str] = str_chars("Hi");
    if len(ch) == 2 {
        ok += 1;
    } else {
        print("FAIL str_chars len");
        err += 1;
    }
    if ch[0] == "H" {
        ok += 1;
    } else {
        print("FAIL str_chars[0]");
        err += 1;
    }
    if ch[1] == "i" {
        ok += 1;
    } else {
        print("FAIL str_chars[1]");
        err += 1;
    }

    # ── str_hash ──────────────────────────────────────────────────────────────
    h1: int = str_hash("hello");
    h2: int = str_hash("hello");
    h3: int = str_hash("world");
    if h1 == h2 {
        ok += 1;
    } else {
        print("FAIL str_hash same");
        err += 1;
    }
    if h1 != h3 {
        ok += 1;
    } else {
        print("FAIL str_hash diff");
        err += 1;
    }

    # ── str_intern / str_from_id ──────────────────────────────────────────────
    id1: int = str_intern("foo");
    id2: int = str_intern("foo");
    id3: int = str_intern("bar");
    if id1 == id2 {
        ok += 1;
    } else {
        print("FAIL intern same key");
        err += 1;
    }
    if id1 != id3 {
        ok += 1;
    } else {
        print("FAIL intern diff key");
        err += 1;
    }
    if str_from_id(id1) == "foo" {
        ok += 1;
    } else {
        print("FAIL str_from_id foo");
        err += 1;
    }
    if str_from_id(id3) == "bar" {
        ok += 1;
    } else {
        print("FAIL str_from_id bar");
        err += 1;
    }

    # ── JSString basics ───────────────────────────────────────────────────────
    s: JSString = js_string("Hello");
    if s.length == 5 {
        ok += 1;
    } else {
        print("FAIL length");
        err += 1;
    }
    if s.to_string() == "Hello" {
        ok += 1;
    } else {
        print("FAIL to_string");
        err += 1;
    }

    # ── char_at / char_code_at ────────────────────────────────────────────────
    if s.char_at(0) == "H" {
        ok += 1;
    } else {
        print("FAIL char_at 0");
        err += 1;
    }
    if s.char_at(4) == "o" {
        ok += 1;
    } else {
        print("FAIL char_at 4");
        err += 1;
    }
    if s.char_code_at(0) == 72 {
        ok += 1;
    } else {
        print("FAIL char_code_at H");
        err += 1;
    }
    # ── index_of / last_index_of ─────────────────────────────────────────────
    t: JSString = js_string("abcabc");
    if t.index_of("bc") == 1 {
        ok += 1;
    } else {
        print("FAIL index_of bc");
        err += 1;
    }
    if t.last_index_of("bc") == 4 {
        ok += 1;
    } else {
        print("FAIL last_index_of bc");
        err += 1;
    }
    if t.index_of("xyz") == -1 {
        ok += 1;
    } else {
        print("FAIL index_of miss");
        err += 1;
    }

    # ── includes / starts_with / ends_with ────────────────────────────────────
    w: JSString = js_string("Hello World");
    if w.includes("World") {
        ok += 1;
    } else {
        print("FAIL includes World");
        err += 1;
    }
    if not w.includes("xyz") {
        ok += 1;
    } else {
        print("FAIL includes xyz");
        err += 1;
    }
    if w.starts_with("Hello") {
        ok += 1;
    } else {
        print("FAIL starts_with Hello");
        err += 1;
    }
    if w.ends_with("World") {
        ok += 1;
    } else {
        print("FAIL ends_with World");
        err += 1;
    }

    # ── slice ────────────────────────────────────────────────────────────────
    sl: JSString = w.slice(6, 11);
    if sl.to_string() == "World" {
        ok += 1;
    } else {
        print("FAIL slice World got", sl.to_string());
        err += 1;
    }

    # ── to_lower_case / to_upper_case ─────────────────────────────────────────
    lc: JSString = js_string("Hello").to_lower_case();
    uc: JSString = js_string("Hello").to_upper_case();
    if lc.to_string() == "hello" {
        ok += 1;
    } else {
        print("FAIL to_lower got", lc.to_string());
        err += 1;
    }
    if uc.to_string() == "HELLO" {
        ok += 1;
    } else {
        print("FAIL to_upper got", uc.to_string());
        err += 1;
    }

    # ── trim ─────────────────────────────────────────────────────────────────
    tr: JSString = js_string("  hi  ").trim();
    if tr.to_string() == "hi" {
        ok += 1;
    } else {
        print("FAIL trim got", tr.to_string());
        err += 1;
    }

    # ── split ────────────────────────────────────────────────────────────────
    parts: list[str] = js_string("a,b,c").split(",");
    if len(parts) == 3 {
        ok += 1;
    } else {
        print("FAIL split len");
        err += 1;
    }
    if parts[0] == "a" {
        ok += 1;
    } else {
        print("FAIL split[0]");
        err += 1;
    }
    if parts[2] == "c" {
        ok += 1;
    } else {
        print("FAIL split[2]");
        err += 1;
    }

    # ── replace / replace_all ────────────────────────────────────────────────
    rep: JSString = js_string("foo bar foo").replace("foo", "baz");
    if rep.to_string() == "baz bar foo" {
        ok += 1;
    } else {
        print("FAIL replace got", rep.to_string());
        err += 1;
    }
    repa: JSString = js_string("foo bar foo").replace_all("foo", "baz");
    if repa.to_string() == "baz bar baz" {
        ok += 1;
    } else {
        print("FAIL replace_all got", repa.to_string());
        err += 1;
    }

    # ── concat ───────────────────────────────────────────────────────────────
    c: JSString = js_string("Hello").concat(" World");
    if c.to_string() == "Hello World" {
        ok += 1;
    } else {
        print("FAIL concat got", c.to_string());
        err += 1;
    }

    # ── repeat ───────────────────────────────────────────────────────────────
    rp: JSString = js_string("ab").repeat(3);
    if rp.to_string() == "ababab" {
        ok += 1;
    } else {
        print("FAIL repeat got", rp.to_string());
        err += 1;
    }

    # ── pad_start / pad_end ──────────────────────────────────────────────────
    ps: JSString = js_string("5").pad_start(3, "0");
    pe: JSString = js_string("5").pad_end(3, "0");
    if ps.to_string() == "005" {
        ok += 1;
    } else {
        print("FAIL pad_start got", ps.to_string());
        err += 1;
    }
    if pe.to_string() == "500" {
        ok += 1;
    } else {
        print("FAIL pad_end got", pe.to_string());
        err += 1;
    }

    # ── equals ───────────────────────────────────────────────────────────────
    if js_string("abc").equals("abc") {
        ok += 1;
    } else {
        print("FAIL equals true");
        err += 1;
    }
    if not js_string("abc").equals("xyz") {
        ok += 1;
    } else {
        print("FAIL equals false");
        err += 1;
    }

    # ── js_string_from_code ───────────────────────────────────────────────────
    codestr: JSString = js_string_from_code(65);
    if codestr.to_string() == "A" {
        ok += 1;
    } else {
        print("FAIL js_string_from_code A got", codestr.to_string());
        err += 1;
    }

    print("jsstring smoke:", ok, "passed,", err, "failed");
    if err > 0 {
        fflush(0);
        _exit(1);
    }
}
