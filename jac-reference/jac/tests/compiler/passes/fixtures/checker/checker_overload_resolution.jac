"""Test overload resolution for methods like str.split() returning list[str]."""

glob text = "hello world",
     parts = text.split(" "),
     first = parts[0],
     result = first + " test",
     text2 = ["hello world"],
     parts2 = text2[0].split(" "),
     first3 = parts2[0],
     result3 = first3 + " test";
