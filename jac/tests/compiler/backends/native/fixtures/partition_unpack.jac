def split_once(text: str, mark: str) -> str {
    (head, found, tail) = text.partition(mark);
    return head + "<" + found + ">" + tail;
}

def split_last(text: str, mark: str) -> str {
    (head, found, tail) = text.rpartition(mark);
    return head + "<" + found + ">" + tail;
}

def split_either(text: str, mark: str, first: bool) -> str {
    (head, found, tail) = text.partition(mark) if first else text.rpartition(mark);
    return head + "<" + found + ">" + tail;
}

with entry {
    print(split_once("a,b,c", ","), split_once("abc", ","));
    print(split_last("a,b,c", ","), split_last("abc", ","));
    print(split_either("a,b,c", ",", True), split_either("a,b,c", ",", False));
}
