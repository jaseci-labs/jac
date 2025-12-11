import from mylib.math_utils { add, multiply }
import from mylib.string_utils { greet }

with entry {
    print(f"add(3, 5): {add(3, 5)}");
    print(f"multiply(4, 6): {multiply(4, 6)}");
    print(f"greet('World'): {greet('World')}");
}
