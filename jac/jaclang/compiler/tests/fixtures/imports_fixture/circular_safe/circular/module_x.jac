glob VALUE_X = "Value from X";

def get_y_value -> str {
    # Import inside function to avoid circular import at module level
    import from .module_y { VALUE_Y }
    return f"X accessing Y: {VALUE_Y}";
}
