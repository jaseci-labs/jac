import from byllm.lib { MockLLM, MockToolCall }

"""Run Python code and return the output, if any error exists, return the error message."""
def run_and_test_python_code(code: str) -> str {
    try {
        print("[run_and_test_python_code] Executing code:");
        print(f"[run_and_test_python_code] {repr(code)}");
        exec(code, {}, {});
        print("[run_and_test_python_code] Code executed successfully.");
        return "Code executed successfully.";
    } except Exception as e {
        print("[run_and_test_python_code] Error occurred.");
        return f"Error executing code: {str(e)}";
    }
}

glob models = {
         "text-gen": MockLLM(
             # model_name="gpt-4o-mini",
             model_name="mockllm",
             config={"outputs": ["Hello, Alice! It's great to see you!"]}
         ),
         "code-gen": MockLLM(
             # model_name="gpt-4o-mini",
             model_name="mockllm",
             config={
                 "outputs": [
                     MockToolCall(
                         tool=run_and_test_python_code,
                         args={
                             "code": "name = 'Alice'\nprint(f'Hello, {name}! Welcome to the Python world!')"
                         }
                     ),
                     "name = 'Alice'\nprint(f'Hello, {name}! Welcome to the Python world!')"
                 ]
             },
         )(
             tools=[run_and_test_python_code]
         ),

     };

""" Generate a greeting text for the given person's name.  """
def generate_greeting_text(name: str) -> str by models["text-gen"];

"""
Generate a python greeting code for the given person's name.
Make sure to use the given tools run the code to verify the generated
code is correct and return the python code.
"""
def generate_greeting_code(name: str) -> str by models["code-gen"];

glob greeting = generate_greeting_text("Alice");

with entry {
    print(f"Generated greeting: {greeting}");
}

glob greeting_code = generate_greeting_code("Alice");

with entry {
    print(f"Generated greeting code: {greeting_code}");
}
