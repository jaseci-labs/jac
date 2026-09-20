def text(number: int) -> str {
    return "key" + str(number);
}

def optional_text(number: int) -> str | None {
    return text(number);
}

def pair(number: int) -> tuple[str, str] {
    return (text(number), text(number + 1));
}

def check -> bool {
    first = text(42);
    second = text(31);
    maybe = optional_text(17);
    values = pair(50);
    return first == "key42"
        and second == "key31"
        and maybe == "key17"
        and values[0] == "key50"
        and values[1] == "key51";
}
