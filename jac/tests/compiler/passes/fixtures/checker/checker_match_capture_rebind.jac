"""A match capture that reuses a local's name writes that local (#10564).

`case str() as title` binds the subject narrowed to the pattern, and a bare
`case title` binds the subject itself, so each is held to the local's frozen
type like any other rebind. A bare capture takes the subject without what
earlier unguarded cases matched.
"""

obj Label {
    has text: str = "";
}

obj Other {
    has code: int = 0;
}

obj Box {
    has content: str = "";
}

def as_pattern(v: object) {
    title = Label(text="a");
    match v {
        case str() as title:  # <-- Error
            print(1);

    }
    print(title.text);
}

def bare_capture(v: object) {
    title = Label(text="a");
    match v {
        case title:  # <-- Error
            print(1);

    }
}

def or_pattern(v: object) {
    n = 1;
    match v {
        case int() | str() as n:  # <-- Error
            print(n);

    }
}

def guarded_case_does_not_narrow(v: str | Label, flag: bool) {
    title = Label(text="a");
    match v {
        case str() if flag:
            print("s");

        case title:  # <-- Error
            print(title.text);

    }
}

def same_type(v: object) {
    title = Label(text="a");
    match v {
        case Label() as title:  # <-- Ok
            print(title.text);

    }
}

def narrowed_by_earlier_case(v: str | Label) {
    title = Label(text="a");
    match v {
        case str():
            print("s");

        case title:  # <-- Ok: the case above took every str
            print(title.text);

    }
}

def constrained_case_does_not_narrow(v: Other | Label) {
    title = Label(text="a");
    match v {
        case Other(code = 0):
            print("zero");

        case title:  # <-- Error
            print(title.text);

    }
}

def subject_narrower_than_pattern(v: str) {
    s = "";
    match v {
        case object() as s:  # <-- Ok: a str subject binds a str
            print(s);

    }
}

def nested_positional(v: object) {
    title = Label(text="a");
    match v {
        case Box(str() as title):  # <-- Error
            print(title);

    }
}

def nested_keyword_bare(v: object) {
    title = Label(text="a");
    match v {
        case Box(content = title):  # <-- Error
            print(title);

    }
}

def nested_keyword_wider_pattern(v: object) {
    s = "";
    match v {
        case Box(content = object() as s):  # <-- Ok: the field holds a str
            print(s);

    }
}

def first_binding(v: object) {
    match v {
        case str() as fresh:  # <-- Ok: the capture is the first binding
            print(fresh);

    }
}
