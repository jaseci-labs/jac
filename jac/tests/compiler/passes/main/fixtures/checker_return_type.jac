def foo() {
    return 1;  # <-- Error


    return;  # <-- Ok


    return "";  # <-- Error


    return None;  # <-- Ok

}

def bar()  -> int {
    return "";  # <-- Error


    return 1;  # <-- Ok


    return 1.1;  # <-- Error

}
