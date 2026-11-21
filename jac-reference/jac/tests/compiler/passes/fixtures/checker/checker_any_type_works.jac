
def takes_any(any: any) { }

def test_any_type_arg()  -> int {
    val_int = 42;
    takes_any(val_int);  # <-- Ok
    return val_int;
}
