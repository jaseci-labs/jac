# Structured Outputs

Get type-safe responses from LLMs with enums, objects, and lists.

> **Prerequisites**
>
> - Completed: [byLLM Quickstart](quickstart.md)
> - Time: ~30 minutes

---

## Why Structured Outputs?

Traditional LLM calls return strings that you must parse manually. byLLM returns proper typed objects:

```
# Traditional: Returns string, you parse it
response = llm.call("What's the sentiment?")  # "positive" or "POSITIVE" or "Positive"?

# byLLM: Returns typed enum
sentiment = analyze(text)  # Sentiment.POSITIVE (guaranteed)
```

---

## Enums

Return one of a fixed set of values:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

enum Priority {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

def classify_priority(ticket: str) -> Priority by llm();

with entry {
    tickets = [
        "My app crashes when I click the button",
        "Can you change the font color?",
        "Production database is down!",
        "Minor typo on the about page"
    ];

    for ticket in tickets {
        priority = classify_priority(ticket);
        print(f"{priority}: {ticket[:40]}...");
    }
}
```

**Output:**

```
Priority.HIGH: My app crashes when I click the button...
Priority.LOW: Can you change the font color?...
Priority.CRITICAL: Production database is down!...
Priority.LOW: Minor typo on the about page...
```

### Enums with Values

```jac
enum HttpStatus {
    OK = 200,
    NOT_FOUND = 404,
    SERVER_ERROR = 500
}

def get_status(response_description: str) -> HttpStatus by llm();
```

---

## Objects (Dataclasses)

Return complex structured data:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj Person {
    has name: str;
    has age: int;
    has occupation: str;
}

def extract_person(text: str) -> Person by llm();

with entry {
    text = "Alice is a 30-year-old software engineer from Seattle.";
    person = extract_person(text);

    print(f"Name: {person.name}");
    print(f"Age: {person.age}");
    print(f"Occupation: {person.occupation}");
}
```

**Output:**

```
Name: Alice
Age: 30
Occupation: software engineer
```

---

## Nested Objects

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj Address {
    has street: str;
    has city: str;
    has country: str;
}

obj Company {
    has name: str;
    has industry: str;
    has headquarters: Address;
}

def extract_company(text: str) -> Company by llm();

with entry {
    text = """
    Apple Inc. is a technology company headquartered at
    One Apple Park Way in Cupertino, United States.
    """;

    company = extract_company(text);

    print(f"Company: {company.name}");
    print(f"Industry: {company.industry}");
    print(f"Location: {company.headquarters.city}, {company.headquarters.country}");
}
```

---

## Lists

Return multiple items:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj Task {
    has title: str;
    has priority: str;
}

def extract_tasks(text: str) -> list[Task] by llm();

with entry {
    text = """
    Today I need to:
    - Finish the quarterly report (urgent)
    - Review pull requests (normal)
    - Update documentation (low priority)
    - Fix the login bug (critical)
    """;

    tasks = extract_tasks(text);

    print(f"Found {len(tasks)} tasks:");
    for task in tasks {
        print(f"  - [{task.priority}] {task.title}");
    }
}
```

**Output:**

```
Found 4 tasks:
  - [urgent] Finish the quarterly report
  - [normal] Review pull requests
  - [low] Update documentation
  - [critical] Fix the login bug
```

---

## Optional Fields

```jac
import from byllm.lib { Model }
import from typing { Optional }

glob llm = Model(model_name="gpt-4o-mini");

obj Contact {
    has name: str;
    has email: str;
    has phone: Optional[str] = None;  # May not be present
}

def extract_contact(text: str) -> Contact by llm();

with entry {
    text1 = "Contact John at john@example.com or call 555-1234";
    text2 = "Reach out to Jane at jane@example.com";

    c1 = extract_contact(text1);
    c2 = extract_contact(text2);

    print(f"{c1.name}: {c1.email}, phone: {c1.phone}");
    print(f"{c2.name}: {c2.email}, phone: {c2.phone}");
}
```

---

## Complex Example: Resume Parser

```jac
import from byllm.lib { Model }
import from typing { Optional }

glob llm = Model(model_name="gpt-4o-mini");

obj Education {
    has degree: str;
    has institution: str;
    has year: int;
}

obj Experience {
    has title: str;
    has company: str;
    has years: int;
    has description: str;
}

obj Resume {
    has name: str;
    has email: str;
    has phone: Optional[str];
    has skills: list[str];
    has education: list[Education];
    has experience: list[Experience];
}

def parse_resume(text: str) -> Resume by llm();

with entry {
    resume_text = """
    John Smith
    john.smith@email.com | (555) 123-4567

    SKILLS
    Python, JavaScript, Machine Learning, AWS

    EDUCATION
    BS Computer Science, MIT, 2018
    MS Data Science, Stanford, 2020

    EXPERIENCE
    Senior Engineer at Google (3 years)
    Led team building recommendation systems.

    Software Developer at Startup Inc (2 years)
    Full-stack web development.
    """;

    resume = parse_resume(resume_text);

    print(f"Name: {resume.name}");
    print(f"Skills: {', '.join(resume.skills)}");
    print(f"Education:");
    for edu in resume.education {
        print(f"  - {edu.degree} from {edu.institution} ({edu.year})");
    }
    print(f"Experience:");
    for exp in resume.experience {
        print(f"  - {exp.title} at {exp.company} ({exp.years} years)");
    }
}
```

---

## Semantic Strings

Add hints to help the LLM understand field meanings:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj Product {
    has name: str;
    has price: float;
    has category: str;
}

# Semantic hints for better extraction
sem Product.name = "The product's brand and model name";
sem Product.price = "Price in USD";
sem Product.category = "One of: Electronics, Clothing, Home, Food";

def extract_product(listing: str) -> Product by llm();
```

---

## Combining with OSP

Use structured outputs with walkers:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

enum Priority { LOW, MEDIUM, HIGH }

node Ticket {
    has title: str;
    has description: str;
    has priority: Priority = Priority.MEDIUM;
}

def analyze_priority(title: str, description: str) -> Priority by llm();

walker PrioritizeTickets {
    can prioritize with Ticket entry {
        here.priority = analyze_priority(here.title, here.description);
        report here;
        visit [-->];
    }
}

with entry {
    root ++> Ticket(title="App crash", description="App crashes on startup");
    root ++> Ticket(title="Typo", description="Small typo on homepage");
    root ++> Ticket(title="Data loss", description="Customer data was deleted");

    result = root spawn PrioritizeTickets();

    for ticket in result.reports {
        print(f"[{ticket.priority}] {ticket.title}");
    }
}
```

---

## Type Validation

byLLM validates that the LLM response matches your type:

```jac
obj StrictData {
    has count: int;      # Must be integer
    has ratio: float;    # Must be float
    has active: bool;    # Must be boolean
}

def extract_data(text: str) -> StrictData by llm();
```

If the LLM returns invalid types, byLLM will:

1. Attempt to coerce the value (e.g., "5" → 5)
2. Raise an error if coercion fails

---

## Key Takeaways

| Return Type | Use Case |
|-------------|----------|
| `str` | Free-form text |
| `int`, `float`, `bool` | Single values |
| `Enum` | One of fixed choices |
| `obj` | Structured data |
| `list[T]` | Multiple items |
| `Optional[T]` | May be missing |
| Nested objects | Complex hierarchies |

---

## Next Steps

- [Agentic AI](agentic.md) - Add tools for the LLM to use
- [byLLM Reference](../../reference/plugins/byllm.md) - Complete documentation
- [Examples Gallery](../examples/index.md) - See structured outputs in action
