"""Line boundaries, keepends and embedded data survive native splitting."""
def:pub line_checks(keep: bool) -> bool {
    if "".splitlines(keep) != [] {
        return False;
    }
    if "plain".splitlines(keep) != ["plain"] {
        return False;
    }
    for separator in [
        "\n",
        "\r",
        "\r\n",
        "\v",
        "\f",
        "\x1c",
        "\x1d",
        "\x1e",
        "\u0085",
        "\u2028",
        "\u2029"
    ] {
        text = "Ω\x00😀" + separator + separator + "end" + separator;
        expected = ["Ω\x00😀" + separator, separator, "end" + separator]
            if keep
            else ["Ω\x00😀", "", "end"];
        if text.splitlines(keepends=keep) != expected {
            return False;
        }
        if separator.splitlines(keep) != [separator if keep else ""] {
            return False;
        }
    }
    if "a\r\nb\rc\n".splitlines() != ["a", "b", "c"] {
        return False;
    }
    if "a\n\n".splitlines() != ["a", ""] {
        return False;
    }
    if "\r\r\n".splitlines(True) != ["\r", "\r\n"] {
        return False;
    }
    if "a\x1fb\t c Ωâ".splitlines() != ["a\x1fb\t c Ωâ"] {
        return False;
    }
    return True;
}

with entry {
    assert line_checks(False);
    assert line_checks(True);
    print("SPLITLINES PASS");
}
