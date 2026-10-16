def lookup(t: type, table: dict[type, str]) -> str {
    if t in table {
        if t is None {
            print(t.__name__);
        } elif t is str {
            print("str");
        }
        return table[t];
    }
    return "";
}

obj Settings {
    has files: (list[str] | None) = None;

    def load {
        self.files = ["a"];
    }
}

def reload(c: Settings) {
    assert c.files is None;
    c.load();
    assert c.files is not None;
    assert "a" in c.files;
}

def still_typed {
    bad: int = "x";
}
