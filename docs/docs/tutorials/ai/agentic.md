# Agentic AI

Build AI agents that can use tools and reason through problems.

> **Prerequisites**
>
> - Completed: [Structured Outputs](structured-outputs.md)
> - Time: ~45 minutes

---

## What is Agentic AI?

Regular LLMs can only generate text. **Agentic AI** can:

- Use **tools** (functions you define)
- **Reason** about which tools to use
- **Iterate** until the task is complete

```
User: "What's the weather in Tokyo?"

Regular LLM:     Agentic LLM:
"I don't have    1. I need weather data
 real-time       2. Call get_weather("Tokyo")
 data..."        3. Return: "It's 22°C and sunny"
```

---

## Basic Tool Calling

Define functions the LLM can use:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

# Define a tool
def get_current_time() -> str {
    import datetime;
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");
}

# LLM function that can use the tool
"""Answer questions, using available tools when needed."""
def answer(question: str) -> str by llm(
    tools=[get_current_time]
);

with entry {
    response = answer("What time is it right now?");
    print(response);
}
```

**Output:**

```
The current time is 2024-01-21 14:30:45.
```

The LLM automatically:

1. Recognized it needed the current time
2. Called `get_current_time()`
3. Used the result to form its answer

---

## Multiple Tools

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

"""Add two numbers together."""
def add(a: int, b: int) -> int {
    return a + b;
}

"""Multiply two numbers."""
def multiply(a: int, b: int) -> int {
    return a * b;
}

"""Get the value of pi."""
def get_pi() -> float {
    return 3.14159;
}

"""Solve math problems using the available tools."""
def solve_math(problem: str) -> str by llm(
    tools=[add, multiply, get_pi]
);

with entry {
    print(solve_math("What is 5 + 3?"));
    print(solve_math("Calculate 7 times 8"));
    print(solve_math("What is pi times 2?"));
}
```

---

## Tool Parameters

Tools can have parameters that the LLM fills in:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

"""Search the database for matching records."""
def search_database(query: str, limit: int = 10) -> list[str] {
    # Simulated database search
    return [f"Result {i} for '{query}'" for i in range(min(limit, 3))];
}

"""Get information about a specific user."""
def get_user_info(user_id: str) -> dict {
    # Simulated user lookup
    return {
        "id": user_id,
        "name": f"User {user_id}",
        "email": f"user{user_id}@example.com"
    };
}

"""Answer questions about users and data."""
def query(question: str) -> str by llm(
    tools=[search_database, get_user_info]
);

with entry {
    print(query("Find records about 'machine learning'"));
    print(query("What's the email for user 42?"));
}
```

---

## ReAct Pattern

**ReAct** (Reason + Act) lets the LLM think step-by-step:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

"""Search the web for information."""
def search_web(query: str) -> str {
    # Simulated web search
    return f"Web results for '{query}': Found relevant information about the topic.";
}

"""Evaluate a mathematical expression."""
def calculate(expression: str) -> float {
    return eval(expression);
}

"""Get today's date."""
def get_date() -> str {
    import datetime;
    return datetime.date.today().isoformat();
}

"""Answer complex questions using reasoning and tools."""
def research(question: str) -> str by llm(
    method="ReAct",
    tools=[search_web, calculate, get_date]
);

with entry {
    answer = research(
        "If today's date has an odd day number, calculate 2^10, "
        "otherwise calculate 3^5"
    );
    print(answer);
}
```

With ReAct, the LLM:

1. **Thought:** I need to check today's date first
2. **Action:** Call `get_date()`
3. **Observation:** 2024-01-21 (day 21 is odd)
4. **Thought:** Since it's odd, I need to calculate 2^10
5. **Action:** Call `calculate("2**10")`
6. **Observation:** 1024
7. **Answer:** The result is 1024

---

## Method-Based Tools

Tools can be methods on objects:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj Calculator {
    has memory: float = 0;

    """Add to memory."""
    def add(x: float) -> float {
        self.memory += x;
        return self.memory;
    }

    """Subtract from memory."""
    def subtract(x: float) -> float {
        self.memory -= x;
        return self.memory;
    }

    """Clear memory."""
    def clear() -> float {
        self.memory = 0;
        return self.memory;
    }

    """Get current memory value."""
    def get_memory() -> float {
        return self.memory;
    }

    """Perform calculations step by step."""
    def calculate(instructions: str) -> str by llm(
        tools=[self.add, self.subtract, self.clear, self.get_memory]
    );
}

