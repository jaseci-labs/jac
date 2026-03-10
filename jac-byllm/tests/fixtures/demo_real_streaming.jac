"""REAL streaming demo with ReAct method using actual LLM.

This demonstrates ACTUAL streaming from the LLM, not mocked.
You need to set your API key as an environment variable:
  export OPENAI_API_KEY="your-key-here"

Or use any other supported model.
"""
import from byllm.lib { Model }
import from datetime { datetime }
import from os { environ }

# Real LLM - change this to your preferred model
glob llm = Model(
         model_name="gpt-4o-mini", config={"verbose": True},
     );

"""Get the current date and time."""
def get_current_datetime -> str {
    return datetime.now().strftime("%d-%m-%Y %H:%M:%S");
}

"""Calculate a mathematical expression."""
def calculate(expression: str) -> str {
    try {
        result = eval(expression);
        return f"The result is {result}";
    } except Exception as e {
        return f"Error: {str(e)}";
    }
}

"""Answer the question using available tools. Be detailed in your response."""
def answer_question(question: str) -> str by llm(
    tools=[get_current_datetime, calculate],
    stream=True,
    temperature=0.7
);

with entry {
    print("=" * 70);
    print("REAL STREAMING DEMO - ReAct with Actual LLM");
    print("=" * 70);
    print("\nThis will make real API calls and stream the response token-by-token!");
    print("\nWatch closely - you should see the text appear gradually...\n");
}

glob question = "What is the current date and time, and what is 127 multiplied by 89?";

with entry {
    print(f"Question: {question}\n");
    print("Answer (streaming in real-time): ");
    print("-" * 70);

    # This will ACTUALLY stream from the LLM!
    # You'll see:
    # 1. Tool calls execute (not streamed)
    # 2. Final answer streams token-by-token (REAL streaming!)
    for chunk in answer_question(question) {
        print(chunk, end='', flush=True);
    }

    print("\n" + "-" * 70);
    print("\n✓ Streaming complete!");
    print("\nWhat happened:");
    print("1. LLM made tool calls (get_current_datetime, calculate)");
    print("2. After gathering results, LLM streamed final answer");
    print("3. You saw tokens appear in real-time!");
}
