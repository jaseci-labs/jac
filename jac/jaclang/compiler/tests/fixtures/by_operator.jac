"""Test file for by operator."""

import from byllm.lib { MockLLM }

glob llm: MockLLM = MockLLM(
    model_name = "mockllm",
    outputs = [
        "Hello, Alice!",
        "Hello, Alice!",
    ],
);

def say_hello(name: str) -> str by llm();

walker greet {
    has name: str;

    def say_hello(name: str) -> str by llm();
    can do_it with `root entry {
        result = self.say_hello(self.name);
        print(result);
    }
}

with entry {
    # Test 1: Simple by expression
    result = "hello" by "world";
    print("Test 1:", result);

    # Test 2: Chained by expressions
    result2 = "a" by "b" by "c";
    print("Test 2:", result2);

    # Test 3: By with complex expressions
    result3 = (1 + 2) by (3 * 3) by (5 / 2 by 1);
    print("Test 3:", result3);

    # Test 4: By in assignment
    x = "input" by "output";
    print("Test 4:", x);

    # Test 5: By with LLM function
    result5 = say_hello("Alice");
    print("Test 5:", result5);

    # Test 6: Using walker with by operator
    greet(name="Bob") spawn root;

    # Test 7: By in loop
    for i = 0 to i < 5 by i += 1 {
        print(i);
    }
}
