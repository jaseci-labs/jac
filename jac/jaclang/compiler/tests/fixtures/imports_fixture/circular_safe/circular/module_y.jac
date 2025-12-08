# circular/module_y.jac
# Safe circular import - import inside function

glob VALUE_Y = "Value from Y";

def get_x_value -> str {
    import from .module_x { VALUE_X }
    return f"Y accessing X: {VALUE_X}";
}
