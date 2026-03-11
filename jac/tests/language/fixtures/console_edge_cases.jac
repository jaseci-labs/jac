"""Test fixture with patterns that could break console output."""

import json;

# === JSON with hex-like patterns (caused ValueError crash) ===
glob data = {"addr": "Suite #2000", "color": "#ff0000", "short": "#fff"};

with entry {
    print(json.dumps(data));

    # === Markup-like patterns (were incorrectly stripped) ===
    print("[red]this is not markup[/red]");
    print("[bold]user text[/bold]");
    print("[dim]dimmed[/dim]");
    print("[bold red on blue]styled[/]");
    print("[green]success[/green]");
    print("[yellow]warning[/yellow]");
    print("[cyan]info[/cyan]");

    # === Config file patterns ===
    print("[section]");
    print("[project]");
    print("[database]");
    print("[tool.mypy]");
    print("[build-system]");

    # === Array/dict access patterns ===
    print("arr[0]");
    print("list[1][2]");
    print("dict['key']");
    print('obj["name"]');
    print("matrix[i][j]");

    # === Hex color variations ===
    print("#fff");
    print("#000");
    print("#123");
    print("#abc");
    print("#ff0000");
    print("#00ff00");
    print("#0000ff");
    print("#123456");
    print("#abcdef");
    print('color: #2000"}');  # The exact pattern that crashed

    # === RGB/color function patterns ===
    print("rgb(255, 0, 0)");
    print("rgb(0,0,0)");
    print("rgba(255, 255, 255, 0.5)");
    print("color(196)");
    print("color(255)");
    print("hsl(120, 100%, 50%)");

    # === URL fragments ===
    print("http://example.com#section");
    print("https://docs.com/page#heading-1");
    print("file:///path#anchor");

    # === Regex-like patterns ===
    print("[a-z]+");
    print("[0-9]{3}");
    print("[A-Za-z_][A-Za-z0-9_]*");
    print("match [^]]*");

    # === Nested/escaped brackets ===
    print("[[nested]]");
    print("[[[triple]]]");
    print("\\[escaped\\]");
    print("before[middle]after");

    # === Error message patterns ===
    print("Error: [INVALID]");
    print("Warning: [DEPRECATED]");
    print("[ERROR] Something failed");
    print("[INFO] Status update");
    print("[DEBUG] Trace info");

    # === Mixed complex patterns ===
    print(f"User #123 selected [option] with color #ff0");
    print("Config [db] at localhost:5432#schema");
    print('{"items": [1,2,3], "color": "#abc"}');
}

# === Real-world data structures ===
glob table_data = [[i, "name_" + str(i), "city", i * 100] for i in range(3)];
with entry {
    print(table_data);
    print([[1, 2], [3, 4], [5, 6]]);
    print({"rows": [[1, "a"], [2, "b"]]});
}
