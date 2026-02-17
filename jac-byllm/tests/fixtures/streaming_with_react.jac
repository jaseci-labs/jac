"""Test streaming with ReAct method using MockLLM."""
import from byllm.lib { Model, MockToolCall }
import from datetime { datetime }

# Mock function that will be used as a tool
def get_current_date -> str {
    return "29-10-2025";
}

def calculate(expression: str) -> str {
    return f"Result: {eval(expression)}";
}

# Create a mock finish_tool that matches the dynamically generated one
def finish_tool(
    final_output: str
) -> str {
    return final_output;
}

# Create a mock LLM that simulates tool calling then final output
glob llm = Model(
         model_name="mockllm",
         config={
             "outputs": [
                 # First, LLM decides to call get_current_date
                 MockToolCall(tool=get_current_date, args={}),
                 # Then, LLM decides to call calculate
                 MockToolCall(tool=calculate, args={"expression": "25 * 4"}),
                 # Then, LLM calls finish_tool with the answer (simulating real LLM behavior)
                 MockToolCall(
                     tool=finish_tool,
                     args={
                         "final_output": "Based on my calculations, today's date is 29-10-2025 and 25 multiplied by 4 equals 100."
                     }
                 ),
                 # Finally, the streaming response after all tool calls
                 "Based on my calculations, today's date is 29-10-2025 and 25 multiplied by 4 equals 100. This demonstrates the ReAct pattern with streaming support.",

             ]
         },
     );

"""Answer the question using available tools."""
def answer_question(question: str) -> str by llm(
    tools=[get_current_date, calculate], stream=True
);

with entry {
    print("Testing ReAct with streaming...\n");
}

glob question = "What is today's date and what is 25 * 4?";

with entry {
    print(f"Question: {question}\n");
    print("Answer (streaming): ");
}

glob result = answer_question(question);

# Result should be a generator (for streaming)
with entry {
    assert result is not str , "Expected generator for streaming, got string";
}

# Collect all chunks
glob full_response = "";

with entry {
    for chunk in result {
        print(chunk, end='', flush=True);
        full_response += chunk;
    }

    print("\n");

    # Verify the response contains expected content
    assert "29-10-2025" in full_response , "Response should mention the date";
    assert "100" in full_response , "Response should mention the calculation result";

    print("\nTest passed! ✓");
}
