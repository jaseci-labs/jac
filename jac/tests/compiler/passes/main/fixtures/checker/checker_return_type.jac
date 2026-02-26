def foo() {
    return 1;  # <-- Error (no return annotation, but returning a value)


    return;  # <-- Ok


    return "";  # <-- Error (no return annotation, but returning a value)


    return None;  # <-- Ok

}

def bar()  -> int {
    return "";  # <-- Error


    return 1;  # <-- Ok


    return 1.1;  # <-- Error

}
