import from unicodedata { category, east_asian_width }

glob chars: list[str] = [
         "\U0002EBEF",
         "\U0002EBF0",
         "\U0002EE5D",
         "\U0002EE5E",
         "\uFF66",
         "\uFF21"
     ];

with entry {
    for ch in chars {
        print(category(ch), east_asian_width(ch));
    }
}
