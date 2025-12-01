"""Test file for by operator."""

import from byllm.lib { Model }

glob llm: Model = Model(model_name = "gpt-4o");

def say_hello(name: str) -> str by llm();

walker greet {
    has name: str;

    def say_hello(name: str) -> str by llm();
    can do_it with `root entry {
        result = self.say_hello(self.name);
        # return result;
        print("Greeting:", result);
    }
}

with entry {
    # Test 1: Simple by expression
    result = "hello" by "world";
    print("Test 1:", result);

    # Test 2: Chained by expressions
    result2 = "a" by "b" by "c";
    print("Test 2:", result2);

    # Test 3: By with function call
    def process(x: str) -> str {
        return x.upper();
    }
    result3 = "text" by process;
    print("Test 3:", result3);

    # Test 4: By with complex expressions
    result4 = (1 + 2) by (3 * 4) by (5 / 2 by 1);
    print("Test 4:", result4);

    # Test 5: By in assignment
    x = "input" by "output";
    print("Test 5:", x);

    result5 = say_hello("Alice");
    print("Test 6:", result5);

    greet(name="Bob") spawn root;

    print("By operator test file compiled and executed successfully!");
}
