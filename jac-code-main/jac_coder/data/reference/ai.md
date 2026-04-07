# AI Integration — by llm()

## Required Setup — byllm Import

**You MUST import byllm and create a glob model before using any `by llm()` call.**

```jac
import from byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4o");
```

Without this, `by llm()` will fail. The glob variable name (e.g. `llm`, `model`) is what you reference in `by llm()` or `by model()`.

## Simple LLM Functions

The `by llm()` suffix turns a function into an LLM call. The LLM infers behavior from the function name, parameter names, types, and return type.

```jac
import from byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4o");

# Simple classification — LLM figures it out from name + types
def classify_sentiment(text: str) -> str by llm();

# With explicit reasoning
def classify(message: str) -> str by llm(method="Reason", temperature=0.1);

# Enum return type for constrained output
enum Sentiment { POSITIVE, NEGATIVE, NEUTRAL }
def analyze(text: str) -> Sentiment by llm();
```

## Semantic Annotations

`sem` annotations provide system prompts for `by llm()` functions.

```jac
# On methods
sem MyAgent.respond = """You are an expert coding agent.
Use tools to read, write, and test code.""";

# On fields (describes what the field means to the LLM)
sem ReviewResult.is_approved = "True if content meets quality standards";
```

## ReAct Agent with Tools

Passing `tools=` auto-triggers ReAct (reason-act) loop.

```jac
def respond(message: str, chat_history: list[dict]) -> str by llm(
    messages=chat_history,
    tools=[read_file, search, bash_exec],
    incl_info={"reference": knowledge_base},
    max_react_iterations=10,
    temperature=0.2,
    stream=True
);
```

## LLM-Driven Graph Traversal

The LLM can decide which node to visit next:

```jac
# LLM picks child node based on context
can route with Router entry {
    visit [-->] by llm(
        incl_info={"message": self.message, "context": self.context}
    );
}
```

## Model Configuration

```jac
import from byllm.lib { Model }

glob model: Model = Model(model_name="openai/gpt-4o-mini");

# Use specific model for a function
def summarize(text: str) -> str by model(
    reason="Summarize in 2-3 sentences"
);
```

## Interface/Implementation with LLM

Declaration file:

```jac
node Router {
    def classify(message: str) -> str by llm(method="Reason");
}
```

Implementation file:

```jac
sem Router.classify = """Return exactly one label: BUILD, PLAN, or EXPLORE.""";
```

## Full Agent Example

```jac
node Router {}
node QAHandler {
    def respond(message: str, context: list[dict]) -> str by llm(
        method="Reason", messages=context, temperature=0.3
    );
    can handle with process_request entry;
}

walker :pub process_request {
    has message: str;
    has context: list[dict] = [];

    can route with Router entry {
        visit [-->] by llm(
            incl_info={"message": self.message}
        );
    }
    can init_graph with Root entry {
        visit [-->][?:Router] else {
            router = (here ++> Router())[0];
            router ++> QAHandler();
            visit router;
        };
    }
}
```
