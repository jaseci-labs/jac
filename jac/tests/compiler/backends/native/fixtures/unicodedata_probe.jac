import from unicodedata { category, east_asian_width }

glob chars: list[str] = ["A", "\u0301", "界", "·", "😀", "\u0000"];

with entry {
    for ch in chars {
        print(category(ch), east_asian_width(ch));
    }
    for ch in ["", "ab"] {
        try {
            print(category(ch));
        } except TypeError as err {
            print(str(err));
        }
        try {
            print(east_asian_width(ch));
        } except TypeError as err {
            print(str(err));
        }
    }
}
