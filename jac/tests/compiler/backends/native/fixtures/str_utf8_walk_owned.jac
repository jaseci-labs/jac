"""Index and loop over multibyte text in the owned world (every profile,
nogc included): characters read out of a string are never freed by the
reader, so nothing double-frees and nothing leaks."""

def count_of(s: &str, target: &str) -> int {
    n = 0;
    for ch in s {
        if ch == target {
            n += 1;
        }
    }
    return n;
}

def point_sum(s: &str) -> int {
    total = 0;
    for i in range(len(s)) {
        total += ord(s[i]);
    }
    return total;
}

def last_points(s: &str) -> int {
    total = 0;
    for i in range(1, len(s) + 1) {
        total = total * 7 + ord(s[-i]);
    }
    return total % 1000003;
}

def run -> int {
    big = "日本" * 40000 + "é";
    found = count_of(&big, "本");
    print(found, len(big));
    print(point_sum("héllo日本🙂"), last_points("a日b本c🙂"));
    print(count_of("éèé", "é"), count_of("abcabc", "c"));
    print("héllo"[1], "日本語"[-1], "🙂x🙂"[::-1], "日本語"[1:], "aé"[0]);
    return found;
}

with entry {
    print(run());
}
