# circular/module_x.jac
# Safe circular import - import inside function
glob VALUE_X = "Value from X";

def get_y_value -> str {
    import from .module_y { VALUE_Y }
    return f"X accessing Y: {VALUE_Y}";
}
