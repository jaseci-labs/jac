# Chapter 4: A Deeper Look at Functions
---

In this chapter, we will explore the more advanced capabilities of functions in Jac. You will learn how Jac supports functional programming patterns, how to use functions as first-class citizens, and how to integrate AI directly into your function definitions. We will build a small math library to demonstrate these features in a practical context.

> In Jac, functions are treated as first-class citizens, meaning they can be stored in variables, passed as arguments to other functions, and returned from them, just like any other data type such as an integer or a string.

## Functional Programming in Jac
---
Functional programming is a style of writing software that treats computation as the evaluation of mathematical functions. While Jac is not a strict functional programming language, it provides strong support for functional programming concepts, enabling you to write more modular and expressive code.


### Function as First-Class Citizens
The core principle of functional programming is treating functions as first-class citizens. This means you can handle functions with the same flexibility as any other variable.

Let's revisit the calculator we built in Chapter 3. This time, we will redesign it using functional programming principles to make it more flexible and easier to extend.

First, we will create a single, generic `calculator` function. Instead of performing a specific operation like addition, this function will take an operation as one of its arguments.

```jac
# This function takes two numbers and another function as input.
# The `callable` type annotation indicates that `operation` is expected to be a function.
def calculator(a: float, b: float, operation: callable) -> float {
    return operation(a, b);
}
```
<br />

Next, we can define our basic arithmetic operations as standalone functions.

```jac
# These are the individual operations we can pass to our main calculator function.
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
    if b == 0 {
        raise ValueError("Cannot divide by zero");
    }
    return a / b;
}
```

Now, we can create a dictionary using `dict` keyword that maps a string (like "add") to the actual function object (like add). This allows us to select an operation dynamically using its name.


```jac
# A global dictionary to map operation names to their corresponding functions.
glob operations: dict[str, callable] = {
    "add": add,
    "subtract": subtract,
    "multiply": multiply,
    "divide": divide
};
```
<br />

Finally, let's put it all together. Our main execution block can now use the calculator function and the operations dictionary to perform calculations dynamically.

``` jac

# Main entry point for the program
with entry {
    a: float = 10.0;
    b: float = 5.0;

    # To test other operations, simply change this string.
    operation_name: str = "add";

    # Check if the requested operation exists in our dictionary.
    if operation_name in operations {
        # Look up the function in the dictionary and pass it to the calculator.
        selected_operation_func = operations[operation_name];
        result: float = calculator(a, b, selected_operation_func);
        print(f"Result of {operation_name}({a}, {b}) = {result}");
    } else {
        print(f"Operation '{operation_name}' is not supported.");
    }
}

```
This design is highly flexible. To add a new operation, like exponentiation, you would simply define a new `power` function and add it to the operations dictionary. You wouldn't need to change the core calculator logic at all. This demonstrates the power of treating functions as first-class data.

<br />


### Lambda Functions
In Jac, a lambda function is a concise, single-line, anonymous function. These are useful for short, specific operations where defining a full function with def would be unnecessarily verbose.

Lambda functions use the syntax lambda `lambda parameters: return_type: expression`. They can be assigned to a variable or used directly as an argument to another function.They are also useful for functional programming patterns like map, filter, and reduce.

For example, a simple add function can be defined as a lambda:

```jac
# This lambda takes two `float` parameters, `a` and `b`, and returns their sum as a `float`. It can be called just like a regular function.
add = lambda x: float, y: float: x + y;
```
<br />


```jac
with entry {
    add = lambda x: float, y: float: x + y;

    a: float = 10.0;
    b: float = 5.0;

    # Using the lambda function
    result: float = add(a, b);
    print(f"Result of add({a}, {b}) = {result}");
}
```
<br />

### Higher-Order Functions
A higher-order function is a function that either takes another function as an argument, returns a function, or both. This is a powerful concept that enables functional programming patterns, promoting code that is abstract, reusable, and composable.

The `callable` type hint is used to specify that a parameter or return value is expected to be a function.

