import from circular.module_x { VALUE_X, get_y_value }
import from circular.module_y { VALUE_Y, get_x_value }

with entry {
    print(f"Circular safe - VALUE_X: {VALUE_X}");
    print(f"Circular safe - VALUE_Y: {VALUE_Y}");
    print(f"Circular safe - get_y_value(): {get_y_value()}");
    print(f"Circular safe - get_x_value(): {get_x_value()}");
}
