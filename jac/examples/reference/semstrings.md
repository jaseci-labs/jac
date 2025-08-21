Semantic Strings in Jac provide a powerful mechanism for enriching code with natural language descriptions that can be leveraged by Large Language Models (LLMs) for intelligent code generation and execution. This feature enables developers to create AI-powered functions and provide semantic context for code elements, facilitating more intuitive and intelligent programming patterns.

#### Semantic String Concept

Jac-lang offers a unique feature called semantic strings (semstrings) that allows developers to associate natural language descriptions with code elements. These descriptions serve as instructions or context for LLMs, enabling AI-powered code execution and intelligent behavior generation.

The `sem` keyword allows you to define semantic descriptions for:

- **Function behavior**: Detailed instructions for what a function should do
- **Object properties**: Descriptions of class attributes and their purposes
- **Method parameters**: Context for function arguments and their expected values
- **Enumeration values**: Semantic meaning of enum constants
- **Nested structures**: Hierarchical descriptions for complex objects

#### Comparison with Traditional Approaches

Traditional programming relies on explicit implementations and comments for documentation:

```python
def generate_password():
    """
    Generates a secure password with specific requirements.
    This is just documentation - the implementation must be written manually.
    """
    import random
    import string

    # Manual implementation required
    characters = string.ascii_letters + string.digits + "!@#$%^&*"
    password = ''.join(random.choice(characters) for _ in range(12))
    return password
```

Jac's semantic strings enable AI-powered function execution without manual implementation:

```jac
import from mtllm.llms {OpenAI}

glob llm = OpenAI(model_name="gpt-4o");

def generate_password() -> str by llm();

sem generate_password = """\
Generates and returns password that:
    - contain at least 8 characters
    - contain at least one uppercase letter
    - contain at least one lowercase letter
    - contain at least one digit
    - contain at least one special character
""";
```

#### Function Semantic Strings

Functions can be enhanced with semantic strings that provide detailed instructions for LLM execution:

**Basic Function with Semantic String:**
```jac
def generate_specific_number() -> int by llm();

sem generate_specific_number = "Generates a specific number that is 120597 and returns it.";
```

**Complex Function with Detailed Instructions:**
```jac
def generate_password() -> str by llm();

sem generate_password = """\
Generates and returns password that:
    - contain at least 8 characters
    - contain at least one uppercase letter
    - contain at least one lowercase letter
    - contain at least one digit
    - contain at least one special character
""";
```

The `by llm()` syntax indicates that the function should be executed by the configured LLM using the semantic string as instructions.

#### Object and Property Semantic Strings

Objects and their properties can be described semantically for better AI understanding:

**Object Description:**
```jac
obj Person {
    has name: str;
    has yob: int;

    def calc_age(year: int) -> int {
        return year - self.yob;
    }
}

sem Person = "A class representing a person.";
sem Person.name = "The name of the person.";
sem Person.yob = "The year of birth of the person.";
```

**Method and Parameter Descriptions:**
```jac
sem Person.calc_age = "Calculate the age of the person.";
sem Person.calc_age.year = "The year to calculate the age against.";
```

#### Nested Object Semantic Strings

Semantic strings support hierarchical descriptions for complex nested structures:

```jac
obj OuterClass {
    obj InnerClass {
        has inner_value: str;
    }
}

sem OuterClass = "A class containing an inner class.";
sem OuterClass.InnerClass = "An inner class within OuterClass.";
sem OuterClass.InnerClass.inner_value = "A value specific to the inner class.";
```

#### Enumeration Semantic Strings

Enumerations can have semantic descriptions for both the enum itself and individual values:

```jac
enum Size {
    Small = 1,
    Medium = 2,
    Large = 3
}

sem Size = "An enumeration representing different sizes.";
sem Size.Small = "The smallest size option.";
sem Size.Medium = "The medium size option.";
sem Size.Large = "The largest size option.";
```

#### LLM Integration

Semantic strings work in conjunction with LLM configurations to enable AI-powered execution:

**LLM Configuration:**
```jac
import from mtllm.llms {OpenAI}

glob llm = OpenAI(model_name="gpt-4o");
```