```jac
# Higher-order function that applies operation to list
def apply_operation(numbers: list[float], operation: callable) -> list[float] {
    return [operation(num) for num in numbers];
}

# Function that creates specialized functions
def create_multiplier(factor: float) -> callable[[float], float] {
    return lambda x: float: x * factor;
}

# Function composition
def compose(f: callable, g: callable) -> callable {
    return lambda x: any: f(g(x));
}

with entry {
    print("=== Higher-Order Functions Demo ===");

    numbers = [1.0, 2.0, 3.0, 4.0, 5.0];

    # Create specialized multiplier functions
    triple = create_multiplier(3.0);
    quadruple = create_multiplier(4.0);

    # Apply operations
    tripled = apply_operation(numbers, triple);
    quadrupled = apply_operation(numbers, quadruple);

    print(f"Original: {numbers}");
    print(f"Tripled: {tripled}");
    print(f"Quadrupled: {quadrupled}");
}
```
<br />

### Built-in Higher-Order Functions `map`, `filter`, and `sorted`
Jac supports Python's essential built-in higher-order functions, which are powerful tools for working with lists and other collections without writing explicit loops.

### *filter*

The `filter` function constructs a new iterable from elements of an existing one for which a given function returns True.

Its signature is `filter(function, iterable)`.

Let's revisit our grade-filtering example from Chapter 3. Instead of a list comprehension, we can use filter with a lambda function to define our condition.


```jac
with entry {
    # Raw test scores
    test_scores: list = [78, 85, 92, 69, 88, 95, 72];

    # Get passing grades (70 and above)
    passing_scores: list = [score for score in test_scores if score >= 70];
    print(f"Passing scores: {passing_scores}");
}
```
<br />

The same result can be achieved using the `filter` function along with a lambda function to define the filtering condition.

```jac
with entry {
    test_scores: list[int] = [78, 85, 92, 69, 88, 95, 72];

    # The lambda `lambda score: bool: score >= 70` returns True for passing scores.
    # 'filter' applies this lambda to each item in 'test_scores'.
    passing_scores_iterator = filter(lambda score: float: score >= 70, test_scores);

    # The result of 'filter' is an iterator, so we convert it to a list to see the results.
    passing_scores: list[int] = list(passing_scores_iterator);
    print(f"Passing scores: {passing_scores}");
}
```
<br />


### *map*
The `map` function applies a given function to every item of an iterable and returns an iterator of the results.
Its signature is `map(function, iterable)`. This is ideal for transforming data without writing explicit loops.

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
    test_scores = [78, 85, 92, 69, 88, 95, 72];

    # Get passing grades (70 and above) using filter
    passing_scores = list(filter(lambda x: float: x >= 70, test_scores));
    print(f"Passing scores: {passing_scores}");

    # Get the grade of passing scores using map
    grades = list(map(classify_grade, passing_scores));
    print(f"Grades: {grades}");
}
```
<br />

### *sorted*
The `sorted` function returns a new sorted list from the items in an iterable. You can customize the sorting logic by providing a function to the `key` parameter.

```jac
with entry {
    # A list of tuples: (student_name, final_score)
    student_records: list[tuple[str, int]] = [("Charlie", 88), ("Alice", 95), ("Bob", 72)];

    # Sort alphabetically by name (the first item in each tuple).
    sorted_by_name = sorted(student_records, key=lambda record: str: record[0]);
    print(f"Sorted by name: {sorted_by_name}");

    # Sort numerically by score (the second item), in descending order.
    sorted_by_score = sorted(student_records, key=lambda record: int: record[1], reverse=True);
    print(f"Sorted by score (desc): {sorted_by_score}");
}
```
<br />



## Decorators for Enhanced Functionality
---
As your programs grow, you'll often need to add cross-cutting functionality—like logging, timing, or caching—to multiple functions. Modifying each function directly would be repetitive and error-prone. Decorators solve this problem by providing a clean way to wrap a function with extra behavior.

A decorator is a function that takes another function as an argument, adds some functionality, and returns a new function.


Consider the following example of a simple decorator that adds pre- and post-processing logic to a function.

The decorator function call `decorator_name` takes a function `func` as an argument and wraps it in a new function `wrapper` that adds additional behavior before and after calling the original function. The decorator returns the `wrapper` function, which is then used to replace the original function when the decorator is applied.

```jac
def decorator_name(func: callable) -> callable {
    def wrapper(*args: any, **kwargs: any) -> any {
        # Pre-processing logic
        result = func(*args, **kwargs);
        # Post-processing logic
        return result;
    }
    return wrapper;
}
```

!!! note
    `*args` is a python contruct that allows a function to accept a variable number of positional arguments, while `**kwargs` allows it to accept a variable number of keyword arguments.


Decorators provide a clean way to add functionality to functions without modifying their core logic. The general syntax for using decorators in Jac is:

```jac
@decorator_name
def function_name(parameters) -> return_type {
    # function body
}
```
<br />


### Decorator Stacking Order
You can apply multiple decorators to a single function. They are applied from the bottom up the decorator closest to the function definition is applied first.

```jac
import time;

