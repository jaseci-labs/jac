# Chapter 4: Functions, AI Functions, and Decorators

Jac provides a powerful function system with mandatory type annotations, built-in AI capabilities, decorators, and first-class support for functional programming patterns. This chapter builds a math functions library with AI-powered features and timing capabilities to demonstrate these features.

!!! topic "Function Philosophy"
    In Jac, functions are first-class citizens with mandatory typing that prevents runtime errors and improves code clarity. Jac also seamlessly integrates AI capabilities directly into the language.

## Function Definitions with Type Safety

### Basic Math Functions

!!! example "Basic Function Definitions"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic math functions with mandatory types
        def add(a: float, b: float) -> float {
            return a + b;
        }

        def multiply(a: float, b: float) -> float {
            return a * b;
        }

        def power(base: float, exponent: float) -> float {
            return base ** exponent;
        }

        # Function with error handling
        def safe_divide(a: float, b: float) -> float | None {
            if b == 0.0 {
                return None;
            }
            return a / b;
        }

        with entry {
            print(f"5 + 3 = {add(5.0, 3.0)}");
            print(f"4 * 6 = {multiply(4.0, 6.0)}");
            print(f"2^3 = {power(2.0, 3.0)}");
            print(f"10 / 2 = {safe_divide(10.0, 2.0)}");
            print(f"10 / 0 = {safe_divide(10.0, 0.0)}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Optional

        # Python functions with optional type hints
        def add(a: float, b: float) -> float:
            return a + b

        def multiply(a: float, b: float) -> float:
            return a * b

        def power(base: float, exponent: float) -> float:
            return base ** exponent

        # Function with error handling
        def safe_divide(a: float, b: float) -> Optional[float]:
            if b == 0.0:
                return None
            return a / b

        if __name__ == "__main__":
            print(f"5 + 3 = {add(5.0, 3.0)}")
            print(f"4 * 6 = {multiply(4.0, 6.0)}")
            print(f"2^3 = {power(2.0, 3.0)}")
            print(f"10 / 2 = {safe_divide(10.0, 2.0)}")
            print(f"10 / 0 = {safe_divide(10.0, 0.0)}")
        ```

### Advanced Math Functions

!!! topic "Complex Calculations"
    Build more sophisticated mathematical operations using Jac's type system.

!!! example "Advanced Mathematical Operations"
    === "Jac"
        <div class="code-block">
        ```jac
        # More complex math functions
        def factorial(n: int) -> int {
            if n <= 1 {
                return 1;
            }
            return n * factorial(n - 1);
        }

        def fibonacci(n: int) -> int {
            if n <= 1 {
                return n;
            }
            return fibonacci(n - 1) + fibonacci(n - 2);
        }

        def calculate_statistics(numbers: list[float]) -> dict[str, float] {
            if len(numbers) == 0 {
                return {"mean": 0.0, "sum": 0.0, "count": 0.0};
            }

            total = sum(numbers);
            count = len(numbers);
            mean = total / count;

            return {
                "sum": total,
                "count": float(count),
                "mean": mean
            };
        }

        with entry {
            print(f"5! = {factorial(5)}");
            print(f"Fibonacci(10) = {fibonacci(10)}");

            test_numbers = [1.0, 2.0, 3.0, 4.0, 5.0];
            stats = calculate_statistics(test_numbers);
            print(f"Statistics: {stats}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict

        # More complex math functions
        def factorial(n: int) -> int:
            if n <= 1:
                return 1
            return n * factorial(n - 1)

        def fibonacci(n: int) -> int:
            if n <= 1:
                return n
            return fibonacci(n - 1) + fibonacci(n - 2)

        def calculate_statistics(numbers: List[float]) -> Dict[str, float]:
            if len(numbers) == 0:
                return {"mean": 0.0, "sum": 0.0, "count": 0.0}

            total = sum(numbers)
            count = len(numbers)
            mean = total / count

            return {
                "sum": total,
                "count": float(count),
                "mean": mean
            }

        if __name__ == "__main__":
            print(f"5! = {factorial(5)}")
            print(f"Fibonacci(10) = {fibonacci(10)}")

            test_numbers = [1.0, 2.0, 3.0, 4.0, 5.0]
            stats = calculate_statistics(test_numbers)
            print(f"Statistics: {stats}")
        ```

## Built-in AI Function Calls

!!! topic "AI-Powered Functions"
    Jac makes AI integration simple with built-in functions that can perform natural language processing, reasoning, and other AI tasks directly in your code.

### Basic AI Functions

!!! example "Simple AI Function Calls"
    === "Jac"
        <div class="code-block">
        ```jac
        import from mtllm.llms { Gemini }

        glob llm = Gemini(
            model_name="gemini-2.0-flash"
        );

        glob GEMINI_API_KEY = "";

        # Basic AI function calls for text processing
        def analyze_sentiment(text: str) -> str {
            # AI function that analyzes sentiment
            sentiment = llm(f"Analyze the sentiment of this text: '{text}'. Return only 'positive', 'negative', or 'neutral'.");
            return sentiment.strip().lower();
        }

        def generate_math_explanation(problem: str, solution: float) -> str {
            # AI function that explains math solutions
            explanation = llm(f"Explain how to solve this math problem step by step: {problem} = {solution}");
            return explanation;
        }

        def classify_number_type(num: int) -> str {
            # AI function that classifies numbers
            classification = llm(f"Classify this number {num}. Is it prime, composite, or neither? Give a brief explanation.");
            return classification;
        }

        with entry {
            print("=== AI Function Examples ===");

            # Sentiment analysis
            texts = ["I love programming!", "This is frustrating", "The weather is okay"];
            for text in texts {
                sentiment = analyze_sentiment(text);
                print(f"'{text}' -> {sentiment}");
            }

            # Math explanation
            explanation = generate_math_explanation("5 + 3", 8.0);
            print(f"\nMath explanation:\n{explanation}");

            # Number classification
            numbers = [7, 12, 1];
            for num in numbers {
                classification = classify_number_type(num);
                print(f"\nNumber {num}: {classification}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        # Note: Python doesn't have built-in AI functions like Jac
        # This would require external libraries like OpenAI API

        # Simulated AI function responses for demonstration
        def analyze_sentiment(text: str) -> str:
            # Would need to call external API or use ML library
            # Simplified simulation based on keywords
            positive_words = ["love", "great", "awesome", "good"]
            negative_words = ["hate", "bad", "terrible", "frustrating"]

            text_lower = text.lower()
            if any(word in text_lower for word in positive_words):
                return "positive"
            elif any(word in text_lower for word in negative_words):
                return "negative"
            else:
                return "neutral"

        def generate_math_explanation(problem: str, solution: float) -> str:
            # Would need to call external AI API
            return f"To solve {problem}: Add the numbers together to get {solution}"

        def classify_number_type(num: int) -> str:
            # Would need to call external AI API
            if num < 2:
                return f"{num} is neither prime nor composite"
            for i in range(2, int(num**0.5) + 1):
                if num % i == 0:
                    return f"{num} is composite (divisible by {i})"
            return f"{num} is prime (only divisible by 1 and itself)"

        if __name__ == "__main__":
            print("=== AI Function Examples ===")

            # Sentiment analysis
            texts = ["I love programming!", "This is frustrating", "The weather is okay"]
            for text in texts:
                sentiment = analyze_sentiment(text)
                print(f"'{text}' -> {sentiment}")

            # Math explanation
            explanation = generate_math_explanation("5 + 3", 8.0)
            print(f"\nMath explanation:\n{explanation}")

            # Number classification
            numbers = [7, 12, 1]
            for num in numbers:
                classification = classify_number_type(num)
                print(f"\nNumber {num}: {classification}")
        ```

### AI-Enhanced Math Functions

!!! example "Combining AI with Traditional Math"
    === "Jac"
        <div class="code-block">
        ```jac
        import from mtllm.llms { Gemini }

        glob llm = Gemini(
            model_name="gemini-2.0-flash"
        );

        glob GEMINI_API_KEY = "";

        def calculate(text: str) -> str by llm(method='Reason');

        def generate_response(original_text: str) -> str by llm(method="Reason");

        # AI-enhanced math library
        def smart_calculator(expression: str) -> dict[str, any] {
            # Use AI to parse and solve math expressions
            result = calculate(f"Calculate this math expression and return only the numeric result: {expression}");

            try {
                numeric_result = float(result.strip());
                explanation = llm(f"Explain how to calculate {expression} step by step in simple terms");

                return {
                    "expression": expression,
                    "result": numeric_result,
                    "explanation": explanation
                };
            } except ValueError {
                return {
                    "expression": expression,
                    "result": None,
                    "error": "Could not parse result"
                };
            }
        }

        def ai_math_tutor(question: str) -> str {
            # AI tutoring for math concepts
            response = generate_response(f"You are a friendly math tutor. Answer this question in simple terms: {question}");
            return response;
        }

        with entry {
            print("=== AI-Enhanced Math Functions ===");

            # Smart calculator
            expressions = ["15 + 27", "8 * 7", "100 / 4"];
            for expr in expressions {
                result = smart_calculator(expr);
                print(f"\nExpression: {result['expression']}");
                print(f"Result: {result.get('result', 'Error')}");
                print(f"Explanation: {result.get('explanation', 'N/A')}");
            }

            # AI math tutor
            questions = [
                "What is the difference between prime and composite numbers?",
                "How do I calculate the area of a circle?"
            ];

            for question in questions {
                answer = ai_math_tutor(question);
                print(f"\nQ: {question}");
                print(f"A: {answer}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Dict, Any

        # AI-enhanced math library (simulated)
        def smart_calculator(expression: str) -> Dict[str, Any]:
            # Simplified calculator without AI
            try:
                # Basic expression evaluation (in real scenario, use safe eval)
                result = eval(expression)  # Note: eval is unsafe in production

                return {
                    "expression": expression,
                    "result": float(result),
                    "explanation": f"Calculate {expression} by performing the operation to get {result}"
                }
            except Exception as e:
                return {
                    "expression": expression,
                    "result": None,
                    "error": f"Could not calculate: {str(e)}"
                }

        def ai_math_tutor(question: str) -> str:
            # Simulated AI tutor responses
            responses = {
                "prime": "Prime numbers are numbers greater than 1 that are only divisible by 1 and themselves. Composite numbers have other divisors too.",
                "circle": "To find the area of a circle, use the formula A = π × r², where r is the radius."
            }

            question_lower = question.lower()
            for key, response in responses.items():
                if key in question_lower:
                    return response

            return "I'd be happy to help with math questions!"

        if __name__ == "__main__":
            print("=== AI-Enhanced Math Functions ===")

            # Smart calculator
            expressions = ["15 + 27", "8 * 7", "100 / 4"]
            for expr in expressions:
                result = smart_calculator(expr)
                print(f"\nExpression: {result['expression']}")
                print(f"Result: {result.get('result', 'Error')}")
                print(f"Explanation: {result.get('explanation', 'N/A')}")

            # AI math tutor
            questions = [
                "What is the difference between prime and composite numbers?",
                "How do I calculate the area of a circle?"
            ]

            for question in questions:
                answer = ai_math_tutor(question)
                print(f"\nQ: {question}")
                print(f"A: {answer}")
        ```

## Decorators for Enhanced Functionality

!!! topic "Decorators"
    Decorators provide a clean way to add functionality to functions without modifying their core logic.

### Timing Decorator

!!! example "Performance Timing Decorator"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        import time
        from typing import Callable, Any
        from functools import wraps

        # Timing decorator to measure function performance
        def timing_decorator(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(*args: Any, **kwargs: Any) -> Any:
                start_time = time.time()
                result = func(*args, **kwargs)
                end_time = time.time()
                execution_time = end_time - start_time
                print(f"{func.__name__} executed in {execution_time:.4f} seconds")
                return result
            return wrapper

        # Apply timing to our math functions
        @timing_decorator
        def slow_fibonacci(n: int) -> int:
            if n <= 1:
                return n
            return slow_fibonacci(n - 1) + slow_fibonacci(n - 2)

        @timing_decorator
        def slow_factorial(n: int) -> int:
            if n <= 1:
                return 1
            return n * slow_factorial(n - 1)

        if __name__ == "__main__":
            print("=== Timing Decorator Demo ===")
            result1 = slow_fibonacci(2)
            print(f"Fibonacci(2) = {result1}")

            result2 = slow_factorial(3)
            print(f"Factorial(3) = {result2}")
        ```

### Caching Decorator for Optimization

!!! example "Memoization Decorator"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        import time
        from typing import Callable, Any, Dict
        from functools import wraps

        # Caching decorator for expensive computations
        def cache_decorator(func: Callable) -> Callable:
            cache: Dict[str, Any] = {}

            @wraps(func)
            def wrapper(*args: Any) -> Any:
                # Create a simple cache key from arguments
                cache_key = str(args)

                if cache_key in cache:
                    print(f"Cache hit for {func.__name__}{args}")
                    return cache[cache_key]

                print(f"Computing {func.__name__}{args}")
                result = func(*args)
                cache[cache_key] = result
                return result
            return wrapper

        # Combine timing and caching decorators
        @timing_decorator
        @cache_decorator
        def optimized_fibonacci(n: int) -> int:
            if n <= 1:
                return n
            return optimized_fibonacci(n - 1) + optimized_fibonacci(n - 2)

        @timing_decorator
        @cache_decorator
        def expensive_calculation(n: int) -> int:
            # Simulate expensive computation
            result = 0
            for i in range(n * 1000):
                result += i
            return result

        if __name__ == "__main__":
            print("=== Cached Functions Demo ===")

            # First call - computed and cached
            result1 = optimized_fibonacci(3)
            print(f"Fibonacci(3) = {result1}")

            # Second call - retrieved from cache
            result2 = optimized_fibonacci(3)
            print(f"Fibonacci(3) again = {result2}")

            # Expensive calculation test
            result3 = expensive_calculation(10)
            print(f"Expensive calculation result: {result3}")

            # Second call to expensive calculation
            result4 = expensive_calculation(10)
            print(f"Expensive calculation again: {result4}")
        ```

## Lambda Functions and Functional Programming

!!! topic "Functional Programming"
    Lambda functions provide a concise way to create small, focused functions for data processing.

### Lambda Functions for Data Processing

!!! example "Lambda Functions in Data Processing"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Basic lambda functions for math operations
            square = lambda x: float: x * x;
            double = lambda x: float: x * 2;
            is_even = lambda x: int: x % 2 == 0;

            # Test basic lambdas
            print(f"square(5) = {square(5.0)}");
            print(f"double(7) = {double(7.0)}");
            print(f"is_even(4) = {is_even(4)}");

            # Using lambdas with lists
            numbers = [1.0, 2.0, 3.0, 4.0, 5.0];

            # Map operations
            squared_numbers = [square(x) for x in numbers];
            doubled_numbers = [double(x) for x in numbers];

            print(f"Original: {numbers}");
            print(f"Squared: {squared_numbers}");
            print(f"Doubled: {doubled_numbers}");

            # Filter operations
            int_numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
            even_numbers = [x for x in int_numbers if is_even(x)];
            print(f"Even numbers: {even_numbers}");
        }
        ```
        </div>
    === "Python"
        ```python
        if __name__ == "__main__":
            # Basic lambda functions for math operations
            square = lambda x: x * x
            double = lambda x: x * 2
            is_even = lambda x: x % 2 == 0

            # Test basic lambdas
            print(f"square(5) = {square(5.0)}")
            print(f"double(7) = {double(7.0)}")
            print(f"is_even(4) = {is_even(4)}")

            # Using lambdas with lists
            numbers = [1.0, 2.0, 3.0, 4.0, 5.0]

            # Map operations
            squared_numbers = [square(x) for x in numbers]
            doubled_numbers = [double(x) for x in numbers]

            print(f"Original: {numbers}")
            print(f"Squared: {squared_numbers}")
            print(f"Doubled: {doubled_numbers}")

            # Filter operations
            int_numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            even_numbers = [x for x in int_numbers if is_even(x)]
            print(f"Even numbers: {even_numbers}")
        ```

### Higher-Order Functions

!!! example "Functions that Work with Functions"
    === "Jac"
        <div class="code-block">
        ```jac
        # Higher-order function that applies operation to list
        def apply_operation(numbers: list[float], operation: callable[[float], float]) -> list[float] {
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

        # Reduce-like function
        def reduce_list(numbers: list[float], operation: callable[[float, float], float], initial: float) -> float {
            result = initial;
            for num in numbers {
                result = operation(result, num);
            }
            return result;
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

            # Function composition
            add_one = lambda x: float: x + 1.0;
            square_func = lambda x: float: x * x;
            add_then_square = compose(square_func, add_one);

            result = add_then_square(4.0);  # (4 + 1)^2 = 25
            print(f"(4 + 1)^2 = {result}");

            # Reduce operations
            sum_result = reduce_list(numbers, lambda a:float, b: float: a + b, 0.0);
            product_result = reduce_list(numbers, lambda a:float, b: float: a * b, 1.0);

            print(f"Sum: {sum_result}");
            print(f"Product: {product_result}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Callable

        # Higher-order function that applies operation to list
        def apply_operation(numbers: List[float], operation: Callable[[float], float]) -> List[float]:
            return [operation(num) for num in numbers]

        # Function that creates specialized functions
        def create_multiplier(factor: float) -> Callable[[float], float]:
            return lambda x: x * factor

        # Function composition
        def compose(f: Callable, g: Callable) -> Callable:
            return lambda x: f(g(x))

        # Reduce-like function
        def reduce_list(numbers: List[float], operation: Callable[[float, float], float], initial: float) -> float:
            result = initial
            for num in numbers:
                result = operation(result, num)
            return result

        if __name__ == "__main__":
            print("=== Higher-Order Functions Demo ===")

            numbers = [1.0, 2.0, 3.0, 4.0, 5.0]

            # Create specialized multiplier functions
            triple = create_multiplier(3.0)
            quadruple = create_multiplier(4.0)

            # Apply operations
            tripled = apply_operation(numbers, triple)
            quadrupled = apply_operation(numbers, quadruple)

            print(f"Original: {numbers}")
            print(f"Tripled: {tripled}")
            print(f"Quadrupled: {quadrupled}")

            # Function composition
            add_one = lambda x: x + 1.0
            square_func = lambda x: x * x
            add_then_square = compose(square_func, add_one)

            result = add_then_square(4.0)  # (4 + 1)^2 = 25
            print(f"(4 + 1)^2 = {result}")

            # Reduce operations
            sum_result = reduce_list(numbers, lambda a, b: a + b, 0.0)
            product_result = reduce_list(numbers, lambda a, b: a * b, 1.0)

            print(f"Sum: {sum_result}")
            print(f"Product: {product_result}")
        ```

## Async Functions

!!! topic "Asynchronous Programming"
    Jac supports async functions for handling concurrent operations and non-blocking I/O.

### Basic Async Functions

!!! example "Async Function Examples"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        import asyncio
        import time
        from typing import Dict, Any, List

        # Async function for simulated API calls
        async def fetch_data(source: str, delay: float) -> Dict[str, Any]:
            print(f"Starting to fetch from {source}...")
            await asyncio.sleep(delay)  # Simulate network delay

            return {
                "source": source,
                "data": f"Data from {source}",
                "timestamp": time.time()
            }

        # Async function that processes multiple sources
        async def gather_all_data() -> List[Dict[str, Any]]:
            # Run multiple async operations concurrently
            tasks = [
                fetch_data("API-1", 1.0),
                fetch_data("API-2", 0.5),
                fetch_data("API-3", 1.5)
            ]

            results = await asyncio.gather(*tasks)
            return results

        # Regular function that uses async
        def run_async_example() -> None:
            print("=== Async Functions Demo ===")

            # Run the async function
            results = asyncio.run(gather_all_data())

            print("All data fetched:")
            for result in results:
                print(f"  {result['source']}: {result['data']}")

        if __name__ == "__main__":
            run_async_example()
        ```

## Complete Example: AI-Enhanced Math Library

!!! example "Complete Library with AI and Traditional Functions"
    === "Jac"
        <div class="code-block">
        ```jac
        import time;

        # Combined timing and AI analysis decorator
        def smart_timing(func: callable) -> callable {
            def wrapper(*args: any, **kwargs: any) -> any {
                start_time = time.time();
                result = func(*args, **kwargs);
                end_time = time.time();
                execution_time = end_time - start_time;

                print(f"{func.__name__} executed in {execution_time}s");

                # AI insight for slow functions
                if execution_time > 0.5 {
                    insight = llm(f"Function {func.__name__} with args {args} took {execution_time} seconds. What might be causing this performance?");
                    print(f"AI Insight: {insight}");
                }

                return result;
            }
            return wrapper;
        }

        # Enhanced math library with AI capabilities
        obj SmartMathLibrary {
            has calculation_count: int = 0;

            @smart_timing
            def fibonacci(n: int) -> int;

            @smart_timing
            def explain_calculation(operation: str, result: any) -> str;

            def get_stats() -> dict[str, any];
        }

        impl SmartMathLibrary.fibonacci {
            self.calculation_count += 1;
            if n <= 1 {
                return n;
            }
            return self.fibonacci(n - 1) + self.fibonacci(n - 2);
        }

        impl SmartMathLibrary.explain_calculation {
            explanation = llm(f"Explain this calculation in simple terms: {operation} = {result}");
            return explanation;
        }

        impl SmartMathLibrary.get_stats {
            return {
                "total_calculations": self.calculation_count,
                "library_version": "2.0-AI"
            };
        }

        with entry {
            print("=== Smart Math Library Demo ===");

            math_lib = SmartMathLibrary();

            # Test Fibonacci
            fib_result = math_lib.fibonacci(3);
            print(f"Fibonacci(3) = {fib_result}");

            # Get AI explanation
            explanation = math_lib.explain_calculation("Fibonacci(3)", fib_result);
            print(f"AI Explanation: {explanation}");

            # Show stats
            stats = math_lib.get_stats();
            print(f"Library Stats: {stats}");
        }
        ```
        </div>
    === "Python"
        ```python
        import time
        from typing import Dict, Any, Callable
        from functools import wraps

        # Combined timing and AI analysis decorator (simulated)
        def smart_timing(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(self, *args: Any, **kwargs: Any) -> Any:
                start_time = time.time()
                result = func(self, *args, **kwargs)
                end_time = time.time()
                execution_time = end_time - start_time

                print(f"{func.__name__} executed in {execution_time:.4f}s")

                # Simulated AI insight for slow functions
                if execution_time > 0.001:  # Lower threshold for demo
                    insight = f"Function {func.__name__} with args {args} took {execution_time:.4f} seconds. Consider using memoization for recursive functions."
                    print(f"AI Insight: {insight}")

                return result
            return wrapper

        # Enhanced math library with AI capabilities
        class SmartMathLibrary:
            def __init__(self):
                self.calculation_count = 0

            @smart_timing
            def fibonacci(self, n: int) -> int:
                self.calculation_count += 1
                if n <= 1:
                    return n
                return self.fibonacci(n - 1) + self.fibonacci(n - 2)

            @smart_timing
            def explain_calculation(self, operation: str, result: Any) -> str:
                # Simulated AI explanation
                explanation = f"The calculation {operation} = {result} works by following the mathematical rules step by step."
                return explanation

            def get_stats(self) -> Dict[str, Any]:
                return {
                    "total_calculations": self.calculation_count,
                    "library_version": "2.0-AI"
                }

        if __name__ == "__main__":
            print("=== Smart Math Library Demo ===")

            math_lib = SmartMathLibrary()

            # Test Fibonacci
            fib_result = math_lib.fibonacci(3)
            print(f"Fibonacci(3) = {fib_result}")

            # Get AI explanation
            explanation = math_lib.explain_calculation("Fibonacci(3)", fib_result)
            print(f"AI Explanation: {explanation}")

            # Show stats
            stats = math_lib.get_stats()
            print(f"Library Stats: {stats}")
        ```

## Key Takeaways

!!! summary "Chapter Summary"
    - **Mandatory Types**: All function parameters and return types must be explicitly declared
    - **AI Integration**: Built-in `by llm()` function makes AI capabilities easily accessible
    - **Decorators**: Powerful tools for adding functionality like timing, caching, and AI analysis
    - **Lambda Functions**: Concise syntax for simple operations and functional programming
    - **Async Functions**: Support for concurrent operations and non-blocking I/O
    - **Performance**: Use decorators to add timing and AI insights without modifying core logic
    - **Code Organization**: Group related functions into objects or modules for better structure

!!! topic "Coming Up"
    In the next chapter, we'll dive deeper into advanced AI operations, exploring MTLLM variations, model configuration, and semantic strings for more sophisticated AI integration.