**Function with LLM Execution:**
```jac
def generate_password() -> str by llm();

sem generate_password = """\
Generates and returns password that:
    - contain at least 8 characters
    - contain at least one uppercase letter
    - contain at least one lowercase letter
    - contain at least one digit
    - contain at least one special character
""";
```

**LLM Method Parameters:**
```jac
def analyze_sentiment(text: str) -> str by llm(method="Chain-of-Thoughts");

sem analyze_sentiment = "Analyze the sentiment of the given text and return positive, negative, or neutral.";
```

#### Complete Example

Here's a comprehensive example demonstrating various semantic string applications:

```jac
import from mtllm.llms {OpenAI}

glob llm = OpenAI(model_name="gpt-4o");

# AI-powered functions
def generate_password() -> str by llm();
def generate_email() -> str by llm();
def analyze_text(content: str) -> dict by llm();

# Object with semantic descriptions
obj User {
    has username: str;
    has email: str;
    has created_at: str;

    def validate_credentials(password: str) -> bool by llm();
}

# Semantic string definitions
sem generate_password = """\
Generates and returns a secure password that:
    - contains at least 8 characters
    - contains at least one uppercase letter
    - contains at least one lowercase letter
    - contains at least one digit
    - contains at least one special character
""";

sem generate_email = "Generates a realistic email address for testing purposes.";

sem analyze_text = "Analyzes the given text content and returns a dictionary with sentiment, key topics, and summary.";
sem analyze_text.content = "The text content to be analyzed for sentiment and topics.";

sem User = "A class representing a user account in the system.";
sem User.username = "The unique username for the user account.";
sem User.email = "The email address associated with the user account.";
sem User.created_at = "The timestamp when the user account was created.";

sem User.validate_credentials = "Validates if the provided password meets security requirements.";
sem User.validate_credentials.password = "The password to be validated against security criteria.";

with entry {
    # Use AI-powered functions
    password = generate_password();
    email = generate_email();

    print("Generated password:", password);
    print("Generated email:", email);

    # Create user with AI validation
    user = User(username="testuser", email=email, created_at="2025-06-17");
    is_valid = user.validate_credentials(password);

    print("Password is valid:", is_valid);
}
```

#### File Organization for Semantic Strings

Like implementations, semantic strings can be organized in multiple ways:

##### Same File Organization

Semantic strings can be defined in the same file as the code:

```jac
def generate_password() -> str by llm();

sem generate_password = "Generates a secure password with specific requirements.";
```

##### Separate Semantic Files

For better organization, semantic strings can be separated into dedicated files:

**File structure:**
```
base
├── main.jac
└── main.impl.jac
```

**main.jac:**
```jac
import from mtllm.llms {OpenAI}

glob llm = OpenAI(model_name="gpt-4o");

def generate_password() -> str by llm();

obj User {
    has name: str;
    has email: str;
}

with entry {
    password = generate_password();
    print("Password:", password);
}
```

**main.sem.jac:**
```jac
sem generate_password = """\
Generates and returns password that:
    - contain at least 8 characters
    - contain at least one uppercase letter
    - contain at least one lowercase letter
    - contain at least one digit
    - contain at least one special character
""";

sem User = "A class representing a user account.";
sem User.name = "The full name of the user.";
sem User.email = "The email address of the user.";
```

#### Benefits of Semantic Strings

1. **AI-Powered Development**: Enable LLMs to generate function implementations based on natural language descriptions

2. **Self-Documenting Code**: Semantic strings serve as both documentation and functional specifications

3. **Intelligent Behavior**: LLMs can understand context and generate appropriate responses based on semantic descriptions

4. **Rapid Prototyping**: Quickly create functional prototypes without writing detailed implementations

5. **Maintainable AI Integration**: Clear separation between AI instructions and traditional code logic

6. **Flexible Descriptions**: Support for simple one-liners to complex multi-line instructions

7. **Hierarchical Context**: Nested semantic descriptions for complex object structures

8. **Method-Agnostic**: Works with various LLM providers and reasoning methods