def decorator_a(func: callable) -> callable {
    def wrapper(*args: any, **kwargs: any) -> any {
        print("Decorator A Start");
        result = func(*args, **kwargs);
        print("Decorator A End");
        return result;
    }
    return wrapper;
}

def decorator_b(func: callable) -> callable {
    def wrapper(*args: any, **kwargs: any) -> any {
        print("Decorator B Start");
        result = func(*args, **kwargs);
        print("Decorator B End");
        return result;
    }
    return wrapper;
}

# Decorator 'b' is applied first, then 'a' wraps 'b'.
@decorator_a
@decorator_b
def greet(name: str) -> None {
    print(f"Hello, {name}!");
}

with entry {
    greet("Alice");
}
```
<br />

The output will show that decorator B's "start" and "end" messages are nested inside decorator A's messages.

### Parameterized Decorators
For more flexibility, decorators can accept their own parameters. This requires an extra layer of nesting in the decorator function.

```jac
# This outer function takes the decorator's parameter.
def repeat(times: int) -> callable {
    # The second layer is the actual decorator.
    def decorator(func: callable) -> callable {
        # The third layer is the wrapper.
        def wrapper(*args: any, **kwargs: any) -> any {
            result: any;
            for i in range(times) {
                print(f"Execution {i+1} of {times}");
                result = func(*args, **kwargs);
            }
            return result;
        }
        return wrapper;
        }
    return decorator;
}

@repeat(3)
def say_hello(name: str) -> None {
    print(f"Hello, {name}");
}

with entry {
    say_hello("Bob");
}
```
<br />

This will print "Hello, Bob!" three times, as specified by the `@repeat(times=3)` parameter.

### Error Handling in Decorators

Decorators in Jac can handle exceptions, retry operations, and log errors gracefully.

```jac
import time;

def retry_decorator(max_retries: int, delay: float) -> callable {
    def decorator(func: callable) -> callable {
        def wrapper(*args: any, **kwargs: any) -> any {
            attempts: int = 0;
            while attempts < max_retries {
                try {
                    return func(*args, **kwargs);
                } except Exception as e {
                    attempts += 1;
                    print(f"Attempt {attempts} failed: {e}");
                    time.sleep(delay);
                }
            }
            raise Exception("Maximum retries exceeded");
        }
        return wrapper;
    }
    return decorator;
}

@retry_decorator(max_retries=3, delay=1.0)
def risky_operation() -> None {
    import random;
    if random.random() < 0.7 {
        raise ValueError("Random failure");
    }
    print("Operation succeeded!");
}

with entry {
    risky_operation();
}
```
<br />

### Timing Decorator
A timing decorator is a simple way to measure the performance of your functions.

```jac
import time;

# Timing decorator to measure function performance
def timing_decorator(func: callable) -> callable {
    def wrapper(*args: any, **kwargs: any) -> any {
        start_time = time.time();
        result = func(*args, **kwargs);
        end_time = time.time();
        execution_time = end_time - start_time;
        print(f"{func.__name__} executed in {execution_time} seconds");
        return result;
    }
    return wrapper;
}

# Apply timing to our math functions
@timing_decorator
def slow_fibonacci(n: int) -> int {
    if n <= 1 {
        return n;
    }
    return slow_fibonacci(n - 1) + slow_fibonacci(n - 2);
}

@timing_decorator
def slow_factorial(n: int) -> int {
    if n <= 1 {
        return 1;
    }
    return n * slow_factorial(n - 1);
}

with entry {
    print("=== Timing Decorator Demo ===");
    result1 = slow_fibonacci(2);
    print(f"Fibonacci(2) = {result1}");

    result2 = slow_factorial(3);
    print(f"Factorial(3) = {result2}");
}
```
<br />

### Caching (Memoization) Decorator
For functions that perform expensive calculations, a caching decorator can store results and return them instantly on subsequent calls with the same arguments. This technique is known as memoization.

```jac
import time;

