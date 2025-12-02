"""Same functionality 3 white space styles."""

with entry {  # very pythonic
    a = "hello";
    b = len(a);
    print(b);
}

with entry {  # a bit more Jac like
    a = "hello" |> len;
    a |> print;
}

with entry {
    "hello" |> len |> print;
}  # more concise


with entry {
    print(len("hello"));
}  # same, but no pipe
