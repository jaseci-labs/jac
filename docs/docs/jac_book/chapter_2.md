# 2. Variables, Types, and Basic Syntax
---
**Variables** how you store and manage data in your program. Each variable has a **type**, which tells Jac what kind of information it can hold, like numbers or text.


Jac requires you to declare the type for every variable you create. This is known as **strong typing**. Unlike in Python, where type hints are optional, Jac makes them mandatory. This helps you catch common errors such as runtime type errors early and makes your code easier to read and maintain, especially as your projects grow.


### Variable Declarations
To declare a variable in Jac, you specify its name, its type, and its initial value.

```jac
with entry {
    # Basic type annotations (Jac requires you to specify the type for each variable.)
    student_name: str = "Alice";
    grade: int = 95;
    gpa: float = 3.8;
    is_honor_student: bool = True;
}
```
<br />

A **literal** is a fixed value you write directly in your code, like "Alice" or 95. Jac uses common literals like *string*, *integer*, *float*, and *boolean*. It also introduces a special kind of literal called an **architype** (node, edge, and walker), which was briefly discussed in the prvious chapter.We will explore architypes in more detail later in chapter 9.

Jac supports both local and global variables. Local variables are defined within a block and are not accessible outside it, while global variables can be accessed anywhere in the code.

### Local Variables
```jac
def add_numbers(a: int, b: int) -> int {
    result: int = a + b;  # Local variable
    return result;
}
with entry {
    sum = add_numbers(5, 10);
    print(f"Sum: {sum}");
}
```
<br />

### Global Variables
Sometimes, you may need a variable that can be accessed from anywhere in your program. These are called global variables. In Jac, you can declare them using the `glob` keyword.
Global variables are most often used for defining constants, like configuration settings or version numbers, that need to be available throughout your code.


```jac
glob school_name: str = "Jac High School";
glob passing_grade: int = 60;
glob honor_threshold: float = 3.5;

def get_school_info() -> str {
    :g: school_name; # Accessing global variable
    return f"Welcome to {school_name}";
}

with entry {
    print(get_school_info());
    print(f"Honor threshold is {honor_threshold}");
}
```
<br />

### Integers
An integer is a whole number (without a decimal point). In Jac, you declare integers using the `int` type.

```jac
with entry {
    student_id: int = 12345;
    print(student_id);
}
```
<br />

### Floats
A float is a number with a decimal point. You declare floats using the `float` type.
```jac
with entry {
    gpa: float = 3.85;
    print(gpa);
}
```
<br />

### Strings
A string is a sequence of characters, like a name or a sentence. Strings are declared with the `str` type and are enclosed in quotes.

```jac
with entry {
    student_name: str = "Alice Johnson";
    # You can use f-strings to easily include variables in your output.
    print(f"Student Name: {student_name}");
}
```
<br />

### Booleans
A boolean represents a truth value: either True` or `False`. You declare booleans using the `bool` type.

```jac
with entry {
    is_enrolled: bool = True;
    print(f"Is enrolled: {is_enrolled}");
}
```
<br />




### Any Type for Flexibility
---
Sometimes, you may need a variable that can hold values of different types. For these situations, Jac provides the `any` type similar to Python's dynamic typing.

```jac
with entry {
    # This variable can hold different kinds of data.
    grade_data: any = 95;
    print(f"Grade as number: {grade_data}");

    # Now, we can assign a string to the same variable.
    grade_data = "A";  # Now a letter grade
    print(f"Grade as letter: {grade_data}");
}
```
<br />


## Jac REPL
---
!!! warning "Warning"
    The Jac REPL (Read-Eval-Print Loop) feature is currently under development and not yet available. Please run your code in files using the jac run command for now.

## Wrapping Up
---
In this chapter, we covered the basics of working with variables and types in Jac. You learned how to declare variables and use fundamental data types. This foundation is essential as we move on to explore Jac's more advanced features.


!!! tip "Try It Yourself"
    Practice the basics by creating:
    - A simple temperature converter (Celsius to Fahrenheit).
    - A basic calculator that can add, subtract, multiply, and divide.
    - An inventory tracker that stores an item's name (string), quantity (integer), and price (float).
    - A text processing utility

    Remember: As you build, focus on using the correct types for your variables. This is a key habit for writing good Jac code!

---
