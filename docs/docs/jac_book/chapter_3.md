# 3. Functions, Control Flow, and Collections in Jac
---
In this chapter, you will learn how to organize your code into reusable blocks called functions. We will also cover how to direct the flow of your program with control flow statements and how to work with groups of data using collections.

## Functions and Type Annotations
---

As your programs become more complex, you'll often find yourself writing the same lines of code in multiple places. **Functions** help you solve this by letting you group a block of code together and give it a name. You can then "call" that function whenever you need to perform that specific task, making your code cleaner and easier to manage.

In Jac, you define a function using the `def` keyword. Just like with variables, you must specify the data type for each of the function's parameters and for the value it returns.

Let's look at an example. Here is how you can create a simple function that adds two numbers together.

```jac
def add_numbers(a: int, b: int) -> int {
    result: int = a + b;
    return result;
}
```

### Basic Calculator Program
---
Let's put what you've learned about functions into practice by building a simple calculator. We will create four functions, one for each basic math operation: addition, subtraction, multiplication, and division.
Each function will take two numbers (floats) as input and return the result.

```jac
# calculator.jac
def add(a: float, b: float) -> float {
    return a + b;
}

def subtract(a: float, b: float) -> float {
    return a - b;
}

def multiply(a: float, b: float) -> float {
    return a * b;
}

def divide(a: float, b: float) -> float {
    return a / b;
}

with entry {
    print("=== Simple Calculator ===");

    # Test calculations
    num1: float = 10.0;
    num2: float = 3.0;

    print(f"{num1} + {num2} = {add(num1, num2)}");
    print(f"{num1} - {num2} = {subtract(num1, num2)}");
    print(f"{num1} * {num2} = {multiply(num1, num2)}");
    print(f"{num1} / {num2} = {divide(num1, num2)}");
}
```
<br />

You might have noticed that our `divide` function has a potential issue: it doesn't handle cases where the second number is zero. Trying to divide by zero will cause an error in our program.
Don't worry about this for now. We will cover how to handle potential errors gracefully in a later section. For now, this example shows how you can use functions to create a clean and organized program.

<br />

## Basic Object Oriented Programming
---
Jac is primarily an Object Spatial Language, but it also supports Object Oriented Programming (OOP) concepts. An object is a self-contained unit that combines data and behavior.
In Jac, you can define a blueprint for an object using the `obj`  keyword. Inside this blueprint, you define the object's data (called attributes) using the `has` keyword, and its behavior (called methods) using the `def` keyword.

Let's create a Student object to see how this works. A student has data (like a name, age, and GPA) and can also perform actions (like providing their information).

### Defining an Object
```jac
obj Student {
    has name: str;
    has age: int;
    has gpa: float;

     # Notice the 'self' parameter, which refers to the object itself.
    def get_info() -> str {
        return f"Name: {self.name}, Age: {self.age}, GPA: {self.gpa}";
    }
}

with entry {
    student: Student = Student("Alice", 20, 3.8);  # Create a new Student object
    print(student.get_info());
}
```
<br />

You might be wondering, "Where is the constructor or `__init__` method?" That's a great question! Jac simplifies the process. Instead of needing a special method to initialize the object, you simply define the attributes with `has` and provide their values directly when you create a new instance of the object.


!!! note
    If you have experience with Python, you might notice that Jac's `obj` works in a way that is similar to Python's dataclasses. They both provide a straightforward way to create objects that are primarily used to group and manage data.


### Enhanced Calculator with Object-Oriented Design
Now, let's improve our calculator by turning it into an object. By using an `obj`, we can not only group the calculation methods together but also add a new feature: a history of all the calculations we perform. This makes our calculator more powerful and easier to use.
We will create a Calculator object that has methods for adding and subtracting, as well as a history attribute to keep a record of each operation.

<div class="code-block">

```jac
# oop_calculator.jac

obj Calculator {
    has history: list[str] = [];

    def add(a: float, b: float) -> float {
        result: float = a + b;
        self.history.append(f"{a} + {b} = {result}");
        return result;
    }

    def subtract(a: float, b: float) -> float {
        result: float = a - b;
        self.history.append(f"{a} - {b} = {result}");
        return result;
    }

    def get_history() -> list[str] {
        return self.history;
    }

    def clear_history() {
        self.history = [];
    }
}

with entry {
    # First, create an instance of our Calculator object.
    calc = Calculator();

    # Perform calculations
    result1: float = calc.add(5.0, 3.0);
    result2: float = calc.subtract(10.0, 4.0);

    print(f"Results: {result1}, {result2}");

    # Show history
    print("\nCalculation History:");
    for entry in calc.get_history() {
        print(f"  {entry}");
    }
}
```
</div>
<br />

