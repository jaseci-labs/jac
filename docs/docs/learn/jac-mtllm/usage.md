# AI-Integrated Programming with MTLLM

This guide covers all the ways you can use MTLLM to build AI-integrated software in Jaclang. From simple AI-powered functions to complex multi-agent systems, MTLLM provides the tools to seamlessly integrate Large Language Models into your applications. For truly agentic behavior that can reason, plan, and act autonomously, MTLLM offers the ReAct method with tool integration.

## Available Models

MTLLM use [LiteLLM](https://docs.litellm.ai/docs) under the hood allowing seamless integration of a wide range of models.

=== "OpenAI"
    ```jac linenums="1"
    import from mtllm {Model}

    glob llm = Model(model_name = "gpt-4o")
    ```
=== "Gemini"
    ```jac linenums="1"
    import from mtllm {Model}

    glob llm = Model(model_name = "gemini/gemini-2.0-flash")
    ```
=== "Anthropic"
    ```jac linenums="1"
    import from mtllm {Model}

    glob llm = Model(model_name = "claude-3-5-sonnet-20240620")
    ```
=== "Ollama"
    ```jac linenums="1"
    import from mtllm {Model}

    glob llm = Model(model_name = "ollama/llama3:70b")
    ```
=== "HuggingFace Models"
    ```jac linenums="1"
    import from mtllm {Model}

    glob llm = Model(model_name = "huggingface/meta-llama/Llama-3.3-70B-Instruct")
    ```

??? Note
    There are Many other supported models and model serving platforms available with LiteLLM, please check their [documentation](https://docs.litellm.ai/docs/providers) for model names.

## Intelligent Functions

### Basic Functions

Transform any function into an intelligent agent by adding the `by llm` declaration. Instead of writing manual API calls and prompt engineering, simply define the function signature and let MTLLM handle the implementation:

```jac linenums="1"
import from mtllm {Model}

glob llm = Model(model_name="gpt-4o");

def translate(text: str, target_language: str) -> str by llm();
def analyze_sentiment(text: str) -> str by llm();
def summarize(content: str, max_words: int) -> str by llm();
```

These functions become intelligent functions that can understand inputs and produce contextually appropriate outputs with zero prompt engineering.

### Enhanced Functions with Reasoning

Add the `method='Reason'` parameter to enable step-by-step reasoning for complex tasks:

```jac linenums="1"
import from mtllm {Model}

glob llm = Model(model_name="gpt-4o");

def analyze_sentiment(text: str) -> str by llm(method='Reason');
def generate_response(original_text: str, sentiment: str) -> str by llm();

with entry {
    customer_feedback = "I'm really disappointed with the product quality. The delivery was late and the item doesn't match the description at all.";

    # Agent reasons through the sentiment analysis step by step
    sentiment = analyze_sentiment(customer_feedback);

    # Agent crafts appropriate response based on sentiment
    response = generate_response(customer_feedback, sentiment);

    print(f"Customer sentiment: {sentiment}");
    print(f"Suggested response: {response}");
}
```

### Functions using custom types

MTLLM excels at understandiong typed input and generating typed outputs. Define functions that return complex types:

```jac linenums="1"
import from mtllm {Model}

glob llm = Model(model_name="gpt-4o-mini");

enum Personality {
    INTROVERT = "Introvert",
    EXTROVERT = "Extrovert"
    AMBIVERT = "Ambivert"
}

obj Person {
    has full_name: str,
        yod: int,
        personality: Personality;
}
sem Person.yod = "Year of Death of the person";

def get_person_info(name: str) -> Person by llm(
    method="Reason",
    temperature=0.0
);

with entry {
    person_obj = get_person_info('Martin Luther King Jr.');
    print(
        f"{person_obj.full_name} was a {person_obj.personality.value} person who died in {person_obj.yod}"
    );
}
```

A more complex example of using object schema for adding context to LLM and constrint genaration to structured output genaration is explained in the [game level genaration](../examples/mtp_examples/rpg_game.md) example.


## AI-Integrated Object Methods

Transform object methods into intelligent components that can reason about their state and context:

### Object Methods

The "by llm" methods of the Person object inherently have access to all object attributes to pass in more context.

```jac linenums="1"
import from mtllm {Model}

glob llm = Model(model_name="gpt-4o");

obj Person {
    has name: str;
    has age: int;

    def introduce() -> str by llm();
    def suggest_hobby() -> str by llm();
}

with entry {
    alice = Person("Alice", 25);
    print(alice.introduce());
    print(alice.suggest_hobby());
}
```

## Adding Explicit Context for Functions, Methods and Objects

When building AI-integrated applications, providing the right amount of context is crucial for optimal performance. MTLLM offers multiple ways to add context to your functions and objects without over-engineering prompts.

### Adding Context with Docstrings

Docstrings serve as crucial context for your intelligent functions. MTLLM uses docstrings to understand the function's purpose and expected behavior. Keep them concise and focused - they should guide the LLM, not replace its reasoning.

```jac linenums="1"
import from mtllm {Model}

glob llm = Model(model_name="gpt-4o");

"""Translate text to the target language."""
def translate(text: str, target_language: str) -> str by llm();

"""Analyze sentiment returning (sentiment, confidence, themes)."""
def analyze_sentiment(review: str) -> tuple[str, float, list[str]] by llm();

"""Generate a professional email response based on the input message tone."""
def generate_email_response(message: str, recipient_type: str) -> str by llm();
```

**Key principles for effective docstrings:**

- Be specific about the function's purpose
- Mention return format for complex outputs
- Avoid detailed instructions - let the LLM reason
- Keep them under one sentence when possible

### Adding Context with Semantic Strings (Semstrings)

For more complex scenarios where you need to describe object attributes or function parameters without cluttering your code, Jaclang provides semantic strings using the `sem` keyword. This is particularly useful for:

- Describing object attributes with domain-specific meaning
- Adding context to parameters without verbose docstrings
- Maintaining clean code while providing rich semantic information

```jac linenums="1"
obj Person {
    has name;
    has dob;
    has ssn;
}

sem Person = "Represents the personal record of a person";
sem Person.name = "Full name of the person";
sem Person.dob = "Date of Birth";
sem Person.ssn = "Last four digits of the Social Security Number of a person";

"""Calculate eligibility for various services based on person's data."""
def check_eligibility(person: Person, service_type: str) -> bool by llm();
```

### Object Context in Methods

When using object methods with MTLLM, you can include specific object attributes as context using the `incl_info` parameter:

```jac linenums="1"
glob current_promotions = ["summer_sale", "loyalty_bonus", "new_member_discount"];

obj Customer {
    has name: str;
    has purchase_history: list[str];
    has satisfaction_score: float;
    has membership_tier: str;
}

sem Customer = "Customer profile with purchase and satisfaction data";
sem Customer.satisfaction_score = "Rating from 0.0 to 1.0 based on feedback";
sem Customer.membership_tier = "bronze, silver, gold, or platinum";

obj Customer {
    """Generate personalized product recommendations."""
    def get_recommendations(category: str) -> list[str] by llm();

    """Create a tailored marketing message using current promotions."""
    def create_marketing_message(promotion_type: str) -> str by llm(incl_info=(current_promotions));
}
```

### When to Use Each Approach

- **Docstrings**: Use for function-level context and behavior description
- **Semstrings**: Use for attribute-level descriptions and domain-specific terminology
- **incl_info**: Use to selectively include relevant objects/variables in method calls

The `sem` keyword can be used in [separate implementation files](../../jac_book/chapter_5.md#declaring-interfaces-vs-implementations), allowing for cleaner code organization and better maintainability.

## LLM Function/Method Overriding

In addition to defining functions and methods with the `by llm()` syntax, Jaclang also supports **LLM overriding** of existing functions. This powerful feature allows you to take any regular function and override its behavior with LLM-powered implementation at runtime using the `function_call() by llm()` syntax.

You can override any function call by appending `by llm()` to the function call:

```jac linenums="1"
import from mtllm {Model}

glob llm = Model(model_name="gpt-4o");

"""Greet the user with the given name."""
def greet(name: str) -> str {
    return "Hello " + name;
}

def format_data(data: dict) -> str {
    return str(data);
}

with entry {
    # Normal function call
    print("Normal:", greet("Alice"));

    # LLM override call - makes greeting more natural and contextual
    print("LLM Override:", greet("Alice") by llm());

    # Override data formatting with intelligent presentation
    user_data = {"name": "Bob", "role": "engineer", "experience": 5};
    print("Normal format:", format_data(user_data));
    print("Smart format:", format_data(user_data) by llm());
}
```

In this example:

- `greet("Alice")` executes the normal function and returns `"Hello Alice"`
- `greet("Alice") by llm()` overrides the function with LLM behavior, potentially returning a more natural or contextual greeting
- `format_data(user_data) by llm()` transforms simple data formatting into intelligent, human-readable presentation


## Tool-Using Agents with ReAct

The ReAct (Reasoning and Acting) method enables true agentic behavior by allowing agents to reason about problems and use external tools to solve them. This is where functions become genuinely agentic - they can autonomously decide what tools they need and how to use them.

```jac linenums="1"
import from mtllm {Model}
import from datetime {datetime}

glob llm = Model(model_name="gpt-4o");

obj Person {
    has name: str;
    has dob: str;
}

"""Calculate the age of the person where current date can be retrieved by the get_date tool."""
def calculate_age(person: Person) -> int by llm(method="ReAct", tools=[get_date]);

"""Get the current date in DD-MM-YYYY format."""
def get_date() -> str {
    return datetime.now().strftime("%d-%m-%Y");
}

with entry {
    mars = Person("Mars", "27-05-1983");
    print("Age of Mars =", calculate_age(mars));
}
```

### What Makes ReAct Truly Agentic?

The ReAct method demonstrates genuine agentic behavior because:

1. **Autonomous Reasoning**: The agent analyzes the problem independently
2. **Tool Selection**: It decides which tools are needed and when to use them
3. **Adaptive Planning**: Based on tool results, it adjusts its approach
4. **Goal-Oriented**: It works towards solving the complete problem, not just individual steps

A full tutorial on [building an agentic application is available here.](../examples/mtp_examples/fantasy_trading_game.md)