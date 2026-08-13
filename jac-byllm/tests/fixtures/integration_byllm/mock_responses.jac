"""Pre-configured MockLLM outputs for each integration test scenario.

Each load function populates the MockLLM output queues with the exact
sequence of responses needed for one test scenario. The outputs were
derived from real OpenAI API responses and translated into MockLLM format.
"""

import from byllm.lib { MockToolCall }
import from tools { calculate, run_and_test_python_code }


def load_concept_agent_outputs(llms: dict) {
    # Routing decision: visit ConceptAgent (index 0)
    llms["llm2"].config["outputs"].extend([
        [0],
    ]);
    # ConceptAgent.explain response
    llms["llm1"].config["outputs"].extend([
        "Machine learning is a field of artificial intelligence that enables computers to learn from data and improve their performance on tasks without being explicitly programmed. In simple terms, it involves teaching a computer to recognize patterns and make decisions based on examples rather than following specific instructions. For instance, if you show a machine learning model many pictures of cats and dogs, it can learn to tell the difference between them by identifying features like fur texture or ear shape.",
    ]);
}


def load_math_agent_outputs(llms: dict) {
    # Routing decision: visit MathAgent (index 1)
    llms["llm2"].config["outputs"].extend([
        [1],
    ]);
    # MathAgent.solve uses ReAct with stream=True, logging=True and tools=[calculate]
    # Step 1: LLM decides to call the calculate tool
    # Step 2: LLM calls finish_tool with the result
    # Step 3: Final streamed answer after finish_tool
    llms["llm2"].config["outputs"].extend([
        MockToolCall(tool=calculate, args={"expr": "(15 + 5) * 2 - (10 / 2)"}),
        "35.0",
    ]);
}


def load_research_agent_outputs(llms: dict, ResearchSummary: type) {
    # Routing decision: visit ResearchAgent (index 2)
    llms["llm2"].config["outputs"].extend([
        [2],
    ]);
    # ResearchAgent.analyze returns a ResearchSummary object
    llms["llm2"].config["outputs"].extend([
        ResearchSummary(
            summary="Supervised fine-tuning and prompt engineering are two distinct methods used to improve the performance of large language models (LLMs). Supervised fine-tuning involves training the model on a labeled dataset to enhance its capabilities in specific tasks, while prompt engineering focuses on designing effective input prompts that guide the model to produce desired outputs without modifying its internal parameters.",
            key_points=[
                "Supervised fine-tuning requires labeled datasets and retrains the model on specific tasks.",
                "Prompt engineering does not alter the model but optimizes how inputs are presented to achieve better outputs.",
                "Fine-tuning generally yields higher performance for task-specific applications compared to prompt engineering.",
                "Prompt engineering can be more flexible and quicker to implement for various tasks without extensive retraining."
            ],
            confidence="High"
        ),
    ]);
}


def load_code_agent_outputs(llms: dict) {
    # Routing decision: visit CodeAgent (index 3)
    llms["llm2"].config["outputs"].extend([
        [3],
    ]);
    # CodeAgent.generate_code uses ReAct with tools=[run_and_test_python_code]
    # Step 1: LLM generates code and calls the tool to verify it
    # Step 2: LLM returns the verified code as final answer
    llms["llm3"].config["outputs"].extend([
        MockToolCall(tool=run_and_test_python_code, args={"code": "def fibonacci(n):\n    if n <= 0:\n        return []\n    elif n == 1:\n        return [0]\n    elif n == 2:\n        return [0, 1]\n    else:\n        fib_seq = [0, 1]\n        for i in range(2, n):\n            fib_seq.append(fib_seq[-1] + fib_seq[-2])\n        return fib_seq\n"}),
        "The Python function to compute the Fibonacci sequence is as follows:\n\n```python\ndef fibonacci(n):\n    if n <= 0:\n        return []\n    elif n == 1:\n        return [0]\n    elif n == 2:\n        return [0, 1]\n    else:\n        fib_seq = [0, 1]\n        for i in range(2, n):\n            fib_seq.append(fib_seq[-1] + fib_seq[-2])\n        return fib_seq\n```\n\nThis function takes an integer `n` as input and returns a list containing the first `n` numbers of the Fibonacci sequence.",
    ]);
}