This example shows how you can use familiar Object-Oriented Programming (OOP) concepts right here in Jac. Jac is designed to work with both OOP and its own Object-Spatial features. This means you can start with what you know and then gradually incorporate Jac's unique graph-based tools, like nodes and walkers, when your project can benefit from them.


## Collections and Data Structures
---
Since Jac is a super-set of Python, it supports the same collection types: lists, dictionaries, sets, and tuples. However, Jac enforces type annotations for all collections, ensuring type safety and clarity.

### Lists
Lists are ordered collections of items that can be of mixed types. In Jac, lists are declared with the `list` type.

Let's create a list to store a student's grades.

```jac
with entry {
    # Create an empty list for storing integer grades
    alice_grades: list[int] = [];

    # Append grades to the list
    alice_grades.append(88); # [88]
    alice_grades.append(92); # [88, 92]
    alice_grades.append(85); # [88, 92, 85]

    # Access grades by index
    first_grade: int = alice_grades[0];  # 88
    print(f"Alice's first grade: {first_grade}");

    # print the entire list of grades
    print(f"Alice's grades: {alice_grades}");
}
```
<br />

```text
$ jac run example.jac
Alice's first grade: 88
Alice's grades: [88, 92, 85]
```


### Dictionaries
Dictionaries are perfect for storing data as key-value pairs, which allows you to look up a value instantly if you know its key. You declare a dictionary with the `dict` type, specifying the type for the keys and the values.

Here is how you could use a dictionary to create a gradebook where student names are the keys and their grades are the values.

```jac
with entry {
    # Class gradebook
    math_grades: dict[str, int] = {
        "Alice": 92,
        "Bob": 85,
        "Charlie": 78
    };

    # Access grades by student name
    print(f"Alice's Math grade: {math_grades['Alice']}");
    print(f"Bob's Math grade: {math_grades['Bob']}");
    print(f"Charlie's Math grade: {math_grades['Charlie']}");
}
```
<br />

```text
$ jac run example.jac
Alice's Math grade: 92
Bob's Math grade: 85
Charlie's Math grade: 78
```

### Sets
A set is an unordered collection that does not allow duplicate items. This makes them very useful for tasks like tracking unique entries or comparing two groups of data. You declare a set with the `set` type.

In this example, we'll use sets to find out which courses two students have in common.

