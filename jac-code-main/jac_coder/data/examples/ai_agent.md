# Example: AI Agent with LLM Routing

Uses `by llm()` for intelligent routing, `sem` annotations for prompts, walker graph traversal.

## Backend: agent.jac — Declarations

```jac
"""AI agent with LLM-driven routing between handler nodes."""

import from byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4.1-mini");

node Router {}

node QAHandler {
    def respond(message: str, context: list[dict]) -> str by llm(
        method="Reason",
        messages=context,
        temperature=0.3
    );
    can handle with process_request entry;
}

node CodeHandler {
    def respond(message: str, context: list[dict]) -> str by llm(
        messages=context,
        tools=[search_docs]
    );
    can handle with process_request entry;
}

walker :pub process_request {
    has message: str = "";
    has context: list[dict] = [];

    can route with Router entry {
        visit [-->] by llm(
            incl_info={"message": self.message, "context": self.context[-5:]}
        );
    }

    can init_graph with Root entry {
        visit [-->][?:Router] else {
            router = (here ++> Router())[0];
            router ++> QAHandler();
            router ++> CodeHandler();
            visit router;
        };
    }
}
```

## Implementation: impl/agent.impl.jac

```jac
sem Router.classify = """Return exactly one label: QA, CODE, or DONE.
QA = general questions, CODE = programming tasks, DONE = task complete.""";

sem QAHandler.respond = """You are a helpful assistant. Answer clearly and concisely.""";

sem CodeHandler.respond = """You are an expert programmer.
Use search_docs to find documentation before answering.""";

impl QAHandler.handle with process_request entry {
    response = here.respond(message=self.message, context=self.context);
    report {"response": response, "handler": "qa"};
    visit [<--][?:Router];
}

impl CodeHandler.handle with process_request entry {
    response = here.respond(message=self.message, context=self.context);
    report {"response": response, "handler": "code"};
    visit [<--][?:Router];
}

impl process_request.route with Router entry {
    label = here.classify(message=self.message, context=self.context);
    if "DONE" in label { disengage; }
}
```

## Key Patterns Demonstrated

- **Lazy graph creation**: `visit [-->][?:Router] else { ... }` creates graph on first use
- **LLM-driven routing**: `visit [-->] by llm(...)` lets LLM choose which handler
- **Interface/impl split**: Declarations in `.jac`, semantics + logic in `.impl.jac`
- **Multi-node traversal**: Walker visits Router → Handler → back to Router
- **`sem` annotations**: System prompts for each LLM-powered method
- **`disengage`**: Stops walker when task is complete