# Timing decorator to measure function performance
def timing_decorator(func: callable) -> callable {
    def wrapper(*args: any, **kwargs: any) -> any {
        start_time = time.time();
        result = func(*args, **kwargs);
        end_time = time.time();
        execution_time = end_time - start_time;
        print(f"{func.__name__} executed in {execution_time} seconds");
        return result;
    }
    return wrapper;
}

# Caching decorator for expensive computations
def cache_decorator(func: callable) -> callable {
    cache: dict[str, any] = {};

    def wrapper(*args: any) -> any {
        # Create a simple cache key from arguments
        cache_key = str(args);

        if cache_key in cache {
            print(f"Cache hit for {func.__name__}{args}");
            return cache[cache_key];
        }

        print(f"Computing {func.__name__}{args}");
        result = func(*args);
        cache[cache_key] = result;
        return result;
    }
    return wrapper;
}

# Combine timing and caching decorators
@timing_decorator
@cache_decorator
def optimized_fibonacci(n: int) -> int {
    if n <= 1 {
        return n;
    }
    return optimized_fibonacci(n - 1) + optimized_fibonacci(n - 2);
}

@timing_decorator
@cache_decorator
def expensive_calculation(n: int) -> int {
    # Simulate expensive computation
    result = 0;
    for i in range(n * 1000) {
        result += i;
    }
    return result;
}

with entry {
    print("=== Cached Functions Demo ===");

    # First call - computed and cached
    result1 = optimized_fibonacci(3);
    print(f"Fibonacci(3) = {result1}");

    # Second call - retrieved from cache
    result2 = optimized_fibonacci(3);
    print(f"Fibonacci(3) again = {result2}");

    # Expensive calculation test
    result3 = expensive_calculation(10);
    print(f"Expensive calculation result: {result3}");

    # Second call to expensive calculation
    result4 = expensive_calculation(10);
    print(f"Expensive calculation again: {result4}");
}
```
<br />


## Async Functions
---
Some tasks, like network requests or reading large files, are I/O-bound. This means your program spends most of its time waiting for an external resource. During this waiting time, a standard program sits idle.

Jac's support for async functions allows your program to perform other work while it waits, leading to significant performance improvements for I/O-bound applications. This is known as concurrency.

- `async def`: Marks a function as a "coroutine"—a special function that can be paused and resumed.
- `await`: Pauses the execution of the current coroutine, allowing the program to work on other tasks until the awaited operation (e.g., a network call) is complete.

### Basic Async Functions

```jac
import asyncio;
import time;

# Async function for simulated API calls
async def fetch_data(source: str, delay: float) -> dict[str, any] {
    print(f"Starting to fetch from {source}...");
    await asyncio.sleep(delay);  # Simulate network delay

    return {
        "source": source,
        "data": f"Data from {source}",
        "timestamp": time.time()
    };
}

# Async function that processes multiple sources
async def gather_all_data() -> list[dict[str, any]] {
    # Run multiple async operations concurrently
    tasks = [
        fetch_data("API-1", 1.0),
        fetch_data("API-2", 0.5),
        fetch_data("API-3", 1.5)
    ];

    results = await asyncio.gather(*tasks);
    return results;
}

# Regular function that uses async
def run_async_example() -> None {
    print("=== Async Functions Demo ===");

    # Run the async function
    results = asyncio.run(gather_all_data());

    print("All data fetched:");
    for result in results {
        print(f"  {result['source']}: {result['data']}");
    }
}

with entry {
    run_async_example();
}
```
<br />

## Best Practices
---
- **Use descriptive names**: Function names should clearly indicate their purpose
- **Keep functions focused**: Each function should have a single, well-defined responsibility
- **Handle errors gracefully**: Use appropriate return types and exception handling
- **Leverage decorators**: Use decorators for cross-cutting concerns like timing and caching
- **Document with types**: Let type annotations serve as documentation
- **Consider async**: Use async functions for I/O-bound operations

## Wrapping Up
---

In this chapter, we looked at higher order functions, decorators, and async functions in Jac. We explored how to use these features to create flexible, reusable code that can handle complex operations efficiently.


*Ready to explore advanced AI operations? Continue to [Chapter 5: Advanced AI Operations](chapter_5.md)!*
