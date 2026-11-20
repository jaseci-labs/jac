glob label = "world";

with entry {
    print(f'ESC_NEWLINE:\nhello {label}');
    print(f'ESC_TAB:\there {label}');
    print(f'ESC_ANSI:\x1b[0m{label}');
    print(f'UNICODE_A:\u0041 {label}');
    print(f'CHINESE:你好 {label}');
    print(f'ARABIC:مرحبا {label}');
    print(f'EMOJI_BOOK:📚 {label}');
    print(f'EMOJI_CHAT:💬 {label}');
    print(f'EMOJI_BUG:🐛 {label}');
    print(f'EMOJI_ROCKET:🚀 {label}');
    print(f'EMOJI_MIXED:\n📚 {label} 💬');
}