with entry {
    calc = Calculator();
    result = calc.calculate("Start at 0, add 10, subtract 3, then add 5");
    print(result);
    print(f"Final memory: {calc.memory}");
}
```

---

## Agentic Walker

Combine tools with graph traversal:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

node Document {
    has title: str;
    has content: str;
    has summary: str = "";
}

"""Summarize this document in 2-3 sentences."""
def summarize(content: str) -> str by llm();

"""Search documents for matching content."""
def search_documents(query: str, docs: list) -> list {
    results = [];
    for doc in docs {
        if query.lower() in doc.content.lower() {
            results.append(doc.title);
        }
    }
    return results;
}

walker DocumentAgent {
    has query: str;

    can process with `root entry {
        all_docs = [-->](`?Document);

        # Find relevant documents
        relevant = search_documents(self.query, all_docs);

        # Summarize each relevant document
        for doc in all_docs {
            if doc.title in relevant {
                doc.summary = summarize(doc.content);
                report {"title": doc.title, "summary": doc.summary};
            }
        }
    }
}

with entry {
    root ++> Document(
        title="AI Overview",
        content="Artificial intelligence is transforming industries..."
    );
    root ++> Document(
        title="Weather Report",
        content="Sunny skies expected throughout the week..."
    );
    root ++> Document(
        title="Machine Learning Guide",
        content="Machine learning is a subset of AI that..."
    );

    result = root spawn DocumentAgent(query="AI");

    for doc in result.reports {
        print("## " + doc["title"]);
        print(doc["summary"]);
        print();
    }
}
```

---

## Context Injection

Provide additional context to the LLM:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

glob company_info = """
Company: TechCorp
Products: CloudDB, SecureAuth, DataViz
Support Hours: 9 AM - 5 PM EST
Support Email: support@techcorp.com
""";

"""Answer customer questions about our products and services."""
def support_agent(question: str) -> str by llm(
    incl_info={"company_context": company_info}
);

with entry {
    print(support_agent("What products do you offer?"));
    print(support_agent("What are your support hours?"));
}
```

---

## Building a Full Agent

```jac
import from byllm.lib { Model }
import json;

glob llm = Model(model_name="gpt-4o");

# Knowledge base
glob kb: dict = {
    "products": ["Widget A", "Widget B", "Service X"],
    "prices": {"Widget A": 99, "Widget B": 149, "Service X": 29},
    "inventory": {"Widget A": 50, "Widget B": 0, "Service X": 999}
};

"""List all available products."""
def list_products() -> list[str] {
    return kb["products"];
}

"""Get the price of a product."""
def get_price(product: str) -> str {
    if product in kb["prices"] {
        return f"${kb['prices'][product]}";
    }
    return "Product not found";
}

"""Check if a product is in stock."""
def check_inventory(product: str) -> str {
    if product in kb["inventory"] {
        qty = kb["inventory"][product];
        if qty > 0 {
            return f"In stock ({qty} available)";
        }
        return "Out of stock";
    }
    return "Product not found";
}

"""Place an order for a product."""
def place_order(product: str, quantity: int) -> str {
    if product not in kb["inventory"] {
        return "Product not found";
    }
    if kb["inventory"][product] < quantity {
        return "Insufficient inventory";
    }
    kb["inventory"][product] -= quantity;
    return f"Order placed: {quantity}x {product}";
}

"""You are a helpful sales assistant. Help customers browse products,
check prices and availability, and place orders."""
def sales_agent(request: str) -> str by llm(
    method="ReAct",
    tools=[list_products, get_price, check_inventory, place_order]
);

with entry {
    print("Customer: What products do you have?");
    print(f"Agent: {sales_agent('What products do you have?')}");
    print();

    print("Customer: How much is Widget A and is it in stock?");
    print(f"Agent: {sales_agent('How much is Widget A and is it in stock?')}");
    print();

    print("Customer: I'd like to order 2 Widget A please");
    print(f"Agent: {sales_agent('I want to order 2 Widget A')}");
}
```

---

## Key Takeaways

| Concept | Usage |
|---------|-------|
| Basic tools | `by llm(tools=[func1, func2])` |
| ReAct reasoning | `by llm(method="ReAct", tools=[...])` |
| Object methods | `by llm(tools=[self.method])` |
| Context injection | `by llm(incl_info={"key": value})` |
| Tool docstrings | Help LLM understand when to use tools |

---

## Best Practices

1. **Clear docstrings** - The LLM uses docstrings to understand tools
2. **Descriptive parameters** - Name parameters clearly
3. **Return useful info** - Return strings the LLM can interpret
4. **Limit tool count** - Too many tools can confuse the LLM
5. **Use ReAct for complex tasks** - Multi-step reasoning

---

## Next Steps

- [byLLM Reference](../../reference/plugins/byllm.md) - Complete tool documentation
- [Examples: EmailBuddy](../examples/emailbuddy.md) - Agentic email assistant
- [Full-Stack Tutorial](../fullstack/setup.md) - Add UI to your agent
