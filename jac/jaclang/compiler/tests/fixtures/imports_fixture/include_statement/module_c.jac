# Fixture 03: From-import star (2 files)
# module_c.jac - module with public symbols
glob PUBLIC_VAR = "I am public";
glob _PRIVATE_VAR = "I am private";

def public_func -> str {
    return "Public function";
}

def _private_func -> str {
    return "Private function";
}
