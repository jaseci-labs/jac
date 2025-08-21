with entry {
    # unicode characters
    items = [{"title":"1st", "due":True, "completed":True}, {"title":"2nd", "due":False, "completed":False}];
    for (i, item) in enumerate(items) {
        status = "✓" if item["completed"] else "○";
        due = f" (due: {item['due']})" if item["due"] else "";
        print(f"{i+1}. {status} {item['title']}{due}");
    }
    
    # unicode emojis and symbols
    print("🌟 Star");    
    
    # unicode in triple quoted strings
    multiline = """Multi-line with ✓ unicode and ○ symbols""";
    print(multiline);
    
    # unicode in raw strings
    raw_unicode = r"Raw string with ✓ and ○";
    print(raw_unicode);
    
    # mixed unicode and escape sequences
    mixed = "Tab ✓\nNewline ○";
    print(mixed);
}