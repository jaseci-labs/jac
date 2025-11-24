# AI-Integrated Programming with byLLM

This guide covers different ways to use byLLM for AI-integrated software development in Jaclang. byLLM provides language-level abstractions for integrating Large Language Models into applications, from basic AI-powered functions to complex multi-agent systems. For agentic behavior capabilities, byLLM includes the ReAct method with tool integration.

## Supported Models

byLLM uses [LiteLLM](https://docs.litellm.ai/docs) to provide integration with a wide range of models.

=== "OpenAI"
    ```jac linenums="1"
    import from byllm.lib {Model}

    glob llm = Model(model_name = "gpt-4o")
    ```
=== "Gemini"
    ```jac linenums="1"
    import from byllm.lib {Model}

    glob llm = Model(model_name = "gemini/gemini-2.0-flash")
    ```
=== "Anthropic"
    ```jac linenums="1"
    import from byllm.lib {Model}

    glob llm = Model(model_name = "claude-3-5-sonnet-20240620")
    ```
=== "Ollama"
    ```jac linenums="1"
    import from byllm.lib {Model}

    glob llm = Model(model_name = "ollama/llama3:70b")
    ```
=== "HuggingFace Models"
    ```jac linenums="1"
    import from byllm.lib {Model}

    glob llm = Model(model_name = "huggingface/meta-llama/Llama-3.3-70B-Instruct")
    ```

??? Note
    Additional supported models and model serving platforms are available with LiteLLM. Refer to their [documentation](https://docs.litellm.ai/docs/providers) for model names.

### Allowed Arguments for the Model Object.

| Argument   | Description |
|------------|-------------|
| `model_name` | (Required) The model name to use (e.g., "gpt-4o", "claude-3-5-sonnet-20240620") |
| `api_key` | (Optional) API key for the model provider |
| `base_url` | (Optional) Base URL for the API endpoint (same as `host`, `api_base`)|
| `proxy_url` | (Optional) Proxy URL, automatically sets `base_url` |
| `verbose` | (Optional) Boolean to enable verbose logging for debugging |
| `method` | (Optional) Specifies the LLM method ('Reason' enables step-by-step reasoning, default is standard generation) |
| `tools` | (Optional) List of tool functions to enable agentic behavior with ReAct tool-calling |
| `hyperparams` | (Optional) Additional model-specific parameters supported by LiteLLM (e.g., `temperature`, `max_tokens`, `top_p`, etc.) |

## byLLM for Functions

### Basic Functions

Functions can be integrated with LLM capabilities by adding the `by llm` declaration. This eliminates the need for manual API calls and prompt engineering:

```jac linenums="1"
import from byllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

def translate(text: str, target_language: str) -> str by llm();

def analyze_sentiment(text: str) -> str by llm();

def summarize(content: str, max_words: int) -> str by llm();
```

These functions process natural language inputs and generate contextually appropriate outputs.

### Functions with Reasoning

The `method='Reason'` parameter enables step-by-step reasoning for complex tasks:

```jac linenums="1"
import from byllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

def analyze_sentiment(text: str) -> str by llm(method='Reason');

def generate_response(original_text: str, sentiment: str) -> str by llm();

with entry {
    customer_feedback = "I'm really disappointed with the product quality. The delivery was late and the item doesn't match the description at all.";

    # Function performs step-by-step sentiment analysis
    sentiment = analyze_sentiment(customer_feedback);

    # Function generates response based on sentiment
    response = generate_response(customer_feedback, sentiment);

    print(f"Customer sentiment: {sentiment}");
    print(f"Suggested response: {response}");
}
```

### Structured Output Functions

byLLM supports generation of structured outputs. Functions can return complex types:

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

A more complex example using object schema for context and structured output generation is demonstrated in the [game level generation](../examples/mtp_examples/rpg_game.md) example.


## Context-Aware byLLM Methods

Methods can be integrated with LLM capabilities to process object state and context:

<!-- ### Basic Methods -->

When integrating LLMs for methods of a class, byLLM automatically adds attributes of the initialized object into the prompt of the LLM, adding extra context to the LLM.

```jac linenums="1"
import from byllm.llm { Model }

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

<!-- ### Complex AI-Integrated Workflows with Objects -->

<!-- Multi-step workflows can be implemented using object methods: -->

<!-- ```jac linenums="1"
import from byllm.llm { Model }

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
``` -->

## Adding Explicit Context for Functions, Methods and Objects

Providing appropriate context is essential for optimal LLM performance. byLLM provides multiple methods to add context to functions and objects.

### Adding Context with Docstrings

Docstrings provide context for LLM-integrated functions. byLLM uses docstrings to understand function purpose and expected behavior.

```jac linenums="1"
import from byllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

"""Translate text to the target language."""
def translate(text: str, target_language: str) -> str by llm();

"""Generate a professional email response based on the input message tone."""
def generate_email_response(message: str, recipient_type: str) -> str by llm();
```

### Adding Context with Semantic Strings (Semstrings)

Jaclang provides semantic strings using the `sem` keyword for describing object attributes and function parameters. This is useful for:

- Describing object attributes with domain-specific meaning
- Adding context to parameters
- Providing semantic information while maintaining clean code

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

### Additional Context with `incl_info`

The `incl_info` parameter provides additional context to LLM methods for context-aware processing:

```jac linenums="1"
import from byllm.llm { Model }
import from datetime { datetime }

glob llm = Model(model_name="gpt-4o");

obj Person {
    has name: str;
    has date_of_birth: str;

    # Uses the date_of_birth attribute and "today" information
    # from incl_info to calculate the person's age
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

The `sem` keyword can be used in [separate implementation files](../../jac_book/chapter_5.md#declaring-interfaces-vs-implementations) for improved code organization and maintainability.

In this example:

<!-- - `greet("Alice")` executes the normal function and returns `"Hello Alice"`
- `greet("Alice") by llm()` overrides the function with LLM behavior
- `format_data(user_data) by llm()` transforms data formatting into human-readable presentation -->


## Tool-Calling Agents with ReAct

The ReAct (Reasoning and Acting) method enables agentic behavior by allowing functions to reason about problems and use external tools. Functions can be made agentic by adding the `by llm(tools=[...])` declaration.

```jac linenums="1"
import from byllm.lib { Model }
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

A comprehensive tutorial on [building an agentic application is available here.](../examples/mtp_examples/fantasy_trading_game.md)


## Streaming Outputs

The streaming feature enables real-time token reception from LLM functions, useful for generating content where results should be displayed as they are produced.

Set `stream=True` in the invoke parameters to enable streaming:

```jac linenums="1"
import from byllm.lib { Model }

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

??? example "NOTE:"
    "The `stream=True` parameter only supports `str` output type. Tool calling is not currently supported in streaming mode but will be available in future releases."