```jac
with entry {
    # Track unique courses
    alice_courses: set[str] = {"Math", "Science", "English"};
    bob_courses: set[str] = {"Math", "History", "Art"};

    # Find common courses
    common_courses = alice_courses.intersection(bob_courses);
    print(f"Common courses: {common_courses}");

    # All unique courses
    all_courses = alice_courses.union(bob_courses);
    print(f"All courses: {all_courses}");
}
```
The `intersection` method finds items that are present in both sets, while the `union` method combines both sets into one, automatically removing any duplicates. These are standard operations provided by Python’s built-in `set` type, and Jac supports them as well. For a more comprehensive overview of collection-related functions in Python, refer to the [official Python documentation](https:#docs.python.org/3/tutorial/datastructures.html).


## Collection Comprehensions
---
Jac supports list and dictionary comprehensions, which are a concise and powerful way to create new collections by processing existing ones. Let's see how you can use them to work with a gradebook.

Imagine you have a list of test scores and you want to quickly create a new list containing only the passing grades.

```jac
with entry {
    # Raw test scores
    test_scores: list[int] = [78, 85, 92, 69, 88, 95, 72];

    # Get passing grades (70 and above)
    passing_scores: list[int] = [score for score in test_scores if score >= 70];
    print(f"Passing scores: {passing_scores}");
}
```
<br />

The list comprehension syntax in Jac is similar to Python:
```[expression for item in iterable if condition]``` where,
`expression` is the value to include in the new list,
`item` is the variable representing each element in the original collection,
`iterable` is the collection being processed, and
`condition` is an optional filter.

Now, what if you wanted to apply a curve by adding 5 points to every score? A comprehension makes this simple too.

```jac
with entry {
    # Raw test scores
    test_scores: list[int] = [78, 85, 92, 69, 88, 95, 72];

    # Get passing grades (70 and above)
    passing_scores: list[int] = [score for score in test_scores if score >= 70];
    print(f"Passing scores: {passing_scores}");

    # Create a new list where each score is 5 points higher.
    curved_scores: list[int] = [score + 5 for score in test_scores];
    print(f"Curved scores: {curved_scores}");
}
```
<br />

## Control Flow with Curly Braces
---
Earlier, we built a simple calculator but left a problem in our `divide` function: it couldn't handle division by zero. To write robust programs, you need to control if and when certain blocks of code are executed. Jac uses control flow statements like `if`, `elif`, and `else` for this, using curly braces {} to group the code for each block.


### If Statements
An `if` statement allows you to execute code conditionally based on whether a certain condition is true. In Jac, we use curly braces `{}` to define the block of code that should be executed if the condition is met.

Let's now fix our `divide` function. With an `if` statement, we can check if the second number is zero before we try to do the division. This allows us to handle the problem gracefully instead of letting our program crash.

```jac
# We can specify multiple possible return types using the '|' symbol.
def divide(a: float, b: float) -> float | str {
    # Check if b is zero before dividing.
    if b == 0.0 {
        return "Error: Cannot divide by zero!";
    }
    # If b is not zero, we can safely perform the division.
    return a / b;
}
```
<br />
In this updated function, we first check if b is equal to 0.0. If the condition is `True`, the code inside the curly braces {} is executed, and the function returns an error message. If the condition is `False`, the `if` block is skipped, and the function proceeds to the next line to perform the division.

### Conditional Logic `if-elif-else`

Often, you'll need to check for more than just one condition. For these situations, you can use a chain of `if`, `elif` (short for "else if"), and `else` statements. This lets you create a clear path for your program to follow based on different possibilities.

Let's expand on our gradebook example by creating a function that assigns a letter grade based on a score. We'll use a list comprehension to apply this function to a whole list of scores.


```jac
def classify_grade(score: int) -> str {
    if score >= 90 {
        return "A";
    } elif score >= 80 {
        return "B";
    } elif score >= 70 {
        return "C";
    } elif score >= 60 {
        return "D";
    } else {
        return "F";
    }
}

with entry {
    # Raw test scores
    test_scores: list[int] = [78, 85, 92, 69, 88, 95, 72];

    # Get passing grades (70 and above)
    passing_scores: list[int] = [score for score in test_scores if score >= 70];
    print(f"Passing scores: {passing_scores}");

    # Apply curve (+5 points)
    curved_scores: list[int] = [score + 5 for score in test_scores];
    print(f"Curved scores: {curved_scores}");

    # Classify each score
    grades: list[str] = [classify_grade(score) for score in test_scores];
    print(f"Grades: {grades}");
}
```
<br />

When you run this code, you'll see how the `classify_grade` function was applied to each score in the list:

```text
$ jac run example.jac
Passing scores: [78, 85, 92, 88, 95, 72]
Curved scores: [83, 90, 97, 74, 93, 100, 77]
Grades: ['C', 'B', 'A', 'D', 'B', 'A', 'C']
```

## Working with Loops
---
Loops allow you to run a block of code multiple times, which is essential for working with collections or performing repetitive tasks. Jac provides several ways to create loops, each suited for different situations including traditional `for` loops, Jac's unique `for-to-by` loops, and clear, structured `while` loops.

### Traditional For Loops

The standard `for` loop is used to iterate over the items in a collection, such as a list or a dictionary.
Let's write a function that calculates the average grade for each student in a class. We'll use a `for` loop to go through the dictionary of students and another nested `for` loop to go through each student's list of grades.

```jac

def process_class_grades(grades: dict[str, list[int]]) -> None {
    # This loop iterates through the key-value pairs in the dictionary.
    for (student, student_grades) in grades.items() {
        total: int = 0;
        # This nested loop iterates through the list of grades for each student.
        for grade in student_grades {
            total += grade;
        }
        average: float = total / len(student_grades);
        print(f"{student}'s average grade: {average}");
    }
}

with entry {
    class_grades: dict[str, list[int]] = {
        "Alice": [88, 92, 85],
        "Bob": [79, 83, 77],
        "Charlie": [95, 89, 92]
    };

    process_class_grades(class_grades);
}

```
 <br />

### Jac's Unique For-to-by Loops
Jac introduces a special `for-to-by` loop that gives you precise control over a sequence of numbers. This is useful when you need to iterate within a specific range with a defined step.

```jac
with entry {
    print("Converting scores (0-100) to GPA (0-4.0):");

    # This loop starts at 60, continues as long as score <= 100,
    # and increases the score by 10 in each step.
    for score = 60 to score <= 100 by score += 10 {
        gpa: float = (score - 60) * 4.0 / 40.0;
        print(f"Score {score} -> GPA {gpa}");
    }
}
```
<br />

### While Loops
A `while` loop continues to run as long as its condition remains True. This is useful when you don't know in advance how many times you need to loop.

```jac
with entry {
    count: int = 1;
    total: int = 0;

    # This loop will continue as long as 'count' is less than or equal to 5.
    while count <= 5 {
        print(f"Adding {count} to total");
        total += count;
        count += 1;
    }
    print(f"Final total: {total}");
}
```
<br />


## Pattern Matching for Complex Logic
---
When you have a variable that could be one of many different types or values, a long chain of if-elif-else statements can become hard to read. Pattern matching provides a cleaner and more powerful way to handle these complex situations.

```jac
def process_grade_input(input: any) -> str {
    # The 'match' statement checks the input against several possible patterns.
    match input {
        case int() if 90 <= input <= 100:
            return f"Excellent work! Score: {input}";
        case int() if 80 <= input < 90:
            return f"Good job! Score: {input}";
        case int() if 70 <= input < 80:
            return f"Satisfactory. Score: {input}";
        case int() if 0 <= input < 70:
            return f"Needs improvement. Score: {input}";
        case str() if input in ["A", "B", "C", "D", "F"]:
            return f"Letter grade received: {input}";
        case list() if len(input) > 0:
            avg = sum(input) / len(input);
            return f"Average of {len(input)} grades: {avg}";
        # The 'catch-all' case: If no other pattern matched.
        case _:
            return "Invalid grade input";
    }
}

with entry {
    print(process_grade_input(95));        # Number grade
    print(process_grade_input("A"));       # Letter grade
    print(process_grade_input([88, 92, 85])); # List of grades
}
```
<br />


## Exception Handling
---
Sometimes, things go wrong in a program unexpectedly. A user might enter invalid data, or a file might be missing. Exception handling allows you to anticipate these potential errors and manage them without crashing your program.

In Jac, you use a `try...except` block to do this. You put the code that might cause an error inside the `try` block, and the code to handle the error inside the `except` block. You can also use the raise keyword to create your own custom errors.

```jac
def safe_calculate_gpa(grades: list[int]) -> float {
    try {
        if len(grades) == 0 {
            # If the list of grades is empty, we create our own error.
            raise ValueError("No grades provided");
        }

        total = sum(grades);
        return total / len(grades);

    } except ValueError as e {
        # If a ValueError occurs, this block will run.
        print(f"Error: {e}");
        return 0.0;
    }
}

def validate_grade(grade: int) -> None {
    if grade < 0 or grade > 100 {
        raise ValueError(f"Grade {grade} is out of valid range (0-100)");
    }
}

with entry {
    # Test 1: A valid calculation.
    valid_grades: list[int] = [85, 90, 78];
    gpa: float = safe_calculate_gpa(valid_grades);
    print(f"The calculated GPA is: {gpa}");

     # Test 2: Handling a custom validation error.
    try {
        validate_grade(150);
    } except ValueError as e {
        print(f"A validation error occurred: {e}");
    }
}
```
<br />

## Comments in Jac
---
Comments help document your Jac code clearly. Jac supports both single-line and multiline comments.

```jac
with entry {
    # This is a single-line comment
    student_name: str = "Alice";

    #*
        This is a
        multi-line comment.
    *#

    grades: list[int] = [88, 92, 85];

    print(student_name);
    print(grades);
}
```
<br />

## Project Structure Conventions
---
As your Jac programs grow, keeping your code organized is key to making it easy to manage and update. Jac encourages a project structure that separates the what from the how—that is, separating the definition of your objects from the code that makes them work.

A good way to structure your project is to create different folders for your main program logic, your data models, and any utility functions you might need.

Here is a common and effective way to organize a Jac project:

```
my_project/
├── main.jac              # Main program
├── models/
│   ├── user.jac          # User interface
│   ├── user.impl.jac     # User implementation
│   └── user.test.jac     # User tests
└── utils/
    ├── helpers.jac       # Helper functions
    └── constants.jac     # Application constants
```
<br />

### Interface and Implementation Separation
You'll notice that for our User model, we have two files: `user.jac` and `user.impl.jac`. This is a recommended practice in Jac for keeping your code clean. `user.jac` and `user.impl.jac`. The interface file (.jac) is like a blueprint. It defines what an object looks like—its attributes and the methods it should have. The implementation file (.impl.jac) contains the actual code that makes the methods work.

Let's look at an example. We want to create a User object that has a `name` and an `email`. We also need methods to validate the user's information and to get a nicely formatted display name.

First, we define the interface in `user.jac`. This file outlines the structure of our User object.

```jac
# user.jac - Interface declaration
obj User {
    # It has these attributes.
    has name: str;
    has email: str;

    # And it must have these methods.
    # We don't write the code for them here.
    def validate() -> bool;
    def get_display_name() -> str;
}
```
<br />
Next, we provide the implementation in `user.impl.jac`. This is where we write the code for the methods we defined in the interface. Jac automatically links these implementation blocks to the interface.

```jac
# user.impl.jac - Implementation

# The implementation for the validate() method.
impl User.validate {
    # It checks if the email contains an '@' and the name is not empty.
    return "@" in self.email and len(self.name) > 0;
}

# The implementation for the get_display_name() method.
impl User.get_display_name {
    return f"{self.name} <{self.email}>";
}
```
<br />



## Common Beginner Mistakes and Solutions
---
Most beginner issues stem from Jac's stricter type requirements compared to Python. Here are the most common mistakes and their solutions.

| **Issue** | **Solution** |
|-----------|--------------|
| Missing semicolons | Add `;` at the end of statements |
| Missing type annotations | Add types to all variables: `x: int = 5;` |
| No entry block | Add `with entry { ... }` for executable scripts |
| Python-style indentation | Use `{ }` braces instead of indentation |

### Example of Common Fixes
Someone unfamiliar with Jac might write code like this:

```jac
# This won't work - missing types and semicolons
def greet(name) {
    return f"Hello, {name}"
}

# Missing entry block
print(greet("World"))
```
<br />

The corrected version of the code would be:
```jac
# This works - proper types and syntax
def greet(name: str) -> str {
    return f"Hello, {name}";
}

with entry {
    print(greet("World"));
}
```
<br />




## Complete Example: Simple Grade Book System
---
Let's bring everything you've learned in this chapter together to build a complete program. We will create a simple gradebook system using an object to manage students and their grades. This example will showcase how functions, collections, and control flow work together in a practical application.
First, we will define the interface for our `GradeBook` object, outlining its attributes and methods.

<div class="code-block">

```jac
obj GradeBook {
    has students: dict[str, list[int]] = {};

    def add_student(name: str) -> None;
    def add_grade(student: str, grade: int) -> None;
    def get_average(student: str) -> float;
    def get_all_averages() -> dict[str, float];
}

impl GradeBook.add_student(name: str) -> None {
    if name not in self.students {
        self.students[name] = [];
        print(f"Added student: {name}");
    } else {
        print(f"Student {name} already exists");
    }
}

impl GradeBook.add_grade(student: str, grade: int) -> None {
    if grade < 0 or grade > 100 {
        print(f"Invalid grade: {grade}");
        return;
    }

    if student in self.students {
        self.students[student].append(grade);
        print(f"Added grade {grade} for {student}");
    } else {
        print(f"Student {student} not found");
    }
}

impl GradeBook.get_average(student: str) -> float {
    if student not in self.students or len(self.students[student]) == 0 {
        return 0.0;
    }
    grades = self.students[student];
    return sum(grades) / len(grades);
}

impl GradeBook.get_all_averages() -> dict[str, float] {
    averages: dict[str, float] = {};
    for (student, grades) in self.students.items() {
        if len(grades) > 0 {
            averages[student] = sum(grades) / len(grades);
        }
    }
    return averages;
}

with entry {
    # Create gradebook
    gradebook = GradeBook();

    # Add students
    gradebook.add_student("Alice");
    gradebook.add_student("Bob");

    # Add grades
    gradebook.add_grade("Alice", 88);
    gradebook.add_grade("Alice", 92);
    gradebook.add_grade("Bob", 85);
    gradebook.add_grade("Bob", 79);

    # Get results
    all_averages = gradebook.get_all_averages();
    for (student, avg) in all_averages.items() {
        letter = "A" if avg >= 90 else "B" if avg >= 80 else "C" if avg >= 70 else "F";
        print(f"{student}: {avg} ({letter})");
    }
}
```
</div>
<br />



## Wrapping Up
---

Congratulations! You've just covered the essential building blocks of the Jac programming language. In this chapter, you learned about:
- Jac's strong type system and how to declare variables.
- Creating reusable code with functions and objects.
- Directing your program's logic with control flow statements like if, for, and while.
- Managing data with collections like lists and dictionaries.
- Handling errors gracefully with exception handling.
- Organizing your code with a clean project structure.

These fundamental concepts will be your foundation as you begin to explore the more advanced features that make Jac truly powerful.

---

*Now that you have a solid grasp of Jac's core syntax, you're ready to move on to the next chapter. We'll explore how to integrate AI directly into your programs and work with Jac's unique graph-based data structures.*
