# AI-Integrated Programming with MTLLM

This guide covers different ways you can use MTLLM to build AI-integrated software in Jaclang. From simple AI-powered functions to complex multi-agent systems, MTLLM provides the tools to seamlessly integrate Large Language Models into your applications. For truly agentic behavior that can reason, plan, and act autonomously, MTLLM offers the ReAct method with tool integration.

## Supported Models

MTLLM use [LiteLLM](https://docs.litellm.ai/docs) under the hood allowing seamless integration with a wide range of models.

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

### Key MTLLM Features

LLM integration is a first class feature in Jaclang, enabling you to build AI-powered applications with minimal effort. Here are some of the key features:

- **Zero Prompt Engineering**: Define function signatures and let MTLLM handle implementation
- **Type Safety**: Maintain strong typing while adding AI capabilities
- **Tool Integration**: Connect AI functions to external APIs and services
- **Function Overriding**: Transform existing functions with LLM behavior at runtime
- **Context Aware Methods**: AI-powered methods that understand object context
- **Structured Outputs**: Generate complex, typed data structures automatically
- **Media Support**: Handle images and videos as inputs and outputs
- **ReAct Method**: Build agentic applications that can reason and use tools

## Intelligent Functions

### Basic Functions

Transform any function into an intelligent agent by adding the `by llm` declaration. Instead of writing manual API calls and prompt engineering, simply define the function signature and let MTLLM handle the implementation:

```jac linenums="1"
import from mtllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

def translate(text: str, target_language: str) -> str by llm();

def analyze_sentiment(text: str) -> str by llm();

def summarize(content: str, max_words: int) -> str by llm();
```

These functions become intelligent agents that can understand natural language inputs and produce contextually appropriate outputs.

### Enhanced Functions with Reasoning

Add the `method='Reason'` parameter to enable step-by-step reasoning for complex tasks:

```jac linenums="1"
import from mtllm.llm { Model }

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

### Structured Output Functions

MTLLM excels at generating structured outputs. Define functions that return complex types:

```jac linenums="1"
obj Person {
    has name: str;
    has age: int;
    has description: str | None;
}

def generate_random_person() -> Person by llm();

with entry {
    person = generate_random_person();
    assert isinstance(person, Person);
    print(f"Generated Person: {person.name}, Age: {person.age}, Description: {person.description}");
}
```

A more complex example of using object schema for adding context to LLM and constrint genaration to structured output genaration is explained in the [game level genaration](../examples/mtp_examples/rpg_game.md) example.


## Instance context aware MTP methods

Transform methods into intelligent components that can reason about their state and context:

### Basic Methods

```jac linenums="1"
import from mtllm.llm { Model }

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

### Complex AI-Integrated Workflows with Objects

Create sophisticated multi-agent systems using object methods:

```jac linenums="1"
import from mtllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

obj Essay {
    has essay: str;

    def get_essay_judgement(criteria: str) -> str by llm();

    def get_reviewer_summary(judgements: dict) -> str by llm();

    "Grade should be 'A' to 'D'"
    def give_grade(summary: str) -> str by llm();
}

with entry {
    essay = "With a population of approximately 45 million Spaniards and 3.5 million immigrants,"
        "Spain is a country of contrasts where the richness of its culture blends it up with"
        "the variety of languages and dialects used. Being one of the largest economies worldwide,"
        "and the second largest country in Europe, Spain is a very appealing destination for tourists"
        "as well as for immigrants from around the globe. Almost all Spaniards are used to speaking at"
        "least two different languages, but protecting and preserving that right has not been"
        "easy for them.Spaniards have had to struggle with war, ignorance, criticism and the governments,"
        "in order to preserve and defend what identifies them, and deal with the consequences.";
    essay = Essay(essay);
    criterias = ["Clarity", "Originality", "Evidence"];
    judgements = {};
    for criteria in criterias {
        judgement = essay.get_essay_judgement(criteria);
        judgements[criteria] = judgement;
    }
    summary = essay.get_reviewer_summary(judgements);
    grade = essay.give_grade(summary);
    print("Reviewer Notes: ", summary);
    print("Grade: ", grade);
}
```

## Adding Explicit Context for Functions, Methods and Objects

When building AI-integrated applications, providing the right amount of context is crucial for optimal performance. MTLLM offers multiple ways to add context to your functions and objects without over-engineering prompts.

### Adding Context with Docstrings

Docstrings serve as crucial context for your intelligent functions. MTLLM uses docstrings to understand the function's purpose and expected behavior. Keep them concise and focused - they should guide the LLM, not replace its reasoning.

```jac linenums="1"
import from mtllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

"""Translate text to the target language."""
def translate(text: str, target_language: str) -> str by llm();

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

### Additional context with `incl_info`

Use `incl_info` to provide additional context to LLM methods for context-aware processing:

```jac linenums="1"
import from mtllm.llm { Model }
import from datetime { datetime }

glob llm = Model(model_name="gpt-4o");

obj Person {
    has name: str;
    has date_of_birth: str;

    # This will use the above date_of_birth attribute and the "today" information
    # in the `incl_info` to calculate the age of the person.
    def calculate_age() -> str by llm(
        incl_info={
            "today": datetime.now().strftime("%d-%m-%Y"),
        }
    );
}
```


### When to Use Each Approach

- **Docstrings**: Use for function-level context and behavior description
- **Semstrings**: Use for attribute-level descriptions and domain-specific terminology
- **incl_info**: Use to selectively include relevant object state in method calls

The `sem` keyword can be used in [separate implementation files](../../jac_book/chapter_5.md#declaring-interfaces-vs-implementations), allowing for cleaner code organization and better maintainability.

## LLM Function/Method Overriding

In addition to defining functions and methods with the `by llm()` syntax, Jaclang also supports **LLM overriding** of existing functions. This powerful feature allows you to take any regular function and override its behavior with LLM-powered implementation at runtime using the `function_call() by llm()` syntax.

You can override any function call by appending `by llm()` to the function call:

```jac linenums="1"
import from mtllm.llm { Model }

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

The ReAct (Reasoning and Acting) method enables true agentic behavior by
allowing agents to reason about problems and use external tools to solve
them. This is where functions become genuinely agentic - they
can autonomously decide what tools they need and how to use them.

Any function can be made agentic by adding the `by llm(tools=[...])`
declaration. This allows the function to use external tools to solve
problems, making it capable of reasoning and acting like an agent.

```jac linenums="1"
import from mtllm.llm { Model }
import from datetime { datetime }

glob llm = Model(model_name="gpt-4o");

obj Person {
    has name: str;
    has dob: str;
}

"""Calculate the age of the person where current date can be retrieved by the get_date tool."""
def calculate_age(person: Person) -> int by llm(tools=[get_date]);

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


## Streaming Outputs

The streaming feature allows you to receive tokens from LLM functions in real-time, enabling dynamic interactions and responsive applications. This is particularly useful for generating content like essays, code, or any long-form text where you want to display results as they are produced.

In the invoke parameters, you can set `stream=True` to enable streaming:

```jac linenums="1"
import from mtllm { Model }

glob llm = Model(model_name="gpt-4o-mini");

""" Generate short essay (less than 300 words) about the given topic """
def generate_essay(topic: str) -> str by llm(stream=True);


with entry {
    topic = "The orca whale and it's hunting techniques";
    for tok in generate_essay(topic) {
        print(tok, end='', flush=True);
    }
    print(end='\n');
}
```

??? example "NOTE:
    "The `stream=True` will only support the output of type `str` and at the moment tool calling is not supported in streaming mode. That will be supported in the future."