import from typing { Any }

def takes_any(any: Any) { }

def test_any_type_arg()  -> int {
    val_int = 42;
    takes_any(val_int);  # <-- Ok
}
