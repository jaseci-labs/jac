import from mathlib { add, subtract, multiply, divide, PI, E, Calculator }

with entry {
    print(f"Init reexport - add(5, 3): {add(5, 3)}");
    print(f"Init reexport - subtract(10, 4): {subtract(10, 4)}");
    print(f"Init reexport - multiply(6, 7): {multiply(6, 7)}");
    print(f"Init reexport - divide(20, 4): {divide(20, 4)}");
    print(f"Init reexport - PI: {PI}");
    print(f"Init reexport - E: {E}");
    calc = Calculator();
    print(
        f"Init reexport - Calculator.compute(10, 2, 'add'): {calc.compute(10, 2, 'add')}"
    );
}
