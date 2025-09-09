## **Jac's Native Superset of Python**

At its core, Jac is a natural evolution of Python—not a replacement, but an enhancement. For Python developers, Jac offers a familiar foundation with powerful new features for modern software architecture, all while integrating seamlessly with the existing Python ecosystem.

### **How it Works: Transpilation to Native Python**

Unlike languages that require their own runtime environments, virtual machines, or interpreters, Jac programs execute on the standard Python runtime. Instead, the Jac compiler **transpiles** your Jac code into pure, efficient Python code. This means:

*   **100% Python Runtime:** Your Jac programs execute on the standard Python runtime, giving you access to Python's mature garbage collector, memory management, and threading model.
*   **Full Ecosystem Access:** Every package on PyPI, every internal library, and every Python tool you already use works out-of-the-box with Jac.

Essentially, Jac is to Python what TypeScript is to JavaScript: a powerful superset that compiles down to the language you know and love.

**Example: From Jac to Python**

A simple Jac module with archetypes, functions, and an entrypoint...

```jac
1 def foo() -> str {
2     return "Hello";
3 }
4
5 obj vehicle {
6     has name: str = "Car";
7 }
8
9 enum Size {
10    Small=1, Medium=2, Large=3
11 }
12
13 with entry {
14    car = vehicle();
15    print(foo());
16    print(car.name);
17    print(Size.Medium.value);
18 }
```

...is transpiled into familiar Python code that your Python interpreter runs natively.

```python
# Simplified Python equivalent
1 from enum import Enum
2
3 def foo() -> str:
4     return "Hello"
5
6 class vehicle:
7     def __init__(self) -> None:
8         self.name: str = "Car"
9
10 class Size(Enum):
11    Small = 1; Medium = 2; Large = 3
12
13 if __name__ == "__main__":
14    car = vehicle()
15    print(foo())
16    print(car.name)
17    print(Size.Medium.value)
```

---

### **Seamless Interoperability: Mix and Match**

Because Jac and Python share the same runtime and object model, you can mix them freely in your projects without any "glue" code.

#### **1. Using Python in Your Jac Code**

Import any Python module or library directly into your Jac files using familiar syntax. Jac automatically forwards any non-`.jac` imports to Python's native importer.

```jac
# mathstest.jac

# Import from Python's standard library
import math;

def area_of_circle(radius: float) -> float {
    return math.pi * radius * radius;
}

with entry {
    print("Area of circle with radius 2:", area_of_circle(2));
}
```

#### **2. Using Jac in Your Python Code**

Integrating Jac modules into an existing Python project is trivial. Simply import `jaclang` at the beginning of your Python entrypoint to activate the import hook.

```python
# main.py

# This one-time import enables Python to find and compile .jac files
import jaclang

# Now you can import your Jac modules just like any Python module
# Assumes you have a file named 'mathstest.jac'
import mathstest

# Use functions and archetypes defined in your Jac module
result = mathstest.area_of_circle(2)
print("Called from Python:", result)
```

---

### **Advanced Integration Patterns**

The integration goes even deeper, allowing you to choose the adoption strategy that fits your team's needs.

#### **1. Using Jac Features as a Python Library**

You can leverage Jac's powerful object-spatial programming model (nodes, edges, walkers) directly in your `.py` files without writing any Jac syntax. This is perfect for incrementally adopting Jac's architectural patterns.

```python
1 from jaclang import JacMachineInterface as _
2 from jaclang.runtimelib.archetype import NodeArchetype, WalkerArchetype
3
4 class Person(NodeArchetype):
5     name: str
6
7 class Greeter(WalkerArchetype):
8     @_.entry
9     def start(self, n: Person):
10        print(f"Hello, {n.name}!")
11
12 if __name__ == "__main__":
13    alice = Person(name="Alice")
14    walker = Greeter()
15    _.spawn(walker, alice)
```

#### **2. The Escape Hatch: Inlining Raw Python**

For situations where you need Python-specific syntax or want to gradually migrate a file, you can embed raw Python code directly inside a `.jac` module using the `::py::` directive.


```jac
1 with entry {
2     print("hello ");
3 }
4
5 ::py::
6 def foo():
7     print("world")
8
9 foo()
10 ::py::
```

Jac's relationship with Python isn't about choosing one over the other. It's about providing a powerful "and". You get the simplicity and vast ecosystem of Python and the advanced architectural constructs of Jac, all within a single, unified development experience.

This design philosophy means you can,

- Adopt Incrementally: Introduce Jac into your existing Python projects one file at a time, at your own pace.

- Leverage Everything: Continue using your favorite Python libraries, frameworks, and tools without any compatibility issues.

- Maintain Flexibility: Choose the level of integration that’s right for you—from writing full .jac modules to using Jac's features as a standard Python library.

- Eliminate Risk: With the ability to transpile Jac to readable Python, you’re never locked into a proprietary ecosystem.

Ultimately, Jac empowers you to write more structured, maintainable, and scalable code easily.