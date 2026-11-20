glob VALUE_Y = "Value from Y";

def get_x_value -> str {
    # Import inside function to avoid circular import at module level
    import from .module_x { VALUE_X }
    return f"Y accessing X: {VALUE_X}";
}
