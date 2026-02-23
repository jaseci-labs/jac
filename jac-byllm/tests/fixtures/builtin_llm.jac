"""Test builtin llm: by llm() works without explicit import or glob."""
import from byllm.lib { MockLLM }

# Override the builtin llm with a mock for testability.
# The key test is that 'llm' in 'by llm()' compiles as a builtin name.
glob llm = MockLLM(model_name="mockllm", config={"outputs": ["positive"]});

enum Sentiment { POSITIVE, NEGATIVE, NEUTRAL }

def classify(text: str) -> Sentiment by llm();

with entry {
    result = classify("I love this!");
    print(result);
}
