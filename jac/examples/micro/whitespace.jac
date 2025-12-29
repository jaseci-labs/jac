"""Same functionality 3 white space styles."""

glob a = "hello",
     b = len(a);

with entry {
    print(b);
}

glob a = "hello" |> len;

with entry {
    a |> print;
}

with entry {
    "hello" |> len |> print;
}

with entry {
    print(len("hello"));
}
# very pythonic

# a bit more Jac like

# more concise

# same, but no pipe
