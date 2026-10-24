impl text_segments(text: str) -> list[dict[str, str]] {
    out: list[dict[str, str]] = [];
    plain = "";
    i = 0;
    n = len(text);
    while i < n {
        if text[i] == " " or text[i] == "\n" or text[i] == "\t" {
            plain = plain + text[i];
            i = i + 1;
            continue;
        }
        j = i;
        while j < n and text[j] != " " and text[j] != "\n" and text[j] != "\t" {
            j = j + 1;
        }
        word = text[i:j];
        core = word;
        tail = "";
        while len(core) > 0 and ".,;:!?)".find(core[len(core) - 1]) >= 0 {
            tail = core[len(core) - 1] + tail;
            core = core[:len(core) - 1];
        }
        kind = "";
        if core.startswith("https://")
            or core.startswith("http://")
            or core.startswith("/jacyac/")
            or core.startswith("/docs/") {
            kind = "link";
        } elif core.startswith("@") and len(core) > 1 {
            kind = "mention";
        }
        if kind != "" {
            if plain != "" {
                out.append({"k": "t", "t": plain});
            }
            out.append({"k": kind, "t": core});
            plain = tail;
        } else {
            plain = plain + word;
        }
        i = j;
    }
    if plain != "" {
        out.append({"k": "t", "t": plain});
    }
    return out;
}
